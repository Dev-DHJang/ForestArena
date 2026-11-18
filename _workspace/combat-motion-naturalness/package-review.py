"""Keep compact, reproducible visual evidence for the pending motion review."""
from pathlib import Path
import json
import shutil
import subprocess
import sys
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
REV = sys.argv[1] if len(sys.argv) > 1 else 'r02'
OUT = ROOT / f'_workspace/combat-motion-naturalness/review-{REV}/live'
OUT.mkdir(parents=True, exist_ok=True)

for variant, folder in [('candidate', f'candidate-live-{REV}'), ('small-flipped', f'candidate-mirrored-small-{REV}')]:
    source = ROOT / 'build/combat-naturalness' / folder
    report = source / 'state-report.json'
    if not report.exists():
        continue
    shutil.copy2(report, OUT / f'{variant}-state-report.json')
    for clip in json.loads(report.read_text())['scenarios']:
        cid = clip['character_id']
        frames = source / clip['name']
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-framerate', '60', '-i', str(frames / 'frame-%03d.png'), '-c:v', 'libx264', '-crf', '19', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(OUT / f'{cid}-{variant}.mp4')], check=True)
        crop = (540, 220, 860, 390) if variant == 'candidate' else (520, 290, 740, 410)
        width, height = crop[2]-crop[0], crop[3]-crop[1]
        for page in range(3):
            board = Image.new('RGB', (width*6, (height+22)*9), '#14281f')
            draw = ImageDraw.Draw(board)
            for offset in range(54):
                frame = page*54+offset
                path = frames / f'frame-{frame:03d}.png'
                if not path.exists():
                    continue
                x, y = offset%6*width, offset//6*(height+22)
                board.paste(Image.open(path).crop(crop).convert('RGB'), (x,y+22))
                state = clip['states'][frame]
                label = '/'.join(f"{p['shown_motion']}:{p['frame']+1}" for p in state['drawn'])
                draw.text((x+3,y+4), f'{frame:03d} {label}', fill='white')
            board.save(OUT / f'{cid}-{variant}-sequence-{page+1}.jpg', quality=92)

# Show every tick across prone -> wake -> idle; do not select only nice poses.
frames = ROOT / f'build/combat-naturalness/candidate-live-{REV}/ja-hyun__full-combo'
board = Image.new('RGB', (280*6, 185*4), '#14281f')
draw = ImageDraw.Draw(board)
for offset, frame in enumerate(range(122,146)):
    x, y = offset%6*280, offset//6*185
    board.paste(Image.open(frames / f'frame-{frame:03d}.png').crop((680,225,960,390)).convert('RGB'),(x,y+20))
    draw.text((x+4,y+3),f'tick {frame} / {frame/60:.3f}s',fill='white')
board.save(OUT / 'nabi-down-wake-idle-every-tick.jpg',quality=95)

for cid in ['ja-hyun','nabi']:
    shutil.copy2(ROOT / f'_workspace/combat-motion-naturalness/review-r01/live/{cid}-before.mp4', OUT / f'{cid}-before.mp4')
page = (ROOT / '_workspace/combat-motion-naturalness/review-r01/play.html').read_text()
page = page.replace('두 모션 시안','세 모션 시안').replace('두 시안 적용','세 시안 적용')
page = page.replace('나비: 다시 일어서는 중간 자세를 없앤 새 넘어짐16프레임.', '나비: 다시 일어서는 중간 자세를 없앤 새 넘어짐16프레임과 누움→일어남을 연결하는 새 기상16프레임.')
page = page.replace('live/before-after.jpg','live/nabi-down-wake-idle-every-tick.jpg')
page = page.replace('<h2>같은 시점 비교</h2>', '<h2>나비 다운→기상→대기 매 틱 비교</h2>')
page = page.replace('<h2>나비 다운→', '<h2>좌우 반전 · 작은 크기</h2><div class="grid"><video controls muted playsinline src="live/ja-hyun-small-flipped.mp4"></video><video controls muted playsinline src="live/nabi-small-flipped.mp4"></video></div><h2>나비 다운→')
page = page.replace("let videos=[...document.querySelectorAll('video')];", "let videos=[...document.querySelectorAll('video')].filter(v=>v.readyState>=2);")
if REV == 'r05':
    page = page.replace('세 모션 시안','네 모션 시안').replace('세 시안 적용','연결 시안 적용')
    page = page.replace('<h2>자현 연계', '<p><a href="special/index.html">추가 확인: 자현 특수기 전체 표시 크기 +18% 전후 비교</a></p><p>채택 대상: 자현 마지막 킥 · 자현 특수기 · 나비 다운 · 나비 기상. 네 항목 모두 개별 승인 전입니다. 나비 다운·기상은 같은 배율0.71을 사용합니다.</p><h2>자현 연계')
    page = page.replace('모션별 전체 프레임·재생 자료', '네 모션 전체 프레임·개별 재생 자료')
(OUT.parent / 'play.html').write_text(page)
