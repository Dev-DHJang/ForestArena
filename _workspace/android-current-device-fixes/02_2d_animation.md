# 실기기 모션 크기 문제 수정

사용자가 두 실제 기기의 자현 연습에서 모션마다 크기가 다르다고 보고했다. 승인된 PNG·SpriteFrames·manifest와 원본 작업 폴더는 변경하지 않고, 화면에 그릴 배율만 고쳤다. 전투 이동·피해·피격·콤보 의미는 전투 역할이 별도로 다룬다.

기존 `local_fighter_presentation.gd`는 manifest의 `presentation_scale`을 그대로 사용했다. 2026-10-08 승인 교체본에도 이전 시트의 1.2 값이 남아 idle/run/기본 콤보와 회피·피격·강공격 사이에 배율이 달랐다. 실제 자현 약 콤보 1의 몸도 idle보다 작으므로 1.2를 일괄 삭제하는 것만으로는 충분하지 않았다.

`forest_arena/data/character_display_layout_v01.json`에 schema_version 1, 캐릭터·모션 ID, 승인된 PNG 해시, 고정 표시 배율, 발 기준점 124를 기록했다. 적용할 때 manifest의 PNG 해시까지 같아야 사용한다. 다른 버전 그림은 이전 manifest 설정으로 돌아가므로 현재 수치를 이전 승인 시트에 잘못 적용하지 않는다. Android에서 원본 PNG가 가져오기(import) 과정으로 바뀌는 경우에도 manifest 해시로 대상을 구분한다.

배율은 각 캐릭터 idle의 머리·얼굴 중심부를 기준으로 시각 조정했다. 귀·꼬리·무기·효과를 포함한 전체 불투명 영역(alpha)의 폭이나 높이를 몸 크기로 사용하지 않는다. 모션 하나에 고정 배율 하나를 적용하며 프레임마다 크기를 늘였다 줄이지 않는다. 웅크림·도약·누움의 자연적인 자세 차이와 승인된 프레임 내용은 유지한다. 머리 중심부 폭은 약 2 원본 픽셀 오차를 포함하는 수동 시각 기준이며 자동 픽셀 측정이나 미적 품질 합격 수치로 주장하지 않는다.

자현의 예: idle 1.0, 약 콤보 1은 1.0→1.263158, 존치한 charge는 1.2→0.8, 나머지 큰 머리 공격 그룹은 대부분 1.2→0.857143이다. 배율이 바뀌어도 `(발 기준점 - 셀 중심 64) × 배율`만큼 위치를 함께 옮겨 바닥 접점은 유지한다. 충돌체·공격 영역·승패·고정 tick을 그림에 맞춰 바꾸지 않는다.

## 검증과 증거

- `godot --headless --path . --script tests/local_fighter_presentation.gd`: PASS. `MOTION-SIZE-01`은 승인 120개 시트가 모두 연결됨, 해시가 다른 그림에 미적용, 모션 중 고정 배율, 발 접점, 전투 snapshot 불변을 검사한다. 기존 점프 단계·공격 단계·좌우 반전 검사도 통과했다.
- `MOTION-SIZE-02`: 실제 OpenGL Compatibility / Apple M4 렌더러로 현재 승인 120개 모션의 0·8·15 프레임을 이전/수정 배율과 나란히 그렸다. 네 캐릭터 12개 비교판을 직접 확인했다. 자현 약 콤보의 작은 몸과 강공격·회피·피격의 과한 확대가 줄었고, 쓰러짐의 낮은 자세나 무기 궤적을 일어서 있는 높이로 늘리지 않았다. 실제 renderer에서만 실행하며 headless dummy 이미지로 통과하지 않는다.
- `python3 tools/forest_arena/verify_godot_resources.py --project-root .`: PASS, 당시 공동 작업 상태에서 491 logical assets / 품질별 24개.
- `build/motion-size-review/approved-art-preservation.json`: 현재 원본 작업 폴더와 수정 작업 사본의 승인 PNG 120개, SpriteFrames 120개 차이 0. manifest 바이트도 동일. PNG의 전체 높이는 진단 자료로만 기록하고 몸 높이로 판정하지 않았다.

실제 렌더 증거는 `build/motion-size-review/<character>-godot-f00.png`, `-f08.png`, `-f15.png`와 `render-trace-f00.json`, `-f08.json`, `-f15.json`이다. 원본 비교용 시트 읽기와 진단 렌더만 수행했으며 PNG 파일을 다시 만들거나 승인 상태를 바꾸지 않았다.

재생성 명령:

```sh
for frame in 0 8 15; do
  godot --path . --rendering-method gl_compatibility --resolution 640x360 \
    --script tests/local_fighter_display_board.gd -- "$frame"
done
```

`MOTION-SIZE-03` 수동 재검사: 새 APK의 두 실제 기기에서 자현 idle→달리기→약 콤보 1/2/3→charge/강공격→회피→피격을 직접 보고 몸 크기·발 기준·가독성을 비교한다. 이어 묘령·나비·유란을 확인한다. 이 수정 단계에서 기기를 조작하지 않았으므로 실기기 통과는 아직 기록하지 않는다. 원본 승인 그림에서 자세별 원근·머리카락 모양이 다르게 그려진 부분은 코드에서 재그리지 않았다.
