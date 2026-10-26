# 나비 공격 원화 부착점 전달

제작 역할 `nabi_anchor_finish`가 기존 부분 자료를 이어받아 원화 80프레임의 좌표 표시판 20장과 발톱 확대판 4장을 직접 확인했다. 원화 PNG·후보 아틀라스·카탈로그·게임 코드는 수정하지 않았다. 기존 `head-unit-proposals.json`도 별개로 보존했다.

| 모션 | 원화 | 전체 프레임 | tip이 보이는 모션 프레임(0부터) |
| --- | --- | ---: | --- |
| attack_heavy_up | attack_heavy_up-r02.png | 16 | 7, 8 |
| attack_air_heavy | attack_air_heavy-r02.png | 16 | 4–7 |
| attack_air_light | attack_air_light-r01.png | 16 | 4–7 |
| special_side | special_side-partA/B-r02.png | 32 | 21–23 |

손 기준점 `claw_hand` 80개, 실제 구별 가능한 발톱 끝 `claw_tip` 13개를 남겼다. 나머지 67개는 접히거나 손가락과 겹쳐 같은 끝을 확정할 수 없으므로 `omitted_anchors.claw_tip`에 이유를 기록했다. 특수기 F20은 손을 당긴 자세로 발톱 끝이 확인되지 않는다.

## 좌표와 사용 방법

- 각 `*.anchors.json`의 `frames`를 해당 원화 순서에 맞춰 사용한다. special B의 `frame_index`는 0–15, `motion_frame_index`는 16–31이다.
- 좌표는 원시 PNG의 4×4 격자 셀 왼쪽 위 기준 픽셀이다. `source_absolute = cell.origin + anchor`이며 128px 셀 좌표가 아니다. 원화 밖으로 추정한 끝은 추가하지 않았다.
- 원화를 잘라 크기·위치를 맞추는 단계에서 원화와 같은 변환을 적용해 128px 표시 좌표로 바꿔야 한다. 그 뒤 게임의 facing/flip_h 반전을 한 번 적용한다. 이미 반전한 좌표로 저장하지 않는다.
- `claw_hand`는 공격 팔에 연결된 장갑 손바닥·주먹 중심 근처다. heavy 두 모션은 먼 X 소매 팔이며, 가까운 흰 줄 소매 팔은 가드에 남는다. air_light와 special은 가까운 흰 줄 소매 팔이다.
- `claw_tip`은 펼친 발톱 부채의 가운데 긴 보라색 발톱으로 읽히는 실제 끝이다. 원화만으로 해부학적 중지라고 확정하지 않는다. tip 누락 프레임에서 손으로 임의의 발톱 끝을 만들거나 뒤 프레임 좌표를 그대로 붙이지 않는다.

## 확인 범위와 한계

손 표시가 해당 소매 끝의 실제 손에 연결되는지, 위로 올리는 두 강공격과 앞으로 뻗는 약공격·특수 타격의 구별, 보이는 발톱 끝과 표시 위치를 원화 확대판에서 확인했다. 기존 좌표는 수동 판독 오차 약 ±5px 안에서 실제 손/끝을 가리켜 수치를 임의로 바꾸지 않았다. 설명에서 해부학적 중지라고 단정하던 부분은 그림에서 증명 가능한 표현으로 고쳤다.

스크립트 확인은 5개 PNG 해시 일치, 80프레임 순서·필수 손 좌표, tip 또는 생략 사유의 배타성, 총 93개 점과 가시 픽셀까지 최대 거리 4px 이하를 검사했다. 픽셀 근접 검사만으로 손의 해부학적 정확성이나 모션의 행위·완성도를 증명하지 않는다. 실제 효과 연결·정상 속도·작은 화면·좌우 반전의 독립 QA와 모션별 사용자 승인은 남아 있다. Android 기기 검사는 실행하지 않았다.

재생성: `python3 _workspace/motion-naturalness-v1/remaining/nabi/write-source-anchors.py`, 이어서 `python3 _workspace/motion-naturalness-v1/remaining/nabi/mark-source-anchors.py`. 원화 변경 시 해시가 달라지므로 이 전달의 시각 검토를 재사용하지 않는다.

## 파일 확인값

| 원화 | SHA-256 | sidecar SHA-256 |
| --- | --- | --- |
| attack_air_heavy-r02.png | `16e98a8be5af4ec0ae025184e1e4ead2717a65747f1e9a72ecd6dc7f4327d498` | `70e95773e4dd8428b943102ff6fe97870f2dfcdfd3a09a7535bbeb901fe98ac8` |
| attack_air_light-r01.png | `cca665f674d9ece4179f1d67aacc6faed76d883d26147104aaf4674982ff36f5` | `d119199ad9a4332f1f729cc1c7832cb4647ca02ff8d3f2d752d19ee6f90f71d7` |
| attack_heavy_up-r02.png | `2146d529701ebca989d2d9438ea17985ec78b882ecd000715c3868cf34ede034` | `a73f5f50a6ff7aa0bf68be5ea91b67ec052892cf6ff242312d1affa17c7ed819` |
| special_side-partA-r02.png | `864706d7c5fcc93b283c7aa6cf4e6b7963d65d6ab0ae71b0c4e4a6395d8fdba8` | `24aea7f297c66a43ec6ac7babcdc69d3d47d8fe2634e38aeb269e24d3fc4e920` |
| special_side-partB-r02.png | `3555b9512d55f93e4ef0656de29fb0522b6267506a08952715cf0541fbc64222` | `59d0afd7e6d5e98b2188cbb3ee5958af2746e7aac2fe0b3d8817738cd1b61442` |

기계 확인 기록: `anchor-diagnostics/source-anchor-verification-r02.json`. 점 표시 기록: `anchor-diagnostics/anchor-location-check.json`. 원화 전체·표시판·확대판은 같은 `anchor-diagnostics/`에 보존했다.
