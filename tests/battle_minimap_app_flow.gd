extends SceneTree

var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app := (load("res://scenes/local_ai_app.tscn") as PackedScene).instantiate()
	var path := "user://minimap-flow-%d.json" % Time.get_ticks_usec()
	app.save_path = path
	app.db_session_path = path + ".session"
	root.add_child(app)
	await process_frame
	check(app.store.grant_first("ja-hyun"), "first character")
	app._show_accessibility()
	await process_frame
	var field := app.page.find_child("NicknameInput", true, false) as LineEdit
	check(field != null, "nickname field exists")
	if field != null: field.text = "숲지기"
	for node: Node in app.body.find_children("*", "Button", true, false):
		if node.text == "닉네임 저장":
			node.pressed.emit()
			break
	await process_frame
	check(app.store.data.nickname == "숲지기", "nickname UI saves")
	var slider := app.body.find_child("MinimapTransparency", true, false) as HSlider
	check(slider != null, "transparency slider exists")
	if slider != null: slider.value = 55
	for node: Node in app.body.find_children("*", "Button", true, false):
		if node.text == "투명도 저장":
			node.pressed.emit()
			break
	await process_frame
	check(app.store.data.minimap.transparency == 55, "transparency UI saves")
	for node: Node in app.body.find_children("*", "OptionButton", true, false):
		if node.item_count == 2 and node.get_item_text(0) == "얼굴":
			node.select(1)
			node.item_selected.emit(1)
			break
	await process_frame
	check(app.store.data.minimap.marker_style == "dot", "marker UI saves")
	for node: Node in app.body.find_children("*", "CheckButton", true, false):
		if node.get_parent().get_child(0).text == "미니맵 이름 표시":
			node.button_pressed = false
			break
	await process_frame
	check(not app.store.data.minimap.show_names, "name toggle saves")
	var restored := LocalPlayerStore.new(app.catalog, path)
	check(restored.load_profile() and restored.data.nickname == "숲지기" and restored.data.minimap == app.store.data.minimap, "settings restored")
	for mode: LocalMatchConfig.Mode in [LocalMatchConfig.Mode.STORY, LocalMatchConfig.Mode.PRACTICE, LocalMatchConfig.Mode.AI, LocalMatchConfig.Mode.SOLO, LocalMatchConfig.Mode.TEAM]:
		app.selected_mode = mode
		app.solo_participant_count = 8
		app.team_size = 4
		app.start_match()
		await physics_frame
		var map := app.match_scene.get_node("Interface/BattleMinimap") as BattleMinimap
		check(map != null and map.is_visible_in_tree(), "mode %d has minimap" % mode)
		check(map.mouse_filter == Control.MOUSE_FILTER_IGNORE, "map passes touches")
		check(is_equal_approx(map.modulate.a, 0.45), "whole map transparency reaches match")
		var hash: String = app.match_controller.snapshot_hash()
		map.update_snapshot(app.match_controller.snapshot())
		check(app.match_controller.snapshot_hash() == hash, "map preserves combat snapshot")
		app.pause_match()
		check(not map.is_visible_in_tree(), "paused interface hides map")
		app.resume_match()
		check(map.is_visible_in_tree(), "resume shows map")
		app._close_match()
	app.queue_free()
	await process_frame
	for suffix: String in ["", ".bak", ".tmp", ".session"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	for failure: String in failures: push_error(failure)
	print("BATTLE_MINIMAP_APP_FLOW: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
