import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { randomUUID, timingSafeEqual } from "node:crypto";
import { URL } from "node:url";
import { loadConfig } from "./config.js";
import { DemoGuests, GuestError } from "./demo_guests.js";
import { isAllowedLanAddress } from "./lan_network.js";
import { Database } from "./db.js";
import { Profiles, ProfileError } from "./profiles.js";
import { Matchmaker, type QueueEntry } from "./matchmaking.js";
import { issueAccessToken, issueMatchToken, verifyToken } from "./tokens.js";

const config = loadConfig();
const database = new Database(config.databaseUrl);
const demoGuests = new DemoGuests(database.pool);
const profiles = new Profiles(database.pool);
const matchmaker = new Matchmaker();
const maxBodyBytes = 16 * 1024;

function json(response: ServerResponse, status: number, body: unknown): void {
  const payload = JSON.stringify(body);
  response.writeHead(status, { "content-type": "application/json; charset=utf-8", "content-length": Buffer.byteLength(payload) });
  response.end(payload);
}

async function body(request: IncomingMessage): Promise<Record<string, unknown>> {
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const chunk of request) {
    const value = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    size += value.length;
    if (size > maxBodyBytes) throw new Error("body_too_large");
    chunks.push(value);
  }
  if (size === 0) return {};
  let parsed: unknown;
  try { parsed = JSON.parse(Buffer.concat(chunks).toString("utf8")); }
  catch { throw new Error("invalid_json"); }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("invalid_json");
  return parsed as Record<string, unknown>;
}

function playerId(request: IncomingMessage): string {
  const authorization = request.headers.authorization;
  if (!authorization?.startsWith("Bearer ")) throw new Error("unauthorized");
  return verifyToken(authorization.slice(7), config.tokenSecret, "access").sub;
}

function secureEqual(left: string, right: string): boolean {
  const a = Buffer.from(left);
  const b = Buffer.from(right);
  return a.length === b.length && timingSafeEqual(a, b);
}

function publicEntry(entry: QueueEntry): Record<string, unknown> {
  const result: Record<string, unknown> = { queue_entry_id: entry.id, status: entry.status };
  if (entry.status === "matched" && entry.matchId && entry.slot && entry.characterId) {
    result.match_id = entry.matchId;
    result.slot = entry.slot;
    result.character_id = entry.characterId;
    result.websocket_url = config.advertisedWebSocketUrl;
    result.match_ticket = issueMatchToken(entry.playerId, entry.matchId, entry.slot, entry.characterId, config.tokenSecret);
  }
  return result;
}

async function route(request: IncomingMessage, response: ServerResponse): Promise<void> {
  const requestId = randomUUID();
  response.setHeader("x-request-id", requestId);
  if (config.demoMode && !isAllowedLanAddress(request.socket.remoteAddress, config.allowedCidr!)) {
    return json(response, 403, { error: "network_not_allowed" });
  }
  const url = new URL(request.url ?? "/", "http://local");

  if (request.method === "GET" && url.pathname === "/health/live") return json(response, 200, { status: "ok" });
  if (request.method === "GET" && url.pathname === "/health/ready") {
    await database.ready();
    return json(response, 200, { status: "ready" });
  }
  if (request.method === "POST" && url.pathname === "/v1/auth/guest") {
    await body(request);
    const guest = await database.createGuest();
    return json(response, 201, {
      protocol_version: 1,
      player_id: guest.playerId,
      access_token: issueAccessToken(guest.playerId, config.tokenSecret),
      access_expires_in: 900,
      refresh_token: guest.refreshToken,
      refresh_expires_in: 2_592_000,
    });
  }
  if (request.method === "POST" && url.pathname === "/v1/auth/refresh") {
    const payload = await body(request);
    if (typeof payload.refresh_token !== "string") return json(response, 400, { error: "refresh_token_required" });
    if (payload.next_refresh_token !== undefined && (typeof payload.next_refresh_token !== "string" || !/^[A-Za-z0-9_-]{43}$/.test(payload.next_refresh_token))) return json(response, 400, { error: "invalid_next_refresh_token" });
    const rotated = await database.rotateRefreshToken(payload.refresh_token, payload.next_refresh_token as string | undefined);
    if (!rotated) return json(response, 401, { error: "invalid_refresh_token" });
    return json(response, 200, {
      protocol_version: 1,
      player_id: rotated.playerId,
      access_token: issueAccessToken(rotated.playerId, config.tokenSecret),
      access_expires_in: 900,
      refresh_token: rotated.refreshToken,
      refresh_expires_in: 2_592_000,
    });
  }
  if (request.method === "GET" && url.pathname === "/v1/guest/profile") {
    return json(response, 200, await demoGuests.get(playerId(request)));
  }
  if (request.method === "PATCH" && url.pathname === "/v1/guest/profile") {
    const id = playerId(request);
    return json(response, 200, await demoGuests.set(id, (await body(request)).nickname));
  }
  if (request.method === "POST" && url.pathname === "/internal/v1/lan/auth") {
    const supplied = request.headers["x-forest-arena-service-token"];
    if (typeof supplied !== "string" || !secureEqual(supplied, config.serviceToken)) return json(response, 401, { error: "unauthorized" });
    const payload = await body(request);
    if (typeof payload.access_token !== "string") return json(response, 401, { error: "unauthorized" });
    const id = verifyToken(payload.access_token, config.tokenSecret, "access").sub;
    const guest = await demoGuests.get(id);
    if (!guest.nickname) return json(response, 409, { error: "nickname_required" });
    return json(response, 200, guest);
  }
  if (request.method === "GET" && url.pathname === "/v1/profile") {
    const saved = await profiles.get(playerId(request));
    return saved ? json(response, 200, saved) : json(response, 404, { error: "profile_missing" });
  }
  if (request.method === "POST" && url.pathname === "/v1/profile/import") {
    const id = playerId(request);
    return json(response, 200, await profiles.import(id, (await body(request)).profile));
  }
  if (request.method === "POST" && url.pathname === "/v1/profile/actions") {
    const id = playerId(request);
    return json(response, 200, await profiles.action(id, await body(request)));
  }
  if (request.method === "POST" && url.pathname === "/v1/matchmaking/join") {
    const authenticatedPlayer = playerId(request);
    const payload = await body(request);
    if (payload.queue !== undefined && payload.queue !== "duel_dev") return json(response, 400, { error: "unsupported_queue" });
    const joined = matchmaker.join(authenticatedPlayer);
    if (joined.pair) {
      try {
        await database.createMatch(joined.pair);
      } catch (error) {
        matchmaker.fail(joined.pair.matchId);
        throw error;
      }
    }
    return json(response, 200, publicEntry(joined.entry));
  }
  const queueMatch = url.pathname.match(/^\/v1\/matchmaking\/([0-9a-f-]+)$/);
  if (queueMatch?.[1] && request.method === "GET") {
    const entry = matchmaker.get(queueMatch[1], playerId(request));
    return entry ? json(response, 200, publicEntry(entry)) : json(response, 404, { error: "queue_entry_not_found" });
  }
  if (queueMatch?.[1] && request.method === "DELETE") {
    return matchmaker.cancel(queueMatch[1], playerId(request))
      ? json(response, 200, { status: "cancelled" })
      : json(response, 409, { error: "queue_entry_not_waiting" });
  }
  const resultMatch = url.pathname.match(/^\/internal\/v1\/matches\/([0-9a-f-]+)\/result$/);
  if (resultMatch?.[1] && request.method === "POST") {
    const supplied = request.headers["x-forest-arena-service-token"];
    if (typeof supplied !== "string" || !secureEqual(supplied, config.serviceToken)) return json(response, 401, { error: "unauthorized" });
    const payload = await body(request);
    const reason = payload.reason;
    const winner = payload.winner_player_id;
    const tick = payload.final_tick;
    const hash = payload.snapshot_hash;
    if (!["combat", "draw", "disconnect"].includes(String(reason)) || !(winner === null || typeof winner === "string") || !Number.isInteger(tick) || typeof hash !== "string" || !/^[0-9a-f]{64}$/.test(hash)) {
      return json(response, 400, { error: "invalid_result" });
    }
    const stored = await database.finishMatch({
      matchId: resultMatch[1],
      winnerPlayerId: winner as string | null,
      reason: reason as "combat" | "draw" | "disconnect",
      finalTick: tick as number,
      snapshotHash: hash,
    });
    if (stored === "missing") return json(response, 404, { error: "match_not_found" });
    if (stored === "invalid_winner") return json(response, 400, { error: "winner_not_participant" });
    matchmaker.complete(resultMatch[1]);
    return json(response, 200, { status: stored });
  }
  json(response, 404, { error: "not_found" });
}

const server = createServer((request, response) => {
  route(request, response).catch((error: unknown) => {
    const code = error instanceof Error ? error.message : "internal_error";
    const authenticationErrors = new Set(["invalid_token", "expired_token", "unauthorized"]);
    const status = (error instanceof ProfileError || error instanceof GuestError) ? error.status : code === "body_too_large" ? 413 : code === "invalid_json" ? 400 : code === "game_server_busy" ? 409 : authenticationErrors.has(code) ? 401 : 500;
    if (status === 500) console.error(JSON.stringify({ level: "error", code: "internal_error", request_path: new URL(request.url ?? "/", "http://localhost").pathname }));
    if (!response.headersSent) json(response, status, { error: status === 500 ? "internal_error" : code });
    else response.end();
  });
});

server.listen(config.port, config.host, () => {
  console.log(JSON.stringify({ event: "api_listening", host: config.host, port: config.port }));
});

async function shutdown(): Promise<void> {
  server.close();
  await database.close();
}
process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
