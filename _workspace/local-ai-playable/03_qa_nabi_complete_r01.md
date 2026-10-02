# 나비 전체 모션 등록 QA r01

- 기존 약공격 1·2단 해시는 유지하고 신규 상태 10종·공격 14종만 추가했다.
- 자동 커버리지는 공격 16/16·상태 13/13이다.
- 신규 runtime은 16개 128×128 RGBA 셀, 2048×128 시트, 비루프 SpriteFrames다.
- 전체 접촉 시트에서 흰 귀 두 개, 긴 흰 꼬리 한 개, 보라 발톱과 발 잘림이 없는지
  확인했다.
- 회색 RGB와 투명 RGBA 입력을 구분해 배경 RGB 잔여값이 runtime에 들어가지 않게 했다.
- `CHARACTER_MOTION_CONTRACT`: 통과.
- `CHARACTER_ATTACK_MOTION_CONTRACT`: 통과.
- `LOCAL_FIGHTER_PRESENTATION`: 통과.
- `verify-docs`: 통과.
- Godot 리소스 검사: 논리 자산 345개, 오류 없음.
- 승인 모션 등록 도구 재실행: 신규 등록 0개로 중복 방지를 확인했다.
- `./scripts/verify.sh`: 통과. 전투 결정론 해시는
  `9ca3d9a3c4fc36f82dba273397f4c115027621ea87d7ca44973c2fc94495fdb8`로 유지됐다.
- 네 캐릭터 전체 상대 조합 장시간 AI 경기, 장신구 실제 적용, 앱 흐름과 터치 입력
  회귀가 통과했다.
- Android debug APK 생성과 패키지 계약 검사가 통과했다.
- Android 15 arm64 에뮬레이터에서 APK 설치, 보유 캐릭터 선택, 대전 진입, 이동·점프
  터치, 홈 중단·복귀, 계속하기, 일시정지, 대전 종료와 로비 복귀가 통과했다.
- 실제 Android 기기 재생·성능은 사용자 지시에 따라 나중으로 미루며 미확인이다.
