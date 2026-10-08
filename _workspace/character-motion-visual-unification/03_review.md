# 캐릭터 모션 교체 후보 승인 목록

상태: 2026-10-08 사용자 119종 명시 승인, 런타임 등록 완료. 승인 기록은 `approval.json`, 등록 전후 해시는 `05_install_receipt.json`에 있다.

자현 기준 `attack_heavy_charge` 1종은 유지하고, 나머지 119종을 복원·재생성한 승인본입니다. 아래 목록이 승인·등록 대상을 정확히 지정합니다.

- 형식: RGBA, 128×128 셀, 2048×128, 모션당 16프레임.
- 기준점: 셀 중앙, 아래 124px. 원래 FPS·반복 설정을 유지합니다.
- 구조 검사: 119종·1904프레임, 파일/원본 SHA-256, 비어 있지 않은 alpha와 시트 규격 통과.
- 수동 검토: 4캐릭터 120종 개요판을 확인하고, 누락·잘림·이중 캐릭터 문제를 분류했습니다. 정량적인 얼굴 유사도 점수는 주장하지 않습니다.
- 확인할 부분: 새 생성본과 복원본 사이의 얼굴 표현·화면상 크기 및 연속 동작의 자연스러움. 게임 내 최종 확인은 승인본 등록 뒤 수행합니다.
- 생성: 내장 이미지 생성 도구. 프롬프트는 `generation-prompts.json`, `resume-prompts.json`, `resume-generation-record.json`, `refinement-prompts.json`에 기록되어 있습니다. 이전 시점 일부 생성의 정확한 프롬프트는 이 파일들에 없으며 새로 복원했다고 주장하지 않습니다.
- 해시별 상세 목록: [report.json](03_staged/report.json). 제외한 실패 시안은 `02_drafts`에 남아 있지만 승인 대상이 아닙니다.

## ja-hyun — 29종

[검토판 1](03_staged/ja-hyun/page-01.jpg) · [검토판 2](03_staged/ja-hyun/page-02.jpg) · [검토판 3](03_staged/ja-hyun/page-03.jpg) · [검토판 4](03_staged/ja-hyun/page-04.jpg) · [검토판 5](03_staged/ja-hyun/page-05.jpg)

- [attack_air_heavy](03_staged/ja-hyun/attack_air_heavy.gif) — [시트](03_staged/ja-hyun/attack_air_heavy_16f.png), 12 FPS, 단발
- [attack_air_light](03_staged/ja-hyun/attack_air_light.gif) — [시트](03_staged/ja-hyun/attack_air_light_16f.png), 12 FPS, 단발
- [attack_dash_heavy](03_staged/ja-hyun/attack_dash_heavy.gif) — [시트](03_staged/ja-hyun/attack_dash_heavy_16f.png), 12 FPS, 단발
- [attack_dash_light](03_staged/ja-hyun/attack_dash_light.gif) — [시트](03_staged/ja-hyun/attack_dash_light_16f.png), 12 FPS, 단발
- [attack_heavy_down](03_staged/ja-hyun/attack_heavy_down.gif) — [시트](03_staged/ja-hyun/attack_heavy_down_16f.png), 12 FPS, 단발
- [attack_heavy_side](03_staged/ja-hyun/attack_heavy_side.gif) — [시트](03_staged/ja-hyun/attack_heavy_side_16f.png), 12 FPS, 단발
- [attack_heavy_up](03_staged/ja-hyun/attack_heavy_up.gif) — [시트](03_staged/ja-hyun/attack_heavy_up_16f.png), 12 FPS, 단발
- [attack_light_combo_01](03_staged/ja-hyun/attack_light_combo_01.gif) — [시트](03_staged/ja-hyun/attack_light_combo_01_16f.png), 12 FPS, 단발
- [attack_light_combo_02](03_staged/ja-hyun/attack_light_combo_02.gif) — [시트](03_staged/ja-hyun/attack_light_combo_02_16f.png), 12 FPS, 단발
- [attack_light_combo_03](03_staged/ja-hyun/attack_light_combo_03.gif) — [시트](03_staged/ja-hyun/attack_light_combo_03_16f.png), 12 FPS, 단발
- [attack_light_down](03_staged/ja-hyun/attack_light_down.gif) — [시트](03_staged/ja-hyun/attack_light_down_16f.png), 12 FPS, 단발
- [attack_light_up](03_staged/ja-hyun/attack_light_up.gif) — [시트](03_staged/ja-hyun/attack_light_up_16f.png), 12 FPS, 단발
- [death](03_staged/ja-hyun/death.gif) — [시트](03_staged/ja-hyun/death_16f.png), 12 FPS, 단발
- [evade](03_staged/ja-hyun/evade.gif) — [시트](03_staged/ja-hyun/evade_16f.png), 80 FPS, 단발
- [guard](03_staged/ja-hyun/guard.gif) — [시트](03_staged/ja-hyun/guard_16f.png), 24 FPS, 단발
- [hitstun](03_staged/ja-hyun/hitstun.gif) — [시트](03_staged/ja-hyun/hitstun_16f.png), 24 FPS, 단발
- [idle](03_staged/ja-hyun/idle.gif) — [시트](03_staged/ja-hyun/idle_16f.png), 8 FPS, 반복
- [jump](03_staged/ja-hyun/jump.gif) — [시트](03_staged/ja-hyun/jump_16f.png), 12 FPS, 단발
- [knock_down](03_staged/ja-hyun/knock_down.gif) — [시트](03_staged/ja-hyun/knock_down_16f.png), 12 FPS, 단발
- [launch](03_staged/ja-hyun/launch.gif) — [시트](03_staged/ja-hyun/launch_16f.png), 12 FPS, 단발
- [ring_out](03_staged/ja-hyun/ring_out.gif) — [시트](03_staged/ja-hyun/ring_out_16f.png), 12 FPS, 단발
- [run](03_staged/ja-hyun/run.gif) — [시트](03_staged/ja-hyun/run_16f.png), 12 FPS, 반복
- [spawn](03_staged/ja-hyun/spawn.gif) — [시트](03_staged/ja-hyun/spawn_16f.png), 12 FPS, 단발
- [special_down](03_staged/ja-hyun/special_down.gif) — [시트](03_staged/ja-hyun/special_down_16f.png), 12 FPS, 단발
- [special_neutral](03_staged/ja-hyun/special_neutral.gif) — [시트](03_staged/ja-hyun/special_neutral_16f.png), 12 FPS, 단발
- [special_side](03_staged/ja-hyun/special_side.gif) — [시트](03_staged/ja-hyun/special_side_16f.png), 12 FPS, 단발
- [special_up](03_staged/ja-hyun/special_up.gif) — [시트](03_staged/ja-hyun/special_up_16f.png), 12 FPS, 단발
- [ultimate](03_staged/ja-hyun/ultimate.gif) — [시트](03_staged/ja-hyun/ultimate_16f.png), 12 FPS, 단발
- [wake_up](03_staged/ja-hyun/wake_up.gif) — [시트](03_staged/ja-hyun/wake_up_16f.png), 12 FPS, 단발

## myo-ryung — 31종

[검토판 1](03_staged/myo-ryung/page-01.jpg) · [검토판 2](03_staged/myo-ryung/page-02.jpg) · [검토판 3](03_staged/myo-ryung/page-03.jpg) · [검토판 4](03_staged/myo-ryung/page-04.jpg) · [검토판 5](03_staged/myo-ryung/page-05.jpg) · [검토판 6](03_staged/myo-ryung/page-06.jpg)

- [attack_air_heavy](03_staged/myo-ryung/attack_air_heavy.gif) — [시트](03_staged/myo-ryung/attack_air_heavy_16f.png), 12 FPS, 단발
- [attack_air_light](03_staged/myo-ryung/attack_air_light.gif) — [시트](03_staged/myo-ryung/attack_air_light_16f.png), 12 FPS, 단발
- [attack_dash_heavy](03_staged/myo-ryung/attack_dash_heavy.gif) — [시트](03_staged/myo-ryung/attack_dash_heavy_16f.png), 12 FPS, 단발
- [attack_dash_light](03_staged/myo-ryung/attack_dash_light.gif) — [시트](03_staged/myo-ryung/attack_dash_light_16f.png), 12 FPS, 단발
- [attack_heavy_charge](03_staged/myo-ryung/attack_heavy_charge.gif) — [시트](03_staged/myo-ryung/attack_heavy_charge_16f.png), 12 FPS, 단발
- [attack_heavy_down](03_staged/myo-ryung/attack_heavy_down.gif) — [시트](03_staged/myo-ryung/attack_heavy_down_16f.png), 12 FPS, 단발
- [attack_heavy_side](03_staged/myo-ryung/attack_heavy_side.gif) — [시트](03_staged/myo-ryung/attack_heavy_side_16f.png), 12 FPS, 단발
- [attack_heavy_up](03_staged/myo-ryung/attack_heavy_up.gif) — [시트](03_staged/myo-ryung/attack_heavy_up_16f.png), 12 FPS, 단발
- [attack_light_combo_01](03_staged/myo-ryung/attack_light_combo_01.gif) — [시트](03_staged/myo-ryung/attack_light_combo_01_16f.png), 12 FPS, 단발
- [attack_light_combo_02](03_staged/myo-ryung/attack_light_combo_02.gif) — [시트](03_staged/myo-ryung/attack_light_combo_02_16f.png), 12 FPS, 단발
- [attack_light_combo_03](03_staged/myo-ryung/attack_light_combo_03.gif) — [시트](03_staged/myo-ryung/attack_light_combo_03_16f.png), 12 FPS, 단발
- [attack_light_combo_04](03_staged/myo-ryung/attack_light_combo_04.gif) — [시트](03_staged/myo-ryung/attack_light_combo_04_16f.png), 12 FPS, 단발
- [attack_light_down](03_staged/myo-ryung/attack_light_down.gif) — [시트](03_staged/myo-ryung/attack_light_down_16f.png), 12 FPS, 단발
- [attack_light_up](03_staged/myo-ryung/attack_light_up.gif) — [시트](03_staged/myo-ryung/attack_light_up_16f.png), 12 FPS, 단발
- [death](03_staged/myo-ryung/death.gif) — [시트](03_staged/myo-ryung/death_16f.png), 12 FPS, 단발
- [evade](03_staged/myo-ryung/evade.gif) — [시트](03_staged/myo-ryung/evade_16f.png), 80 FPS, 단발
- [guard](03_staged/myo-ryung/guard.gif) — [시트](03_staged/myo-ryung/guard_16f.png), 24 FPS, 단발
- [hitstun](03_staged/myo-ryung/hitstun.gif) — [시트](03_staged/myo-ryung/hitstun_16f.png), 24 FPS, 단발
- [idle](03_staged/myo-ryung/idle.gif) — [시트](03_staged/myo-ryung/idle_16f.png), 8 FPS, 반복
- [jump](03_staged/myo-ryung/jump.gif) — [시트](03_staged/myo-ryung/jump_16f.png), 12 FPS, 단발
- [knock_down](03_staged/myo-ryung/knock_down.gif) — [시트](03_staged/myo-ryung/knock_down_16f.png), 12 FPS, 단발
- [launch](03_staged/myo-ryung/launch.gif) — [시트](03_staged/myo-ryung/launch_16f.png), 12 FPS, 단발
- [ring_out](03_staged/myo-ryung/ring_out.gif) — [시트](03_staged/myo-ryung/ring_out_16f.png), 12 FPS, 단발
- [run](03_staged/myo-ryung/run.gif) — [시트](03_staged/myo-ryung/run_16f.png), 12 FPS, 반복
- [spawn](03_staged/myo-ryung/spawn.gif) — [시트](03_staged/myo-ryung/spawn_16f.png), 12 FPS, 단발
- [special_down](03_staged/myo-ryung/special_down.gif) — [시트](03_staged/myo-ryung/special_down_16f.png), 12 FPS, 단발
- [special_neutral](03_staged/myo-ryung/special_neutral.gif) — [시트](03_staged/myo-ryung/special_neutral_16f.png), 12 FPS, 단발
- [special_side](03_staged/myo-ryung/special_side.gif) — [시트](03_staged/myo-ryung/special_side_16f.png), 12 FPS, 단발
- [special_up](03_staged/myo-ryung/special_up.gif) — [시트](03_staged/myo-ryung/special_up_16f.png), 12 FPS, 단발
- [ultimate](03_staged/myo-ryung/ultimate.gif) — [시트](03_staged/myo-ryung/ultimate_16f.png), 12 FPS, 단발
- [wake_up](03_staged/myo-ryung/wake_up.gif) — [시트](03_staged/myo-ryung/wake_up_16f.png), 12 FPS, 단발

## nabi — 29종

[검토판 1](03_staged/nabi/page-01.jpg) · [검토판 2](03_staged/nabi/page-02.jpg) · [검토판 3](03_staged/nabi/page-03.jpg) · [검토판 4](03_staged/nabi/page-04.jpg) · [검토판 5](03_staged/nabi/page-05.jpg)

- [attack_air_heavy](03_staged/nabi/attack_air_heavy.gif) — [시트](03_staged/nabi/attack_air_heavy_16f.png), 12 FPS, 단발
- [attack_air_light](03_staged/nabi/attack_air_light.gif) — [시트](03_staged/nabi/attack_air_light_16f.png), 12 FPS, 단발
- [attack_dash_heavy](03_staged/nabi/attack_dash_heavy.gif) — [시트](03_staged/nabi/attack_dash_heavy_16f.png), 12 FPS, 단발
- [attack_dash_light](03_staged/nabi/attack_dash_light.gif) — [시트](03_staged/nabi/attack_dash_light_16f.png), 12 FPS, 단발
- [attack_heavy_charge](03_staged/nabi/attack_heavy_charge.gif) — [시트](03_staged/nabi/attack_heavy_charge_16f.png), 12 FPS, 단발
- [attack_heavy_down](03_staged/nabi/attack_heavy_down.gif) — [시트](03_staged/nabi/attack_heavy_down_16f.png), 12 FPS, 단발
- [attack_heavy_side](03_staged/nabi/attack_heavy_side.gif) — [시트](03_staged/nabi/attack_heavy_side_16f.png), 12 FPS, 단발
- [attack_heavy_up](03_staged/nabi/attack_heavy_up.gif) — [시트](03_staged/nabi/attack_heavy_up_16f.png), 12 FPS, 단발
- [attack_light_combo_01](03_staged/nabi/attack_light_combo_01.gif) — [시트](03_staged/nabi/attack_light_combo_01_16f.png), 12 FPS, 단발
- [attack_light_combo_02](03_staged/nabi/attack_light_combo_02.gif) — [시트](03_staged/nabi/attack_light_combo_02_16f.png), 12 FPS, 단발
- [attack_light_down](03_staged/nabi/attack_light_down.gif) — [시트](03_staged/nabi/attack_light_down_16f.png), 12 FPS, 단발
- [attack_light_up](03_staged/nabi/attack_light_up.gif) — [시트](03_staged/nabi/attack_light_up_16f.png), 12 FPS, 단발
- [death](03_staged/nabi/death.gif) — [시트](03_staged/nabi/death_16f.png), 12 FPS, 단발
- [evade](03_staged/nabi/evade.gif) — [시트](03_staged/nabi/evade_16f.png), 80 FPS, 단발
- [guard](03_staged/nabi/guard.gif) — [시트](03_staged/nabi/guard_16f.png), 24 FPS, 단발
- [hitstun](03_staged/nabi/hitstun.gif) — [시트](03_staged/nabi/hitstun_16f.png), 24 FPS, 단발
- [idle](03_staged/nabi/idle.gif) — [시트](03_staged/nabi/idle_16f.png), 8 FPS, 반복
- [jump](03_staged/nabi/jump.gif) — [시트](03_staged/nabi/jump_16f.png), 12 FPS, 단발
- [knock_down](03_staged/nabi/knock_down.gif) — [시트](03_staged/nabi/knock_down_16f.png), 12 FPS, 단발
- [launch](03_staged/nabi/launch.gif) — [시트](03_staged/nabi/launch_16f.png), 12 FPS, 단발
- [ring_out](03_staged/nabi/ring_out.gif) — [시트](03_staged/nabi/ring_out_16f.png), 12 FPS, 단발
- [run](03_staged/nabi/run.gif) — [시트](03_staged/nabi/run_16f.png), 12 FPS, 반복
- [spawn](03_staged/nabi/spawn.gif) — [시트](03_staged/nabi/spawn_16f.png), 12 FPS, 단발
- [special_down](03_staged/nabi/special_down.gif) — [시트](03_staged/nabi/special_down_16f.png), 12 FPS, 단발
- [special_neutral](03_staged/nabi/special_neutral.gif) — [시트](03_staged/nabi/special_neutral_16f.png), 12 FPS, 단발
- [special_side](03_staged/nabi/special_side.gif) — [시트](03_staged/nabi/special_side_16f.png), 12 FPS, 단발
- [special_up](03_staged/nabi/special_up.gif) — [시트](03_staged/nabi/special_up_16f.png), 12 FPS, 단발
- [ultimate](03_staged/nabi/ultimate.gif) — [시트](03_staged/nabi/ultimate_16f.png), 12 FPS, 단발
- [wake_up](03_staged/nabi/wake_up.gif) — [시트](03_staged/nabi/wake_up_16f.png), 12 FPS, 단발

## yu-ran — 30종

[검토판 1](03_staged/yu-ran/page-01.jpg) · [검토판 2](03_staged/yu-ran/page-02.jpg) · [검토판 3](03_staged/yu-ran/page-03.jpg) · [검토판 4](03_staged/yu-ran/page-04.jpg) · [검토판 5](03_staged/yu-ran/page-05.jpg)

- [attack_air_heavy](03_staged/yu-ran/attack_air_heavy.gif) — [시트](03_staged/yu-ran/attack_air_heavy_16f.png), 12 FPS, 단발
- [attack_air_light](03_staged/yu-ran/attack_air_light.gif) — [시트](03_staged/yu-ran/attack_air_light_16f.png), 12 FPS, 단발
- [attack_dash_heavy](03_staged/yu-ran/attack_dash_heavy.gif) — [시트](03_staged/yu-ran/attack_dash_heavy_16f.png), 12 FPS, 단발
- [attack_dash_light](03_staged/yu-ran/attack_dash_light.gif) — [시트](03_staged/yu-ran/attack_dash_light_16f.png), 12 FPS, 단발
- [attack_heavy_charge](03_staged/yu-ran/attack_heavy_charge.gif) — [시트](03_staged/yu-ran/attack_heavy_charge_16f.png), 12 FPS, 단발
- [attack_heavy_down](03_staged/yu-ran/attack_heavy_down.gif) — [시트](03_staged/yu-ran/attack_heavy_down_16f.png), 12 FPS, 단발
- [attack_heavy_side](03_staged/yu-ran/attack_heavy_side.gif) — [시트](03_staged/yu-ran/attack_heavy_side_16f.png), 12 FPS, 단발
- [attack_heavy_up](03_staged/yu-ran/attack_heavy_up.gif) — [시트](03_staged/yu-ran/attack_heavy_up_16f.png), 12 FPS, 단발
- [attack_light_combo_01](03_staged/yu-ran/attack_light_combo_01.gif) — [시트](03_staged/yu-ran/attack_light_combo_01_16f.png), 12 FPS, 단발
- [attack_light_combo_02](03_staged/yu-ran/attack_light_combo_02.gif) — [시트](03_staged/yu-ran/attack_light_combo_02_16f.png), 12 FPS, 단발
- [attack_light_combo_03](03_staged/yu-ran/attack_light_combo_03.gif) — [시트](03_staged/yu-ran/attack_light_combo_03_16f.png), 12 FPS, 단발
- [attack_light_down](03_staged/yu-ran/attack_light_down.gif) — [시트](03_staged/yu-ran/attack_light_down_16f.png), 12 FPS, 단발
- [attack_light_up](03_staged/yu-ran/attack_light_up.gif) — [시트](03_staged/yu-ran/attack_light_up_16f.png), 12 FPS, 단발
- [death](03_staged/yu-ran/death.gif) — [시트](03_staged/yu-ran/death_16f.png), 12 FPS, 단발
- [evade](03_staged/yu-ran/evade.gif) — [시트](03_staged/yu-ran/evade_16f.png), 80 FPS, 단발
- [guard](03_staged/yu-ran/guard.gif) — [시트](03_staged/yu-ran/guard_16f.png), 24 FPS, 단발
- [hitstun](03_staged/yu-ran/hitstun.gif) — [시트](03_staged/yu-ran/hitstun_16f.png), 24 FPS, 단발
- [idle](03_staged/yu-ran/idle.gif) — [시트](03_staged/yu-ran/idle_16f.png), 8 FPS, 반복
- [jump](03_staged/yu-ran/jump.gif) — [시트](03_staged/yu-ran/jump_16f.png), 12 FPS, 단발
- [knock_down](03_staged/yu-ran/knock_down.gif) — [시트](03_staged/yu-ran/knock_down_16f.png), 12 FPS, 단발
- [launch](03_staged/yu-ran/launch.gif) — [시트](03_staged/yu-ran/launch_16f.png), 12 FPS, 단발
- [ring_out](03_staged/yu-ran/ring_out.gif) — [시트](03_staged/yu-ran/ring_out_16f.png), 12 FPS, 단발
- [run](03_staged/yu-ran/run.gif) — [시트](03_staged/yu-ran/run_16f.png), 12 FPS, 반복
- [spawn](03_staged/yu-ran/spawn.gif) — [시트](03_staged/yu-ran/spawn_16f.png), 12 FPS, 단발
- [special_down](03_staged/yu-ran/special_down.gif) — [시트](03_staged/yu-ran/special_down_16f.png), 12 FPS, 단발
- [special_neutral](03_staged/yu-ran/special_neutral.gif) — [시트](03_staged/yu-ran/special_neutral_16f.png), 12 FPS, 단발
- [special_side](03_staged/yu-ran/special_side.gif) — [시트](03_staged/yu-ran/special_side_16f.png), 12 FPS, 단발
- [special_up](03_staged/yu-ran/special_up.gif) — [시트](03_staged/yu-ran/special_up_16f.png), 12 FPS, 단발
- [ultimate](03_staged/yu-ran/ultimate.gif) — [시트](03_staged/yu-ran/ultimate_16f.png), 12 FPS, 단발
- [wake_up](03_staged/yu-ran/wake_up.gif) — [시트](03_staged/yu-ran/wake_up_16f.png), 12 FPS, 단발
