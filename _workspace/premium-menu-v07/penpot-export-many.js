const N=storage.v07;
// Read-only PNG rendering may run together; file writes and media uploads remain sequential.
N.exportMany=async(names)=>{
 const results=await Promise.allSettled(names.map(async name=>({name,bytes:await N.boards[name].export({type:'png',scale:2/3})})));
 const out=[];
 for(let i=0;i<results.length;i++){
  const result=results[i];
  if(result.status!=='fulfilled'){out.push({name:names[i],error:String(result.reason)});continue;}
  const {name,bytes}=result.value,filename=N.fileName(name),b=N.boards[name];
  const response=await fetch(N.endpoint+'/export/'+filename,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({bytes:Array.from(bytes)})});
  if(!response.ok)throw Error('Export write failed');
  N.exportRecords[name]={name,id:b.id,filename,bytes:bytes.length,outputSize:[1280,720]};
  N.snapshots[name]=await penpot.uploadMediaData(filename,bytes,'image/png');
  b.setPluginData('v07-snapshot-media',JSON.stringify(N.snapshots[name]));
  await N.post('export-records.json',{scenes:Object.values(N.exportRecords),comparisons:Object.values(N.comparisonExportRecords),designExports:Object.values(N.designExportRecords)});
  await N.post('progress.json',{stage:'all-exports',count:Object.keys(N.exportRecords).length,total:81,designCount:Object.keys(N.designExportRecords).length});
  out.push({name,ok:true});
 }
 return {out,exported:Object.keys(N.exportRecords).length};
};
return {exportManyReady:true};
