extends SceneTree

var TITLE
var TRANSITION
var failures: Array[String] = []
var checks := 0
var builds := 0
var deadline_msec := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func until(predicate: Callable, label: String) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while not predicate.call() and Time.get_ticks_msec() < deadline: await process_frame
	check(predicate.call(), label)

func title_for(path: String) -> Control:
	var title: Control = TITLE.instantiate()
	title.save_path = path
	title.db_session_path = path + ".db"
	title.demo_guest_session_path = path + ".demo"
	return title

func touch(title: Control, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = pressed
	event.position = Vector2(640, 560)
	title._input(event)

func _process(_delta: float) -> bool:
	if deadline_msec > 0 and Time.get_ticks_msec() > deadline_msec:
		push_error("Title loading test deadline exceeded")
		quit(1)
	return false

func run() -> void:
	deadline_msec = Time.get_ticks_msec() + 45000
	TITLE = load("res://scenes/startup_title.tscn")
	TRANSITION = load("res://scripts/screen_transition.gd")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/startup_title.tscn", "project launches lightweight title")
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	check(version == "0.0.1", "project title version")
	var presets := ConfigFile.new()
	check(presets.load("res://export_presets.cfg") == OK, "export config readable")
	for section: String in presets.get_sections():
		if presets.has_section_key(section, "version/name"):
			var features: String = presets.get_value(section.trim_suffix(".options"), "custom_features", "")
			var expected: String = ProjectSettings.get_setting("application/config/version.demo", version) if "demo" in features.split(",") else version
			check(presets.get_value(section, "version/name") == expected, "APK version matches title: " + section)
	var path := "user://test-title-%d/profile.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var title := title_for(path)
	root.add_child(title)
	check(not title.ready_to_start and title.loading.visible and not title.start_prompt.visible, "startup initially loads")
	touch(title, true)
	check(not title.entered, "loading touch cannot enter")
	await until(func() -> bool: return title.ready_to_start, "real title resource preparation completes")
	check(title.background.texture != null, "registered title background loaded")
	check(title.loading.value == 1.0 and not title.loading.visible and title.start_prompt.visible, "ready swaps bar for prompt")
	check(title.version_label.text.contains("v0.0.1") and title.version_label.text.contains("© 2026 Forest Arena. All rights reserved."), "native version and copyright")
	check(title.app != null and not title.app.is_inside_tree() and title.app.db_client == null and title.app.menu_service == null, "title keeps network clients inactive")
	touch(title, true)
	check(not title.entered, "held loading touch cannot enter after ready")
	touch(title, false)
	touch(title, true)
	var app: Node = title.app
	await until(func() -> bool: return app.screen == "first" and not app.transitions.busy, "fresh touch routes new user to first")
	title.enter_game()
	check(app == title.app and not title.visible, "duplicate entry creates only one app")
	check(app.store.grant_first("ja-hyun"), "first character fixture grants")
	app._show_home()
	await until(func() -> bool: return app.screen == "home" and not app.transitions.busy, "home navigation completes")
	app.start_match()
	check(app.match_scene == null, "match does not instantiate before motion preparation")
	await until(func() -> bool: return app.screen == "match" and not app.transitions.busy, "prepared match opens")
	for motion_path: String in app._local_motion_paths():
		check(app.transitions.preparer.retained.get(motion_path) is SpriteFrames, "selected motion strongly retained: " + motion_path.get_file())
	check(app.match_scene.process_mode == Node.PROCESS_MODE_INHERIT, "combat processing resumes only after ready")
	app._close_match()
	app._show_home()
	await until(func() -> bool: return not app.transitions.busy, "home before system completions")
	app.transitions.prepare_override = func(_paths: Array[String]) -> bool:
		await create_timer(0.2).timeout
		return true
	app._show_db_connection()
	check(app.transitions.busy, "DB completion fixture starts during navigation")
	app._finish_db_connection(true, app.store)
	await until(func() -> bool: return app.screen == "home" and not app.transitions.busy, "DB completion waits then opens home")
	app.db_mode = false
	app._show_premium_menu("social")
	app._on_lan_room_ready({"1": {"schema_version": 1, "character_id": "ja-hyun", "job_id": "", "accessory_id": ""}, "2": {"schema_version": 1, "character_id": "ja-hyun", "job_id": "", "accessory_id": ""}}, 1)
	check(app.match_scene == null, "LAN completion waits for existing page navigation")
	await until(func() -> bool: return app.screen == "lan_match" and not app.transitions.busy, "room_ready during menu load still starts LAN match")
	check(app.match_controller != null and app.match_controller.paused, "LAN match waits for server snapshots")
	app._close_match()
	app.transitions.prepare_override = Callable()
	app.queue_free()
	title.queue_free()
	await process_frame
	# Existing profile starts at home through the real entry scene.
	var existing := title_for(path)
	root.add_child(existing)
	await until(func() -> bool: return existing.ready_to_start, "existing title ready")
	existing.enter_game()
	await until(func() -> bool: return existing.app.screen == "home" and not existing.app.transitions.busy, "existing user routes home")
	existing.app.queue_free()
	existing.queue_free()
	await process_frame
	# A failed resource never advertises readiness; explicit retry re-runs prep.
	var broken := title_for(path)
	broken.required_paths.assign(["res://missing-title-resource.png"])
	root.add_child(broken)
	await until(func() -> bool: return broken.retry.visible, "startup missing file offers retry")
	check(not broken.ready_to_start and not broken.start_prompt.visible, "failed startup cannot enter")
	broken.required_paths.clear()
	broken.retry.pressed.emit()
	await until(func() -> bool: return broken.ready_to_start, "startup retry recovers")
	broken.queue_free()
	await process_frame
	var navigation: CanvasLayer = TRANSITION.new()
	root.add_child(navigation)
	await navigation.navigate(func() -> void: builds += 1)
	check(builds == 1 and not navigation.overlay.visible, "fast navigation leaves no loading flash")
	navigation.prepare_override = func(_paths: Array[String]) -> bool:
		await create_timer(0.25).timeout
		return true
	navigation.navigate(func() -> void: builds += 1)
	check(navigation.busy and not navigation.panel.visible, "slow navigation blocks input before bar delay")
	var duplicate: bool = await navigation.navigate(func() -> void: builds += 100)
	check(not duplicate, "duplicate navigation rejected")
	await create_timer(0.18).timeout
	check(navigation.panel.visible and navigation.overlay.modulate.a == 1.0, "slow navigation displays centered loading bar")
	await until(func() -> bool: return not navigation.busy, "slow navigation completes")
	check(builds == 2 and not navigation.overlay.visible, "completion removes loading overlay")
	navigation.navigate(func() -> void: builds += 100)
	navigation.cancel()
	await create_timer(0.3).timeout
	check(builds == 2 and not navigation.overlay.visible, "cancelled completion cannot build stale screen")
	navigation.prepare_override = Callable()
	var missing_paths: Array[String] = ["res://missing-navigation-file.png"]
	await navigation.navigate(func() -> void: builds += 100, missing_paths, func() -> void: pass)
	check(navigation.actions.visible and not navigation.bar.visible and builds == 2, "load failure keeps previous page and shows retry/back")
	(navigation.actions.get_child(1) as Button).pressed.emit()
	check(not navigation.busy and not navigation.overlay.visible, "failure back restores previous page")
	navigation.prepare_override = func(_paths: Array[String]) -> bool:
		await create_timer(0.05).timeout
		return false
	await navigation.navigate(func() -> void: builds += 1)
	navigation.prepare_override = func(_paths: Array[String]) -> bool: return true
	(navigation.actions.get_child(0) as Button).pressed.emit()
	await until(func() -> bool: return not navigation.busy, "failed transition retries original destination")
	check(builds == 3, "retry builds destination once")
	navigation.prepare_override = func(_paths: Array[String]) -> bool:
		await create_timer(0.1).timeout
		return true
	navigation.navigate(func() -> void: builds += 100)
	navigation.queue_free()
	await create_timer(0.15).timeout
	check(builds == 3, "shutdown during load never invokes destination")
	for failure: String in failures: push_error(failure)
	print("TITLE_LOADING_FLOW: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
