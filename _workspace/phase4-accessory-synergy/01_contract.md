# 계약

- AccessoryData v2는 선택 장신구 0 또는 1개와 조건 효과 목록을 소유한다.
- Character → Job chain → Accessory → 조건 효과 순서로 합성한다.
- 조건은 장신구 적용 전의 Character/Job 태그 snapshot으로 한 번만 평가한다.
- 구버전, 누락 슬롯, 활성 효과 충돌은 fallback 없이 실패한다.
