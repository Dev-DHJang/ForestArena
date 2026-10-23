# 대표 10종 실제 등록 후 독립 QA r01

담당: `installed_pilot_qa` / 역할 `qa`. 2026-10-23. 사용자 “승인한다.”에 따라 root가 등록한 대표 10종의 **실제 등록 및 소비 검사 결과는 pass**다. 새 26종의 승인이나 전체 36종의 완료 판정은 포함하지 않는다. 이 검토자는 승인 기록, manifest, 런타임 PNG, 생산 코드를 수정하지 않았다.

## 등록 파일 검사

`qa/installed-pilot-before-r01.json`에 등록 직전 HEAD `63e13d8554f137b0d47cd81a90e3ff744fc8a94f`의 manifest 124항목과 연결 파일 246개의 해시를 독립 보존했다. 등록 뒤 `python3 _workspace/motion-naturalness-v1/qa/installed-pilot-static.py`의 **604검사 PASS**를 확인했다.

- 고정 계획의 21개 출력(새 PNG 10개·SpriteFrames 10개·manifest 1개)은 계획한 최종 해시와 모두 일치한다.
- 기존 9종의 논리 ID와 SpriteFrames 소비 경로(게임이 읽는 파일 위치)를 보존하고, 자현 `attack_light_combo_04`만 새 항목으로 추가했다. 전체 animation-runtime은 120→121이다.
- 이전 승인 PNG는 그대로 존재하며 원래 SHA-256과 일치한다. 나머지 manifest 항목과 연결 파일은 변경되지 않았다.
- 새 PNG는 검토·승인된 후보의 바이트와 같고, 프레임 수·표시 배율·접지 부착점·구간·재생 속도·루프 설정도 후보 값과 같다. 두 점프는 실제 `frame_count=24`다. 기존 논리 ID 안의 `16f` 문자열은 호환을 위해 유지된다.
- 각 새 manifest 항목은 이번 사용자 승인 기록을 연결한다. 검사 결과는 `qa/installed-pilot-static-r01.json`에 있다.

## 실제 게임 소비 검사

`qa/installed-pilot-live.gd`는 이전 실제 입력 촬영 절차를 바탕으로 후보 주입 코드를 완전히 제거한 별도 검사다. `CandidateFrames` 호출이나 `_motions` 덮어쓰기가 없다. 실제 Presentation이 manifest에서 발견해 읽은 SpriteFrames의 경로와 atlas를 직접 확인한다. 실제 MatchController·지형·60Hz 입력의 달리기/해제, 점프/착지, 전체 약공격 연계를 두 캐릭터 각각 촬영한다. 현재 그림의 `body_root`가 있으면 실제 표시 변환이 지면 기준에 도달하는지도 검사한다.

이 촬영은 원화 검토를 위해 OS 초점에 따른 일시정지 알림만 제외한다. Android 기기 생명주기 검사의 대체가 아니다. 실제 Android 기기가 없으므로 기기 가독성·엄지 접근성·중단/복귀·성능은 미실행이다.

## 실제 결과와 직접 본 범위

- 정방향 줌1.50와 좌우 반전·소형 줌0.75를 각각 실제 입력 6클립/804틱으로 촬영했다. 각 **4520검사 PASS**, 오류0이다. 시작·달리기 해제·점프·착지·기본 연계·실제 타격과 상대 HP 감소·idle 복귀를 포함한다. 그림을 표시하기 전후의 전체 전투 상태가 매틱 같았고, 등록된 부착점의 접지 변환도 통과했다.
- `qa/installed-pilot-compare.py`로 승인된 `review/live-pilot-r06`, `review/live-pilot-mirror-r06`와 각각 같은 초기값·입력의 모든804틱을 대조했다. 각 **6459검사 PASS**, 차이0이다. 입력, 사용한 실제 공격, 전체 전투 snapshot, 표시 모션/프레임/배율/위치/반전 상태가 같고, 두 파이터의 실제 SpriteFrames·atlas 소비 경로가 현재 manifest와 매틱 일치한다.
- 설치 후 실제 화면의 핵심 그림12보드(각6장, 총72장)를 직접 보았다. 두 캐릭터의 달리기/정지, 점프/착지, 자현 왼손→오른손→왼손→킥, 나비 전방→상향→X 연계가 표시된다. 정방향과 반전소형에서 새 잘림이나 접지 이탈을 발견하지 않았다. 이72장 관찰을 “새1608장을 모두 육안 검토했다”로 확대하지 않는다. 원화의 행위·전체 프레임과 정상/느린 재생은 승인 전 독립 QA r06의 범위이며, 이번에는 같은 승인 PNG와 표시 데이터가 등록 후에도 동일한 상태/프레임으로 선택됨을 검사했다.
- 정상 자료: `qa/installed-pilot-live-normal-r01/`의 영상·핵심 그림·상태 보고서. 반전소형 자료: `qa/installed-pilot-live-mirror-small-r01/`. 두 폴더의 `index.html`에서 정상/0.25배로 재생할 수 있다. 이번 역할이 새 브라우저 재생 승인이나 원화 재승인을 남긴 것은 아니다.
- 원본1608 PNG는 각 RGBA 프레임이 정확히 복원되는 무손실 H.264 RGB CRF0 아카이브로 보존했다. 모든 원본 PNG 해시와 RGBA 프레임 해시·영상 해시를 각 `rgba-archive.json`에 남긴 뒤 큰 PNG 폴더만 정리했다. 원화나 런타임 자산에는 이 변환을 하지 않았다. 현재 증거 파일 해시는 `qa/installed-pilot-evidence-r01.json`에 있다.

## 설치 후 검사용 도구 변경 검토

root가 수정한 `motion_review_timeline.gd`, `review_motion_actions.py`, `test_motion_action_review.py`를 읽었다. 기본 timeline이 등록 항목의 해시로 고정된 catalog에서 실제 moveset과 기대 행위를 읽고, 미변경 항목은 기존 base moveset을 따르는 변경은 새 자현 킥을 누락하던 원인에 맞다. 사용한 moveset을 출처 해시에 포함한다. 기존120개 고정 검사 대신 manifest와 전체 ID 집합/개수 일치 및 킥의 실제10/4/22틱을 확인하므로 범위 검사를 줄이지 않는다. 수정 요청은 없다.

기존 점프16장 기대값을 새 승인24장의 하강15/착지16→23으로 바꾼 `tests/two_fighter_presentation.gd`도 실제 등록 범위와 일치한다. 전체 필수 검사에서 발견된 오래된 계약 기대값의 갱신과 최종 `verify.sh` 재실행은 root가 수행 중이다. **이번 독립 설치 검사 pass를 아직 실행 중인 전체 검사 pass로 쓰지 않는다.** 전체36종의 제작/승인/등록, 최종 LAN 검증·PR 검토·병합 완료의 증거로도 쓰지 않는다.
