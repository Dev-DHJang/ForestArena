"""Recover approved review sources for staging only; never writes runtime/manifest.

The old per-cell corner color interpolation deleted dark clothing and cut ears.
This separates the characteristic blue-gray review backdrop before grid splitting.
Every result still needs visual QA and explicit approval.
"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import numpy as np
from PIL import Image
import normalize_ja_hyun_approved as ja
import normalize_myo_ryung_approved as myo
from normalize_chibi_motion_refresh import find_source

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / '_workspace/character-motion-visual-unification'


def gray_review_alpha(image):
    pixels = np.asarray(image.convert('RGBA')).copy()
    rgb = pixels[:,:,:3].astype(np.int16)
    r, g, b = rgb[:,:,0], rgb[:,:,1], rgb[:,:,2]
    # The backdrop has a cool blue bias; charcoal/brown clothing has a different
    # channel ordering. Do not erase pixels just for low contrast to the corners.
    background = ((r >= 10) & (r <= 100) & (g-r >= 1) & (g-r <= 10)
                  & (b-r >= 4) & (b-r <= 20) & (b-g >= 1) & (b-g <= 12))
    samples = np.concatenate([rgb[:8,:8].reshape(-1,3),rgb[:8,-8:].reshape(-1,3),
                              rgb[-8:,:8].reshape(-1,3),rgb[-8:,-8:].reshape(-1,3)])
    backdrop = np.median(samples,axis=0)
    if backdrop.min() >= 90 and backdrop.max()-backdrop.min() <= 12:
        # Some approved rabbit reviews use a lighter neutral-gray backdrop.
        # Match its chroma and brightness band, not all gray foreground pixels.
        neutral = ((np.abs((g-r)-(backdrop[1]-backdrop[0])) <= 6)
                   & (np.abs((b-r)-(backdrop[2]-backdrop[0])) <= 6)
                   & (np.abs(r-backdrop[0]) <= 40))
        background |= neutral
    pixels[background] = 0
    return Image.fromarray(pixels)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--character', action='append', choices=['ja-hyun','myo-ryung','nabi','yu-ran'])
    parser.add_argument('--motion', action='append')
    args = parser.parse_args()
    records = []
    manifest = json.loads((ROOT/'assets/character/manifest.json').read_text())
    for cid in args.character or ['ja-hyun','myo-ryung','nabi','yu-ran']:
        if cid in ('ja-hyun','myo-ryung'):
            module = ja if cid == 'ja-hyun' else myo
            sources = {row['name']:module.REVIEW/row['file'] for row in module.SOURCES
                       if not (cid=='ja-hyun' and row['name']=='attack_heavy_charge')}
        else:
            entries = [x for x in manifest['assets'] if x.get('character_id')==cid and x.get('type')=='animation-runtime']
            names = [x.get('visual_state_id') or Path(x['path']).stem.removesuffix('_16f') for x in entries]
            sources = {name:find_source(cid,name) for name in names}
        for name, source in sources.items():
            if args.motion and name not in args.motion:
                continue
            output = WORK/'02_drafts'/cid/f'{name}-r00.png'
            output.parent.mkdir(parents=True,exist_ok=True)
            with Image.open(source) as image:
                if 'A' not in image.getbands() or image.getchannel('A').getextrema()[0]>=250:
                    gray_review_alpha(image).save(output)
                    method='blue-gray review backdrop separation before grid splitting'
                else:
                    shutil.copyfile(source,output)
                    method='immutable approved RGBA source copy; no repainting'
            records.append({'character':cid,'motion':name,'source':str(source.relative_to(ROOT)),
                            'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
                            'output':str(output.relative_to(ROOT)),'method':method})
    record_path=WORK/'source-recovery.json'
    prior=json.loads(record_path.read_text()) if record_path.exists() else []
    indexed={(r['character'],r['motion']):r for r in prior}
    indexed.update({(r['character'],r['motion']):r for r in records})
    record_path.write_text(json.dumps(list(indexed.values()),ensure_ascii=False,indent=2)+'\n')
    print(f'Recovered {len(records)} review sources; runtime untouched')


if __name__=='__main__':
    main()
