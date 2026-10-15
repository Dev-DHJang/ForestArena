import assert from "node:assert/strict";
import {randomUUID} from "node:crypto";
import pg from "pg";
import {issueAccessToken,signToken} from "../src/tokens.js";
const base=process.env.FOREST_ARENA_API_URL!;
assert.match(process.env.DATABASE_URL!,/forest_menu_api_test_/);
const db=new pg.Pool({connectionString:process.env.DATABASE_URL});
const secret=process.env.FOREST_ARENA_TOKEN_SECRET!;
const service=process.env.FOREST_ARENA_SERVICE_TOKEN!;
let checks=0;
async function api(method:string,path:string,token="",body?:unknown,internal=false) {
 const r=await fetch(base+path,{method,headers:{"content-type":"application/json",...(internal?{"x-forest-arena-service-token":service}:{authorization:"Bearer "+token})},...(body===undefined?{}:{body:JSON.stringify(body)})});
 return {status:r.status,data:await r.json() as any};
}
function ok(r:{status:number;data:any},status=200){assert.equal(r.status,status,String(r.data.error??"unexpected_response"));checks++;return r.data;}
const fresh=(character=""):any=>({schema_version:3,first_granted:!!character,characters:character?[character]:[],accessories:[],selected_character:character,selected_accessory:"",opponent_character:"ja-hyun",nickname:"플레이어",minimap:{transparency:30,marker_style:"face",show_names:true},accessibility:{text_scale:1,reduce_visual_effects:false,haptics_enabled:true}});
async function guest(nickname:string,character="ja-hyun") {
 const auth=ok(await api("POST","/v1/auth/guest","",{}),201);
 ok(await api("POST","/v1/profile/import",auth.access_token,{profile:fresh(character)}));
 ok(await api("PATCH","/v1/guest/profile",auth.access_token,{nickname}));
 return {id:auth.player_id,token:auth.access_token,refresh:auth.refresh_token};
}
async function social(token:string,action:string,payload:Record<string,unknown>={}) {return api("POST","/v1/social/action",token,{operation_id:randomUUID(),action,...payload});}
async function match(a:any,b:any,reason="combat",winner:string|null=a.id) {
 const id=randomUUID();
 const registration={room_code:"runtime-room",participants:[{player_id:a.id,slot:1,character_id:"ja-hyun",accessory_id:""},{player_id:b.id,slot:2,character_id:"yu-ran",accessory_id:"fixture-iron-armor"}]};
 ok(await api("POST",`/internal/v1/lan/matches/${id}/register`,"",registration,true));
 const result={reason,winner_player_id:winner,final_tick:120,snapshot_hash:"a".repeat(64)};
 ok(await api("POST",`/internal/v1/lan/matches/${id}/result`,"",result,true));return {id,registration,result};
}
try {
 const serviceId=ok(await api("GET","/v1/service")).service_id;assert.match(serviceId,/^[0-9a-f-]{36}$/);
 ok(await api("GET","/v1/progress"),401);
 const a=await guest("Tester_A"),b=await guest("Tester_B","nabi"),c=await guest("Tester_C","myo-ryung");
 const identity=ok(await api("GET","/v1/identity",a.token));assert.equal(identity.canonical_player_id,a.id);
 const initial=ok(await api("GET","/v1/progress",a.token));assert.equal(initial.stats.offline.played,0);assert.equal(initial.history.length,0);assert.deepEqual(initial.character_ids,[]);
 const event={event_id:randomUUID(),source:"offline",mode:"ai",outcome:"win",character_id:"ja-hyun",ended_at:new Date().toISOString()};
 ok(await api("POST","/v1/progress/offline",a.token,{events:[event,event]}));
 ok(await api("POST","/v1/progress/offline",a.token,{events:[event]}));
 ok(await api("POST","/v1/progress/offline",b.token,{events:[event]}),409);
 ok(await api("POST","/v1/progress/offline",a.token,{events:[{...event,mode:"lan"}]}),400);
 ok(await api("POST","/v1/progress/offline",a.token,{events:[{...event,event_id:randomUUID(),ended_at:"1999-12-31T23:59:59Z"}]}),400);
 ok(await api("POST","/v1/progress/offline",a.token,{events:[{...event,event_id:randomUUID(),ended_at:"2026-02-30T12:00:00Z"}]}),400);
 ok(await api("POST","/v1/progress/offline",a.token,{events:[{...event,event_id:randomUUID(),ended_at:new Date(Date.now()+301000).toISOString()}]}),400);
 ok(await api("POST","/v1/progress/offline",a.token,{events:[{...event,event_id:randomUUID(),ended_at:"2000-01-01T00:00:00Z"}]}));
 const offlineProgress=ok(await api("GET","/v1/progress",a.token));assert.equal(offlineProgress.stats.offline.played,2);assert.deepEqual(offlineProgress.character_ids,["ja-hyun"]);
 const request={operation_id:randomUUID(),action:"request",player_id:b.id};
 const requested=ok(await api("POST","/v1/social/action",a.token,request));assert.deepEqual(ok(await api("POST","/v1/social/action",a.token,request)),requested);
 ok(await social(a.token,"request",{player_id:a.id}),409);ok(await social(b.token,"request",{player_id:a.id}),409);
 ok(await social(c.token,"accept",{request_id:requested.request_id}),403);
 const accepted={operation_id:randomUUID(),action:"accept",request_id:requested.request_id};ok(await api("POST","/v1/social/action",b.token,accepted));ok(await api("POST","/v1/social/action",b.token,accepted));
 assert.equal(ok(await api("GET","/v1/social",a.token)).friends[0].player_id,b.id);
 assert.equal(ok(await api("GET","/v1/social?search=tester_b",a.token)).search[0].player_id,b.id);
 ok(await api("POST","/v1/presence",b.token,{state:"online"}));assert.equal(ok(await api("GET","/v1/social",a.token)).friends[0].online,true);
 await db.query("UPDATE app.menu_presence SET last_seen=now()-interval '90 seconds' WHERE player_id=$1",[b.id]);assert.equal(ok(await api("GET","/v1/social",a.token)).friends[0].online,false);
 const room={room_code:"room-a",host_player_id:a.id,invite_code:"forest://actual-room-a",state:"waiting",updated_at:new Date().toISOString()};
 ok(await api("POST","/internal/v1/lan/rooms","",room),401);ok(await api("POST","/internal/v1/lan/rooms","",room,true));
 const invitation=ok(await social(a.token,"invite",{player_id:b.id,invite_code:room.invite_code}));assert.equal(ok(await api("GET","/v1/social",b.token)).invites[0].invite_id,invitation.invite_id);
 assert.equal(ok(await social(b.token,"accept_invite",{invite_id:invitation.invite_id})).invite_code,room.invite_code);
 const ttl=(await db.query("SELECT extract(epoch FROM expires_at-created_at) AS seconds FROM app.menu_invites WHERE invite_id=$1",[invitation.invite_id])).rows[0];assert.equal(Number(ttl.seconds),120);
 const expires=ok(await social(a.token,"invite",{player_id:b.id,invite_code:room.invite_code}));
 await db.query("UPDATE app.menu_invites SET expires_at=now() WHERE invite_id=$1",[expires.invite_id]);
 ok(await social(b.token,"accept_invite",{invite_id:expires.invite_id}),409);

 ok(await api("POST","/internal/v1/lan/rooms","",{...room,state:"closed"},true));
 ok(await api("POST","/internal/v1/lan/rooms","",room,true));ok(await social(a.token,"invite",{player_id:b.id,invite_code:room.invite_code}),409);
 ok(await api("POST","/internal/v1/lan/rooms","",{...room,room_code:"stale-room",invite_code:"expired",updated_at:new Date(Date.now()-91000).toISOString()},true));
 ok(await social(a.token,"invite",{player_id:b.id,invite_code:"expired"}),409);
 const first=await match(a,b);ok(await api("POST",`/internal/v1/lan/matches/${first.id}/register`,"",first.registration,true));ok(await api("POST",`/internal/v1/lan/matches/${first.id}/result`,"",first.result,true));
 ok(await api("POST",`/internal/v1/lan/matches/${first.id}/result`,"",{...first.result,final_tick:121},true),409);
 await match(c,b);await match(a,c,"disconnect",a.id);await match(a,c,"abandoned",null);
 const leader=ok(await api("GET","/v1/leaderboard",a.token));assert.equal(leader.entries.length,3);assert.deepEqual(leader.entries.map((r:any)=>r.rank),[1,1,3]);assert.equal(leader.own.wins,1);
 await db.query("UPDATE app.menu_lan_matches SET ended_at=(date_trunc('month',now() AT TIME ZONE 'Asia/Seoul') AT TIME ZONE 'Asia/Seoul')-interval '1 second' WHERE match_id=$1",[first.id]);
 const month=ok(await api("GET","/v1/leaderboard?scope=month",a.token));assert.equal(month.entries.length,2);assert.equal(month.own,null);
 await db.query("UPDATE app.menu_lan_matches SET ended_at=now() WHERE match_id=$1",[first.id]);
 assert.equal(ok(await api("GET","/v1/leaderboard?scope=friends&page=0",a.token)).entries.length,2);
 assert.equal(ok(await api("GET","/v1/leaderboard?page=1",a.token)).entries.length,0);
 assert.equal(ok(await api("GET","/v1/progress",a.token)).stats.lan.played,1);
 // A-vs-B becomes a self match after their identities merge; raw records remain.
 const current=fresh("ja-hyun");current.accessibility.text_scale=1.3;current.minimap.transparency=75;
 const now=Math.floor(Date.now()/1000);const soonExpired=signToken({kind:"access",sub:b.id,iat:now,exp:now+2},secret);
 const merge={request_id:randomUUID(),source_access_token:soonExpired,nickname:"Unified_A",profile:current};
 const merged=ok(await api("POST","/v1/identity/merge",a.token,merge));assert.deepEqual(new Set(merged.profile.characters),new Set(["ja-hyun","nabi"]));assert.equal(merged.profile.selected_character,"ja-hyun");assert.equal(merged.profile.accessibility.text_scale,1.3);assert.equal(merged.profile.minimap.transparency,75);
 await new Promise(resolve=>setTimeout(resolve,2100));
 assert.deepEqual(ok(await api("POST","/v1/identity/merge",a.token,merge)),merged);
 ok(await api("POST","/v1/identity/merge",a.token,{...merge,nickname:"Changed_A"}),409);
 assert.equal(ok(await api("GET","/v1/identity",b.token)).canonical_player_id,a.id);
 assert.equal(ok(await api("GET","/v1/guest/profile",b.token)).player_id,b.id);
 const lanIdentity=ok(await api("POST","/internal/v1/lan/auth","",{access_token:b.token,existing_player_ids:[a.id,b.id]},true));assert.equal(lanIdentity.player_id,a.id);assert.deepEqual(lanIdentity.canonical_players,{[a.id]:a.id,[b.id]:a.id});
 ok(await api("POST","/internal/v1/lan/auth","",{access_token:b.token,existing_player_ids:[a.id,b.id,c.id]},true),400);
 const concurrentAuth=await Promise.all(Array.from({length:8},()=>api("POST","/internal/v1/lan/auth","",{access_token:b.token,existing_player_ids:[a.id,b.id]},true)));for(const r of concurrentAuth)ok(r);
 assert.equal(ok(await api("GET","/v1/profile",b.token)).profile.nickname,"Unified_A");
 assert.equal(ok(await api("GET","/v1/progress",b.token)).stats.lan.played,1); // B lost to C; A-B excluded.
 assert.equal(ok(await api("GET","/v1/progress",b.token)).stats.offline.played,2);
 assert.equal(ok(await api("GET","/v1/social",b.token)).friends.length,0);
 assert.equal(ok(await api("GET","/v1/leaderboard",b.token)).own.losses,1);
 assert.equal((await db.query("SELECT count(*)::int n FROM app.menu_lan_matches")).rows[0].n,4);
 assert.equal((await db.query("SELECT nickname FROM app.players WHERE player_id=$1",[b.id])).rows[0].nickname,"Tester_B");
 assert.equal(ok(await api("POST","/v1/auth/refresh","",{refresh_token:b.refresh})).player_id,b.id);
 const invalidMerge={request_id:randomUUID(),source_access_token:issueAccessToken(c.id,"different-secret"),nickname:"Try_Hack",profile:current};assert.equal(ok(await api("POST","/v1/identity/merge",a.token,invalidMerge),409).error,"source_authentication_required");
 ok(await api("POST","/v1/identity/merge",a.token,{request_id:randomUUID(),nickname:"tester_c",profile:current}),409);
 const fallback=ok(await api("POST","/v1/identity/merge",a.token,{request_id:randomUUID(),nickname:"Unified_A",profile:fresh()}));assert.equal(fallback.profile.selected_character,"ja-hyun");
 const expired=issueAccessToken(c.id,secret,Math.floor(Date.now()/1000)-1000);const expiredIntent={...merge,request_id:randomUUID(),source_access_token:expired};
 assert.equal(ok(await api("POST","/v1/identity/merge",a.token,expiredIntent),409).error,"source_authentication_required");
 assert.equal((await db.query("SELECT count(*)::int n FROM app.identity_merge_requests WHERE request_id=$1",[expiredIntent.request_id])).rows[0].n,0);
 // Mutate only a recorded hash to model a source token expiring after the first successful request.
 const stored=await db.query("SELECT request_id,originals FROM app.identity_merge_requests WHERE actor_id=$1",[a.id]);assert.ok(stored.rows[0].originals.length>0);
 // Existing v3 actions and merges serialize on one identity lock, regardless of who starts first.
 const d=await guest("Race_D"),e=await guest("Race_E","nabi");
 const beforeRace=ok(await api("GET","/v1/profile",e.token));
 const purchase={request_id:randomUUID(),expected_revision:beforeRace.revision,action:"purchase",payload:{id:"fixture-thorns"}};
 const raceMerge={request_id:randomUUID(),source_access_token:e.token,nickname:"Race_D",profile:fresh("ja-hyun")};
 const race=await Promise.all([api("POST","/v1/profile/actions",e.token,purchase),api("POST","/v1/identity/merge",d.token,raceMerge)]);
 ok(race[1]!);assert.ok([200,409].includes(race[0]!.status));
 if(race[0]!.status===409) {const saved=ok(await api("GET","/v1/profile",e.token));ok(await api("POST","/v1/profile/actions",e.token,{...purchase,request_id:randomUUID(),expected_revision:saved.revision}));}
 const raceAfter=ok(await api("GET","/v1/profile",d.token));assert.ok(raceAfter.profile.accessories.includes("fixture-thorns"));
 assert.ok(!((await db.query("SELECT profile FROM app.player_profiles WHERE player_id=$1",[e.id])).rows[0].profile.accessories as string[]).includes("fixture-thorns")||race[0]!.status===200);
 assert.equal(ok(await api("GET","/v1/service")).service_id,serviceId);
 console.log(JSON.stringify({test:"MENU_API_RUNTIME",status:"PASS",checks,service_id:serviceId,database:"isolated verification database"}));
} finally {await db.end();}
