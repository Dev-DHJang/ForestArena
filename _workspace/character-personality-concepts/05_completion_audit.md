# 완료 조건 확인표

전체 완료 여부는 아래 검사와 실제 PR 병합 뒤 확정한다. 작은 범위의 검사 통과를 전체 완료로 대신하지 않는다.

| 요구사항 | 확인 자료 | 현재 결과 |
| --- | --- | --- |
| 캐릭터별 차분한 비전투 개성 이미지 한 장 | `05_normalized/`, `06_review/`, `03_qa_r04.md` | 독립 시각 QA pass |
| 성인·3등신·기존 신체/종 특징/의상/색상 유지, 새 소품 없음 | 독립 비교 관찰 및 외형 JSON profiles 비변경 | pass |
| 1024×1536 실제 투명 RGBA와 전신·48px 여백 | 구조 검사, `06_review/report.json`, Godot PNG 가져오기 검사 | pass |
| 사용자 네 장 최종 채택, 정확한 해시 연결 | `approval.json`, 불변 후보 보고서 | 승인 확인 |
| 추가 variant 등록, 대표 네 장과 CharacterData·전투·모션·UI 유지 | 설치 검사, 기존 manifest 비교, 기존 파일 2115개 해시 | pass |
| 비전투 자세만 제한 예외, 스키마와 기존 외형 규칙 유지 | JSON diff, 등록 테스트와 기존 외형 검사 | pass |
| 출처·프롬프트·수정·권리 근거·사용 경로 | manifest, `02_image.md`, 개별 디자인 기록 | 기록 완료, 외부 권리 검증 주장 없음 |
| 기존 manifest 보존 도구의 정확한 추가 항목 지원 | helper 검토, 잘못된 승인/해시/부분·전체 누락/중복 테스트 | pass |
| 구조·정리·등록 자동 검사 | 6+6+10개 테스트, `verify.sh` 연결 | 22개 pass |
| 문서·하네스·Godot 리소스 전체 검사 | 명령 실제 출력 | pass (별도 develop 작업 공간: 논리 자산 519개) |
| 전체 `./scripts/verify.sh` | `verify-full.log`, 종료 코드 0 및 마지막 통과 문구 | pass, 종료 시 리소스 잔류 경고는 마무리 기록에 명시 |
| 다른 작업트리 변경 보존·관련 변경만 통합 | 별도 develop 작업 공간, 원 작업트리 250개 기존 소스 비변경 | 관련 변경만 선별 예정 |
| 최신 develop 기반 commit·push·PR·QA·병합 | `04_closeout.md`의 PR·SHA | 대기 |
| 선행 문서 재구성 통합 | 시작 develop `95e1fe4437de0d046baa12fd0660bcad42aee891`의 선행 병합 이력 | 반영됨 |
| Android export·에뮬레이터·물리 기기 | `00_request.md`의 사용자 이연 | 명시 이연, 실행/통과 주장 없음 |
