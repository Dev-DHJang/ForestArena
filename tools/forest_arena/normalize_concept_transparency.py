"""User-approved local alpha cleanup; preserves every source RGB byte."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / '_workspace/character-concept-transparency'
ROSTER = ('ja-hyun', 'myo-ryung', 'nabi', 'yu-ran')
ENCLOSED_BACKGROUND_BOXES = {
    # Manually checked hair/limb/tail gaps in these exact approved source files.
    'ja-hyun': [(601,69,703,124),(746,135,758,166),(713,501,742,530),(722,573,767,600)],
    'nabi': [(584,12,638,35),(685,22,710,55),(349,83,410,123),(335,131,360,142),
             (280,159,341,208),(287,242,304,279),(273,274,303,306),(824,326,858,390),
             (293,360,318,397),(806,398,817,421),(390,409,405,440),(236,419,391,786),(741,487,798,568)],
    'yu-ran': [(384,39,421,50),(307,59,364,122),(300,168,316,211),(282,213,297,244),
               (262,261,298,308),(234,273,273,323),(810,320,821,347),(298,374,315,395),
               (266,386,312,433),(744,413,768,437),(369,485,407,535),(855,504,909,553),
               (770,510,794,555),(785,518,813,567),(811,549,837,588),(853,552,898,617),(286,693,502,867)],
}
EXPECTED_SOURCE_HASHES = {
    'ja-hyun': '0822de75713db985451c8d6e0022d43bfc54072d74a14d123770f2dc34fdd67c',
    'nabi': '5c9cd3c572a12ef754d98cf93c8dfc44255fcdc043019da246582c2262a86fe4',
    'yu-ran': 'f3c4109c97cb9c79d85352dc6270628a741d4bc2a3f3667ed0ffa264a4f8cc12',
}


def components(mask):
    runs, parents, previous = [], [], []
    def root(i):
        while parents[i] != i:
            parents[i] = parents[parents[i]]
            i = parents[i]
        return i
    for y, row in enumerate(mask):
        edges = np.flatnonzero(np.diff(np.r_[False, row, False]))
        current = []
        for left, right in zip(edges[::2], edges[1::2]):
            i = len(runs)
            parents.append(i)
            runs.append((y, int(left), int(right)))
            current.append(i)
            for j in previous:
                _, pl, pr = runs[j]
                if pr >= left and pl <= right:
                    parents[root(j)] = root(i)
        previous = current
    regions = {}
    for i, (y, left, right) in enumerate(runs):
        region = regions.setdefault(root(i), {'runs': [], 'area': 0, 'border': False})
        region['runs'].append((y, left, right))
        region['area'] += right - left
        region['border'] |= y in (0, mask.shape[0]-1) or left == 0 or right == mask.shape[1]
    return list(regions.values())


def remove_black_background(image, enclosed_boxes=()):
    rgb = np.asarray(image.convert('RGB')).copy()
    # Only nearly black connected backdrop regions; dark clothing remains opaque.
    dark = rgb.max(axis=2) <= 6
    background = np.zeros(dark.shape, dtype=bool)
    regions = components(dark)
    found = set()
    for region in regions:
        box = (min(l for y,l,r in region['runs']), min(y for y,l,r in region['runs']),
               max(r for y,l,r in region['runs']), max(y for y,l,r in region['runs'])+1)
        selected = box in enclosed_boxes
        if selected:
            found.add(box)
        if region['border'] or selected:
            for y, left, right in region['runs']:
                background[y, left:right] = True
    alpha = np.where(background, 0, 255).astype(np.uint8)
    assert found == set(enclosed_boxes), 'Reviewed gap geometry changed; inspect source instead of guessing'
    result = Image.fromarray(np.dstack((rgb, alpha)))
    return result, {'removed_pixels': int(background.sum()),
                    'enclosed_regions_removed': len(found)}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def make_preview(image, path):
    thumb = image.copy()
    thumb.thumbnail((430, 575))
    board = Image.new('RGB', (900, 625), 'white')
    draw = ImageDraw.Draw(board)
    draw.rectangle((450, 0, 899, 624), fill=(35, 45, 60))
    for x in (10, 460):
        board.paste(thumb, (x, 35), thumb)
    board.save(path)


def stage():
    records = []
    for cid in ROSTER:
        source = ROOT / f'assets/character/{cid}/concept/{cid}-concept-v01.png'
        output = WORK / f'02_local/{cid}-transparent.png'
        output.parent.mkdir(parents=True, exist_ok=True)
        with Image.open(source) as image:
            if image.mode == 'RGBA' and image.getchannel('A').getextrema() == (0, 255):
                shutil.copy2(source, output)
                details = {'method': 'preserved existing transparent PNG'}
            else:
                assert sha(source) == EXPECTED_SOURCE_HASHES[cid], 'Source changed; manual gap review required'
                result, details = remove_black_background(image, ENCLOSED_BACKGROUND_BOXES[cid])
                result.save(output)
                details['method'] = 'local connected near-black backdrop alpha removal; RGB unchanged'
            with Image.open(output) as result:
                assert result.mode == 'RGBA' and result.size == image.size
                assert np.array_equal(np.asarray(image.convert('RGB')), np.asarray(result.convert('RGB')))
                make_preview(result, output.with_name(f'{cid}-white-dark-review.png'))
        records.append({'character_id': cid, 'source_path': str(source.relative_to(ROOT)),
                        'source_sha256': sha(source), 'output_path': str(output.relative_to(ROOT)),
                        'output_sha256': sha(output), **details})
    (WORK / '02_local/report.json').write_text(json.dumps(records, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(records, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.parse_args()
    stage()
