# 나비 약공격 1단 검토 시안 r01

- 제작일: 2026-09-25
- 상태: 미승인 검토 시안. 런타임 등록 없음.
- 방식: 내장 image_gen. CLI/API 키 사용 없음.
- 입력: 승인 콘셉트 `assets/character/nabi/concept/nabi-concept-v01.png`, 외형 계약 v05-white-tail-chibi.
- 기술: `nabi-light-01`, `attack_light_combo_01`, 준비 4 / 활성 3 / 회복 7 tick.
- 산출물: `light01-r01.png`, 1254×1254 RGBA (sips hasAlpha=yes).
- SHA-256: `88363627246357dd71cfaf6e742cfc4a096d3f3b80b806b04555ce6ed85b3878`
- 원본 보존: `/Users/jdh/.codex/generated_images/01a0d31a-687e-7cd1-8433-aa550beb6533/exec-508d969c-a5a5-417f-8544-30593a64e607.png`
- 권리: 프로젝트 승인 콘셉트를 입력으로 생성. 외부 권리 확인을 추가로 주장하지 않는다.

## 눈으로 확인한 품질

16개 포즈와 흰 귀·흰 꼬리·검정/보라 의상·라벤더 발톱은 확인됐다. 방향은 오른쪽을 향한 3/4 방향이며 인간형 손발을 유지한다.

현재 상태는 런타임용으로 부적합하다. 프레임 3–4에서 이미 팔이 뻗었다가 5에서 돌아오는 등 시간 순서가 매끄럽지 않다. 6–8과 13–16은 차이가 작아 연속 동작이 약하다. 셀 경계 여백이 부족하고 왼쪽 꼬리 및 오른쪽 손 끝이 경계에 닿는다. 바깥쪽에 흰색·보라색 잔여 픽셀이 보이며 실제 투명 채널이 있어도 깨끗한 가장자리임을 뜻하지 않는다. 1254는 4로 나누어떨어지지 않아 정확한 동일 셀 분할도 후속 정리가 필요하다.

다음 시안은 같은 외형을 보존한 채 **셀 안쪽 여백·일정 발 기준선·순서가 연속적인 단발 잽**을 우선 수정한다. 승인 전 runtime 시트나 SpriteFrames를 만들지 않는다. 미리보기만으로 전투 모션 제작 완료나 사용자 채택을 주장하지 않는다.

## 실제 생성 프롬프트

Use case: stylized-concept. Asset type: review-only 2D fighting game animation sprite sheet, Nabi light combo 01. Input image 1 is the approved adult female chibi character identity reference, not an edit target. Generate a new square 4 by 4 grid of exactly 16 full-body animation frames, row-major left-to-right then next row, no visible grid, no numbers, no text. Genuinely transparent RGBA background, not a painted checkerboard. Each cell identical framing with generous margins for ears and tail, stable centered ground foot pivot, consistent 3-head-tall proportions, every frame facing RIGHT in fixed side/three-quarter game view. Preserve silver-white hair, exactly two WHITE cat ears, one large long fluffy WHITE cat tail, human face hands feet, black cropped hooded fighter jacket with purple diagonal accents, charcoal shorts and fitted tights, purple/white high-top sneakers, short lavender metal claw guards, restrained single gold crescent accent. No bell, ribbon, paw emblem, muzzle, animal legs, extra tails or ears. Polished semi-dimensional anime game rendering matching the reference, consistent costume and scale throughout. Action: quick close-range low claw jab to the right, first light combo step, not the finishing slash. Frames 1-4 low guarded anticipation and slight rear draw; frames 5-8 quick compact forward claw jab extending front arm at chest height, torso leans slightly; frames 9-12 retract and stabilize; frames 13-16 return to low ready stance. The feet remain on an identical baseline in every cell, no hopping, no camera movement, no overall world translation, tail follows through without covering the striking hand. This only illustrates AttackData startup 4 ticks, active 3 ticks, recovery 7 ticks; do not print timing or labels. All 16 frames distinct continuous motion, no cut-off extremities, no opponent, no props, no VFX covering anatomy.
