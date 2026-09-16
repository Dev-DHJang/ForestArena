# batch-01 생성 프롬프트 기록

- 도구: 내장 이미지 생성 도구.
- 참조: 승인된 `myo-ryung-concept-v01`과 `attack_light_combo_01~04` RGBA 검토 시트.
- 공통 기준: 우향 전신 4×4·16포즈, 은백색 머리, 긴 흰 토끼 귀 2개, 인간형 손발, 분홍·흰 운동복, 큰 하이탑 운동화와 장미색 리본 유지. 상대·무기·문자·워터마크·판정/VFX 금지.

| visual state | 생성 핵심 문구 | 중간본 SHA-256 |
| --- | --- | --- |
| `attack_light_up` | 낮은 가드 → 빠른 상승 킥 → 짧은 착지 회복 | `e724e197757d6cf6742fcd8fee823b63276080480376fff665a2d1831ef58cdc` |
| `attack_light_down` | 중심 하강 → 앞발 토 킥 → 빠른 회수 | `80a242e2dbcbd872455a8e01ee2a2fd1275266598eee7c0cb007f37a23178bed` |
| `attack_heavy_side` | 지지발·몸통 회전 → 큰 수평 사이드 킥 → 무거운 회복 | `11c7656d47a143897178f84f09aae47c688ae7e213c45e3bc9e01618756f999f` |
| `attack_heavy_up` | 깊은 웅크림 → 수직 도약 런처 킥 → 착지 회복 | `7ac8ea411b85c5dbf27b02202594f51dc4708985220751c86c4e5bb4c0bba8bb` |
| `attack_heavy_down` | 낮은 축 → 넓은 회전 로 킥 → 지상 복귀 | `45c151a49e780be3ae5414dcb199771fe9071fb1060b3a503d8f6334bd68d4e2` |

## 현재 처리 상태

- 다섯 시각 시안은 `raw_checker/`에 원본 그대로 보존했다.
- 원본은 RGB이며 체크무늬가 실제 픽셀로 포함되어 있어 각 파일을 정확한 단일 편집 대상으로 지정한 `background-extraction` 요청으로 true alpha를 만들었다.
- 차단 해제 뒤 내장 이미지 생성 도구로 처리했으며 임의의 로컬 색상 키 제거나 다른 모델 전환은 수행하지 않았다.

Clean SHA-256:

- `attack_light_up-r01-clean.png` — `d6eacc7a473296c93488acc58100bac0c13a93ba9b4681a735566d021d17c3a6`
- `attack_light_down-r01-clean.png` — `d7cfbf307cdc5399ddf4f900c9ced8ca49fc5e44985d24e3b836f9f2e4338670`
- `attack_heavy_side-r01-clean.png` — `efaee5fc477162e25a894f2aacda63d4f26a35623fc9b0685f2b47249faeec71`
- `attack_heavy_up-r01-clean.png` — `07d2f6ff64220e5e90d32c6dfb000d22dc8dc1a018ec83642ced58af70e05859`
- `attack_heavy_down-r01-clean.png` — `34e1f0230882ccaa225cb63084562e6ec0918f30ae267da27f8df0d1985e3276`
