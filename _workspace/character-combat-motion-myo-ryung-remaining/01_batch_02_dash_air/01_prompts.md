# batch-02 생성 프롬프트 기록

- 도구: 내장 이미지 생성 도구. 모션별 4×4 시트를 따로 만든 뒤 각 원본을 단일 편집 대상으로 지정해 체크무늬 배경만 true alpha로 바꿨다.
- 참조: 승인된 `myo-ryung-concept-v01`, 기본 약공격 04, batch-01 승인 시안.
- 공통 기준: 우향 전신 16포즈, 은백색 머리, 긴 흰 토끼 귀 2개, 인간형 손발, 분홍·흰 운동복, 큰 운동화와 장미색 리본 유지. 상대·무기·문자·워터마크·판정/VFX 금지.

| visual state | 생성 핵심 문구 | RGB 중간본 SHA-256 | Clean SHA-256 |
| --- | --- | --- | --- |
| `attack_dash_light` | 짧은 대시 → 슬라이딩 프런트 킥 → 제동·가드 복귀 | `46804d4d809ccc10c2f5b58fd6a71f4b98bb6f66bfe7d76d804f2a987a2dd9e7` | `43316e46ce54187c73be098a1043f3bdfc68f87a8a746c82706dd7a3548fe621` |
| `attack_dash_heavy` | 큰 전진 체중 이동 → 도약 사이드 킥 → 긴 착지 회복 | `edabe9629b933bf2f2884214be9ecd1a3e9a6e1141ad619e8b2816028975d678` | `524bab5cc1b288ade40a83431bbee7bf4ac6ba5b1e878506482dfb5ddbc03f04` |
| `attack_air_light` | 몸을 작게 접음 → 빠른 공중 스냅 킥 → 공중 가드 회복 | `e08653a4c27b4c3e4a19621412026e8c33b2ac39b6074c304ddb292e6819c24d` | `ef61c989332025678d279d8e8179ff807fe74e0b44d6b3e17415b84b84326c7d` |
| `attack_air_heavy` | 회전 축적 → 전하방 큰 킥 → 회전 후 낙하 회복 | `c7e8eb8f110224092bf128ae7397f31251b768fd832b2ef56ffd37cf99fc9d2d` | `8cf977bd8e3e940dd0b6af79f6cc105399ecf978bb24fcd8682202d2c9138f64` |
