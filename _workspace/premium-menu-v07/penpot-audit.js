const N=storage.v07;
N.audit=async()=>{
 const outsideChanges=[],missingOriginalComponents=[],changedLegacyLinks=[],missingDestinations=[],textIssues=[],touchIssues=[],shapeIssues=[],comparisonIssues=[],baseIdIssues=[],officialScreenIssues=[],legacyChildIssues=[],sourceControlIssues=[],actualControls=[];
 for(const name of N.spec.base){
  const original=N.baseline.sources.find(s=>s.name===name),b=N.boards[name];
  if(!b||b.id!==original.id)baseIdIssues.push({name,expected:original.id,actual:b?.id});
  if(!b)continue;
  const check=N.legacyChecks.find(s=>s.name===name);
  if(!check||check.actual!==check.expected||check.count!==check.expectedCount)legacyChildIssues.push({name,reason:'original full descendant digest or count changed',check});
  for(const c of b.children.filter(c=>c.getPluginData('v07-original-hidden')))if(!c.hidden)legacyChildIssues.push({name,id:c.id,reason:'original child not hidden'});
 }
 const officialIds=[];for(const p of penpot.currentFile.pages)for(const b of p.root.children)if(/^SCR_\d{2}_/.test(b.name))officialIds.push({name:b.name,id:b.id,width:b.width,height:b.height,page:p.name});
 for(let i=1;i<=24;i++){const prefix='SCR_'+String(i).padStart(2,'0')+'_',matches=officialIds.filter(b=>b.name.startsWith(prefix));if(matches.length!==1||matches[0].width!==1920||matches[0].height!==1080)officialScreenIssues.push({prefix,matches});}
 for(const original of N.baseline.sources.filter(s=>!s.target)){
  const p=penpotUtils.getPageByName(original.page),b=p.root.children.find(b=>b.id===original.id);
  if(!b){outsideChanges.push({name:original.name,reason:'missing board'});continue;}
  const actual=N.snapshot(b);if(original.digest!==N.hash(actual))outsideChanges.push({name:original.name,id:b.id,reason:'snapshot changed'});
 }
 for(const original of (N.prototypeBaseline||[]).filter(s=>!N.spec.base.includes(s.name.replace(/^PROTO \/ /,'')))){
  const b=N.proto.root.children.find(b=>b.id===original.id);
  if(!b||N.hash(N.snapshot(b))!==original.digest)outsideChanges.push({name:original.name,id:original.id,reason:'prototype snapshot changed'});
 }
 const componentIds=new Set(penpot.library.local.components.map(c=>c.id));
 for(const c of N.baseline.components)if(!componentIds.has(c.id))missingOriginalComponents.push(c);
 const currentLinks=N.links(N.proto),linksByKey=new Map(currentLinks.map(l=>[l.id+':'+l.index,l]));
 for(const l of N.baseline.links){const a=linksByKey.get(l.id+':'+l.index);if(!a||a.destination!==l.destination||a.type!==l.type||a.trigger!==l.trigger||JSON.stringify(a.animation)!==JSON.stringify(l.animation))changedLegacyLinks.push({before:l,after:a||null});}
 const destinationIds=new Set(N.proto.root.children.filter(b=>b.type==='board').map(b=>b.id));
 for(const l of currentLinks)if(l.destination&&!destinationIds.has(l.destination))missingDestinations.push(l);
 for(const spec of N.spec.scenes){
  const b=N.boards[spec.name];if(!b){shapeIssues.push({scene:spec.name,reason:'missing source'});continue;}
  const a=b.children.filter(c=>c.getPluginData('premium-menu-v07')==='true');
  const lastShade=spec.elements.map(e=>e.name).lastIndexOf('Modal shade');
  if(a.length!==spec.elements.length)shapeIssues.push({scene:spec.name,reason:'element count',expected:spec.elements.length,actual:a.length});
  for(let i=0;i<Math.min(a.length,spec.elements.length);i++){
   const e=spec.elements[i],s=a[i];if(s.name!==e.name)shapeIssues.push({scene:spec.name,index:i,expected:e.name,actual:s.name});
   if(e.kind==='button'||e.kind==='hotspot'){
    const meta=JSON.parse(s.getPluginData('v07-control')||'null');if(!meta||meta.dest!==(e.dest||null)||meta.state!==(e.state||'default'))sourceControlIssues.push({scene:spec.name,name:s.name,reason:'control metadata differs',expected:e.dest||null,actual:meta});
    if(Math.abs(s.x-b.x-e.x)>.01||Math.abs(s.y-b.y-e.y)>.01||Math.abs(s.width-e.w)>.01||Math.abs(s.height-e.h)>.01)sourceControlIssues.push({scene:spec.name,name:s.name,reason:'source control geometry differs'});
    const expectedActive=i>lastShade&&!!e.dest&&e.state!=='disabled';
    const hit=expectedActive?N.protoMap[spec.name]?.children.find(c=>c.name==='HIT07 / '+e.name&&Math.abs(c.x-N.protoMap[spec.name].x-e.x)<.01&&Math.abs(c.y-N.protoMap[spec.name].y-e.y)<.01):null,interaction=hit?.interactions?.[0];
    if(expectedActive&&(!hit||interaction?.action.destination?.id!==N.protoMap[e.dest]?.id))sourceControlIssues.push({scene:spec.name,name:e.name,reason:'actual hotspot missing or destination differs'});actualControls.push({scene:spec.name,name:e.name,sourceId:s.id,id:hit?.id||null,x:s.x-b.x,y:s.y-b.y,w:s.width,h:s.height,active:!!hit,destinationName:meta?.dest||null,destinationId:interaction?.action.destination?.id||null,animation:interaction?.action.animation||null});
   }
   if(e.kind==='image'&&s.getPluginData('v07-image-slot')!==e.slot)shapeIssues.push({scene:spec.name,name:s.name,reason:'image slot differs'});
   if(e.kind==='text'){
    if(s.characters!==e.text)textIssues.push({scene:spec.name,name:s.name,reason:'text differs',expected:e.text,actual:s.characters});
    const t=s.textBounds||s.bounds;
    if(t.x<b.x-1||t.y<b.y-1||t.x+t.width>b.x+b.width+1||t.y+t.height>b.y+b.height+1)textIssues.push({scene:spec.name,name:s.name,reason:'rendered text outside source board',bounds:t});
   }
  }
  const p=N.protoMap[spec.name];if(!p){shapeIssues.push({scene:spec.name,reason:'missing prototype'});continue;}
  for(const c of p.children.filter(c=>c.name.startsWith('HIT07 / '))){
   if(c.width<72||c.height<72)touchIssues.push({scene:spec.name,name:c.name,reason:'under 72px',width:c.width,height:c.height});
   const x=c.x-p.x,y=c.y-p.y;if(x<96||y<48||x+c.width>1824||y+c.height>1032)touchIssues.push({scene:spec.name,name:c.name,reason:'outside safe area',x,y,width:c.width,height:c.height});
   for(const l of c.interactions)if(l.action.animation?.type!=='dissolve'||l.action.animation?.duration!==200)touchIssues.push({scene:spec.name,name:c.name,reason:'transition differs'});
  }
 }
 for(const [name,b] of Object.entries(N.comparisons)){
  const source=N.boards[name.replace('CMP20 / MENU07 / ','')],center=b.children.find(s=>s.name==='1920 × 1080 unchanged center');
  if(!center||b.width!==2400||b.height!==1080||center.width!==1920||center.height!==1080||Math.abs(center.x-b.x-240)>.01||Math.abs(center.y-b.y)>.01){comparisonIssues.push({name,reason:'comparison geometry'});continue;}
  const original=source.children.filter(s=>s.getPluginData('premium-menu-v07')==='true');
  if(original.length!==center.children.length)comparisonIssues.push({name,reason:'center child count'});
  original.forEach((s,i)=>{const c=center.children[i];if(!c||c.name!==s.name||Math.abs((c.x-center.x)-(s.x-source.x))>.01||Math.abs((c.y-center.y)-(s.y-source.y))>.01||Math.abs(c.width-s.width)>.01||Math.abs(c.height-s.height)>.01||c.characters!==s.characters)comparisonIssues.push({name,index:i,reason:'center content differs'});});
 }
 const report={file:penpot.currentFile.id,base13:N.spec.base.map(name=>({name,id:N.boards[name]?.id})),scenes81:Object.values(N.exportRecords),comparisons4:Object.values(N.comparisonExportRecords),sourceCount:Object.keys(N.boards).length,prototypeCount:N.spec.scenes.filter(s=>N.protoMap[s.name]?.getPluginData('v07-wired')).length,originalLinks:N.baseline.links.length,currentLinks:currentLinks.length,originalComponents:N.baseline.components.length,currentComponents:componentIds.size,outsideChanges,missingOriginalComponents,changedLegacyLinks,missingDestinations,textIssues,touchIssues,shapeIssues,comparisonIssues,baseIdIssues,officialIds,officialScreenIssues,legacyChildIssues,sourceControlIssues,prototypeIds:Object.fromEntries(N.spec.scenes.map(s=>[s.name,N.protoMap[s.name]?.id])),checks:['actual native board bounds and text compared with scene-spec','original 13 IDs and hidden descendant IDs compared with baseline','official 24 screen IDs and 1920x1080 dimensions checked','actual source control metadata and geometry compared with scene-spec','actual prototype target size, safe area and transition read back','actual 20:9 center positions, sizes and text compared with source','original source snapshots compared with pre-edit baseline','all original prototype interaction shape IDs, indexes and destinations compared','all original component IDs checked'],deviceChecked:false};
 report.base=report.base13;report.scenes=report.scenes81;report.comparisons=report.comparisons4;report.designExports=Object.values(N.designExportRecords||{});report.actualControls=actualControls;report.legacyNativePreservation=N.legacyChecks;report.componentUsage=N.componentUsage;report.componentIssues=N.componentIssues||[];report.actualComponentInstanceUsage=N.actualComponentInstanceUsage;report.additionalButtonIconInstances=N.additionalButtonIconInstances;
 const originalLinkKeys=new Set(N.baseline.links.map(l=>l.id+':'+l.index));report.originalLinksPreserved=N.baseline.links.map(l=>linksByKey.get(l.id+':'+l.index));report.newLinks=currentLinks.filter(l=>!originalLinkKeys.has(l.id+':'+l.index));
 await N.post('final-audit.json',report);return {sourceCount:report.sourceCount,prototypeCount:report.prototypeCount,exports:report.scenes81.length,comparisons:report.comparisons4.length,outsideChanges:outsideChanges.length,missingOriginalComponents:missingOriginalComponents.length,changedLegacyLinks:changedLegacyLinks.length,missingDestinations:missingDestinations.length,textIssues:textIssues.length,touchIssues:touchIssues.length,shapeIssues:shapeIssues.length};
};
return {auditHelper:true};
