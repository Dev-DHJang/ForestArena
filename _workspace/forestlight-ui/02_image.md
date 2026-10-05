# 숲빛 UI 자산 제작

## 제작 방식과 원본성

사용자가 선택한 숲빛 유리·잎 장식을 SVG 경로와 그라데이션으로 직접 설계했다. Wild Rift는 왼손 이동·오른손 행동, 주요 행동 우선순위와 설정 접근의 사용 원리만 참고했다. 제3자 이미지·아이콘·테두리·문양을 추출하거나 트레이싱하지 않았다.

- 참고: https://www.leagueoflegends.com/pl-pl/news/game-updates/sterowanie-w-wild-rift/
- 참고: https://interfaceingame.com/screenshots/league-of-legends-wild-rift-controls/
- 새 UI 원본: `assets/ui/forestlight-v01/*.svg`
- 투명 PNG: 동일한 파일 이름의 `.png`; SVG와 같은 기하 형태를 resvg로 렌더링했다.
- 기록: 같은 폴더의 `manifest.json`, `asset-requirements.csv`
- 생성기: 이 작업 폴더의 `asset-kit.mjs`

재생성은 이 폴더에서 `npm ci` 후 `npm run build`로 수행한다. `package-lock.json`에 resvg 2.6.2를 고정했으며 임시 폴더에 설치된 패키지에 의존하지 않는다. PNG 안에는 글자를 넣지 않는다.

87개 자산은 버튼·탭·카드·패널 상태 24개, 의미 아이콘 33개, 행동 버튼 상태 20개, 방향패드 상태 6개, 슬라이더·토글·로딩 4개다. UI 문구는 이미지에 넣지 않았다. 현재 자산은 제작된 설계 검토본이며 Godot 리소스 연결 목록에는 등록하지 않았다.

## 이미지 재사용

기존 high 품질의 로비·Splash 배경과 자현·묘령·나비의 승인 콘셉트를 재사용했다. Penpot 전송용 사본은 종횡비를 유지해 축소했으며 형태·색상을 다시 그리지 않았다. 자현 원본은 불투명 검정 배경을 포함한다. 새 투명 캐릭터 원화를 제작한 것으로 기록하지 않는다.

`image-mapping.csv`는 기존 61개 `IMG/*` 슬롯과 현재 리소스 목록의 파일을 대조한다. 원래 `assets/ui/generated/` 경로 대신 등록된 `forest_arena/assets/` 경로에서 61개 모두 파일이 확인됐다. 파일 누락은 0개이며, 신규 로스터는 승인 전이므로 표시하지 않는다. 새 벡터 대체, 승인 콘셉트 재사용과 이번 화면에서 미사용인 항목을 각각 기록했다. 기존 슬롯 ID와 원래 목록의 형식은 변경하지 않는다.

## 시각 규칙

연두 `#B8DE78`, 하늘색 `#91D5EF`, 숲 초록 `#27634D`, 밝은 바탕 `#F4F9EE`, 진한 글자 `#183D35`를 사용한다. 비대칭 잎 모서리와 얇은 잎맥으로 독창적인 프레임을 만들었다. 일반 UI 텍스트는 Noto Sans KR이다. 장신구는 등급·희귀도 표시를 갖지 않는다.

법적 권리 확인을 완료했다는 보증이 아니라, 실제 사용한 입력과 제작 방법의 기록이다.
