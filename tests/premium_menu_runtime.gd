extends SceneTree

# Independent contract checks exercise the native controls that ship in the app.
# --ui-capture writes the real rendered viewport; never run it with --headless.
const OUTPUT := "res://_workspace/premium-menu-v07-runtime/qa-captures"
const MENUS := {
	"character_collection": "SCR_04_CharacterCollection", "character_detail": "SCR_05_CharacterDetail",
	"accessory_collection": "SCR_06_AccessoryCollection", "accessory_detail": "SCR_07_AccessoryDetail",
	"preset": "SCR_08_Preset", "shop": "SCR_19_Shop", "collection": "SCR_20_Collection",
	"mission": "SCR_21_Mission", "social": "SCR_22_Social", "rank": "SCR_23_Rank",
	"profile": "SCR_24_Profile", "settings": "EXT_06_GeneralSettings", "controls": "CBT_08_Settings",
}
var failures: Array[String] = []
var checks: Array[Dictionary] = []
var layouts: Array[Dictionary] = []
var state_coverage: Array[Dictionary] = []
var app
var audio: Node
var capture := "--ui-capture" in OS.get_cmdline_user_args()
var qa_dir := "user://premium-menu-qa-%d" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks.append({"label": label, "pass": ok})
	if not ok: failures.append(label)

func settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.24).timeout
	await process_frame

func control(id: String) -> Control:
	for item: Node in app.page.find_children("*", "Control", true, false):
		if String(item.get_meta("qa_id", "")) == id: return item as Control
	return null

func set_slider(id: String, value: float) -> void:
	var slider := control(id) as HSlider
	check(slider != null, "native slider exists: " + id)
	if slider != null:
		slider.value = value
		await settle()

func button(id: String) -> Button:
	for item: Node in app.page.find_children("*", "Button", true, false):
		if String(item.get_meta("qa_id", "")) == id: return item as Button
	return null

func press(id: String) -> void:
	var target := button(id)
	check(target != null, "native control exists: " + id)
	if target == null: return
	check(not target.disabled and target.is_visible_in_tree(), "native control available: " + id)
	if target.disabled or not target.is_visible_in_tree(): return
	target.pressed.emit()
	await settle()

func open_menu(id: String, params: Dictionary = {}) -> void:
	app._show_premium_menu(id, params)
	await settle()
	check(String(app.menu_router.state.get("id", "")) == id, "route is " + id)
	check(String(app.page.get_meta("menu_screen_id", "")) == MENUS[id], "official design ID: " + id)
	check(app.page.find_children("*", "Button", true, false).size() > 0, "native editable buttons: " + id)
	check(not "3등신" in labels() and not "스트리트웨어" in labels(), "player menu excludes artist implementation text: " + id)

func labels() -> String:
	var text := ""
	for item: Node in app.page.find_children("*", "Label", true, false):
		text += item.text + "\n"
	return text

func inside_scroll(node: Node) -> bool:
	var parent := node.get_parent()
	while parent != app.page and parent != null:
		if parent is ScrollContainer: return true
		parent = parent.get_parent()
	return false

func inspect_layout(name: String) -> void:
	var bounds := root.get_visible_rect()
	var row := {"name": name, "viewport": [root.size.x, root.size.y], "logical_viewport": [bounds.size.x, bounds.size.y], "buttons": [], "labels": []}
	for item: Node in app.page.find_children("*", "Button", true, false):
		var target := item as Button
		if not target.is_visible_in_tree(): continue
		var rect := target.get_global_rect()
		var id := String(target.get_meta("qa_id", ""))
		row.buttons.append({"id": id, "text": target.text, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "disabled": target.disabled})
		if not inside_scroll(target):
			check(bounds.encloses(rect), name + " button fits viewport: " + id)
			if bounds.size.x >= 1280 and bounds.size.y >= 720:
				var safe_margin := bounds.grow_individual(-63.5, -31.5, -63.5, -31.5)
				check(safe_margin.encloses(rect), name + " button respects 96/48 design safe margin: " + id)
		if id.begins_with("menu/"):
			check(rect.size.x >= 71.5 and rect.size.y >= 71.5, name + " touch area >=72: " + id)
	for item: Node in app.page.find_children("*", "Control", true, false):
		if not item is HSlider and not item is LineEdit: continue
		var target := item as Control
		if not target.is_visible_in_tree(): continue
		var id := String(target.get_meta("qa_id", ""))
		check(target.get_global_rect().size.y >= 71.5, name + " native input touch height >=72: " + id)
	for item: Node in app.page.find_children("*", "Label", true, false):
		var label := item as Label
		if not label.is_visible_in_tree(): continue
		var rect := label.get_global_rect()
		row.labels.append({"text": label.text, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "minimum": [label.get_minimum_size().x, label.get_minimum_size().y]})
		if not inside_scroll(label): check(bounds.encloses(rect), name + " label fits viewport: " + label.text.left(32))
	layouts.append(row)

func frame(name: String) -> void:
	await settle()
	inspect_layout(name)
	if not capture: return
	await RenderingServer.frame_post_draw
	var rendered := root.get_texture().get_image()
	check(not rendered.is_empty(), "actual rendered viewport: " + name)
	if not rendered.is_empty():
		check(rendered.save_png(OUTPUT + "/" + name + ".png") == OK, "save actual viewport: " + name)

func run() -> void:
	audio = root.get_node("ForestArenaAudio")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1280, 720)
	if capture:
		check(DisplayServer.get_name() != "headless", "capture uses native window rendering")
		DisplayServer.window_set_size(root.size)
	app = load("res://scenes/local_ai_app.tscn").instantiate()
	app.save_path = qa_dir + "/profile.json"
	app.db_session_path = qa_dir + "/db-session.json"
	root.add_child(app)
	audio.settings_path = qa_dir + "/audio.cfg"
	await settle()
	check(app.store.grant_first("ja-hyun"), "first grant isolated QA profile")
	await run_interactions()
	await run_state_coverage()
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		if capture: DisplayServer.window_set_size(resolution)
		for menu: String in MENUS:
			await open_menu(menu)
			await frame(menu + "-" + str(resolution.x))
	root.size = Vector2i(1600, 720)
	if capture: DisplayServer.window_set_size(root.size)
	for menu: String in ["character_collection", "shop", "social", "settings"]:
		await open_menu(menu)
		await frame(menu + "-20x9")
	root.size = Vector2i(1280, 720)
	if capture: DisplayServer.window_set_size(root.size)
	app.store.data.accessibility.text_scale = 1.3
	for menu: String in MENUS:
		await open_menu(menu)
		await frame(menu + "-large-text")
	app.store.data.accessibility.text_scale = 1.15
	for menu: String in MENUS:
		await open_menu(menu)
		await frame(menu + "-medium-text")
	await run_safe_area_checks()
	var report := {"checks": checks, "failures": failures, "layouts": layouts, "native_capture": capture, "state_coverage": state_coverage, "device_test": "not_run", "qa_profile": qa_dir}
	var output := FileAccess.open(OUTPUT + "/runtime-report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	if capture:
		var native_output := FileAccess.open(OUTPUT + "/native-runtime-report.json", FileAccess.WRITE)
		native_output.store_string(JSON.stringify(report, "\t"))
	app.queue_free()
	await process_frame
	_cleanup(qa_dir)
	for failure: String in failures: push_error(failure)
	print("PREMIUM_MENU_RUNTIME: " + ("PASS" if failures.is_empty() else "FAIL") + " (%d checks)" % checks.size())
	quit(0 if failures.is_empty() else 1)

func run_interactions() -> void:
	# Action IDs are filled from the producer's real API, not from design mocks.
	for menu: String in ["mission", "social", "rank"]:
		await open_menu(menu)
		var before: Dictionary = app.store.data.duplicate(true)
		check("준비" in labels(), "future service clearly unavailable: " + menu)
		check(not "숲길친구" in labels() and not "푸른바람" in labels() and not "나뭇잎" in labels(), "future service contains no fake friends: " + menu)
		check(app.store.data == before, "future service leaves profile unchanged: " + menu)
	for target: String in MENUS:
		await open_menu("settings", {"category": "sound"})
		await press("menu/settings/all_menu")
		await press("menu/settings/open/" + target)
		check(app.menu_router.state.id == target, "all-menu native button opens " + target)
	await run_ownership_checks()
	await run_preset_checks()
	await run_settings_checks()
	await run_origin_checks()
	await open_menu("collection")
	var before: Dictionary = app.store.data.duplicate(true)
	check(button("menu/collection/apply") == null, "codex offers no equip action")
	check(app.store.data == before, "codex leaves selection unchanged")

func run_safe_area_checks() -> void:
	var full := Rect2(0, 0, 1280, 720)
	var logical_safe: Rect2 = CombatUiGeometry.logical_safe_rect(full, Rect2(96, 0, 1184, 720), Transform2D.IDENTITY)
	check(logical_safe == Rect2(96, 0, 1184, 720), "synthetic left notch maps to logical safe region")
	var scaled_safe: Rect2 = CombatUiGeometry.logical_safe_rect(full, Rect2(144, 0, 1776, 1080), Transform2D(Vector2(1.5, 0), Vector2(0, 1.5), Vector2.ZERO))
	check(scaled_safe == logical_safe, "synthetic notch transforms screen pixels into logical coordinates")
	# Render the available 1184px width itself; the excluded 96px are not rendered.
	# This is a desktop geometry check, not an Android display-safe-area result.
	var previous_content_scale: Vector2i = root.content_scale_size
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1184, 720)
	if capture: DisplayServer.window_set_size(root.size)
	await settle()
	check(is_equal_approx(root.get_visible_rect().size.x, 1184), "synthetic narrow fixture uses real logical1184 viewport")
	app.store.data.accessibility.text_scale = 1.3
	for menu: String in MENUS:
		app.menu_router.reset()
		await open_menu(menu)
		inspect_layout(menu + "-synthetic-notch")
		var rect: Rect2 = app.menu_router.view.content.get_global_rect()
		check(root.get_visible_rect().encloses(rect), "native menu canvas fits synthetic available width: " + menu)
	var previous_pending: Dictionary = app.db_client.pending.duplicate(true)
	var previous_db_mode: bool = app.db_mode
	app.db_mode = true
	app.db_client.pending = {"action": "identity", "payload": {"nickname": "재시도검사"}}
	app.menu_router.reset()
	await open_menu("controls")
	check(button("menu/controls/retry_db") != null, "native DB pending adds retry footer")
	await frame("controls-retry-db-synthetic-notch")
	app.db_mode = previous_db_mode
	app.db_client.pending = previous_pending
	var base_dir: String = app.menu_store.base_dir
	app.menu_store.base_dir = qa_dir + "/blocked"
	app.menu_router.reset()
	await open_menu("controls")
	check(button("menu/controls/retry_local") != null, "native local load failure adds retry footer")
	await frame("controls-retry-local-synthetic-notch")
	app.db_mode = true
	app.db_client.pending = {"action": "identity", "payload": {"nickname": "동시재시도검사"}}
	app.menu_router.reset()
	await open_menu("controls")
	check(button("menu/controls/retry_db") != null and button("menu/controls/retry_local") != null, "combined pending DB and local read failure expose both retry controls")
	await frame("controls-retry-combined-synthetic-notch")
	app.db_mode = previous_db_mode
	app.db_client.pending = previous_pending
	app.menu_router.reset()
	await open_menu("preset")
	check(app.menu_router.state.get("local_load_error", false), "owner/load failure is visible in preset state")
	check(app._menu_owner_key() != app.menu_store._owner, "failed owner switch retains old storage owner without publishing it")
	await frame("preset-owner-load-failure-synthetic-notch")
	check(app.menu_router._preset_draft.is_empty() or app.menu_router.view.preset.is_empty(), "owner/load failure does not display old owner preset data")
	var previous_slots: Array = app.menu_store.slots.duplicate(true)
	var actual_profile: Dictionary = app.store.data.duplicate(true)
	var save_button := button("menu/preset/preset_save")
	if save_button != null: save_button.pressed.emit()
	await settle()
	var apply_button := button("menu/preset/preset_apply")
	if apply_button != null: apply_button.pressed.emit()
	await settle()
	check(app.menu_store.slots == previous_slots and app.store.data == actual_profile, "failed menu-owner load blocks actual preset save and apply")
	app.menu_store.base_dir = base_dir
	app.menu_router.reset()
	root.content_scale_size = previous_content_scale
	root.size = Vector2i(1280, 720)
	if capture: DisplayServer.window_set_size(root.size)

func run_state_coverage() -> void:
	var specification: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://_workspace/premium-menu-v07-runtime/state-runtime-coverage.json"))
	for row: Dictionary in specification.states:
		var start := checks.size()
		var menu: String = row.runtime_menu
		var params: Dictionary = row.params.duplicate(true)
		# A pause design origin is validated with a live frozen match separately.
		# State inspection here uses lobby to avoid inventing a match.
		params.entry_context = "lobby"
		if menu in ["mission", "social"] and params.has("tab"):
			params.category = params.tab
		if row.action == "empty_state" and menu == "collection": params.filter = "미보유"
		app.menu_router.reset()
		await open_menu(menu, params)
		match String(row.action):
			"preset_slot": await press("menu/preset/slot/%d" % int(params.slot))
			"open_product_modal":
				await press("purchase/" + String(params.product_id))
				check(is_instance_valid(app.menu_router.view.modal), "state native shop modal: " + String(row.design_screen))
				await press("menu/shop/modal_cancel")
			"settings_reset_modal":
				await press("menu/%s/settings_reset" % menu)
				check(is_instance_valid(app.menu_router.view.modal), "state native defaults modal: " + String(row.design_screen))
				await press("menu/%s/modal_cancel" % menu)
			"draft_floating":
				await press("menu/controls/draft/joystick_mode/floating")
				check(app.menu_router._draft.joystick_mode == "floating", "state floating draft uses real control")
			"native_sliders":
				check(control("menu/controls/draft/button_scale") is HSlider and control("menu/controls/draft/button_transparency") is HSlider, "state parameters have real native sliders")
			"all_menu_navigation":
				await press("menu/%s/all_menu" % menu)
				for target: String in MENUS: check(button("menu/%s/open/%s" % [menu, target]) != null, "all-menu native destination: " + target)
				await press("menu/%s/modal_cancel" % menu)
			"empty_slot_apply_modal":
				# Empty slot flow ran before filling all four; do not clear user-like data.
				check(checks.any(func(record: Dictionary) -> bool: return record.label == "empty preset apply asks for selection" and record.pass), "selection-required state exercised before filled slots")
			"draft_then_cancel_or_apply":
				var key: String = "muted" if params.category == "sound" else ("reduce_visual_effects" if params.category == "effects" else "haptics_enabled")
				var toggle := control("menu/settings/draft/" + key) as CheckButton
				check(toggle != null, "state off toggle exists: " + key)
				if toggle != null: toggle.button_pressed = not toggle.button_pressed
				await press("menu/settings/settings_cancel")
		if row.policy == "honest_empty": check("준비 중" in labels(), "approved future state is honest empty: " + String(row.design_screen))
		if menu == "character_detail": check(app.menu_router.state.tab == params.get("tab", app.menu_router.state.tab), "character detail uses requested native tab")
		if params.has("selected_id"): check(app.menu_router.state.selected_id == params.selected_id, "state visible item matches requested real catalog ID: " + String(row.design_screen))
		var passed := true
		for index: int in range(start, checks.size()):
			if not checks[index].pass: passed = false
		state_coverage.append({"design_screen": row.design_screen, "runtime_menu": menu, "checks": checks.size() - start, "pass": passed, "policy": row.policy})
	check(state_coverage.size() == 81, "all approved 81 states mapped to executed native or honest-empty behavior")
	app.menu_router.reset()
	app._show_home()
	await settle()

func run_ownership_checks() -> void:
	app.menu_router.reset()
	await open_menu("character_collection", {"selected_id": "myo-ryung", "filter": "전체"})
	var before: Dictionary = app.store.data.duplicate(true)
	await press("menu/character_collection/select")
	check(is_instance_valid(app.menu_router.view.modal), "unowned selection shows honest purchase guidance")
	check(app.store.data == before, "unowned selection cannot change profile")
	await press("menu/character_collection/modal_cancel")
	await press("menu/character_collection/detail")
	await press("menu/character_detail/tab/이야기")
	await press("menu/character_detail/back")
	check(app.menu_router.state.id == "character_collection" and app.menu_router.state.selected_id == "myo-ryung", "detail back preserves character selection")
	await open_menu("shop", {"category": "전체"})
	for product: Dictionary in app.catalog.products:
		if app.store.owns(String(product.id)): continue
		check(int(product.price) == 0, "existing free price: " + String(product.id))
		await press("purchase/" + String(product.id))
		check(is_instance_valid(app.menu_router.view.modal), "purchase opens native confirmation: " + String(product.id))
		await press("menu/shop/purchase_confirm/" + String(product.id))
		check(app.store.owns(String(product.id)), "confirmed free purchase updates ownership: " + String(product.id))
	await open_menu("character_collection", {"selected_id": "myo-ryung"})
	await press("menu/character_collection/select")
	check(app.store.data.selected_character == "myo-ryung", "owned character selection applies real profile")
	await open_menu("accessory_collection", {"selected_id": "fixture-iron-armor"})
	await press("menu/accessory_collection/select")
	check(app.store.data.selected_accessory == "fixture-iron-armor", "owned accessory selection applies real profile")
	await open_menu("collection", {"category": "character", "filter": "보유"})
	before = app.store.data.duplicate(true)
	await press("menu/collection/read/myo-ryung")
	check("읽기 전용" in labels(), "codex detail explains readonly record")
	check(button("menu/collection/select") == null and button("menu/collection/purchase") == null, "codex detail has no selection or purchase")
	await press("menu/collection/modal_confirm")
	check(app.store.data == before, "codex detail leaves actual profile unchanged")

func run_preset_checks() -> void:
	const CHARACTERS := ["ja-hyun", "myo-ryung", "nabi", "yu-ran"]
	const ACCESSORIES := ["fixture-iron-armor", "fixture-boxing-gloves", "fixture-thorns", "fixture-explosive-gloves"]
	app.menu_router.reset()
	await open_menu("preset")
	await press("menu/preset/slot/3")
	await press("menu/preset/preset_apply")
	check(is_instance_valid(app.menu_router.view.modal), "empty preset apply asks for selection")
	await press("menu/preset/modal_confirm")
	for index: int in 4:
		await open_menu("preset")
		await press("menu/preset/slot/%d" % index)
		var actual_before: Dictionary = app.store.data.duplicate(true)
		await press("menu/preset/edit/character")
		await press("menu/character_collection/character/" + CHARACTERS[index])
		await press("menu/character_collection/select")
		check(app.menu_router.state.id == "preset", "preset character chooser returns to draft")
		await press("menu/preset/edit/accessory")
		await press("menu/accessory_collection/accessory/" + ACCESSORIES[index])
		await press("menu/accessory_collection/select")
		await press("menu/preset/preset_save")
		check(app.menu_store.slots[index] == {"character": CHARACTERS[index], "accessory": ACCESSORIES[index]}, "slot %d stores chosen native draft" % index)
		check(app.store.data == actual_before, "slot %d draft save leaves actual loadout unchanged" % index)
		await press("menu/preset/preset_apply")
		check(app.screen == "prepare", "slot %d apply opens real prepare" % index)
		check(app.store.data.selected_character == CHARACTERS[index] and app.store.data.selected_accessory == ACCESSORIES[index], "slot %d applies chosen real loadout" % index)
	var restored = load("res://scripts/premium_menu/local_menu_state_store.gd").new(qa_dir, app.catalog)
	check(restored.load_presets(app._menu_owner_key(), {"character": app.store.data.selected_character, "accessory": app.store.data.selected_accessory}), "menu presets reopen isolated disk file")
	check(restored.slots == app.menu_store.slots and restored.selected_slot == 3, "all four slots and active slot survive reopen")
	check(int(app.store.data.schema_version) == 3, "menu presets leave player schema v3 unchanged")

func run_settings_checks() -> void:
	app.menu_router.reset()
	await open_menu("settings", {"category": "sound"})
	var baseline := {"music": audio.music_level, "effects": audio.effects_level, "muted": audio.muted}
	var changed: float = 0.15 if not is_equal_approx(float(baseline.music), 0.15) else 0.75
	await set_slider("menu/settings/draft/music", changed)
	check(audio.music_level == baseline.music, "sound draft does not change applied audio")
	await press("menu/settings/settings_cancel")
	check(app.menu_router._draft.music == baseline.music, "cancel restores sound draft")
	await set_slider("menu/settings/draft/music", changed)
	await press("menu/settings/category/accessibility")
	check(is_instance_valid(app.menu_router.view.modal) and app.menu_router.state.category == "sound", "dirty category switch requires native confirmation")
	await press("menu/settings/modal_cancel")
	check(app.menu_router._draft.music == changed, "category cancel preserves edited draft")
	await press("menu/settings/settings_cancel")
	var blocker := qa_dir + "/blocked"
	var file := FileAccess.open(blocker, FileAccess.WRITE)
	file.store_string("ordinary file prevents directory save")
	file.close()
	var original_audio_path: String = audio.settings_path
	audio.settings_path = blocker + "/audio.cfg"
	await set_slider("menu/settings/draft/music", changed)
	await press("menu/settings/settings_apply")
	check(audio.music_level == baseline.music and audio.effects_level == baseline.effects and audio.muted == baseline.muted, "failed sound save restores applied audio levels")
	check("저장하지 못" in labels(), "failed sound save shows user error")
	audio.settings_path = original_audio_path
	await press("menu/settings/settings_cancel")
	await press("menu/settings/category/accessibility")
	var old_accessibility: Dictionary = app.store.data.accessibility.duplicate(true)
	await press("menu/settings/draft/text_scale/1.3")
	check(app.store.data.accessibility == old_accessibility, "accessibility draft is not saved early")
	await press("menu/settings/settings_cancel")
	check(app.menu_router._draft == old_accessibility, "accessibility cancel restores baseline")
	await press("menu/settings/draft/text_scale/1.3")
	await press("menu/settings/settings_apply")
	check(app.store.data.accessibility.text_scale == 1.3, "accessibility apply saves real profile")
	await press("menu/settings/settings_reset")
	check(is_instance_valid(app.menu_router.view.modal), "defaults require explicit native confirmation")
	await press("menu/settings/modal_confirm")
	check(app.menu_router._draft.text_scale == 1.0 and app.store.data.accessibility.text_scale == 1.3, "defaults change draft only before apply")
	await press("menu/settings/settings_apply")
	check(app.store.data.accessibility.text_scale == 1.0, "apply saves accessibility defaults")
	await press("menu/settings/category/effects")
	var effects_toggle := control("menu/settings/draft/reduce_visual_effects") as CheckButton
	check(effects_toggle != null, "effects uses native accessibility toggle")
	if effects_toggle != null: effects_toggle.button_pressed = true
	await press("menu/settings/settings_apply")
	check(app.store.data.accessibility.reduce_visual_effects, "effects apply persists reduce visual effects")
	await press("menu/settings/category/minimap")
	await set_slider("menu/settings/draft/transparency", 55)
	await press("menu/settings/draft/marker_style/dot")
	var names_toggle := control("menu/settings/draft/show_names") as CheckButton
	check(names_toggle != null, "minimap uses native names toggle")
	if names_toggle != null: names_toggle.button_pressed = false
	await press("menu/settings/settings_apply")
	check(app.store.data.minimap == {"transparency": 55, "marker_style": "dot", "show_names": false}, "minimap apply persists all existing fields")
	await open_menu("controls", {"entry_context": "lobby"})
	var old_controls: Dictionary = app.menu_store.controls.duplicate(true)
	await press("menu/controls/draft/joystick_mode/floating")
	await set_slider("menu/controls/draft/button_scale", 1.2)
	await set_slider("menu/controls/draft/button_transparency", 50)
	check(app.menu_store.controls == old_controls, "control draft is not saved early")
	await press("menu/controls/settings_cancel")
	check(app.menu_router._draft == old_controls, "controls cancel restores baseline")
	await press("menu/controls/draft/joystick_mode/floating")
	await set_slider("menu/controls/draft/button_scale", 1.2)
	await set_slider("menu/controls/draft/button_transparency", 50)
	var original_menu_path: String = app.menu_store.base_dir
	app.menu_store.base_dir = blocker
	await press("menu/controls/settings_apply")
	check(app.menu_store.controls == old_controls and "저장하지 못" in labels(), "failed control save preserves applied settings and reports error")
	app.menu_store.base_dir = original_menu_path
	await press("menu/controls/settings_apply")
	var expected := {"joystick_mode": "floating", "button_scale": 1.2, "button_transparency": 50}
	check(app.menu_store.controls == expected, "control apply saves requested native draft")
	var restored = load("res://scripts/premium_menu/local_menu_state_store.gd").new(qa_dir, app.catalog)
	check(restored.load_controls() and restored.controls == expected, "control settings survive reopen")
	await open_menu("profile")
	var input := control("menu/profile/nickname_input") as LineEdit
	check(input != null, "nickname is real editable profile field")
	if input != null: input.text = "검사숲지기"
	await press("menu/profile/nickname_save")
	check(app.store.data.nickname == "검사숲지기", "profile nickname action persists real profile")

func run_origin_checks() -> void:
	app.menu_router.reset()
	app._show_home()
	await open_menu("controls", {"entry_context": "lobby"})
	app.handle_back_request(Time.get_ticks_msec() + 1000)
	await settle()
	check(app.screen == "home", "controls back restores lobby origin")
	app.menu_router.reset()
	app._show_prepare()
	await open_menu("controls", {"entry_context": "prepare"})
	app.handle_back_request(Time.get_ticks_msec() + 2000)
	await settle()
	check(app.screen == "prepare", "controls back restores prepare origin")
	app.selected_mode = LocalMatchConfig.Mode.PRACTICE
	app.start_match()
	await settle()
	app.pause_match()
	await settle()
	var snapshot: String = app.match_controller.snapshot_hash()
	var music_index: int = audio.music_index
	await open_menu("controls", {"entry_context": "pause"})
	check(app.match_controller.paused, "controls preserve paused combat")
	check(app.match_controller.snapshot_hash() == snapshot, "controls leave frozen combat unchanged")
	check(audio.paused_match and audio.context == "battle", "controls preserve paused battle audio")
	check(audio.music_index == music_index, "controls do not restart battle music")
	app.handle_back_request(Time.get_ticks_msec() + 3000)
	await settle()
	check(app.screen == "pause", "controls back restores actual pause page")
	check(app.match_controller.paused and app.match_controller.snapshot_hash() == snapshot, "back leaves battle paused without combat changes")
	app._close_match()
	app.menu_router.reset()
	app._show_home()
	await settle()

func _cleanup(directory: String) -> void:
	var listing := DirAccess.open(directory)
	if listing == null: return
	for file: String in listing.get_files(): DirAccess.remove_absolute(directory + "/" + file)
	DirAccess.remove_absolute(directory)
