# 실제 표시 코드 연결

2026-10-25 독립 시안의 좌표 기반 표시를 공통 코드에 연결했다. 새 나비 PNG·SpriteFrames·manifest는 등록하지 않았다. 현재 승인된 나비 모션에는 이 좌표가 없어 기존 표시 경로를 사용한다. 새 원화4종은 `render-production.gd`가 해당 프로세스 안에서만 연결하며, 효과는 실제 제품 스크립트를 그대로 쓴다.

`qa/production-normal-r01/`와 `qa/production-mirror-small-r01/`는 같은 소스·후보r07에서 실제 입력·고정60틱·각4장면480프레임을 촬영했다. 각각2,921검사와 로그의 그리기 오류 없음을 확인했다. 모든 RGBA를 무손실 MKV에서 복원해 비교한 뒤 중복 raw만 지웠다. 원시 영상 해시와 프레임별 대조값은 `raw-archive.json`에 남았다.

`qa/production-draft-equivalence-r01.json`은 시안r04와 실제 코드의 전체960프레임 RGBA·전투 상태·공통 표시 필드가 같음을 확인한다. 시안 보고서만 `trail_count` 진단값을 기록하므로 원시 보고서 전체가 같다고 주장하지 않는다. 자현 승인 특수기 정상·반전소형240프레임과 전체 상태도 이전 설치 영상과 정확히 같다(`../ja-scarf-barrage-v1/qa/claw-consumer-equivalence-r01.json`).

자동 검사와 이 픽셀 비교는 모션의 미술 품질이나 사용자 승인을 대신하지 않는다. 독립 코드·시각 QA를 분리해 진행한다. 실제 Android 기기는 미연결이며 기기 통과는 기록하지 않는다.

초기 `qa/consumer-r01.log`는 테스트 준비 코드의 CharacterData/default 애니메이션 오류가 있어 PASS 문구를 통과 근거로 쓰지 않는다. 수정 뒤 `consumer-r05.log`와 실제 제품 코드의 `production-consumer-r01.log`에서 오류 없이 다시 검사했다.
