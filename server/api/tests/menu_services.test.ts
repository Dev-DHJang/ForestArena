import test from "node:test";
import assert from "node:assert/strict";
import {aggregateProgress,periods,type GameEvent} from "../src/menu_services.js";
import {fingerprint} from "../src/identities.js";
test("KST day Monday week and month boundaries",()=>{
 assert.deepEqual(periods(new Date("2026-10-18T14:59:59Z")),{daily:"2026-10-18",weekly:"2026-10-12",month:"2026-10"});
 assert.deepEqual(periods(new Date("2026-10-18T15:00:00Z")),{daily:"2026-10-19",weekly:"2026-10-19",month:"2026-10"});
 assert.equal(periods(new Date("2026-10-31T15:00:00Z")).month,"2026-11");
});
test("mission totals use all history while display is capped and sources stay separate",()=>{
 const events:GameEvent[]=Array.from({length:60},(_,i)=>({source:i%2?"offline":"lan",mode:i%2?"ai":"lan",outcome:i%3?"win":"draw",character_id:["ja-hyun","myo-ryung","nabi","yu-ran"][i%4]!,ended_at:"2026-10-19T01:00:00.000Z",match_id:String(i)}));
 const progress=aggregateProgress(events,new Date("2026-10-19T02:00:00Z"));
 assert.equal(progress.history.length,50);assert.equal(progress.stats.offline.played,30);assert.equal(progress.stats.lan.played,30);
 assert.equal(progress.missions.find(m=>m.id==="all-characters")!.current,4);assert.equal(progress.missions.find(m=>m.id==="weekly-play")!.current,60);
 assert.equal(progress.missions.find(m=>m.id==="daily-play")!.period,"2026-10-19");
});
test("request fingerprint ignores object key order but preserves values",()=>{
 assert.equal(fingerprint({b:2,a:1}),fingerprint({a:1,b:2}));assert.notEqual(fingerprint({a:1}),fingerprint({a:2}));
});
