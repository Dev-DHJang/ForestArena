extends SceneTree
## Exercises native settings, exact geometry consumption and visualization independence.
var failures: Array[String] = []
var app
var capture := "--ui-capture" in OS.get_cmdline_user_args()
var output := "user://combat-debug-settings-%d" % OS.get_process_id()


func _initialize() -> void:
	var configured := OS.get_environment("FOREST_ARENA_VERIFY_OUTPUT")
	if not configured.is_empty(): output = configured.path_join("combat-debug-settings")
	call_deferred("run")


func check(value: bool, label: String) -> void:
	if not value: failures.append(label)


func settle() -> void:
	await process_frame
	await create_timer(0.24).timeout
	await process_frame


func control(id: String) -> Control:
	for item: Node in app.page.find_children("*", "Control", true, false):
		if String(item.get_meta("qa_id", "")) == id: return item as Control
	return null


func action(id: String, payload: Dictionary = {}) -> void:
	app.page.action.emit(id, payload)
	await settle()


func open_debug() -> void:
	app._show_premium_menu("settings", {"category": "debug"})
	await settle()


func save_frame(name: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "capture " + name)


func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var profile_dir := output.path_join("profile-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(profile_dir)
	app = load("res://scenes/local_ai_app.tscn").instantiate()
	app.save_path = profile_dir.path_join("player.json")
	app.db_session_path = profile_dir.path_join("db.json")
	app.demo_guest_session_path = profile_dir.path_join("demo.json")
	root.add_child(app)
	await settle()
	check(app.store.grant_first("ja-hyun"), "isolated profile granted")
	var original_profile := FileAccess.get_file_as_string(app.save_path)
	check(not app.debug_hitboxes_enabled, "fresh app debug starts disabled")
	await open_debug()
	var toggle := control("menu/settings/draft/show_combat_ranges") as CheckButton
	check(toggle != null and not toggle.button_pressed, "native debug checkbox defaults off")
	if toggle != null: toggle.button_pressed = true
	check(not app.debug_hitboxes_enabled, "draft checkbox does not apply immediately")
	await action("settings_cancel")
	check(not app.debug_hitboxes_enabled and not app.menu_router._draft.show_combat_ranges, "cancel restores draft without enabling")
	await action("draft", {"show_combat_ranges": true})
	await action("settings_apply")
	check(app.debug_hitboxes_enabled, "apply enables session debug")
	check(FileAccess.get_file_as_string(app.save_path) == original_profile, "debug does not write player profile")
	app.menu_router._reset_draft()
	check(not app.menu_router._draft.show_combat_ranges and app.debug_hitboxes_enabled, "default reset remains a draft until apply")
	await action("settings_apply")
	check(not app.debug_hitboxes_enabled, "applying defaults disables debug")
	await action("draft", {"show_combat_ranges": true})
	await action("settings_apply")
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 720)]:
		root.size = resolution
		if capture: DisplayServer.window_set_size(resolution)
		await open_debug()
		var category := control("menu/settings/category/debug")
		check(category != null, "debug category available at " + str(resolution))
		if category != null:
			var scroll := category.get_parent().get_parent() as ScrollContainer
			check(scroll.get_global_rect().encloses(category.get_global_rect()), "selected debug category is fully visible " + str(resolution))
		toggle = control("menu/settings/draft/show_combat_ranges") as CheckButton
		check(toggle != null and root.get_visible_rect().encloses(toggle.get_global_rect()), "debug checkbox fits " + str(resolution))
		await save_frame("settings-%d" % resolution.x)
	app.selected_mode = LocalMatchConfig.Mode.SOLO
	app.solo_participant_count = 4
	app.start_match()
	app.match_controller.set_physics_process(false)
	app.match_controller.bot_source = null
	app.match_controller.bot_sources.clear()
	await settle()
	var scene: Node2D = app.match_scene
	var controller: MatchController = app.match_controller
	var overlay: Node2D = scene.combat_debug_overlay
	check(scene.combat_debug_enabled and overlay.visible and scene.combat_debug_legend.visible, "new match inherits enabled session debug and legend")
	check(overlay.sample_geometry().size() == 4, "overlay includes late-added participants")
	var fighter := controller.player
	fighter.state = FighterController.State.ATTACK_ACTIVE
	fighter.active_attack = fighter.runtime_profile.move_set.attacks()[-1]
	fighter.attack_phase_tick = 5
	var geometry: Dictionary = fighter.get_debug_geometry()
	check(geometry.hitboxes.size() == 3, "Ja-Hyun pulse exposes every active attack area")
	var before: Dictionary = controller.snapshot().duplicate(true)
	var sampled: Array[Dictionary] = overlay.sample_geometry()
	check(sampled[0].geometry == geometry, "overlay consumes exact combat rectangles")
	check(before == controller.snapshot(), "sampling geometry does not mutate combat")
	var network_fighter: Dictionary = controller.network_snapshot().fighters[0]
	var remote_geometry := {"hurtbox": {"x": 100.0, "y": 200.0, "w": 30.0, "h": 40.0}, "hitboxes": [{"x": 90.0, "y": 210.0, "w": 80.0, "h": 10.0}]}
	network_fighter.debug_geometry = remote_geometry
	fighter.apply_network_snapshot(network_fighter)
	check(overlay.sample_geometry()[0].geometry == remote_geometry, "LAN consumes server rectangles without reconstructing reach or facing")
	var paths: Array = []
	for enabled: bool in [false, true]:
		controller.reset_match()
		# CharacterBody2D retains contact flags across teleport/reset. Establish the
		# same real floor contact before comparing the two identical input runs.
		for participant: FighterController in controller.call("_fighters"):
			participant.position.y = 572
			participant.velocity = Vector2(0, 1)
			participant.move_and_slide()
			participant.velocity = Vector2.ZERO
			check(participant.is_on_floor(), "determinism fixture establishes floor contact")
		scene.set_combat_debug_enabled(enabled)
		var frames: Array = []
		for tick: int in 65:
			if tick in [0, 5]: controller.submit_intent(CombatIntent.new(controller.tick + 1, fighter.fighter_id, &"attack_light", CombatIntent.Direction.RIGHT, CombatIntent.Edge.PRESS, CombatIntent.Context.GROUND))
			controller.step_fixed_tick(false)
			overlay.sample_geometry()
			frames.append(controller.snapshot().duplicate(true))
		paths.append(frames)
	check(paths[0] == paths[1], "debug on and off preserve identical fixed-tick results")
	app.set_debug_hitboxes_enabled(true)
	fighter.state = FighterController.State.ATTACK_ACTIVE
	fighter.active_attack = fighter.runtime_profile.move_set.attacks()[-1]
	fighter.attack_phase_tick = 5
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 720)]:
		root.size = resolution
		if capture: DisplayServer.window_set_size(resolution)
		await settle()
		check(root.get_visible_rect().encloses(scene.combat_debug_legend.get_global_rect()), "debug legend fits " + str(resolution))
		await save_frame("match-%d" % resolution.x)
	app.pause_match()
	app._show_premium_menu("controls", {"entry_context": "pause"})
	await settle()
	var debug_category := control("menu/controls/category/debug") as Button
	check(debug_category != null, "pause controls provide debug navigation")
	if debug_category != null: debug_category.pressed.emit()
	await settle()
	check(app.menu_router.state.category == "debug" and app.menu_router.state.entry_context == "pause", "debug route preserves pause return context")
	await action("draft", {"show_combat_ranges": false})
	await action("settings_apply")
	check(not scene.combat_debug_enabled and not overlay.visible, "pause settings update current match")
	var second_app = load("res://scripts/local_ai_app.gd").new()
	check(not second_app.debug_hitboxes_enabled, "new app instance does not restore previous session checkbox")
	second_app.free()
	app.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	print("COMBAT_DEBUG_SETTINGS: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
