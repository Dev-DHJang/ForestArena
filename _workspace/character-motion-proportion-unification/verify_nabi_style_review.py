"""Strict technical review and optional hash freeze, never grants user approval."""
from pathlib import Path
import argparse
import hashlib
import json
from PIL import Image, ImageDraw
from stage_style_proofs import matte
from install_approved_myo import check as check_installed_myo

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
BATCH = WORK / '07_nabi-style-locked'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main(freeze=False):
    report_path = BATCH / '04_review/29-motion-report.json'
    report = json.loads(report_path.read_text())
    baseline = json.loads((WORK / '01_baseline.json').read_text())
    entries = {e['visual_state_id']: e for e in baseline['runtime_entries'] if e['character_id'] == 'nabi'}
    samples = json.loads((WORK / '03_sample_approval.json').read_text())
    idle = next(s for s in samples['samples'] if s['character_id'] == 'nabi')
    assert samples['user_approved'] and sha(ROOT / idle['path']) == idle['sha256']
    assert len(report['states']) == 29 and report['approved_count'] == 1 and report['pending_count'] == 28
    assert {r['visual_state_id'] for r in report['states']} == set(entries)
    assert len(list((BATCH / '04_review').glob('*/*-r01-clean.png'))) == 29
    inspection = json.loads((BATCH / '04_review/inspection/report.json').read_text())
    assert len(inspection) == 28 and not any(r['source_edge_touch_frames'] for r in inspection)
    assert json.loads((BATCH / '04_review/inspection/inspection-failures.json').read_text()) == []
    refs = json.loads((BATCH / '01_style_reference/selection.json').read_text())
    for path, expected in zip(refs['reference_paths'], refs['reference_sha256']):
        assert sha(Path(path)) == expected
    frozen = []
    for row in report['states']:
        state = row['visual_state_id']
        path = ROOT / row['review_path']
        assert path.name == f'{state}-r01-clean.png' and sha(path) == row['review_sha256']
        image = Image.open(path)
        image.load()
        assert image.size == (512, 512) and image.mode == 'RGBA' and image.getchannel('A').getextrema() == (0, 255)
        hashes = []
        for i in range(16):
            frame = image.crop((i % 4 * 128, i // 4 * 128, (i % 4 + 1) * 128, (i // 4 + 1) * 128))
            box = frame.getbbox()
            assert box and min(box[:2]) >= 2 and max(box[2:]) <= 126, (state, i, box)
            digest = hashlib.sha256(frame.tobytes()).hexdigest()
            if state != 'idle':
                assert digest == row['frames'][i]['rgba_sha256']
            hashes.append(digest)
        assert len(set(hashes)) == 16
        assert row['user_approved'] == (state == 'idle')
        assert row['original_fps'] == entries[state]['fps'] and row['original_loop'] == entries[state]['loop']
        if state == 'idle':
            assert sha(path) == idle['sha256']
        else:
            assert len({r['fixed_scale'] for r in row['frames']}) == 1
            assert abs(row['head_height_after_scale']/26-1) <= .1
            if row['neutral_body_height_after_scale'] is not None:
                assert abs(row['neutral_body_height_after_scale']/72-1) <= .05
            source = Image.open(ROOT / row['source_path'])
            source.load()
            assert source.mode == 'RGBA' and source.getchannel('A').getextrema() == (0, 255)
            assert sha(ROOT / row['source_path']) == row['source_sha256']
        gif = Image.open(path.parent / f'{state}-r01.gif')
        assert gif.n_frames == 16
        for i in range(16):
            gif.seek(i)
            assert gif.info['duration'] == row['gif_durations_ms'][i]
        for suffix in ('preview-128', 'keypose-128'):
            small = Image.open(path.parent / f'{state}-r01-{suffix}.png')
            assert small.size == (128, 128) and small.mode == 'RGBA'
        if state != 'idle':
            files = [{'path': str(p.relative_to(ROOT)), 'sha256': sha(p)} for p in sorted(path.parent.iterdir()) if p.is_file()]
            files.append({'path': row['source_path'], 'sha256': row['source_sha256']})
            frozen.append({'visual_state_id': state, 'user_approved': False, 'review_path': row['review_path'],
                           'review_sha256': row['review_sha256'], 'files': files})
    # Independent of review generation: only the previously approved Myo runtime can differ from start.
    installed = (BATCH / '08_install_receipt.json').exists()
    final90 = (WORK / '08_yu_ran-style-locked/08_install_receipt.json').exists()
    if final90:
        from install_approved_yu_ran import check as check_final90
        check_final90(True)
    elif installed:
        from install_approved_nabi import check as check_cumulative
        check_cumulative(True)
    else:
        check_installed_myo(True)
    qa = BATCH / '04_review/qa-pages'
    qa.mkdir(exist_ok=True)
    for start in range(0, 29, 4):
        board = Image.new('RGB', (1024, 1120), '#243044')
        draw = ImageDraw.Draw(board)
        draw.text((8, 8), f'NABI_STYLE_LOCK_REVIEW_R01 / page{start//4+1} / row-major16', fill='white')
        for n, row in enumerate(report['states'][start:start+4]):
            x, y = n % 2 * 512, 32+n//2*544
            draw.text((x+5, y), row['visual_state_id'], fill='white')
            board.paste(matte(Image.open(ROOT / row['review_path'])), (x, y+20))
        board.save(qa / f'page-{start//4+1:02}.png')
    result = {'regression': 'NABI_STYLE_LOCK_STRUCTURAL_R01', 'status': 'pass', 'motions': 29, 'frames': 464,
              'review_time_approved_count': 1, 'review_time_pending_count': 28,
              'current_approved_count': 29 if installed else 1, 'current_pending_count': 0 if installed else 28,
              'idle_unchanged': True, 'runtime_unchanged': not installed,
              'runtime_scope': 'approved final90 installed; Ja-Hyun preserved' if final90 else ('approved Myo31+Nabi29 installed; others preserved' if installed else 'only approved Myo31 installed; Nabi unchanged'),
              'report_sha256': sha(report_path), 'android_device_tested': False,
              'scope': 'Decode/RGBA/alpha/16 unique cells/padding/fixed scale/2D head and neutral height/FPS/loop/GIF timing/hashes. No automatic all-joint or aesthetic proof.'}
    (BATCH / 'structural-check.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    if freeze:
        target = BATCH / 'pending-review-28.json'
        assert not target.exists(), 'Already frozen; do not change shown candidates'
        record = {'date': '2026-10-17', 'timezone': 'Asia/Seoul', 'status': 'pending-user-approval', 'user_approved': False,
                  'approved_idle_record': str((WORK / '03_sample_approval.json').relative_to(ROOT)),
                  'review_report_sha256': sha(report_path), 'states': frozen,
                  'scope': 'Exact28 new candidates shown with unchanged approved idle; not runtime installation approval.'}
        target.write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n')
    elif (BATCH / 'pending-review-28.json').exists():
        frozen_record = json.loads((BATCH / 'pending-review-28.json').read_text())
        assert frozen_record['review_report_sha256'] == sha(report_path)
        assert len(frozen_record['states']) == 28 and frozen_record['user_approved'] is False
        for state in frozen_record['states']:
            for asset in state['files']:
                assert sha(ROOT / asset['path']) == asset['sha256'], asset['path']
    print('NABI STYLE STRUCTURE: PASS (29 sheets/464 cells; frozen review unchanged; '+('29 approved and installed).' if installed else '28 approval pending; Nabi runtime unchanged).'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--freeze', action='store_true')
    main(parser.parse_args().freeze)
