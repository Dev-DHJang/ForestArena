extends Node
## 소리 표현만 담당한다. 전투 계산에서 이 노드를 참조하지 않는다.
const SETTINGS_PATH := "user://forest_arena_audio.cfg"
const MAX_VOICES := 16
const MAX_UI_VOICES := 4
var music_level := 0.6
var effects_level := 0.8
var muted := false
var suspended := false
var context := ""
var music_players: Array[AudioStreamPlayer] = []
var music_index := 0
var music_tween: Tween
var voices: Array[Dictionary] = []
var event_map: Dictionary = {}
var last_epoch := -1
var last_event_seq := 0
var duck_until := 0.0
var elapsed := 0.0
var paused_match := false
var played_count := 0
var result_played := false
var result_deadline := -1.0
var settings_path := SETTINGS_PATH

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: String in ["Music", "UI", "Combat"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")
	var has_limiter := false
	for index: int in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, index) is AudioEffectLimiter: has_limiter = true
	if not has_limiter:
		var limiter := AudioEffectLimiter.new()
		limiter.ceiling_db = -1.0
		limiter.threshold_db = -3.0
		AudioServer.add_bus_effect(0, limiter)
	event_map = JSON.parse_string(FileAccess.get_file_as_string("res://forest_arena/data/audio_events_v01.json"))
	for index: int in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		add_child(player)
		music_players.append(player)
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		music_level = _valid_level(config.get_value("audio", "music", 0.6), 0.6)
		effects_level = _valid_level(config.get_value("audio", "effects", 0.8), 0.8)
		var saved_mute: Variant = config.get_value("audio", "muted", false)
		muted = saved_mute if saved_mute is bool else false
	_apply_levels()

func _valid_level(value: Variant, fallback: float) -> float:
	if not (value is float or value is int) or not is_finite(float(value)): return fallback
	return clampf(float(value), 0.0, 1.0)

func set_levels(music: float, effects: float, silence: bool, save := true) -> Error:
	music_level = _valid_level(music, 0.6)
	effects_level = _valid_level(effects, 0.8)
	muted = silence
	_apply_levels()
	if muted: stop_effects()
	if not save: return OK
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_level)
	config.set_value("audio", "effects", effects_level)
	config.set_value("audio", "muted", muted)
	return config.save(settings_path)

func _apply_levels() -> void:
	for bus: String in ["Music", "UI", "Combat"]:
		var index := AudioServer.get_bus_index(bus)
		if index < 0: continue
		var level := music_level if bus == "Music" else effects_level
		if bus == "Music" and (elapsed < duck_until or paused_match): level *= 0.35
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))
		AudioServer.set_bus_mute(index, muted or level <= 0.0 or suspended)

func set_context(value: String) -> void:
	if value in ["result", "lan_result"] and result_deadline > elapsed: return
	result_deadline = -1.0
	paused_match = value == "pause"
	_apply_levels()
	var track := "battle" if value in ["match", "pause", "lan_match", "lan_leave_confirm"] else "lobby"
	if track == context: return
	context = track
	if music_players.is_empty(): return
	if music_tween != null: music_tween.kill()
	var old := music_players[music_index]
	music_index = 1 - music_index
	var next := music_players[music_index]
	next.stop()
	next.stream = ForestArenaResources.load_audio("fa.audio." + track)
	if next.stream == null: return
	next.volume_db = -60.0
	next.play()
	next.stream_paused = suspended
	music_tween = create_tween().set_parallel(true)
	music_tween.tween_property(old, "volume_db", -60.0, 0.5)
	music_tween.tween_property(next, "volume_db", 0.0, 0.5)
	music_tween.chain().tween_callback(old.stop)

func begin_match() -> void:
	result_deadline = -1.0
	last_epoch = -1
	last_event_seq = 0
	result_played = false
	stop_effects()
	set_context("match")
	play_event(&"match_start", {})

func finish_match(outcome: String) -> void:
	if result_played: return
	result_played = true
	paused_match = false
	stop_effects("Combat")
	play_event(StringName(outcome), {})
	var spec: Dictionary = event_map.get(outcome, {})
	var stream: AudioStream = ForestArenaResources.load_audio(String(spec.get("asset", ""))) if not spec.is_empty() else null
	result_deadline = elapsed + (stream.get_length() if stream != null else 0.0)
	set_context("result")

func play_event(event_id: StringName, payload: Dictionary = {}) -> void:
	# Sequence is checked even while muted so old packets cannot sound later.
	if payload.has("event_seq"):
		var epoch := int(payload.get("epoch", 0))
		var sequence := int(payload.event_seq)
		if epoch < last_epoch or (epoch == last_epoch and sequence <= last_event_seq): return
		last_epoch = epoch
		last_event_seq = sequence
	if suspended or muted: return
	var key := resolve_event(event_id, payload)
	if key.is_empty() or not event_map.has(key): return
	var spec: Dictionary = event_map[key]
	if paused_match and String(spec.bus) == "Combat": return
	if (String(spec.bus) == "UI" and effects_level <= 0.0) or (String(spec.bus) == "Combat" and effects_level <= 0.0): return
	_prune_voices()
	var priority := int(spec.priority)
	var bus := String(spec.bus)
	var same: Array[Dictionary] = []
	for voice: Dictionary in voices:
		if voice.key == key: same.append(voice)
	if same.size() >= int(spec.get("concurrency", 3)):
		_remove_voice(same[0])
	var bus_count := 0
	for voice: Dictionary in voices:
		if voice.bus == "UI": bus_count += 1
	if voices.size() >= MAX_VOICES or (bus == "UI" and bus_count >= MAX_UI_VOICES):
		var victim: Dictionary = {}
		for voice: Dictionary in voices:
			if bus == "UI" and bus_count >= MAX_UI_VOICES and voice.bus != "UI": continue
			if victim.is_empty() or voice.priority < victim.priority: victim = voice
		if victim.is_empty() or int(victim.priority) > priority: return
		_remove_voice(victim)
	var stream := ForestArenaResources.load_audio(String(spec.asset))
	if stream == null: return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = StringName(bus)
	player.volume_db = float(spec.get("gain_db", -4.0))
	add_child(player)
	voices.append({"player": player, "key": key, "priority": priority, "bus": bus})
	player.play()
	played_count += 1
	if priority >= 90:
		duck_until = elapsed + minf(stream.get_length(), 3.0)
		_apply_levels()

func resolve_event(event_id: StringName, payload: Dictionary) -> String:
	if event_id == &"hit_resolved":
		var result := String(payload.get("result", ""))
		if result in ["MISS", "IMMUNE", ""]: return ""
		if result in ["BLOCK", "PERFECT_GUARD"]: return "guard_hit"
		var action := String(payload.get("action_id", ""))
		if action == "ultimate": return "ultimate_hit"
		if action == "attack_special": return "special_hit"
		return "hit_heavy" if action == "attack_heavy" else "hit_light"
	if event_id == &"attack_started":
		var action := String(payload.get("action_id", ""))
		if action in ["attack_special", "ultimate"]:
			var character := String(payload.get("character_id", ""))
			var suffix := "ultimate" if action == "ultimate" else "special_" + String(payload.get("direction", "neutral"))
			var key := character + "_" + suffix
			return key if event_map.has(key) else ""
		return "swing_heavy" if action == "attack_heavy" else "swing_light"
	# Results are contextual: the app knows the local team and LAN slot.
	if event_id in [&"match_end", &"match_draw"]: return ""
	return String(event_id)

func _prune_voices() -> void:
	for voice: Dictionary in voices.duplicate():
		if not is_instance_valid(voice.player) or not voice.player.playing: _remove_voice(voice)

func _remove_voice(voice: Dictionary) -> void:
	if is_instance_valid(voice.player):
		voice.player.stop()
		voice.player.queue_free()
	voices.erase(voice)

func stop_effects(bus := "") -> void:
	for voice: Dictionary in voices.duplicate():
		if bus.is_empty() or voice.bus == bus: _remove_voice(voice)

func set_match_paused(value: bool) -> void:
	paused_match = value
	if value: stop_effects("Combat")
	_apply_levels()

func set_suspended(value: bool) -> void:
	suspended = value
	if value: stop_effects()
	for player: AudioStreamPlayer in music_players: player.stream_paused = value
	_apply_levels()

func _process(delta: float) -> void:
	if suspended: return
	elapsed += delta
	if result_deadline >= 0.0 and elapsed >= result_deadline: set_context("result")
	_prune_voices()
	_apply_levels()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]: set_suspended(true)
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]: set_suspended(false)

func shutdown() -> void:
	result_deadline = -1.0
	context = ""
	if music_tween != null:
		music_tween.kill()
		music_tween = null
	for voice: Dictionary in voices:
		if is_instance_valid(voice.player):
			voice.player.stop()
			voice.player.stream = null
			voice.player.queue_free()
	voices.clear()
	for player: AudioStreamPlayer in music_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func _exit_tree() -> void:
	shutdown()
	music_players.clear()
