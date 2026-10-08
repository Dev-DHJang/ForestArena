"""Verify review artifacts, not approval or character identity."""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / '_workspace/character-motion-visual-unification/03_staged'


def main():
    report = json.loads((WORK/'report.json').read_text())
    failures = json.loads((WORK/'failures.json').read_text())
    assert not failures, failures
    expected = {'ja-hyun':29, 'myo-ryung':31, 'nabi':29, 'yu-ran':30}
    count = 0
    for cid, number in expected.items():
        records = report[cid]['motions']
        assert len(records) == number, (cid,len(records))
        assert len({r['motion'] for r in records}) == number
        for row in records:
            path = ROOT/row['staged_path']
            assert hashlib.sha256(path.read_bytes()).hexdigest() == row['sha256']
            source = ROOT/row['source_path']
            assert hashlib.sha256(source.read_bytes()).hexdigest() == row['source_sha256']
            with Image.open(path) as image:
                assert image.mode == 'RGBA' and image.size == (2048,128), path
                for i in range(16):
                    alpha = image.crop((i*128,0,(i+1)*128,128)).getchannel('A')
                    box = alpha.getbbox()
                    assert box and box[1] >= 0 and box[3] <= 124, (path,i,box)
                    assert alpha.getextrema() == (0,255), (path,i)
            assert row['fps'] > 0 and isinstance(row['loop'],bool)
            count += 1
    assert 'attack_heavy_charge' not in {r['motion'] for r in report['ja-hyun']['motions']}
    print(f'STAGED_MOTION_STRUCTURE: PASS ({count} sheets, {count*16} frames; not user approval)')


if __name__ == '__main__':
    main()
