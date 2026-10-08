"""Stage review sheets at runtime size without writing approved runtime assets."""
from pathlib import Path
import hashlib
import json
import statistics
import argparse

from PIL import Image

from audit_character_motion_visuals import render_board
from motion_sheet_regions import split_regions

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / '_workspace/character-motion-visual-unification'
# New reference-guided sheets have more transparent padding than recovered
# originals. Calibrate whole sheets, never stretch individual action poses.
SOURCE_SCALE = {
    'ja-hyun/special_neutral': 1.15, 'ja-hyun/ultimate': 1.15,
    'myo-ryung/special_down': 1.3,
    'nabi/hitstun': 1.35, 'nabi/ring_out': 1.35, 'nabi/spawn': 1.35,
    'yu-ran/attack_air_heavy': 1.5, 'yu-ran/jump': 1.5,
    'yu-ran/ring_out': 1.5,
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--exclude', action='append', default=[], help='character/motion under regeneration; not approved')
    args = parser.parse_args()
    report = {}
    failures = []
    manifest = json.loads((ROOT/'assets/character/manifest.json').read_text())
    for cid in ('ja-hyun', 'myo-ryung', 'nabi', 'yu-ran'):
        selected = {}
        for source in sorted((WORK / '02_drafts' / cid).glob('*-r*.png')):
            if cid+'/'+source.stem.rsplit('-r',1)[0] in args.exclude:
                continue
            selected[source.stem.rsplit('-r',1)[0]] = source
        sources = list(selected.values())
        if not sources:
            continue
        sequences = {}
        for source in sources:
            with Image.open(source) as opened:
                if opened.mode != 'RGBA':
                    raise ValueError(f'No RGBA alpha: {source}')
                sheet = opened.copy()
            try:
                sequences[source.stem.rsplit('-r',1)[0]] = split_regions(sheet)
            except ValueError as error:
                failures.append({'character':cid,'motion':source.stem.rsplit('-r',1)[0], 'source':str(source.relative_to(ROOT)), 'reason':str(error)})
        if not sequences:
            continue
        anchor = Image.open(ROOT / f'assets/character/{cid}/animation/runtime/local_ai_v01/attack_heavy_charge_16f.png')
        anchor_height = statistics.median(anchor.crop((i*128, 0, (i+1)*128, 128)).getbbox()[3] - anchor.crop((i*128, 0, (i+1)*128, 128)).getbbox()[1] for i in range(16))
        reference = sequences.get('idle', next(iter(sequences.values())))
        scale = anchor_height / statistics.median(f.height for f in reference)
        # One scale for the entire character; never resize individual poses to fit.
        scale = min(scale, 120/max(f.width*SOURCE_SCALE.get(cid+'/'+name,1) for name,fs in sequences.items() for f in fs),
                    120/max(f.height*SOURCE_SCALE.get(cid+'/'+name,1) for name,fs in sequences.items() for f in fs))
        output = WORK / '03_staged' / cid
        output.mkdir(parents=True, exist_ok=True)
        rows = []
        records = []
        for name, frames in sequences.items():
            source_scale = SOURCE_SCALE.get(cid+'/'+name,1)
            entry = next(x for x in manifest['assets'] if x.get('character_id')==cid and x.get('type')=='animation-runtime' and (x.get('visual_state_id') or Path(x['path']).stem.removesuffix('_16f'))==name)
            fps, loop = entry['fps'], entry['loop']
            strip = Image.new('RGBA', (2048,128))
            review_frames = []
            for i, frame in enumerate(frames):
                resized = frame.resize((round(frame.width*scale*source_scale), round(frame.height*scale*source_scale)), Image.Resampling.LANCZOS)
                cell = Image.new('RGBA', (128,128))
                cell.alpha_composite(resized, ((128-resized.width)//2,124-resized.height))
                strip.paste(cell, (i*128,0))
                review_frames.append(cell)
            path = output / f'{name}_16f.png'
            strip.save(path)
            previews = []
            for cell in review_frames:
                bg = Image.new('RGBA',cell.size,(48,52,60,255))
                bg.alpha_composite(cell)
                previews.append(bg.convert('RGB'))
            previews[0].save(output/f'{name}.gif',save_all=True,append_images=previews[1:],duration=round(1000/fps),loop=0 if loop else 1)
            records.append({'motion':name,'staged_path':str(path.relative_to(ROOT)),
                            'sha256':hashlib.sha256(path.read_bytes()).hexdigest(), 'source_scale':source_scale,
                            'source_path':str(selected[name].relative_to(ROOT)),
                            'source_sha256':hashlib.sha256(selected[name].read_bytes()).hexdigest(), 'fps':fps, 'loop':loop})
            rows.append((name, review_frames))
        render_board(cid,rows,output/'all-candidates.jpg')
        for start in range(0,len(rows),6):
            render_board(cid,rows[start:start+6],output/f'page-{start//6+1:02}.jpg')
        report[cid] = {'scale':scale,'anchor_height':anchor_height,'motions':records}
    (WORK/'03_staged'/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    (WORK/'03_staged'/'failures.json').write_text(json.dumps(failures,indent=2)+'\n')
    print(json.dumps({cid:len(row['motions']) for cid,row in report.items()}))
    if failures:
        print(json.dumps(failures,indent=2))
        raise SystemExit(1)


if __name__ == '__main__':
    main()
