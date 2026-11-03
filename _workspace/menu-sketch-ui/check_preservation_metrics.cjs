/* Read-only comparison. No candidate search and no writes to Penpot. */
const fs=require('node:fs');
const path=require('node:path');
const here=__dirname;
const old=JSON.parse(fs.readFileSync(path.join(here,'../premium-menu-v08/baseline-audit.json')));
const drift=JSON.parse(fs.readFileSync(path.join(here,'drift-snapshots.json'))).result;
const history=JSON.parse(fs.readFileSync(path.join(here,'history-ui-text-boxes.json')));
function hash(value){let h=2166136261;for(const c of JSON.stringify(value)){h^=c.charCodeAt(0);h=Math.imul(h,16777619);}return(h>>>0).toString(16);}
function indexTree(s,out={}){out[s.id]=s;for(const c of s.children||[])indexTree(c,out);return out;}
const results=drift.map(item=>{
 const previous=old.boards.find(b=>b.name===item.name);
 const archived=Object.fromEntries(previous.shapes.map(s=>[s.id,s]));
 const observed=history.find(b=>b.board===item.snap.id).before;
 const copy=structuredClone(item.snap),current=indexTree(copy),patches=[];
 for(const s of Object.values(current)){
  if(s.type!=='text')continue;
  const source=observed[s.id]?'read-only v08 history preview text-container height':archived[s.id]?'pre-v08 archived text snapshot':null;
  const reference=observed[s.id]||archived[s.id];
  if(!reference||reference.h===s.h)continue;
  // The complete reference set is applied deterministically, never a searched subset.
  patches.push({id:s.id,name:s.name,characters:s.text,currentHeight:s.h,referenceHeight:reference.h,source});
  s.h=reference.h;
 }
 const normalized=hash(copy);
 return{name:item.name,beforeHash:item.baseline,currentHash:hash(item.snap),normalizedHash:normalized,matchedWithOnlyTextHeightChanges:normalized===item.baseline,patches};
});
const report={readOnly:true,searchPerformed:false,method:'All observed prior text heights are substituted in memory. No other JSON property or array order is modified. Exact equality is checked against the fingerprint captured before MENU09 work.',results};
fs.writeFileSync(path.join(here,'preservation-metrics-analysis.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({pass:results.every(r=>r.matchedWithOnlyTextHeightChanges),screens:results.map(r=>({name:r.name,pass:r.matchedWithOnlyTextHeightChanges,metricChanges:r.patches.length}))}));
process.exitCode=results.every(r=>r.matchedWithOnlyTextHeightChanges)?0:1;
