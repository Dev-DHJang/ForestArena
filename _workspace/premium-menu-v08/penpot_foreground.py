"""Serialize official Penpot REPL tasks; each task awaits its actual API work."""
import json,sys,urllib.request,urllib.error
from pathlib import Path
TASK=Path(__file__).resolve().parent

def call(code):
 request=urllib.request.Request('http://localhost:4403/execute',data=json.dumps({'code':code}).encode(),headers={'Content-Type':'application/json'})
 try:
  with urllib.request.urlopen(request,timeout=145) as response: result=json.load(response)
 except urllib.error.HTTPError as exc:raise RuntimeError(exc.read().decode()[:1600]) from None
 if not result.get('success'):raise RuntimeError(str(result)[:1600])
 return result.get('result')

if __name__=='__main__':
 if sys.argv[1]=='load':
  for name in sys.argv[2:]:print(name,json.dumps(call((TASK/name).read_text()),ensure_ascii=False),flush=True)
 elif sys.argv[1]=='bases':
  count=int(sys.argv[2]);rows=[]
  for i in range(count):
   code='''const N=storage.v08;N.ensureFlags();const spec=N.spec.scenes.find(s=>N.spec.base.includes(s.name)&&!N.boards[s.name]?.getPluginData('v08-ready'));if(!spec)return {done:true};const token=penpot.history.undoBlockBegin();try{return await N.make(spec);}finally{penpot.history.undoBlockFinish(token);}'''
   row=call(code);rows.append(row);print(json.dumps(row,ensure_ascii=False),flush=True)
  result=call("const N=storage.v08;const v=await penpot.currentFile.saveVersion('메뉴 v08 · 기본 14화면 편집 원본');return {ready:N.spec.base.filter(n=>N.boards[n]?.getPluginData('v08-ready')).length,label:v.label,createdAt:v.createdAt};")
  (TASK/'native-base-save.json').write_text(json.dumps({'scenes':rows,'version':result},ensure_ascii=False,indent=2))
  print(json.dumps(result,ensure_ascii=False),flush=True)

 elif sys.argv[1]=='native':
  count=int(sys.argv[2]);last_saved=16
  for i in range(count):
   r=call("const N=storage.v08;N.stopRequested=false;return await N.makeBatch(2);")
   row={'batch':i+1,'readyInMemory':r['ready'],'total':r['total'],'last':r['out'][-1]['name'] if r['out'] else None,'savedCheckpoint':last_saved,'reloadVerified':False}
   if (r['ready']-14)%24==0 or r['ready']==r['total']:
    saved=call("const N=storage.v08;const count=N.readyList().length;const v=await penpot.currentFile.saveVersion('메뉴 v08 · 편집 원본 '+count+'/214');return {count,label:v.label,createdAt:v.createdAt};")
    last_saved=saved['count'];row['savedCheckpoint']=last_saved;row['version']=saved
   (TASK/'native-foreground-progress.json').write_text(json.dumps(row,ensure_ascii=False,indent=2))
   print(json.dumps(row,ensure_ascii=False),flush=True)
   if r['ready']==r['total']:break

 elif sys.argv[1]=='exports':
  import subprocess
  rounds=int(sys.argv[2]);last_saved=0
  for i in range(rounds):
   r=call("return await storage.v08.exportNextBatch(true,2);")
   subprocess.run([sys.executable,str(TASK/'resize_exports.py')],check=True,capture_output=True,text=True)
   derived=json.loads((TASK/'derived-snapshots.json').read_text())
   names={item['name'] for item in r['out']}
   if not names:
    missing=call("const N=storage.v08;return N.spec.scenes.filter(s=>!N.hasExportSnapshot(s.name)||!N.exportRecords[s.name]?.sourceSha256).map(s=>s.name);")
    names=set(missing[:2])
   selected=[x for x in derived if x['name'] in names]
   imported=call('return await storage.v08.importSnapshotBatch('+json.dumps(selected,ensure_ascii=False,separators=(',',':'))+',2);') if selected else None
   current=json.loads((TASK/'export-records.json').read_text())
   native=len(current.get('designExports',[]));small=sum(bool(x.get('sourceSha256')) for x in current.get('scenes',[]))
   row={'round':i+1,'native1920':native,'derived1280Imported':small,'expected':214,'page':r.get('page'),'savedCheckpoint':last_saved,'reloadVerified':False}
   if native-last_saved>=24 or (native==214 and small==214) or native==14:
    saved=call("const N=storage.v08;const v=await penpot.currentFile.saveVersion('메뉴 v08 · 실제 출력 '+Object.keys(N.designExportRecords).length+'/214');return {label:v.label,createdAt:v.createdAt};")
    last_saved=native;row['savedCheckpoint']=native;row['version']=saved
   (TASK/'export-foreground-progress.json').write_text(json.dumps(row,ensure_ascii=False,indent=2))
   print(json.dumps(row,ensure_ascii=False),flush=True)
   if native==214 and small==214:break
