const N=storage.v08;
if(!N.importSnapshotBatchSequential)N.importSnapshotBatchSequential=N.importSnapshotBatch;
const validateSnapshot=async record=>{
 N.ensureFlags();const {name,filename,sourceFilename,sourceSha256,sha256,resizeAlgorithm}=record,b=N.boards[name],source=N.designExportRecords[name],specHash=N.nativeSpecHash(name);
 if(!b?.getPluginData('v08-ready')||!source)throw Error('Actual native 1920 export is required: '+name);
 if(source.id!==b.id||source.filename!==sourceFilename||source.nativeSpecHash!==specHash||record.nativeSpecHash!==specHash)throw Error('Derived source identity or spec hash differs: '+name);
 if(filename!==N.fileName(name)||JSON.stringify(record.outputSize)!=='[1280,720]'||JSON.stringify(source.outputSize)!=='[1920,1080]')throw Error('Derived output name or dimensions differ: '+name);
 if(!/^[a-f0-9]{64}$/.test(sha256)||!/^[a-f0-9]{64}$/.test(sourceSha256)||typeof resizeAlgorithm!=='string'||!/pillow/i.test(resizeAlgorithm)||!/lanczos/i.test(resizeAlgorithm))throw Error('Derived hash or Pillow LANCZOS metadata is invalid: '+name);
 let verifiedSourceSha=source.sha256;
 if(!verifiedSourceSha){const png=await N.readExportPng(sourceFilename),bytes=png.bytes;if(JSON.stringify(N.readPngSize(bytes))!=='[1920,1080]')throw Error('Actual source PNG dimensions differ: '+name);verifiedSourceSha=await N.sha256(bytes);if(png.sha256!==verifiedSourceSha)throw Error('Actual source PNG JSON SHA-256 differs: '+name);}
 if(verifiedSourceSha!==sourceSha256)throw Error('Actual native source SHA-256 differs: '+name);
 const png=await N.readExportPng(filename),bytes=png.bytes;
 if(JSON.stringify(N.readPngSize(bytes))!=='[1280,720]'||await N.sha256(bytes)!==sha256||png.sha256!==sha256||(record.bytes&&record.bytes!==bytes.length))throw Error('Actual derived PNG size or SHA-256 differs: '+name);
 return {record,board:b,bytes,specHash,verifiedSourceSha};
};
const phaseError=(stage,results,records)=>{const failures=results.flatMap((r,i)=>r.status==='rejected'?[{name:records[i].name,error:String(r.reason)}]:[]);return failures.length?Error('Snapshot '+stage+' failed; source metadata and records were not changed: '+JSON.stringify(failures)):null;};
N.importSnapshotBatch=async(records,count=2)=>{
 const started=Date.now();N.ensureFlags();if(!Array.isArray(records))throw Error('Derived snapshot records must be an array');if(!Number.isInteger(count)||count<1)throw Error('Snapshot batch count must be a positive integer');
 const pending=records.filter(r=>{const existing=N.exportRecords[r.name];return !existing||existing.sha256!==r.sha256||existing.sourceSha256!==r.sourceSha256||existing.nativeSpecHash!==N.nativeSpecHash(r.name)||!N.hasExportSnapshot(r.name);});
 if(!pending.length)return {out:[],pending:0,imported:Object.keys(N.exportRecords).length,parallel:true,savedVerified:false};
 const first=N.boards[pending[0].name];if(!first?.getPluginData('v08-ready'))throw Error('Native source is not ready: '+pending[0].name);
 const page=N.pageForExport(first),selected=pending.filter(r=>N.boards[r.name]&&N.pageForExport(N.boards[r.name]).id===page.id).slice(0,Math.min(2,count));
 if(new Set(selected.map(r=>r.name)).size!==selected.length)throw Error('Duplicate scene names in one snapshot batch');
 await N.activateExportPage(selected.map(r=>r.name));N.ensureFlags();
 const validated=await Promise.allSettled(selected.map(validateSnapshot)),invalid=phaseError('validation',validated,selected);if(invalid)throw invalid;
 const validationMs=Date.now()-started,items=validated.map(r=>r.value),uploadStarted=Date.now();
 const uploaded=await Promise.allSettled(items.map(item=>{N.ensureFlags();return penpot.uploadMediaData(item.record.filename,item.bytes,'image/png');})),uploadError=phaseError('upload',uploaded,selected);if(uploadError)throw uploadError;
 for(let i=0;i<uploaded.length;i++)if(typeof uploaded[i].value?.id!=='string'||!uploaded[i].value.id)throw Error('Snapshot upload returned no media ID: '+selected[i].name);
 const uploadMs=Date.now()-uploadStarted,commitStarted=Date.now();
 // Both independent IO phases succeeded. Only now write to source boards, in order.
 await N.activateExportPage(selected.map(r=>r.name));N.ensureFlags();
 const before=items.map(item=>{const {record,board,specHash,verifiedSourceSha}=item,current=N.designExportRecords[record.name];if(N.boards[record.name]?.id!==board.id||!board.getPluginData('v08-ready')||N.nativeSpecHash(record.name)!==specHash||current?.id!==board.id||current.filename!==record.sourceFilename||current.nativeSpecHash!==specHash||(current.sha256&&current.sha256!==verifiedSourceSha))throw Error('Source changed while snapshot IO was running: '+record.name);return {item,image:board.getPluginData('v08-snapshot-media'),provenance:board.getPluginData('v08-snapshot-provenance'),snapshot:N.snapshots[record.name],exportRecord:N.exportRecords[record.name],sourceSha:current.sha256};});
 const token=penpot.history.undoBlockBegin();
 try{
  for(let i=0;i<items.length;i++){
   const {record,board,specHash}=items[i],media=uploaded[i].value;
   board.setPluginData('v08-snapshot-media',JSON.stringify(media));board.setPluginData('v08-snapshot-provenance',JSON.stringify({sha256:record.sha256,sourceFilename:record.sourceFilename,sourceSha256:record.sourceSha256,resizeAlgorithm:record.resizeAlgorithm,nativeSpecHash:specHash}));
  }
  for(let i=0;i<items.length;i++){
   const {record,board,bytes,specHash,verifiedSourceSha}=items[i],media=uploaded[i].value;
   N.designExportRecords[record.name].sha256=verifiedSourceSha;N.snapshots[record.name]=media;
   N.exportRecords[record.name]={name:record.name,id:board.id,filename:record.filename,bytes:bytes.length,outputSize:[1280,720],sha256:record.sha256,sourceFilename:record.sourceFilename,sourceSha256:record.sourceSha256,resizeAlgorithm:record.resizeAlgorithm,nativeSpecHash:specHash,snapshotMediaId:media.id};
  }
  await N.persistExportRecords();
 }catch(error){
  const rollbackErrors=[];
  try{await N.activateExportPage(selected.map(r=>r.name));N.ensureFlags();}catch(e){rollbackErrors.push('activate: '+String(e));}
  for(const previous of before){const name=previous.item.record.name;try{previous.item.board.setPluginData('v08-snapshot-media',previous.image||'');previous.item.board.setPluginData('v08-snapshot-provenance',previous.provenance||'');}catch(e){rollbackErrors.push(name+': '+String(e));}if(previous.snapshot)N.snapshots[name]=previous.snapshot;else delete N.snapshots[name];if(previous.exportRecord)N.exportRecords[name]=previous.exportRecord;else delete N.exportRecords[name];if(previous.sourceSha===undefined)delete N.designExportRecords[name].sha256;else N.designExportRecords[name].sha256=previous.sourceSha;}
  try{await N.persistExportRecords();}catch(e){rollbackErrors.push('record restore: '+String(e));}
  throw Error('Snapshot commit failed: '+String(error)+(rollbackErrors.length?'; rollback needs readback: '+JSON.stringify(rollbackErrors):'; previous metadata and records restored'));
 }finally{penpot.history.undoBlockFinish(token);}
 const commitMs=Date.now()-commitStarted;const out=items.map((item,i)=>({name:item.record.name,id:item.board.id,mediaId:uploaded[i].value.id}));let progressWarning=null;
 try{await N.post('snapshot-import-progress.json',{last:out[out.length-1].name,page:page.name,imported:Object.keys(N.exportRecords).length,total:N.spec.scenes.length,parallel:true,at:new Date().toISOString(),savedVerified:false});}catch(e){progressWarning=String(e);}
 return {out,page:page.name,pending:pending.length-selected.length,imported:Object.keys(N.exportRecords).length,parallel:true,timingMs:{validation:validationMs,upload:uploadMs,commit:commitMs,total:Date.now()-started},savedVerified:false,...(progressWarning?{progressWarning}:{})};
};
return {snapshotParallel:true,mode:'foreground-await-only',maximumBatch:2,phaseOrder:['parallel validation','parallel upload','sequential metadata and records']};
