# 오디오 연결 약속 v01

- 파일 대신 ForestArenaResources.load_audio의 fa.audio.* 논리 ID로 접근한다. 파일 이름과 같은 ID 끝부분을 쓴다.
- AudioDirector는 BGM·UI·Combat 재생을 소유한다. CombatAudio는 기존 이벤트 연결의 어댑터다.
- FighterController.presentation_event(event_id, payload)는 성공한 동작을 알리며 MatchController가 fighter_id, character_id, tick, epoch, event_seq를 더해 전달한다. attack_started에는 attack_id, action_id, activation_serial, direction이 있다. 기존 hit_resolved에는 action_id와 character_id를 추가한다.
- event_seq는 경기 epoch마다 1부터 증가한다. LAN 서버는 기존 presentation_event 메시지로 전달하며 클라이언트는 epoch·event_seq로 중복·이전 경기를 차단한다. 스냅샷 복원은 동작 이벤트를 발생시키지 않는다.
- AudioDirector.play_event(event_id, payload), begin_match(), finish_match(outcome), set_context(context), set_levels(music, effects, muted), set_suspended(value)를 공개한다.
- Master/Music/UI/Combat 버스를 사용한다. 겹친 소리의 최대 출력은 Master limiter로 -1 dB 아래로 제한한다. 효과음 합계 최대 16, UI 최대 4. 우선순위가 낮은 오래된 소리부터 정리한다. 필살기·결과음은 음악을 잠시 낮춘다.
- 음악/효과음 기본 0.6/0.8, 전체 음소거 false. user://forest_arena_audio.cfg에 기기별 저장한다. DB·LocalPlayerStore 형식은 바꾸지 않는다.
- 이벤트는 표현만 한다. 피해·공격 단계·판정·명령·승패 계산에 오디오 값을 참조하지 않는다.
