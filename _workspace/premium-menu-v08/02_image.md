# 메뉴 v08 이미지 기록

2026-10-20. 새 메뉴 구성에서 v07의 숲 공간 배경6개·승인 원화4개·자체 벡터 아이콘16개를 재사용했다. 새 캐릭터·배경을 생성하거나 기존 원본을 덮어쓰지 않았다. 승인된 큰 원화와 배경을 더 크게 활용하고 패널·여백·타이포그래피를 재설계하는 요청이다.

출처·원본 SHA-256은 assets/ui/premium-menu-v08/manifest.json에 총26개로 기록했다. 생성 배경과 벡터 아이콘의 기존 제작 기록은 assets/ui/premium-menu-v07/manifest.json 및 ../premium-menu-v07/02_image.md에서 이어 추적한다. 승인 원화는 v07 전달 당시의 approved-source 파일을 그대로 사용한다.

image-mapping.csv는 모든263개 화면의 이미지·아이콘 사용 위치와 정확한 출처를 연결한다. IMG/*와 DESIGN/* 별칭은 설계용이며 새 Godot 논리 ID를 등록하지 않는다. 실제 Penpot에서는 기존 media ID를 재사용하고 글자는 편집 가능한 텍스트로 분리한다.

`runtime_registration_changed_by_v08=false`는 이번 작업에서 등록을 바꾸지 않았다는 뜻이며, `existing_runtime_ids`는 같은 파일 이름과 실제 파일 SHA-256이 모두 일치하는 기존 Godot 논리 ID 목록이다. 기존 등록 자체가 없다는 뜻과 구분한다.

메뉴 전용 새 래스터 자산은0개다. 앱 아이콘 v02는 별도 ../myoryung-app-branding-v02/02_image.md와 assets/branding/myo-ryung-v02/manifest.json에 기록한다.
