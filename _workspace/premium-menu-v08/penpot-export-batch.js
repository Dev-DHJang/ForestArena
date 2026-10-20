const N=storage.v08;
// Native PNG rendering can run together only while all boards share one active page.
N.exportMany=async(names,design=false)=>{
 if(!names.length)return {out:[],exported:Object.keys(design?N.designExportRecords:N.exportRecords).length,savedVerified:false};
 const page=await N.activateExportPage(names);N.ensureFlags();
 const scale=design?1:2/3,records=design?N.designExportRecords:N.exportRecords;
 const results=await Promise.allSettled(names.map(async name=>({name,bytes:await N.boards[name].export({type:'png',scale})}))),out=[];
 for(let i=0;i<results.length;i++){
  const result=results[i];if(result.status!=='fulfilled')throw Error('Render '+names[i]+': '+result.reason);
  const {name,bytes}=result.value,b=N.boards[name],filename=N.fileName(name).replace('-v08.png',design?'-v08-1920.png':'-v08.png');
  const r=await fetch(N.endpoint+'/export/'+filename,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({bytes:Array.from(bytes)})});if(!r.ok)throw Error('Export write '+r.status);
  if(!design){const media=await penpot.uploadMediaData(filename,bytes,'image/png');if(penpot.currentPage.id!==page.id)await penpot.openPage(page);N.ensureFlags();b.setPluginData('v08-snapshot-media',JSON.stringify(media));N.snapshots[name]=media;}
  records[name]={name,id:b.id,filename,bytes:bytes.length,outputSize:design?[1920,1080]:[1280,720],nativeSpecHash:N.nativeSpecHash(name),sha256:await N.sha256(bytes)};
  await N.persistExportRecords();await N.post('export-progress.json',{stage:design?'1920':'1280',exported:Object.keys(records).length,total:N.spec.scenes.length,last:name,page:page.name,at:new Date().toISOString(),savedVerified:false});out.push({name,ok:true});
 }
 return {out,page:page.name,exported:Object.keys(records).length,savedVerified:false};
};
N.exportNextBatch=async(design=false,count=2)=>{
 N.ensureFlags();const records=design?N.designExportRecords:N.exportRecords;
 const ready=N.spec.scenes.filter(s=>N.boards[s.name]?.getPluginData('v08-ready')).sort((a,b)=>Number((N.spec.base||[]).includes(b.name))-Number((N.spec.base||[]).includes(a.name)));
 const pending=ready.filter(s=>{const record=records[s.name];return !record||record.id!==N.boards[s.name].id||record.nativeSpecHash!==N.nativeSpecHash(s.name)||(!design&&!N.hasExportSnapshot(s.name));});
 if(!pending.length)return {out:[],exported:Object.keys(records).length,readySources:ready.length,total:N.spec.scenes.length,pendingReady:0,savedVerified:false};
 const page=N.pageForExport(N.boards[pending[0].name]),names=pending.filter(s=>N.pageForExport(N.boards[s.name]).id===page.id).slice(0,count).map(s=>s.name);
 const result=await N.exportMany(names,design);N.ensureFlags();
 return {...result,readySources:ready.length,total:N.spec.scenes.length,pendingReady:pending.length-names.length};
};
N.exportPngUrl=filename=>{if(typeof filename!=='string'||!/^[A-Za-z0-9_-]+[.]png$/.test(filename))throw Error('Invalid export PNG filename');return N.endpoint+'/_workspace/premium-menu-v08/exports/'+encodeURIComponent(filename);};
N.readPngSize=bytes=>{if(bytes.length<24||[137,80,78,71,13,10,26,10].some((v,i)=>bytes[i]!==v))throw Error('Invalid PNG bytes');const view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);return [view.getUint32(16),view.getUint32(20)];};
N.exportPngBytesUrl=filename=>{N.exportPngUrl(filename);return N.endpoint+'/png-bytes/'+encodeURIComponent(filename)+'.json';};
N.readExportPng=async filename=>{
 const response=await fetch(N.exportPngBytesUrl(filename));if(!response.ok)throw Error('PNG byte JSON fetch '+response.status);const result=await response.json();
 if(!Array.isArray(result.bytes)||!Number.isInteger(result.length)||result.length!==result.bytes.length||!result.bytes.every(v=>Number.isInteger(v)&&v>=0&&v<=255)||!/^[a-f0-9]{64}$/.test(result.sha256))throw Error('PNG byte JSON length, byte values or digest are invalid');
 const bytes=new Uint8Array(result.bytes);if(bytes.length!==result.length)throw Error('PNG byte JSON length differs');return {bytes,sha256:result.sha256,length:result.length};
};
N.importSnapshotBatch=async(records,count=2)=>{
 N.ensureFlags();if(!Array.isArray(records))throw Error('Derived snapshot records must be an array');
 const pending=records.filter(r=>{const existing=N.exportRecords[r.name];return !existing||existing.sha256!==r.sha256||existing.sourceSha256!==r.sourceSha256||existing.nativeSpecHash!==N.nativeSpecHash(r.name)||!N.hasExportSnapshot(r.name);});
 if(!pending.length)return {out:[],pending:0,imported:Object.keys(N.exportRecords).length,savedVerified:false};
 const first=N.boards[pending[0].name];if(!first?.getPluginData('v08-ready'))throw Error('Native source is not ready: '+pending[0].name);
 const page=N.pageForExport(first),selected=pending.filter(r=>N.boards[r.name]&&N.pageForExport(N.boards[r.name]).id===page.id).slice(0,Math.min(2,count));
 await N.activateExportPage(selected.map(r=>r.name));N.ensureFlags();const out=[];
 for(const record of selected){
  const {name,filename,sourceFilename,sourceSha256,sha256,resizeAlgorithm}=record,b=N.boards[name],source=N.designExportRecords[name],specHash=N.nativeSpecHash(name);
  if(!b?.getPluginData('v08-ready')||!source)throw Error('Actual native 1920 export is required: '+name);
  if(source.id!==b.id||source.filename!==sourceFilename||source.nativeSpecHash!==specHash||record.nativeSpecHash!==specHash)throw Error('Derived source identity or spec hash differs: '+name);
  if(filename!==N.fileName(name)||JSON.stringify(record.outputSize)!=='[1280,720]'||JSON.stringify(source.outputSize)!=='[1920,1080]')throw Error('Derived output name or dimensions differ: '+name);
  if(!/^[a-f0-9]{64}$/.test(sha256)||!/^[a-f0-9]{64}$/.test(sourceSha256)||typeof resizeAlgorithm!=='string'||!/pillow/i.test(resizeAlgorithm)||!/lanczos/i.test(resizeAlgorithm))throw Error('Derived hash or Pillow LANCZOS metadata is invalid: '+name);
  if(!source.sha256){const png=await N.readExportPng(sourceFilename),bytes=png.bytes;if(JSON.stringify(N.readPngSize(bytes))!=='[1920,1080]')throw Error('Actual source PNG dimensions differ: '+name);const actualSha256=await N.sha256(bytes);if(png.sha256!==actualSha256)throw Error('Actual source PNG JSON SHA-256 differs: '+name);source.sha256=actualSha256;}
  if(source.sha256!==sourceSha256)throw Error('Actual native source SHA-256 differs: '+name);
  const png=await N.readExportPng(filename),bytes=png.bytes;
  if(JSON.stringify(N.readPngSize(bytes))!=='[1280,720]'||await N.sha256(bytes)!==sha256||png.sha256!==sha256||(record.bytes&&record.bytes!==bytes.length))throw Error('Actual derived PNG size or SHA-256 differs: '+name);
  const media=await penpot.uploadMediaData(filename,bytes,'image/png');if(penpot.currentPage.id!==page.id)await penpot.openPage(page);N.ensureFlags();
  b.setPluginData('v08-snapshot-media',JSON.stringify(media));b.setPluginData('v08-snapshot-provenance',JSON.stringify({sha256,sourceFilename,sourceSha256,resizeAlgorithm,nativeSpecHash:specHash}));N.snapshots[name]=media;
  N.exportRecords[name]={name,id:b.id,filename,bytes:bytes.length,outputSize:[1280,720],sha256,sourceFilename,sourceSha256,resizeAlgorithm,nativeSpecHash:specHash,snapshotMediaId:media.id};
  await N.persistExportRecords();await N.post('snapshot-import-progress.json',{last:name,page:page.name,imported:Object.keys(N.exportRecords).length,total:N.spec.scenes.length,at:new Date().toISOString(),savedVerified:false});N.ensureFlags();out.push({name,id:b.id,mediaId:media.id});
 }
 return {out,page:page.name,pending:pending.length-selected.length,imported:Object.keys(N.exportRecords).length,savedVerified:false};
};
N.makeLegacyPrototypeBatch=async(count=4)=>{
 N.ensureFlags();if(penpot.currentPage.id!==N.proto.id)await penpot.openPage(N.proto);N.ensureFlags();
 const pending=N.spec.scenes.filter(s=>!N.protoMap[s.name]?.getPluginData('v08-prototype')).slice(0,count),out=[];
 for(const spec of pending){out.push(N.makePrototype(spec,N.spec.scenes.indexOf(spec)));await N.post('prototype-progress.json',{stage:'snapshots',last:spec.name,total:N.spec.scenes.length,savedVerified:false});N.ensureFlags();}
 return {out,created:N.spec.scenes.filter(s=>N.protoMap[s.name]?.getPluginData('v08-prototype')).length,total:N.spec.scenes.length,savedVerified:false};
};
N.wireLegacyPrototypeBatch=async(count=12)=>{
 N.ensureFlags();if(penpot.currentPage.id!==N.proto.id)await penpot.openPage(N.proto);N.ensureFlags();
 if(!N.spec.scenes.every(s=>N.protoMap[s.name]?.getPluginData('v08-prototype')))throw Error('Create every prototype destination before wiring');
 const pending=N.spec.scenes.filter(s=>!N.protoMap[s.name]?.getPluginData('v08-wired')).slice(0,count),out=[];
 for(const spec of pending){out.push(N.wirePrototype(spec));await N.post('prototype-progress.json',{stage:'wiring',last:spec.name,total:N.spec.scenes.length,savedVerified:false});N.ensureFlags();}
 return {out,wired:N.spec.scenes.filter(s=>N.protoMap[s.name]?.getPluginData('v08-wired')).length,total:N.spec.scenes.length,savedVerified:false};
};
N.startExports=()=>{throw Error('Background export is disabled. Use await N.exportNextBatch(design,count), then verify the saved version.');};
N.startPrototypes=()=>{throw Error('Background editing is disabled. Use foreground makePrototypeBatch/wirePrototypeBatch from penpot-prototype-fast.js.');};
return {exportBatch:true,mode:'foreground-await-only'};
