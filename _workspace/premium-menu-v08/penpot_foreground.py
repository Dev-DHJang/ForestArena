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

EXPORT_STATUS_CODE = """const N=storage.v08;N.ensureFlags();
const missingNative=[],missingSnapshots=[];let currentNative=0,current1280=0;
const parse=value=>{try{return JSON.parse(value||'null');}catch{return null;}},sha=value=>typeof value==='string'&&/^[a-f0-9]{64}$/.test(value),size=(value,w,h)=>Array.isArray(value)&&value.length===2&&value[0]===w&&value[1]===h;
for(const spec of N.spec.scenes){
 const name=spec.name,b=N.boards[name],native=N.designExportRecords[name],small=N.exportRecords[name],hash=N.nativeSpecHash(name),filename=N.fileName(name);
 const nativeOK=b?.getPluginData('v08-ready')==='true'&&b.name===name&&native?.name===name&&native.id===b.id&&native.nativeSpecHash===hash&&native.filename===filename.replace('-v08.png','-v08-1920.png')&&size(native.outputSize,1920,1080)&&sha(native.sha256);
 if(nativeOK)currentNative++;else missingNative.push(name);
 const media=parse(b?.getPluginData('v08-snapshot-media')),provenance=parse(b?.getPluginData('v08-snapshot-provenance'));
 const snapshotOK=nativeOK&&small?.name===name&&small.id===b.id&&small.filename===filename&&size(small.outputSize,1280,720)&&small.nativeSpecHash===hash&&sha(small.sha256)&&small.sourceFilename===native.filename&&small.sourceSha256===native.sha256&&typeof small.resizeAlgorithm==='string'&&/pillow/i.test(small.resizeAlgorithm)&&/lanczos/i.test(small.resizeAlgorithm)&&!!media?.id&&media.id===N.snapshots[name]?.id&&media.id===small.snapshotMediaId&&provenance?.sha256===small.sha256&&provenance.sourceFilename===native.filename&&provenance.sourceSha256===native.sha256&&provenance.nativeSpecHash===hash&&provenance.resizeAlgorithm===small.resizeAlgorithm;
 if(snapshotOK)current1280++;else missingSnapshots.push(name);
}
return {total:N.spec.scenes.length,currentNative,current1280,missingNative,missingSnapshots};"""


def export_status(invoke=call):
 return invoke('/*export-driver:status*/\n'+EXPORT_STATUS_CODE)


def run_exports(rounds,batch=1,invoke=call,task=TASK,resize=None):
 """Serial current-spec render/import loop; old record totals cannot finish it."""
 import subprocess
 import time
 if batch not in (1,2):raise ValueError('Export batch count must be 1 or 2')
 task=Path(task);prior=task/'export-foreground-progress.json';last_saved=json.loads(prior.read_text()).get('savedCheckpoint',0) if prior.exists() else 0
 if resize is None:
  def resize():
   subprocess.run([sys.executable,str(task/'resize_exports.py')],check=True,capture_output=True,text=True)
 for i in range(rounds):
  started=time.monotonic()
  r=invoke('/*export-driver:render*/\nreturn await storage.v08.exportNextBatch(true,'+str(batch)+');')
  render_seconds=round(time.monotonic()-started,3)
  # Keep the existing real-file/hash assertions; missing native PNGs are errors.
  resize()
  derived=json.loads((task/'derived-snapshots.json').read_text())
  status=export_status(invoke)
  names={item['name'] for item in r['out']}
  if not names:
   names=set(status['missingSnapshots'][:batch])
  selected=[x for x in derived if x['name'] in names]
  if names.difference(x['name'] for x in selected):raise RuntimeError('Current derived snapshots unavailable: '+', '.join(sorted(names.difference(x['name'] for x in selected))))
  before=(status['currentNative'],status['current1280'])
  imported=invoke('/*export-driver:import*/\nreturn await storage.v08.importSnapshotBatch('+json.dumps(selected,ensure_ascii=False,separators=(',',':'))+','+str(batch)+');') if selected else None
  status=export_status(invoke)
  done=status['currentNative']==status['total'] and status['current1280']==status['total'] and not status['missingNative'] and not status['missingSnapshots']
  if not done and not r['out'] and (not imported or not imported.get('out')) and (status['currentNative'],status['current1280'])==before:
   raise RuntimeError('No current-spec export progress; native sources, snapshot provenance or import state need repair: '+json.dumps(status,ensure_ascii=False))
  row={'round':i+1,**status,'page':r.get('page'),'savedCheckpoint':last_saved,'reloadVerified':False,'renderSeconds':render_seconds,'snapshotTimingMs':imported.get('timingMs') if imported else None,'roundSeconds':round(time.monotonic()-started,3)}
  if status['currentNative']-last_saved>=24 or done or status['currentNative']==14:
   saved=invoke("/*export-driver:save*/\nconst N=storage.v08;const v=await penpot.currentFile.saveVersion('메뉴 v08 · 현재 설계 출력 "+str(status['currentNative'])+"/'+N.spec.scenes.length);return {label:v.label,createdAt:v.createdAt};")
   last_saved=status['currentNative'];row['savedCheckpoint']=last_saved;row['version']=saved
  (task/'export-foreground-progress.json').write_text(json.dumps(row,ensure_ascii=False,indent=2)+'\n')
  compact={key:value for key,value in row.items() if key not in ('missingNative','missingSnapshots')}
  compact.update(missingNativeCount=len(status['missingNative']),missingSnapshotsCount=len(status['missingSnapshots']),nextMissingNative=status['missingNative'][:3],nextMissingSnapshots=status['missingSnapshots'][:3])
  print(json.dumps(compact,ensure_ascii=False),flush=True)
  if done:return row
 return row if rounds else None

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
  count=int(sys.argv[2]);prior=TASK/'native-foreground-progress.json';last_saved=json.loads(prior.read_text()).get('savedCheckpoint',0) if prior.exists() else 0
  for i in range(count):
   r=call("const N=storage.v08;N.stopRequested=false;return await N.makeBatch(2);")
   row={'batch':i+1,'readyInMemory':r['ready'],'total':r['total'],'last':r['out'][-1]['name'] if r['out'] else None,'savedCheckpoint':last_saved,'reloadVerified':False}
   if (r['ready']-14)%24==0 or r['ready']==r['total']:
    saved=call("const N=storage.v08;const count=N.readyList().length;const v=await penpot.currentFile.saveVersion('메뉴 v08 · 편집 원본 '+count+'/'+N.spec.scenes.length);return {count,label:v.label,createdAt:v.createdAt};")
    last_saved=saved['count'];row['savedCheckpoint']=last_saved;row['version']=saved
   (TASK/'native-foreground-progress.json').write_text(json.dumps(row,ensure_ascii=False,indent=2))
   print(json.dumps(row,ensure_ascii=False),flush=True)
   if r['ready']==r['total']:break

 elif sys.argv[1]=='exports':
  import argparse
  parser=argparse.ArgumentParser(description='Await current-spec native exports and snapshot imports serially')
  parser.add_argument('rounds',type=int)
  parser.add_argument('batch',type=int,nargs='?',default=1)
  parser.add_argument('--count',type=int,dest='count',default=None)
  args=parser.parse_args(sys.argv[2:])
  run_exports(args.rounds,args.count if args.count is not None else args.batch)
