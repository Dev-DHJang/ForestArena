"""Record source hashes without modifying existing game assets."""
from pathlib import Path
import hashlib
import json

WORK=Path(__file__).resolve().parent
ROOT=WORK.parents[1]
SELECTED={'ja-hyun':'r02','myo-ryung':'r02','nabi':'r01','yu-ran':'r01'}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    baseline_path=WORK/'source-baseline.json'
    paths=[ROOT/'assets/character/manifest.json',ROOT/'docs/contracts/character-appearance-v01.json']
    for cid in SELECTED:
        base=ROOT/'assets/character'/cid
        paths.extend((base/'character.tres',base/'concept'/f'{cid}-concept-v01.png'))
        paths.extend((base/'animation/runtime').rglob('*.png'))
        paths.extend((base/'animation/runtime').rglob('*.tres'))
    snapshot={str(path.relative_to(ROOT)):digest(path) for path in paths}
    if baseline_path.exists():
        assert json.loads(baseline_path.read_text())==snapshot,'Existing source changed; do not overwrite baseline'
    else:
        baseline_path.write_text(json.dumps(snapshot,indent=2)+'\n')
    report={}
    for cid,version in SELECTED.items():
        path=WORK/'03_drafts'/f'{cid}-{version}.png'
        report[cid]={'path':str(path.relative_to(ROOT)),'sha256':digest(path),
            'reference_concept_asset_id':f'{cid}-concept-v01',
            'reference_sha256':snapshot[f'assets/character/{cid}/concept/{cid}-concept-v01.png'],
            'user_approved':False,'review_status':'fix-margin'}
    (WORK/'review-candidates.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'SOURCE_BASELINE: preserved {len(snapshot)} asset/data hashes; four unapproved raw candidates recorded')


if __name__=='__main__':
    main()
