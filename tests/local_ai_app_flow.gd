extends SceneTree

var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app := (load("res://scenes/local_ai_app.tscn") as PackedScene).instantiate()
	var path := "user://test-flow-%d.json" % Time.get_ticks_usec()
	app.save_path = path
	root.add_child(app)
	await process_frame
	check(app.screen == "first", "first-time selection screen")
	check(app.store.grant_first("nabi"), "grant")
	for item: Dictionary in app.catalog.products:
		if not app.store.owns(item.id): check(app.store.purchase(item.id), "purchase")
	for own: CharacterData in app.catalog.combat.characters:
		for enemy: CharacterData in app.catalog.combat.characters:
			check(app.store.select(String(own.character_id), "", String(enemy.character_id)), "selection")
			app.start_match()
			await physics_frame
			check(app.match_controller.player.runtime_profile.character_id == own.character_id, "player profile")
			check(app.match_controller.training_dummy.runtime_profile.character_id == enemy.character_id, "opponent profile")
			check(app.match_controller.player.fighter_id != app.match_controller.training_dummy.fighter_id, "distinct participants including mirror matches")
			check(app.match_controller.bot_source != null, "AI connected")
	app.pause_match()
	var tick: int = app.match_controller.tick
	await physics_frame
	check(app.screen == "pause" and app.match_controller.tick == tick, "pause")
	app.start_match()
	check(app.match_controller.tick == 0 and app.match_controller.player.stocks == 3, "rematch reset")
	app.match_controller.is_draw = true
	app._show_result(&"")
	check(app.screen == "result", "draw result")
	app.start_match()
	app._show_result(&"player")
	check(app.screen == "result", "victory result")
	app.start_match()
	app._show_result(&"opponent")
	check(app.screen == "result", "defeat result")
	app._close_match()
	app._show_home()
	check(app.screen == "home", "return home")
	app.queue_free()
	await process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	for failure: String in failures: push_error(failure)
	print("LOCAL_AI_APP_FLOW: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
