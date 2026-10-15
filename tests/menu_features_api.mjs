// Independent, black-box ADR-033 checks. Run only against a dedicated QA DB/API.
// No credentials or access/refresh tokens are written to the report.
import assert from 'node:assert/strict';
import {isDeepStrictEqual} from 'node:util';
import {randomUUID, createHash} from 'node:crypto';
import {writeFileSync, mkdirSync} from 'node:fs';
import {dirname} from 'node:path';
import pg from '../server/api/node_modules/pg/lib/index.js';

const base = process.env.FOREST_ARENA_QA_API_URL;
const dbUrl = process.env.FOREST_ARENA_QA_DATABASE_URL;
const serviceToken = process.env.FOREST_ARENA_QA_SERVICE_TOKEN;
if (!base || !dbUrl || !serviceToken) throw new Error('Explicit QA API URL, QA DATABASE URL and QA service token are required.');
const parsedDb = new URL(dbUrl), parsedApi = new URL(base);
if (!/^forest_menu_qa_[a-z0-9_]+$/.test(parsedDb.pathname.slice(1))) throw new Error('Refusing a database without the forest_menu_qa_ prefix.');
if (!['127.0.0.1','localhost','[::1]'].includes(parsedApi.hostname)) throw new Error('QA API must be a loopback address.');
const pool = new pg.Pool({connectionString: dbUrl, max: 4});
const reportPath = process.env.FOREST_ARENA_QA_REPORT ?? '_workspace/premium-menu-features-v01/qa-api-report.json';
const report = {run_id: randomUUID(), started_at: new Date().toISOString(), database: parsedDb.pathname.slice(1), base_url: base, physical_device: 'not_run', cases: [], checks: []};
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
let serviceId = '';
function check(ok, name, actual) {
  report.checks.push({name, pass: Boolean(ok), ...(actual === undefined ? {} : {actual})});
  assert.ok(ok, name);
}
function rejected(status) { return status>=400 && status<500; }
function equal(actual, expected, name) {
  const ok = isDeepStrictEqual(actual, expected);
  check(ok, name, ok ? undefined : {actual, expected});
}
async function suite(name, fn) {
  const start = report.checks.length;
  try { await fn(); report.cases.push({name, status:'pass', checks:report.checks.length-start}); }
  catch (error) { report.cases.push({name, status:'fail', checks:report.checks.length-start, error: error instanceof assert.AssertionError ? error.message.split('\n')[0] : String(error?.message ?? error).replace(/eyJ[A-Za-z0-9_.-]+/g,'[redacted-token]')}); }
}
async function api(path, {method='GET', token='', body, internal=false}={}) {
  const response = await fetch(base+path, {method, signal: AbortSignal.timeout(15000), headers:{'Content-Type':'application/json', ...(token ? {Authorization:'Bearer '+token} : {}), ...(internal ? {'x-forest-arena-service-token':serviceToken} : {})}, ...(body===undefined?{}:{body:JSON.stringify(body)})});
  let data; try { data = await response.json(); } catch { data = {error:'non_json_response'}; }
  return {status: response.status, data};
}
function nickname(prefix='q') { return prefix+randomUUID().replaceAll('-','').slice(0,8); }
function profile(character='ja-hyun', accessory='fixture-iron-armor', name=nickname()) {
  return {schema_version:3, first_granted:true, characters:[character], accessories:accessory?[accessory]:[], selected_character:character, selected_accessory:accessory, opponent_character:'ja-hyun', accessibility:{text_scale:1,reduce_visual_effects:false,haptics_enabled:true}, nickname:name, minimap:{transparency:30,marker_style:'face',show_names:true}};
}
async function actor(character='ja-hyun', accessory='fixture-iron-armor') {
  const auth = await api('/v1/auth/guest',{method:'POST',body:{}});
  check(auth.status===201 && uuidPattern.test(auth.data.player_id) && typeof auth.data.access_token==='string','QA guest has valid credentials');
  const value = profile(character,accessory);
  const imported = await api('/v1/profile/import',{method:'POST',token:auth.data.access_token,body:{profile:value}});
  equal(imported.status,200,'QA profile import succeeds');
  const linked=await api('/v1/identity/merge',{method:'POST',token:auth.data.access_token,body:{request_id:randomUUID(),nickname:value.nickname,profile:value}});
  equal(linked.status,200,'QA actor registers unique service nickname');
  return {id:auth.data.player_id, token:auth.data.access_token, refresh:auth.data.refresh_token, profile:value};
}
function event(character='ja-hyun', outcome='win', mode='ai', endedAt=new Date(Date.now()-1000).toISOString()) {
  return {event_id:randomUUID(),mode,outcome,character_id:character,ended_at:endedAt};
}
async function offline(person, events) { return api('/v1/progress/offline',{method:'POST',token:person.token,body:{events}}); }
async function progress(person) { const r=await api('/v1/progress',{token:person.token}); equal(r.status,200,'Authenticated progress succeeds'); return r.data; }
async function identity(person) { const r=await api('/v1/identity',{token:person.token}); equal(r.status,200,'Authenticated identity succeeds'); return r.data; }
async function social(person, search) { const r=await api('/v1/social'+(search===undefined?'':'?search='+encodeURIComponent(search)),{token:person.token}); equal(r.status,200,'Authenticated social succeeds'); return r.data; }
async function action(person, body) { return api('/v1/social/action',{method:'POST',token:person.token,body:{operation_id:randomUUID(),...body}}); }
async function board(person, scope='all',page=0) { const r=await api(`/v1/leaderboard?scope=${scope}&page=${page}`,{token:person.token}); equal(r.status,200,'Authenticated leaderboard succeeds'); return r.data; }
async function befriend(a,b) {
  equal((await action(a,{action:'request',player_id:b.id})).status,200,'Friend request succeeds');
  const request=(await social(b)).incoming.find(r=>r.player_id===a.id);
  check(request && uuidPattern.test(request.request_id),'Recipient sees authentic pending request');
  equal((await action(b,{action:'accept',request_id:request.request_id})).status,200,'Recipient accepts friend request');
}
async function lan(a,b,{winner=a.id,reason='combat',matchId=randomUUID()}={}) {
  const registration={participants:[{player_id:a.id,slot:1,character_id:'ja-hyun',accessory_id:''},{player_id:b.id,slot:2,character_id:'myo-ryung',accessory_id:'fixture-boxing-gloves'}],room_code:'QA'+randomUUID().slice(0,6)};
  const result={reason,winner_player_id:winner,final_tick:420,snapshot_hash:createHash('sha256').update(matchId).digest('hex')};
  const register=await api(`/internal/v1/lan/matches/${matchId}/register`,{method:'POST',internal:true,body:registration});
  equal(register.status,200,'Service registers real LAN participants');
  const saved=await api(`/internal/v1/lan/matches/${matchId}/result`,{method:'POST',internal:true,body:result});
  equal(saved.status,200,'Service persists LAN result');
  return {matchId, registration,result};
}
function counters(part) { return {played:part.played,wins:part.wins,losses:part.losses,draws:part.draws}; }
function kstStart(now, kind) {
  const shifted=new Date(now.getTime()+9*3600000);
  let epoch=Date.UTC(shifted.getUTCFullYear(),shifted.getUTCMonth(),shifted.getUTCDate())-9*3600000;
  if(kind==='week') epoch-=((shifted.getUTCDay()+6)%7)*86400000;
  if(kind==='month') epoch=Date.UTC(shifted.getUTCFullYear(),shifted.getUTCMonth(),1)-9*3600000;
  return epoch;
}
try {
  await suite('AUTH-SERVICE-01',async()=>{
    const r=await api('/v1/service');equal(r.status,200,'Service discovery is public');check(uuidPattern.test(r.data.service_id),'Service ID is a UUID');equal(r.data.protocol_version,1,'Service protocol is v1');serviceId=r.data.service_id;
    const stored=(await pool.query('SELECT service_id FROM app.menu_service_identity WHERE singleton=true')).rows[0];equal(stored.service_id,serviceId,'Public service ID matches persistent DB singleton');
    for(const path of ['/v1/identity','/v1/progress','/v1/social','/v1/leaderboard']) equal((await api(path)).status,401,'Missing bearer rejected: '+path);
    for(const path of ['/v1/identity/merge','/v1/progress/offline','/v1/social/action','/v1/presence']) equal((await api(path,{method:'POST',body:{}})).status,401,'Unauthenticated mutation rejected: '+path);
  });
  await suite('OFFLINE-ATOMIC-DEDUP-TIME-02',async()=>{
    const a=await actor(), e=event();
    equal((await offline(a,[e])).status,200,'Offline event accepted');equal((await offline(a,[e])).status,200,'Exact offline replay accepted');
    equal(counters((await progress(a)).stats.offline),{played:1,wins:1,losses:0,draws:0},'Exact replay counts once');
    equal((await offline(a,[{...e,outcome:'loss'}])).status,409,'Same event ID with different payload conflicts');
    equal(counters((await progress(a)).stats.lan),{played:0,wins:0,losses:0,draws:0},'Offline event never increments LAN counters');check((await board(a)).own===null,'Offline event never creates rank');
    for(const invalid of [{...event(),mode:'lan'},{...event(),mode:'practice'},{...event(),mode:'story'},{...event(),character_id:'invented'},{...event(),ended_at:'2026-10-15'},{...event(),ended_at:'1999-12-31T23:59:59Z'},{...event(),ended_at:new Date(Date.now()+6*60000).toISOString()}]) equal((await offline(a,[invalid])).status,400,'Invalid offline source/catalog/time rejected');
    equal((await offline(a,[event('ja-hyun','draw','solo',new Date(Date.now()+4*60000).toISOString())])).status,200,'Future clock allowance below five minutes accepted');
    const b=await actor(), valid=event();equal((await offline(b,[valid,{...event(),outcome:'invented'}])).status,400,'Mixed invalid offline batch rejected');equal((await progress(b)).stats.offline.played,0,'Invalid batch applies no partial events');
    equal((await offline(b,Array.from({length:51},()=>event()))).status,400,'Offline batch over fifty rejected');
    const records=Array.from({length:50},(_,i)=>event('ja-hyun','win','team',new Date(Date.now()-(i+2)*1000).toISOString()));equal((await offline(b,records)).status,200,'Fifty offline events accepted');equal((await offline(b,[event()])).status,200,'Later offline event accepted');const p=await progress(b);equal(p.history.length,50,'History is latest fifty entries');check(p.history.every(r=>r.source==='offline'),'Offline history source is explicit');check(p.history.every((r,i,all)=>!i||Date.parse(all[i-1].ended_at)>=Date.parse(r.ended_at)),'History is newest first');
  });
  await suite('MISSION-KST-BOUNDARIES-03',async()=>{
    const a=await actor(), now=new Date(), day=kstStart(now,'day'), week=kstStart(now,'week');
    equal((await offline(a,[event('ja-hyun','win','ai',new Date(day-1).toISOString()),event('myo-ryung','win','ai',new Date(day).toISOString())])).status,200,'Events on both sides of KST midnight accepted');
    let p=await progress(a);const daily=p.missions.filter(m=>m.category==='daily');equal(daily.length,2,'Two daily missions defined');check(daily.every(m=>m.current===1&&m.target===1&&m.completed===true),'Daily missions count only current KST day');
    const b=await actor();await offline(b,[event('ja-hyun','win','ai',new Date(week-1).toISOString()),event('ja-hyun','win','ai',new Date(week).toISOString())]);p=await progress(b);const weekly=p.missions.filter(m=>m.category==='weekly');equal(weekly.map(m=>m.target).sort((x,y)=>x-y),[3,5],'Weekly targets are three wins/five completions');check(weekly.every(m=>m.current===1&&!m.completed),'Weekly missions count only since KST Monday');
    const c=await actor();await offline(c,['ja-hyun','myo-ryung','nabi','yu-ran'].map(id=>event(id)));p=await progress(c);const achievements=p.missions.filter(m=>m.category==='achievements');equal(achievements.map(m=>m.target).sort((x,y)=>x-y),[1,4,10],'Achievement targets are first/ten/four characters');check(achievements.find(m=>m.target===4)?.completed,'Four actual characters complete distinct-character mission');check(!JSON.stringify(p).match(/"(?:reward|currency|experience)"/),'Progress contains no reward/economy fields');
  });
  await suite('LAN-SERVICE-REPLAY-EXCLUSIONS-04',async()=>{
    const a=await actor(), b=await actor('myo-ryung'), unknown=await actor('nabi'), matchId=randomUUID();
    equal((await api(`/internal/v1/lan/matches/${matchId}/result`,{method:'POST',token:a.token,body:{}})).status,401,'Player bearer cannot submit internal LAN result');
    check(rejected((await api(`/internal/v1/lan/matches/${matchId}/result`,{method:'POST',internal:true,body:{reason:'combat',winner_player_id:a.id,final_tick:1,snapshot_hash:'0'.repeat(64)}})).status),'Result before registration rejected');
    const r=await lan(a,b);equal((await api(`/internal/v1/lan/matches/${r.matchId}/register`,{method:'POST',internal:true,body:r.registration})).status,200,'Exact LAN registration replay accepted');equal((await api(`/internal/v1/lan/matches/${r.matchId}/result`,{method:'POST',internal:true,body:r.result})).status,200,'Exact LAN result replay accepted');equal((await api(`/internal/v1/lan/matches/${r.matchId}/result`,{method:'POST',internal:true,body:{...r.result,final_tick:421}})).status,409,'Conflicting result replay rejected');
    equal(counters((await progress(a)).stats.lan),{played:1,wins:1,losses:0,draws:0},'LAN winner counted once');equal(counters((await progress(b)).stats.lan),{played:1,wins:0,losses:1,draws:0},'LAN loser counted once');equal((await progress(a)).stats.offline.played,0,'LAN does not enter offline stats');
    await lan(a,b,{winner:null,reason:'draw'});await lan(a,b,{winner:a.id,reason:'disconnect'});await lan(a,b,{winner:null,reason:'abandoned'});equal(counters((await progress(a)).stats.lan),{played:2,wins:1,losses:0,draws:1},'Disconnect and abandonment are excluded from normal stats');
    const own=(await board(a)).own;check(own?.played===2&&own.wins===1&&own.draws===1,'Only normal LAN results appear in rank');check(!(await board(unknown)).own,'Zero-match user has no rank');
    const recent=(await social(a)).recent;equal(recent.filter(r=>r.player_id===b.id).length,1,'Repeated opponent appears once in recent list');
  });
  await suite('IDENTITY-MERGE-REPLAY-STALE-TOKEN-05',async()=>{
    const a=await actor(), b=await actor('myo-ryung','fixture-boxing-gloves');const ea=event('ja-hyun','loss'),eb=event('myo-ryung','win');await offline(a,[ea]);await offline(b,[eb]);
    const originalRows=(await pool.query('SELECT player_id,profile FROM app.player_profiles WHERE player_id=ANY($1::uuid[]) ORDER BY player_id',[[a.id,b.id]])).rows;
    const local=profile('nabi','fixture-phoenix-revive');local.accessibility={text_scale:1.3,reduce_visual_effects:true,haptics_enabled:false};local.minimap={transparency:55,marker_style:'dot',show_names:false};const body={request_id:randomUUID(),source_access_token:b.token,nickname:nickname('m'),profile:local};
    const merged=await api('/v1/identity/merge',{method:'POST',token:a.token,body});equal(merged.status,200,'Two proved owners can merge');const p=merged.data.profile;equal([...p.characters].sort(),['ja-hyun','myo-ryung','nabi'].sort(),'Merge unions server and device characters');equal([...p.accessories].sort(),['fixture-iron-armor','fixture-boxing-gloves','fixture-phoenix-revive'].sort(),'Merge unions accessories');equal(p.selected_character,'nabi','Merge preserves active device character');equal(p.selected_accessory,'fixture-phoenix-revive','Merge preserves active accessory');equal(p.accessibility,local.accessibility,'Merge preserves accessibility');equal(p.minimap,local.minimap,'Merge preserves minimap');equal(p.nickname,body.nickname,'Merge uses final chosen nickname');
    const replay=await api('/v1/identity/merge',{method:'POST',token:a.token,body});equal(replay.status,200,'Lost merge response can replay exact intent');equal(replay.data.revision,merged.data.revision,'Merge replay does not increment profile revision');equal((await api('/v1/identity/merge',{method:'POST',token:a.token,body:{...body,nickname:nickname('x')}})).status,409,'Changed merge intent cannot reuse request ID');
    const ia=await identity(a), ib=await identity(b);equal(ia.canonical_player_id,a.id,'Target remains canonical');equal(ib.canonical_player_id,a.id,'Old source access token resolves canonical');equal(ib.service_id,serviceId,'Unified identity stays in same service');const rotated=await api('/v1/auth/refresh',{method:'POST',body:{refresh_token:b.refresh}});equal(rotated.status,200,'Old source refresh survives merge');equal(rotated.data.player_id,b.id,'Refresh preserves original token owner ID');equal((await identity({...b,token:rotated.data.access_token})).canonical_player_id,a.id,'Refreshed old owner still resolves canonical');
    equal(counters((await progress(a)).stats.offline),{played:2,wins:1,losses:1,draws:0},'Canonical progress combines distinct original events');await offline(b,[eb]);equal((await progress(a)).stats.offline.played,2,'Old-owner offline replay after merge does not duplicate');
    const retained=(await pool.query('SELECT player_id FROM app.player_profiles WHERE player_id=ANY($1::uuid[]) ORDER BY player_id',[[a.id,b.id]])).rows;equal(retained.map(r=>r.player_id),originalRows.map(r=>r.player_id),'Merge preserves both original profile rows');
    const bad=await api('/v1/identity/merge',{method:'POST',token:a.token,body:{...body,request_id:randomUUID(),source_access_token:'forged.access.token'}});check(bad.status===409 && bad.data.error==='source_authentication_required','Forged source ownership proof rejected');
  });
  await suite('CANONICAL-SELF-HISTORIC-LAN-06',async()=>{
    const a=await actor(), b=await actor('myo-ryung');await lan(a,b);equal((await progress(a)).stats.lan.played,1,'Pre-merge distinct participants count normally');
    equal((await api('/v1/identity/merge',{method:'POST',token:a.token,body:{request_id:randomUUID(),source_access_token:b.token,nickname:nickname('s'),profile:a.profile}})).status,200,'Historical opponents can unify ownership');equal((await progress(a)).stats.lan.played,0,'Historical canonical-self match is excluded after merge');check((await board(a)).own===null,'Historical canonical-self match has no rank');check((await social(a)).recent.every(r=>r.player_id!==a.id&&r.player_id!==b.id),'Historical self is suppressed from recent opponents');
    equal((await pool.query('SELECT count(*)::int AS n FROM app.menu_lan_participants WHERE player_id=ANY($1::uuid[])',[[a.id,b.id]])).rows[0].n,2,'Raw participants remain preserved despite exclusion');
  });
  await suite('SOCIAL-OWNERSHIP-REPLAY-INVITE-07',async()=>{
    const a=await actor(), b=await actor('myo-ryung'), c=await actor('nabi');const request={action:'request',player_id:b.id,operation_id:randomUUID()};equal((await action(a,request)).status,200,'Friend request with operation ID accepted');equal((await action(a,request)).status,200,'Friend operation exact replay succeeds');equal((await action(a,{...request,player_id:c.id})).status,409,'Social operation payload conflict rejected');
    const incoming=(await social(b)).incoming;equal(incoming.filter(r=>r.player_id===a.id).length,1,'Request replay does not duplicate pending request');const req=incoming.find(r=>r.player_id===a.id);check(req,'Pending request exists');check(rejected((await action(c,{action:'accept',request_id:req.request_id})).status),'Third party cannot accept another user request');check(rejected((await action(b,{action:'request',player_id:a.id})).status),'Reverse request does not silently auto-accept');equal((await social(a)).friends.length,0,'Reverse request has not created friendship');
    equal((await action(b,{action:'accept',request_id:req.request_id})).status,200,'Actual recipient accepts');equal((await social(a)).friends.filter(r=>r.player_id===b.id).length,1,'Mutual friend displayed once');check(rejected((await action(a,{action:'request',player_id:a.id})).status),'Self friend request rejected');
    await api('/v1/presence',{method:'POST',token:b.token,body:{state:'online'}});check((await social(a)).friends.find(r=>r.player_id===b.id)?.online,'Recent explicit heartbeat shows online');await pool.query("UPDATE app.menu_presence SET last_seen=now()-interval '91 seconds' WHERE player_id=$1",[b.id]);check(!(await social(a)).friends.find(r=>r.player_id===b.id)?.online,'Presence expires after ninety seconds');
    const room='Q'+randomUUID().slice(0,7),code='qa-invite-'+randomUUID();equal((await api('/internal/v1/lan/rooms',{method:'POST',internal:true,body:{room_code:room,host_player_id:a.id,invite_code:code,state:'waiting',updated_at:new Date().toISOString()}})).status,200,'Service registers genuine waiting room');
    check(rejected((await action(b,{action:'invite',player_id:a.id,invite_code:code})).status),'Non-host cannot invite using another host room');equal((await action(a,{action:'invite',player_id:b.id,invite_code:code})).status,200,'Waiting room owner invites mutual friend');let invite=(await social(b)).invites.find(r=>r.player_id===a.id);check(invite,'Recipient sees real room invitation');check(rejected((await action(c,{action:'accept_invite',invite_id:invite.invite_id})).status),'Third party cannot accept another player invitation');
    equal((await api('/internal/v1/lan/rooms',{method:'POST',internal:true,body:{room_code:room,host_player_id:a.id,invite_code:code,state:'closed',updated_at:new Date().toISOString()}})).status,200,'Service closes waiting room');check(rejected((await action(b,{action:'accept_invite',invite_id:invite.invite_id})).status),'Closed room invitation cannot be accepted');
    const found=await social(a,b.profile.nickname);check(found.search.some(r=>r.player_id===b.id),'Exact nickname search returns actual player');check((await social(a,"' OR 1=1 --")).search.length===0,'Search string is not executable SQL');
  });
  await suite('RANK-TIES-MONTH-FRIENDS-PAGE-08',async()=>{
    const a=await actor(),b=await actor('myo-ryung'),c=await actor('nabi'),opponent=await actor('yu-ran');await lan(a,opponent);await lan(a,opponent);await lan(b,opponent);await lan(b,opponent);await lan(c,opponent);
    const all=await board(a);const ra=all.entries.find(r=>r.player_id===a.id),rb=all.entries.find(r=>r.player_id===b.id),rc=all.entries.find(r=>r.player_id===c.id);check(ra&&rb&&rc,'Rank fixture users appear');equal(ra.rank,rb.rank,'Equal wins and win rate share rank');check(rc.rank>=ra.rank+2,'Competition rank skips tied positions');
    await befriend(a,c);const friends=await board(a,'friends');check(friends.entries.every(r=>[a.id,c.id].includes(r.player_id)),'Friends scope contains current mutual friends plus self only');check(friends.own?.player_id===a.id,'Own entry remains available in selected scope');
    const monthActor=await actor(),other=await actor('myo-ryung');const last=await lan(monthActor,other),current=await lan(monthActor,other);const boundary=kstStart(new Date(),'month');await pool.query('UPDATE app.menu_lan_matches SET ended_at=$2 WHERE match_id=$1',[last.matchId,new Date(boundary-1)]);await pool.query('UPDATE app.menu_lan_matches SET ended_at=$2 WHERE match_id=$1',[current.matchId,new Date(boundary)]);equal((await board(monthActor,'all')).own.wins,2,'All-time scope retains both month-edge wins');equal((await board(monthActor,'month')).own.wins,1,'Monthly scope begins at KST first-day midnight');
    check(all.entries.length<=50,'Rank page never exceeds fifty');equal((await api('/v1/leaderboard?scope=all&page=-1',{token:a.token})).status,400,'Negative rank page rejected');equal((await api('/v1/leaderboard?scope=invented&page=0',{token:a.token})).status,400,'Unknown rank scope rejected');
  });
  await suite('SOCIAL-ALIAS-EXPIRY-RESTORE-09',async()=>{
    const a=await actor(), b=await actor('myo-ryung'), c=await actor('nabi');
    await befriend(a,c);await befriend(b,c);await befriend(a,b);
    const merged=await api('/v1/identity/merge',{method:'POST',token:a.token,body:{request_id:randomUUID(),source_access_token:b.token,nickname:nickname('u'),profile:a.profile}});equal(merged.status,200,'Friends with overlapping relations merge');
    const visible=await social(c);equal(visible.friends.filter(r=>r.player_id===a.id).length,1,'Common friend sees one canonical relation');check(visible.friends.every(r=>r.player_id!==b.id),'Merged source ID disappears from friend display');
    const owner=await social(a);equal(owner.friends.length,1,'Friendship between merged identities is suppressed');check(owner.friends.every(r=>r.player_id!==a.id),'No canonical self friend displayed');
    const empty=profile();Object.assign(empty,{first_granted:false,characters:[],accessories:[],selected_character:'',selected_accessory:''});
    const fresh=await api('/v1/identity/merge',{method:'POST',token:a.token,body:{request_id:randomUUID(),nickname:nickname('n'),profile:empty}});equal(fresh.status,200,'Empty pre-grant local profile can merge existing server inventory');check(fresh.data.profile.characters.includes(fresh.data.profile.selected_character),'Server fallback selection remains owned and nonempty');
    const code='qa-'+randomUUID(),room='Q'+randomUUID().slice(0,7);const heartbeat=new Date().toISOString();
    const put=async(state,updated_at)=>api('/internal/v1/lan/rooms',{method:'POST',internal:true,body:{room_code:room,host_player_id:a.id,invite_code:code,state,updated_at}});
    equal((await put('waiting',heartbeat)).status,200,'Current waiting heartbeat accepted');
    equal((await action(a,{action:'invite',player_id:c.id,invite_code:code})).status,200,'Canonical owner can invite mutual friend');
    let invite=(await social(c)).invites.find(r=>r.player_id===a.id);check(invite,'Live invitation present');
    await pool.query('UPDATE app.menu_invites SET expires_at=now() WHERE invite_id=$1',[invite.invite_id]);
    check(rejected((await action(c,{action:'accept_invite',invite_id:invite.invite_id})).status),'Invitation expires at exact database now boundary');
    await pool.query("UPDATE app.menu_lan_rooms SET updated_at=now()-interval '91 seconds' WHERE invite_code=$1",[code]);
    check(rejected((await action(a,{action:'invite',player_id:c.id,invite_code:code})).status),'Stale room heartbeat cannot create fresh invitation');
    equal((await put('closed',new Date().toISOString())).status,200,'Fresh closed state recorded');
    await put('waiting',heartbeat);
    check(rejected((await action(a,{action:'invite',player_id:c.id,invite_code:code})).status),'Delayed old waiting replay cannot resurrect closed room');
    equal((await action(a,{action:'remove',player_id:c.id})).status,200,'Mutual friend removal succeeds');
    equal((await social(c)).friends.length,0,'Removal visible to other side');
    await befriend(a,c);equal((await social(c)).friends.length,1,'Removed relation can be requested and accepted again');
  });
  await suite('RANK-ACTUAL-PAGINATION-10',async()=>{
    const loser=await actor('yu-ran');const winners=[];
    for(let i=0;i<51;i++){const w=await actor();winners.push(w);await lan(w,loser);}
    const first=await board(winners[0],'all',0),second=await board(winners[0],'all',1);
    equal(first.entries.length,50,'More than fifty actual ranked players produces full first page');check(first.has_more && second.entries.length>0,'Actual second page is available');
    const ids=new Set(first.entries.map(r=>r.player_id));check(second.entries.every(r=>!ids.has(r.player_id)),'Rank pages contain no duplicate canonical identity');
    equal(first.own,second.own,'Own rank is independent of requested page');
    const rankRows=[...first.entries,...second.entries];check(winners.every(w=>rankRows.some(r=>r.player_id===w.id)),'All fifty-one fixture winners occur across real pages');
    check(rankRows.every((r,i)=>!i||rankRows[i-1].wins>=r.wins),'Actual pages preserve descending wins');
  });
} finally {
  await pool.end();report.finished_at=new Date().toISOString();report.status=report.cases.every(c=>c.status==='pass')?'pass':'fail';mkdirSync(dirname(reportPath),{recursive:true});writeFileSync(reportPath,JSON.stringify(report,null,2)+'\n');console.log('MENU_FEATURES_INDEPENDENT_API: '+report.status.toUpperCase()+` (${report.cases.length} suites, ${report.checks.length} checks)`);process.exitCode=report.status==='pass'?0:1;
}
