import { createHash, randomUUID } from "node:crypto";
import pg from "pg";
import { newOpaqueToken } from "./tokens.js";
import type { MatchPair } from "./matchmaking.js";

const { Pool } = pg;

export class Database {
  readonly pool: pg.Pool;

  constructor(connectionString: string) {
    this.pool = new Pool({ connectionString, max: 5 });
  }

  async ready(): Promise<void> {
    await this.pool.query("SELECT 1");
  }

  async close(): Promise<void> {
    await this.pool.end();
  }

  static hashToken(token: string): string {
    return createHash("sha256").update(token).digest("hex");
  }

  async createGuest(): Promise<{ playerId: string; refreshToken: string }> {
    const playerId = randomUUID();
    const refreshToken = newOpaqueToken();
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      await client.query(
        "INSERT INTO app.players (player_id, display_name) VALUES ($1, $2)",
        [playerId, `Guest-${playerId.slice(0, 8)}`],
      );
      await client.query(
        "INSERT INTO app.refresh_tokens (token_hash, player_id, expires_at) VALUES ($1, $2, now() + interval '30 days')",
        [Database.hashToken(refreshToken), playerId],
      );
      await client.query("COMMIT");
      return { playerId, refreshToken };
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  }

  async rotateRefreshToken(token: string): Promise<{ playerId: string; refreshToken: string } | undefined> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const result = await client.query<{ player_id: string }>(
        `UPDATE app.refresh_tokens
           SET revoked_at = now()
         WHERE token_hash = $1 AND revoked_at IS NULL AND expires_at > now()
         RETURNING player_id`,
        [Database.hashToken(token)],
      );
      const row = result.rows[0];
      if (!row) {
        await client.query("ROLLBACK");
        return undefined;
      }
      const refreshToken = newOpaqueToken();
      await client.query(
        "INSERT INTO app.refresh_tokens (token_hash, player_id, expires_at) VALUES ($1, $2, now() + interval '30 days')",
        [Database.hashToken(refreshToken), row.player_id],
      );
      await client.query("COMMIT");
      return { playerId: row.player_id, refreshToken };
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  }

  async createMatch(pair: MatchPair): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      await client.query("INSERT INTO app.matches (match_id, status) VALUES ($1, 'matched')", [pair.matchId]);
      await client.query(
        `INSERT INTO app.match_participants (match_id, player_id, slot, character_id)
         VALUES ($1, $2, 1, 'ja-hyun'), ($1, $3, 2, 'myo-ryung')`,
        [pair.matchId, pair.first.playerId, pair.second.playerId],
      );
      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  }

  async finishMatch(input: {
    matchId: string;
    winnerPlayerId: string | null;
    reason: "combat" | "draw" | "disconnect";
    finalTick: number;
    snapshotHash: string;
  }): Promise<"stored" | "duplicate" | "missing" | "invalid_winner"> {
    const existing = await this.pool.query<{ status: string; winner_valid: boolean }>(
      `SELECT match.status,
              ($2::uuid IS NULL OR EXISTS (
                SELECT 1 FROM app.match_participants participant
                 WHERE participant.match_id = match.match_id
                   AND participant.player_id = $2::uuid
              )) AS winner_valid
         FROM app.matches match
        WHERE match.match_id = $1`,
      [input.matchId, input.winnerPlayerId],
    );
    const current = existing.rows[0];
    if (!current) return "missing";
    if (!current.winner_valid) return "invalid_winner";
    if (current.status === "ended") return "duplicate";
    const result = await this.pool.query(
      `UPDATE app.matches
          SET status = 'ended', winner_player_id = $2, result_reason = $3,
              final_tick = $4, snapshot_hash = $5, ended_at = now(),
              started_at = COALESCE(started_at, created_at)
        WHERE match_id = $1 AND status <> 'ended'
      RETURNING match_id`,
      [input.matchId, input.winnerPlayerId, input.reason, input.finalTick, input.snapshotHash],
    );
    if (result.rowCount === 1) return "stored";
    return "duplicate";
  }
}
