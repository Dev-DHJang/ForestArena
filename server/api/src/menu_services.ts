import { randomUUID } from "node:crypto";
import type pg from "pg";
import { readFileSync } from "node:fs";
import { canonicalId, fingerprint, locked, uuid } from "./identities.js";
import { ProfileError } from "./profiles.js";
const catalog=JSON.parse(readFileSync(new URL("./profile_catalog.json",import.meta.url),"utf8")) as {characters:string[];accessories:string[]};
function failure(code:string,status=400):never {throw new ProfileError(code,status);}
const date=(value:unknown):string=>{
 if(typeof value!=="string"||!/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?Z$/.test(value)||!Number.isFinite(Date.parse(value))) return failure("invalid_timestamp");
 const parsed=new Date(value).toISOString();if(parsed.slice(0,19)!==value.slice(0,19))return failure("invalid_timestamp");return parsed;
};
export type GameEvent={source:"offline"|"lan";mode:string;outcome:string;character_id:string;ended_at:string;match_id:string};
export function periods(now=new Date()) {
 const kst=new Date(now.getTime()+9*3600000); const daily=kst.toISOString().slice(0,10);
 const monday=new Date(Date.UTC(kst.getUTCFullYear(),kst.getUTCMonth(),kst.getUTCDate()-((kst.getUTCDay()+6)%7)));
 return {daily,weekly:monday.toISOString().slice(0,10),month:daily.slice(0,7)};
}
export function aggregateProgress(events:GameEvent[],now=new Date()) {
 const p=periods(now); const stats:any={offline:{played:0,wins:0,losses:0,draws:0},lan:{played:0,wins:0,losses:0,draws:0},modes:{}};
 for(const mode of ["ai","solo","team","lan"]) stats.modes[mode]={played:0,wins:0,losses:0,draws:0};
 for(const e of events) for(const row of [stats[e.source],stats.modes[e.mode]]) {row.played++;row[e.outcome==="win"?"wins":e.outcome==="loss"?"losses":"draws"]++;}
 const daily=events.filter(e=>periods(new Date(e.ended_at)).daily===p.daily);
 const weekly=events.filter(e=>periods(new Date(e.ended_at)).weekly===p.weekly);
 const mission=(id:string,category:string,title:string,current:number,target:number,period:string)=>({id,category,title,current,target,completed:current>=target,period});
 const missions=[mission("daily-play","daily","대전 1회 완료",daily.length,1,p.daily),mission("daily-win","daily","대전 1승",daily.filter(e=>e.outcome==="win").length,1,p.daily),mission("weekly-play","weekly","대전 5회 완료",weekly.length,5,p.weekly),mission("weekly-win","weekly","대전 3승",weekly.filter(e=>e.outcome==="win").length,3,p.weekly),mission("first-play","achievements","첫 대전 완료",events.length,1,"all"),mission("ten-play","achievements","대전 10회 완료",events.length,10,"all"),mission("all-characters","achievements","네 캐릭터로 대전 완료",new Set(events.map(e=>e.character_id)).size,4,"all")];
 return {missions,stats,character_ids:[...new Set(events.map(e=>e.character_id))].sort(),history:events.slice().sort((a,b)=>b.ended_at.localeCompare(a.ended_at)||a.match_id.localeCompare(b.match_id)).slice(0,50),sync_status:"synced"};
}
export class MenuServices {
 constructor(readonly pool:pg.Pool) {}
 async offline(actor:string,input:Record<string,unknown>) {
  if(!Array.isArray(input.events)||input.events.length>50) failure("invalid_events");
  const events=input.events as Record<string,unknown>[];
  for(const e of events) if(!e||(e.source!==undefined&&e.source!=="offline")||!uuid(e.event_id)||!["ai","solo","team"].includes(String(e.mode))||!["win","loss","draw"].includes(String(e.outcome))||!catalog.characters.includes(String(e.character_id))) failure("invalid_event");
  return locked(this.pool,async db=>{
   const id=await canonicalId(db,actor);const accepted:string[]=[];
   for(const e of events) {
    const ended=date(e.ended_at);if(Date.parse(ended)>Date.now()+300000||Date.parse(ended)<Date.UTC(2000,0,1)) failure("invalid_event_time");
    const hash=fingerprint({...e,ended_at:ended});
    const previous=(await db.query("SELECT e.*,COALESCE(p.canonical_player_id,p.player_id) AS owner FROM app.menu_offline_events e JOIN app.players p USING(player_id) WHERE event_id=$1",[e.event_id])).rows[0];
    if(previous) {if(previous.owner!==id||previous.payload_hash!==hash) failure("event_id_conflict",409);}
    else await db.query("INSERT INTO app.menu_offline_events(event_id,player_id,mode,outcome,character_id,ended_at,payload_hash) VALUES($1,$2,$3,$4,$5,$6,$7)",[e.event_id,actor,e.mode,e.outcome,e.character_id,ended,hash]);
    accepted.push(e.event_id as string);
   }
   return {accepted:[...new Set(accepted)],source:"offline",sync_status:"synced"};
  });
 }
 async events(actor:string,db:Pick<pg.Pool,"query">|pg.PoolClient=this.pool):Promise<GameEvent[]> {
  const id=await canonicalId(db,actor);
  const offline=(await db.query("SELECT 'offline' AS source,mode,outcome,character_id,ended_at,event_id AS match_id FROM app.menu_offline_events e JOIN app.players p USING(player_id) WHERE COALESCE(p.canonical_player_id,p.player_id)=$1",[id])).rows;
  const lan=(await db.query(`SELECT 'lan' AS source,'lan' AS mode, CASE WHEN m.result_reason='draw' THEN 'draw' WHEN COALESCE(w.canonical_player_id,w.player_id)=$1 THEN 'win' ELSE 'loss' END AS outcome,a.character_id,m.ended_at,m.match_id
    FROM app.menu_lan_matches m JOIN app.menu_lan_participants a USING(match_id) JOIN app.players p ON p.player_id=a.player_id
    JOIN app.menu_lan_participants b ON b.match_id=m.match_id AND b.slot<>a.slot JOIN app.players q ON q.player_id=b.player_id
    LEFT JOIN app.players w ON w.player_id=m.winner_player_id
    WHERE COALESCE(p.canonical_player_id,p.player_id)=$1 AND COALESCE(q.canonical_player_id,q.player_id)<>$1 AND m.result_reason IN ('combat','draw') AND m.ended_at IS NOT NULL`,[id])).rows;
  return [...offline,...lan].map(e=>({...e,ended_at:new Date(e.ended_at).toISOString()})) as GameEvent[];
 }
 async progress(actor:string) {return locked(this.pool,async db=>aggregateProgress(await this.events(actor,db)));}
 async friends(db:Pick<pg.Pool,"query">|pg.PoolClient,id:string):Promise<string[]> {
  return (await db.query(`SELECT DISTINCT CASE WHEN COALESCE(a.canonical_player_id,a.player_id)=$1 THEN COALESCE(b.canonical_player_id,b.player_id) ELSE COALESCE(a.canonical_player_id,a.player_id) END AS id
   FROM app.menu_friendships f JOIN app.players a ON a.player_id=f.first_player_id JOIN app.players b ON b.player_id=f.second_player_id WHERE f.removed_at IS NULL
   AND (COALESCE(a.canonical_player_id,a.player_id)=$1 OR COALESCE(b.canonical_player_id,b.player_id)=$1) AND COALESCE(a.canonical_player_id,a.player_id)<>COALESCE(b.canonical_player_id,b.player_id)`,[id])).rows.map(r=>r.id);
 }
 async presence(actor:string,input:Record<string,unknown>) {
  if(!["online","offline"].includes(String(input.state))) failure("invalid_presence");
  return locked(this.pool,async db=>{const id=await canonicalId(db,actor);await db.query("INSERT INTO app.menu_presence(player_id,state) VALUES($1,$2) ON CONFLICT(player_id) DO UPDATE SET state=$2,last_seen=now()",[id,input.state]);return {status:"ok"};});
 }
 async people(db:Pick<pg.Pool,"query">|pg.PoolClient,ids:string[]) {
  if(!ids.length)return [];
  return (await db.query(`SELECT p.player_id,p.nickname,COALESCE(s.online,false) AS online,s.last_seen FROM app.players p
    LEFT JOIN LATERAL (SELECT bool_or(state='online' AND last_seen>now()-interval '90 seconds') AS online,max(last_seen) AS last_seen FROM app.menu_presence presence JOIN app.players alias ON alias.player_id=presence.player_id WHERE COALESCE(alias.canonical_player_id,alias.player_id)=p.player_id) s ON true
    WHERE p.player_id=ANY($1::uuid[]) ORDER BY lower(p.nickname),p.player_id`,[ids])).rows;
 }
 async social(actor:string,search:string|null) {
  const id=await canonicalId(this.pool,actor);const friends=await this.people(this.pool,await this.friends(this.pool,id));
  const requests=(await this.pool.query(`SELECT r.request_id,COALESCE(a.canonical_player_id,a.player_id) AS from_id,COALESCE(b.canonical_player_id,b.player_id) AS to_id FROM app.menu_friend_requests r
    JOIN app.players a ON a.player_id=r.from_player_id JOIN app.players b ON b.player_id=r.to_player_id WHERE r.state='pending' AND (COALESCE(a.canonical_player_id,a.player_id)=$1 OR COALESCE(b.canonical_player_id,b.player_id)=$1)
    AND COALESCE(a.canonical_player_id,a.player_id)<>COALESCE(b.canonical_player_id,b.player_id) ORDER BY r.created_at`,[id])).rows;
  const decorate=async(r:any,other:string)=>({request_id:r.request_id,...(await this.people(this.pool,[other]))[0]});
  const dedup=(rows:any[])=>[...new Map(rows.filter(r=>!friends.some(f=>f.player_id===r.player_id)).map(r=>[r.player_id,r])).values()];
  const incoming=dedup(await Promise.all(requests.filter(r=>r.to_id===id).map(r=>decorate(r,r.from_id))));
  const outgoing=dedup(await Promise.all(requests.filter(r=>r.from_id===id).map(r=>decorate(r,r.to_id))));
  const recent=(await this.pool.query(`SELECT p.player_id,p.nickname,MAX(m.ended_at) AS ended_at FROM app.menu_lan_matches m
    JOIN app.menu_lan_participants a USING(match_id) JOIN app.players own ON own.player_id=a.player_id JOIN app.menu_lan_participants b ON b.match_id=m.match_id AND b.slot<>a.slot
    JOIN app.players other ON other.player_id=b.player_id JOIN app.players p ON p.player_id=COALESCE(other.canonical_player_id,other.player_id)
    WHERE COALESCE(own.canonical_player_id,own.player_id)=$1 AND p.player_id<>$1 AND m.ended_at IS NOT NULL GROUP BY p.player_id ORDER BY ended_at DESC,p.player_id LIMIT 20`,[id])).rows;
  const invites=(await this.pool.query(`SELECT i.invite_id,p.player_id,p.nickname,i.invite_code,i.expires_at FROM app.menu_invites i JOIN app.players original ON original.player_id=i.from_player_id
    JOIN app.players recipient ON recipient.player_id=i.to_player_id JOIN app.players p ON p.player_id=COALESCE(original.canonical_player_id,original.player_id)
    JOIN app.menu_lan_rooms r ON r.room_code=i.room_code AND r.invite_code=i.invite_code WHERE i.state='pending' AND COALESCE(recipient.canonical_player_id,recipient.player_id)=$1
    AND p.player_id<>$1 AND i.expires_at>now() AND r.state='waiting' AND r.updated_at>now()-interval '90 seconds'`,[id])).rows;
  const found=search?(await this.pool.query("SELECT player_id,nickname FROM app.players WHERE canonical_player_id IS NULL AND lower(nickname)=lower($1) AND player_id<>$2",[search,id])).rows:[];
  return {friends,incoming,outgoing,recent,invites:[...new Map(invites.map(r=>[r.player_id+":"+r.invite_code,r])).values()],search:found};
 }
 async socialAction(actor:string,input:Record<string,unknown>) {
  const action=String(input.action);
  if(!["request","accept","reject","cancel","remove","invite","accept_invite","reject_invite"].includes(action)) failure("invalid_action");
  if(!uuid(input.operation_id))failure("operation_id_required");
  for(const key of ["player_id","request_id","invite_id"]) if(input[key]!==undefined&&!uuid(input[key])) failure("invalid_request");
  return locked(this.pool,async db=>{
   const id=await canonicalId(db,actor);const key=String(input.operation_id);const hash=fingerprint(input);
   if(key) {const replay=(await db.query("SELECT o.* FROM app.menu_social_operations o JOIN app.players p ON p.player_id=o.actor_id WHERE COALESCE(p.canonical_player_id,p.player_id)=$1 AND operation_key=$2",[id,key])).rows[0];if(replay){if(replay.request_hash!==hash)failure("request_id_conflict",409);return replay.response;}}
   const target=input.player_id?await canonicalId(db,String(input.player_id)):null;
   if(target===id) failure("self_action",409);
   let response:any={status:"ok"};
   const friendIds=await this.friends(db,id);
   if(action==="request") {
    if(!target)failure("player_required");if(friendIds.includes(target))failure("already_friends",409);
    const pending=(await db.query(`SELECT 1 FROM app.menu_friend_requests r JOIN app.players a ON a.player_id=r.from_player_id JOIN app.players b ON b.player_id=r.to_player_id
     WHERE r.state='pending' AND ((COALESCE(a.canonical_player_id,a.player_id)=$1 AND COALESCE(b.canonical_player_id,b.player_id)=$2) OR (COALESCE(a.canonical_player_id,a.player_id)=$2 AND COALESCE(b.canonical_player_id,b.player_id)=$1))`,[id,target])).rowCount;
    if(pending)failure("request_pending",409);const requestId=input.request_id??randomUUID();
    await db.query("INSERT INTO app.menu_friend_requests(request_id,from_player_id,to_player_id,state) VALUES($1,$2,$3,'pending')",[requestId,id,target]);response={status:"ok",request_id:requestId};
   } else if(["accept","reject","cancel"].includes(action)) {
    if(!uuid(input.request_id))failure("request_required");
    const r=(await db.query("SELECT * FROM app.menu_friend_requests WHERE request_id=$1 FOR UPDATE",[input.request_id])).rows[0];
    if(!r||r.state!=="pending")failure("stale_request",409);
    const from=await canonicalId(db,r.from_player_id),to=await canonicalId(db,r.to_player_id);
    if(from===to)failure("self_action",409);if((action==="cancel"?from:to)!==id)failure("forbidden",403);
    if(action==="accept") {if(friendIds.includes(from))failure("already_friends",409);const pair=[from,to].sort();await db.query("INSERT INTO app.menu_friendships(first_player_id,second_player_id) VALUES($1,$2) ON CONFLICT(first_player_id,second_player_id) DO UPDATE SET removed_at=NULL",pair);}
    await db.query("UPDATE app.menu_friend_requests SET state=$2,updated_at=now() WHERE request_id=$1",[input.request_id,action==="accept"?"accepted":action==="reject"?"rejected":"cancelled"]);
   } else if(action==="remove") {
    if(!target||!friendIds.includes(target))failure("not_friends",409);
    await db.query(`UPDATE app.menu_friendships f SET removed_at=now() FROM app.players a,app.players b WHERE a.player_id=f.first_player_id AND b.player_id=f.second_player_id
     AND ((COALESCE(a.canonical_player_id,a.player_id)=$1 AND COALESCE(b.canonical_player_id,b.player_id)=$2) OR (COALESCE(a.canonical_player_id,a.player_id)=$2 AND COALESCE(b.canonical_player_id,b.player_id)=$1))`,[id,target]);
   } else if(action==="invite") {
    if(!target||!friendIds.includes(target)||typeof input.invite_code!=="string")failure("invalid_invite");
    const room=(await db.query(`SELECT r.* FROM app.menu_lan_rooms r JOIN app.players p ON p.player_id=r.host_player_id WHERE r.invite_code=$2 AND COALESCE(p.canonical_player_id,p.player_id)=$1 AND r.state='waiting' AND r.updated_at>now()-interval '90 seconds'`,[id,input.invite_code])).rows[0];
    if(!room)failure("room_not_waiting",409);
    const pending=(await db.query(`SELECT 1 FROM app.menu_invites i JOIN app.players p ON p.player_id=i.to_player_id WHERE COALESCE(p.canonical_player_id,p.player_id)=$1 AND i.invite_code=$2 AND i.state='pending' AND i.expires_at>now()`,[target,input.invite_code])).rowCount;
    if(pending)failure("invite_pending",409);const inviteId=input.invite_id??randomUUID();
    await db.query("INSERT INTO app.menu_invites(invite_id,from_player_id,to_player_id,room_code,invite_code,state,expires_at) VALUES($1,$2,$3,$4,$5,'pending',now()+interval '120 seconds')",[inviteId,id,target,room.room_code,input.invite_code]);response={status:"ok",invite_id:inviteId};
   } else {
    if(!uuid(input.invite_id))failure("invite_required");const i=(await db.query("SELECT *,expires_at<=now() AS expired FROM app.menu_invites WHERE invite_id=$1 FOR UPDATE",[input.invite_id])).rows[0];
    if(!i||i.state!=="pending"||i.expired)failure("stale_invite",409);
    if(await canonicalId(db,i.to_player_id)!==id)failure("forbidden",403);
    const room=(await db.query("SELECT 1 FROM app.menu_lan_rooms WHERE room_code=$1 AND invite_code=$2 AND state='waiting' AND updated_at>now()-interval '90 seconds'",[i.room_code,i.invite_code])).rowCount;
    if(!room)failure("room_not_waiting",409);
    await db.query("UPDATE app.menu_invites SET state=$2 WHERE invite_id=$1",[input.invite_id,action==="accept_invite"?"accepted":"rejected"]);
    if(action==="accept_invite")response.invite_code=i.invite_code;
   }
   if(key)await db.query("INSERT INTO app.menu_social_operations(actor_id,operation_key,request_hash,response) VALUES($1,$2,$3,$4)",[actor,key,hash,response]);
   return response;
  });
 }
 async room(input:Record<string,unknown>) {
  if(typeof input.room_code!=="string"||input.room_code.length<1||input.room_code.length>128||typeof input.invite_code!=="string"||input.invite_code.length<1||input.invite_code.length>2048||!uuid(input.host_player_id)||!["waiting","closed"].includes(String(input.state)))failure("invalid_room");
  const updated=date(input.updated_at);if(Date.parse(updated)>Date.now()+30000)failure("invalid_room_time");
  return locked(this.pool,async db=>{
   const host=await canonicalId(db,String(input.host_player_id));
   const old=(await db.query("SELECT * FROM app.menu_lan_rooms WHERE room_code=$1 AND invite_code=$2 FOR UPDATE",[input.room_code,input.invite_code])).rows[0];
   if(old&&await canonicalId(db,old.host_player_id)!==host)failure("room_owner_conflict",409);
   if(old&&(new Date(old.updated_at).getTime()>Date.parse(updated)||(new Date(old.updated_at).getTime()===Date.parse(updated)&&(old.state==="closed"||input.state!=="closed"))))return {status:"duplicate"};
   if(input.state==="waiting"&&Date.parse(updated)<=Date.now()-90000)return {status:"expired"};
   await db.query("INSERT INTO app.menu_lan_rooms(room_code,host_player_id,invite_code,state,updated_at) VALUES($1,$2,$3,$4,$5) ON CONFLICT(room_code,invite_code) DO UPDATE SET state=$4,updated_at=$5",[input.room_code,input.host_player_id,input.invite_code,input.state,updated]);
   return {status:"stored"};
  });
 }
 async register(matchId:string,input:Record<string,unknown>) {
  if(!uuid(matchId)||!Array.isArray(input.participants)||input.participants.length!==2||typeof input.room_code!=="string")failure("invalid_match");
  const parts=input.participants as Record<string,unknown>[];
  for(const p of parts)if(!p||!uuid(p.player_id)||![1,2].includes(Number(p.slot))||!Number.isInteger(p.slot)||!catalog.characters.includes(String(p.character_id))||!(p.accessory_id===""||catalog.accessories.includes(String(p.accessory_id))))failure("invalid_participant");
  if(new Set(parts.map(p=>p.slot)).size!==2||new Set(parts.map(p=>p.player_id)).size!==2)failure("invalid_participant");
  const hash=fingerprint({...input,participants:parts.slice().sort((a,b)=>Number(a.slot)-Number(b.slot))});
  return locked(this.pool,async db=>{
   for(const p of parts)await canonicalId(db,String(p.player_id));
   const old=(await db.query("SELECT registration_hash FROM app.menu_lan_matches WHERE match_id=$1 FOR UPDATE",[matchId])).rows[0];
   if(old){if(old.registration_hash!==hash)failure("match_id_conflict",409);return {status:"duplicate"};}
   await db.query("INSERT INTO app.menu_lan_matches(match_id,room_code,registration_hash) VALUES($1,$2,$3)",[matchId,input.room_code,hash]);
   for(const p of parts)await db.query("INSERT INTO app.menu_lan_participants(match_id,player_id,slot,character_id,accessory_id) VALUES($1,$2,$3,$4,$5)",[matchId,p.player_id,p.slot,p.character_id,p.accessory_id]);
   return {status:"stored"};
  });
 }
 async result(matchId:string,input:Record<string,unknown>) {
  const {reason,winner_player_id:winner,final_tick:tick,snapshot_hash:hash}=input;
  if(!uuid(matchId)||!["combat","draw","disconnect","abandoned"].includes(String(reason))||!(winner===null||uuid(winner))||!Number.isSafeInteger(tick)||Number(tick)<0||typeof hash!=="string"||!/^[0-9a-f]{64}$/.test(hash))failure("invalid_result");
  if((reason==="combat"&&winner===null)||(reason==="draw"&&winner!==null))failure("invalid_winner");
  const requestHash=fingerprint(input);
  return locked(this.pool,async db=>{
   const match=(await db.query("SELECT * FROM app.menu_lan_matches WHERE match_id=$1 FOR UPDATE",[matchId])).rows[0];if(!match)failure("match_not_found",404);
   if(match.result_hash){if(match.result_hash!==requestHash)failure("result_conflict",409);return {status:"duplicate"};}
   const parts=(await db.query("SELECT player_id FROM app.menu_lan_participants WHERE match_id=$1",[matchId])).rows;
   if(winner!==null&&!parts.some(p=>p.player_id===winner))failure("winner_not_participant");
   await db.query("UPDATE app.menu_lan_matches SET result_reason=$2,winner_player_id=$3,final_tick=$4,snapshot_hash=$5,result_hash=$6,ended_at=now() WHERE match_id=$1",[matchId,reason,winner,tick,hash,requestHash]);
   // Mission and profile totals are derived from this committed result, so no partial aggregate can escape.
   return {status:"stored"};
  });
 }
 async leaderboard(actor:string,scope:string,page:number) {
  if(!["all","month","friends"].includes(scope)||!Number.isSafeInteger(page)||page<0||page>100000)failure("invalid_leaderboard");
  const id=await canonicalId(this.pool,actor);const friendIds=scope==="friends"?[id,...await this.friends(this.pool,id)]:[];
  const rows=(await this.pool.query(`WITH games AS (
    SELECT COALESCE(p.canonical_player_id,p.player_id) AS player_id,m.match_id,m.result_reason,COALESCE(w.canonical_player_id,w.player_id) AS winner
    FROM app.menu_lan_matches m JOIN app.menu_lan_participants a USING(match_id) JOIN app.players p ON p.player_id=a.player_id
    JOIN app.menu_lan_participants b ON b.match_id=m.match_id AND b.slot<>a.slot JOIN app.players q ON q.player_id=b.player_id LEFT JOIN app.players w ON w.player_id=m.winner_player_id
    WHERE m.result_reason IN ('combat','draw') AND m.ended_at IS NOT NULL AND COALESCE(p.canonical_player_id,p.player_id)<>COALESCE(q.canonical_player_id,q.player_id)
    AND ($1<>'month' OR date_trunc('month',m.ended_at AT TIME ZONE 'Asia/Seoul')=date_trunc('month',now() AT TIME ZONE 'Asia/Seoul'))
    AND ($1<>'friends' OR COALESCE(p.canonical_player_id,p.player_id)=ANY($2::uuid[]))
   ), totals AS (
    SELECT player_id,count(*)::int AS played,count(*) FILTER(WHERE result_reason='combat' AND winner=player_id)::int AS wins,
     count(*) FILTER(WHERE result_reason='combat' AND winner<>player_id)::int AS losses,count(*) FILTER(WHERE result_reason='draw')::int AS draws FROM games GROUP BY player_id
   ), ranked AS (
    SELECT (rank() OVER(ORDER BY wins DESC,wins::numeric/played DESC))::int AS rank,t.*,p.nickname,wins::float/played AS win_rate FROM totals t JOIN app.players p USING(player_id)
   ) SELECT * FROM ranked ORDER BY rank,player_id`,[scope,friendIds])).rows;
  return {entries:rows.slice(page*50,page*50+50),own:rows.find(r=>r.player_id===id)??null,page,has_more:rows.length>(page+1)*50};
 }
}
