# Galaxy S23 Ultra 선행 증적과 R2 모바일 인수인계 — 2026-09-13

## Target and build

- Source: `feature/phase-5-job-growth` at `c7dbfb4`.
- Device: Samsung Galaxy S23 Ultra (`SM-S918N`, device `dm3q`), Android 16, wireless ADB.
- Renderer reported by Godot: OpenGL ES 3.2 Compatibility on Qualcomm Adreno 740.
- Build command: `./scripts/export-debug-android.sh` — pass, including APK contract verification.
- Installed package: `com.forestarena.welllbeing`.

## Executed checks

- Cold start: pass (`Status: ok`; Godot activity reached the foreground).
- Landscape: pass. Android reported `SCREEN_ORIENTATION_LANDSCAPE`; the captured app surface was 3088x1440.
- Launcher and combat HUD visual inspection: pass for the observed state. The launcher, D-pad, jump, light, heavy, special, ultimate and HUD were visible without observed horizontal overlap.
- Touch diagnostics: pass for movement, jump, dash/action, light, heavy, special and ultimate. Device logs contained `FOREST_ARENA_TOUCH` press/release events for those actions.
- Background and hot resume: pass. Android returned `Status: ok`, restored the Godot activity as top-resumed in landscape, and Godot logged `FOREST_ARENA_INPUT_RESET reason=pause` twice while a held movement input was being exercised.
- Ten-minute foreground input workload: completed. The device remained foregrounded and the log contained no Godot fatal exception or script error. The workload alternated movement, light, heavy, special and ultimate touch inputs.

## Not a passing performance result

`adb shell dumpsys gfxinfo com.forestarena.welllbeing` produced zero rendered-frame samples after the run. Android `gfxinfo` only measured the Java View hierarchy here; it did not collect the Godot SurfaceView renderer's frame times. Its placeholder 4950ms percentiles are therefore invalid and must not be interpreted as a performance failure or a performance pass.

The following remain unverified:

- renderer-level 60 FPS and p95 frame time <= 16.7ms for the full ten-minute combat scenario;
- the prescribed 18 Phase 3 three-stock matches and Phase 4 satisfaction/non-satisfaction matches;
- each Phase 5 leaf's corresponding-bot match and independent QA review.

Phase 3–5 status remains `blocked` until a renderer-capable performance capture and the remaining playtest matrix are supplied.

## Recovery R2 적용

- 위 결과는 보존된 이전 브랜치의 선행 smoke 증적이며 R2 코드의 통과로 간주하지 않는다.
- R2는 `user://phase5-validation/performance.jsonl`에 5초 warm-up 이후 활성·전면 `_process` delta만 600초 수집한다. pause, background, 결과 화면과 런처 노출 구간은 표본에서 제외하고 interruption으로 기록한다.
- 기록 항목은 평균 FPS, p50/p95/p99, 16.7ms 초과 frame 수다. 전투 authority와 snapshot hash에는 입력되지 않는다.
- R2 APK에서 30개 3-stock 매치, 10분 평균 60 FPS/p95 ≤16.7ms, UI·touch·pause/resume와 독립 QA를 새로 실행해야 한다.
