# 나비 약공격 1단 r04 검토

## 사용자 승인

- 2026-09-26 사용자 응답: `신규 모션을 승인한다.`
- 직전 검토 요청으로 제시한 나비 약공격 1단 r04의 동작·외형 승인을 확정한다. 아직 제시하지 않은 다른 모션에 대한 포괄 승인으로 확대하지 않는다.
- 모션 디자인 승인과 런타임 파일 품질 검사는 별개다. 투명 배경·16프레임 규격 검사를 통과한 뒤 등록한다.

- 내장 imagegen으로 r03의 가장자리 잡픽셀을 정리한 검토 시트다. 불투명 회색 배경이며 런타임 자산이 아니다.
- 시트와 preview.html을 통해 준비·잽·회수의 16개 프레임을 검토한다. 실제 공격 tick 연결과 투명 런타임 패키지 등록은 사용자 모션 승인 뒤 별도로 처리한다.
- 외형: 흰 귀와 흰 꼬리 1개, 흰 머리, 검정·보라 의상과 인간형 팔다리를 유지했다. 기본 셀에서 완전히 잘리는 신체 부위는 보이지 않는다. 자연스러운 연속성은 재생 검토 대상이다.
- 원본: imagegen exec-f515d443-90f5-4471-8c5e-24539bfee577.png. 입력 r03, 사용자 승인된 나비 콘셉트의 파생 시안. 외부 라이선스 확인을 주장하지 않는다.

## 프롬프트

Edit this animation review sprite sheet only to repair its background and edges. Preserve exactly every character drawing, white cat ears, white tail, purple outfit, exact 16 positions and 4 by 4 grid, motion progression and scale. Remove ALL scattered purple magenta blue white debris and white edge halos around the characters. Output clean antialiased silhouettes on a UNIFORM OPAQUE medium-dark gray background #34383f, no transparency for this review copy. No added outlines, shadows, labels, effects, borders. All 16 full bodies including tails and extended hands must remain intact inside each grid cell. Do not change character identity or poses. This is a review contact sheet and exact pose consistency is more important than redesign.
