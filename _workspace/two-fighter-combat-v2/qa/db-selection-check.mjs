// Run only against the temporary DB created by run-isolated-db.py.
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {randomUUID} from 'node:crypto';
import {writeFileSync} from 'node:fs';
const require = createRequire(process.cwd() + '/server/api/package.json');
const {Pool} = require('pg');
assert.match(process.env.DATABASE_URL, /\/forest_menu_qa_/);
const db = new Pool({connectionString:process.env.FOREST_ARENA_QA_ADMIN_DATABASE_URL});
const checks = [];
const observations = [];
async function request(method,path,token='',body) {
  const response = await fetch(process.env.FOREST_ARENA_API_URL+path,{method,headers:{'content-type':'application/json',authorization:'Bearer '+token},...(body===undefined?{}:{body:JSON.stringify(body)})});
  return {status:response.status,data:await response.json()};
}
async function guest() {const result=await request('POST','/v1/auth/guest','',{}); assert.equal(result.status,201); return result.data;}
function legacy(characters=['myo-ryung','yu-ran','nabi']) {
  return {schema_version:3,first_granted:true,characters,accessories:['fixture-iron-armor','fixture-phoenix-revive'],selected_character:'myo-ryung',selected_accessory:'fixture-iron-armor',opponent_character:'yu-ran',nickname:'과거보유',minimap:{transparency:65,marker_style:'dot',show_names:false},accessibility:{text_scale:1.3,reduce_visual_effects:true,haptics_enabled:false}};
}
async function seed(auth,profile) {await db.query('INSERT INTO app.player_profiles(player_id,profile) VALUES($1,$2)',[auth.player_id,profile]);}
async function row(auth) {return (await db.query('SELECT profile,revision,updated_at FROM app.player_profiles WHERE player_id=$1',[auth.player_id])).rows[0];}
function normalized(value,character) {const next=structuredClone(value);next.selected_character=character;next.selected_accessory='';next.opponent_character='ja-hyun';if(!next.characters.includes(character))next.characters.push(character);return next;}
function check(label,fn) {fn();checks.push({name:label,pass:true}); console.log('PASS '+label);}
try {
  const auth=await guest(), before=legacy(); await seed(auth,before);
  const get=await request('GET','/v1/profile',auth.access_token), saved=await row(auth);
  check('GET normalizes inactive selection, retains all archived ownership and settings',()=>{assert.equal(get.status,200);assert.deepEqual(get.data.profile,normalized(before,'nabi'));assert.deepEqual(saved.profile,get.data.profile);assert.equal(saved.revision,1);});
  const repeated=await request('GET','/v1/profile',auth.access_token), repeatedRow=await row(auth);
  check('repeated GET does not rewrite an already normalized row',()=>{assert.deepEqual(repeated.data,get.data);assert.equal(repeatedRow.updated_at.toISOString(),saved.updated_at.toISOString());});
  const fallback=await guest(), oldOnly=legacy(['myo-ryung','yu-ran']);await seed(fallback,oldOnly);
  const fallbackGet=await request('GET','/v1/profile',fallback.access_token);
  check('inactive-only ownership receives ja-hyun without deleting archived records',()=>{assert.equal(fallbackGet.status,200);assert.deepEqual(fallbackGet.data.profile,normalized(oldOnly,'ja-hyun'));});
  const importedAuth=await guest();
  const imported=await request('POST','/v1/profile/import',importedAuth.access_token,{profile:before});
  check('new import response equals committed normalized SQL row',()=>{assert.equal(imported.status,200);assert.deepEqual(imported.data.profile,normalized(before,'nabi'));});
  assert.deepEqual((await row(importedAuth)).profile,imported.data.profile);
  const existing=await guest();await seed(existing,oldOnly);
  const existingImport=await request('POST','/v1/profile/import',existing.access_token,{profile:before});
  check('import into an existing archived row commits its own normalization',()=>{assert.equal(existingImport.status,200);assert.deepEqual(existingImport.data.profile,normalized(oldOnly,'ja-hyun'));});
  assert.deepEqual((await row(existing)).profile,existingImport.data.profile);
  for(const [action,payload] of [['purchase',{id:'myo-ryung'}],['purchase',{id:'fixture-iron-armor'}],['select',{character:'myo-ryung',accessory:'',opponent:'nabi'}],['select',{character:'nabi',accessory:'fixture-iron-armor',opponent:'ja-hyun'}]]) {
    const denied=await request('POST','/v1/profile/actions',auth.access_token,{request_id:randomUUID(),expected_revision:1,action,payload});
    check('reject inactive new '+action+' '+JSON.stringify(payload),()=>assert.equal(denied.status,400));
  }
  check('rejected actions preserve the committed profile and revision',()=>{});
  assert.deepEqual(await row(auth),saved);
  const fault=await guest();await seed(fault,before);
  await db.query(`CREATE FUNCTION app.qa_reject_normalization() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF OLD.player_id='${fault.player_id}'::uuid THEN RAISE EXCEPTION 'owned QA forced write failure'; END IF; RETURN NEW; END $$`);
  await db.query('CREATE TRIGGER qa_reject_normalization BEFORE UPDATE ON app.player_profiles FOR EACH ROW EXECUTE FUNCTION app.qa_reject_normalization()');
  for(const method of ['GET','POST']) {
    const failed=await request(method,method==='GET'?'/v1/profile':'/v1/profile/import',fault.access_token,method==='POST'?{profile:before}:undefined);
    check(method+' normalization never reports success after forced SQL UPDATE failure',()=>{assert.equal(failed.status,500);assert.equal(failed.data.error,'internal_error');});
    assert.deepEqual((await row(fault)).profile,before);
  }
  await db.query('DROP TRIGGER qa_reject_normalization ON app.player_profiles');
  await db.query('DROP FUNCTION app.qa_reject_normalization()');
  const recovered=await request('GET','/v1/profile',fault.access_token);
  check('normalization recovers and commits after the owned failure trigger is removed',()=>{assert.equal(recovered.status,200);assert.deepEqual(recovered.data.profile,normalized(before,'nabi'));});
  for(const [label,value] of [['get-normalized',auth],['free-fallback',fallback],['new-import',importedAuth],['existing-import',existing],['write-failure-recovered',fault]]) observations.push({label,...await row(value)});
  console.log('TWO_FIGHTER_DB_SELECTION: PASS ('+checks.length+' checks)');
} finally {
  writeFileSync('_workspace/two-fighter-combat-v2/qa/db-selection-report.json',JSON.stringify({checks,observations,physical_device:'not_run'},null,2)+'\n');
  await db.end();
}
