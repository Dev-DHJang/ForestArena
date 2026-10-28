"""Synthetic delivery-verifier checks only; never validates the live delivery."""
import copy
import json
from pathlib import Path
import tempfile

from PIL import Image

from check_delivery import TASK, WIDE_TARGETS, check_delivery, digest, local_path, native_hashes, png_record, scene_filename, validate_manual, validate_outputs
from runtime_source_ids import registry_candidates, existing_runtime_ids


def main():
    checks=[]
    def rejected(label, function):
        try: function()
        except (ValueError, FileNotFoundError, KeyError): checks.append(label)
        else: raise AssertionError('Invalid fixture accepted: '+label)
    with tempfile.TemporaryDirectory() as folder:
        task=Path(folder);(task/'exports').mkdir()
        missing=check_delivery(task,task)
        assert missing['status']=='FAIL' and missing['errors']
        checks.append('missing final evidence fails; never reports partial PASS')
        scene={'name':'한글 / 🐰','elements':[{'text':'한글','x':1.0,'ratio':.6666666666666666}]}
        spec_path=task/'scene-spec.json';spec_path.write_text(json.dumps({'scenes':[scene]},ensure_ascii=False))
        first=native_hashes(spec_path)[scene['name']]
        spec_path.write_text(json.dumps({'scenes':[scene]},ensure_ascii=True,indent=2))
        assert native_hashes(spec_path)[scene['name']]==first
        checks.append('current scene hash uses Node JSON.stringify, including Korean/emoji/float formatting')
        sources={};hashes={};graph={};records={'designExports':[],'scenes':[],'comparisons':[]}
        def record(name,filename,size):
            path=task/'exports'/filename;Image.new('RGBA',size,(17,24,28,255)).save(path)
            return {'name':name,'id':'source-'+name,'filename':filename,'outputSize':list(size),'bytes':path.stat().st_size,'sha256':digest(path),'nativeSpecHash':'current'}
        for index,name in enumerate(WIDE_TARGETS):
            sources[name]={'id':'source-'+name,'prototypeId':'proto-'+name};hashes[name]='current'
            filename=scene_filename(name);large=record(name,filename.replace('-v08.png','-v08-1920.png'),(1920,1080));small=record(name,filename,(1280,720));small.update(sourceFilename=large['filename'],sourceSha256=large['sha256'],snapshotMediaId='media-'+name,resizeAlgorithm='Pillow 12 Image.Resampling.LANCZOS')
            records['designExports'].append(large);records['scenes'].append(small);graph[name]={'expectedSnapshotImageId':'media-'+name,'snapshotImageId':'media-'+name}
            comparison_name='CMP20 / MENU08 / '+name;wide=record(comparison_name,scene_filename(comparison_name),(1600,720));wide.update(comparisonSignature='native-center-v1:current');records['comparisons'].append(wide)
        result=validate_outputs(task,{},hashes,sources,records,graph);assert result['native1920']==result['preview1280']==result['wide20x9']==5
        checks.append('all current native/preview/wide files independently decoded and SHA/identity/provenance checked')
        for label,mutate in [
            ('stale native spec hash rejected',lambda r:r['designExports'][0].update(nativeSpecHash='stale')),
            ('preview wrong source SHA rejected',lambda r:r['scenes'][0].update(sourceSha256='0'*64)),
            ('preview wrong media ID rejected',lambda r:r['scenes'][0].update(snapshotMediaId='wrong')),
            ('missing output scene rejected',lambda r:r['designExports'].pop()),
            ('missing 20:9 comparison rejected',lambda r:r['comparisons'].pop()),
            ('stale comparison signature rejected',lambda r:r['comparisons'][0].update(comparisonSignature='old')),
            ('recorded PNG size mismatch rejected',lambda r:r['designExports'][0].update(outputSize=[1,1])),
            ('duplicate output filename rejected',lambda r:r['designExports'][1].update(filename=r['designExports'][0]['filename'])),
            ('rejected aggregate capture provenance rejected',lambda r:r['designExports'][0].update(pageCaptureSha256='0'*64)),
        ]:
            altered=copy.deepcopy(records);mutate(altered);rejected(label,lambda:validate_outputs(task,{},hashes,sources,altered,graph))
        path=task/'exports'/records['designExports'][0]['filename'];path.write_bytes(path.read_bytes()+b'changed')
        rejected('actual PNG bytes differing from recorded SHA rejected',lambda:png_record(task,records['designExports'][0],(1920,1080)))
        rejected('artifact path traversal rejected',lambda:local_path(task,'../outside.png'))
        runtime=task/'runtime';runtime.mkdir();(runtime/'same.png').write_bytes(b'exact source bytes');(runtime/'different.png').write_bytes(b'changed source bytes')
        (task/'forest_arena/data').mkdir(parents=True)
        registry={'assets':[{'id':'fa.exact','relative_path':'ui/same.png','path':'res://runtime/same.png'},{'id':'fa.wrong-bytes','relative_path':'ui/same.png','path':'res://runtime/different.png'},{'id':'fa.wrong-basename','relative_path':'ui/other.png','path':'res://runtime/same.png'}]}
        registry_path=task/'forest_arena/data/resource_registry.json';registry_path.write_text(json.dumps(registry));registry_before=registry_path.read_bytes()
        candidates=registry_candidates(task);exact=digest(runtime/'same.png')
        assert existing_runtime_ids('workspace/same.png',exact,candidates)==['fa.exact']
        checks.append('existing runtime ID requires matching basename and actual file SHA; same name with wrong bytes and other name with same bytes excluded')
        assert existing_runtime_ids('workspace/same.png','0'*64,candidates)==[] and existing_runtime_ids('workspace/missing.png',exact,candidates)==[]
        checks.append('absent basename or unmatched source hash creates no runtime ID')
        assert registry_path.read_bytes()==registry_before
        checks.append('runtime registry remains byte-for-byte unchanged during metadata lookup')
        name=WIDE_TARGETS[0];step={'step':1,'fromScene':name,'controlName':'BUTTON / 뒤로','expectedArrivalScene':name}
        plan={'specSha256':'spec-sha','cases':[{'id':'NAV-TEST','startScene':name,'steps':[step]}]}
        actual=copy.deepcopy(plan);actual['cases'][0]['executionStatus']='PASS';actual['cases'][0]['steps'][0].update(executionStatus='PASS',actualArrivalFrameId=sources[name]['prototypeId'])
        assert validate_manual(plan,actual,sources,'spec-sha')=={'manualCases':1,'manualSteps':1}
        checks.append('executed manual step matches exact expected actual prototype ID')
        for label,mutate in [
            ('manual NOT_RUN rejected',lambda a:a['cases'][0]['steps'][0].update(executionStatus='NOT_RUN')),
            ('wrong observed arrival ID rejected',lambda a:a['cases'][0]['steps'][0].update(actualArrivalFrameId='wrong')),
            ('missing manual case rejected',lambda a:a['cases'].clear()),
            ('manual expected destination tampering rejected',lambda a:a['cases'][0]['steps'][0].update(expectedArrivalScene='different')),
        ]:
            altered=copy.deepcopy(actual);mutate(altered);rejected(label,lambda:validate_manual(plan,altered,sources,'spec-sha'))
    report={'passed':True,'tests':len(checks),'checks':checks,'note':'Synthetic local file fixtures only. Final actual delivery checker was not run; no Penpot API, browser, runtime source or delivery evidence was modified.'}
    (TASK/'delivery-verifier-fixture-check.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False))


if __name__=='__main__': main()
