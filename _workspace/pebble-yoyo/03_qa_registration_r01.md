# 조약돌 요요 채택 자산 등록 독립 QA r01

2026-11-02 등록 검증 결과 `pass`. 사용자 답변 “수정 시안 5종 모두 채택”을 기록한 승인 문서, 표준 등록 계획·영수증과 현재 runtime을 대조했다. 추가 승인을 요청하지 않았다. 등록 전 시각 QA는 `review-r05/motion-review.json`의5개 pass이며 이 검토는 등록 후 소비 결과를 확인한다.

## 승인과 등록 연결

- 계획 SHA-256 `f7d4b5f5c011c95845b2391116a668107e4e48240190c6aa67e52d32bedba416`, 원 QA SHA-256 `9075e39a01c59cc378bce98513bb5ca467546b286fe9af34c4da68c22f2a3d08`과 카탈로그·범위·목표 파일 해시가 승인·receipt·현재 파일에서 일치한다. 표준 `verify_approval()`로5개 개별 채택과 출력 PNG/SpriteFrames 해시 연결을 확인했다.
- 다섯 runtime PNG는 채택 후보와 바이트가 동일하다. runtime SpriteFrames는 후보의 PNG 참조 경로 한 곳만 바뀌었고 등록 계획의 최종 해시와 일치한다. frame count·셀·FPS·시간·반복·배율·발 기준점·프레임별 손/몸 기준점·장비4단계 모두 후보 메타데이터와 같다. manifest의 논리 ID와 SpriteFrames 소비자 경로가 계획과 일치한다.
- 나비 idle은 기존 PNG도 현재 그대로 남고 새 버전 PNG와 바이트가 같다. 기존 논리 ID·소비자 경로·이미지·시간·배율·발 기준점이 보존되며 채택한 body_root만 보정되었다. 기존 manifest 항목은 등록 이력의 마지막에 원래 값 그대로 보존되고 이전 이력도 유지된다. 이전 idle.tres와 manifest는 백업 해시와 일치한다.
- 큰 텍스트 diff와 별개로 manifest JSON 값을 순서대로 비교했다. 원래146개 행은 기존 위치를 유지하며 나비 idle1개 외145개 행의 모든 JSON 값이 완전히 같다. 뒤에 새 요요4개만 추가되어 현재150개 행이다. 이 결과를 `registration-checks.json`에 기록했다.

등록 전 QA가 고정한88개 source 중 현재 달라진 것은 승인 설치가 수정한 manifest와 나비 idle.tres 두 개뿐이다. 두 파일은 receipt의 before 해시 및 백업에서 원 QA 해시와 정확히 연결되고, 현재 값은 receipt after 해시와 같다. 나머지86개는 현재도 원 해시가 일치한다. 따라서 등록 뒤 pending 후보 노출 검사를 다시 통과시킨 것으로 주장하지 않는다. 원 QA 기록의 의미와 바이트는 보존하고 승인 설치의 전후 연결을 검증했다.

## 실제 runtime 재생 비교

`record_preview.gd`에서 후보 ImageTexture·SpriteFrames·layout 및 나비 idle layout 주입 부분을 제거한 별도 `registration-qa-r03/record_registered_preview.gd`를 작성했다. 후보 JSON은 비교용 이름·메타데이터 표제에만 읽으며 실행 그림·표시 메타데이터에는 주입하지 않는다. 실제 로드된 runtime 장비 모션과16프레임 존재도 확인한다. 원본·파생 스크립트의 해시와 정확한 차이는 `recorder-derivation.json`/`recorder.diff`에 남겼다. 시뮬레이션·시작 좌표·27틱 진입 전/24틱 종료 후·모든 입력/표본은 승인 시안 recorder와 같다.

`workflow.py run` 잠금 아래 import 후 runtime recorder를 순차 실행했다. 좌우8개 ×99틱 =792개 frame 사전 전체가 채택한 `game-timeline-r03.json`과 **정확히 같다**. 프레임 ID·단계/단계틱·그림 위치·배율/반전·실제 캐릭터 위치·손·권위 본체/표시 본체 좌표·실제 회전각을 모두 포함한 비교다. 공중16프레임/4단계와 jump 복귀도 그대로다. 나비16개 idle ×좌우32개 진입의 before 및 각49개 cast/post 표본(총1600개)도 전부 정확히 같다. 별도 PNG/TRES 바이트 비교와 이 런타임 표시 매개변수 동일성으로, 채택한 시안의 그림과 재생이 실제 등록 소비에서 유지됨을 확인했다.

- 실제 runtime 기록: `registration-qa-r03/runtime-timeline.json`
- 읽기 전용 대조 코드/결과: `registration-qa-r03/verify_registration.py`, `registration-checks.json`
- 실행 로그: `build/verification/pebble-yoyo/registration-qa-import-r01.log`, `registration-qa-runtime-r01.log`, `registration-qa-runtime-r02.log`, `registration-qa-audit-r01.log`

첫 recorder 종료 뒤 엔진의 ObjectDB/Resource 해제 경고가 있었다. 파생 검증 스크립트의 quit만 지연 호출해 함수 지역 참조 해제를 확인한 두 번째 실행도 종료0·기록 비교 pass이며 경고가 남았다. 두 번째 원문은13개 ObjectDB와1개 Resource 종료 해제 경고다. 생산 전투·표현 코드를 이 경고 때문에 수정하지 않았고 경고 없는 실행으로 기록하지 않는다. Godot 잠금은 두 번째 실행 종료 후 해제하여 메인 전체 검사에 인계했다.

## 표시 비용과 범위

신규 요요 모션4시트의 RGBA 원시 텍스처 상한은 `4 ×16 ×128 ×128 ×4 =4,194,304 bytes =4MiB`다. 밉맵·드라이버/압축·캐시 비용은 제외한 계산이며 실제 Android 메모리 측정값이 아니다. 나비 idle은 기존 한 모션의 동일 픽셀 교체다. 이번 자산 등록은 기존 CharacterSprite 및 장비 표시 노드/그리기 명령을 재사용하며 등록 때문에 추가되는 노드나 효과 그리기 명령은 없다. 실제 Android 기기 검사는 수행하지 않았다. 전체93개 통합 검사는 이 독립 등록 QA 이후 메인 담당이며 여기서 선행 통과를 주장하지 않는다.

## 결과 식별 해시

```json
{
  "registration-qa-r03/registration-checks.json": "d043bca762ec13a38101ce55efe69308b882faca98fd44f4f44fd0554eb738e5",
  "registration-qa-r03/runtime-timeline.json": "62487e32576a42c73b36214f2fbad31d2fbc0a77aaee12610e3ffd8aff18ffc8",
  "registration-qa-r03/record_registered_preview.gd": "7c3fd068c311e5a089630583793d2b51ff6607ed280dd6dc0f5e692e02eac086",
  "registration-qa-r03/verify_registration.py": "ef3c1f792225059dbd265eb4e65c5af254dcf48d03edab60a136558e1904e38a"
}
```
