"""Keep two unused legacy paths on their already-approved canonical images."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
from audit_character_motion_visuals import ROOT, LEGACY_ALIASES

WORK = ROOT/'_workspace/character-motion-visual-unification'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--install',action='store_true')
    args = parser.parse_args()
    receipt = WORK/'08_legacy_aliases.json'
    records = []
    if args.install:
        assert not receipt.exists(), 'Already synchronized; run without --install to check'
        approved = json.loads((WORK/'03_staged/report.json').read_text())['nabi']['motions']
        for alias,canonical in LEGACY_ALIASES.items():
            source,target = ROOT/canonical,ROOT/alias
            assert any(row['sha256'] == digest(source) for row in approved)
            backup = WORK/'05_before_install'/alias
            assert not backup.exists()
            backup.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(target,backup)
            records.append({'path':alias,'canonical_path':canonical,'before_sha256':digest(target),'after_sha256':digest(source)})
            shutil.copy2(source,target)
        receipt.write_text(json.dumps({'approval':'same explicitly approved 119-motion set; no new poses','aliases':records},indent=2)+'\n')
    for alias,canonical in LEGACY_ALIASES.items():
        assert digest(ROOT/alias) == digest(ROOT/canonical), alias
    print('LEGACY_MOTION_ALIASES: PASS (2 paths, identical approved poses, no new motion IDs)')


if __name__ == '__main__':
    main()
