"""Local current-spec output status/driver tests; no Penpot or browser access."""
import contextlib
import io
import json
import subprocess
import tempfile
from pathlib import Path

from penpot_foreground import EXPORT_STATUS_CODE, TASK, run_exports


def check_status():
    js = r'''
const fs=require('fs'),code=JSON.parse(fs.readFileSync(0,'utf8')).code;
const sha='a'.repeat(64),other='b'.repeat(64),recipe='Pillow 12 Image.Resampling.LANCZOS';
function fixture(){const N={spec:{scenes:[{name:'A'},{name:'B'}]},boards:{},designExportRecords:{},exportRecords:{},snapshots:{},ensureFlags(){},nativeSpecHash:()=> 'current',fileName:n=>n+'-v08.png'};
for(const name of ['A','B']){const id='board-'+name,media={id:'media-'+name};N.boards[name]={id,name,data:{'v08-ready':'true','v08-snapshot-media':JSON.stringify(media),'v08-snapshot-provenance':JSON.stringify({sha256:sha,sourceFilename:name+'-v08-1920.png',sourceSha256:sha,resizeAlgorithm:recipe,nativeSpecHash:'current'})},getPluginData(k){return this.data[k]||'';}};N.designExportRecords[name]={name,id,filename:name+'-v08-1920.png',outputSize:[1920,1080],sha256:sha,nativeSpecHash:'current'};N.exportRecords[name]={name,id,filename:name+'-v08.png',outputSize:[1280,720],sha256:sha,sourceFilename:name+'-v08-1920.png',sourceSha256:sha,resizeAlgorithm:recipe,nativeSpecHash:'current',snapshotMediaId:media.id};N.snapshots[name]=media;}return N;}
const cases=[['complete',()=>{},2,2],['stale-native-spec',N=>N.designExportRecords.A.nativeSpecHash='old',1,1],['stale-small-spec',N=>N.exportRecords.A.nativeSpecHash='old',2,1],['wrong-source-sha',N=>N.exportRecords.A.sourceSha256=other,2,1],['wrong-provenance-source-sha',N=>{const p=JSON.parse(N.boards.A.data['v08-snapshot-provenance']);p.sourceSha256=other;N.boards.A.data['v08-snapshot-provenance']=JSON.stringify(p);},2,1],['wrong-media-id',N=>N.snapshots.A={id:'wrong'},2,1],['missing-native-ready',N=>N.boards.A.data['v08-ready']='',1,1],['malformed-provenance',N=>N.boards.A.data['v08-snapshot-provenance']='bad json',2,1],['invalid-native-sha',N=>N.designExportRecords.A.sha256='bad',1,1],['wrong-native-id',N=>N.designExportRecords.A.id='wrong',1,1],['wrong-1280-size',N=>N.exportRecords.A.outputSize=[1920,1080],2,1],['extra-obsolete-records',N=>{N.designExportRecords.OLD={};N.exportRecords.OLD={};},2,2]];
for(const [name,mutate,native,small] of cases){const N=fixture();mutate(N);const r=new Function('storage',code)({v08:N});if(r.total!==2||r.currentNative!==native||r.current1280!==small||r.missingNative.length!==2-native||r.missingSnapshots.length!==2-small)throw Error(name+' '+JSON.stringify(r));}
process.stdout.write(JSON.stringify({passed:cases.length,names:cases.map(x=>x[0])}));
'''
    result = subprocess.run(['node', '-e', js], input=json.dumps({'code': EXPORT_STATUS_CODE}), text=True, capture_output=True, check=True)
    return json.loads(result.stdout)


class Fake:
    def __init__(self, task, stale_small=True, blocked=False):
        self.task=task; self.native=2; self.small=1 if stale_small else 2; self.blocked=blocked; self.calls=[]
        # All old records already exist, so record lengths equal total throughout.
        (task/'export-records.json').write_text(json.dumps({'designExports':[{'name':'A'},{'name':'B'}],'scenes':[{'name':'A'},{'name':'B'}]}))
        (task/'derived-snapshots.json').write_text(json.dumps([{'name':'A'},{'name':'B'}]))
    def __call__(self, code):
        self.calls.append(code)
        if 'export-driver:render' in code:
            assert 'exportNextBatch(true,1)' in code
            return {'out':[],'page':'original-page'}
        if 'export-driver:status' in code:
            return {'total':2,'currentNative':self.native,'current1280':self.small,'missingNative':[],'missingSnapshots':['A'] if self.small<2 else []}
        if 'export-driver:import' in code:
            assert '[{"name":"A"}],1' in code
            if self.blocked:return {'out':[]}
            self.small=2;return {'out':[{'name':'A'}]}
        if 'export-driver:save' in code:return {'label':'mock','createdAt':'mock'}
        raise AssertionError(code)


def main():
    status=check_status();tests=[{'name':name,'passed':True} for name in status['names']]
    with tempfile.TemporaryDirectory() as temp:
        task=Path(temp);fake=Fake(task);resized=[]
        with contextlib.redirect_stdout(io.StringIO()):result=run_exports(3,1,invoke=fake,task=task,resize=lambda:resized.append(True))
        assert result['current1280']==2 and len(resized)==1
        assert any('export-driver:import' in code for code in fake.calls)
        tests.append({'name':'full-old-record-count-does-not-skip-stale-snapshot-import','passed':True})
    with tempfile.TemporaryDirectory() as temp:
        task=Path(temp);fake=Fake(task,blocked=True)
        try:
            with contextlib.redirect_stdout(io.StringIO()):run_exports(3,1,invoke=fake,task=task,resize=lambda:None)
        except RuntimeError as exc:assert 'No current-spec export progress' in str(exc)
        else:raise AssertionError('Blocked provenance repair was accepted')
        assert not any('export-driver:save' in code for code in fake.calls)
        tests.append({'name':'unchanged-import-refusal-cannot-report-done','passed':True})
    with tempfile.TemporaryDirectory() as temp:
        task=Path(temp);fake=Fake(task)
        def missing_native_png():raise FileNotFoundError('missing native PNG')
        try:
            run_exports(1,1,invoke=fake,task=task,resize=missing_native_png)
        except FileNotFoundError:pass
        else:raise AssertionError('Missing PNG assertion swallowed')
        tests.append({'name':'real-resize-source-file-error-stops-driver','passed':True})
    report={'scope':'Local mock only; no API, browser, real rendering or save executed','passed':len(tests),'failed':0,'tests':tests}
    (TASK/'export-driver-check.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False))


if __name__=='__main__':main()
