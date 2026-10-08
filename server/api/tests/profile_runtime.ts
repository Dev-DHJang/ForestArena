import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import pg from "pg";
import { readFileSync } from "node:fs";
import { issueAccessToken } from "../src/tokens.js";
import { newOpaqueToken } from "../src/tokens.js";

const base = process.env.FOREST_ARENA_API_URL ?? "http://127.0.0.1:3000";
const db = new pg.Pool({connectionString: process.env.DATABASE_URL});
const fresh = {schema_version: 2, first_granted: false, characters: [], accessories: [], selected_character: "", selected_accessory: "", opponent_character: "ja-hyun", accessibility: {text_scale: 1, reduce_visual_effects: false, haptics_enabled: true}};
async function request(method: string, path: string, token = "", body?: unknown) {
  const r = await fetch(base + path, {method, headers: {"Content-Type": "application/json", "Authorization": "Bearer " + token}, ...(body === undefined ? {} : {body: JSON.stringify(body)})});
  return {status: r.status, data: await r.json() as any};
}
try {
  const auth = await request("POST", "/v1/auth/guest", "", {});
  assert.equal(auth.status, 201);
  const token = auth.data.access_token as string, player = auth.data.player_id as string;
  assert.equal((await request("GET", "/v1/profile", token)).status, 404);
  assert.equal((await request("GET", "/v1/profile")).status, 401);
  assert.equal((await request("POST", "/v1/profile/import", token, {profile: {...fresh, schema_version: 99}})).status, 400);
  assert.equal((await request("POST", "/v1/profile/import", token, {profile: fresh})).data.revision, 1);
  const grant = {request_id: randomUUID(), expected_revision: 1, action: "grant_first", payload: {id: "nabi"}};
  const replay = await Promise.all([request("POST", "/v1/profile/actions", token, grant), request("POST", "/v1/profile/actions", token, grant)]);
  for (const r of replay) { assert.equal(r.status, 200); assert.equal(r.data.revision, 2); }
  assert.deepEqual(replay[0]!.data, replay[1]!.data);
  assert.equal((await request("POST", "/v1/profile/actions", token, {...grant, payload: {id: "ja-hyun"}})).data.error, "request_id_conflict");
  assert.equal((await request("POST", "/v1/profile/import", token, {profile: fresh})).data.revision, 2);
  const concurrent = await Promise.all(["yu-ran", "myo-ryung"].map(id => request("POST", "/v1/profile/actions", token, {request_id: randomUUID(), expected_revision: 2, action: "purchase", payload: {id}})));
  assert.deepEqual(concurrent.map(r => r.status).sort(), [200, 409]);
  assert.equal((await request("POST", "/v1/profile/actions", token, {request_id: randomUUID(), expected_revision: 3, action: "select", payload: {character: "ja-hyun", accessory: "", opponent: "nabi"}})).status, 400);
  const second = await request("POST", "/v1/auth/guest", "", {});
  assert.equal((await request("GET", "/v1/profile", second.data.access_token)).status, 404);
  const rotated = await request("POST", "/v1/auth/refresh", "", {refresh_token: auth.data.refresh_token});
  assert.equal(rotated.status, 200);
  assert.equal(rotated.data.player_id, player);
  assert.equal((await request("GET", "/v1/profile", rotated.data.access_token)).data.revision, 3);
  const next = newOpaqueToken();
  const rotation = {refresh_token: rotated.data.refresh_token, next_refresh_token: next};
  const rotations = await Promise.all([request("POST", "/v1/auth/refresh", "", rotation), request("POST", "/v1/auth/refresh", "", rotation)]);
  for (const r of rotations) {
    assert.equal(r.status, 200);
    assert.equal(r.data.refresh_token, next);
    assert.equal(r.data.player_id, player);
  }
  assert.equal((await request("POST", "/v1/auth/refresh", "", {refresh_token: rotation.refresh_token})).status, 401);
  assert.equal((await request("POST", "/v1/auth/refresh", "", {...rotation, next_refresh_token: newOpaqueToken()})).status, 401);
  const expired = issueAccessToken(player, process.env.FOREST_ARENA_TOKEN_SECRET!, Math.floor(Date.now() / 1000) - 1000);
  assert.equal((await request("GET", "/v1/profile", expired)).status, 401);
  const invalidJson = await fetch(base + "/v1/profile/import", {method: "POST", headers: {"Authorization": "Bearer " + token}, body: "{"});
  assert.equal(invalidJson.status, 400);
  const stored = (await db.query("SELECT profile, revision FROM app.player_profiles WHERE player_id = $1", [player])).rows[0];
  assert.equal(stored.revision, 3);
  assert.equal(stored.profile.characters.length, 2);
  const applied = (await db.query("SELECT count(*)::int AS count FROM app.profile_requests WHERE player_id = $1", [player])).rows[0];
  assert.equal(applied.count, 2);
  if (process.env.FOREST_ARENA_PROFILE_REPORT) {
    const report = JSON.parse(readFileSync(process.env.FOREST_ARENA_PROFILE_REPORT, "utf8"));
    const actual = (await db.query("SELECT profile, revision FROM app.player_profiles WHERE player_id = $1", [report.player_id])).rows[0];
    assert.deepEqual(actual, {profile: report.profile, revision: report.revision});
    console.log("PROFILE_GAME_SQL: PASS (Godot profile and PostgreSQL row are identical)");
  }
  console.log("PROFILE_API_RUNTIME: PASS (actual PostgreSQL, auth isolation, import, concurrency, replay, token refresh)");
} finally { await db.end(); }
