# 모션 참조 데이터

## 범위와 승인 경계

외형 계약은 변경하지 않는다. 아래 자료는 제작용이며 게임 판정·상태·저장·통신 API를 추가하지 않는다. 새 시안은 `_workspace`에만 둔다. 각 캐릭터 세트의 독립 QA pass와 사용자 명시 승인이 모두 있을 때 등록한다.

## 세트 형식

캐릭터별 `reference.json`의 schema_version은 1, character_id는 기존 ID, reference_version은 v01이다. status는 draft 또는 approved이며 approval에는 승인 기록 경로와 승인 대상 이미지 해시를 기록한다. reference_concept_asset_id와 reference_concept_sha256, appearance_contract_sha256을 고정한다.

images에는 combat/front/side/rear 네 항목을 두고 asset_id, path, sha256, source_path, source_sha256, head_crown, chin, chin_estimated, soles, layout_scale, layout_offset을 기록한다. 좌표는 [x,y] 픽셀이며 생성 원본과 정규화 출력 좌표를 구분한다. 크기 비교는 중립 front를 기준으로 한다. combat는 실제 굽힌 자세의 높이를 유지한다. 후면 턱은 추정, 나머지는 관찰 기준점이다. 중립 정면·측면의 몸/머리 비율2.6~3.4와 정면 대비 머리 높이8% 차이를 구조 검사의 재검토 기준으로 쓴다.

geometry에는 canvas_size [1024,1024], neutral_body_height 640, foot_baseline_y 896, 각도별 실측 머리 높이와 몸 높이를 기록한다. view별 한 번의 균일 배율과 이동으로만 캔버스에 배치한다. 비율 변형·그림 재도색·각 신체 부위의 독립 확대는 하지 않는다. 생성 원본은 보존한다.

등록 시 assets/character/<character-id>/reference/v01/에 PNG 4장과 reference.json을 두고 manifest에는 기존 공통 출처·권리 필드 및 type motion-reference, view, reference_version, reference_set_path, reference_concept_asset_id를 기록한다. 세트 승인 전 게임 manifest에는 쓰지 않는다. 런타임 참조는 추가하지 않는다.

approval과 qa에는 상태·기록 경로·이미지 해시를 기록한다. 해당 JSON 기록 자체의 character_id/reference_version/decision/image_sha256/evidence가 일치해야 approved 검사를 통과한다. 구조 검사는 기록 정합성을 확인하며 사람의 승인 발언이나 시각 판단 자체를 자동 증명하지 않는다.

## 소비와 실패 처리

모션 제작자는 approved 세트의 해시·승인·원본 콘셉트·외형 계약을 확인하고 combat와 필요한 각도 이미지를 imagegen 입력에 첨부한다. 소비 기록에 세트 경로·버전·해시를 남긴다. 미등록·미승인·해시 불일치이면 새 모션 제작을 중단하고 기준 복구 또는 재승인을 요청한다. 기존 승인 모션의 재생은 영향을 받지 않는다.
