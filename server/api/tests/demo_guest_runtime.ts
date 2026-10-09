import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import pg from "pg";
import { issueAccessToken, newOpaqueToken } from "../src/tokens.js";
import { DemoGuests } from "../src/demo_guests.js";

const base = process.env.FOREST_ARENA_API_URL ?? "http://127.0.0.1:3000";
const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const secret = process.env.FOREST_ARENA_TOKEN_SECRET!;
const service = process.env.FOREST_ARENA_SERVICE_TOKEN!;
const created: string[] = [];
async function request(method: string, path: string, access = "", payload?: unknown, serviceToken?: string) {
  const response = await fetch(base + path, {
    method,
    headers: { "content-type": "application/json", "authorization": "Bearer " + access,
      ...(serviceToken === undefined ? {} : { "x-forest-arena-service-token": serviceToken }) },
    ...(payload === undefined ? {} : { body: JSON.stringify(payload) }),
    signal: AbortSignal.timeout(8000),
  });
  return { status: response.status, data: await response.json() as Record<string, any> };
}
async function guest() {
  const result = await request("POST", "/v1/auth/guest", "", {});
  assert.equal(result.status, 201);
  created.push(result.data.player_id);
  return result.data;
}
try {
  const first = await guest(), second = await guest();
  const a = first.access_token as string, b = second.access_token as string;
  assert.equal((await request("GET", "/v1/guest/profile")).status, 401);
  assert.equal((await request("PATCH", "/v1/guest/profile", "bad", { nickname: "나비" })).status, 401);
  assert.deepEqual((await request("GET", "/v1/guest/profile", a)).data, { player_id: first.player_id, nickname: null });
  assert.equal((await request("POST", "/internal/v1/lan/auth", "", { access_token: a })).status, 401);
  assert.equal((await request("POST", "/internal/v1/lan/auth", "", { access_token: a }, "incorrect")).status, 401);
  assert.equal((await request("POST", "/internal/v1/lan/auth", "", { access_token: a }, service)).data.error, "nickname_required");
  for (const nickname of ["x", "x".repeat(13), " 이름", "이름 ", "a-b", "aa\n", null]) {
    assert.equal((await request("PATCH", "/v1/guest/profile", a, { nickname })).data.error, "invalid_nickname");
  }
  const name = "D" + randomUUID().replaceAll("-", "").slice(0, 9);
  const racing = await Promise.all([
    request("PATCH", "/v1/guest/profile", a, { nickname: name }),
    request("PATCH", "/v1/guest/profile", b, { nickname: name.toLowerCase() }),
  ]);
  assert.deepEqual(racing.map(value => value.status).sort(), [200, 409]);
  assert.equal(racing.find(value => value.status === 409)!.data.error, "nickname_taken");
  // Korean canonical equivalence, display_name preservation, rename and freed old nickname.
  const koreanName = "나비" + name.slice(1, 6);
  assert.equal((await request("PATCH", "/v1/guest/profile", a, { nickname: koreanName })).data.nickname, koreanName.normalize("NFC"));
  assert.equal((await request("PATCH", "/v1/guest/profile", b, { nickname: koreanName.normalize("NFC") })).data.error, "nickname_taken");
  assert.equal((await request("PATCH", "/v1/guest/profile", b, { nickname: name })).status, 200);
  assert.equal((await request("POST", "/internal/v1/lan/auth", "", { access_token: a, player_id: second.player_id, nickname: "Fake" }, service)).data.player_id, first.player_id);
  const stored = await pool.query("SELECT nickname, display_name FROM app.players WHERE player_id=$1", [first.player_id]);
  assert.equal(stored.rows[0].display_name, "Guest-" + first.player_id.slice(0, 8));
  const reopened = new pg.Pool({ connectionString: process.env.DATABASE_URL });
  try { assert.equal((await new DemoGuests(reopened).get(first.player_id)).nickname, koreanName.normalize("NFC")); }
  finally { await reopened.end(); }
  const refresh = await request("POST", "/v1/auth/refresh", "", { refresh_token: first.refresh_token, next_refresh_token: newOpaqueToken() });
  assert.equal(refresh.status, 200);
  assert.equal(refresh.data.player_id, first.player_id);
  assert.equal((await request("GET", "/v1/guest/profile", refresh.data.access_token)).data.nickname, koreanName.normalize("NFC"));
  const expired = issueAccessToken(first.player_id, secret, Math.floor(Date.now() / 1000) - 1000);
  for (const access_token of [expired, "bad", issueAccessToken(randomUUID(), secret)]) {
    assert.equal((await request("POST", "/internal/v1/lan/auth", "", { access_token }, service)).status, 401);
  }
  // Client spoofed proxy headers cannot change loopback socket-based admission.
  const spoof = await fetch(base + "/health/live", { headers: { "x-forwarded-for": "8.8.8.8" } });
  assert.equal(spoof.status, 200);
  console.log("DEMO_GUEST_API_RUNTIME: PASS (PostgreSQL uniqueness race, NFC, persisted guest, internal auth and refresh)");
} finally {
  if (created.length) await pool.query("DELETE FROM app.players WHERE player_id = ANY($1::uuid[])", [created]);
  await pool.end();
}
