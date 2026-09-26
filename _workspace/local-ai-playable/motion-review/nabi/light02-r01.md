# 나비 약공격 2단 r01 검토 시안

- 2026-09-26. 미승인 검토 시안이며 runtime·manifest 등록 없음.
- 기술: `nabi-light-02`, `attack_light_combo_02`. 준비 6 / 활성 3 / 회복 12 tick, 기본 약연계 피니시. 검토용 12 FPS는 적중 시점을 결정하지 않는다.
- 입력: 승인 콘셉트 `nabi-concept-v01.png`와 승인 약공격 1단 r04를 외형·크기 참조로 사용했다. 1단 승인으로 2단 승인을 추정하지 않는다.
- 내장 imagegen 원본: `exec-7f70a339-fb37-40a9-966b-dbe7331715a3.png`. 외부 이용 권리 확인을 추가로 주장하지 않는다.
- 출력: `light02-r01.png` 및 `light02-preview.html`. 불투명 회색 배경의 검토용 4×4 시트다.
- SHA-256: `0f11cf2620384412c71b62353e1a55d7be19dd8bedb8ce84fe5ddfa4b6c9d1dc`.

## 확인과 한계

흰 머리·귀·꼬리 한 개, 검정·보라 의상과 인간형 손발을 유지했다. 6–8번의 뻗기와 9–11번의 아래 회수는 1단의 짧은 잽과 구별된다. 그러나 원본 4→5번은 준비 자세로 되돌아간다. PNG 자체를 편집하지 않고 미리보기의 재생 순서를 `1,5,2,3,4,6,7,8,9,10,11,12,13,14,15,16`으로 제안한다. 원본 순서도 선택할 수 있다.

8번 손 끝의 여백이 좁고 프레임별 발 높이·크기 차이가 있어 최종 셀 정규화 검사가 필요하다. 현재 시트를 그대로 runtime으로 쓰지 않는다. 재생 연속성·실루엣·사용자 채택과 투명화 품질은 별도로 확인한다.

독립 QA의 이미지 직접 검토 의견: 외형·동작 방향 선택 자료로 제시 가능하나, 가로 휘두르기보다 큰 찌르기로 읽힐 수 있다. 13–16번은 복귀 자세 차이가 작다. 1254×1254 원본은 4등분한 셀이 313.5px이므로 정확한 정수 셀 포장이 아니다. 12 FPS 재생은 1.33초 느린 검토이고 실제 21 tick(0.35초)과 다르다. 저장된 독립 보고서는 작업 폴더의 `03_qa_light02_review.md`이며 브라우저 재생 통과를 주장하지 않는다.

미리보기 HTML 제공과 실제 브라우저 재생 검증을 구분한다. HTTP 응답은 200으로 확인했으나 브라우저의 로컬 페이지 접근이 실패했고 파일 URL은 보안 정책으로 차단됐다. 우회하지 않았으며 재생 시각 검사는 미확인이다. 임시 HTTP 서버는 종료했다.

## 생성 프롬프트

Use case: stylized-concept. Generate a NEW review sprite sheet for Nabi light combo 02, a grounded finishing claw sweep to the RIGHT. Image 1 is the approved adult female chibi character identity reference. Image 2 is ONLY reference for consistent scale, style, costume and ready stance; do not repeat its jab action. Exactly 16 sequential full-body poses in a square 4x4 equal-cell grid, row-major. Flat UNIFORM OPAQUE background #34383f, no transparency, no grid lines or text. All characters face RIGHT in a stable side/three-quarter view. Three-head-tall human-form fighter, silver-white hair, exactly two white cat ears and ONE full long white cat tail, black cropped hooded jacket with purple diagonal accents, charcoal shorts and fitted tights, purple/white high-top sneakers, short lavender metal claw guards, restrained gold crescent. No animal paws/legs/muzzle, bell, ribbon, extra tails or ears. Motion: 1-4 crouched ready pose draws right/front claw back across torso and coils shoulders; 5-8 opens torso and extends a broad strong horizontal outward claw sweep at chest height to the right; 9-12 reaches follow-through, arm sweeps slightly down, weight settles back; 13-16 returns to ready stance. Both feet stay planted, foot baseline and root position identical across cells, no leaps, no spins, no camera movement. All 16 clearly progressive distinct poses with consistent limb lengths, identity and costume. Keep every ear, tail, hand and foot comfortably inside its cell with at least 10 percent padding; no neighboring-cell overlap. No opponent, particles, speed trails or slash VFX, no white outline or halos. This illustrates the attack's 6 startup / 3 active / 12 recovery ticks but do not print numbers. Emphasize actual arm and torso motion, not moving a static cutout.
