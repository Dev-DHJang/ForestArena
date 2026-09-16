# 문서 구조 이동 기록

## 이동 원칙

- 설명 문서는 목적별 폴더에 둔다.
- 프로그램이 읽고 검사하는 JSON은 `docs/contracts/`에 모은다.
- `docs/` 최상위에는 시작점인 `INDEX.md`와 `GLOSSARY.md`만 둔다.
- 이전 경로에 복제본을 남기지 않고 색인에 이동표를 둔다.

## 함께 갱신한 사용자

- README와 AGENTS의 문서 경로
- `.agents/skills/`의 필수 입력 경로
- 캐릭터 콘셉트 문서의 외형 데이터 경로
- Godot 테스트의 공격·외형 JSON 경로
- 하네스 검사 스크립트의 필수 파일과 검색 범위
- 문서 안의 Markdown 상대 링크

## 자동 보호

`scripts/verify-docs.sh`가 다음을 검사한다.

- 필수 문서와 7개 목적별 폴더
- `docs/` 최상위 파일 제한
- 활성 파일에 남은 이전 경로
- AGENTS와 AI 개발 절차의 쉬운 문장·색인 갱신 규칙
- README, AGENTS와 모든 Markdown의 상대 링크

이 검사는 `verify-harness.sh`에 연결되어 기본 전체 검사에서도 실행된다.
