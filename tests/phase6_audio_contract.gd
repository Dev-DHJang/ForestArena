extends SceneTree


var failures: Array[String] = []
var audio: Node

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	audio = root.get_node("ForestArenaAudio")
	audio.set_levels(0.6, 0.8, false, false)
	audio.set_suspended(false)
	audio.set_match_paused(false)
	_test_assets()
	_test_resolution()
	_test_sequences()
	_test_voice_budget()
	await _test_music_and_lifecycle()
	await _test_settings()
	await _test_shutdown_pool()
	audio.stop_effects()
	await process_frame
	for failure: String in failures: push_error(failure)
	print("PHASE6_AUDIO_CONTRACT: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _test_assets() -> void:
	var resources := root.get_node("ForestArenaResources")
	for key: String in audio.event_map:
		var stream: AudioStream = resources.load_audio(audio.event_map[key].asset)
		check(stream != null and stream.get_length() > 0.0, "event asset loads: " + key)
	for track: String in ["lobby", "battle"]:
		var stream: AudioStream = resources.load_audio("fa.audio." + track)
		check(stream is AudioStreamOggVorbis, "music uses compressed OGG: " + track)
		if stream is AudioStreamOggVorbis:
			check(stream.loop, "music loops: " + track)
			check(stream.get_length() >= 79.5 if track == "lobby" else stream.get_length() >= 89.5, "music duration: " + track)

func _test_resolution() -> void:
	for result: String in ["MISS", "IMMUNE", ""]:
		check(audio.resolve_event(&"hit_resolved", {"result": result}).is_empty(), "silent unresolved hit: " + result)
	for result: String in ["BLOCK", "PERFECT_GUARD"]:
		check(audio.resolve_event(&"hit_resolved", {"result": result}) == "guard_hit", "guard instead of damage sound: " + result)
	for pair: Array in [["attack_light", "hit_light"], ["attack_heavy", "hit_heavy"], ["attack_special", "special_hit"], ["ultimate", "ultimate_hit"]]:
		check(audio.resolve_event(&"hit_resolved", {"result": "HIT", "action_id": pair[0]}) == pair[1], "hit category: " + pair[0])
	for character: String in ["ja-hyun", "myo-ryung", "nabi", "yu-ran"]:
		for direction: String in ["neutral", "side", "up", "down"]:
			check(audio.resolve_event(&"attack_started", {"character_id": character, "action_id": "attack_special", "direction": direction}) == character + "_special_" + direction, "character special: " + character + direction)
		check(audio.resolve_event(&"attack_started", {"character_id": character, "action_id": "ultimate"}) == character + "_ultimate", "character ultimate: " + character)
	check(audio.resolve_event(&"attack_started", {"character_id": "unknown", "action_id": "ultimate"}).is_empty(), "unknown character does not choose another character sound")
	check(audio.resolve_event(&"match_end", {}).is_empty(), "uncontextual match end stays silent")
	check(audio.resolve_event(&"match_draw", {}).is_empty(), "app owns result presentation")
	var before: int = audio.played_count
	audio.play_event(&"hit_resolved", {"result": "MISS"})
	audio.play_event(&"hit_resolved", {"result": "IMMUNE"})
	audio.play_event(&"unknown_event", {})
	check(audio.played_count == before, "silent events allocate no voices")

func _test_sequences() -> void:
	audio.begin_match()
	var before: int = audio.played_count
	audio.play_event(&"jump", {"epoch": 3, "event_seq": 10})
	audio.play_event(&"jump", {"epoch": 3, "event_seq": 10})
	audio.play_event(&"jump", {"epoch": 3, "event_seq": 9})
	audio.play_event(&"jump", {"epoch": 2, "event_seq": 99})
	check(audio.played_count == before + 1, "LAN duplicate and old epoch suppressed")
	audio.play_event(&"jump", {"epoch": 3, "event_seq": 11})
	audio.play_event(&"jump", {"epoch": 4, "event_seq": 1})
	check(audio.played_count == before + 3, "new sequence and new epoch play")
	audio.set_levels(0.6, 0.8, true, false)
	audio.play_event(&"jump", {"epoch": 4, "event_seq": 2})
	check(audio.voices.is_empty(), "muting clears effects")
	audio.set_levels(0.6, 0.8, false, false)
	audio.play_event(&"jump", {"epoch": 4, "event_seq": 2})
	check(audio.played_count == before + 3, "muted packet cannot replay after unmute")
	audio.play_event(&"jump", {"epoch": 4, "event_seq": 3, "reduce_visual_effects": true})
	check(audio.played_count == before + 4, "visual reduction does not mute sound")

func _test_voice_budget() -> void:
	var limiter_count := 0
	for index: int in AudioServer.get_bus_effect_count(0):
		var effect := AudioServer.get_bus_effect(0, index)
		if effect is AudioEffectLimiter:
			limiter_count += 1
			check(effect.ceiling_db <= -1.0, "combined mix has headroom below clipping")
	check(limiter_count == 1, "master has one limiter even with isolated settings managers")
	audio.stop_effects()
	for repeat: int in 5:
		for key: String in ["ui_click", "ui_back", "ui_select", "ui_confirm", "ui_error"]: audio.play_event(StringName(key))
	check(audio.voices.size() <= 4, "UI voice ceiling")
	audio.stop_effects()
	for repeat: int in 4:
		for key: String in ["jump", "land", "dash", "evade", "respawn", "swing_light", "hit_light"]: audio.play_event(StringName(key))
	check(audio.voices.size() == 16, "combat burst fills bounded pool")
	audio.play_event(&"ultimate_hit")
	check(audio.voices.size() == 16, "priority replacement keeps global ceiling")
	var found := false
	for voice: Dictionary in audio.voices:
		if voice.key == "ultimate_hit": found = true
	check(found, "ultimate survives low priority burst")
	check(audio.duck_until > audio.elapsed, "important sound lowers music temporarily")
	audio.stop_effects()
	var original: Dictionary = audio.event_map.duplicate(true)
	# Keep one high priority sample alive per slot to exercise refusal, not same-key replacement.
	for index: int in 16:
		audio.event_map["priority_test_%d" % index] = {"asset": "fa.audio.ultimate_hit", "bus": "Combat", "priority": 95, "concurrency": 1}
		audio.play_event(StringName("priority_test_%d" % index))
	var before: int = audio.played_count
	audio.play_event(&"jump")
	check(audio.played_count == before and audio.voices.size() == 16, "low priority event cannot evict important sounds")
	audio.event_map = original
	audio.stop_effects()

func _test_music_and_lifecycle() -> void:
	audio.set_context("lobby")
	await create_timer(0.6).timeout
	var index: int = audio.music_index
	var player: AudioStreamPlayer = audio.music_players[index]
	var position := player.get_playback_position()
	audio.set_context("settings")
	await create_timer(0.05).timeout
	check(audio.music_index == index and player.get_playback_position() >= position, "same lobby music continues across menu")
	audio.set_context("match")
	check(audio.context == "battle" and audio.music_index != index, "battle switches music")
	audio.play_event(&"jump")
	audio.set_match_paused(true)
	check(audio.voices.is_empty(), "pause clears combat sounds")
	var before: int = audio.played_count
	audio.play_event(&"jump")
	audio.play_event(&"ui_click")
	check(audio.played_count == before + 1, "pause allows UI and suppresses combat")
	audio.set_suspended(true)
	check(audio.voices.is_empty(), "background clears all effects")
	for music: AudioStreamPlayer in audio.music_players: check(music.stream_paused, "background pauses music")
	audio.play_event(&"ui_click")
	check(audio.played_count == before + 1, "background cannot queue effects")
	audio.set_suspended(false)
	for music: AudioStreamPlayer in audio.music_players: check(not music.stream_paused, "foreground resumes existing music players")
	audio.set_match_paused(false)
	audio.finish_match("victory")
	before = audio.played_count
	audio.finish_match("victory")
	check(audio.played_count == before and audio.context == "battle", "result plays once while battle music remains")
	var deadline: float = audio.result_deadline
	check(deadline > audio.elapsed, "result schedules lobby after jingle duration")
	audio.set_context("result")
	check(audio.context == "battle" and audio.result_deadline == deadline, "result page does not override pending jingle")
	await create_timer(maxf(0.0, deadline - audio.elapsed) + 0.1).timeout
	check(audio.context == "lobby" and audio.result_deadline < 0.0, "jingle completion transitions to lobby")
	audio.begin_match()
	audio.finish_match("defeat")
	var remaining: float = audio.result_deadline - audio.elapsed
	audio.begin_match()
	check(audio.context == "battle" and audio.result_deadline < 0.0, "rematch cancels pending lobby transition")
	await create_timer(remaining + 0.1).timeout
	check(audio.context == "battle", "old result deadline cannot interrupt rematch music")

func _test_settings() -> void:
	var temporary_root := OS.get_environment("TMPDIR")
	if temporary_root.is_empty(): temporary_root = OS.get_environment("TEMP")
	if temporary_root.is_empty(): temporary_root = "/tmp"
	var path := temporary_root.path_join("audio-contract-%d.cfg" % Time.get_ticks_usec())
	var config := ConfigFile.new()
	config.set_value("audio", "music", "broken")
	config.set_value("audio", "effects", 3.0)
	config.set_value("audio", "muted", "true")
	check(config.save(path) == OK, "write isolated corrupt settings fixture")
	var isolated: Node = load("res://scripts/audio_director.gd").new()
	isolated.settings_path = path
	root.add_child(isolated)
	check(isolated.music_level == 0.6 and isolated.effects_level == 1.0 and not isolated.muted, "invalid settings fallback and clamp")
	check(isolated._valid_level(NAN, 0.8) == 0.8 and isolated._valid_level(INF, 0.6) == 0.6, "nonfinite levels sanitized")
	check(isolated.set_levels(0.25, 0.5, true) == OK, "settings saved")
	isolated.queue_free()
	await process_frame
	var restored: Node = load("res://scripts/audio_director.gd").new()
	restored.settings_path = path
	root.add_child(restored)
	check(restored.music_level == 0.25 and restored.effects_level == 0.5 and restored.muted, "device settings round trip")
	restored.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	audio.set_levels(0.6, 0.8, false, false)

func _test_shutdown_pool() -> void:
	audio.shutdown()
	await process_frame
	var baseline: int = audio.get_child_count()
	for repeat: int in 20:
		audio.begin_match()
		audio.play_event(&"hit_light")
		# Let one audio buffer begin before simulating scene teardown.
		await create_timer(0.04).timeout
		audio.shutdown()
		await process_frame
	await create_timer(0.2).timeout
	check(audio.get_child_count() == baseline and audio.voices.is_empty(), "repeated shutdown releases effect player nodes")
	for player: AudioStreamPlayer in audio.music_players:
		check(player.stream == null and not player.playing, "shutdown releases music playback and stream")
