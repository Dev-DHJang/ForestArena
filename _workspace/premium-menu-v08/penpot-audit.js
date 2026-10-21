const N=storage.v08;
N.readShape=(s)=>({id:s.id,name:s.name,type:s.type,x:s.x,y:s.y,w:s.width,h:s.height,hidden:s.hidden,opacity:s.opacity??null,text:s.characters||null,children:s.children?.map(c=>c.id)||null,fills:s.fills?.map(f=>({color:f.fillColor??null,opacity:f.fillOpacity??null,image:f.fillImage?.id??null})),interactions:(s.interactions||[]).map(i=>({trigger:i.trigger,type:i.action.type,dest:i.action.destination?.id||null}))});
N.prototypeEffectiveHidden=(shape,board)=>{
 if(shape.hidden!==false)return true;
 for(let parent=shape.parent;parent;parent=parent.parent){if(parent.hidden===true)return true;if(parent.id===board.id)break;}
 return false;
};
N.auditPrototypeGraph=(spec,proto)=>{
 N.ensureFlags();const issues=[],touchIssues=[],shade=spec.elements.map(e=>e.name).lastIndexOf('MODAL / scrim');
 const expected=spec.elements.slice(shade+1).filter(e=>['button','hotspot'].includes(e.kind)&&e.dest&&e.state!=='disabled').map(e=>({name:'HIT08 / '+e.name,x:e.x,y:e.y,w:e.w,h:e.h,dest:e.dest,destinationId:N.protoMap[e.dest]?.id||null}));
 if(!proto)return {issues:[{scene:spec.name,reason:'prototype missing'}],touchIssues,summary:{scene:spec.name,expectedHotspots:expected.length,actualHotspots:0,snapshots:0},actualHotspots:[]};
 // Search the complete subtree, including hidden rectangles and hidden ancestors.
 const shapes=penpotUtils.findShapes(s=>s.name.startsWith('HIT08 / ')||s.name==='SNAPSHOT / v08',proto);
 const hits=shapes.filter(s=>s.name.startsWith('HIT08 / ')),snapshots=shapes.filter(s=>s.name==='SNAPSHOT / v08');
 const same=(a,b)=>a.name===b.name&&Math.abs(a.x-b.x)<.1&&Math.abs(a.y-b.y)<.1&&Math.abs(a.w-b.w)<.1&&Math.abs(a.h-b.h)<.1;
 const actual=hits.map(hit=>({shape:hit,id:hit.id,name:hit.name,x:hit.x-proto.x,y:hit.y-proto.y,w:hit.width,h:hit.height,hidden:N.prototypeEffectiveHidden(hit,proto)}));
 if(actual.length!==expected.length)issues.push({scene:spec.name,reason:'hotspot total count differs',expected:expected.length,actual:actual.length});
 for(const e of expected){const matches=actual.filter(a=>same(a,e));if(!matches.length)issues.push({scene:spec.name,name:e.name,reason:'expected active hotspot missing',geometry:{x:e.x,y:e.y,w:e.w,h:e.h}});if(matches.length>1)issues.push({scene:spec.name,name:e.name,reason:'duplicate actual hotspot',ids:matches.map(a=>a.id)});if(!e.destinationId)issues.push({scene:spec.name,name:e.name,reason:'expected destination board missing',destination:e.dest});}
 const actualHotspots=[];
 for(const hit of actual){
  const matches=expected.filter(e=>same(hit,e)),links=[...(hit.shape.interactions||[])];
  if(!matches.length)issues.push({scene:spec.name,id:hit.id,name:hit.name,reason:'unexpected hotspot',geometry:{x:hit.x,y:hit.y,w:hit.w,h:hit.h}});
  if(matches.length>1)issues.push({scene:spec.name,id:hit.id,name:hit.name,reason:'ambiguous expected hotspot key',expected:matches.length});
  if(hit.hidden)issues.push({scene:spec.name,id:hit.id,name:hit.name,reason:'hotspot is hidden or has a hidden ancestor'});
  if(links.length!==1)issues.push({scene:spec.name,id:hit.id,name:hit.name,reason:'hotspot interaction count differs',expected:1,actual:links.length});
  for(const [index,link] of links.entries()){
   const action=link.action;
   if(link.trigger!=='click')issues.push({scene:spec.name,id:hit.id,name:hit.name,index,reason:'hotspot trigger differs',expected:'click',actual:link.trigger});
   if(action?.type!=='navigate-to')issues.push({scene:spec.name,id:hit.id,name:hit.name,index,reason:'hotspot action type differs',expected:'navigate-to',actual:action?.type||null});
   if(matches.length===1&&(!matches[0].destinationId||action?.destination?.id!==matches[0].destinationId))issues.push({scene:spec.name,id:hit.id,name:hit.name,index,reason:'hotspot destination differs',expected:matches[0].destinationId,actual:action?.destination?.id||null});
   if(action?.animation?.type!=='dissolve'||action?.animation?.duration!==200)issues.push({scene:spec.name,id:hit.id,name:hit.name,index,reason:'hotspot transition differs',expected:{type:'dissolve',duration:200},actual:action?.animation||null});
  }
  if(hit.w<72||hit.h<72||hit.x<95.9||hit.y<47.9||hit.x+hit.w>1824.1||hit.y+hit.h>1032.1)touchIssues.push({scene:spec.name,id:hit.id,name:hit.name,x:hit.x,y:hit.y,w:hit.w,h:hit.h});
  actualHotspots.push({scene:spec.name,id:hit.id,name:hit.name,x:hit.x,y:hit.y,w:hit.w,h:hit.h,hidden:hit.hidden,expectedMatches:matches.length,interactionCount:links.length,interactions:links.map(link=>({trigger:link.trigger,type:link.action?.type||null,destinationId:link.action?.destination?.id||null,animation:link.action?.animation||null}))});
 }
 if(snapshots.length!==1)issues.push({scene:spec.name,reason:'snapshot count differs',expected:1,actual:snapshots.length,ids:snapshots.map(s=>s.id)});
 const expectedImageId=N.snapshots[spec.name]?.id||null;if(!expectedImageId)issues.push({scene:spec.name,reason:'expected snapshot media missing'});
 for(const snapshot of snapshots){
  if(N.prototypeEffectiveHidden(snapshot,proto))issues.push({scene:spec.name,id:snapshot.id,reason:'snapshot is hidden or has a hidden ancestor'});
  if(Math.abs(snapshot.x-proto.x)>.1||Math.abs(snapshot.y-proto.y)>.1||Math.abs(snapshot.width-1920)>.1||Math.abs(snapshot.height-1080)>.1)issues.push({scene:spec.name,id:snapshot.id,reason:'snapshot geometry differs',actual:{x:snapshot.x-proto.x,y:snapshot.y-proto.y,w:snapshot.width,h:snapshot.height}});
  const fills=snapshot.fills||[],imageId=fills[0]?.fillImage?.id||null;
  if(fills.length!==1||!expectedImageId||imageId!==expectedImageId)issues.push({scene:spec.name,id:snapshot.id,reason:'snapshot media differs',expected:expectedImageId,actual:imageId,fillCount:fills.length});
  if((snapshot.opacity??1)!==1||(fills[0]?.fillOpacity??1)!==1)issues.push({scene:spec.name,id:snapshot.id,reason:'snapshot opacity differs'});
 }
 return {issues,touchIssues,actualHotspots,summary:{scene:spec.name,expectedHotspots:expected.length,actualHotspots:actual.length,snapshots:snapshots.length,snapshotId:snapshots[0]?.id||null,snapshotImageId:snapshots[0]?.fills?.[0]?.fillImage?.id||null,expectedSnapshotImageId:expectedImageId}};
};
N.audit=async()=>{
 N.ensureFlags();
 const baseIdIssues=[],legacyChildIssues=[],outsideChanges=[],componentIssues=[],shapeIssues=[],textIssues=[],sourceControlIssues=[],prototypeIssues=[],touchIssues=[],comparisonIssues=[],statePageIssues=[],actualControls=[],actualPrototypeHotspots=[],prototypeGraph=[],sourceIndex=[];
 const byId=new Map();for(const p of penpot.currentFile.pages)for(const b of p.root.children)byId.set(b.id,{p,b});
 for(const old of N.base.boards){
  await N.post('audit-progress.json',{stage:'baseline',last:old.name,total:N.base.boards.length,at:new Date().toISOString()});N.ensureFlags();
  const edited=old.target||(old.name.startsWith('PROTO / ')&&N.spec.base.includes(old.name.slice(8)));
  const found=byId.get(old.id);if(!found){(edited?legacyChildIssues:outsideChanges).push({name:old.name,reason:'original board missing',id:old.id});continue;}
  const b=found.b,actual=new Map(penpotUtils.findShapes(()=>true,b).map(s=>[s.id,s]));
  if(found.p.name!==old.page)(edited?baseIdIssues:outsideChanges).push({name:old.name,id:b.id,reason:'original board page changed',expected:old.page,actual:found.p.name});
  if(b.name!==old.name||b.width!==old.width||b.height!==old.height)(edited?baseIdIssues:outsideChanges).push({name:old.name,id:b.id,reason:'board name or dimensions changed'});
  for(const previous of old.shapes){
   const now=actual.get(previous.id);if(!now){(edited?legacyChildIssues:outsideChanges).push({name:old.name,id:previous.id,reason:'original shape missing'});continue;}
   const value=N.readShape(now),expected={...previous};
   if(edited&&now.parent?.id===b.id)expected.hidden=true;
   if(JSON.stringify(value)!==JSON.stringify(expected))(edited?legacyChildIssues:outsideChanges).push({name:old.name,id:previous.id,reason:'original shape properties changed',fields:Object.keys(expected).filter(k=>JSON.stringify(expected[k])!==JSON.stringify(value[k]))});
  }
  if(!edited&&actual.size!==old.shapes.length)outsideChanges.push({name:old.name,reason:'outside board descendant count changed',before:old.shapes.length,after:actual.size});
 }
 const components=penpot.library.local.components,currentIds=new Set(components.map(c=>c.id));for(const c of N.base.components)if(!currentIds.has(c.id))componentIssues.push({reason:'original component missing',...c});
 const official=[];for(const {p,b} of byId.values())if(/^SCR_\d{2}_/.test(b.name))official.push({name:b.name,id:b.id,width:b.width,height:b.height,page:p.name});
 const officialIssues=[];for(let i=1;i<=24;i++){const prefix='SCR_'+String(i).padStart(2,'0')+'_',matches=official.filter(x=>x.name.startsWith(prefix));if(matches.length!==1||matches[0].width!==1920||matches[0].height!==1080)officialIssues.push({prefix,matches});}
 const componentUsage=[];
 for(const spec of N.spec.scenes){
  await N.post('audit-progress.json',{stage:'native-and-prototype',last:spec.name,total:N.spec.scenes.length,at:new Date().toISOString()});N.ensureFlags();
  const b=N.boards[spec.name],proto=N.protoMap[spec.name],graph=N.auditPrototypeGraph(spec,proto);prototypeIssues.push(...graph.issues);touchIssues.push(...graph.touchIssues);actualPrototypeHotspots.push(...graph.actualHotspots);prototypeGraph.push(graph.summary);if(!b){shapeIssues.push({scene:spec.name,reason:'native missing'});continue;}
  const originalPrototype=N.base.boards.find(x=>x.name==='PROTO / '+spec.name);if(originalPrototype&&proto?.id!==originalPrototype.id)prototypeIssues.push({scene:spec.name,reason:'original prototype ID differs',expected:originalPrototype.id,actual:proto?.id||null});
  const original=N.base.boards.find(x=>x.name===spec.name&&x.target);if(original&&b.id!==original.id)baseIdIssues.push({name:spec.name,expected:original.id,actual:b.id});
  const a=b.children.filter(c=>c.getPluginData('premium-menu-v08')==='true'),shade=spec.elements.map(e=>e.name).lastIndexOf('MODAL / scrim');
  if(!N.spec.base.includes(spec.name)&&N.statePlacement){const expected=N.statePlacement(spec),actual=byId.get(b.id)?.p.name;if(actual!==expected.name)statePageIssues.push({scene:spec.name,reason:'state page differs',expected:expected.name,actual});}
  sourceIndex.push({name:spec.name,id:b.id,page:byId.get(b.id)?.p.name||null,pageId:byId.get(b.id)?.p.id||null,width:b.width,height:b.height,elements:a.length,prototypeId:proto?.id||null});
  const instances=penpotUtils.findShapes(s=>s.isComponentHead?.()&&s.component()?.path===N.path,b);componentUsage.push({name:spec.name,instances:instances.length,components:[...new Set(instances.map(s=>s.component().name))]});
  if(!instances.length)componentIssues.push({scene:spec.name,reason:'no v08 component instances'});
  if(a.length!==spec.elements.length)shapeIssues.push({scene:spec.name,reason:'native element count',expected:spec.elements.length,actual:a.length});
  for(let i=0;i<Math.min(a.length,spec.elements.length);i++){
   const e=spec.elements[i],s=a[i],x=s.x-b.x,y=s.y-b.y;
   if(s.name!==e.name)shapeIssues.push({scene:spec.name,index:i,reason:'element name/order',expected:e.name,actual:s.name});
   if(e.kind==='text'){
    if(s.characters!==e.text)textIssues.push({scene:spec.name,name:e.name,reason:'native text differs'});
    const t=s.textBounds||s.bounds;if(t.x<b.x-1||t.y<b.y-1||t.x+t.width>b.x+b.width+1||t.y+t.height>b.y+b.height+1)textIssues.push({scene:spec.name,name:e.name,reason:'text exceeds board',bounds:t});
   }
   if(e.kind==='button'){const label=s.children?.find(c=>c.name==='Label');if(label?.characters!==e.text)textIssues.push({scene:spec.name,name:e.name,reason:'button label differs',expected:e.text,actual:label?.characters||null});}
   if(['button','hotspot'].includes(e.kind)){
    const meta=JSON.parse(s.getPluginData('v08-control')||'null'),active=i>shade&&!!e.dest&&e.state!=='disabled';
    if(meta?.dest!==(e.dest||null)||meta?.state!==(e.state||'default'))sourceControlIssues.push({scene:spec.name,name:e.name,reason:'control metadata differs',actual:meta});
    if(Math.abs(x-e.x)>.1||Math.abs(y-e.y)>.1||Math.abs(s.width-e.w)>.1||Math.abs(s.height-e.h)>.1)sourceControlIssues.push({scene:spec.name,name:e.name,reason:'source geometry differs',actual:{x,y,w:s.width,h:s.height},expected:{x:e.x,y:e.y,w:e.w,h:e.h}});
    const hit=graph.actualHotspots.find(c=>c.name==='HIT08 / '+e.name&&Math.abs(c.x-e.x)<.1&&Math.abs(c.y-e.y)<.1&&Math.abs(c.w-e.w)<.1&&Math.abs(c.h-e.h)<.1),link=hit?.interactions?.[0];
    actualControls.push({scene:spec.name,name:e.name,sourceId:s.id,id:hit?.id||null,x,y,w:s.width,h:s.height,active:!!hit&&!hit.hidden&&hit.interactionCount===1&&link?.trigger==='click'&&link?.type==='navigate-to',hidden:hit?.hidden??null,interactionCount:hit?.interactionCount||0,trigger:link?.trigger||null,actionType:link?.type||null,destinationName:meta?.dest||null,destinationId:link?.destinationId||null,animation:link?.animation||null});
   }
   if(e.kind==='image'){const slot=e.slot||'DESIGN/bg/'+e.key;if(s.getPluginData('v08-image-slot')!==slot)shapeIssues.push({scene:spec.name,name:e.name,reason:'image slot differs',expected:slot,actual:s.getPluginData('v08-image-slot')});}
  }

 }
 for(const [name,b] of Object.entries(N.comparisons)){
  const src=N.boards[name.replace('CMP20 / MENU08 / ','')],center=b.children.find(s=>s.name==='1920 × 1080 unchanged center');
  if(!center||b.width!==2400||b.height!==1080||center.width!==1920||center.height!==1080||Math.abs(center.x-b.x-240)>.1||Math.abs(center.y-b.y)>.1){comparisonIssues.push({name,reason:'20:9 dimensions/center'});continue;}
  const a=src.children.filter(s=>s.getPluginData('premium-menu-v08')==='true');if(a.length!==center.children.length)comparisonIssues.push({name,reason:'20:9 child count'});
  const compareDeep=(s,c,path)=>{
   if(!c||c.name!==s.name||c.type!==s.type||Math.abs(c.x-center.x-s.x+src.x)>.1||Math.abs(c.y-center.y-s.y+src.y)>.1||Math.abs(c.width-s.width)>.1||Math.abs(c.height-s.height)>.1||c.characters!==s.characters||c.fontSize!==s.fontSize||c.fontWeight!==s.fontWeight)comparisonIssues.push({name,path,reason:'20:9 nested native content differs'});
   if(!c)return;const sc=s.children||[],cc=c.children||[];if(sc.length!==cc.length)comparisonIssues.push({name,path,reason:'20:9 nested child count differs'});sc.forEach((child,i)=>compareDeep(child,cc[i],path+'/'+i));
  };
  a.forEach((s,i)=>compareDeep(s,center.children[i],String(i)));
 }
 const statePageCounts={};for(const s of sourceIndex.filter(s=>!N.spec.base.includes(s.name)))statePageCounts[s.page]=(statePageCounts[s.page]||0)+1;for(const [page,count] of Object.entries(statePageCounts))if(count>(N.statePageCapacity||24))statePageIssues.push({page,count,reason:'state page exceeds capacity'});
 const report={file:penpot.currentFile.id,revn:penpot.currentFile.revn,checkedAt:new Date().toISOString(),base:N.spec.base.map(name=>({name,id:N.boards[name]?.id})),sourceCount:sourceIndex.length,prototypeCount:N.spec.scenes.filter(s=>N.protoMap[s.name]?.getPluginData('v08-wired')).length,scenes:Object.values(N.exportRecords),designExports:Object.values(N.designExportRecords),comparisons:Object.values(N.comparisonExportRecords),sourceIndex,actualControls,actualPrototypeHotspots,prototypeGraph,componentUsage,originalComponents:N.base.components.length,currentComponents:components.length,official,officialIssues,baseIdIssues,legacyChildIssues,outsideChanges,componentIssues,shapeIssues,textIssues,sourceControlIssues,prototypeIssues,touchIssues,comparisonIssues,statePageIssues,statePageCounts,deviceChecked:false};
 await N.post('final-audit.json',report);await N.post('actual-source-index.json',sourceIndex);await N.post('actual-controls.json',actualControls);await N.post('actual-prototype-hotspots.json',actualPrototypeHotspots);await N.post('prototype-graph-audit.json',prototypeGraph);
 return {sourceCount:report.sourceCount,prototypeCount:report.prototypeCount,export1280:report.scenes.length,export1920:report.designExports.length,comparisons:report.comparisons.length,issues:Object.fromEntries(['officialIssues','baseIdIssues','legacyChildIssues','outsideChanges','componentIssues','shapeIssues','textIssues','sourceControlIssues','prototypeIssues','touchIssues','comparisonIssues','statePageIssues'].map(k=>[k,report[k].length]))};
};
N.startAudit=()=>{throw Error('Background audit is disabled. Use await N.audit() after loading the saved file.');};
return {auditHelper:true};
