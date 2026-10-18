# 자산 제작 기록

숲빛 프리미엄 v02는 build.mjs의 직접 작성한 벡터 도형과 프로젝트 소유 의미 아이콘 경로로 제작했다. 참고 게임의 이미지를 가져오거나 트레이싱·재색칠하지 않았다. manifest.json에 실제 제작 파일 91종만 등록했으며, 각각 편집 가능한 SVG와 투명 PNG를 제공한다. 텍스트는 자산에 포함하지 않는다. 신규 논리 슬롯은 IMG/forestlight-premium/으로 시작하며 기존 ID와 Godot 등록은 변경하지 않았다.

연두·하늘색·숲 초록·밝은 바탕·진한 글자를 중심으로, 얇은 금색 테두리와 유리 표면 명암을 주요 행동에 사용했다. 기본·눌림·선택·사용 불가 상태를 별도 파일로 제공한다. 선택은 체크와 테두리를, 비활성은 명암과 표시를 함께 사용한다. 원형 행동 버튼의 고유 의미 도형과 잎 방향패드를 유지한다.

## 참고와 제작 경계

- Wild Rift 조작: https://www.leagueoflegends.com/pl-pl/news/game-updates/sterowanie-w-wild-rift/ — 왼손 이동·오른손 행동, 엄지 접근성 참고.
- 조작 화면: https://interfaceingame.com/screenshots/league-of-legends-wild-rift-controls/ — 설정 접근과 정보 위계 참고.
- Brawl Stars: https://supercell.com/en/games/brawlstars/ — 작은 화면의 실루엣 식별 참고.
- Pokémon UNITE: https://unite.pokemon.com/en-us/overview/ — 전투 정보와 행동 영역 분리 참고.

참고 확인일은 2026-10-08이다. 공개 화면을 시각 기준으로 삼았으며 해당 게임의 내부 제작 사양이나 동일 품질을 검증했다고 주장하지 않는다. 신규 자산의 해시·크기·알파와 지정 색상쌍 대비는 asset-audit.json에 기록한다.

## 승인 자료와 미정 자료

기존 승인 배경·캐릭터 원화와 로비의 자현 투명 PNG를 유지했다. PNG는 움직이는 파일이 아니므로 별도 레이어에 작은 호흡 변형을 적용한다. preview.html은 4초 루프와 일시정지·움직임 줄이기를 제공한다. 실제 프레임 애니메이션이나 Godot 런타임 구현은 이번 범위가 아니다.

새 UI 91종의 누락 파일은 0개다. 기존 콘텐츠의 직업·경기장·Story 챕터 확정 원화는 미정이며 기존 의미 아이콘·준비 중 표시를 유지한다. 이전 v01 missing-assets.json의 ‘자현 검정 배경’ 메모는 로비 투명 자산 제작으로 해소되었지만 다른 승인 콘셉트 원본을 일괄 교체하지 않는다.
