# 마무리 기록

## 현재 결과

코드와 자동 검증 기준으로 macOS 한 경기 서버와 Android 두 클라이언트의 LAN 1대1 흐름을
완성했다. 네 캐릭터·무료 장신구 6종, 코드 복사·붙여넣기, 서버 판정, 재접속, 결과·재대전,
Forestlight 터치 조작과 확장 숲 지형이 연결됐다. Story는 보상·성장 없는 프롤로그로 표시한다.

Android debug APK는
`/Users/jdh/Desktop/workspace/ForestTales/build/android/ForestArena-LAN-debug.apk`에 복사했다.

## 다음 계획으로 옮긴 검사

물리 Android 두 대의 실제 사용자 LAN 플레이는 2026-10-08 사용자 결정으로 다음 계획에
반영한다. 이번 작업에서는 Android 에뮬레이터가 macOS의 실제 사설 Wi-Fi 주소로 접속해 방을
만들고, 두 번째 Godot 클라이언트와 두 경기·결과·재대전·방 종료까지 완료했다.

원격 `origin` push·PR·`develop` 병합은 GitHub 인증과 원격 대상의 명시적 승인 확인이 없어
수행하지 않았다. 로컬 전용 브랜치 커밋은 안전하게 보존돼 있다.

## 되돌리기

- LAN만 제거할 때는 `server/game/lan_*`, `scripts/network/lan_*`, `scripts/lan-host.sh`,
  LocalAiApp의 LAN 화면과 ADR-028 소비자를 함께 되돌린다.
- 지형만 되돌릴 때는 `StageData` v2, 숲 경기장 Resource, `ArenaVisual`, 품질별 지형 PNG와
  제작·검사 스크립트를 같은 변경으로 되돌린다.
- Android `INTERNET` 권한은 LAN 클라이언트를 제거할 때만 함께 끈다.
