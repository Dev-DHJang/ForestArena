# 음원 연결 변경

기존 논리 ID와 이벤트 데이터 형식은 그대로다. 사용자 확정에 따라 실제 파일 경로 네 개만 바꾼다.

| 논리 ID | 버전 | 실행 파일 |
| --- | --- | --- |
| fa.audio.lobby | v01 | v01/lobby.ogg, 기존 80초 반복 |
| fa.audio.battle | v01 | v01/battle.ogg, 기존 90초 반복 |
| fa.audio.ui_click | v02 r03 | v02-selected/ui_click.wav |
| fa.audio.jump | v01 | v01/jump.wav |
| fa.audio.hit_light | v02 r03 | v02-selected/hit_light.wav |
| fa.audio.hit_heavy | v01 | v01/hit_heavy.wav |
| fa.audio.guard_break | v02 r03 | v02-selected/guard_break.wav |
| fa.audio.myo-ryung_special_up | v01 | v01/myo-ryung_special_up.wav |
| fa.audio.ja-hyun_ultimate | v02 r03 | v02-selected/ja-hyun_ultimate.wav |

경로 앞부분은 res://forest_arena/assets/audio/다. registry의 기존 ID·개수·카테고리·품질 경계를 유지한다. ForestArenaResources와 ForestArenaAudio가 기존 이벤트·버스·음량·동시 재생·중단 복귀 정책으로 읽는다. 새 판정이나 네트워크 이벤트를 만들지 않는다. 승인된 캐릭터/UI 자산은 바꾸지 않는다.
