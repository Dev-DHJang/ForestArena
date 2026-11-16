extends SceneTree

var app: Node
var checks: Array[Dictionary] = []
var measurements: Array[Dictionary] = []
var failures := 0
var fixture := "user://menu09-independent-qa-%d" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	await process_frame
	await create_timer(0.27).timeout
	await process_frame

func button(id: String) -> Button:
	for node: Node in app.page.find_children("*", "Button", true, false):
		if node.get_meta("qa_id", "") == id:
			return node as Button
	return null

func check(ok: bool, title: String) -> void:
	checks.append({"test": title, "pass": ok})
	if not ok:
		failures += 1
		printerr(title)

func press(id: String) -> void:
	var target := button(id)
	check(is_instance_valid(target) and not target.disabled, "control available: " + id)
	if is_instance_valid(target) and not target.disabled:
		target.pressed.emit()
	await settle()

func tap(point: Vector2) -> void:
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await settle()

func scan_cards(category: String, scale_value: float) -> void:
	app.store.data.accessibility.text_scale = scale_value
	app.menu_router.reset()
	app._show_premium_menu("shop", {"category": category, "filter": "전체", "scroll": 0})
	await settle()
	for node: Node in app.page.find_children("*", "Button", true, false):
		var card := node as Button
		var id := String(card.get_meta("qa_id", ""))
		if not id.begins_with("menu/shop/detail/"):
			continue
		var area := card.get_global_rect()
		for item: Node in card.find_children("*", "Label", true, false):
			var label := item as Label
			var label_rect := label.get_global_rect()
			var overflow := maxf(0.0, label_rect.end.y - area.end.y)
			measurements.append({"category": category, "scale": scale_value, "card": id, "text": label.text, "vertical_overflow_px": overflow})
			check(overflow <= 0.5, "card text fits %.2f %s %s (overflow %.2f)" % [scale_value, id, label.text, overflow])

func run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(fixture)
	root.get_node("ForestArenaAudio").settings_path = fixture.path_join("audio.cfg")
	app = load("res://scenes/local_ai_app.tscn").instantiate()
	app.save_path = fixture.path_join("profile.json")
	app.db_session_path = fixture.path_join("db-session.json")
	app.demo_guest_session_path = fixture.path_join("demo-session.json")
	root.add_child(app)
	await settle()
	check(app.store.grant_first("ja-hyun"), "isolated profile grants Ja-hyun")
	app._show_home()
	await settle()
	await scan_cards("character", 1.0)
	var card := button("menu/shop/detail/ja-hyun")
	if card != null:
		await tap(card.get_global_rect().position + Vector2(50, 34))
	check(app.menu_router.state.get("id") == "shop_detail" and app.menu_router.state.get("product_id") == "ja-hyun", "click on character art area opens exact detail")
	await press("menu/shop_detail/character/nabi")
	check(app.menu_router.state.get("product_id") == "nabi", "quick character switch changes exact product")
	await press("menu/shop_detail/back")
	check(app.menu_router.state.get("id") == "shop" and app.menu_router.state.get("category") == "character", "back returns to character list")
	await scan_cards("accessory", 1.0)
	await scan_cards("character", 1.3)
	await scan_cards("accessory", 1.3)
	app.menu_router.reset()
	app._show_premium_menu("accessory_collection", {"filter": "defense"})
	await settle()
	check(app.menu_router.state.get("selected_id") == "fixture-iron-armor", "defense detail selects iron armor")
	app._show_premium_menu("preset")
	await settle()
	await press("menu/preset/edit/accessory")
	check(app.menu_router.state.get("filter") in ["전체", "attack"], "preset chooser normalizes a remembered defense filter")
	check(button("menu/accessory_collection/accessory/pebble-yoyo") != null, "preset chooser keeps playable yo-yo in visible results")
	var path := OS.get_environment("MENU09_QA_REPORT")
	if not path.is_empty():
		var output := FileAccess.open(path, FileAccess.WRITE)
		output.store_string(JSON.stringify({"checks": checks, "failures": failures, "card_measurements": measurements}, "\t") + "\n")
	print("MENU09_INDEPENDENT_SHOP_PROBE %d checks, %d failures" % [checks.size(), failures])
	quit(0 if failures == 0 else 1)
