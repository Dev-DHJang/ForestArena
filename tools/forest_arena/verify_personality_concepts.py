"""Check draft personality PNG structure, never infer visual identity or approval."""
from pathlib import Path
import argparse
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT/'_workspace/character-personality-concepts'
ROSTER = ('ja-hyun','myo-ryung','nabi','yu-ran')


def image_errors(image, *, require_margin=True):
    errors = []
    if image.mode != 'RGBA':
        return ['real RGBA PNG required']
    if image.size != (1024,1536):
        errors.append('1024x1536 canvas required')
    alpha = image.getchannel('A')
    low, high = alpha.getextrema()
    if low != 0 or high < 240:
        errors.append('transparent background and solid character core required')
    box = alpha.getbbox()
    if box is None:
        errors.append('empty character')
    elif require_margin and min(box[0],box[1],image.width-box[2],image.height-box[3]) < 48:
        errors.append('at least 48 fully transparent pixels of margin required')
    return errors


def check_review(report, root=ROOT, *, require_margin=True):
    errors = []
    seen_paths, seen_hashes = set(), set()
    if set(report) != set(ROSTER):
        errors.append('exactly four named characters required')
    for cid,row in report.items():
        path = (root/row['path']).resolve()
        if not path.is_relative_to(root.resolve()):
            errors.append(f'{cid}: path outside workspace')
            continue
        if path in seen_paths or row['sha256'] in seen_hashes:
            errors.append(f'{cid}: duplicate candidate path or image hash')
        seen_paths.add(path)
        seen_hashes.add(row['sha256'])
        if row.get('reference_concept_asset_id') != f'{cid}-concept-v01':
            errors.append(f'{cid}: wrong reference concept ID')
        reference = root/f'assets/character/{cid}/concept/{cid}-concept-v01.png'
        if not reference.exists() or hashlib.sha256(reference.read_bytes()).hexdigest() != row.get('reference_sha256'):
            errors.append(f'{cid}: reference source hash changed or missing')
        if not path.exists():
            errors.append(f'{cid}: missing image')
            continue
        if hashlib.sha256(path.read_bytes()).hexdigest() != row['sha256']:
            errors.append(f'{cid}: image hash changed since review')
        with Image.open(path) as image:
            errors.extend(f'{cid}: {error}' for error in image_errors(image,require_margin=require_margin))
    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--report',type=Path,default=WORK/'review-candidates.json')
    args = parser.parse_args()
    report = json.loads(args.report.read_text())
    errors = check_review(report)
    if errors:
        for error in errors:
            print('FIX:',error)
        raise SystemExit(1)
    print('PERSONALITY_CONCEPT_STRUCTURE: PASS (4 PNGs; not visual QA or user approval)')


if __name__=='__main__':
    main()
