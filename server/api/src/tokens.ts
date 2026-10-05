import { createHmac, randomBytes, timingSafeEqual } from "node:crypto";

export type TokenClaims = {
  kind: "access" | "match";
  sub: string;
  iat: number;
  exp: number;
  match_id?: string;
  slot?: 1 | 2;
  character_id?: "ja-hyun" | "myo-ryung";
  nonce?: string;
};

const header = { alg: "HS256", typ: "JWT" } as const;

function encode(value: unknown): string {
  return Buffer.from(JSON.stringify(value)).toString("base64url");
}

function signature(input: string, secret: string): Buffer {
  return createHmac("sha256", secret).update(input).digest();
}

export function signToken(claims: TokenClaims, secret: string): string {
  const input = `${encode(header)}.${encode(claims)}`;
  return `${input}.${signature(input, secret).toString("base64url")}`;
}

export function verifyToken(token: string, secret: string, expectedKind: TokenClaims["kind"], now = Math.floor(Date.now() / 1000)): TokenClaims {
  const parts = token.split(".");
  if (parts.length !== 3 || !parts[0] || !parts[1] || !parts[2]) throw new Error("invalid_token");
  const input = `${parts[0]}.${parts[1]}`;
  const actual = Buffer.from(parts[2], "base64url");
  const expected = signature(input, secret);
  if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) throw new Error("invalid_token");
  const parsed = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8")) as Partial<TokenClaims>;
  if (parsed.kind !== expectedKind || typeof parsed.sub !== "string" || typeof parsed.iat !== "number" || typeof parsed.exp !== "number") {
    throw new Error("invalid_token");
  }
  if (parsed.exp <= now || parsed.iat > now + 30) throw new Error("expired_token");
  return parsed as TokenClaims;
}

export function issueAccessToken(playerId: string, secret: string, now = Math.floor(Date.now() / 1000)): string {
  return signToken({ kind: "access", sub: playerId, iat: now, exp: now + 15 * 60 }, secret);
}

export function issueMatchToken(playerId: string, matchId: string, slot: 1 | 2, characterId: "ja-hyun" | "myo-ryung", secret: string, now = Math.floor(Date.now() / 1000)): string {
  return signToken({
    kind: "match",
    sub: playerId,
    match_id: matchId,
    slot,
    character_id: characterId,
    nonce: randomBytes(16).toString("hex"),
    iat: now,
    exp: now + 60,
  }, secret);
}

export function newOpaqueToken(): string {
  return randomBytes(32).toString("base64url");
}
