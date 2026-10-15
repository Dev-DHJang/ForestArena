import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { randomUUID, timingSafeEqual } from "node:crypto";
import { URL } from "node:url";
import { loadConfig } from "./config.js";
import { DemoGuests, GuestError } from "./demo_guests.js";
import { isAllowedLanAddress } from "./lan_network.js";
import { Database } from "./db.js";
import {Identities,canonicalId,locked,uuid} from "./identities.js";
import {MenuServices} from "./menu_services.js";
import { Profiles, ProfileError } from "./profiles.js";
import { Matchmaker, type QueueEntry } from "./matchmaking.js";
import { issueAccessToken, issueMatchToken, verifyToken } from "./tokens.js";

const config = loadConfig();
const database = new Database(config.databaseUrl);
const demoGuests = new DemoGuests(database.pool);
const profiles = new Profiles(database.pool);
const identities=new Identities(database.pool,config.tokenSecret);
const menus=new MenuServices(database.pool);
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
  if(request.method==="GET"&&url.pathname==="/v1/service")return json(response,200,await identities.service());
  if(request.method==="GET"&&url.pathname==="/v1/identity")return json(response,200,await identities.get(playerId(request)));
  if(request.method==="POST"&&url.pathname==="/v1/identity/merge")return json(response,200,await identities.merge(playerId(request),await body(request)));
  if(request.method==="GET"&&url.pathname==="/v1/progress")return json(response,200,await menus.progress(playerId(request)));
  if(request.method==="POST"&&url.pathname==="/v1/progress/offline")return json(response,200,await menus.offline(playerId(request),await body(request)));
  if(request.method==="GET"&&url.pathname==="/v1/social")return json(response,200,await menus.social(playerId(request),url.searchParams.get("search")));
  if(request.method==="POST"&&url.pathname==="/v1/social/action")return json(response,200,await menus.socialAction(playerId(request),await body(request)));
  if(request.method==="POST"&&url.pathname==="/v1/presence")return json(response,200,await menus.presence(playerId(request),await body(request)));
  if(request.method==="GET"&&url.pathname==="/v1/leaderboard")return json(response,200,await menus.leaderboard(playerId(request),url.searchParams.get("scope")??"all",Number(url.searchParams.get("page")??"0")));
  const lanMenuMatch=url.pathname.match(/^\/internal\/v1\/lan\/matches\/([0-9a-f-]+)\/(register|result)$/);
  if(request.method==="POST"&&(url.pathname==="/internal/v1/lan/rooms"||lanMenuMatch)) {
    const supplied=request.headers["x-forest-arena-service-token"];
    if(typeof supplied!=="string"||!secureEqual(supplied,config.serviceToken))return json(response,401,{error:"unauthorized"});
    const payload=await body(request);
    return json(response,200,lanMenuMatch?(lanMenuMatch[2]==="register"?await menus.register(lanMenuMatch[1]!,payload):await menus.result(lanMenuMatch[1]!,payload)):await menus.room(payload));
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
    const id=playerId(request);const guest=await demoGuests.get(id);
    return json(response,200,{...guest,player_id:id});
  }
  if (request.method === "PATCH" && url.pathname === "/v1/guest/profile") {
    const id = playerId(request);
    const guest=await demoGuests.set(id,(await body(request)).nickname);
    return json(response,200,{...guest,player_id:id});
  }
  if (request.method === "POST" && url.pathname === "/internal/v1/lan/auth") {
    const supplied = request.headers["x-forest-arena-service-token"];
    if (typeof supplied !== "string" || !secureEqual(supplied, config.serviceToken)) return json(response, 401, { error: "unauthorized" });
    const payload = await body(request);
    if (typeof payload.access_token !== "string") return json(response, 401, { error: "unauthorized" });
    const id = verifyToken(payload.access_token, config.tokenSecret, "access").sub;
    if(payload.existing_player_ids!==undefined&&(!Array.isArray(payload.existing_player_ids)||payload.existing_player_ids.length>2||!payload.existing_player_ids.every(uuid)))return json(response,400,{error:"invalid_existing_players"});
    const guest=await locked(database.pool,async db=>{
      const canonical=await canonicalId(db,id);
      const current=(await db.query<{player_id:string;nickname:string|null}>("SELECT player_id,nickname FROM app.players WHERE player_id=$1",[canonical])).rows[0]!;
      const canonical_players:Record<string,string>={};
      for(const raw of (payload.existing_player_ids??[]) as string[])canonical_players[raw]=await canonicalId(db,raw);
      return {...current,canonical_players};
    });
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
    const authenticatedPlayer = await canonicalId(database.pool,playerId(request));
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
    const entry = matchmaker.get(queueMatch[1], await canonicalId(database.pool,playerId(request)));
    return entry ? json(response, 200, publicEntry(entry)) : json(response, 404, { error: "queue_entry_not_found" });
  }
  if (queueMatch?.[1] && request.method === "DELETE") {
    return matchmaker.cancel(queueMatch[1], await canonicalId(database.pool,playerId(request)))
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
