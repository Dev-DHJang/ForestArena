"""Assemble a read-only pilot review page; never grant approval or install art."""
from pathlib import Path
import hashlib, html, json

b = Path(__file__).resolve().parent
root = b.parents[1]
out = b / 'review/final-pilot-r01'
out.mkdir(exist_ok=True)
catalog = json.loads((b / 'candidate-catalog.json').read_text())
review = json.loads((b / 'review/pilot-r04/motion-review.json').read_text())
statuses = {(r['character_id'], r['motion']): r['status'] for r in review['motions']}
approval_path = b / 'user-motion-registration-approval.json'
receipt_path = b / 'qa/installation-receipt-r01.json'
installed = False
if approval_path.exists() and receipt_path.exists():
    approval = json.loads(approval_path.read_text())
    receipt = json.loads(receipt_path.read_text())
    installed = receipt.get('status') == 'installed' and receipt.get('plan_sha256') == approval.get('plan_sha256') and len(approval.get('motions', [])) == 10 and all(row.get('user_approved') for row in approval['motions'])
esc = html.escape
parts = ['''<!doctype html><html lang="ko"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>자현·나비 대표 모션 10종 검토</title>
<style>body{margin:24px auto;padding:0 20px;max-width:1200px;background:#192330;color:#eff5f8;font:16px/1.6 system-ui}h1{font-size:26px}h2{font-size:22px;margin-top:36px}a{color:#9edaff}article{padding:18px;margin:16px 0;background:#253345;border-radius:12px}img,video{max-width:100%;height:auto}button{font:inherit;padding:8px 16px;margin:4px;border-radius:8px}code{overflow-wrap:anywhere}small{color:#c1d0df}.clips{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,480px),1fr));gap:16px}</style>
<h1>자현·나비 대표 모션 10종</h1>
<p>달리기·점프·약공격의 연결을 검토한 대표 10종 영상입니다. 승인 당시의 후보 재생을 보존합니다. 등록 상태와 남은 26종의 진행 내용은 아래에 표시합니다.</p>
<p>실제 경기 영상은 제품의 전투·지형·카메라·표시 코드를 사용합니다. 촬영 중 OS 포커스 일시정지만 제외했습니다. Android 기기 중단·복귀 검사 결과가 아닙니다.</p>
<p>영상의 전체 화면 버튼으로 크게 볼 수 있습니다. 자세 연결은 정상 속도와 느린 속도에서 함께 확인합니다.</p>
<p><button onclick="speed(1)">정상 속도 1×</button><button onclick="speed(.25)">느리게 0.25×</button><button onclick="document.querySelectorAll('video').forEach(v=>{v.pause();v.currentTime=0})">처음으로</button></p>
<script>function speed(s){document.querySelectorAll('video').forEach(v=>{v.playbackRate=s})}</script>''']
parts.append('<p><strong>2026-10-23: 대표 10종 사용자 승인·게임 자산 등록 완료.</strong> <a href="../../03_qa_installed_pilot_r01.md">설치 후 독립 QA</a>. 남은 26종은 제작 중이며 아직 승인·등록되지 않았습니다.</p>' if installed else '<p>대표 10종의 사용자 승인과 게임 자산 등록을 기다립니다.</p>')
for label, folder in [('정상 크기 · 줌 1.50', 'live-pilot-r06'), ('좌우 반전 · 작은 표시 · 줌 0.75', 'live-pilot-mirror-r06')]:
    report_path = b / 'review' / folder / 'state-report.json'
    parts.append(f'<h2>{label}</h2><div class="clips">')
    if not report_path.exists():
        parts.append('<p>촬영·확인 중입니다.</p>')
    else:
        report = json.loads(report_path.read_text())
        assert not report['errors'], 'failed capture cannot appear as review footage'
        for clip in report['scenarios']:
            video = b / 'review' / folder / (clip['name'] + '.mp4')
            assert video.exists(), video
            name = clip['name'].replace('ja-hyun', '자현').replace('nabi', '나비').replace('__', ' · ').replace('run-stop', '달리기 → 정지').replace('jump-land', '점프 → 착지').replace('full-combo', '약공격 전체 연계')
            parts.append(f'<article><strong>{esc(name)}</strong><video controls loop playsinline preload="metadata" src="../{folder}/{video.name}"></video></article>')
    parts.append('</div>')
parts.append('<h2>10종 전체 그림</h2><p>아래는 각 그림의 자세·순서를 보는 자료입니다. 실제 크기·접지와 연결은 위 경기 영상에서 확인합니다. 별도 타임라인 페이지의 캔버스는 그림 선택과 시간 확인용이며 몸 크기·발 위치 보정을 재현하지 않습니다.</p>')
for row in catalog['assets']:
    key = row['character_id'] + '__' + row['visual_state_id']
    board = '../pilot-r04/boards/' + key + '.jpg'
    status = statuses[(row['character_id'], row['visual_state_id'])]
    label = {'pass':'통과', 'fix':'수정 필요', 'redo':'재제작 필요', 'blocked':'검토 중'}[status]
    parts.append(f'<article><strong>{esc(key)}</strong> · {row["frame_count"]}장 · 독립 검토: {label}<p>{esc(row["expected_action"])}</p><a href="{board}"><img loading="lazy" src="{board}" alt="{esc(key)} 전체 프레임"></a></article>')
digest = hashlib.sha256((b/'candidate-catalog.json').read_bytes()).hexdigest()
parts.append(f'<p><small>후보 목록 SHA-256: <code>{digest}</code><br>{"대표 10종 승인·등록 완료" if installed else "승인 전 후보"} · 피해·공격 시간·60Hz 전투 계산 변경 없음 · Android 기기 검사 미실행</small></p></html>')
(out/'index.html').write_text('\n'.join(parts))
print(out/'index.html')
