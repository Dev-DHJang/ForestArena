"""Install only hash-bound, explicitly approved motion review artifacts.

Existing runtime paths, SpriteFrames, IDs, FPS and combat data remain unchanged.
The previous dirty runtime files and manifest are backed up before replacement.
"""
from pathlib import Path
import argparse
import copy
import hashlib
import json
import shutil

from verify_staged_motion_unification import main as verify_staged

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT/'_workspace/character-motion-visual-unification'
MANIFEST = ROOT/'assets/character/manifest.json'
ANCHOR = ROOT/'assets/character/ja-hyun/animation/runtime/local_ai_v01/attack_heavy_charge_16f.png'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def collect(manifest, report):
    result = []
    for cid, group in report.items():
        for row in group['motions']:
            matches = [e for e in manifest['assets'] if e.get('character_id') == cid
                       and e.get('type') == 'animation-runtime'
                       and (e.get('visual_state_id') or Path(e['path']).stem.removesuffix('_16f')) == row['motion']]
            assert len(matches) == 1, (cid,row['motion'])
            entry = matches[0]
            target = (ROOT/entry['path']).resolve()
            assert target.is_relative_to(ROOT/'assets/character'/cid/'animation/runtime')
            assert target.exists() and target != ANCHOR
            assert entry['fps'] == row['fps'] and entry['loop'] == row['loop']
            frames = ROOT/entry['sprite_frames_path'].removeprefix('res://')
            assert frames.exists() and entry['consumer_path'] == entry['sprite_frames_path']
            assert 'res://'+entry['path'] in frames.read_text()
            result.append((row,entry,target,frames))
    assert len(result) == 119
    return result


def verify_installed(manifest, report, receipt):
    records = collect(manifest,report)
    for row,entry,target,frames in records:
        assert digest(target) == row['sha256'] == entry['sha256'], target
        assert digest(frames) == receipt['sprite_frames_sha256'][str(frames.relative_to(ROOT))], frames
        assert entry['motion_unification']['report_sha256'] == receipt['report_sha256']
        assert entry['visual_state_id'] == row['motion'] and entry['foot_pivot_y'] == 124
    assert digest(ANCHOR) == receipt['retained_anchor_sha256']
    previous = json.loads((WORK/'05_before_install/manifest.json').read_text())
    originals = {e['asset_id']:e for e in previous['assets']}
    replaced = {entry['asset_id'] for _,entry,_,_ in records}
    assert len(manifest['assets']) == len(previous['assets'])
    changed_fields = {'sha256','verified_on','creation','rights','modifications','motion_unification','foot_pivot_y','visual_state_id'}
    concept_baseline = {}
    if (ROOT/'_workspace/character-concept-transparency/installation.json').exists():
        from install_concept_transparency import check as check_concept_transparency
        check_concept_transparency()
        concept_before = json.loads((ROOT/'_workspace/character-concept-transparency/03_backup/manifest.json').read_text())
        concept_baseline = {e['asset_id']:e for e in concept_before['assets'] if e.get('type') == 'concept'}
    for entry in manifest['assets']:
        original = originals[entry['asset_id']]
        if entry['asset_id'] not in replaced:
            # A later separately approved alpha-only concept edit is validated above.
            comparison = concept_baseline.get(entry['asset_id'], entry)
            assert comparison == original, entry['asset_id']
        else:
            assert {k:v for k,v in entry.items() if k not in changed_fields} == {k:v for k,v in original.items() if k not in changed_fields}, entry['asset_id']
            assert entry['rights']['status'] == original['rights']['status']
            if 'visual_state_id' in original:
                assert entry['visual_state_id'] == original['visual_state_id']
    print('MOTION_STORAGE_BYTES:', json.dumps({
        'before_png':sum((WORK/'05_before_install'/t.relative_to(ROOT)).stat().st_size for _,_,t,_ in records),
        'after_png':sum(t.stat().st_size for _,_,t,_ in records),
        'rgba8_pixels_119_sheets':119*2048*128*4,
        'note':'same dimensions; not an Android GPU measurement',
    }))
    print('INSTALLED_MOTION_UNIFICATION: PASS (119 approved replacements; anchor/SpriteFrames unchanged)')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--install',action='store_true')
    parser.add_argument('--check',action='store_true')
    parser.add_argument('--finalize-pivots',action='store_true',help='Apply approved 124px contact point to existing basic-motion entries')
    args = parser.parse_args()
    verify_staged()
    report_path = WORK/'03_staged/report.json'
    report = json.loads(report_path.read_text())
    approval = json.loads((WORK/'approval.json').read_text())
    assert approval['report_sha256'] == digest(report_path)
    assert approval['approved_count'] == 119 and approval['user_approved'] is True
    manifest = json.loads(MANIFEST.read_text())
    receipt_path = WORK/'05_install_receipt.json'
    if args.finalize_pivots:
        assert receipt_path.exists(), 'Install before finalizing layout'
        for row,entry,_,_ in collect(manifest,report):
            assert entry.get('visual_state_id',row['motion']) == row['motion']
            entry['visual_state_id'] = row['motion']
            entry['foot_pivot_y'] = 124
        MANIFEST.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
        verify_installed(manifest,report,json.loads(receipt_path.read_text()))
        return
    if args.check:
        verify_installed(manifest,report,json.loads(receipt_path.read_text()))
        return
    records = collect(manifest,report)
    if not args.install:
        print('INSTALL_PREFLIGHT: PASS (119 approved sheets; no writes)')
        return
    assert not receipt_path.exists(), 'Already installed: use --check instead of overwriting backup'
    backup = WORK/'05_before_install'
    assert not backup.exists(), 'Existing backup must be inspected before another install'
    receipt = {
        'report_sha256':digest(report_path), 'approved_on':approval['approved_on'],
        'retained_anchor_sha256':digest(ANCHOR),
        'sprite_frames_sha256':{str(f.relative_to(ROOT)):digest(f) for _,_,_,f in records},
        'previous_manifest_sha256':digest(MANIFEST), 'replacements':[],
    }
    for _,_,target,_ in records:
        saved = backup/target.relative_to(ROOT)
        saved.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(target,saved)
    shutil.copy2(MANIFEST,backup/'manifest.json')
    updated = copy.deepcopy(manifest)
    updated_records = collect(updated,report)
    for row,entry,target,_ in updated_records:
        previous_hash = digest(target)
        shutil.copy2(ROOT/row['staged_path'],target)
        entry['sha256'] = row['sha256']
        entry['verified_on'] = approval['approved_on']
        entry['visual_state_id'] = row['motion']
        entry['foot_pivot_y'] = 124
        entry['creation'] = {
            'method':'approved original review recovery and region normalization' if row['source_path'].endswith('-r00.png') else 'built-in image generation, approved identity reference and region normalization',
            'provider':'project-local normalization' if row['source_path'].endswith('-r00.png') else 'OpenAI built-in image generation + project-local normalization',
            'version':'motion-visual-unification-v01',
        }
        entry.setdefault('rights',{}).setdefault('references',[]).append(
            'User explicitly approved 119 replacement motion candidates, '+approval['approved_on']+'; external license verification not asserted')
        entry.setdefault('modifications',[]).append(
            approval['approved_on']+': Installed hash-bound approved candidate; preserved runtime path, SpriteFrames, frame count, FPS, loop and combat timing.')
        entry['motion_unification'] = {
            'report_sha256':receipt['report_sha256'], 'source_path':row['source_path'],
            'source_sha256':row['source_sha256'], 'review_path':row['staged_path'],
            'source_scale':row['source_scale'], 'approval_record':str((WORK/'approval.json').relative_to(ROOT)),
        }
        receipt['replacements'].append({'path':entry['path'],'before_sha256':previous_hash,'after_sha256':row['sha256']})
    # Mechanical metadata update only; unrelated manifest entries stay intact.
    MANIFEST.write_text(json.dumps(updated,ensure_ascii=False,indent=2)+'\n')
    receipt_path.write_text(json.dumps(receipt,indent=2)+'\n')
    verify_installed(updated,report,receipt)


if __name__ == '__main__':
    main()
