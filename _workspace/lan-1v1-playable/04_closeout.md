# 마무리 기록

## 현재 결과

코드와 자동 검증 기준으로 macOS 한 경기 서버와 Android 두 클라이언트의 LAN 1대1 흐름을
완성했다. 네 캐릭터·무료 장신구 6종, 코드 복사·붙여넣기, 서버 판정, 재접속, 결과·재대전,
Forestlight 터치 조작과 확장 숲 지형이 연결됐다. Story는 보상·성장 없는 프롤로그로 표시한다.

Android debug APK는
`/Users/jdh/Desktop/workspace/ForestTales/build/android/ForestArena-LAN-debug.apk`에 복사했다.

## 완료 전 남은 한 가지

실제 사용자 두 명이 물리 Android 두 대에서 같은 Wi-Fi LAN 한 판과 재대전을 끝내야 한다.
현재 ADB에 실기기가 없어 이 항목은 실패가 아니라 미확인이다. 두 기기가 연결되면
`docs/gameplay/lan-1v1-play.md` 순서로 설치·접속·플레이하고 이 문서와 QA 기록을 갱신한다.

## 되돌리기

- LAN만 제거할 때는 `server/game/lan_*`, `scripts/network/lan_*`, `scripts/lan-host.sh`,
  LocalAiApp의 LAN 화면과 ADR-028 소비자를 함께 되돌린다.
- 지형만 되돌릴 때는 `StageData` v2, 숲 경기장 Resource, `ArenaVisual`, 품질별 지형 PNG와
  제작·검사 스크립트를 같은 변경으로 되돌린다.
- Android `INTERNET` 권한은 LAN 클라이언트를 제거할 때만 함께 끈다.
