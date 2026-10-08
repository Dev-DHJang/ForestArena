extends SceneTree

var failures: Array[String] = []
var audio: Node

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func has_voice(key: String) -> bool:
	for voice: Dictionary in audio.voices:
		if voice.key == key: return true
	return false

func run() -> void:
	audio = root.get_node("ForestArenaAudio")
	audio.set_levels(0.6, 0.8, false, false)
	audio.set_suspended(false)
	var app: Node = (load("res://scenes/local_ai_app.tscn") as PackedScene).instantiate()
	var temporary_root := OS.get_environment("TMPDIR")
	if temporary_root.is_empty(): temporary_root = OS.get_environment("TEMP")
	if temporary_root.is_empty(): temporary_root = "/tmp"
	var path := temporary_root.path_join("audio-app-%d.json" % Time.get_ticks_usec())
	app.save_path = path
	app.db_session_path = "user://audio-app-no-db.json"
	root.add_child(app)
	await process_frame
	check(audio.context == "lobby", "first screen starts lobby music")
	var callback_state := {"clicked": false, "selected": -1, "toggled": false}
	var button: Button = app._button("오디오 테스트", func() -> void: callback_state.clicked = true)
	audio.stop_effects()
	button.pressed.emit()
	check(callback_state.clicked and has_voice("ui_click"), "button click sounds and still invokes callback")
	button = app._button("로비", func() -> void: callback_state.clicked = true)
	button.pressed.emit()
	check(has_voice("ui_back"), "back navigation sound")
	var labels: Array[String] = ["A", "B"]
	app._choice_labels("선택 테스트", labels, 0, func(index: int) -> void: callback_state.selected = index)
	var options: OptionButton = app.body.get_child(app.body.get_child_count() - 1).get_child(1)
	options.item_selected.emit(1)
	check(callback_state.selected == 1 and has_voice("ui_select"), "selection sound preserves callback")
	app._toggle("토글 테스트", false, func(value: bool) -> void: callback_state.toggled = value)
	var toggle: CheckButton = app.body.get_child(app.body.get_child_count() - 1).get_child(1)
	toggle.toggled.emit(true)
	check(callback_state.toggled and has_voice("ui_select"), "toggle sound preserves callback")
	check(app.store.grant_first("nabi"), "grant first character: " + app.store.error)
	app.store.data.accessibility.reduce_visual_effects = true
	app.start_match()
	await process_frame
	check(audio.context == "battle" and has_voice("match_start"), "real local match starts battle music and cue")
	app.match_controller.set_physics_process(false)
	var events: Array[Dictionary] = []
	app.match_controller.presentation_event.connect(func(event_id: StringName, payload: Dictionary) -> void:
		if event_id == &"attack_started": events.append(payload))
	var fighter: FighterController = app.match_controller.player
	fighter.runtime_state.ultimate_gauge = 0.0
	var intent := CombatIntent.new(1, fighter.fighter_id, &"ultimate", CombatIntent.Direction.NEUTRAL, CombatIntent.Edge.PRESS, CombatIntent.Context.GROUND)
	fighter.consume_intent(intent, app.match_controller.rules)
	check(events.is_empty(), "rejected empty gauge ultimate has no presentation event")
	fighter.runtime_state.ultimate_gauge = app.match_controller.rules.ultimate_gauge_max
	fighter.consume_intent(intent, app.match_controller.rules)
	check(events.size() == 1, "successful ultimate emits once")
	if not events.is_empty():
		check(events[0].character_id == "nabi" and events[0].has("epoch") and events[0].has("event_seq"), "actual fighter event carries character and network sequence")
		check(audio.resolve_event(&"attack_started", events[0]) == "nabi_ultimate", "actual attack event chooses character sound")
		check(has_voice("nabi_ultimate"), "successful attack reaches audio adapter")
	fighter.consume_intent(intent, app.match_controller.rules)
	check(events.size() == 1, "rejected active ultimate does not emit another sound")
	app._show_lan_match_controls()
	var battle_index: int = audio.music_index
	app._show_lan_leave_confirm()
	check(app.screen == "lan_leave_confirm" and audio.context == "battle" and audio.music_index == battle_index, "LAN leave confirmation keeps same battle music")
	var continue_button: Button = find_button(app.page, "계속 플레이")
	check(continue_button != null, "LAN leave confirmation offers cancel")
	if continue_button != null: continue_button.pressed.emit()
	check(app.screen == "lan_match" and audio.context == "battle" and audio.music_index == battle_index, "LAN leave cancel restores controls without restarting battle music")
	app._show_result(&"player")
	check(has_voice("victory") and audio.context == "battle", "local winner gets victory after match pause before lobby")
	var deadline: float = audio.result_deadline
	await create_timer(maxf(0.0, deadline - audio.elapsed) + 0.1).timeout
	check(audio.context == "lobby", "app result page waits for jingle before lobby music")
	app._close_match()
	await process_frame
	app.start_match()
	await process_frame
	app.match_controller.set_physics_process(false)
	app.match_controller.is_draw = true
	app._show_result(&"")
	check(has_voice("draw"), "local draw sound")
	app._close_match()
	await process_frame
	app.selected_mode = LocalMatchConfig.Mode.TEAM
	app.team_size = 2
	app.start_match()
	await process_frame
	app.match_controller.set_physics_process(false)
	app.match_controller.winner_team_id = app.match_controller.team_by_fighter_id[&"player"]
	app._show_result(&"ai-2")
	check(has_voice("victory"), "teammate winner uses local team victory")
	app._close_match()
	await process_frame
	app.lan_local_slot = 2
	for result: Dictionary in [{"winner_slot": 2, "reason": "combat"}, {"winner_slot": 1, "reason": "combat"}, {"winner_slot": 0, "reason": "draw"}]:
		audio.begin_match()
		app._on_lan_match_finished(result)
		var expected := "draw" if result.reason == "draw" else ("victory" if result.winner_slot == 2 else "defeat")
		check(has_voice(expected) and audio.context == "battle" and audio.result_deadline > audio.elapsed, "LAN contextual jingle precedes lobby: " + expected)
		audio.stop_effects()
	app._on_lan_match_finished({"winner_slot": 0, "reason": "room_closed"})
	check(audio.voices.is_empty(), "room close does not invent win or loss")
	app.queue_free()
	await process_frame
	for suffix: String in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	audio.stop_effects()
	var enabled_hash := await simulate(false)
	var muted_hash := await simulate(true)
	check(enabled_hash == muted_hash, "same combat input produces same state with audio enabled or muted")
	audio.set_levels(0.6, 0.8, false, false)
	audio.shutdown()
	await create_timer(0.2).timeout
	for failure: String in failures: push_error(failure)
	print("AUDIO_APP_FLOW: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func simulate(muted: bool) -> String:
	audio.set_levels(0.6, 0.8, muted, false)
	var scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var controller: MatchController = scene.get_node("MatchController")
	controller.set_physics_process(false)
	controller.reset_match()
	for intent: CombatIntent in [CombatIntent.new(1, &"ja-hyun", &"move", CombatIntent.Direction.RIGHT, CombatIntent.Edge.PRESS, CombatIntent.Context.GROUND), CombatIntent.new(8, &"ja-hyun", &"dash", CombatIntent.Direction.RIGHT, CombatIntent.Edge.PRESS, CombatIntent.Context.GROUND), CombatIntent.new(10, &"ja-hyun", &"attack_light", CombatIntent.Direction.RIGHT, CombatIntent.Edge.PRESS, CombatIntent.Context.GROUND)]:
		controller.submit_intent(intent)
	for index: int in 90: controller.step_fixed_tick(false)
	var result := controller.snapshot_hash()
	scene.queue_free()
	await process_frame
	return result

func find_button(node: Node, title: String) -> Button:
	if node is Button and node.text == title: return node
	for child: Node in node.get_children():
		var button := find_button(child, title)
		if button != null: return button
	return null
