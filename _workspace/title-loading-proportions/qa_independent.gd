extends SceneTree
# QA-TITLE-01: independent native-render/state checks; no production edits.
const OUT := "res://_workspace/title-loading-proportions/qa-captures"
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var title
var transition
var save_dir := "user://qa-title-independent-%d" % Time.get_ticks_usec()
var capture := "--qa-render" in OS.get_cmdline_user_args()

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"label": label, "pass": ok})
	if not ok: failures.append(label)
func touch(down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 3
	event.pressed = down
	event.position = Vector2(640, 550)
	title._input(event)
func frame(name: String) -> void:
	await process_frame
	await process_frame
	if capture:
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		check(not image.is_empty() and image.save_png(OUT + "/" + name + ".png") == OK, "native capture " + name)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.make_dir_recursive_absolute(save_dir)
	root.size = Vector2i(1280, 720)
	if capture:
		check(DisplayServer.get_name() != "headless", "native renderer required for images")
		DisplayServer.window_set_size(root.size)
	title = load("res://scenes/startup_title.tscn").instantiate()
	title.save_path = save_dir + "/profile.json"
	title.db_session_path = save_dir + "/db.json"
	title.demo_guest_session_path = save_dir + "/guest.json"
	root.add_child(title)
	touch(true)
	check(not title.entered, "loading touch cannot enter")
	await frame("startup-loading-16x9")
	var deadline := Time.get_ticks_msec() + 90000
	var previous := 0.0
	var decreases := 0
	while not title.ready_to_start and Time.get_ticks_msec() < deadline:
		if title.loading.visible:
			if title.loading.value + 0.0001 < previous: decreases += 1
			previous = title.loading.value
		await process_frame
	check(title.ready_to_start, "startup completes")
	check(decreases == 0, "startup progress never decreases (%d)" % decreases)
	check(not title.entered and title.start_prompt.visible and not title.loading.visible, "held touch does not enter after ready")
	check(title.app != null and not title.app.is_inside_tree(), "game detached before deliberate start")
	for width: int in [1280, 1600]:
		root.size = Vector2i(width, 720)
		if capture: DisplayServer.window_set_size(root.size)
		await frame("title-ready-%dx720" % width)
		for name: String in ["TitleLogo", "StartPrompt", "VersionCopyright"]:
			var label := title.get_node(name) as Label
			check(root.get_visible_rect().encloses(label.get_global_rect()), "label fits %s %d" % [name, width])
			check(label.size.x >= label.get_minimum_size().x, "text fits %s %d" % [name, width])
	touch(false)
	check(not title.entered, "touch release does not enter")
	touch(true)
	check(title.entered and title.app.is_inside_tree(), "fresh touch enters once")
	var app = title.app
	touch(false)
	await create_timer(0.35).timeout
	check(app.screen == "first", "new profile routes to first selection")
	check(app.db_client != null and not app.db_mode, "new local profile preserves storage path")
	transition = app.transitions
	check(transition != null, "production app enables transitions")
	var built := [0]
	transition.prepare_override = func(_paths: Array[String]) -> bool:
		await create_timer(0.35).timeout
		return true
	transition.navigate(func() -> void: built[0] += 1)
	check(transition.busy and not transition.panel.visible, "slow transition starts with hidden bar")
	await create_timer(0.20).timeout
	check(transition.panel.visible and transition.overlay.visible, "slow transition shows after 150ms")
	await frame("transition-loading-20x9")
	check(not await transition.navigate(func() -> void: built[0] += 10), "duplicate transition rejected")
	await create_timer(0.25).timeout
	check(not transition.busy and not transition.overlay.visible and built[0] == 1, "transition completes once and hides")
	transition.prepare_override = func(_paths: Array[String]) -> bool: return false
	await transition.navigate(func() -> void: built[0] += 100)
	check(transition.busy and transition.actions.visible and not transition.bar.visible, "failure retains retry and back")
	await frame("transition-error-20x9")
	transition.cancel()
	check(not transition.busy and not transition.overlay.visible, "cancel clears error blocker")
	var report := {"display_server":DisplayServer.get_name(), "rendered":capture, "checks":checks,"failures":failures,"physical_android":"not_run"}
	var file := FileAccess.open(OUT + "/independent-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("QA-TITLE-01 %d checks, %d failures" % [checks.size(),failures.size()])
	for failure: String in failures: push_error(failure)
	app.queue_free()
	title.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
