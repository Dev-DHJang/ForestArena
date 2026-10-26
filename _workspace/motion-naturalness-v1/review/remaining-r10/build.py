"""Assemble a local, text-and-file review page without copying or rewriting art."""
from pathlib import Path
from html import escape
import json,os,hashlib
BASE=Path(__file__).resolve().parent
TOP=BASE.parents[1]
REVIEW=TOP/'qa/remaining-candidate-review-r10-final'
CATALOG=TOP/'remaining-candidate-catalog-r10.json'
data=json.loads((REVIEW/'motion-review.json').read_text())
assert len(data['motions'])==25
labels={'idle':'대기','guard':'가드','hitstun':'피격','launch':'공중 피격','knock_down':'쓰러짐','wake_up':'일어남','death':'사망','ring_out':'장외 탈락','spawn':'재등장','attack_air_heavy':'공중 강공격','attack_air_light':'공중 약공격','attack_heavy_up':'지상 강공격 · 올려치기','special_neutral':'지상 강공격 · 목도리 끌어오기','special_side':'돌진 특수기'}
def link(path):return escape(os.path.relpath(path,BASE),quote=True)
parts=['''<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>자현·나비 새 모션 25종 검토</title><style>body{font:16px/1.6 system-ui,sans-serif;background:#101827;color:#eef2ff;max-width:1200px;margin:0 auto;padding:24px}a{color:#9fcdff}h1{font-size:28px}h2{margin-top:40px}article,section{background:#1b2940;padding:18px;margin:16px 0;border-radius:12px}img,video{display:block;width:100%;height:auto;max-width:1100px}small{color:#b9c6da}.pending{color:#ffdb8a}button{font:inherit;padding:8px 14px;margin:8px 8px 8px 0;background:#d8eaff;border:0;border-radius:7px}.clips{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:12px}details{margin:12px 0}summary{cursor:pointer;padding:8px}code{overflow-wrap:anywhere}</style><h1>자현·나비 새 모션 25종</h1><p>자현 12종과 나비 13종을 확인하는 자료입니다. 이미 승인·등록한 자현 목도리 잔상 특수기는 이 목록에 포함하지 않습니다.</p>''']
approval=json.loads((TOP/'remaining-user-motion-registration-approval-r10.json').read_text())
receipt=json.loads((TOP/'qa/approved-registration-r10/receipt.json').read_text())
installed=receipt.get('status')=='installed' and len(approval.get('motions',[]))==25
counts={k:sum(m['status']==k for m in data['motions']) for k in ['pass','fix','redo','blocked']}
parts.append('<p class="pending">독립 검토: 통과 '+str(counts['pass'])+'종 · 수정 필요 '+str(counts['fix']+counts['redo'])+'종 · 확인 중 '+str(counts['blocked'])+'종. '+('새 25종은 사용자 승인 후 게임에 등록했습니다.' if installed else '새 25종은 아직 게임에 등록하지 않았습니다.')+'</p>')
parts.append('<p>아래 비교판은 전체 원화, 뒤의 영상은 실제 전투 입력으로 촬영한 화면입니다. 영상에서 보통·느린 속도를 선택할 수 있습니다. Android 실제 기기 검사는 하지 않았습니다.</p><p>후보 목록 SHA-256: <code>'+hashlib.sha256(CATALOG.read_bytes()).hexdigest()+'</code></p>')
for cid,who in [('ja-hyun','자현'),('nabi','나비')]:
 parts.append('<h2>'+who+' 모션</h2>')
 for row in data['motions']:
  if row['character_id']!=cid:continue
  board=next(k for k in row['materials'] if k.startswith('boards/'))
  parts.append('<article><h3>'+who+' · '+escape(labels.get(row['motion'],row['motion']))+'</h3><p>'+escape(row['expected_action'])+'</p><small>'+escape(row['motion'])+' · '+escape(row['status'])+'</small><details><summary>전체 프레임 보기</summary><img loading="lazy" alt="'+escape(who+' '+row['motion'])+' 전체 프레임" src="'+link(REVIEW/board)+'"></details></article>')
parts.append('<h2>실제 게임 연속 재생</h2><p>상태 장면은 피격·날림·착지·일어남 등 여러 모션의 연결을 함께 보여 줍니다. 정상 방향은 줌1.50, 반전 소형은 줌0.75로 촬영했습니다.</p>')
actual=TOP/'qa/remaining-live-r11'
for family,title in [('state','상태 전환'),('ja-attacks','자현 공격'),('nabi-attacks','나비 공격')]:
 report=json.loads((actual/(family+'-normal')/'state-report.json').read_text())
 for scene in report['scenarios']:
  parts.append('<section><h3>'+escape(title+' · '+scene['name'])+'</h3><div class="clips">')
  for direction,label in [('normal','정상'),('mirror-small','반전 소형')]:
   src=actual/(family+'-'+direction)/(scene['name']+'.mp4');assert src.is_file()
   parts.append('<div><p>'+label+'</p><video controls preload="none" src="'+link(src)+'"></video><button onclick="this.parentElement.querySelector(\'video\').playbackRate=1">보통 속도</button><button onclick="this.parentElement.querySelector(\'video\').playbackRate=.5">0.5배속</button></div>')
  parts.append('</div></section>')
parts.append('<h2>LAN 공중 피격 연결</h2><p>실제 서버에 연결한 두 클라이언트의 검토용 표시 화면입니다. 같은 피격 대상을 소유한 쪽과 원격으로 보는 쪽을 나란히 담았습니다.</p>')
for cid,who in [('ja-hyun','자현'),('nabi','나비')]:
 for direction,label in [('normal','정상'),('mirror','반전')]:
  src=TOP/'qa/lan-launch-release-visual-independent-r01'/f'{cid}-{direction}-actual-vfr.mp4'
  assert src.is_file()
  parts.append('<section><h3>'+who+' · LAN '+label+'</h3><video controls preload="none" src="'+link(src)+'"></video><button onclick="this.parentElement.querySelector(\'video\').playbackRate=1">보통 속도</button><button onclick="this.parentElement.querySelector(\'video\').playbackRate=.5">0.5배속</button></section>')
parts.append('<p>정식 모션 검토 기록: <a href="'+link(REVIEW/'index.html')+'">검토 양식과 원화 자료</a></p></html>')
(BASE/'index.html').write_text('\n'.join(parts))
print('review page prepared; 25 cards, 30 actual gameplay clips; current status',counts)
