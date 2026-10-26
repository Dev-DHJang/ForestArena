# 승인 25종의 최종 통합 검토 r01

담당 `final_integration_review`. 2026-10-27. 판정은 **PASS — 승인된 25종의 등록 변경과 기존 검토 자료의 연결 범위**다. 새 영상 촬영이나 기존 전체 검사를 반복하지 않고 현재 변경 파일과 기존 독립 검토의 적용 범위를 확인했다. PR 병합 실행과 중단된 전체 검사의 잔여 완료는 조율 역할의 별도 마무리다.

## 현재 변경과 승인 연결

직접 사용자 메시지 “승인한다.”를 기록한 `remaining-user-motion-registration-approval-r10.json`은 자현12·나비13의 개별 PNG·후보 TRES·등록 TRES와 고정 계획을 가리킨다. 현재 PNG·TRES 50개를 원 계획의 출력 SHA와 다시 읽어 대조했고 불일치는 0개다. manifest SHA는 `0af4d840475beb3d85f7d3844e1a923d80437c3d1b561a0d12c30a27fd86a155`로, 독립 실제 로딩 결과의 대상과 같다.

HEAD와 현재 manifest를 구조로 대조하면 asset ID 130개가 동일하고 변경된 항목은 정확히25개다. 그25개의 소비 경로도 유지됐다. 기존 다른105개는 동일하다. 현재 미커밋 변경 중 `scripts`·`forest_arena`·`server`·`scenes`·`assets/combat`·`assets/loadouts`의 변경은 없다. 등록 과정에서 전투·LAN·저장·공개 표현 코드를 다시 바꾸지 않았다. 새 PNG import 설정25개도 준비돼 있다. 자동 생성된 프리미엄 메뉴 runtime-report는 이번 변경에 포함할 필요가 없다.

원 설치 이후 자현 launch의 과거 단계 `status` 하나를 제거한 사실은 `03_qa_registration_r01.md`와 `metadata-cleanup-proof.json`에 분리돼 있다. 현재 manifest를 원 설치 receipt의 최초 manifest와 같은 바이트라고 주장하지 않는다. 그림·표시 설정·승인·다른 항목은 이 정리로 바뀌지 않았다.

## 기존 독립 검토와 실제 등록 결과

다음 결과의 범위를 구분해 읽었다.

- `03_qa_remaining_final_r04.md`: 자현12·나비 상태9의 전체 원화336장, 실제 게임22장면3580프레임, 정상·반전 및 정상/느린 재생 검토.
- `../nabi-claw-vfx-v2/03_qa_visual_r02.md`: 나비 공격4종 원화80장, 실제 입력8장면960프레임, 양 방향과 정상/느린 재생 검토. 실제 특수기에서 선택한 그림24장과 원화32장 전수 검토를 구분한다.
- `qa/remaining-candidate-review-r10-final/motion-review.json`과 `qa/final-review-independent-r01/`: 두 독립 결과의 정확한25종 통합과 읽기 전용 등록 계획 검토.
- `03_qa_lan_visual_r01.md`: 실제 서버와 양 클라이언트에서 자현·나비 정상/반전의 후반 연결,306 PNG와 실제 표시 시각에 맞춘 재생 검토. 앱 HUD·Android 통과로 확대하지 않는다.
- `03_qa_registration_r01.md`와 `qa/approved-registration-independent-r01/runtime-load-proof-cleaned.json`: 후보 덮어쓰기 없이 공개 presentation이 실제 등록 TRES·metadata를 선택함을2256검사로 확인했고, 실제 import된416프레임 전체 RGBA 및 순서·region·margin·duration·FPS·loop·유효 anchor·공격 phase·후반 연결 설정이 검토한 후보와 같다.

이 연결로 승인 전 의미·자연스러움 시각 검토와 승인 후 실제 등록의 동일성이 모두 확인된다. 단순 파일명·메타데이터만으로 최초 시각 통과를 대신한 경우가 아니다. 따라서 동일한 공개 코드·그림·표시 설정을 다시4540프레임 GPU 촬영하는 작업은 이번 등록의 필수 검사가 아니다. 후보 시각 QA에서 확정한 그림을 등록하면서 새로운 안무나 효과를 변경하지 않았기 때문이다. 실제 등록 로딩 검사가 대체하는 범위는 등록의 정확성이며, 과거 게임 영상의 날짜나 환경을 새 실행 결과로 바꾸지 않는다.

## 남은 통합 마무리

새 필수 제품 결함이나 모션 재승인을 요구할 변경은 찾지 못했다. 현재 전체 검사 r01 로그는 `PROFILE_CATALOG: PASS` 다음 엔진 시작에서 끝나고 종료 판정 파일이 없다. 전체 통과로 쓰지 말고 이미 완료된 부분의 소스 동일성을 확인한 뒤 미완료 부분만 이어서 실행해 결과를 남기면 된다. 문서·리소스 검사, 관련 파일만 commit/push, PR109의 최종 변경 설명·원격 검사·병합 결과는 조율 역할이 마무리한다. 실제 Android 엄지 접근성·가독성·중단/복귀는 사용자 계획대로 별도 수동 재검사이며 이번 pass에 포함하지 않는다.
