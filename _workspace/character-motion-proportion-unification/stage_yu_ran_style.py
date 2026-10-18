"""Pack only manually calibrated Yu-Ran candidates; keep approved idle pixels intact."""
from pathlib import Path
import hashlib
import html
import json
import math
import shutil
import sys
from PIL import Image, ImageDraw
from stage_style_proofs import matte, sheet, support_x, durations

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
BATCH = WORK / '08_yu_ran-style-locked'
sys.path.insert(0, str(ROOT / 'tools/forest_arena'))
from motion_sheet_regions import split_regions


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def outputs(state, frames, fps):
    folder = BATCH / '04_review' / state
    folder.mkdir(exist_ok=True)
    target = folder / f'{state}-r01-clean.png'
    sheet(frames).save(target)
    frames[0].save(folder / f'{state}-r01-preview-128.png')
    frames[7].save(folder / f'{state}-r01-keypose-128.png')
    animation = [matte(f) for f in frames]
    timing = durations(fps)
    animation[0].save(folder / f'{state}-r01.gif', save_all=True, append_images=animation[1:],
                      duration=timing, loop=0, disposal=2, optimize=False)
    return target, timing


def main():
    assert not (BATCH / 'pending-review-29.json').exists(), 'Shown review frozen; do not overwrite'
    approval = json.loads((WORK / '03_sample_approval.json').read_text())
    idle = next(r for r in approval['samples'] if r['character_id'] == 'yu-ran')
    assert approval['user_approved'] and sha(ROOT / idle['path']) == idle['sha256']
    entries = {e['visual_state_id']: e for e in json.loads((WORK / '01_baseline.json').read_text())['runtime_entries'] if e['character_id'] == 'yu-ran'}
    original_idle = Image.open(ROOT / idle['path'])
    frames = [original_idle.crop((i % 4 * 128, i // 4 * 128, (i % 4 + 1) * 128, (i // 4 + 1) * 128)) for i in range(16)]
    target, timing = outputs('idle', frames, entries['idle']['fps'])
    # Copy original PNG encoding too: pixel AND file hash remain approval-bound.
    shutil.copy2(ROOT / idle['path'], target)
    records = [{'character_id': 'yu-ran', 'visual_state_id': 'idle', 'user_approved': True,
                'review_path': str(target.relative_to(ROOT)), 'review_sha256': sha(target),
                'frame_count': 16, 'original_fps': entries['idle']['fps'], 'original_loop': entries['idle']['loop'],
                'gif_durations_ms': timing, 'approval_record': str((WORK / '03_sample_approval.json').relative_to(ROOT)),
                'note': 'Exact unchanged approved idle PNG; original measurement retained in 03_landmarks.json.'}]
    inspection = {r['state']: r for r in json.loads((BATCH / '04_review/inspection/report.json').read_text())}
    spec = json.loads((BATCH / 'landmarks-r01.json').read_text())
    for state, config in spec['states'].items():
        if state not in inspection:
            continue
        inspected = inspection[state]
        assert not inspected['source_edge_touch_frames'], state
        path = ROOT / inspected['source_path']
        assert sha(path) == inspected['sha256']
        source = Image.open(path)
        poses = split_regions(source)
        index = config.get('index', inspected['calibration_index'])
        neutral_height = config.get('target_neutral_body_height', 72)
        assert abs(neutral_height/72-1) <= .05
        scale = neutral_height / (config['sole_y']-config['crown_y']) if config.get('scale_method') == 'neutral-body-height' else 26 / (config['chin_y']-config['crown_y'])
        head = (config['chin_y']-config['crown_y']) * scale
        assert abs(head/26-1) <= .1
        sizes = [(round(p.width*scale), round(p.height*scale)) for p in poses]
        lefts = [(p['source_box'][0] - i % 4 * source.width/4)*scale for i, p in enumerate(inspected['poses'])]
        origin = inspected['poses'][index]['source_box'][0] - index % 4 * source.width/4
        anchor = support_x(poses[index]) if config.get('alignment', 'ground') == 'ground' or index in config.get('ground_indices', []) else poses[index].width/2
        low, high = 2-min(lefts), 126-max(x+s[0] for x, s in zip(lefts, sizes))
        pivot_aligned = config.get('horizontal_alignment') == 'support-pivot'
        assert pivot_aligned or low <= high, (state, 'horizontal span', low, high)
        assert max(w for w, _ in sizes) <= 124, (state, 'pose width cannot fit at fixed scale')
        offset = max(low, min(high, 64-(origin+anchor)*scale))
        tallest = max(h for _, h in sizes)
        assert tallest <= 122, (state, 'fixed body scale cannot fit', tallest)
        air_center = min(config.get('air_center_y', 78), 126-math.ceil(tallest/2))
        assert air_center >= 2+math.ceil(tallest/2)
        frames, measurements = [], []
        for i, (pose, size) in enumerate(zip(poses, sizes)):
            x = round(lefts[i]+offset)
            if pivot_aligned:
                # Technical pivot translation only. One physical scale remains fixed.
                x = max(2, min(126-size[0], round(64-support_x(pose)*scale)))
            ground = config.get('alignment', 'ground') == 'ground' or i in config.get('ground_indices', [])
            y = 124-size[1] if ground else round(air_center-size[1]/2)
            assert x >= 2 and x+size[0] <= 126 and y >= 2 and y+size[1] <= 126, (state, i, x, y, size)
            frame = Image.new('RGBA', (128, 128))
            frame.alpha_composite(pose.resize(size, Image.Resampling.LANCZOS), (x, y))
            frames.append(frame)
            measurements.append({'index': i, 'fixed_scale': scale, 'bbox': list(frame.getbbox()),
                                 'ground_foot_anchor': ground, 'rgba_sha256': hashlib.sha256(frame.tobytes()).hexdigest()})
        assert len({r['rgba_sha256'] for r in measurements}) == 16
        target, timing = outputs(state, frames, entries[state]['fps'])
        guide = matte(poses[index].resize((poses[index].width*3, poses[index].height*3)))
        draw = ImageDraw.Draw(guide)
        for name, color in [('crown_y', '#ffca61'), ('chin_y', '#8fffc0')]:
            yy = config[name]*3
            draw.line((0, yy, guide.width-1, yy), fill=color, width=2)
            draw.text((3, max(0, yy-13)), f'{name}={config[name]} / frame{index+1}', fill=color)
        guide.save(target.parent / 'head-calibration.png')
        records.append({'character_id': 'yu-ran', 'visual_state_id': state, 'user_approved': False,
                        'source_path': inspected['source_path'], 'source_sha256': sha(path), 'source_dimensions': list(source.size),
                        'source_alpha_range': list(source.getchannel('A').getextrema()),
                        'review_path': str(target.relative_to(ROOT)), 'review_sha256': sha(target),
                        'frame_count': 16, 'fixed_motion_scale': scale, 'head_height_after_scale': head,
                        'neutral_body_height_after_scale': neutral_height if config.get('scale_method') == 'neutral-body-height' else None,
                        'calibration_index': index, 'head_landmarks': config, 'common_horizontal_offset': offset,
                        'air_center_y': air_center, 'original_fps': entries[state]['fps'], 'original_loop': entries[state]['loop'],
                        'gif_durations_ms': timing, 'frames': measurements})
        print(state, 'staged', round(scale, 5), 'head', round(head, 2), flush=True)
    ordered = {r['visual_state_id']: r for r in records}
    records = [ordered[s] for s in entries if s in ordered]
    out = BATCH / '04_review'
    report = {'status': 'review-ready-pending29' if len(records) == 30 else 'production-in-progress',
              'approved_count': 1, 'pending_count': len(records)-1, 'expected_total': 30,
              'quantitative_scope': 'Comparable head and neutral body height only, not all-joint 3D proof.', 'states': records}
    (out / '30-motion-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    overview = Image.new('RGB', (1280, math.ceil(len(records)/5)*280+40), '#243044')
    draw = ImageDraw.Draw(overview)
    draw.text((12, 10), 'YU-RAN / SAME APPROVED IDLE MASTER / review only', fill='white')
    cards = []
    for n, row in enumerate(records):
        state = row['visual_state_id']
        x, y = n % 5 * 256, 40+n//5*280
        key = Image.open(out / state / f'{state}-r01-keypose-128.png')
        overview.paste(matte(key).resize((256, 256), Image.Resampling.NEAREST), (x, y))
        draw.text((x+4, y+258), state, fill='white')
        safe = html.escape(state)
        status = '기존 승인' if row['user_approved'] else '새 시안·승인 대기'
        cards.append(f'<article><h2>{safe}</h2><p>{status}</p><img src="{safe}/{safe}-r01.gif" width="256" height="256"><p><a href="{safe}/{safe}-r01-clean.png">16포즈 투명 시트</a></p></article>')
    overview.save(out / '30-motion-overview.png')
    page = '<!doctype html><html lang="ko"><meta charset="utf-8"><title>유란 동일 그림체 모션 검토</title><style>body{background:#202b3b;color:#edf2ff;font:16px system-ui;margin:28px}a{color:#9bdfff}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:18px}article{background:#344154;padding:16px;border-radius:12px}h2{font-size:16px}img{image-rendering:pixelated}</style><h1>유란 동일 그림체 모션 검토</h1><p>승인된 idle은 그대로 보존했습니다. 새 모션은 승인 전이며 게임에 반영하지 않았습니다. GIF는 검토용 반복으로 실제 FPS·반복·판정 설정을 바꾸지 않습니다.</p><div class="grid">'+''.join(cards)+'</div></html>'
    (out / 'index.html').write_text(page)
    assert sha(ROOT / idle['path']) == idle['sha256'] == sha(out / 'idle/idle-r01-clean.png')
    print(f'YU-RAN REVIEW: {len(records)}/30; approved idle unchanged; no runtime writes.')


if __name__ == '__main__':
    main()
