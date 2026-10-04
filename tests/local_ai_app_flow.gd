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
	check(not quit_on_go_back, "app owns Android back requests")
	check(app.screen == "first", "first-time selection screen")
	var first_button := find_button(app, "나비")
	check(first_button != null, "first character button exists")
	if first_button != null: first_button.pressed.emit()
	await process_frame
	check(app.screen == "home" and app.store.owns("nabi"), "first character button grants and opens home")
	var shop_button := find_button(app, "상점 · 모두 0원")
	check(shop_button != null, "shop button exists")
	if shop_button != null: shop_button.pressed.emit()
	await process_frame
	for expected_purchase: int in app.catalog.products.size() - 1:
		var free_button := find_button(app, "0원 · 무료 구매")
		check(free_button != null, "free purchase button %d exists" % expected_purchase)
		if free_button == null: break
		free_button.pressed.emit()
		await process_frame
	check(app.store.data.characters.size() == 4 and app.store.data.accessories.size() == 6, "shop buttons purchase the full free catalog")
	check(find_button(app, "0원 · 무료 구매") == null, "owned products cannot be purchased again from UI")
	var lobby_button := find_button(app, "로비")
	check(lobby_button != null, "shop lobby button exists")
	if lobby_button != null: lobby_button.pressed.emit()
	await process_frame
	app._show_shop()
	app.handle_back_request(1000)
	check(app.screen == "home", "back from shop returns home")
	app.handle_back_request(1001)
	check(app.screen == "home", "duplicate Android back request cannot quit after navigation")
	app._show_prepare()
	app.handle_back_request(1500)
	check(app.screen == "home", "back from prepare returns home")
	var prepare_button := find_button(app, "대전 준비")
	check(prepare_button != null, "prepare button exists")
	if prepare_button != null: prepare_button.pressed.emit()
	await process_frame
	var character_button := find_button(app, "유란")
	check(character_button != null, "owned character selection button exists")
	if character_button != null: character_button.pressed.emit()
	await process_frame
	var choices := find_options(app)
	check(choices.size() == 2, "accessory and AI selectors exist")
	if choices.size() == 2:
		select_option(choices[0], "철갑옷")
		await process_frame
		choices = find_options(app)
		select_option(choices[1], "나비")
		await process_frame
	var start_button := find_button(app, "대전 시작")
	check(start_button != null, "start match button exists")
	if start_button != null: start_button.pressed.emit()
	await physics_frame
	check(app.screen == "match", "start button opens match")
	check(app.match_controller.player.runtime_profile.character_id == &"yu-ran", "UI-selected player reaches match")
	check(app.match_controller.player.runtime_profile.accessory_id == &"fixture-iron-armor", "UI-selected accessory reaches match")
	check(app.match_controller.training_dummy.runtime_profile.character_id == &"nabi", "UI-selected opponent reaches match")
	# Exercise the shipping path with real approved sprite bounds, not the fallback body box.
	app.match_controller.set_physics_process(false)
	var camera := app.match_scene.get_node("Camera2D") as Camera2D
	var indicator := app.match_scene.get_node("Interface/OffscreenOpponentIndicator") as OffscreenOpponentIndicator
	app.match_controller.player.global_position = Vector2(640, 520)
	app.match_controller.training_dummy.global_position = Vector2(1900, 520)
	camera.call("_process", 0.016)
	await process_frame
	var opponent_presentation = app.match_controller.training_dummy.get_node("Presentation")
	opponent_presentation.sync_visual(0.016)
	check(opponent_presentation.screen_bounds().has_area(), "approved opponent sprite exposes screen bounds")
	var camera_snapshot: String = app.match_controller.snapshot_hash()
	indicator.update_indicator()
	check(indicator.visible and indicator.arrow_direction.x > 0.0, "real offscreen opponent shows right arrow")
	check(app.match_controller.snapshot_hash() == camera_snapshot, "shipping camera and arrow preserve combat snapshot")
	app.match_controller.training_dummy.global_position = Vector2(1145, 520)
	await process_frame
	indicator.update_indicator()
	check(not indicator.visible, "partly visible approved sprite hides arrow")
	app._close_match()
	app._show_home()
	for own: CharacterData in app.catalog.combat.characters:
		for enemy: CharacterData in app.catalog.combat.characters:
			check(app.store.select(String(own.character_id), "", String(enemy.character_id)), "selection")
			app.start_match()
			await physics_frame
			check(app.match_controller.player.runtime_profile.character_id == own.character_id, "player profile")
			check(app.match_controller.training_dummy.runtime_profile.character_id == enemy.character_id, "opponent profile")
			check(app.match_controller.player.fighter_id != app.match_controller.training_dummy.fighter_id, "distinct participants including mirror matches")
			check(app.match_controller.bot_source != null, "AI connected")
	app.handle_back_request(2000)
	var tick: int = app.match_controller.tick
	await physics_frame
	check(app.screen == "pause" and app.match_controller.tick == tick, "back from match pauses")
	app.handle_back_request(2500)
	check(app.screen == "match" and not app.match_controller.paused, "back from pause resumes")
	app.start_match()
	check(app.match_controller.tick == 0 and app.match_controller.player.stocks == 3, "rematch reset")
	app.match_controller.match_ended.emit(&"opponent")
	app.start_match()
	await process_frame
	check(app.screen == "match" and not app.match_controller.paused, "old deferred result must not pause a new match")
	app.match_controller.is_draw = true
	app._show_result(&"")
	check(app.screen == "result", "draw result")
	app.handle_back_request(3000)
	check(app.screen == "prepare" and app.match_controller == null, "back from result returns prepare")
	app.start_match()
	app._show_result(&"player")
	check(app.screen == "result", "victory result")
	var replay_button := find_button(app, "같은 조건으로 재대전")
	check(replay_button != null, "result rematch button exists")
	if replay_button != null: replay_button.pressed.emit()
	await physics_frame
	check(app.screen == "match" and app.match_controller.tick <= 1 and app.match_controller.player.stocks == 3, "result rematch button starts a clean match")
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


func find_button(app: Node, text: String) -> Button:
	for child: Node in app.body.find_children("*", "Button", true, false):
		var button := child as Button
		if button.text == text and not button.disabled: return button
	return null


func find_options(app: Node) -> Array[OptionButton]:
	var result: Array[OptionButton] = []
	for child: Node in app.body.find_children("*", "OptionButton", true, false):
		result.append(child as OptionButton)
	return result


func select_option(option: OptionButton, text: String) -> void:
	for index: int in option.item_count:
		if option.get_item_text(index) == text:
			option.select(index)
			option.item_selected.emit(index)
			return
	check(false, "option exists: " + text)
