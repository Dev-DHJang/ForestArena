extends Control
## The entry scene intentionally has no dependency on the game scene or its catalog.
const PREPARER = preload("res://scripts/ui_resource_preparer.gd")
const APP_SCENE := "res://scenes/local_ai_app.tscn"
var preparer: UiResourcePreparer
var background: TextureRect
var loading: ProgressBar
var status: Label
var start_prompt: Label
var ready_to_start := false
var entered := false
var app: Node
var save_path := ""
var db_session_path := ""
var demo_guest_session_path := ""
var required_paths: Array[String] = []
var held_touches: Dictionary = {}
var mouse_held := false
var accept_held := false
var retry: Button
var preparing_index := 0
var preparing_count := 1
var qa_directory := ""
var qa_run := ""
var qa_boot := ""
var version_label: Label

func _ready() -> void:
	name = "StartupTitle"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().quit_on_go_back = false
	var fill := ColorRect.new()
	fill.color = Color("142d25")
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background = TextureRect.new()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.06, 0.04, 0.26)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := _label("FOREST ARENA", 60)
	title.name = "TitleLogo"
	_position(title, 0.28, 580, 80)
	start_prompt = _label("게임 시작", 32)
	start_prompt.name = "StartPrompt"
	start_prompt.add_theme_stylebox_override("normal", _text_backing())
	_position(start_prompt, 0.78, 440, 64)
	start_prompt.hide()
	status = _label("게임을 준비하고 있습니다…", 20)
	_position(status, 0.79, 800, 40)
	loading = ProgressBar.new()
	loading.name = "StartupLoadingBar"
	loading.max_value = 1.0
	loading.show_percentage = false
	add_child(loading)
	_position(loading, 0.87, 680, 18)
	version_label = _label("v" + String(ProjectSettings.get_setting_with_override("application/config/version")) + "   ·   © 2026 Forest Arena. All rights reserved.", 16)
	version_label.name = "VersionCopyright"
	version_label.add_theme_stylebox_override("normal", _text_backing())
	_position(version_label, 0.94, 1000, 28)
	retry = Button.new()
	retry.name = "RetryStartup"
	retry.text = "다시 시도"
	add_child(retry)
	_position(retry, 0.69, 240, 58)
	retry.hide()
	retry.pressed.connect(_prepare)
	preparer = PREPARER.new()
	add_child(preparer)
	preparer.progress_changed.connect(func(value: float) -> void: loading.value = (preparing_index + value) / (preparing_count + 1))
	resized.connect(_safe_layout)
	_safe_layout()
	_publish_qa(false)
	_prepare.call_deferred()

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("f3f4df"))
	label.add_theme_color_override("font_outline_color", Color("173b2a"))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _position(control: Control, y: float, width: float, height: float) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	control.anchor_top = y
	control.anchor_bottom = y
	control.offset_left = -width * 0.5
	control.offset_right = width * 0.5
	control.offset_top = -height * 0.5
	control.offset_bottom = height * 0.5

func _safe_layout() -> void:
	# Match the project canvas while keeping footers away from display cutouts.
	var viewport_size := get_viewport_rect().size
	var safe := DisplayServer.get_display_safe_area()
	var window_size := DisplayServer.window_get_size()
	var bottom := 20.0
	if OS.has_feature("mobile") and window_size.y > 0:
		bottom = maxf(bottom, (window_size.y - safe.end.y) * viewport_size.y / window_size.y + 12.0)
	version_label.anchor_top = 1.0
	version_label.anchor_bottom = 1.0
	version_label.offset_top = -bottom - 28
	version_label.offset_bottom = -bottom
	version_label.offset_left = -minf(500, viewport_size.x * 0.46)
	version_label.offset_right = minf(500, viewport_size.x * 0.46)

func _prepare() -> void:
	ready_to_start = false
	retry.hide()
	loading.show()
	loading.value = 0.0
	status.text = "게임을 준비하고 있습니다…"
	status.show()
	await get_tree().process_frame
	var paths: Array[String] = required_paths.duplicate()
	if paths.is_empty():
		paths = PREPARER.ui_paths(["fa.background.title.forest", "fa.font.menu.v07.noto_sans_kr", "fa.ui.forestlight."])
		paths.append("res://scenes/main.tscn")
		paths.append(APP_SCENE)
	preparing_count = paths.size()
	for index: int in paths.size():
		preparing_index = index
		# App script compilation touches globally named gameplay classes. Compile
		# this small shell on the main thread after threaded scene dependencies.
		if paths[index] == APP_SCENE:
			preparer.retained["res://scripts/local_ai_app.gd"] = load("res://scripts/local_ai_app.gd")
		if not await preparer.prepare([paths[index]]):
			status.text = preparer.error
			retry.show()
			loading.hide()
			return
		loading.value = float(index + 1) / (paths.size() + 1)
		var title_path := ForestArenaResources.resource_path("fa.background.title.forest")
		if preparer.retained.has(title_path): background.texture = preparer.retained[title_path]
		var font_path := ForestArenaResources.resource_path("fa.font.menu.v07.noto_sans_kr")
		if preparer.retained.has(font_path):
			var title_theme := Theme.new()
			var font := FontVariation.new()
			font.base_font = preparer.retained[font_path]
			font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 650}
			title_theme.default_font = font
			theme = title_theme
	# Instantiation performs the catalog's local initialization before readiness.
	var packed: PackedScene = preparer.retained.get(APP_SCENE)
	if packed == null:
		status.text = "게임 장면을 준비하지 못했습니다. 다시 시도하세요."
		retry.show()
		return
	app = packed.instantiate()
	app.async_navigation = true
	app.resource_retainer = preparer
	if not save_path.is_empty(): app.save_path = save_path
	if not db_session_path.is_empty(): app.db_session_path = db_session_path
	if not demo_guest_session_path.is_empty(): app.demo_guest_session_path = demo_guest_session_path
	loading.value = 1.0
	await get_tree().process_frame
	ready_to_start = true
	mouse_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	accept_held = Input.is_action_pressed("ui_accept")
	loading.hide()
	status.hide()
	start_prompt.show()
	_publish_qa(true)
	if OS.is_debug_build(): print("FOREST_ARENA_TITLE_READY")

func _input(event: InputEvent) -> void:
	var fresh_press := false
	if event is InputEventScreenTouch:
		fresh_press = event.pressed and not held_touches.has(event.index)
		if event.pressed: held_touches[event.index] = true
		else: held_touches.erase(event.index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		fresh_press = event.pressed and not mouse_held and event.device != InputEvent.DEVICE_ID_EMULATION
		mouse_held = event.pressed
	elif event.is_action("ui_accept"):
		fresh_press = event.is_pressed() and not event.is_echo() and not accept_held
		accept_held = event.is_pressed()
	if fresh_press and ready_to_start and not entered:
		get_viewport().set_input_as_handled()
		enter_game()

func enter_game() -> void:
	if not ready_to_start or entered: return
	entered = true
	start_prompt.hide()
	# The prepared game remains detached until this deliberate input. No HTTP
	# clients or saved DB auto-connect run during the title preparation.
	get_parent().add_child(app)
	if get_tree().current_scene == self: get_tree().current_scene = app
	# Keep the title alive but hidden: it owns the retained common resources.
	hide()
	set_process_input(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible: get_tree().quit()

func _exit_tree() -> void:
	if is_instance_valid(app) and not app.is_inside_tree(): app.free()


func _publish_qa(ready: bool) -> void:
	if not OS.is_debug_build(): return
	if qa_directory.is_empty():
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--qa-run="): qa_run = argument.trim_prefix("--qa-run=")
		if qa_run.is_empty() or qa_run.length() > 64: return
		for character: String in qa_run:
			if character not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-": return
		qa_directory = "user://qa/" + qa_run
		if DirAccess.make_dir_recursive_absolute(qa_directory) != OK: return
		qa_boot = "title-" + str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec())
	var file := FileAccess.open(qa_directory + "/startup.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"schema_version": 1, "run_id": qa_run, "boot_id": qa_boot, "screen": "title", "ready": ready, "msec": Time.get_ticks_msec(), "viewport": {"width": size.x, "height": size.y}}))


func _text_backing() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.025, 0.075, 0.045, 0.72)
	box.set_corner_radius_all(12)
	return box
