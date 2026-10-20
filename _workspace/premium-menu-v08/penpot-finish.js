const N=storage.v08;
N.fileName=(name)=>{
 let h=2166136261;for(const c of name){h^=c.charCodeAt(0);h=Math.imul(h,16777619);}
 return name.replace(/[^A-Za-z0-9_-]/g,'_')+'-'+(h>>>0).toString(16)+'-v08.png';
};
N.exportRecords=N.exportRecords||{};N.snapshots=N.snapshots||{};
N.designExportRecords=N.designExportRecords||{};
N.exportPageCache=N.exportPageCache||{};
N.pageForExport=board=>{
 N.ensureFlags();if(N.exportPageCache[board.id])return N.exportPageCache[board.id];
 for(const page of penpot.currentFile.pages)for(const child of page.root.children){N.exportPageCache[child.id]=page;if(child.id===board.id)return page;}
 throw Error('Export board is not a top-level board in this file: '+board.name);
};
N.activateExportPage=async(names,comparison=false)=>{
 N.ensureFlags();const map=comparison?N.comparisons:N.boards,pages=names.map(name=>{const board=map[name];if(!board)throw Error('Missing export board '+name);return N.pageForExport(board);});
 const ids=new Set(pages.map(p=>p.id));if(ids.size!==1)throw Error('One export batch must use one page only: '+[...new Set(pages.map(p=>p.name))].join(', '));
 const page=pages[0];if(!page)throw Error('Export batch is empty');if(penpot.currentPage.id!==page.id)await penpot.openPage(page);N.ensureFlags();if(penpot.viewport&&N.quietExportViewport!==false){penpot.selection=[];penpot.viewport.zoom=1;penpot.viewport.center={x:-3000,y:-3000};}return page;
};
N.sha256=async bytes=>{
 if(typeof crypto!=='undefined'&&crypto&&crypto.subtle&&typeof crypto.subtle.digest==='function')return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))).map(v=>v.toString(16).padStart(2,'0')).join('');
 const response=await fetch(N.endpoint+'/digest/sha256.json',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({bytes:Array.from(bytes)})});if(!response.ok)throw Error('SHA-256 digest service '+response.status);
 const result=await response.json();if(!/^[a-f0-9]{64}$/.test(result.sha256)||result.bytes!==bytes.length)throw Error('SHA-256 digest response is invalid');return result.sha256;
};
N.nativeSpecHash=name=>{const spec=N.spec.scenes.find(s=>s.name===name);if(!spec)return null;let h=2166136261;for(const c of JSON.stringify(spec)){h^=c.charCodeAt(0);h=Math.imul(h,16777619);}return (h>>>0).toString(16);};
N.hasExportSnapshot=name=>{
 const raw=N.boards[name]?.getPluginData('v08-snapshot-media');if(!raw)return false;
 const saved=JSON.parse(raw);if(!saved?.id)return false;if(!N.snapshots[name])N.snapshots[name]=saved;return N.snapshots[name].id===saved.id;
};
N.persistExportRecords=()=>N.post('export-records.json',{scenes:Object.values(N.exportRecords),comparisons:Object.values(N.comparisonExportRecords||{}),designExports:Object.values(N.designExportRecords)});
N.exportDesign=async(name)=>{
 await N.activateExportPage([name]);N.ensureFlags();const b=N.boards[name],bytes=await b.export({type:'png',scale:1}),filename=N.fileName(name).replace('-v08.png','-v08-1920.png');
 const r=await fetch(N.endpoint+'/export/'+filename,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({bytes:Array.from(bytes)})});if(!r.ok)throw Error('Design export '+r.status);
 const rec={name,id:b.id,filename,bytes:bytes.length,outputSize:[1920,1080],nativeSpecHash:N.nativeSpecHash(name),sha256:await N.sha256(bytes)};N.designExportRecords[name]=rec;await N.persistExportRecords();return rec;
};
N.exportDesignMany=async(names)=>{if(!N.exportMany)throw Error('Load penpot-export-batch.js first');return await N.exportMany(names,true);};
N.export=async(name,comparison=false)=>{
 const page=await N.activateExportPage([name],comparison);N.ensureFlags();const b=(comparison?N.comparisons:N.boards)[name],bytes=await b.export({type:'png',scale:2/3}),filename=N.fileName(name);
 const r=await fetch(N.endpoint+'/export/'+filename,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({bytes:Array.from(bytes)})});if(!r.ok)throw Error('Export '+r.status);
 if(!comparison){const media=await penpot.uploadMediaData(filename,bytes,'image/png');if(penpot.currentPage.id!==page.id)await penpot.openPage(page);N.ensureFlags();b.setPluginData('v08-snapshot-media',JSON.stringify(media));N.snapshots[name]=media;}
 const rec={name,id:b.id,filename,bytes:bytes.length,outputSize:[Math.round(b.width*2/3),Math.round(b.height*2/3)],nativeSpecHash:N.nativeSpecHash(comparison?(b.getPluginData('v08-comparison-source')||name.replace('CMP20 / MENU08 / ','')):name),comparisonSignature:comparison?b.getPluginData('v08-comparison-ready')||null:undefined,sha256:await N.sha256(bytes)};(comparison?N.comparisonExportRecords:N.exportRecords)[name]=rec;
 await N.persistExportRecords();return rec;
};
N.protoMap=N.protoMap||Object.fromEntries(N.proto.root.children.filter(b=>b.name.startsWith('PROTO / ')).map(b=>[b.name.slice(8),b]));
N.makePrototype=(spec,index)=>{
 N.ensureFlags();
 let b=N.protoMap[spec.name];if(!b){b=N.board(N.proto,'PROTO / '+spec.name,130000+(index%5)*2120,Math.floor(index/5)*1280);N.protoMap[spec.name]=b;}
 if(b.getPluginData('v08-prototype'))return {name:spec.name,existing:true};
 for(const c of b.children){c.setPluginData('v08-original-proto-hidden',String(c.hidden));c.hidden=true;}
 const img=N.snapshots[spec.name];if(!img)throw Error('Missing snapshot '+spec.name);
 const s=N.rect(b,'SNAPSHOT / v08',0,0,1920,1080,null,1,0);s.fills=[{fillImage:img,fillOpacity:1}];s.setPluginData('premium-menu-v08','true');
 b.setPluginData('v08-prototype',spec.name);
 return {name:spec.name,id:b.id};
};
N.wirePrototype=(spec)=>{
 N.ensureFlags();
 const b=N.protoMap[spec.name];if(b.getPluginData('v08-wired'))return {name:spec.name,existing:true};
 for(const c of b.children.filter(c=>c.name.startsWith('HIT08 / ')&&c.getPluginData('premium-menu-v08')==='true'))c.remove();
 const lastShade=spec.elements.map(e=>e.name).lastIndexOf('MODAL / scrim');
 let count=0;for(const e of spec.elements.slice(lastShade+1)){
  if(!['button','hotspot'].includes(e.kind)||!e.dest||e.state==='disabled')continue;
  const dest=N.protoMap[e.dest];if(!dest)throw Error('Missing destination '+spec.name+' -> '+e.dest);
  const s=N.rect(b,'HIT08 / '+e.name,e.x,e.y,e.w,e.h,null,1,0);
  s.fills=[{fillColor:N.C.bg,fillOpacity:0}];
  s.setPluginData('premium-menu-v08','true');s.setPluginData('v08-control',JSON.stringify({dest:e.dest,state:e.state||'default',legacy:e.legacy||e.name}));
  s.addInteraction('click',{type:'navigate-to',destination:dest,animation:{type:'dissolve',duration:200,easing:'ease-out'}});count++;
 }
 b.setPluginData('v08-wired','true');return {name:spec.name,count};
};
N.comparisons=N.comparisons||{};N.comparisonExportRecords=N.comparisonExportRecords||{};
N.makeComparison=(name,index)=>{
 N.ensureFlags();
 const key='CMP20 / MENU08 / '+name;if(N.comparisons[key])return {name:key,existing:true};
 if(false)throw Error('Comparison source page is not active');
 const source=N.boards[name],page=penpot.currentPage;
 const b=N.board(page,key,156000,index*1280,2400,1080);
 const bg=N.spec.scenes.find(s=>s.name===name).elements.find(e=>e.kind==='image');
 const s=N.rect(b,'20:9 forest extension',0,0,2400,1080,null,1,0);s.fills=[{fillImage:N.media[bg.key],fillOpacity:1}];
 N.rect(b,'20:9 quiet extension',0,0,2400,1080,N.C.bg,.58,0);
 const content=penpot.createBoard();content.name='1920 × 1080 unchanged center';content.resize(1920,1080);content.fills=[];content.clipContent=true;N.put(b,content,240,0);
 for(const s of source.children.filter(s=>s.getPluginData('premium-menu-v08')==='true')){const c=s.clone();N.put(content,c,s.x-source.x,s.y-source.y);}
 b.exports=[{type:'png',scale:2/3,suffix:'-v08'}];b.setPluginData('premium-menu-v08','comparison');N.comparisons[key]=b;return {name:key,id:b.id};
};
return {finishHelpers:true};
