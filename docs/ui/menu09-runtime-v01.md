# MENU09 실제 앱 메뉴

2026-11-11. 승인한 손그림 기반 MENU09 화면을 Godot 메뉴에 연결했다. 로비, 캐릭터 스탯·기술·스토리, 신기, 상점, 미션·출석·업적, 친구·우편·공지·설정과 일반·AI·랭킹 대전 준비를 다룬다. 이전 메뉴 기능의 저장·서비스 계약은 [프리미엄 메뉴 v07 앱 연결](premium-menu-runtime-v07.md)과 [메뉴 기능](menu-features-v01.md)을 따른다.

상점에서는 캐릭터와 신기 카드를 선택해 상세를 본다. 현재 활성 상품만 기존 0원 구매를 사용할 수 있다. 비활성 캐릭터·신기는 소개로 표시하고 선택·장착·판매를 허용하지 않는다. 조약돌·무지개돌 상품 구성과 결제 조건은 미정이다. 경기 데이터의 내부 ID와 저장 형식은 유지한다.

영상은 기존 소개 미디어를 Godot이 재생할 수 있는 Ogg Theora로 변환해 앱에 포함한다. 재생·일시정지·재시작·닫기를 제공하고 앱이 백그라운드로 가면 일시정지한다. 새 이미지와 영상은 `ForestArenaResources`의 `fa.ui.menu09.*` 논리 ID로 참조한다. 원본과 변환물의 목록·해시는 [미디어 제작 기록](../../_workspace/menu-sketch-ui/app-media-r01/02_media.md)에 있다.

일일·주간 미션과 친구는 기존 서비스를 사용한다. 출석·우편·공지의 운영과 수집·기술 업적은 미정 또는 준비 중으로 표시한다. 랭킹의 실버 3은 예시이며 기존 LAN 승패 순위는 별도 화면으로 연결한다. 공개 방 목록·자동 매칭과 시즌 운영은 준비 상태로 표시한다. 실제 LAN은 기존 같은 Wi-Fi 1:1이다.

[작업 요청·화면 계약](../../_workspace/menu-sketch-ui/app-media-r01/01_contract.md), [대전 반영](../../_workspace/menu-sketch-ui/app-media-r01/02_match.md), [생활 반영](../../_workspace/menu-sketch-ui/app-media-r01/02_life.md), [검증과 남은 항목](../../_workspace/menu-sketch-ui/app-media-r01/04_closeout.md)을 참고한다.
