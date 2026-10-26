# 제작자 headless 검사 r03

명령:

```sh
godot --headless --path . --script _workspace/motion-naturalness-v1/qa/launch-release-prototype-r01/check-prototype.gd
```

`check-r03.log`: Godot4.7.1, **631개 검사 PASS**, 실패0, ERROR 없음. `report.json`은 최종 검사 수와 FPS별 실제 선택 번호를 담는다. 이 자료는 제작자가 만든 복제 코드의 상태/프레임 선택 시험이며 독립 QA 또는 실제 게임 영상 통과가 아니다.

- 실제 MatchController/FighterController와 자현 프로필을 생성하고 r09 PNG를 메모리 Texture/SpriteFrames로 읽었다. 원본 PNG 해시와 entry 해시 일치도 검사했다.
- 원본 entry를 메모리에서 복사한 clone 쪽에만 선택 필드 두 개를 넣었다. baseline은 선택 필드가 없으며 제품 표현 스크립트 그대로다.
- 실제 `apply_network_snapshot`으로 경직0의 LAUNCH를 넣고12FPS로F5를 본 뒤 FALL 또는JUMP 상태로 전환했다. 클론의 `_reaction_duration_ticks`는0이다.
- 정상/반전 각30·60·120FPS에서4/60초 해제, 예상 그림 번호, 단일 반전 유지. 30FPS의 관찰은F13→F15→jumpF11, 60FPS는F13→14→15→16→jumpF11, 120FPS는각그림2번이다. 낮은 표시FPS에서 시간을 늘려 누락 그림을 강제로 보여 주지 않는다.
- 실제 마지막F16 도달 뒤 연결0회. 모든 기존 마지막 번호0..15를 helper에 넣어 구간 시작/남은 그림 선택을 확인했다.
- 선택 값이 없으면 launch와FALL의 그림·모션·위치가 제품 baseline과 일치했다.
- 실제 `consume_intent` 점프·약공격은 연결이 끝나기 전에 전투에서 즉시 실행되며 표현 연결도 즉시 중단됐다. 이동 입력도 그대로 적용됐다.
- 상태 결과를 통한 새 guard/evade/down/착지/사망/ringout/경기종료, 활성 공격, 새activation, 점프 허용 횟수/발사 점프/속도 충격/FALL→JUMP, 타격 신호, 고유LAN HIT/중복HIT, reset/프로필 변경을 확인했다. 일반 새 피격은HITSTUN F1, 날림 새 피격은launch F1로 바뀌었다.
- 매 표현 호출 전후 전체 `fighter.snapshot()`과 별도 내부hitstun/input_direction/buffered_intent/activation/launcher허용 값을 비교했다. 입력 버퍼의 전문 값도 비교했으며 모두 불변이었다.
- 잘못된 값: 쌍 누락, 빈/문자열/잘못된 배열, 음수/역전/범위초과/같은경계, 정수가 아닌index/ticks, NaN/Inf,0/음수/13틱, 그림수보다짧은시간, 해시누락을 거부했다. 실제 복제 표현에서도 잘못된 값은 기존 낙하로 갔다. 진행 중 잘못된 값/다른원화hash는 연결을 끊었다.

`source-hashes-r03.json`: 원본 제품이 복제 이후 바뀌지 않았음, 고정 r09 인계8파일 해시가 모두 같음, helper/복제/시험 소스의 최종 해시를 기록한다. 기존 테스트나 r09/candidate catalog/제품/manifest는 수정하지 않았다. 전체verify는 root가 수행 중이므로 중복 실행하지 않았다.
