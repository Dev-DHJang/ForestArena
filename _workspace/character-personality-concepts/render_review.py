"""Read-only candidate QA and alpha-composited review boards; no asset edits."""
from pathlib import Path
import argparse
import json
import hashlib
import numpy as np
from PIL import Image, ImageDraw

WORK = Path(__file__).resolve().parent
ROSTER = ('ja-hyun','myo-ryung','nabi','yu-ran')


def metrics(path):
    with Image.open(path) as image:
        rgba = image.convert('RGBA')
        alpha = rgba.getchannel('A')
        box = alpha.getbbox()
        margins = [box[0],box[1],image.width-box[2],image.height-box[3]] if box else []
        return {'path':str(path.relative_to(WORK)),
                'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                'mode':image.mode,'size':list(image.size),
                'alpha_range':list(alpha.getextrema()),'alpha_bbox':box,
                'margins':margins,'valid_margin':bool(margins) and min(margins)>=48,
                'transparent_fraction':float((np.asarray(alpha)==0).mean())}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--normalized',action='store_true')
    args=parser.parse_args()
    selected=json.loads((WORK/'normalized-candidates.json').read_text()) if args.normalized else None
    destination = WORK/('06_review' if args.normalized else '04_review')
    destination.mkdir(exist_ok=True)
    report = []
    board = Image.new('RGB',(1280,1160 if args.normalized else 580),'white')
    draw = ImageDraw.Draw(board)
    if args.normalized:
        draw.rectangle((0,580,1279,1159),fill=(35,45,60))
    for i,cid in enumerate(ROSTER):
        versions = [WORK.parents[1]/selected[cid]['path']] if selected else sorted((WORK/'03_drafts').glob(f'{cid}-r*.png'))
        if not versions:
            continue
        path = versions[-1]
        report.append(metrics(path))
        with Image.open(path) as image:
            thumb = image.convert('RGBA')
            thumb.thumbnail((300,510))
            draw.text((i*320+12,6),path.stem,fill='black')
            board.paste(thumb,(i*320+(320-thumb.width)//2,34),thumb)
            if args.normalized:
                draw.text((i*320+12,586),path.stem,fill='white')
                board.paste(thumb,(i*320+(320-thumb.width)//2,614),thumb)
            pair=Image.new('RGB',(840,680),'white')
            ImageDraw.Draw(pair).rectangle((420,0,839,679),fill=(35,45,60))
            image=image.convert('RGBA')
            image.thumbnail((400,640))
            for x in (10,430):
                pair.paste(image,(x+(400-image.width)//2,20),image)
            pair.save(destination/f'{cid}-white-dark.png')
    board.save(destination/'overview.png')
    (destination/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    # Compare garment placement with actual approved source; no asset mutation.
    source = WORK.parents[1]/'assets/character/myo-ryung/concept/myo-ryung-concept-v01.png'
    candidate = WORK.parents[1]/selected['myo-ryung']['path'] if selected else sorted((WORK/'03_drafts').glob('myo-ryung-r*.png'))[-1]
    clothing = Image.new('RGB',(1100,700),'white')
    for x,path,box in [(0,source,(230,350,980,1000)),(550,candidate,(180,350,930,1000))]:
        with Image.open(path) as image:
            sample=image.convert('RGBA').crop(box)
            sample.thumbnail((540,650))
            clothing.paste(sample,(x,35),sample)
    ImageDraw.Draw(clothing).text((10,8),'approved reference / latest draft',fill='black')
    clothing.save(destination/'myo-outfit-comparison.png')
    print(json.dumps(report,ensure_ascii=False,indent=2))


if __name__=='__main__':
    main()
