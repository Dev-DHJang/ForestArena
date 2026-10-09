import type pg from "pg";

export class GuestError extends Error {
  constructor(message: string, readonly status: number) { super(message); }
}

export function normalizeNickname(value: unknown): string {
  if (typeof value !== "string") throw new GuestError("invalid_nickname", 400);
  const nickname = value.normalize("NFC");
  if (!/^[가-힣A-Za-z0-9_]{2,12}$/.test(nickname)) throw new GuestError("invalid_nickname", 400);
  return nickname;
}

export class DemoGuests {
  constructor(private readonly pool: pg.Pool) {}

  async get(playerId: string): Promise<{ player_id: string; nickname: string | null }> {
    const result = await this.pool.query<{ player_id: string; nickname: string | null }>(
      "SELECT player_id, nickname FROM app.players WHERE player_id = $1", [playerId],
    );
    if (!result.rows[0]) throw new GuestError("unauthorized", 401);
    return result.rows[0];
  }

  async set(playerId: string, value: unknown): Promise<{ player_id: string; nickname: string }> {
    const nickname = normalizeNickname(value);
    try {
      const result = await this.pool.query<{ player_id: string; nickname: string }>(
        "UPDATE app.players SET nickname = $2 WHERE player_id = $1 RETURNING player_id, nickname", [playerId, nickname],
      );
      if (!result.rows[0]) throw new GuestError("unauthorized", 401);
      return result.rows[0];
    } catch (error) {
      if ((error as { code?: string; constraint?: string }).code === "23505" &&
          (error as { constraint?: string }).constraint === "players_nickname_unique") {
        throw new GuestError("nickname_taken", 409);
      }
      throw error;
    }
  }
}
