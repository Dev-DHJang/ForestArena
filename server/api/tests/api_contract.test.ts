import test from "node:test";
import assert from "node:assert/strict";
import { Matchmaker } from "../src/matchmaking.js";
import { issueAccessToken, issueMatchToken, verifyToken } from "../src/tokens.js";

const secret = "0123456789abcdef0123456789abcdef";

test("access token checks kind, signature and expiry", () => {
  const token = issueAccessToken("player-a", secret, 100);
  assert.equal(verifyToken(token, secret, "access", 101).sub, "player-a");
  assert.throws(() => verifyToken(token, `${secret}x`, "access", 101), /invalid_token/);
  assert.throws(() => verifyToken(token, secret, "match", 101), /invalid_token/);
  assert.throws(() => verifyToken(token, secret, "access", 1001), /expired_token/);
});

test("match ticket carries fixed slot and expires after 60 seconds", () => {
  const token = issueMatchToken("player-a", "match-a", 1, "ja-hyun", secret, 100);
  const claims = verifyToken(token, secret, "match", 159);
  assert.equal(claims.match_id, "match-a");
  assert.equal(claims.slot, 1);
  assert.equal(claims.character_id, "ja-hyun");
  assert.throws(() => verifyToken(token, secret, "match", 160), /expired_token/);
});

test("matchmaker pairs fixed loadouts, prevents a second active room and releases after completion", () => {
  const matchmaking = new Matchmaker();
  const first = matchmaking.join("player-a").entry;
  assert.equal(first.status, "waiting");
  assert.equal(matchmaking.join("player-a").entry.id, first.id);
  const second = matchmaking.join("player-b");
  assert.equal(second.pair?.first.characterId, "ja-hyun");
  assert.equal(second.pair?.second.characterId, "myo-ryung");
  assert.throws(() => matchmaking.join("player-c"), /game_server_busy/);
  matchmaking.complete(second.pair!.matchId);
  assert.equal(matchmaking.join("player-c").entry.status, "waiting");
});

test("only a waiting player can cancel its own entry", () => {
  const matchmaking = new Matchmaker();
  const waiting = matchmaking.join("player-a").entry;
  assert.equal(matchmaking.cancel(waiting.id, "player-b"), false);
  assert.equal(matchmaking.cancel(waiting.id, "player-a"), true);
  assert.equal(matchmaking.get(waiting.id, "player-a"), undefined);
});
