extends SceneTree
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var app: Node = load("res://scripts/local_ai_app.gd").new()
	var normal: String = app.save_path
	var rejected := AndroidQaSession.new()
	check(not rejected.configure(app, PackedStringArray(["--qa-run=release"]), false), "release must reject QA")
	check(app.save_path == normal and not rejected.active, "rejected release preserves paths")
	check(not rejected.configure(app, PackedStringArray(["--qa-run=../escape"]), true), "reject traversal")
	check(not rejected.configure(app, PackedStringArray(["--qa-run=one", "--qa-run=two"]), true), "reject duplicate flags")
	check(not rejected.configure(app, PackedStringArray(), true), "normal launch has no QA")
	rejected.free()
	var qa := AndroidQaSession.new()
	var run_id := "unit-" + str(Time.get_ticks_usec())
	check(qa.configure(app, PackedStringArray(["--qa-run=" + run_id, "--qa-device=unit"]), true), "enable explicit QA")
	check(app.save_path.begins_with("user://qa/" + run_id + "/"), "isolate inventory")
	check(app.db_session_path.begins_with(qa.directory) and app.demo_guest_session_path.begins_with(qa.directory), "isolate both session stores")
	root.add_child(app)
	app.qa_session = qa
	app.add_child(qa)
	await process_frame
	check(app.screen == "first", "fresh isolated first selection")
	check(app.store.grant_first("ja-hyun"), "ordinary first grant")
	for item: Dictionary in app.catalog.products:
		if not app.store.owns(item.id): check(app.store.purchase(item.id), "normal purchase " + String(item.id))
	app._show_prepare()
	await process_frame
	var ui: Array = qa._ui()
	check(ui.any(func(value: Dictionary) -> bool: return value.id == "prepare/choice/장신구"), "stable selection IDs")
	mail(qa, 1, "select_config", {"character": "nabi", "accessory": "fixture-iron-armor", "mode": 3})
	check(qa.command_seq == 1 and qa.command_error.is_empty() and app.store.data.selected_character == "nabi", "normal config selects owned values")
	mail(qa, 1, "select_config", {"character": "yu-ran"})
	check(app.store.data.selected_character == "nabi", "replayed seq ignored")
	mail(qa, 2, "select_config", {"mode": 9})
	check(qa.command_error == "invalid_config" and app.selected_mode == 3, "bad mode fails without config mutation")
	app.start_match()
	await process_frame
	qa._observe_match()
	check(qa.match_generation == 1 and qa.snapshot.fighters.size() == 2, "observe real match")
	check(qa.snapshot.fighters[0].character_id == "nabi" and qa.snapshot.fighters[0].accessory_id == "fixture-iron-armor", "selected resource reaches fighter")
	mail(qa, 3, "autoplay", {"enabled": true, "ultimate": false})
	check(qa._bot != null and not qa._bot.allow_ultimate and app.match_controller.bot_sources.has(qa._bot), "QA bot uses normal controller source")
	check(Engine.time_scale == 1 and Engine.physics_ticks_per_second == 60, "real time unchanged")
	qa._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not qa.foreground and qa._bot == null and qa.input_reset_count == 1, "background clears bot and input")
	qa._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(qa.foreground and qa._bot != null, "foreground creates fresh bot")
	mail(qa, 4, "autoplay", {"enabled": false})
	check(qa._bot == null and app.match_controller.bot_sources.is_empty(), "real touch phase disables QA source")
	var touch: Control = app.match_scene.get_node("Interface/TouchCommandSource")
	var jump_visual: Control = touch._action_visuals[&"jump"]
	var event := InputEventScreenTouch.new()
	event.index = 4
	event.position = jump_visual.get_global_rect().get_center()
	event.pressed = true
	touch.handle_pointer_event(event)
	event.pressed = false
	touch.handle_pointer_event(event)
	check(qa.touch_events.size() == 2 and qa.touch_events[0].action == "jump" and qa.touch_events[1].edge == "release", "touch source diagnostics preserve press release")
	mail(qa, 5, "interrupt", {"seconds": 10})
	check(qa.command_error == "invalid_interrupt", "offline cannot interrupt LAN")
	qa._publish()
	var state: Variant = JSON.parse_string(FileAccess.get_file_as_string(qa.directory + "/state.json"))
	check(state is Dictionary and state.schema_version == 1 and state.command_seq == 5 and state.run_id == run_id, "versioned atomic state")
	check(not JSON.stringify(state).contains("access_token") and not JSON.stringify(state).contains("reconnect_token"), "no private tokens in diagnostics")
	var saved_path: String = app.save_path
	app._close_match()
	app.remove_child(qa)
	qa.free()
	app.queue_free()
	await process_frame
	var reopened: Node = load("res://scripts/local_ai_app.gd").new()
	var reopened_qa := AndroidQaSession.new()
	check(reopened_qa.configure(reopened, PackedStringArray(["--qa-run=" + run_id]), true), "reopen run")
	check(reopened_qa.command_seq == 5, "cold start does not replay prior command")
	root.add_child(reopened)
	check(reopened.store.data.selected_character == "nabi" and reopened.screen == "home", "normal saved profile survives restart")
	reopened_qa.free()
	reopened.queue_free()
	await process_frame
	var folder := DirAccess.open("user://qa/" + run_id)
	for file: String in folder.get_files(): folder.remove(file)
	DirAccess.remove_absolute("user://qa/" + run_id)
	await create_timer(0.25).timeout
	if failures.is_empty(): print("ANDROID_QA_SESSION: PASS"); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)
func mail(qa: AndroidQaSession, seq: int, op: String, args: Dictionary) -> void:
	var file := FileAccess.open(qa.directory + "/command.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 1, "run_id": qa.run_id, "seq": seq, "case_id": "UNIT", "op": op, "args": args}))
	file.close()
	qa._read_command()
