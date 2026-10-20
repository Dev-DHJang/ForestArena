extends SceneTree

var failures: Array[String] = []
var app
var capture := "--ui-capture" in OS.get_cmdline_user_args()
var folder := "res://build/android-current-fixes/ui-render"

func check(ok: bool, text: String) -> void:
	if not ok: failures.append(text)

func _initialize() -> void:
	call_deferred("run")

func frame(name: String) -> void:
	await process_frame
	await process_frame
	if capture:
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		check(not image.is_empty(), "actual rendered viewport " + name)
		image.save_png(folder + "/" + name + ".png")

func run() -> void:
	root.size = Vector2i(1280, 720)
	if capture:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		DirAccess.make_dir_recursive_absolute(folder)
	app = load("res://scenes/local_ai_app.tscn").instantiate()
	app.save_path = "user://forestlight-test-%d/profile.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(app.save_path.get_base_dir())
	app.db_session_path = app.save_path + ".session"
	app.demo_guest_session_path = app.save_path + ".demo-session"
	root.add_child(app)
	await frame("first")
	check(app.screen == "first", "first selection is real native page")
	for quality: String in ["high", "medium", "low"]:
		root.get_node("ForestArenaResources").set_quality(quality)
		check(root.get_node("ForestArenaResources").load_texture("fa.ui.forestlight.background.forest.v06") != null, "forestlight background loads at " + quality)
		check(root.get_node("ForestArenaResources").load_texture("fa.ui.forestlight.primary.default") != null, "button loads at " + quality)
	root.get_node("ForestArenaResources").set_quality("medium")
	app.store.grant_first("ja-hyun")
	for product: Dictionary in app.catalog.playable_products(): app.store.purchase(String(product.id))
	app._show_home()
	await frame("home")
	check(app.page.get_node("LobbyCanvas/LobbyCharacter").texture != null, "approved transparent lobby character visible")
	check(app.page.get_node("LobbyCanvas/LobbyNavigation").get_child_count() == 6, "six real lobby navigation buttons")
	for feature: String in ["프리셋", "미션", "친구"]:
		var button := find_button(feature)
		check(button != null, feature + " native button")
		button.pressed.emit()
		check(app.screen == {"프리셋": "preset", "미션": "mission", "친구": "social"}[feature], "native menu " + feature + " opens")
		app._show_home()
	app._show_prepare()
	await frame("prepare")
	check(app.page.find_children("*", "OptionButton", true, false).size() == 2, "mode and active AI choices retained without accessory selector")
	check(find_button("대전 시작") != null, "native battle start retained")
	app._show_shop()
	await frame("shop")
	app._show_accessibility()
	await frame("settings")
	var haptic_count: int = app.haptic_request_count
	app._on_presentation_event(&"hit_resolved", {"result": "MISS"})
	app._on_presentation_event(&"hit_resolved", {"result": "IMMUNE"})
	check(app.haptic_request_count == haptic_count, "miss/immune do not request haptics")
	app._on_presentation_event(&"hit_resolved", {"result": "HIT"})
	app._on_presentation_event(&"hit_resolved", {"result": "BLOCK"})
	check(app.haptic_request_count == haptic_count + 2, "valid hit/block request enabled feedback")
	app._show_lan_menu()
	await frame("lan-menu")
	app.selected_mode = LocalMatchConfig.Mode.PRACTICE
	app.start_match()
	await frame("battle")
	check(app.match_scene.get_node("Interface/TouchCommandSource").forestlight_controls, "real match enables approved touch skins")
	var status_hud: Control = app.match_scene.forestlight_hud
	var real_snapshot: Dictionary = app.match_controller.snapshot().duplicate(true)
	var replacement := real_snapshot.duplicate(true)
	replacement.fighters[0].id = "lan_host"
	replacement.fighters[0].current_hp = 42
	replacement.fighters[1].id = "lan_guest"
	replacement.fighters[1].current_hp = 71
	status_hud.update_snapshot(replacement)
	check(status_hud.cards.has("lan_host") and status_hud.cards.has("lan_guest"), "same participant count with new IDs rebuilds LAN cards")
	check(status_hud.cards["lan_host"].health.text.begins_with("HP 42/"), "new LAN ID reads current health")
	check(app.match_controller.snapshot() == real_snapshot, "ID replacement presentation leaves combat data untouched")
	status_hud.update_snapshot(real_snapshot)
	root.size = Vector2i(1600, 720)
	if capture: DisplayServer.window_set_size(Vector2i(1600, 720))
	await frame("battle-20x9")
	root.size = Vector2i(1280, 720)
	if capture: DisplayServer.window_set_size(Vector2i(1280, 720))
	app.match_controller.set_physics_process(false)
	var before: Array = app.match_controller.snapshot().fighters.duplicate(true)
	app._show_result(&"player")
	await frame("result")
	check(app.match_controller.snapshot().fighters == before, "result skin cannot change combat state")
	app._close_match()
	for mode: LocalMatchConfig.Mode in [LocalMatchConfig.Mode.SOLO, LocalMatchConfig.Mode.TEAM]:
		app.selected_mode = mode
		app.solo_participant_count = 8
		app.team_size = 4
		app.start_match()
		app.match_controller.set_physics_process(false)
		var hud: Control = app.match_scene.forestlight_hud
		check(hud.cards.size() == 8, "eight actual snapshot status cards")
		var original: Dictionary = app.match_controller.snapshot().duplicate(true)
		var observed := original.duplicate(true)
		observed.fighters[0].current_hp = 42
		observed.fighters[0].stocks = 1
		hud.update_snapshot(observed)
		var first_id: String = String(observed.fighters[0].id)
		check(hud.cards[first_id].health.text.begins_with("HP 42/"), "HUD reads supplied health")
		check(hud.cards[first_id].stocks.text == "기회 1", "HUD reads supplied remaining chances")
		check(app.match_controller.snapshot() == original, "HUD cannot mutate fighter snapshot")
		hud.update_snapshot(original)
		var camera := app.match_scene.get_node("Camera2D") as Camera2D
		camera.fixed_zoom = 0.5 # declared minimum, presentation-only inspection
		var label := "solo8" if mode == LocalMatchConfig.Mode.SOLO else "team4x4"
		for width: int in [1280, 1600]:
			root.size = Vector2i(width, 720)
			if capture: DisplayServer.window_set_size(Vector2i(width, 720))
			await frame(label + "-" + str(width))
			var map := app.match_scene.get_node("Interface/BattleMinimap") as Control
			for card: Dictionary in hud.cards.values():
				check(not card.panel.get_global_rect().intersects(map.get_global_rect()), "eight-card HUD leaves minimap clear " + label)
				check(card.panel.get_global_rect().end.y < 338, "HUD leaves touch actions clear " + label)
				check(card.stocks.size.x >= 70, "remaining chances visible " + label)
			if width == 1280 and mode == LocalMatchConfig.Mode.TEAM:
				var large: Dictionary = app.store.data.accessibility.duplicate(true)
				large.text_scale = 1.3
				app.match_scene.apply_accessibility(large)
				await frame("team4x4-large-text")
				for card: Dictionary in hud.cards.values():
					check(card.panel.get_global_rect().end.y < 338, "large text leaves action controls clear")
				app.match_scene.apply_accessibility(app.store.data.accessibility)
		app._close_match()
	app._show_home()
	root.size = Vector2i(1600, 720)
	if capture: DisplayServer.window_set_size(Vector2i(1600, 720))
	await frame("home-20x9")
	for node: Node in app.page.find_children("*", "Button", true, false):
		var button := node as Button
		if button.is_visible_in_tree(): check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(button.get_global_rect()), "visible home button fits 20:9 " + button.text)
	var path: String = app.save_path
	app.queue_free()
	await process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	for failure: String in failures: push_error(failure)
	print("FORESTLIGHT_RUNTIME: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func find_button(text: String) -> Button:
	for node: Node in app.page.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == text: return button
	return null
