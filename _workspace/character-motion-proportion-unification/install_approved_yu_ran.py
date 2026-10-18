"""유란30종 승인 기록·정확한 셀 재배치와 최종90종 누적 보존 검사."""
from pathlib import Path
import argparse
import copy
import shutil
from PIL import Image
import install_approved_myo as myo
import install_approved_nabi as nabi

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
BATCH = WORK / '08_yu_ran-style-locked'
MANIFEST = ROOT / 'assets/character/manifest.json'
APPROVAL = BATCH / 'approval-all-30.json'
RECEIPT = BATCH / '08_install_receipt.json'
BACKUP = BATCH / '07_before_install'
sha, read, write, pack = myo.sha, myo.read, myo.write, nabi.pack


def inputs():
    pending = read(BATCH / 'pending-review-29.json')
    report_path = BATCH / '04_review/30-motion-report.json'
    assert pending['user_approved'] is False and len(pending['states']) == 29
    assert sha(report_path) == pending['review_report_sha256']
    for state in pending['states']:
        myo.verify_files(state['files'])
    samples = read(WORK / '03_sample_approval.json')
    sample = next(s for s in samples['samples'] if s['character_id'] == 'yu-ran')
    assert samples['user_approved'] is True and sha(ROOT / sample['path']) == sample['sha256']
    report = read(report_path)
    assert len(report['states']) == 30
    assert {r['visual_state_id'] for r in report['states']} == {'idle'} | {r['visual_state_id'] for r in pending['states']}
    for row in report['states']:
        assert row['character_id'] == 'yu-ran'
        assert sha(ROOT / row['review_path']) == row['review_sha256']
        if row['visual_state_id'] == 'idle':
            assert row['review_sha256'] == sample['sha256']
        else:
            assert sha(ROOT / row['source_path']) == row['source_sha256']
    return report, pending, sample


def approve():
    assert not APPROVAL.exists(), '승인 기록을 덮어쓰지 않는다'
    report, pending, sample = inputs()
    record = {'user_approved': True, 'approved_on': '2026-10-17', 'timezone': 'Asia/Seoul',
              'user_text': '승인한다.', 'approved_count': 30, 'newly_approved_count': 29,
              'approved_states': {r['visual_state_id']: r['review_sha256'] for r in report['states']},
              'review_report_sha256': pending['review_report_sha256'],
              'pending_29_record_sha256': sha(BATCH / 'pending-review-29.json'),
              'approved_idle_record_sha256': sha(WORK / '03_sample_approval.json'),
              'files': [sample] + [f for s in pending['states'] for f in s['files']],
              'scope': '이번에 제시한 유란 새29종과 앞서 승인된 동일 idle의 정확한30종. 승인90종 계획에 따른 게임 반영만 허용하며 전투·SpriteFrames·자현 변경은 포함하지 않는다.'}
    write(APPROVAL, record)
    print('YU-RAN APPROVAL: new29 + prior idle = 30 hash-bound approved motions.')


def approval():
    report, _, _ = inputs()
    approved = read(APPROVAL)
    assert approved['user_approved'] is True and approved['approved_count'] == 30
    assert approved['review_report_sha256'] == sha(BATCH / '04_review/30-motion-report.json')
    assert approved['pending_29_record_sha256'] == sha(BATCH / 'pending-review-29.json')
    assert approved['approved_idle_record_sha256'] == sha(WORK / '03_sample_approval.json')
    myo.verify_files(approved['files'])
    assert approved['approved_states'] == {r['visual_state_id']: r['review_sha256'] for r in report['states']}
    return report, approved


def records(manifest, report):
    result = []
    for row in report['states']:
        matches = [e for e in manifest['assets'] if e.get('character_id') == 'yu-ran'
                   and e.get('type') == 'animation-runtime' and e.get('visual_state_id') == row['visual_state_id']]
        assert len(matches) == 1
        entry = matches[0]
        assert entry['fps'] == row['original_fps'] and entry['loop'] == row['original_loop']
        target = ROOT / entry['path']
        assert target.resolve().is_relative_to(ROOT / 'assets/character/yu-ran/animation/runtime')
        frames = ROOT / entry['sprite_frames_path'].removeprefix('res://')
        assert entry['consumer_path'] == entry['sprite_frames_path'] and 'res://' + entry['path'] in frames.read_text()
        result.append((row, entry, target))
    assert len(result) == 30
    return result


def check(installed=True):
    report, _ = approval()
    current = read(MANIFEST)
    if not installed:
        nabi.check(True)
        targets = records(current, report)
        assert {p for _, _, p in targets} == set((ROOT / 'assets/character/yu-ran/animation/runtime').rglob('*.png'))
        print('YU-RAN PREFLIGHT: PASS (30 exact approvals; Myo31/Nabi29 and Ja-Hyun preserved).')
        return
    receipt = read(RECEIPT)
    before = read(BACKUP / 'manifest.json')
    assert sha(MANIFEST) == receipt['installed_manifest_sha256']
    assert sha(APPROVAL) == receipt['approval_sha256']
    assert sha(BACKUP / 'manifest.json') == receipt['previous_manifest_sha256'] == read(nabi.RECEIPT)['installed_manifest_sha256']
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
    nabi_report, _ = nabi.approval()
    previous = {e['asset_id']: (r,e,p,packer) for module, old_report, packer in
                ((myo, myo_report, myo.pack), (nabi, nabi_report, nabi.pack))
                for r,e,p in module.records(current, old_report)}
    assert len(previous) == 60 and len(selected) == 30 and set(previous).isdisjoint(selected)
    for old in baseline['runtime_entries']:
        assert sha(ROOT / old['sprite_frames_path'].removeprefix('res://')) == old['sprite_frames_start_sha256']
        if old['asset_id'] in selected:
            row, entry, target = selected[old['asset_id']]
            image = Image.open(target)
            assert image.mode == 'RGBA' and image.size == (2048,128) and image.tobytes() == pack(row).tobytes()
            assert sha(target) == entry['sha256']
            assert sha(BACKUP / old['path']) == old['actual_start_sha256']
        elif old['asset_id'] in previous:
            row, entry, target, packer = previous[old['asset_id']]
            image = Image.open(target)
            assert image.mode == 'RGBA' and image.size == (2048,128) and image.tobytes() == packer(row).tobytes()
            assert sha(target) == entry['sha256']
        else:
            assert old['character_id'] == 'ja-hyun' and sha(ROOT / old['path']) == old['actual_start_sha256'], old['path']
    # Each previous installation remains backed up and approval-bound, without rewriting its historical checker.
    for module, expected_before in ((myo, baseline['manifest_start_sha256']),
                                    (nabi, read(myo.RECEIPT)['installed_manifest_sha256']),
                                    (sys_module(), read(nabi.RECEIPT)['installed_manifest_sha256'])):
        installed_receipt = read(module.RECEIPT)
        assert sha(module.APPROVAL) == installed_receipt['approval_sha256']
        assert sha(module.BACKUP / 'manifest.json') == expected_before
        for row in installed_receipt['replacements'] + installed_receipt.get('aliases', []):
            assert sha(ROOT / row['path']) == row['after_sha256']
            assert sha(module.BACKUP / row['path']) == row['before_sha256']
    for alias, canonical in nabi.LEGACY_ALIASES.items():
        assert sha(ROOT / alias) == sha(ROOT / canonical)
    print('FINAL90 INSTALL: PASS (Myo31+Nabi29+Yu-Ran30 / 1440 exact cells; Ja-Hyun30, all SpriteFrames/concepts/combat unchanged; 2 Nabi aliases preserved).')


def sys_module():
    # Module-like constants for the common immutable receipt-chain check.
    from types import SimpleNamespace
    return SimpleNamespace(RECEIPT=RECEIPT, APPROVAL=APPROVAL, BACKUP=BACKUP)


def install():
    assert not RECEIPT.exists() and not BACKUP.exists(), '기존 반영/백업이 있으면 --check로 확인한다'
    check(False)
    report, approved = approval()
    updated = copy.deepcopy(read(MANIFEST))
    targets = records(updated, report)
    stage = BATCH / '06_runtime_staged'
    assert not stage.exists()
    stage.mkdir()
    for row, _, _ in targets:
        path = stage / (row['visual_state_id'] + '_16f.png')
        strip = pack(row)
        strip.save(path)
        assert Image.open(path).tobytes() == strip.tobytes()
    BACKUP.mkdir()
    shutil.copy2(MANIFEST, BACKUP / 'manifest.json')
    for _, entry, target in targets:
        saved = BACKUP / entry['path']
        saved.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(target, saved)
        assert sha(target) == sha(saved)
    receipt = {'approved_on': approved['approved_on'], 'approval_sha256': sha(APPROVAL),
               'previous_manifest_sha256': sha(MANIFEST), 'replacements': [],
               'scope': 'Only approved Yu-Ran30 PNGs and their presentation/provenance metadata; exact cells, no rescaling.'}
    selection = read(BATCH / '01_style_reference/selection.json')
    for row, entry, target in targets:
        previous = sha(target)
        shutil.copy2(stage / (row['visual_state_id'] + '_16f.png'), target)
        entry.update(sha256=sha(target), verified_on=approved['approved_on'], presentation_scale=1.0, foot_pivot_y=124)
        entry['creation'] = {'method':'built-in image generation, one approved idle style master; exact approved review-cell packing',
                             'provider':'OpenAI built-in image generation + project-local normalization',
                             'version':'character-motion-proportion-unification-yu-ran-v01'}
        entry['rights'].setdefault('references', []).append('2026-10-17: User approved all30 remade Yu-Ran motions; external license verification not asserted.')
        entry.setdefault('modifications', []).append('2026-10-17: Packed exact approved4x4 cells into2048x128, no resize; presentation_scale1.0/foot124; IDs/FPS/loop/combat unchanged.')
        entry['motion_unification'] = {'report_sha256':approved['review_report_sha256'],
                                      'source_path':row.get('source_path', selection['source_path']),
                                      'source_sha256':row.get('source_sha256', selection['source_sha256']),
                                      'review_path':row['review_path'], 'review_sha256':row['review_sha256'],
                                      'source_scale':row.get('fixed_motion_scale', 72/204),
                                      'approval_record':str(APPROVAL.relative_to(ROOT))}
        receipt['replacements'].append({'path':entry['path'], 'before_sha256':previous, 'after_sha256':sha(target)})
    write(MANIFEST, updated)
    receipt['installed_manifest_sha256'] = sha(MANIFEST)
    receipt['png_bytes_before'] = sum((BACKUP / e['path']).stat().st_size for _,e,_ in targets)
    receipt['png_bytes_after'] = sum(p.stat().st_size for _,_,p in targets)
    receipt['rgba8_bytes_30_sheets_unchanged'] = 30*2048*128*4
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
