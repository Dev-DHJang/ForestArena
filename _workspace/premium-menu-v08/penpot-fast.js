const N=storage.v08;
N.ensureFlags=()=>{penpot.flags.naturalChildOrdering=true;penpot.flags.throwValidationErrors=true;};
N.ensureFlags();
N.force=false;
N.stateIndexPage=penpotUtils.getPageByName('12_Menu_States_v08');
N.statePageCapacity=24;
N.statePlacement=(spec,create=false)=>{
 const states=N.spec.scenes.filter(s=>!N.spec.base.includes(s.name)),index=states.findIndex(s=>s.name===spec.name);if(index<0)throw Error('Missing state index '+spec.name);
 const group=Math.floor(index/N.statePageCapacity),localIndex=index%N.statePageCapacity,name=group===0?'12_Menu_States_v08':String(12+group)+'_Menu_States_v08_'+String(group+1).padStart(2,'0');
 let page=penpotUtils.getPageByName(name);if(!page&&create){page=penpot.createPage();page.name=name;}
 return {page,name,index,group,localIndex,x:localIndex%4*2120,y:Math.floor(localIndex/4)*1280};
};
N.readyList=()=>N.spec.scenes.filter(s=>N.boards[s.name]?.getPluginData('v08-ready'));
N.fastMake=async(spec)=>{
 N.ensureFlags();if(penpot.selection?.length)penpot.selection=[];
 if(N.boards[spec.name]?.getPluginData('v08-ready'))return {name:spec.name,existing:true};
 const original=N.base.boards.find(s=>s.name===spec.name&&s.target);
 if(original){const token=penpot.history.undoBlockBegin();try{return await N.make(spec);}finally{penpot.history.undoBlockFinish(token);}}
 const placement=N.statePlacement(spec,true),page=placement.page;N.states=page;
 if(penpot.currentPage.id!==page.id)await penpot.openPage(page);
 N.ensureFlags();
 const previous=page.root.children.find(b=>b.name===spec.name);if(previous){if(previous.getPluginData('v08-ready')){N.boards[spec.name]=previous;return {name:spec.name,existing:true,page:page.name};}
  const approvedEmptyOrphan=placement.group===0&&placement.localIndex===0&&previous.children.length===0&&!N.base.boards.some(b=>b.id===previous.id);
  if(previous.getPluginData('v08-owned-state')!=='true'&&!approvedEmptyOrphan)throw Error('Unfinished state is not owned by v08: '+spec.name);previous.remove();delete N.boards[spec.name];}
 if(N.quietStateViewport!==false){const center=penpot.viewport.center;if(center.x!==-3000||center.y!==-3000)penpot.viewport.center={x:-3000,y:-3000};if(penpot.viewport.zoom!==1)penpot.viewport.zoom=1;}
 const targetKeys=spec.elements.map(e=>JSON.stringify(e));
 const semanticKey=e=>{if(!['button','hotspot','text'].includes(e.kind))return null;const value={...e};for(const k of ['name','text'])delete value[k];if(['button','hotspot'].includes(e.kind)){delete value.dest;delete value.legacy;}return JSON.stringify(value);};
 const samePageIds=new Set(page.root.children.map(b=>b.id));
 const candidates=N.readyList().filter(s=>samePageIds.has(N.boards[s.name].id)).map(s=>{const keys=s.elements.map(e=>JSON.stringify(e)),remaining=[...keys];let matches=0;for(const k of targetKeys){const i=remaining.indexOf(k);if(i>=0){matches++;remaining.splice(i,1);}}return {spec:s,matches,cost:(spec.elements.length-matches)*20+remaining.length};}).sort((a,b)=>a.cost-b.cost);
 if(!candidates.length){
  const token=penpot.history.undoBlockBegin();let seed;
  try{seed=N.board(page,spec.name,placement.x,placement.y);seed.setPluginData('v08-owned-state','true');seed.setPluginData('v08-ready','');N.draw(seed,spec);seed.setPluginData('v08-ready','true');N.boards[spec.name]=seed;
   return {name:spec.name,id:seed.id,page:page.name,seed:true,source:null,total:spec.elements.length};
  }catch(error){if(seed?.getPluginData('v08-owned-state')==='true'){seed.remove();delete N.boards[spec.name];}throw Error('Explicit page seed failed: '+spec.name+' '+String(error));}finally{penpot.history.undoBlockFinish(token);}
 }
 const chosen=candidates[0],source=N.boards[chosen.spec.name],oldElements=chosen.spec.elements;
 const oldShapes=source.children.filter(s=>s.getPluginData('premium-menu-v08')==='true');
 if(oldShapes.length!==oldElements.length)throw Error('Source shape mismatch '+chosen.spec.name+' '+oldShapes.length+'/'+oldElements.length);
 const token=penpot.history.undoBlockBegin();
 try{
  let b;const {x,y}=placement;
  const clean=source.children.length===oldShapes.length;
  if(clean){b=source.clone();b.name=spec.name;N.put(page.root,b,x,y);}else b=N.board(page,spec.name,x,y);
  if(b.getPluginData('v08-owned-state')!=='true')b.setPluginData('v08-owned-state','true');
  b.setPluginData('v08-ready','');
  const cloned=clean?b.children:oldShapes;
  const available=oldElements.map((e,i)=>({key:JSON.stringify(e),semantic:semanticKey(e),shape:cloned[i],used:false}));
  const planned=spec.elements.map((element,i)=>{let match=available.find(x=>!x.used&&x.key===targetKeys[i]);const semantic=semanticKey(element);if(!match&&semantic)match=available.find(x=>!x.used&&x.semantic===semantic);if(match)match.used=true;return {element,match,patch:!!match&&match.key!==targetKeys[i],shape:null};});
  // Remove obsolete copies first so unchanged copies keep their relative order.
  if(clean)for(const item of available.filter(x=>!x.used))item.shape.remove();
  const order=clean?available.filter(x=>x.used).map(x=>x.shape):[];
  for(const item of planned.filter(x=>x.match)){
   if(clean)item.shape=item.match.shape;
   else{const s=item.match.shape.clone();N.put(b,s,item.match.shape.x-source.x,item.match.shape.y-source.y);item.shape=s;order.push(s);}
  }
  for(const item of planned.filter(x=>x.patch)){
   const s=item.shape,e=item.element;if(s.name!==e.name)s.name=e.name;
   if(e.kind==='text'){if(s.characters!==e.text)s.characters=e.text;}
   else{
    if(e.kind==='button'){const label=s.children.find(c=>c.name==='Label');if(!label)throw Error('Semantic button lacks Label: '+e.name);if(label.characters!==e.text)label.characters=e.text;}
    const meta=JSON.stringify({dest:e.dest||null,legacy:e.legacy||e.name,state:e.state||'default'});if(s.getPluginData('v08-control')!==meta)s.setPluginData('v08-control',meta);
   }
  }
  const added=planned.filter(x=>!x.match);
  if(added.length){
   N.draw(b,{name:spec.name,elements:added.map(x=>x.element)});
   const children=b.children,newShapes=children.slice(children.length-added.length);
   added.forEach((item,i)=>{item.shape=newShapes[i];order.push(newShapes[i]);});
  }
  for(let i=0;i<planned.length;i++){
   const shape=planned[i].shape,current=order.findIndex(s=>s.id===shape.id);
   if(current!==i){shape.setParentIndex(i);order.splice(current,1);order.splice(i,0,shape);}
  }
  b.setPluginData('v08-ready','true');
  if(b.getPluginData('v08-spec-name')!==spec.name)b.setPluginData('v08-spec-name',spec.name);
  if(!clean)b.exports=[{type:'png',scale:2/3,suffix:'-v08'}];N.boards[spec.name]=b;
  return {name:spec.name,id:b.id,page:page.name,seed:false,source:chosen.spec.name,matches:chosen.matches,total:spec.elements.length,cleanClone:clean};
 }catch(error){const partial=page.root.children.find(b=>b.name===spec.name&&b.getPluginData('v08-owned-state')==='true'&&!b.getPluginData('v08-ready'));if(partial){partial.remove();delete N.boards[spec.name];}throw Error('State '+spec.name+' failed; owned partial board cleaned: '+String(error));}finally{penpot.history.undoBlockFinish(token);}
};
N.makeBatch=async(count=2)=>{
 const pending=N.spec.scenes.filter(s=>!N.boards[s.name]?.getPluginData('v08-ready')).sort((a,b)=>Number(N.spec.base.includes(b.name))-Number(N.spec.base.includes(a.name))).slice(0,count),out=[];
 for(const spec of pending){
  if(N.stopRequested)break;
  out.push(await N.fastMake(spec));
  const progress={ready:N.readyList().length,total:N.spec.scenes.length,last:spec.name,at:new Date().toISOString()};
  if(N.production?.running){Object.assign(N.production,progress,{completedInBatch:out.length,requestedInBatch:pending.length});await N.post('native-production.json',N.production);}
  await N.post('native-progress.json',progress);
 }
 return {out,ready:N.readyList().length,total:N.spec.scenes.length,stopped:!!N.stopRequested,savedVerified:false};
};
N.startProduction=()=>{throw Error('Background editing is disabled. Use await N.makeBatch(count), then verify the saved version and reload.');};
return {fastMake:true,ready:N.readyList().length,mode:'foreground-await-only',clonePolicy:'same-active-page-only',statePageCapacity:N.statePageCapacity,statePages:[...new Set(N.spec.scenes.filter(s=>!N.spec.base.includes(s.name)).map(s=>N.statePlacement(s).name))]};
