extends SceneTree

const CHARACTERS := ["ja-hyun", "myo-ryung", "nabi", "yu-ran"]
const FIELDS := ["체력", "지상 이동", "공중 이동", "점프", "무게"]
var app: Node
var checks: Array[Dictionary] = []
var measurements: Array[Dictionary] = []
var failures := 0
var fixture := "user://menu09-stats-independent-qa-%d" % OS.get_process_id()
var output_dir := OS.get_environment("MENU09_QA_OUTPUT")

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	await process_frame
	await create_timer(0.25).timeout
	await process_frame

func check(condition: bool, title: String) -> void:
	checks.append({"test": title, "pass": condition})
	if not condition:
		failures += 1
		printerr(title)

func press(id: String) -> void:
	for node: Node in app.page.find_children("*", "Button", true, false):
		var button := node as Button
		if button.get_meta("qa_id", "") == id and not button.disabled:
			button.pressed.emit()
			await settle()
			return
	check(false, "control is available: " + id)

func scroll_for(label: Label) -> ScrollContainer:
	var parent := label.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			return parent as ScrollContainer
		parent = parent.get_parent()
	return null

func usable_scroll_rect(scroll: ScrollContainer) -> Rect2:
	if scroll == null:
		return root.get_visible_rect()
	var area := scroll.get_global_rect()
	var vbar := scroll.get_v_scroll_bar()
	if vbar.is_visible_in_tree():
		area.end.x = minf(area.end.x, vbar.get_global_rect().position.x)
	return area

func inspect_stats(route: String, id: String, text_scale: float) -> void:
	var stats: CharacterStats = app.catalog.combat.character_by_id(StringName(id)).base_stats
	var expected := [str(roundi(stats.max_hp)), str(roundi(stats.ground_speed)), str(roundi(stats.air_speed)), str(roundi(stats.jump_velocity)), "%.2f" % stats.weight]
	var start := measurements.size()
	for node: Node in app.page.find_children("*", "Label", true, false):
		var title := node as Label
		var field := FIELDS.find(title.text)
		if field < 0 or not title.get_parent() is HBoxContainer:
			continue
		var siblings := title.get_parent().get_children()
		if siblings.size() != 2 or not siblings[1] is Label:
			continue
		var value := siblings[1] as Label
		var prefix := "%s/%s/%.1f/%s" % [route, id, text_scale, title.text]
		var area := value.get_global_rect()
		var title_area := title.get_global_rect()
		var scroll := scroll_for(value)
		var panel := usable_scroll_rect(scroll)
		var required_width := value.get_theme_font("font").get_string_size(value.text, HORIZONTAL_ALIGNMENT_LEFT, -1, value.get_theme_font_size("font_size")).x
		var initial_bottom_gap := panel.end.y - area.end.y
		var needed_scroll := initial_bottom_gap < -0.5
		check(value.text == expected[field], prefix + " exact formatted value")
		check(value.get_line_count() == 1 and value.autowrap_mode == TextServer.AUTOWRAP_OFF, prefix + " value uses one line")
		check(area.size.x >= required_width and area.size.x >= 88 and value.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, prefix + " digits and decimal fit right-aligned value")
		check(not title_area.intersects(area) and panel.position.x <= title_area.position.x + 0.5 and panel.end.x >= area.end.x - 0.5, prefix + " no horizontal overlap or clipping")
		if needed_scroll and text_scale > 1.0 and scroll != null:
			scroll.ensure_control_visible(value)
			await process_frame
			await process_frame
		check(panel.grow(0.5).encloses(value.get_global_rect()) and panel.grow(0.5).encloses(title.get_global_rect()), prefix + " whole row is readable at default size or after scrolling at 1.3")
		measurements.append({"route": route, "character": id, "text_scale": text_scale, "field": title.text, "value": value.text, "lines": value.get_line_count(), "value_width": area.size.x, "rendered_text_width": required_width, "gap_after_title": area.position.x - title_area.end.x, "gap_before_scroll_edge": panel.end.x - area.end.x, "initial_bottom_gap": initial_bottom_gap, "needed_scroll": needed_scroll, "gap_after_scrolling": panel.end.y - value.get_global_rect().end.y})
		if needed_scroll and scroll != null:
			scroll.scroll_vertical = 0
			await process_frame
			await process_frame
	check(measurements.size() - start == 5, "%s/%s/%.1f all five rows are present" % [route, id, text_scale])

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	check(screenshot.get_size() == Vector2i(1280, 720) and screenshot.save_png(output_dir.path_join(name + ".png")) == OK, "rendered 1280x720: " + name)

func capture_scrolled(name: String) -> void:
	for node: Node in app.page.find_children("*", "Label", true, false):
		var label := node as Label
		if label.text != "무게" or not label.get_parent() is HBoxContainer:
			continue
		var scroll := scroll_for(label)
		if scroll == null:
			continue
		scroll.ensure_control_visible(label)
		await process_frame
		await capture(name)
		scroll.scroll_vertical = 0
		await process_frame
		return
	check(false, "could not find stats scroll: " + name)

func erase_fixture(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for child: String in directory.get_directories():
		erase_fixture(path.path_join(child))
	for file: String in directory.get_files():
		directory.remove(file)
	DirAccess.remove_absolute(path)

func run() -> void:
	root.size = Vector2i(1280, 720)
	check(DisplayServer.get_name() != "headless", "native window renders the probe")
	DirAccess.make_dir_recursive_absolute(fixture)
	var audio := root.get_node("ForestArenaAudio")
	var original_audio_path: String = audio.settings_path
	audio.settings_path = fixture.path_join("audio.cfg")
	app = load("res://scenes/local_ai_app.tscn").instantiate()
	app.save_path = fixture.path_join("profile.json")
	app.db_session_path = fixture.path_join("db-session.json")
	app.demo_guest_session_path = fixture.path_join("demo-session.json")
	root.add_child(app)
	await settle()
	check(app.store.grant_first("ja-hyun"), "isolated fixture grants Ja-hyun")
	app._show_home()
	await settle()
	for text_scale: float in [1.0, 1.3]:
		app.store.data.accessibility.text_scale = text_scale
		app.menu_router.reset()
		app._show_premium_menu("shop", {"category": "character"})
		await settle()
		await press("menu/shop/detail/ja-hyun")
		for id: String in CHARACTERS:
			if id != "ja-hyun":
				await press("menu/shop_detail/character/" + id)
			check(app.menu_router.state.get("id") == "shop_detail" and app.menu_router.state.get("product_id") == id, "shop displays " + id)
			await inspect_stats("shop_detail", id, text_scale)
			if id in ["ja-hyun", "myo-ryung"]:
				await capture("shop-stats-%s-%d" % [id, roundi(text_scale * 100)])
				if text_scale > 1.0:
					await capture_scrolled("shop-stats-%s-130-scrolled" % id)
		app.menu_router.reset()
		app._show_premium_menu("character_collection", {"selected_id": "ja-hyun"})
		await settle()
		for id: String in CHARACTERS:
			if id != "ja-hyun":
				await press("menu/character_collection/%s/%s" % ["character" if app.catalog.is_playable_character(StringName(id)) else "preview", id])
			check(app.menu_router.state.get("id") == "character_collection" and app.menu_router.state.get("selected_id") == id, "character stats display " + id)
			await inspect_stats("character_stats", id, text_scale)
			if id in ["ja-hyun", "myo-ryung"]:
				await capture("character-stats-%s-%d" % [id, roundi(text_scale * 100)])
				if text_scale > 1.0:
					await capture_scrolled("character-stats-%s-130-scrolled" % id)
	var output := FileAccess.open(output_dir.path_join("stats-report.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"display": DisplayServer.get_name(), "viewport": [1280, 720], "checks": checks, "failures": failures, "measurements": measurements}, "\t") + "\n")
	app.queue_free()
	await process_frame
	await process_frame
	audio.settings_path = original_audio_path
	erase_fixture(fixture)
	print("MENU09_INDEPENDENT_STATS_PROBE %d checks, %d failures" % [checks.size(), failures])
	quit(0 if failures == 0 else 1)
