# 최종 APK 에뮬레이터 확인

2026-10-15. 기존 AnimalFight_API_35 / emulator-5554 / Android API 35, 실제 가로 화면 2400×1080에서 검사했다. 에뮬레이터 전용 결과이며 실기기 결과는 미확인이다.

최종 [성공 기록](menu_emu_4fae78c1a0554aab/summary.json): 6항목 PASS, 기존 일반 저장 해시 보존, QA 실행 ID 분리, APK SHA-256 일치. 이 폴더의 각 PNG에는 같은 번호의 상태 JSON이 함께 있다.

- [구매 모달](menu_emu_4fae78c1a0554aab/004-EMULATOR-SMOKE-purchase-modal.png)
- [조작 설정 적용](menu_emu_4fae78c1a0554aab/006-EMULATOR-SMOKE-controls-applied.png)
- [앱 재실행 뒤 복원](menu_emu_4fae78c1a0554aab/007-EMULATOR-SMOKE-controls-restored.png)
- [조작 메뉴 뒤로 → 일시정지](menu_emu_4fae78c1a0554aab/008-EMULATOR-SMOKE-controls-back-pause.png)

첫 시도 [도구 좌표 실패 기록](menu_emu_5b99dda317ff4d80/summary.json)은 지우지 않았다. 논리 1280×720 좌표를 실제 ADB 화면에 확대하도록 도구를 수정하고 새 QA 실행으로 재검사했다.

[검사 도구](qa_emulator_smoke.py)는 물리 기기 검사 시작 함수를 호출하지 않으며 `emulator-` serial만 허용한다. 앱 데이터 초기화나 OS 설정 변경 없이 install-r와 독립 QA 시작 인자를 사용한다. 실행 명령은 프로젝트 루트에서 다음과 같다.

```sh
python3 _workspace/premium-menu-v07-runtime/emulator/qa_emulator_smoke.py --apk build/android/ForestArena-debug.apk
```

최종 APK SHA-256: `59c79c99f3f244f1c8ebe2423b021d716bbefc75d05f1be87c8419a4ab27af45`.
빌드 소스 SHA-256: `a315794980e5992d1c768dce42f640aa3b50dc6514c5420ba0c5b99536fd4bbe`.
Python 도구 단위 검사: 125개 PASS.

[이전 14f APK 기록](menu_emu_36e2b635d6564cad/summary.json)은 제품 소개 문구 수정 전 결과로 보존했다. 최종 검사 완료 후 [에뮬레이터 종료](shutdown-final-debug.log)를 확인했다.

[이전 d69b APK의 6항목 통과 기록](menu_emu_b7958e815e1f4588/summary.json)은 디버그 로그의 해제된 버튼 참조 수정 전 결과로 보존했다. 최신 59c79 APK는 같은 6개 흐름과 저장 보존을 다시 통과했다. 수집된 logcat의 SCRIPT ERROR와 `_log_button` 형식 오류는 모두 0건이다. 마지막 재검사에서 새 테스트나 제품 코드 변경은 하지 않았다.
