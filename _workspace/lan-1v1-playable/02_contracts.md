# 공용 계약 적용

- `LanInvite` protocol 1은 사설 IPv4의 host·invite 한 줄 코드만 받는다.
- LAN 메시지는 모두 protocol version 1을 요구하며 서버가 로드아웃·입력 순서·방 정원을 검증한다.
- `StageData`는 v2로 올리고 `terrain_asset_id`를 필수로 했다. 저장소의 숲 경기장 데이터를
  v2로 옮겼으며 구버전은 기본값으로 추정하지 않는다.
- Android LAN에는 `INTERNET` 권한만 사용한다. 카메라·마이크·위치 권한은 추가하지 않는다.

검사: `tests/lan_contract.gd`, `tests/lan_runtime_verifier.gd`,
`tests/combat_feel_stage_v2.gd`, `tools/forest_arena/verify_forest_ledge_art.py`.
