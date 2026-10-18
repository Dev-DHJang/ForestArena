extends SceneTree

var app
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.3).timeout

func gesture(start: Vector2, finish: Vector2) -> void:
	# Native pan events exercise GUI bubbling on headless desktops, where the
	# engine intentionally disables touchscreen mouse dragging. ADB verifies
	# the corresponding real finger drag on Android.
	for step in range(1, 13):
		var pan := InputEventPanGesture.new()
		pan.position = start.lerp(finish, float(step) / 12.0)
		pan.delta = (start - finish) / 160.0
		Input.parse_input_event(pan)
		await process_frame
	await settle()

func run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/local_ai_app.tscn").instantiate()
	var directory := "user://menu-scroll-test-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	app.save_path = directory + "/profile.json"
	app.db_session_path = directory + "/db.json"
	app.demo_guest_session_path = directory + "/guest.json"
	root.add_child(app)
	await settle()
	check(app.store.grant_first("ja-hyun"), "isolated initial character")
	app._show_premium_menu("shop", {"category": "character"})
	await settle()
	var scroll: ScrollContainer
	for node in app.page.find_children("*", "ScrollContainer", true, false):
		if node.get_meta("qa_id", "") == "menu/shop/scroll": scroll = node
	check(scroll != null, "native shop scroll exists")
	if scroll != null:
		var before := scroll.scroll_vertical
		var area := scroll.get_global_rect()
		var start := area.position + area.size * Vector2(0.17, 0.72)
		await gesture(start, start - Vector2(0, 260))
		check(scroll.scroll_vertical > before, "pan gesture on card body scrolls the actual native list")
		check(not is_instance_valid(app.menu_router.view.modal), "scroll drag does not open purchase modal")
		check(app.store.data.characters == ["ja-hyun"], "drag does not purchase or alter ownership")
		print("observed native scroll: ", before, " -> ", scroll.scroll_vertical)
	app.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PREMIUM_MENU_TOUCH_SCROLL: PASS")
	quit(0 if failures.is_empty() else 1)
