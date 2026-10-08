import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import type pg from "pg";

const catalog = JSON.parse(readFileSync(new URL("./profile_catalog.json", import.meta.url), "utf8")) as { characters: string[]; accessories: string[] };
export type Profile = {
  schema_version: 3; first_granted: boolean; characters: string[]; accessories: string[];
  selected_character: string; selected_accessory: string; opponent_character: string;
  nickname: string; minimap: { transparency: number; marker_style: "face" | "dot"; show_names: boolean };
  accessibility: { text_scale: number; reduce_visual_effects: boolean; haptics_enabled: boolean };
};
export type SavedProfile = { profile: Profile; revision: number };
export class ProfileError extends Error {
  constructor(message: string, readonly status = 400) { super(message); }
}
function object(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === "object" && !Array.isArray(value);
}
export const defaultMinimap = (): Profile["minimap"] => ({transparency: 30, marker_style: "face", show_names: true});
export function normalizeNickname(value: unknown): string {
  if (typeof value !== "string" || /[\u0000-\u001f\u007f-\u009f\u2028\u2029]/u.test(value)) throw new ProfileError("invalid_nickname");
  const nickname = value.trim();
  if (Array.from(nickname).length < 1 || Array.from(nickname).length > 12) throw new ProfileError("invalid_nickname");
  return nickname;
}
export function migrateProfile(value: unknown): Profile {
  if (!object(value)) throw new ProfileError("invalid_profile");
  const next = structuredClone(value);
  if (next.schema_version === 2) {
    // Only the authored v2 shape can be upgraded; reject stray or malformed data.
    if (Object.keys(next).sort().join() !== ["schema_version", "first_granted", "characters", "accessories", "selected_character", "selected_accessory", "opponent_character", "accessibility"].sort().join()) throw new ProfileError("invalid_profile");
    next.schema_version = 3; next.nickname = "플레이어"; next.minimap = defaultMinimap();
  }
  validateProfile(next);
  return next;
}
export function validateProfile(value: unknown): asserts value is Profile {
  if (!object(value) || Object.keys(value).sort().join() !== ["schema_version", "first_granted", "characters", "accessories", "selected_character", "selected_accessory", "opponent_character", "accessibility", "nickname", "minimap"].sort().join()) throw new ProfileError("invalid_profile");
  if (value.schema_version !== 3 || typeof value.first_granted !== "boolean") throw new ProfileError("invalid_profile");
  for (const key of ["characters", "accessories"] as const) {
    const ids = value[key];
    if (!Array.isArray(ids) || ids.some(id => typeof id !== "string" || !catalog[key].includes(id)) || new Set(ids).size !== ids.length) throw new ProfileError("invalid_profile");
  }
  const characters = value.characters as string[], accessories = value.accessories as string[];
  if (typeof value.selected_character !== "string" || typeof value.selected_accessory !== "string" || typeof value.opponent_character !== "string" || !catalog.characters.includes(value.opponent_character)) throw new ProfileError("invalid_profile");
  if (value.first_granted ? !characters.includes(value.selected_character) : characters.length > 0 || accessories.length > 0 || value.selected_character !== "") throw new ProfileError("invalid_profile");
  if (value.selected_accessory !== "" && !accessories.includes(value.selected_accessory)) throw new ProfileError("invalid_profile");
  const a = value.accessibility;
  if (!object(a) || Object.keys(a).sort().join() !== ["text_scale", "reduce_visual_effects", "haptics_enabled"].sort().join() || ![1, 1.15, 1.3].includes(a.text_scale as number) || typeof a.reduce_visual_effects !== "boolean" || typeof a.haptics_enabled !== "boolean") throw new ProfileError("invalid_profile");
  if (normalizeNickname(value.nickname) !== value.nickname) throw new ProfileError("invalid_profile");
  const m = value.minimap;
  if (!object(m) || Object.keys(m).sort().join() !== ["transparency", "marker_style", "show_names"].sort().join() || !Number.isInteger(m.transparency) || (m.transparency as number) < 0 || (m.transparency as number) > 90 || !["face", "dot"].includes(m.marker_style as string) || typeof m.show_names !== "boolean") throw new ProfileError("invalid_profile");

}
export function applyAction(profile: Profile, action: unknown, payload: unknown): Profile {
  validateProfile(profile);
  if (!object(payload)) throw new ProfileError("invalid_action");
  const next = structuredClone(profile);
  switch (action) {
    case "grant_first":
      if (next.first_granted || typeof payload.id !== "string" || !catalog.characters.includes(payload.id)) throw new ProfileError("invalid_grant");
      next.first_granted = true; next.characters = [payload.id]; next.selected_character = payload.id;
      break;
    case "purchase": {
      if (!next.first_granted || typeof payload.id !== "string") throw new ProfileError("invalid_purchase");
      const kind = catalog.characters.includes(payload.id) ? "characters" : catalog.accessories.includes(payload.id) ? "accessories" : undefined;
      if (!kind || next[kind].includes(payload.id)) throw new ProfileError("invalid_purchase");
      next[kind].push(payload.id); break;
    }
    case "select":
      next.selected_character = payload.character as string; next.selected_accessory = payload.accessory as string; next.opponent_character = payload.opponent as string; break;
    case "identity":
      next.nickname = normalizeNickname(payload.nickname); break;
    case "minimap":
      next.minimap = payload as Profile["minimap"]; break;
    case "accessibility":
      next.accessibility = payload as Profile["accessibility"]; break;
    default: throw new ProfileError("unsupported_action");
  }
  validateProfile(next);
  return next;
}
function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (object(value)) return `{${Object.keys(value).sort().map(k => `${JSON.stringify(k)}:${canonical(value[k])}`).join(",")}}`;
  return JSON.stringify(value);
}
export class Profiles {
  constructor(readonly pool: pg.Pool) {}
  async get(playerId: string): Promise<SavedProfile | undefined> {
    const saved = (await this.pool.query<SavedProfile>("SELECT profile, revision FROM app.player_profiles WHERE player_id = $1", [playerId])).rows[0];
    if (!saved) return undefined;
    const migrated = migrateProfile(saved.profile);
    if ((saved.profile as {schema_version: number}).schema_version !== 3) {
      // Compare revision and schema so a simultaneous user change is never overwritten.
      await this.pool.query("UPDATE app.player_profiles SET profile = $2, updated_at = now() WHERE player_id = $1 AND revision = $3 AND profile->>'schema_version' = '2'", [playerId, migrated, saved.revision]);
      return this.get(playerId);
    }
    return {profile: migrated, revision: saved.revision};
  }
  async import(playerId: string, profile: unknown): Promise<SavedProfile> {
    profile = migrateProfile(profile);
    await this.pool.query("INSERT INTO app.player_profiles (player_id, profile) VALUES ($1, $2) ON CONFLICT DO NOTHING", [playerId, profile]);
    return (await this.get(playerId))!;
  }
  async action(playerId: string, input: Record<string, unknown>): Promise<SavedProfile> {
    if (typeof input.request_id !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(input.request_id) || !Number.isSafeInteger(input.expected_revision) || (input.expected_revision as number) < 1) throw new ProfileError("invalid_request");
    const hash = createHash("sha256").update(canonical(input)).digest("hex");
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const current = (await client.query<SavedProfile>("SELECT profile, revision FROM app.player_profiles WHERE player_id = $1 FOR UPDATE", [playerId])).rows[0];
      if (!current) throw new ProfileError("profile_missing", 404);
      const previous = (await client.query<{request_hash: string; response: SavedProfile}>("SELECT request_hash, response FROM app.profile_requests WHERE player_id = $1 AND request_id = $2", [playerId, input.request_id])).rows[0];
      if (previous) {
        if (previous.request_hash !== hash) throw new ProfileError("request_id_conflict", 409);
        await client.query("COMMIT"); return {...previous.response, profile: migrateProfile(previous.response.profile)};
      }
      if (current.revision !== input.expected_revision) throw new ProfileError("revision_conflict", 409);
      const response = { profile: applyAction(migrateProfile(current.profile), input.action, input.payload), revision: current.revision + 1 };
      await client.query("UPDATE app.player_profiles SET profile = $2, revision = $3, updated_at = now() WHERE player_id = $1", [playerId, response.profile, response.revision]);
      await client.query("INSERT INTO app.profile_requests (player_id, request_id, request_hash, response) VALUES ($1, $2, $3, $4)", [playerId, input.request_id, hash, response]);
      await client.query("COMMIT"); return response;
    } catch (error) { await client.query("ROLLBACK"); throw error; }
    finally { client.release(); }
  }
}
