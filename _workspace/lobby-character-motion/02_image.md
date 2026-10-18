# 투명 PNG와 미세 움직임 제작

승인 원본 assets/character/ja-hyun/concept/ja-hyun-concept-v01.png는 RGB·1086×1448이며 검은 배경을 포함한다. imagegen 편집 도구로 배경 제거 파생본 assets/ja-hyun-lobby-transparent-v01.png를 제작했다. 승인 원본과 캐릭터 등록 파일은 보존한다. 생성 모델의 배경 제거 결과이므로 원본과 픽셀 단위 동일성을 주장하지 않는다.

필수 외형인 두 둥근 귀·은백색 머리·한 개의 얇은 꼬리·파란 리본·흰색/검정/파란 의상을 검토한다. 출력은 RGBA PNG이며 모서리 알파 0, 실제 투명·불투명 픽셀이 존재한다. 검은 옷을 배경으로 지우지 않는다. 출처는 사용자 승인 콘셉트와 imagegen 배경 제거 편집이다.

로비용 PNG 한 장을 재사용해 CSS transform으로 약한 호흡과 흔들림을 표현한다. 4초 ease-in-out 반복, 크기 1→1.006→1, 회전 -0.1°→0.1°→-0.1°, 아래 중심 고정, 작은 수직 이동이다. preview.html은 일시정지와 prefers-reduced-motion을 지원한다. 전투 모션이나 Godot 입력·판정과 연결하지 않는다.

Penpot는 원본과 비교 보드에 투명 PNG를 적용하고, 프로토타입은 두 로비 상태의 느린 dissolve 전환으로 움직임 의도를 표현한다. 연속 변형의 정확한 미리보기는 preview.html이다. PNG 자체는 정적 이미지다.
