# 모션 수정 시안 — 최종 검토 r05

실제 경기 전체 프레임 검토에서 자현 마지막 킥 진입(tick83)의 머리·몸 축소와 나비 다운 F2→F3의 자세 역행을 확인했다. 추가 강/공중/특수 회귀에서 자현 특수기9→12·105→108의 크기 변화도 발견해 같은 작업에 포함했다.

| 모션 | 후보 변경 | 원화·시간 경계 |
| --- | --- | --- |
| 자현 마지막 킥 attack_light_combo_04 | 기존 표시 배율×1.12 | 승인 PNG 바이트·16그림·구간·시간·접지점 유지 |
| 자현 특수기 special_scarf_sweep | 기존 표시 배율×1.18 | 승인 PNG 바이트·32그림·목도리 앵커·구간·시간 유지 |
| 나비 knock_down | 피격→중심 하강→옆으로 누움16그림 | 새 원화, 공통 표시 배율0.71; 기상 첫 누움과 연결 |
| 나비 wake_up | 누움→손 짚기→앉기→낮고 넓은 전투 대기16그림 | 새 원화, 공통 표시 배율0.71; 기상 보호12틱을 변경하지 않음 |

최종 후보 입력: candidates/catalog-r05.json, scope-r05.json. 최종 검토: review-r05/. 사용자 개별 승인 전이므로 runtime PNG·SpriteFrames·manifest에는 쓰지 않았다. PNG를 그대로 쓰는 자현 두 모션의 표시 배율도 개별 승인 대상이다.

나비 원화는 내장 image_gen으로 생성/수정했다. 최종 원본: candidates/nabi-knockdown-r01-source.png와 nabi-wakeup-r02-source.png. 전체 프롬프트는 같은 폴더의 nabi-knockdown-r01-prompt.txt와 nabi-wakeup-r02-prompt.txt에 보존한다. 기존 승인 캐릭터의 파생 제작이며 외부 권리 검증을 별도로 주장하지 않는다.

1254×1254 RGBA 원본의4×4 고정 셀(313.5px)을 모두 동일하게128px로 변환해16열 시트로 포장했다. 포즈마다 크기·몸 부위를 바꾸지 않았다. body_root는 발/손의 지지 위치 차이를 보정한다. 원화 이후의 표시 배율0.71은 다운·기상 전체에 동일하게 적용한다. r02 기상의 높은 마지막 자세는 새 원화 r03으로 낮추고, r03에 남은 체형 차이는 원화 반복 생성 대신 공통배율 검토 r04로 재분류해 해결했다.

나비 새 기상 수정 입력에는 기존 기상 후보, 승인 idle 원화의 출처 `_workspace/motion-naturalness-v1/remaining/nabi/idle-r02.png`, 아래 승인 combat/front를 직접 첨부했다. 각 입력 해시는 최종 catalog의 creation.reference_images에 기록했다. 비교 원본과 제작 이력은 r01~r04 폴더에 보존했다.

참조 세트: assets/character/nabi/reference/v01/reference.json, v01 승인 검증 통과. 실제 생성 입력:
- assets/character/nabi/reference/v01/combat.png SHA256 c93479dd800e4dc77b6e93110119dc2ddde4f9913a499895b7961fe76650e25e
- assets/character/nabi/reference/v01/front.png SHA256 f0002a09935d5a5f38e90f68c9a651abc0a5a5fe74e5a60113c7b9a7311f68f6
- assets/character/nabi/reference/v01/side.png SHA256 f1c8a8e858b3b7793cbfc2acd03af58b593edc0e7c2a867037509afe1c2b9141
