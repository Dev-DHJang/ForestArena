# 음악과 효과음 v01

밝은 숲 판타지 분위기의 독창적 작곡·합성 음원을 사용한다. 목관·뜯는 현악·나무 타악·현악·베이스를 코드로 합성했다. 외부 녹음·악기 샘플·음성은 쓰지 않았다. 합성 음색의 청취 품질은 사람이 따로 확인해야 한다.

## 필요한 소리와 재생 시점

| 영역 | 소리 | 재생 시점 |
| --- | --- | --- |
| 메뉴 음악 | lobby, 80초 반복 | 첫 선택·로비·상점·준비·설정·LAN 대기 |
| 경기 음악 | battle, 90초 반복 | 로컬·LAN 경기, 일시정지 중 음량 낮춤 |
| UI | click, back, select, confirm, error | 버튼·선택 변경, 실제 저장 성공·실패, LAN 연결 오류 |
| 이동 | jump, land, dash, evade, respawn | 동작이 실제 시작되거나 착지·재등장했을 때 |
| 전투 | swing_light/heavy, hit_light/heavy, guard_hit/break, charge_start/ready | 공격 시작, 실제 적중·막기·가드 파괴, 차지 시작·최대 충전 |
| 주요 기술 | 네 캐릭터별 special_neutral/side/up/down, ultimate | 해당 기술의 발동이 성공했을 때 |
| 기술 적중 | special_hit, ultimate_hit | 실제 적중했을 때 |
| 경기 흐름 | match_start, ring_out, victory, defeat, draw | 경기 진입·링아웃·사용자 기준 결과 |

전체 47개 파일이며 음악 2개, 효과음 45개다. 빗나감과 무적 판정에는 적중음이 없다. 막힌 공격에는 가드음이 난다. 거절된 입력에는 기술 발동음이 없다. 발소리·지속 환경음·Story 대화와 보상음은 포함하지 않는다.

## 연결과 설정

실제 경로 대신 `fa.audio.*` 이름을 `ForestArenaResources.load_audio()`에 전달한다. 이벤트별 이름·음량·우선순위와 같은 소리의 동시 재생 개수는 `forest_arena/data/audio_events_v01.json`에서 정한다. `ForestArenaAudio`가 모든 재생을 담당하고 기존 `CombatAudio`는 이벤트를 전달한다.

음량을 묶어 조절하는 경로인 오디오 버스는 Master·Music·UI·Combat이다. 효과음 전체는 최대 16개, 그중 UI는 최대 4개다. 한도를 넘으면 중요도가 낮은 오래된 소리부터 정리한다. 필살기·링아웃·결과음은 우선하며 음악을 잠시 낮춘다. 전체 출력을 제한하는 Master limiter로 여러 효과음이 겹쳐도 최대 크기를 -1 dB 아래로 제한한다. 화면 사이 음악 전환은 0.5초다. 같은 메뉴 음악은 화면을 바꿔도 처음부터 다시 시작하지 않는다.

설정 화면에서 전체 음소거·음악·효과음 음량을 바꾼다. 기본 음량은 음악 60%, 효과음 80%다. 설정은 `user://forest_arena_audio.cfg`에 기기별로 저장되며 DB 프로필과 별개다. 시각 효과 줄이기는 음소거를 바꾸지 않는다.

앱이 백그라운드로 가면 음악을 멈추고 효과음을 정리한다. 복귀하면 음악 위치를 이어 재생한다. 로컬 경기는 사용자가 계속하기를 누를 때까지 일시정지한다. LAN 경기는 서버의 진행을 따르며 이 변경으로 네트워크나 승패 규칙을 바꾸지 않는다.

LAN 효과음은 서버가 확정한 표현 이벤트로 재생한다. 경기 번호(epoch)와 이벤트 번호(event_seq)로 중복을 막는다. 서버가 보낸 상태를 복원하는 동작은 효과음을 새로 발생시키지 않는다. 사운드는 전투 판정을 만들거나 시간을 바꾸지 않는다.

## 제작과 검사

생성 방법·원본·확인값·미리듣기는 [음원 제작 기록](../../assets/audio/v01/README.md)과 자산 목록 `assets/audio/v01/manifest.json`에 있다. 반복 음악은 원본 WAV를 보존하고 게임에서는 압축 OGG를 쓴다. 효과음은 모노 WAV다. `assets/audio/.gdignore`로 원본과 미리듣기 파일이 Godot 패키지에 중복 포함되지 않게 한다.

```sh
python3 tools/forest_arena/generate_audio_v01.py
python3 tools/forest_arena/verify_audio_v01.py
python3 tools/forest_arena/verify_godot_resources.py --project-root .
godot --headless --path . --script res://tests/phase6_audio_contract.gd
godot --headless --path . --script res://tests/audio_app_flow.gd
```

생성과 신호 검사는 NumPy와 ffmpeg가 필요하다. 코드와 고정 난수값으로 같은 실행 파일과 원본을 다시 만들 수 있다. 음악의 Godot 가져오기 설정에서 반복(loop=true)을 유지한다.

## 사람이 확인할 항목

- `AUDIO-LISTEN-01`: 음악을 각각 3회 반복해 끊김과 피로감 확인.
- `AUDIO-PLAY-01`: 메뉴 클릭·저장 성공/실패, 네 캐릭터의 모든 특수기·필살기, 8인전에서 중요한 소리 구분.
- `AUDIO-ANDROID-01`: Android 스피커·이어폰 전환, 앱 중단·복귀, 결과·재대전·로비 복귀에서 중복 재생과 음량 확인.

자동 신호 검사나 데스크톱 실행으로 Android 청취 통과를 대신하지 않는다. 실제 수행 여부는 작업 QA와 마무리 기록에서 확인한다.
