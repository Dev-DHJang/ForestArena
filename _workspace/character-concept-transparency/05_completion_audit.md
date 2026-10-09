# 전체 작업 완료 조건 확인

## 콘셉트 추가 요청

| 요구 | 증거 | 현재 판정 |
| --- | --- | --- |
| 네 캐릭터 배경 없는 실제 PNG | 1086×1448 RGBA, alpha 0~255·투명 모서리·25% 이상 실제 투명 픽셀, `install_concept_transparency.py` | 통과 |
| 디자인·원본 색상 보존 | 원본과 결과의 RGB 전체 배열 동일, 밝기 6 초과 전경 전부 alpha 255, 흰색/어두운 검토판 직접 확인 | 통과 |
| 묘령 기존 투명 PNG 보존 | 원본·결과 SHA-256 동일 | 통과 |
| 사용자 승인·원본·출력 연결 | `approval.json`의 보고서 해시, 원본 백업·출력 해시, `installation.json`, 등록 검사 | 통과 |
| ID·사용 경로·외형 계약·전투·승인 모션 불변 | manifest 변경을 콘셉트 3항목의 해시·날짜·추가 이력으로 제한, 다른 항목 동일. CharacterData 연결 검사·119종 모션 설치 검사 | 통과 |
| 원본 백업·되돌리기 | `03_backup`의 PNG 3개·manifest, 검증된 원본 해시, PR revert 절차 | 통과 |
| 자동 검사·Godot 연결·문서·하네스 | 단위 검사 3개, 최신 develop 전체 `verify.sh` exit 0·마지막 완료 문구 | 통과 |
| 관련 변경만 원격 PR·검토·develop 병합 | PR #79, c909daa, 원격 검토 진행 중 | 미완료 |
| Android 검증 | 사용자 명시 결정으로 이후 수행 | 이연; 통과 아님 |

## 선행 모션 요청

`_workspace/character-motion-visual-unification/07_completion_audit.md`의 120종 전체·119종 승인 교체·기준 시트 유지·실제 점프 단계·표시와 전투 분리 조건을 유지한다. 이 추가 작업에서 모션 PNG·SpriteFrames·판정 데이터는 변경하지 않았다. 최신 콘셉트 설치 뒤에도 119종 승인 해시·FPS·루프·발 기준점·SpriteFrames 검사 통과. PR #76은 develop에 병합됐다(60777dd02e192d0db8c56f44c8d7d877b267672d).

PR #79 병합 확인 전에는 전체 Goal을 완료로 바꾸지 않는다. Phase 6 제품 전체 완료나 Android 실기기 통과를 주장하지 않는다.
