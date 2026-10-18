"""Hash-bound Nabi29 approval and cumulative Myo31+Nabi29 installation check."""
from pathlib import Path
import argparse
import copy
import hashlib
import json
import shutil
import sys
from PIL import Image
import install_approved_myo as myo

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
BATCH = WORK / '07_nabi-style-locked'
MANIFEST = ROOT / 'assets/character/manifest.json'
APPROVAL = BATCH / 'approval-all-29.json'
RECEIPT = BATCH / '08_install_receipt.json'
BACKUP = BATCH / '07_before_install'
sys.path.insert(0, str(ROOT / 'tools/forest_arena'))
from audit_character_motion_visuals import LEGACY_ALIASES

sha, read, write = myo.sha, myo.read, myo.write


def inputs():
    pending = read(BATCH / 'pending-review-28.json')
    report_path = BATCH / '04_review/29-motion-report.json'
    assert pending['user_approved'] is False and len(pending['states']) == 28
    assert sha(report_path) == pending['review_report_sha256']
    for state in pending['states']:
        myo.verify_files(state['files'])
    sample = next(s for s in read(WORK / '03_sample_approval.json')['samples'] if s['character_id'] == 'nabi')
    assert sha(ROOT / sample['path']) == sample['sha256']
    report = read(report_path)
    assert len(report['states']) == 29 and {r['visual_state_id'] for r in report['states']} == {'idle'} | {r['visual_state_id'] for r in pending['states']}
    for row in report['states']:
        assert sha(ROOT / row['review_path']) == row['review_sha256']
        if row['visual_state_id'] == 'idle':
            assert row['review_sha256'] == sample['sha256']
        else:
            assert sha(ROOT / row['source_path']) == row['source_sha256']
    return report, pending, sample


def approve():
    assert not APPROVAL.exists(), 'Do not overwrite approval'
    report, pending, sample = inputs()
    record = {'user_approved': True, 'approved_on': '2026-10-17', 'timezone': 'Asia/Seoul',
              'user_text': '승인한다.', 'approved_count': 29, 'newly_approved_count': 28,
              'approved_states': {r['visual_state_id']: r['review_sha256'] for r in report['states']},
              'review_report_sha256': pending['review_report_sha256'],
              'pending_28_record_sha256': sha(BATCH / 'pending-review-28.json'),
              'approved_idle_record_sha256': sha(WORK / '03_sample_approval.json'),
              'files': [sample] + [f for s in pending['states'] for f in s['files']],
              'scope': 'Exact28 newly shown Nabi candidates plus unchanged previously approved idle; install29 and synchronize two legacy aliases under the approved90-motion plan. No approval of unmade Yu-Ran motions.'}
    # sample uses the same path/hash schema as frozen files.
    write(APPROVAL, record)
    print('NABI APPROVAL: 28 new + prior idle = 29 exact approved motions.')


def approval():
    report, _, _ = inputs()
    approved = read(APPROVAL)
    assert approved['user_approved'] is True and approved['approved_count'] == 29
    assert approved['review_report_sha256'] == sha(BATCH / '04_review/29-motion-report.json')
    myo.verify_files(approved['files'])
    assert approved['approved_states'] == {r['visual_state_id']: r['review_sha256'] for r in report['states']}
    return report, approved


def pack(row):
    image = Image.open(ROOT / row['review_path'])
    image.load()
    assert image.size == (512, 512) and image.mode == 'RGBA' and image.getchannel('A').getextrema() == (0, 255)
    strip = Image.new('RGBA', (2048, 128))
    hashes = []
    for i in range(16):
        x, y = i % 4 * 128, i // 4 * 128
        frame = image.crop((x, y, x+128, y+128))
        box = frame.getbbox()
        assert box and min(box[:2]) >= 2 and max(box[2:]) <= 126
        digest = hashlib.sha256(frame.tobytes()).hexdigest()
        if row['visual_state_id'] != 'idle':
            assert digest == row['frames'][i]['rgba_sha256']
        hashes.append(digest)
        strip.paste(frame, (i*128, 0))
    assert len(set(hashes)) == 16
    return strip


def records(manifest, report):
    result = []
    for row in report['states']:
        matches = [e for e in manifest['assets'] if e.get('character_id') == 'nabi' and e.get('type') == 'animation-runtime' and e.get('visual_state_id') == row['visual_state_id']]
        assert len(matches) == 1
        entry = matches[0]
        assert entry['fps'] == row['original_fps'] and entry['loop'] == row['original_loop']
        target = ROOT / entry['path']
        assert target.resolve().is_relative_to(ROOT / 'assets/character/nabi/animation/runtime')
        frames = ROOT / entry['sprite_frames_path'].removeprefix('res://')
        assert entry['consumer_path'] == entry['sprite_frames_path'] and 'res://'+entry['path'] in frames.read_text()
        result.append((row, entry, target))
    assert len(result) == 29
    return result


def check(installed=True):
    report, _ = approval()
    if not installed:
        myo.check(True)
        current = read(MANIFEST)
        baseline = {r['path']: r for r in read(WORK / '01_baseline.json')['runtime_entries']}
        for alias, canonical in LEGACY_ALIASES.items():
            assert sha(ROOT / alias) == sha(ROOT / canonical) == baseline[canonical]['actual_start_sha256']
        records(current, report)
        print('NABI PREFLIGHT: PASS (29 approved + 2 aliases; existing Myo preserved).')
        return
    receipt = read(RECEIPT)
    current, before = read(MANIFEST), read(BACKUP / 'manifest.json')
    assert sha(MANIFEST) == receipt['installed_manifest_sha256']
    assert sha(BACKUP / 'manifest.json') == read(myo.RECEIPT)['installed_manifest_sha256']
    assert sha(APPROVAL) == receipt['approval_sha256']
    selected = {e['asset_id']: (r, e, p) for r, e, p in records(current, report)}
    assert {k:v for k,v in current.items() if k != 'assets'} == {k:v for k,v in before.items() if k != 'assets'}
    assert [e['asset_id'] for e in current['assets']] == [e['asset_id'] for e in before['assets']]
    for old, new in zip(before['assets'], current['assets']):
        if new['asset_id'] in selected:
            assert {k:v for k,v in old.items() if k not in myo.ALLOWED} == {k:v for k,v in new.items() if k not in myo.ALLOWED}
            assert new['rights']['status'] == old['rights']['status']
            assert new['presentation_scale'] == 1.0 and new['foot_pivot_y'] == 124
        else:
            assert old == new, new['asset_id']
    baseline = read(WORK / '01_baseline.json')
    for rel, expected in baseline['protected_files'].items():
        assert sha(ROOT / rel) == expected, rel
    myo_report, _ = myo.check_approval()
    myo_selected = {e['asset_id']: (r,e,p) for r,e,p in myo.records(current, myo_report)}
    for old in baseline['runtime_entries']:
        assert sha(ROOT / old['sprite_frames_path'].removeprefix('res://')) == old['sprite_frames_start_sha256']
        if old['asset_id'] in selected:
            row, entry, target = selected[old['asset_id']]
            image = Image.open(target)
            assert image.mode == 'RGBA' and image.size == (2048,128) and image.tobytes() == pack(row).tobytes()
            assert sha(target) == entry['sha256']
            assert sha(BACKUP / old['path']) == old['actual_start_sha256']
        elif old['asset_id'] in myo_selected:
            row, entry, target = myo_selected[old['asset_id']]
            assert sha(target) == entry['sha256']
            assert Image.open(target).tobytes() == myo.pack(row).tobytes()
        else:
            assert sha(ROOT / old['path']) == old['actual_start_sha256'], old['path']
    for row in receipt['replacements'] + receipt['aliases']:
        assert sha(ROOT / row['path']) == row['after_sha256']
        assert sha(BACKUP / row['path']) == row['before_sha256']
    for alias, canonical in LEGACY_ALIASES.items():
        assert sha(ROOT / alias) == sha(ROOT / canonical)
    print('CUMULATIVE INSTALL: PASS (Myo31 + Nabi29 exact pixels; 2 Nabi aliases synced; Ja-Hyun30/Yu-Ran30, all SpriteFrames/concepts/combat preserved).')


def install():
    assert not RECEIPT.exists() and not BACKUP.exists(), 'Already installed/backed up; inspect before retry'
    check(False)
    report, approved = approval()
    updated = copy.deepcopy(read(MANIFEST))
    targets = records(updated, report)
    stage = BATCH / '06_runtime_staged'
    assert not stage.exists()
    stage.mkdir()
    for row, _, _ in targets:
        pack(row).save(stage / (row['visual_state_id']+'_16f.png'))
    BACKUP.mkdir()
    shutil.copy2(MANIFEST, BACKUP / 'manifest.json')
    for rel in [e['path'] for _,e,_ in targets] + list(LEGACY_ALIASES):
        saved = BACKUP / rel
        saved.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, saved)
    receipt = {'approved_on': approved['approved_on'], 'approval_sha256': sha(APPROVAL),
               'previous_manifest_sha256': sha(MANIFEST), 'replacements': [], 'aliases': [],
               'scope': '29 approved Nabi sheets + two same-pose legacy aliases; exact review cells, no rescaling; only Nabi metadata changes.'}
    selection = read(BATCH / '01_style_reference/selection.json')
    for row, entry, target in targets:
        previous = sha(target)
        shutil.copy2(stage / (row['visual_state_id']+'_16f.png'), target)
        entry.update(sha256=sha(target), verified_on=approved['approved_on'], presentation_scale=1.0, foot_pivot_y=124)
        entry['creation'] = {'method':'built-in image generation, one approved idle style master; exact approved review-cell packing',
                             'provider':'OpenAI built-in image generation + project-local normalization','version':'character-motion-proportion-unification-nabi-v01'}
        entry['rights'].setdefault('references',[]).append('2026-10-17: User approved all29 remade Nabi motions; external license verification not asserted.')
        entry.setdefault('modifications',[]).append('2026-10-17: Packed exact approved4x4 cells into2048x128, no resize; presentation_scale1.0/foot124; IDs/FPS/loop/combat unchanged.')
        entry['motion_unification'] = {'report_sha256':approved['review_report_sha256'],
                                      'source_path':row.get('source_path',selection['source_path']),
                                      'source_sha256':row.get('source_sha256',selection['source_sha256']),
                                      'review_path':row['review_path'],'review_sha256':row['review_sha256'],
                                      'source_scale':row.get('fixed_motion_scale',72/191),
                                      'approval_record':str(APPROVAL.relative_to(ROOT))}
        receipt['replacements'].append({'path':entry['path'],'before_sha256':previous,'after_sha256':sha(target)})
    for alias, canonical in LEGACY_ALIASES.items():
        previous = sha(ROOT / alias)
        shutil.copy2(ROOT / canonical, ROOT / alias)
        receipt['aliases'].append({'path':alias,'canonical_path':canonical,'before_sha256':previous,'after_sha256':sha(ROOT / alias)})
    write(MANIFEST, updated)
    receipt['installed_manifest_sha256'] = sha(MANIFEST)
    receipt['rgba8_bytes_29_sheets_unchanged'] = 29*2048*128*4
    receipt['android_device_tested'] = False
    write(RECEIPT, receipt)
    check(True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--approve', action='store_true')
    mode.add_argument('--install', action='store_true')
    mode.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.approve:
        approve()
    elif args.install:
        install()
    else:
        check(args.check)
