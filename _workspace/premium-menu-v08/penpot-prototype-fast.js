const N=storage.v08;
N.ensureFlags();
N.proto=penpotUtils.getPageByName('10_Prototype');if(!N.proto)throw Error('Prototype page missing');
N.protoMap=N.protoMap||{};
for(const b of N.proto.root.children.filter(b=>b.name.startsWith('PROTO / ')))if(!N.protoMap[b.name.slice(8)])N.protoMap[b.name.slice(8)]=b;
N.quietPrototypeView=()=>{if(penpot.selection?.length)penpot.selection=[];if(N.quietPrototypeViewport!==false){const center=penpot.viewport.center;if(center.x!==-3000||center.y!==-3000)penpot.viewport.center={x:-3000,y:-3000};if(penpot.viewport.zoom!==1)penpot.viewport.zoom=1;}};
N.protoFastOrder=()=>[...N.spec.base.map(name=>N.spec.scenes.find(s=>s.name===name)),...N.spec.scenes.filter(s=>!N.spec.base.includes(s.name))].filter(Boolean);
N.protoFastPlan=spec=>{
 const shade=spec.elements.map(e=>e.name).lastIndexOf('MODAL / scrim');
 const controls=spec.elements.slice(shade+1).filter(e=>['button','hotspot'].includes(e.kind)&&e.dest&&e.state!=='disabled').map(e=>({name:'HIT08 / '+e.name,x:e.x,y:e.y,w:e.w,h:e.h,meta:{dest:e.dest,legacy:e.legacy||e.name,state:e.state||'default'}}));
 const image=N.snapshots[spec.name]||null;
 return {spec,image,controls,signature:JSON.stringify({name:spec.name,image:image?.id||null,controls})};
};
N.protoFastPrepared=spec=>{const b=N.protoMap[spec.name];return !!N.snapshots[spec.name]&&!!b&&b.getPluginData('v08-fast-prepared')===N.protoFastPlan(spec).signature;};
N.protoFastInfo={};
for(const spec of N.protoFastOrder())if(N.protoFastPrepared(spec)){
 const b=N.protoMap[spec.name],children=b.children;
 N.protoFastInfo[spec.name]={plan:N.protoFastPlan(spec),clean:children.every(s=>s.getPluginData('premium-menu-v08')==='true')};
}
const sameBox=(a,b)=>Math.abs(a.x-b.x)<.1&&Math.abs(a.y-b.y)<.1&&Math.abs(a.w-b.w)<.1&&Math.abs(a.h-b.h)<.1;
N.protoFastCandidate=plan=>{
 const ids=new Set(N.proto.root.children.map(b=>b.id));
 return Object.entries(N.protoFastInfo).filter(([name])=>name!==plan.spec.name&&ids.has(N.protoMap[name]?.id)).map(([name,info])=>{
  const available=info.plan.controls.map(c=>({...c,used:false}));let score=info.clean?0:3;
  for(const control of plan.controls){let m=available.find(c=>!c.used&&sameBox(c,control)&&c.name===control.name);if(!m)m=available.find(c=>!c.used&&sameBox(c,control));if(m){m.used=true;score+=JSON.stringify(m.meta)===JSON.stringify(control.meta)?0:1;}else score+=6;}
  score+=available.filter(c=>!c.used).length*2;
  return {name,info,score};
 }).sort((a,b)=>a.score-b.score)[0]||null;
};
N.prepareFastPrototype=spec=>{
 N.ensureFlags();
 if(penpot.currentPage.id!==N.proto.id)throw Error('Prototype page is not active');
 const plan=N.protoFastPlan(spec);if(!plan.image)throw Error('Snapshot missing: '+spec.name);
 if(N.protoFastPrepared(spec))return {name:spec.name,existing:true};
 let b=N.protoMap[spec.name],created=false,wholeClone=false,childClones=0,rectangles=0,moved=0;
 const original=N.base.boards.find(x=>x.name==='PROTO / '+spec.name);
 if(original&&b?.id!==original.id)throw Error('Original prototype identity differs: '+spec.name);
 if(!b){
  const candidate=N.protoFastCandidate(plan),index=N.spec.scenes.findIndex(s=>s.name===spec.name),x=130000+index%5*2120,y=Math.floor(index/5)*1280;
  if(candidate){
   const source=N.protoMap[candidate.name];
   if(candidate.info.clean){b=source.clone();b.name='PROTO / '+spec.name;wholeClone=true;N.put(N.proto.root,b,x,y);}
   else{b=N.board(N.proto,'PROTO / '+spec.name,x,y);for(const s of source.children.filter(s=>s.getPluginData('premium-menu-v08')==='true')){N.put(b,s.clone(),s.x-source.x,s.y-source.y);childClones++;}}
  }else b=N.board(N.proto,'PROTO / '+spec.name,x,y);
  b.setPluginData('v08-proto-owned','true');N.protoMap[spec.name]=b;created=true;
 }
 if(original){
  for(const child of b.children.filter(s=>s.getPluginData('premium-menu-v08')!=='true')){if(!child.getPluginData('v08-original-proto-hidden'))child.setPluginData('v08-original-proto-hidden',String(child.hidden));if(!child.hidden)child.hidden=true;}
 }else if(!created&&b.getPluginData('v08-proto-owned')!=='true'&&!b.getPluginData('v08-prototype'))throw Error('Unrecognized existing prototype: '+spec.name);
 if(b.getPluginData('v08-wired'))b.setPluginData('v08-wired','');
 const own=b.children.filter(s=>s.getPluginData('premium-menu-v08')==='true');
 const snapshots=own.filter(s=>s.name==='SNAPSHOT / v08');let snapshot=snapshots.find(s=>!s.hidden)||snapshots[snapshots.length-1];
 if(!snapshot){snapshot=N.rect(b,'SNAPSHOT / v08',0,0,1920,1080,null,1,0);snapshot.setPluginData('premium-menu-v08','true');rectangles++;}
 for(const duplicate of snapshots.filter(s=>s.id!==snapshot.id))duplicate.remove();
 if(snapshot.hidden)snapshot.hidden=false;
 if(snapshot.fills?.[0]?.fillImage?.id!==plan.image.id)snapshot.fills=[{fillImage:plan.image,fillOpacity:1}];
 const hits=b.children.filter(s=>s.name.startsWith('HIT08 / ')&&s.getPluginData('premium-menu-v08')==='true').map(s=>({shape:s,name:s.name,x:s.x-b.x,y:s.y-b.y,w:s.width,h:s.height,used:false}));
 for(const control of plan.controls){
  let match=hits.find(h=>!h.used&&h.name===control.name&&sameBox(h,control));if(!match)match=hits.find(h=>!h.used&&sameBox(h,control));if(!match)match=hits.find(h=>!h.used&&h.name===control.name);if(!match)match=hits.find(h=>!h.used);
  let hit;
  if(match){match.used=true;hit=match.shape;if(Math.abs(match.x-control.x)>.1||Math.abs(match.y-control.y)>.1){penpotUtils.setParentXY(hit,control.x,control.y);moved++;}if(Math.abs(match.w-control.w)>.1||Math.abs(match.h-control.h)>.1){hit.resize(control.w,control.h);moved++;}}
  else{hit=N.rect(b,control.name,control.x,control.y,control.w,control.h,N.C.bg,0,0);hit.setPluginData('premium-menu-v08','true');rectangles++;}
  if(hit.name!==control.name)hit.name=control.name;if(hit.hidden)hit.hidden=false;
  const meta=JSON.stringify(control.meta);if(hit.getPluginData('v08-control')!==meta)hit.setPluginData('v08-control',meta);
 }
 for(const unused of hits.filter(h=>!h.used))unused.shape.remove();
 // Keep the single image behind the clickable rectangles; other original children stay hidden.
 const children=b.children,firstOwn=children.findIndex(s=>s.getPluginData('premium-menu-v08')==='true'),snapshotIndex=children.findIndex(s=>s.id===snapshot.id);
 if(snapshotIndex!==firstOwn)snapshot.setParentIndex(firstOwn);
 if(b.getPluginData('v08-prototype')!==spec.name)b.setPluginData('v08-prototype',spec.name);
 b.setPluginData('v08-fast-prepared',plan.signature);
 N.protoFastInfo[spec.name]={plan,clean:b.children.every(s=>s.getPluginData('premium-menu-v08')==='true')};
 return {name:spec.name,id:b.id,wholeClone,childClones,rectangles,moved,controls:plan.controls.length};
};
N.wireFastPrototype=spec=>{
 N.ensureFlags();
 if(penpot.currentPage.id!==N.proto.id)throw Error('Prototype page is not active');
 if(!N.protoFastPrepared(spec))throw Error('Prototype geometry is not prepared: '+spec.name);
 const plan=N.protoFastPlan(spec),b=N.protoMap[spec.name],hits=b.children.filter(s=>s.name.startsWith('HIT08 / ')&&s.getPluginData('premium-menu-v08')==='true');let added=0,changed=0,reused=0,removed=0;
 for(const control of plan.controls){
  const hit=hits.find(s=>s.name===control.name&&sameBox({x:s.x-b.x,y:s.y-b.y,w:s.width,h:s.height},control));if(!hit)throw Error('Prepared hotspot missing: '+spec.name+' '+control.name);
  const dest=N.protoMap[control.meta.dest];if(!dest)throw Error('Destination missing: '+control.meta.dest);
  const links=[...(hit.interactions||[])],first=links[0];for(const extra of links.slice(1)){hit.removeInteraction(extra);removed++;}
  const action={type:'navigate-to',destination:dest,animation:{type:'dissolve',duration:200,easing:'ease-out'}};
  if(!first){hit.addInteraction('click',action);added++;}
  else{const a=first.action;if(first.trigger==='click'&&a.type==='navigate-to'&&a.destination?.id===dest.id&&a.animation?.type==='dissolve'&&a.animation?.duration===200&&a.animation?.easing==='ease-out')reused++;else{if(first.trigger!=='click')first.trigger='click';first.action=action;changed++;}}
 }
 if(!b.getPluginData('v08-wired'))b.setPluginData('v08-wired','true');
 return {name:spec.name,id:b.id,controls:plan.controls.length,added,changed,reused,removed};
};
N.protoFastStatus=()=>{
 N.ensureFlags();const order=N.protoFastOrder(),prepared=order.filter(s=>N.protoFastPrepared(s));
 return {total:order.length,prepared:prepared.length,wired:prepared.filter(s=>N.protoMap[s.name].getPluginData('v08-wired')).length,basePrepared:N.spec.base.filter(name=>N.protoFastPrepared(N.spec.scenes.find(s=>s.name===name))).length,baseWired:N.spec.base.filter(name=>N.protoMap[name]?.getPluginData('v08-wired')).length};
};
N.makePrototypeBatch=async(count=4)=>{
 N.ensureFlags();if(penpot.currentPage.id!==N.proto.id)await penpot.openPage(N.proto);N.ensureFlags();N.quietPrototypeView();
 const pending=N.protoFastOrder().filter(s=>!N.protoFastPrepared(s)).slice(0,count),out=[];
 for(const spec of pending){const token=penpot.history.undoBlockBegin();try{out.push(N.prepareFastPrototype(spec));}finally{penpot.history.undoBlockFinish(token);}await N.post('prototype-fast-progress.json',{stage:'geometry',last:spec.name,...N.protoFastStatus(),at:new Date().toISOString(),savedVerified:false});N.ensureFlags();}
 return {out,...N.protoFastStatus(),savedVerified:false};
};
N.wirePrototypeBatch=async(count=12)=>{
 N.ensureFlags();if(penpot.currentPage.id!==N.proto.id)await penpot.openPage(N.proto);N.ensureFlags();N.quietPrototypeView();
 const order=N.protoFastOrder();if(!order.every(s=>N.protoFastPrepared(s)))throw Error('Prepare all prototype board IDs before wiring; state destinations must exist');
 for(const spec of order)for(const control of N.protoFastPlan(spec).controls)if(!N.protoMap[control.meta.dest])throw Error('Destination missing: '+control.meta.dest);
 const pending=order.filter(s=>!N.protoMap[s.name].getPluginData('v08-wired')).slice(0,count),out=[];
 for(const spec of pending){const token=penpot.history.undoBlockBegin();try{out.push(N.wireFastPrototype(spec));}finally{penpot.history.undoBlockFinish(token);}await N.post('prototype-fast-progress.json',{stage:'wiring',last:spec.name,...N.protoFastStatus(),at:new Date().toISOString(),savedVerified:false});N.ensureFlags();}
 return {out,...N.protoFastStatus(),savedVerified:false};
};
return {prototypeFast:true,mode:'foreground-await-only',...N.protoFastStatus()};
