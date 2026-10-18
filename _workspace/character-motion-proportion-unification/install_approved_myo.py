"""Approve the shown 28, pack exact review pixels, then install only Myo31.

Historical review reports and the dirty-start baseline remain immutable.
Run --approve once, default for preflight, --install once, --check afterwards.
"""
from pathlib import Path
import argparse
import copy
import hashlib
import json
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
BATCH = WORK / '06_myo_ryung-style-locked'
MANIFEST = ROOT / 'assets/character/manifest.json'
APPROVAL = BATCH / 'approval-all-31.json'
RECEIPT = BATCH / '08_install_receipt.json'
BACKUP = BATCH / '07_before_install'
ALLOWED = {'sha256', 'verified_on', 'creation', 'rights', 'modifications',
           'motion_unification', 'foot_pivot_y', 'presentation_scale'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def verify_files(files):
    for row in files:
        assert sha(ROOT / row['path']) == row['sha256'], row['path']


def approved_inputs():
    pending = read(BATCH / '05_remaining/pending-review-28.json')
    report_path = BATCH / '04_review/31-motion-report.json'
    assert sha(report_path) == pending['review_report_sha256']
    proof = read(BATCH / 'approval-proof-3.json')
    assert proof['user_approved'] is True
    verify_files(proof['files'])
    for row in pending['states']:
        verify_files(row['files'])
    report = read(report_path)
    assert len(report['states']) == 31 and len(pending['states']) == 28
    expected = {r['visual_state_id']: r for r in report['states']}
    assert set(proof['approved_states']).isdisjoint(r['visual_state_id'] for r in pending['states'])
    assert set(expected) == set(proof['approved_states']) | {r['visual_state_id'] for r in pending['states']}
    for row in report['states']:
        assert sha(ROOT / row['review_path']) == row['review_sha256']
        assert sha(ROOT / row['source_path']) == row['source_sha256']
    return report, pending, proof


def approve():
    assert not APPROVAL.exists(), 'Approval already recorded; do not overwrite'
    report, pending, proof = approved_inputs()
    files = proof['files'] + [f for r in pending['states'] for f in r['files']]
    record = {'user_approved': True, 'approved_on': '2026-10-17', 'timezone': 'Asia/Seoul',
              'user_text': '승인한다.', 'approved_count': 31, 'newly_approved_count': 28,
              'approved_states': {r['visual_state_id']: r['review_sha256'] for r in report['states']},
              'files': files, 'review_report_sha256': pending['review_report_sha256'],
              'proof_3_record_sha256': sha(BATCH / 'approval-proof-3.json'),
              'pending_28_record_sha256': sha(BATCH / '05_remaining/pending-review-28.json'),
              'scope': 'Exact 28 shown review candidates approved, plus prior approved 3. Myo31 runtime installation follows the approved 90-motion plan; Nabi and Yu-Ran unmade motions are not approved.'}
    write(APPROVAL, record)
    print('MYO APPROVAL: 31 hash-bound approvals (new28 + prior3).')


def check_approval():
    report, _, _ = approved_inputs()
    approval = read(APPROVAL)
    assert approval['user_approved'] is True and approval['approved_count'] == 31
    assert approval['review_report_sha256'] == sha(BATCH / '04_review/31-motion-report.json')
    verify_files(approval['files'])
    assert approval['approved_states'] == {r['visual_state_id']: r['review_sha256'] for r in report['states']}
    return report, approval


def pack(row):
    image = Image.open(ROOT / row['review_path'])
    image.load()
    assert image.mode == 'RGBA' and image.size == (512, 512)
    assert image.getchannel('A').getextrema() == (0, 255)
    strip = Image.new('RGBA', (2048, 128))
    hashes = []
    for i in range(16):
        x, y = i % 4 * 128, i // 4 * 128
        frame = image.crop((x, y, x + 128, y + 128))
        box = frame.getbbox()
        assert box and min(box[:2]) >= 2 and max(box[2:]) <= 126
        digest = hashlib.sha256(frame.tobytes()).hexdigest()
        assert digest == row['frames'][i]['rgba_sha256']
        hashes.append(digest)
        strip.paste(frame, (i * 128, 0))
    assert len(set(hashes)) == 16
    return strip


def records(manifest, report):
    result = []
    for row in report['states']:
        matches = [e for e in manifest['assets'] if e.get('character_id') == 'myo-ryung'
                   and e.get('type') == 'animation-runtime' and e.get('visual_state_id') == row['visual_state_id']]
        assert len(matches) == 1
        entry = matches[0]
        assert entry['fps'] == row['original_fps'] and entry['loop'] == row['original_loop']
        target = ROOT / entry['path']
        assert target.resolve().is_relative_to(ROOT / 'assets/character/myo-ryung/animation/runtime')
        frames = ROOT / entry['sprite_frames_path'].removeprefix('res://')
        assert entry['consumer_path'] == entry['sprite_frames_path']
        assert 'res://' + entry['path'] in frames.read_text()
        result.append((row, entry, target))
    assert len(result) == 31
    return result


def check(installed):
    report, _ = check_approval()
    baseline = read(WORK / '01_baseline.json')
    before = read(WORK / '01_manifest_before.json')
    current = read(MANIFEST)
    assert {k: v for k, v in current.items() if k != 'assets'} == {k: v for k, v in before.items() if k != 'assets'}
    assert len(current['assets']) == len(before['assets'])
    selected = {e['asset_id']: (r, e, t) for r, e, t in records(current, report)}
    assert [e['asset_id'] for e in current['assets']] == [e['asset_id'] for e in before['assets']]
    for old, new in zip(before['assets'], current['assets']):
        if installed and new['asset_id'] in selected:
            assert {k: v for k, v in old.items() if k not in ALLOWED} == {k: v for k, v in new.items() if k not in ALLOWED}
            assert old['rights']['status'] == new['rights']['status']
            assert new['presentation_scale'] == 1.0 and new['foot_pivot_y'] == 124
        else:
            assert old == new, new['asset_id']
    for rel, expected in baseline['protected_files'].items():
        assert sha(ROOT / rel) == expected, rel
    for entry in baseline['runtime_entries']:
        frames = ROOT / entry['sprite_frames_path'].removeprefix('res://')
        assert sha(frames) == entry['sprite_frames_start_sha256']
        if installed and entry['asset_id'] in selected:
            row, current_entry, target = selected[entry['asset_id']]
            strip = Image.open(target)
            strip.load()
            assert strip.mode == 'RGBA' and strip.size == (2048, 128)
            assert strip.tobytes() == pack(row).tobytes(), target
            assert sha(target) == current_entry['sha256']
            assert sha(BACKUP / entry['path']) == entry['actual_start_sha256']
        else:
            assert sha(ROOT / entry['path']) == entry['actual_start_sha256'], entry['path']
    if installed:
        receipt = read(RECEIPT)
        assert sha(MANIFEST) == receipt['installed_manifest_sha256']
        assert sha(BACKUP / 'manifest.json') == baseline['manifest_start_sha256']
        assert sha(APPROVAL) == receipt['approval_sha256']
        for row in receipt['replacements']:
            assert sha(ROOT / row['path']) == row['after_sha256']
        print('MYO INSTALLED: PASS (31 exact sheets/496 cells; 89 other runtime sheets, all SpriteFrames, concepts and combat unchanged).')
    else:
        assert sha(MANIFEST) == baseline['manifest_start_sha256']
        print('MYO PREFLIGHT: PASS (31 approved; all 120 runtime sheets unchanged).')


def install():
    assert not RECEIPT.exists() and not BACKUP.exists(), 'Existing install/backup: use --check'
    check(False)
    report, approval = check_approval()
    original = read(MANIFEST)
    updated = copy.deepcopy(original)
    stage = BATCH / '06_runtime_staged'
    assert not stage.exists(), 'Inspect existing staging before retry'
    stage.mkdir()
    # Produce and verify every strip before any runtime mutation.
    staged = {}
    for row, entry, target in records(updated, report):
        path = stage / (row['visual_state_id'] + '_16f.png')
        pack(row).save(path)
        staged[entry['asset_id']] = path
    BACKUP.mkdir()
    shutil.copy2(MANIFEST, BACKUP / 'manifest.json')
    targets = records(updated, report)
    for _, entry, target in targets:
        saved = BACKUP / entry['path']
        saved.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(target, saved)
    receipt = {'approved_on': approval['approved_on'], 'approval_sha256': sha(APPROVAL),
               'previous_manifest_sha256': sha(MANIFEST), 'replacements': [],
               'scope': 'Only approved Myo31 PNGs and their presentation/provenance metadata; no resize after approval.'}
    for row, entry, target in targets:
        old_hash = sha(target)
        shutil.copy2(staged[entry['asset_id']], target)
        entry['sha256'] = sha(target)
        entry['verified_on'] = approval['approved_on']
        entry['presentation_scale'] = 1.0
        entry['foot_pivot_y'] = 124
        entry['creation'] = {'method': 'built-in image generation, single user-approved style master; exact approved review-cell packing',
                             'provider': 'OpenAI built-in image generation + project-local normalization',
                             'version': 'character-motion-proportion-unification-myo-v01'}
        entry['rights'].setdefault('references', []).append('2026-10-17: User approved all 31 remade Myo-Ryung motions; external license verification not asserted.')
        entry.setdefault('modifications', []).append('2026-10-17: Repacked approved 4x4 review pixels row-major into 2048x128, no further scaling; presentation_scale=1.0; IDs/FPS/loop/combat unchanged.')
        entry['motion_unification'] = {'report_sha256': approval['review_report_sha256'],
                                      'source_path': row['source_path'], 'source_sha256': row['source_sha256'],
                                      'review_path': row['review_path'], 'review_sha256': row['review_sha256'],
                                      'source_scale': row['fixed_motion_scale'],
                                      'approval_record': str(APPROVAL.relative_to(ROOT))}
        receipt['replacements'].append({'path': entry['path'], 'before_sha256': old_hash, 'after_sha256': entry['sha256']})
    write(MANIFEST, updated)
    receipt['installed_manifest_sha256'] = sha(MANIFEST)
    receipt['png_bytes_before'] = sum((BACKUP / e['path']).stat().st_size for _, e, _ in targets)
    receipt['png_bytes_after'] = sum(t.stat().st_size for _, _, t in targets)
    receipt['rgba8_bytes_unchanged'] = 31 * 2048 * 128 * 4
    receipt['android_device_measurement'] = False
    write(RECEIPT, receipt)
    check(True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--approve', action='store_true')
    group.add_argument('--install', action='store_true')
    group.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.approve:
        approve()
    elif args.install:
        install()
    else:
        check(args.check)
