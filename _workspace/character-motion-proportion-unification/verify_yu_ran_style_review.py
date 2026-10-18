"""유란 검토 이미지 기술 검사·해시 고정. 사용자 승인을 대신하지 않는다."""
from pathlib import Path
import argparse
import hashlib
import json
from PIL import Image, ImageDraw
from stage_style_proofs import matte
from install_approved_nabi import check as check_cumulative

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
BATCH = WORK / '08_yu_ran-style-locked'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main(freeze=False):
    report_path = BATCH/'04_review/30-motion-report.json'
    report = json.loads(report_path.read_text())
    entries = {e['visual_state_id']:e for e in json.loads((WORK/'01_baseline.json').read_text())['runtime_entries'] if e['character_id']=='yu-ran'}
    samples = json.loads((WORK/'03_sample_approval.json').read_text())
    idle = next(s for s in samples['samples'] if s['character_id']=='yu-ran')
    assert samples['user_approved'] and sha(ROOT/idle['path'])==idle['sha256']
    assert len(report['states'])==30 and report['approved_count']==1 and report['pending_count']==29
    assert {r['visual_state_id'] for r in report['states']}==set(entries)
    assert len(list((BATCH/'04_review').glob('*/*-r01-clean.png')))==30
    inspection = json.loads((BATCH/'04_review/inspection/report.json').read_text())
    assert len(inspection)==29 and not any(r['source_edge_touch_frames'] for r in inspection)
    assert json.loads((BATCH/'04_review/inspection/inspection-failures.json').read_text())==[]
    refs = json.loads((BATCH/'01_style_reference/selection.json').read_text())
    assert sha(ROOT/refs['source_path'])==refs['source_sha256']
    for path,expected in zip(refs['reference_paths'],refs['reference_sha256']):
        assert sha(Path(path))==expected
    frozen=[]
    for row in report['states']:
        state=row['visual_state_id']; path=ROOT/row['review_path']
        assert path.name==f'{state}-r01-clean.png' and sha(path)==row['review_sha256']
        im=Image.open(path); im.load()
        assert im.size==(512,512) and im.mode=='RGBA' and im.getchannel('A').getextrema()==(0,255)
        hashes=[]
        for i in range(16):
            frame=im.crop((i%4*128,i//4*128,(i%4+1)*128,(i//4+1)*128))
            box=frame.getbbox()
            assert box and min(box[:2])>=2 and max(box[2:])<=126,(state,i,box)
            digest=hashlib.sha256(frame.tobytes()).hexdigest()
            if state!='idle': assert digest==row['frames'][i]['rgba_sha256']
            hashes.append(digest)
        assert len(set(hashes))==16
        assert row['user_approved']==(state=='idle')
        assert row['original_fps']==entries[state]['fps'] and row['original_loop']==entries[state]['loop']
        if state=='idle': assert sha(path)==idle['sha256']
        else:
            assert len({r['fixed_scale'] for r in row['frames']})==1
            assert abs(row['head_height_after_scale']/26-1)<=.1
            if row['neutral_body_height_after_scale'] is not None: assert abs(row['neutral_body_height_after_scale']/72-1)<=.05
            source=Image.open(ROOT/row['source_path']); source.load()
            assert source.mode=='RGBA' and source.getchannel('A').getextrema()==(0,255)
            assert sha(ROOT/row['source_path'])==row['source_sha256']
        gif=Image.open(path.parent/f'{state}-r01.gif'); assert gif.n_frames==16
        for i in range(16):
            gif.seek(i); assert gif.info['duration']==row['gif_durations_ms'][i]
        for suffix in ('preview-128','keypose-128'):
            small=Image.open(path.parent/f'{state}-r01-{suffix}.png')
            assert small.size==(128,128) and small.mode=='RGBA'
        if state!='idle':
            files=[{'path':str(p.relative_to(ROOT)),'sha256':sha(p)} for p in sorted(path.parent.iterdir()) if p.is_file()]
            files.append({'path':row['source_path'],'sha256':row['source_sha256']})
            frozen.append({'visual_state_id':state,'user_approved':False,'review_path':row['review_path'],'review_sha256':row['review_sha256'],'files':files})
    installed = (BATCH/'08_install_receipt.json').exists()
    if installed:
        from install_approved_yu_ran import check as check_final90
        check_final90(True)
    else:
        check_cumulative(True)
    qa=BATCH/'04_review/qa-pages'; qa.mkdir(exist_ok=True)
    for start in range(0,30,4):
        board=Image.new('RGB',(1024,1120),'#243044'); draw=ImageDraw.Draw(board)
        draw.text((8,8),f'YU_RAN_STYLE_LOCK_REVIEW_R01 / page{start//4+1} / row-major16',fill='white')
        for n,row in enumerate(report['states'][start:start+4]):
            x,y=n%2*512,32+n//2*544
            draw.text((x+5,y),row['visual_state_id'],fill='white')
            board.paste(matte(Image.open(ROOT/row['review_path'])),(x,y+20))
        board.save(qa/f'page-{start//4+1:02}.png')
    result={'regression':'YU_RAN_STYLE_LOCK_STRUCTURAL_R01','status':'pass','motions':30,'frames':480,
            'review_time_approved_count':1,'review_time_pending_count':29,
            'current_approved_count':30 if installed else 1,'current_pending_count':0 if installed else 29,
            'idle_unchanged':True,'yu_runtime_unchanged':not installed,
            'runtime_scope':'approved Myo31+Nabi29+Yu-Ran30 installed; Ja-Hyun preserved' if installed else 'Yu runtime unchanged; approved Myo31+Nabi29 preserved',
            'report_sha256':sha(report_path),'android_device_tested':False,'scope':'Decode/RGBA/actual alpha/16 unique cells/padding/one scale per motion/2D head and neutral height/FPS/loop/GIF/hash. Manual art and articulation review separate; no all-joint 3D proof.'}
    (BATCH/'structural-check.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    target=BATCH/'pending-review-29.json'
    if freeze:
        assert not target.exists()
        record={'date':'2026-10-17','timezone':'Asia/Seoul','status':'pending-user-approval','user_approved':False,'approved_idle_record':str((WORK/'03_sample_approval.json').relative_to(ROOT)),'review_report_sha256':sha(report_path),'states':frozen,'scope':'Exact29 new candidates; unchanged prior approved idle; no runtime approval.'}
        target.write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
    elif target.exists():
        record=json.loads(target.read_text())
        assert record['review_report_sha256']==sha(report_path) and len(record['states'])==29 and record['user_approved'] is False
        for state in record['states']:
            for asset in state['files']: assert sha(ROOT/asset['path'])==asset['sha256'],asset['path']
    print('YU-RAN STRUCTURE: PASS (30 sheets/480 cells; frozen review unchanged; '+('30 approved and installed).' if installed else '29 approval pending; Yu runtime unchanged).'))

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--freeze',action='store_true')
    main(parser.parse_args().freeze)
