const N=storage.v08;
N.comparisonTargets=['SCR_03_Lobby','SCR_05_CharacterDetail','SCR_19_Shop','SCR_22_Social','EXT_06_GeneralSettings'];
N.comparisonPageName='21_Menu_Comparisons_v08';
N.comparisons=N.comparisons||{};N.comparisonExportRecords=N.comparisonExportRecords||{};
// Penpot may resolve auto-height text when its page is opened. Preserve the
// source text box dimensions in the comparison without changing source text.
N.alignComparisonText=(source,content)=>{
 const originals=source.children.filter(s=>s.getPluginData('premium-menu-v08')==='true'),changed=[];
 const visit=(s,c,path)=>{
  if(!c||c.name!==s.name||c.type!==s.type)throw Error('Comparison structure differs at '+path);
  if(s.type==='text'&&Math.abs(c.height-s.height)>.1){
   if(c.characters!==s.characters||Math.abs(c.width-s.width)>.1)throw Error('Comparison text content differs at '+path);
   const before=c.height;c.resize(s.width,s.height);c.growType='fixed';changed.push({path,name:c.name,before,after:c.height});
  }
  const a=s.children||[],b=c.children||[];if(a.length!==b.length)throw Error('Comparison child count differs at '+path);
  a.forEach((child,i)=>visit(child,b[i],path+'/'+i));
 };
 if(originals.length!==content.children.length)throw Error('Comparison top-level child count differs');
 originals.forEach((s,i)=>visit(s,content.children[i],String(i)));return changed;
};
N.makeComparisonNative=async name=>{
 N.ensureFlags();const index=N.comparisonTargets.indexOf(name);if(index<0)throw Error('Unknown 20:9 comparison '+name);
 const spec=N.spec.scenes.find(s=>s.name===name),source=N.boards[name];if(!spec||!source?.getPluginData('v08-ready'))throw Error('Native comparison source is not ready '+name);
 let page=penpotUtils.getPageByName(N.comparisonPageName);if(!page){page=penpot.createPage();page.name=N.comparisonPageName;}
 if(penpot.currentPage.id!==page.id)await penpot.openPage(page);N.ensureFlags();
 if(penpot.selection?.length)penpot.selection=[];
 if(N.quietComparisonViewport!==false){const center=penpot.viewport.center;if(center.x!==-3000||center.y!==-3000)penpot.viewport.center={x:-3000,y:-3000};if(penpot.viewport.zoom!==1)penpot.viewport.zoom=1;}
 const key='CMP20 / MENU08 / '+name,signature='native-center-v1:'+N.nativeSpecHash(name);let b=N.comparisons[key]||page.root.children.find(s=>s.name===key);
 if(b&&!page.root.children.some(s=>s.id===b.id))throw Error('Comparison is outside '+N.comparisonPageName+': '+name);
 if(b?.getPluginData('v08-comparison-ready')===signature){N.comparisons[key]=b;return {name:key,id:b.id,page:page.name,existing:true,savedVerified:false};}
 const token=penpot.history.undoBlockBegin();
 try{
  if(!b){b=N.board(page,key,0,index*1280,2400,1080);b.setPluginData('v08-comparison-owned','true');}
  else if(b.getPluginData('v08-comparison-owned')!=='true')throw Error('Unrecognized existing comparison '+key);
  for(const child of b.children)child.remove();
  const background=spec.elements.find(e=>e.kind==='image');if(!background||!N.media[background.key])throw Error('Comparison background missing '+name);
  const media=N.media[background.key],scale=Math.max(2400/media.width,1080/media.height),w=media.width*scale,h=media.height*scale;
  const forest=N.rect(b,'20:9 forest extension',(2400-w)/2,(1080-h)/2,w,h,null,1,0);forest.fills=[{fillImage:media,fillOpacity:1}];
  N.rect(b,'20:9 quiet extension',0,0,2400,1080,N.C.bg,.58,0);
  const content=N.board(page,'1920 × 1080 unchanged center',0,0,1920,1080);content.fills=[];N.put(b,content,240,0);
  // Draw the same native spec; cross-page cloning is intentionally not used.
  N.draw(content,spec);
  N.alignComparisonText(source,content);
  b.exports=[{type:'png',scale:2/3,suffix:'-v08'}];b.setPluginData('premium-menu-v08','comparison');b.setPluginData('v08-comparison-source',name);b.setPluginData('v08-comparison-ready',signature);N.comparisons[key]=b;
  return {name:key,id:b.id,page:page.name,width:2400,height:1080,centerX:240,sourceId:source.id,elements:content.children.length,savedVerified:false};
 }finally{penpot.history.undoBlockFinish(token);}
};
N.makeComparisonBatch=async(count=1)=>{
 N.ensureFlags();const pending=N.comparisonTargets.filter(name=>N.comparisons['CMP20 / MENU08 / '+name]?.getPluginData('v08-comparison-ready')!=='native-center-v1:'+N.nativeSpecHash(name)).slice(0,count),out=[];
 for(const name of pending){out.push(await N.makeComparisonNative(name));await N.post('comparison-progress.json',{last:name,created:Object.keys(N.comparisons).length,total:N.comparisonTargets.length,savedVerified:false});N.ensureFlags();}
 return {out,created:Object.keys(N.comparisons).length,total:N.comparisonTargets.length,savedVerified:false};
};
N.exportComparisonBatch=async(count=1)=>{
 N.ensureFlags();const pending=N.comparisonTargets.map(name=>'CMP20 / MENU08 / '+name).filter(key=>N.comparisons[key]&&(N.comparisonExportRecords[key]?.id!==N.comparisons[key].id||N.comparisonExportRecords[key]?.comparisonSignature!==N.comparisons[key].getPluginData('v08-comparison-ready'))).slice(0,count),out=[];
 for(const key of pending)out.push(await N.export(key,true));
 return {out,exported:Object.keys(N.comparisonExportRecords).length,total:N.comparisonTargets.length,savedVerified:false};
};
N.makeComparison=()=>{throw Error('Cross-page comparison cloning is disabled. Use await N.makeComparisonBatch(count).');};
return {comparisonNative:true,mode:'foreground-await-only',page:N.comparisonPageName,targets:N.comparisonTargets};
