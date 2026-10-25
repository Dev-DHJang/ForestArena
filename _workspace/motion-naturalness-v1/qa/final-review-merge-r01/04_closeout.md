# 병합 완료, 독립 정합성 확인 중

독립21종과4종을 새 `remaining-candidate-review-r10-final`에 합쳤다. 기존 기록과 후보 목록은 보존했다. root는 새로운 시각 판정을 만들지 않았고, 정확한4행의 PNG/TRES 해시와 양쪽 판정 필드가 같을 때만 옮겼다. 승인 상태는 pending으로 유지한다. 전체 require-pass 확인과 읽기 전용 등록 계획, 별도 독립 병합 확인을 진행한다. 실제 runtime·manifest 설치와 사용자 승인 기록 작성은 하지 않는다.

최종25종 require-pass는 `validate-r01.log`에서 pass25/기록 무결성 PASS다. 읽기 전용 등록 계획은 `_workspace/motion-naturalness-v1/remaining-registration-plan-r10.json`에 생성했고 `plan.motions`는25개, `writes`는false, 사용자 명시 승인 기록은 아직 없다는 상태다. 계획 SHA는 `e66bfcf150d8b8c9aa1c174709aa5f4322ba6caffde351321566079d8c6baa88`이다. 원래 manifest SHA `2503ccf0b0b32c3626c047818559d213b1184d1e8017076e4c9968cc0800674c`는 유지됐다. 별도 독립 정합성 검토는 176검사를 통과했고 원래21개·나비4개 관찰의 정확한 이식과 모든 자료 불변을 확인했다. 실제 승인과 install은 실행하지 않았다.
