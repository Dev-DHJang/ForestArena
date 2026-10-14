const N=storage.v07;
N.fileName=(name)=>{
 let h=2166136261;for(const c of name){h^=c.charCodeAt(0);h=Math.imul(h,16777619);}
 return name.replace(/[^A-Za-z0-9_-]/g,'_')+'-'+(h>>>0).toString(16)+'-v07.png';
};
N.exportRecords=N.exportRecords||{};N.snapshots=N.snapshots||{};
N.designExportRecords=N.designExportRecords||{};
N.exportDesign=async(name)=>{
 const b=N.boards[name],bytes=await b.export({type:'png',scale:1}),filename=N.fileName(name).replace('-v07.png','-v07-1920.png');
 const r=await fetch(N.endpoint+'/export/'+filename,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({bytes:Array.from(bytes)})});if(!r.ok)throw Error('Design export '+r.status);
 const rec={name,id:b.id,filename,bytes:bytes.length,outputSize:[1920,1080]};N.designExportRecords[name]=rec;
 await N.post('export-records.json',{scenes:Object.values(N.exportRecords),comparisons:Object.values(N.comparisonExportRecords||{}),designExports:Object.values(N.designExportRecords)});return rec;
};
N.exportDesignMany=async(names)=>{
 const rendered=await Promise.allSettled(names.map(async name=>({name,bytes:await N.boards[name].export({type:'png',scale:1})})));const out=[];
 for(let i=0;i<rendered.length;i++){
  const item=rendered[i];if(item.status!=='fulfilled'){out.push({name:names[i],error:String(item.reason)});continue;}
  const {name,bytes}=item.value,filename=N.fileName(name).replace('-v07.png','-v07-1920.png');
  const r=await fetch(N.endpoint+'/export/'+filename,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({bytes:Array.from(bytes)})});if(!r.ok)throw Error('Design export '+r.status);
  N.designExportRecords[name]={name,id:N.boards[name].id,filename,bytes:bytes.length,outputSize:[1920,1080]};out.push({name,ok:true});
 }
 await N.post('export-records.json',{scenes:Object.values(N.exportRecords),comparisons:Object.values(N.comparisonExportRecords||{}),designExports:Object.values(N.designExportRecords)});return {out,designs:Object.keys(N.designExportRecords).length};
};
N.export=async(name,comparison=false)=>{
 const b=(comparison?N.comparisons:N.boards)[name];if(!b)throw Error('Missing export board '+name);
 const bytes=await b.export({type:'png',scale:2/3});const filename=N.fileName(name);
 const r=await fetch(N.endpoint+'/export/'+filename,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({bytes:Array.from(bytes)})});
 if(!r.ok)throw Error('Export '+r.status);
 const rec={name,id:b.id,filename,bytes:bytes.length,outputSize:[Math.round(b.width*2/3),Math.round(b.height*2/3)]};
 (comparison?N.comparisonExportRecords:N.exportRecords)[name]=rec;
 if(!comparison){N.snapshots[name]=await penpot.uploadMediaData(filename,bytes,'image/png');N.boards[name].setPluginData('v07-snapshot-media',JSON.stringify(N.snapshots[name]));}
 await N.post('export-records.json',{scenes:Object.values(N.exportRecords),comparisons:Object.values(N.comparisonExportRecords||{}),designExports:Object.values(N.designExportRecords)});
 return rec;
};
N.protoMap=N.protoMap||{};
N.makePrototype=(spec,index)=>{
 let b=N.protoMap[spec.name];if(!b){b=N.board(N.proto,'PROTO / '+spec.name,90000+(index%5)*2120,Math.floor(index/5)*1280);N.protoMap[spec.name]=b;}
 if(b.getPluginData('v07-prototype'))return {name:spec.name,existing:true};
 for(const c of b.children){c.setPluginData('v07-original-proto-hidden',String(c.hidden));c.hidden=true;}
 const img=N.snapshots[spec.name];if(!img)throw Error('Missing snapshot '+spec.name);
 const s=N.rect(b,'SNAPSHOT / v07',0,0,1920,1080,null,1,0);s.fills=[{fillImage:img,fillOpacity:1}];s.setPluginData('premium-menu-v07','true');
 b.setPluginData('v07-prototype',spec.name);
 return {name:spec.name,id:b.id};
};
N.wirePrototype=(spec)=>{
 const b=N.protoMap[spec.name];if(b.getPluginData('v07-wired'))return {name:spec.name,existing:true};
 const lastShade=spec.elements.map(e=>e.name).lastIndexOf('Modal shade');
 let count=0;for(const e of spec.elements.slice(lastShade+1)){
  if(!['button','hotspot'].includes(e.kind)||!e.dest||e.state==='disabled')continue;
  const dest=N.protoMap[e.dest];if(!dest)throw Error('Missing destination '+spec.name+' -> '+e.dest);
  const s=N.rect(b,'HIT07 / '+e.name,e.x,e.y,e.w,e.h,null,1,0);
  s.fills=[{fillColor:N.C.bg,fillOpacity:0}];
  s.setPluginData('premium-menu-v07','true');s.setPluginData('v07-control',JSON.stringify({dest:e.dest,state:e.state||'default',legacy:e.legacy||e.name}));
  s.addInteraction('click',{type:'navigate-to',destination:dest,animation:{type:'dissolve',duration:200,easing:'ease-out'}});count++;
 }
 b.setPluginData('v07-wired','true');return {name:spec.name,count};
};
N.comparisons=N.comparisons||{};N.comparisonExportRecords=N.comparisonExportRecords||{};
N.makeComparison=(name,index)=>{
 const key='CMP20 / MENU07 / '+name;if(N.comparisons[key])return {name:key,existing:true};
 if(N.pageFor&&N.pageFor[name].id!==penpot.currentPage.id)throw Error('Comparison source page is not active');
 const source=N.boards[name],page=penpot.currentPage;
 const b=N.board(page,key,112000,index*1280,2400,1080);
 const bg=N.spec.scenes.find(s=>s.name===name).elements.find(e=>e.kind==='image');
 const s=N.rect(b,'20:9 forest extension',0,0,2400,1080,null,1,0);s.fills=[{fillImage:N.media[bg.key],fillOpacity:1}];
 N.rect(b,'20:9 quiet extension',0,0,2400,1080,N.C.bg,.58,0);
 const content=penpot.createBoard();content.name='1920 × 1080 unchanged center';content.resize(1920,1080);content.fills=[];content.clipContent=true;N.put(b,content,240,0);
 for(const s of source.children.filter(s=>s.getPluginData('premium-menu-v07')==='true')){const c=s.clone();N.put(content,c,s.x-source.x,s.y-source.y);}
 b.exports=[{type:'png',scale:2/3,suffix:'-v07'}];b.setPluginData('premium-menu-v07','comparison');N.comparisons[key]=b;return {name:key,id:b.id};
};
return {finishHelpers:true};
