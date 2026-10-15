import { createHash } from "node:crypto";
import type pg from "pg";
import { migrateProfile, validateProfile, type Profile, ProfileError } from "./profiles.js";
import { normalizeNickname } from "./demo_guests.js";
import { verifyToken } from "./tokens.js";

export const uuid = (value: unknown): value is string => typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
export function stable(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stable).join(",")}]`;
  if (value && typeof value === "object") return `{${Object.keys(value).sort().map(k => `${JSON.stringify(k)}:${stable((value as Record<string,unknown>)[k])}`).join(",")}}`;
  return JSON.stringify(value);
}
export const fingerprint = (value: unknown): string => createHash("sha256").update(stable(value)).digest("hex");
export async function canonicalId(db: Pick<pg.Pool,"query"> | pg.PoolClient, id: string): Promise<string> {
  if (!uuid(id)) throw new ProfileError("unauthorized",401);
  const row = (await db.query<{id:string}>("SELECT COALESCE(canonical_player_id,player_id) AS id FROM app.players WHERE player_id=$1",[id])).rows[0];
  if (!row) throw new ProfileError("unauthorized",401);
  return row.id;
}
export async function locked<T>(pool: pg.Pool, work: (db: pg.PoolClient)=>Promise<T>): Promise<T> {
  const db = await pool.connect();
  try { await db.query("BEGIN"); await db.query("SELECT pg_advisory_xact_lock(hashtext('forest_menu_identity'))"); const result=await work(db); await db.query("COMMIT"); return result; }
  catch(e) { await db.query("ROLLBACK"); throw e; } finally { db.release(); }
}
export class Identities {
  constructor(readonly pool:pg.Pool, readonly tokenSecret:string) {}
  async service(db: Pick<pg.Pool,"query"> | pg.PoolClient=this.pool) {
    return {...(await db.query<{service_id:string}>("SELECT service_id FROM app.menu_service_identity WHERE singleton")).rows[0]!,protocol_version:1};
  }
  async get(actor:string) {
    const id=await canonicalId(this.pool,actor);
    const row=(await this.pool.query("SELECT nickname FROM app.players WHERE player_id=$1",[id])).rows[0];
    return {player_id:actor,canonical_player_id:id,nickname:row.nickname,service_id:(await this.service()).service_id};
  }
  async merge(actor:string,input:Record<string,unknown>) {
    if (!uuid(input.request_id)) throw new ProfileError("invalid_request");
    const hash=fingerprint(input);
    return locked(this.pool, async db=>{
      const target=await canonicalId(db,actor);
      const replay=(await db.query("SELECT request_hash,response FROM app.identity_merge_requests WHERE actor_id=$1 AND request_id=$2",[actor,input.request_id])).rows[0];
      // Exact durable retry may carry an expired source token. The live target bearer still authenticates the caller.
      if(replay) { if(replay.request_hash!==hash) throw new ProfileError("request_id_conflict",409); return replay.response; }
      const nickname=normalizeNickname(input.nickname);
      const current=migrateProfile(input.profile);
      let source=target;let sourceActor:string|null=null;
      if(input.source_access_token!==undefined) {
        try {
          if(typeof input.source_access_token!=="string")throw new Error("invalid_source_token");
          sourceActor=verifyToken(input.source_access_token,this.tokenSecret,"access").sub;
          source=await canonicalId(db,sourceActor);
        } catch {throw new ProfileError("source_authentication_required",409);}
      }
      const originals=(await db.query("SELECT p.player_id,p.nickname,f.profile,f.revision FROM app.players p LEFT JOIN app.player_profiles f USING(player_id) WHERE p.player_id=ANY($1::uuid[])",[[target,source]])).rows;
      const merged:Profile=structuredClone(current);
      for(const row of originals) if(row.profile) {
        const profile=migrateProfile(row.profile);
        merged.characters=[...new Set([...merged.characters,...profile.characters])];
        merged.accessories=[...new Set([...merged.accessories,...profile.accessories])];
      }
      if(merged.characters.length && !current.first_granted) {
        const fallback=originals.map(r=>r.profile?migrateProfile(r.profile):null).find(p=>p?.first_granted);
        if(!fallback)throw new ProfileError("current_selection_required",409);
        merged.first_granted=true;merged.selected_character=fallback.selected_character;merged.selected_accessory=fallback.selected_accessory;
      }
      merged.nickname=nickname; validateProfile(merged);
      if(source!==target) await db.query("UPDATE app.players SET canonical_player_id=$1 WHERE player_id=$2 OR canonical_player_id=$2",[target,source]);
      try { await db.query("UPDATE app.players SET nickname=$2 WHERE player_id=$1",[target,nickname]); }
      catch(e) { if((e as {code?:string}).code==="23505") throw new ProfileError("nickname_taken",409); throw e; }
      const saved=(await db.query("INSERT INTO app.player_profiles(player_id,profile) VALUES($1,$2) ON CONFLICT(player_id) DO UPDATE SET profile=EXCLUDED.profile,revision=app.player_profiles.revision+1,updated_at=now() RETURNING profile,revision",[target,merged])).rows[0];
      const response={player_id:actor,canonical_player_id:target,nickname,service_id:(await this.service(db)).service_id,...saved};
      await db.query("INSERT INTO app.identity_merge_requests(actor_id,request_id,request_hash,response,source_player_id,originals) VALUES($1,$2,$3,$4,$5,$6)",[actor,input.request_id,hash,response,sourceActor,JSON.stringify(originals)]);
      return response;
    });
  }
}
