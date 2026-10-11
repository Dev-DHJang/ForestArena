# Android 실기기 자동 플레이 마무리 기록

## 구현과 검증

- 명시적 실기기 1~4대 선택, 오프라인 병렬, LAN 두 쌍 분리, smoke/10분 soak/30분 extended 도구를 구현했다.
- debug 검사 저장·실행 인자 전달·명령/관측 형식·실제 터치·기존 AI 전투·입력 초기화·APK 동일성·기기/성능/단절 증거를 구현했다.
- 사용 방법과 12개 케이스는 `docs/engineering/godot/android-device-autoplay.md`, 독립 품질 기록은 `03_qa_r01.md`에 있다.
- 실행 도구 48개, Android 인자 전달 8개 자동 검사 pass. Godot 저장/입력 검사와 LAN 두 서버 분리 검사 pass.
- `verify.sh`, `verify-docs.sh`, `verify-lan-runtime.sh`, Godot 논리 리소스 397개/품질 변형 24개, Android APK 패키지 검사 pass. 기존 검사 종료의 리소스 정리 경고는 남아 있으며 새 GDScript 오류는 없다.

## 실제 기기와 미확인

- SM-S918N(Android 16)·SM-T725N(Android 11)의 두 실기기만 확인했다. ADB 연결 경로 수와 실제 기기 수를 구분했다.
- r04는 Godot 인자 제거로 fail. 기존 저장 해시 변화도 보존했고 일반 저장을 자동 되돌리지 않았다. debug 인자 전달 어댑터와 APK 사전 표시 확인으로 보완했다.
- r08은 두 기기 DEV-01 pass, 상점 이동 실패/ADB 단절로 후속 검사 미완료다. 종료 저장 해시를 읽지 못한 값을 삭제로 오판한 경로를 blocked로 고쳤다. 기존 r08 결과 원본은 보존하며 해당 저장 손실을 결론 내리지 않는다.
- r09는 수정한 도구의 두 기기 기본 10분 soak 시도로 진행 중이다. 실행 ID `6292d46fea344eaaa24e60f48b372c81`; 결과는 `build/android-fleet/`의 실행별 폴더에 보존한다.
- 네 실기기 동시 실행, 30분/28개 조합, 실제 Wi-Fi 끄기/켜기·동시 터치·소리·진동은 미실행이다. 성능 합격 수치도 미승인이다.
- 테스트 API/프로토콜 연결의 자동 검사는 실제 제품 API/DB 또는 실제 네 실기기 통과를 뜻하지 않는다.

## 통합과 되돌리기

- 기준 develop: cf081dd334ef619450d612844f6206f560ea2cc0. 작업 브랜치: codex/android-device-autoplay.
- 원래 feature/combat-feel-stage-v2 작업 트리와 승인 자산은 보존했다.
- PR·병합 상태: 검증 결과를 확정한 뒤 기록한다.
- 문제가 있으면 이 작업의 통합 커밋을 revert한다. 기기 QA 저장과 호스트 결과는 실행 ID별로 보존하며 일반 프로필을 삭제하지 않는다.
