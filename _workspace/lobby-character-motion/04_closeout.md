# 로비 캐릭터 투명 이미지·미세 움직임 마무리

승인 자현 콘셉트를 보존하고 imagegen 편집으로 투명 RGBA PNG 파생본 1장을 만들었다. 출력 크기는 1086×1448이며 네 모서리 알파는 0이다. 제작 출처와 파일 해시는 visual-review.json에 기록했다. 원본과 픽셀 단위 동일성을 주장하지 않는다.

Penpot Forest_Arena_UI의 SCR_03_Lobby와 20:9 비교 보드, 기본 로비 프로토타입에 적용했다. 기본 로비의 12개 이동 연결을 유지했다. 별도 MOTION rest/inhale 2개 보드와 자동 전환 2개를 추가했으며 프로토타입 페이지의 보드 수는 기존 51개에서 53개가 되었다. 신규 재사용 컴포넌트는 0개다. 이미지 매핑 1개 보드와 개발 전달 1개 보드를 추가했다. 새 이미지에 누락 자산은 없다.

PNG는 정적 파일이며 preview.html에서 4초 반복 호흡·흔들림을 적용한다. 크기 변화 0.6%, 회전 ±0.1°, 아래 중심 고정과 약 2.4px 수직 이동을 사용한다. 메뉴는 고정한다. Penpot는 두 상태의 dissolve 전환으로 움직임 의도를 비교하며 정확한 연속 변형은 HTML 미리보기에서 확인한다.

이름을 붙인 수동 재검사 결과:

- LOBBY_ALPHA_16_9: 밝은 숲 배경에서 검은 사각 배경 없음. 두 귀·한 꼬리·리본·검은 의상 식별, 버튼과 겹침 없음. lobby-transparent.png에 내보내기 증거를 남겼다.
- LOBBY_ALPHA_20_9: 중앙 영역과 안전 영역 비교에서 캐릭터·하단 메뉴 잘림 없음. compare20.png에 내보내기 증거를 남겼다.
- LOBBY_BREATH_LOOP: 브라우저에서 animation-duration 4s와 시간에 따라 달라지는 transform 확인.
- LOBBY_BREATH_PAUSE: 일시정지 후 두 번의 관측에서 같은 transform과 paused 확인. 재생 버튼으로 running 복귀 확인.
- LOBBY_PENPOT_FLOW: 실제 보기 모드에서 inhale 상태 표시와 플레이 → SCR_09_ModeSelect 이동 확인. 두 보드 각각 12개 메뉴 연결 유지.
- LOBBY_REDUCED_MOTION: prefers-reduced-motion CSS 규칙 확인. 운영체제 설정을 바꾸는 실측은 수행하지 않았다.

./scripts/verify-docs.sh PASS, ./scripts/verify.sh PASS. 첫 문서 검사에서 Finder의 docs/.DS_Store가 최상위 파일 규칙에 걸려 작업 폴더에 백업한 뒤 재검사했다. 기본 검사 로그의 기존 ObjectDB 종료 경고는 남아 있으나 검사 종료 결과는 통과다.

이번 변경은 설계 전용이다. Godot 화면·입력·전투 모션·캐릭터 manifest·resource_registry는 변경하지 않았다. 별도 Godot 리소스 등록 검사는 변경 대상이 없어 수행하지 않았다. 다른 작업의 기존 수정 파일은 보존했다. Android 실제 터치와 앱 중단·복귀는 구현 후 기기 확인 대상이다. 현재 로비 효과 외 눈 깜박임·팔다리별 애니메이션은 포함하지 않는다.

로컬 확인: python3 _workspace/lobby-character-motion/serve_preview.py 실행 후 http://127.0.0.1:4422/preview.html을 연다. HTML 파일을 직접 열어도 상대 경로 이미지가 표시된다.

Penpot 움직임 보기: https://design.penpot.app/#/view?file-id=d8ac01df-6646-81d2-8008-a3696fea940e&page-id=fa154361-0c45-804b-8008-a716ae2e1448&section=interactions&frame-id=8626232c-968c-808f-8008-c1a6cb15babf&zoom=fit
