"""Copy only approved motion deliverables into a clean develop worktree."""
from pathlib import Path
import argparse
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
WORK = Path('_workspace/character-motion-visual-unification')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('destination',type=Path)
    parser.add_argument('--refresh',action='store_true',help='Refresh this task-owned integration branch only')
    args = parser.parse_args()
    destination = args.destination.resolve()
    assert destination != ROOT and (destination/'.git').exists()
    if args.refresh:
        assert subprocess.check_output(['git','branch','--show-current'],cwd=destination,text=True).strip() == 'feature/motion-visual-unification'
    else:
        assert not subprocess.check_output(['git','status','--porcelain'],cwd=destination,text=True).strip()
    report = json.loads((ROOT/WORK/'03_staged/report.json').read_text())
    receipt = json.loads((ROOT/WORK/'05_install_receipt.json').read_text())
    files = {
        Path('assets/character/manifest.json'),
        Path('assets/character/nabi/concept/nabi-concept-v01.png'),
        Path('assets/character/nabi/concept/design.md'),
        Path('docs/contracts/character-appearance-v01.json'),
        Path('tests/character_appearance_contract.gd'),
        Path('scripts/local_fighter_presentation.gd'),
        Path('tests/local_fighter_presentation.gd'),
    }
    for name in ('audit_character_motion_visuals','install_motion_unification','motion_sheet_regions',
                 'normalize_chibi_motion_refresh','recover_motion_review_sources','stage_motion_unification',
                 'test_motion_visual_tools','verify_staged_motion_unification','prepare_motion_integration','sync_motion_legacy_aliases'):
        files.add(Path('tools/forest_arena')/(name+'.py'))
    for group in report.values():
        for row in group['motions']:
            files.update((Path(row['source_path']),Path(row['staged_path'])))
    selected = {row['source_path'] for group in report.values() for row in group['motions']}
    for record in json.loads((ROOT/WORK/'source-recovery.json').read_text()):
        if record['output'] in selected:
            files.add(Path(record['source']))
            ignore = ROOT / Path(record['source']).parents[1] / '.gdignore'
            if ignore.exists():
                files.add(ignore.relative_to(ROOT))
    for row in receipt['replacements']:
        files.add(Path(row['path']))
        files.add(WORK/'05_before_install'/row['path'])
    files.add(WORK/'05_before_install/manifest.json')
    for i in (1,2):
        alias = Path(f'assets/character/nabi/animation/runtime/attack_light_combo_0{i}_16f.png')
        files.update((alias,WORK/'05_before_install'/alias))
    files.add(WORK/'.gdignore')
    for pattern in ('*.md','*.json','capture-installed.gd','installed-presentation*.png','installed-presentation.log','completion-verify-2026-10-09.log'):
        files.update(path.relative_to(ROOT) for path in (ROOT/WORK).glob(pattern))
    for pattern in ('*.json','**/*.gif','**/*.jpg'):
        files.update(path.relative_to(ROOT) for path in (ROOT/WORK/'03_staged').glob(pattern))
    files.add(WORK/'06_completion_audit/report.json')
    for path in sorted(files):
        assert not path.is_absolute() and '..' not in path.parts
        target = destination/path
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(ROOT/path,target)
    print(json.dumps({'files':len(files),'bytes':sum((ROOT/path).stat().st_size for path in files),
                      'destination':str(destination)},ensure_ascii=False))


if __name__ == '__main__':
    main()
