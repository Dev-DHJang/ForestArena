extends Node2D

const SEMANTIC_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"dash", &"attack_light", &"attack_heavy", &"attack_special"]
const HUD_PANEL_ID := "fa.ui.panel.panel.dark.l"
const RESTART_NORMAL_ID := "fa.ui.button.base.btn.secondary.m.default"
const RESTART_PRESSED_ID := "fa.ui.button.base.btn.secondary.m.pressed"
const RESTART_DISABLED_ID := "fa.ui.button.base.btn.secondary.m.disabled"

@onready var match_controller: MatchController = $MatchController
@onready var touch: Control = $Interface/TouchCommandSource
@onready var readout: Label = $Interface/MatchReadout
@onready var restart: Button = $Interface/Restart
@onready var debug_readout: Label = $Interface/DebugReadout
@onready var hud_panel: NinePatchRect = $Interface/HudPanel
@onready var resource_warnings: Label = $Interface/ResourceWarnings

var _missing_resource_ids: PackedStringArray = []


func _ready() -> void:
	_apply_resource_ui()
	match_controller.snapshot_changed.connect(_render_snapshot)
	restart.pressed.connect(match_controller.reset_match)
	_render_snapshot(match_controller.snapshot())
	debug_readout.visible = OS.is_debug_build()


func _apply_resource_ui() -> void:
	hud_panel.texture = _resource_texture(HUD_PANEL_ID, Vector2i(16, 9))
	restart.add_theme_color_override("font_color", Color("3b2818"))
	restart.add_theme_color_override("font_hover_color", Color("3b2818"))
	restart.add_theme_color_override("font_pressed_color", Color("24170f"))
	restart.add_theme_color_override("font_focus_color", Color("24170f"))
	restart.add_theme_color_override("font_disabled_color", Color("756a5d"))
	restart.add_theme_font_size_override("font_size", 18)
	restart.add_theme_stylebox_override("normal", _button_style(RESTART_NORMAL_ID))
	restart.add_theme_stylebox_override("hover", _button_style(RESTART_NORMAL_ID))
	restart.add_theme_stylebox_override("pressed", _button_style(RESTART_PRESSED_ID))
	restart.add_theme_stylebox_override("focus", _button_style(RESTART_PRESSED_ID))
	restart.add_theme_stylebox_override("disabled", _button_style(RESTART_DISABLED_ID))


func _button_style(logical_id: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _resource_texture(logical_id, Vector2i(16, 9))
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 42.0)
	return style


func _resource_texture(logical_id: String, fallback_size: Vector2i) -> Texture2D:
	var texture := ForestArenaResources.load_texture(logical_id)
	if texture != null:
		return texture
	if logical_id not in _missing_resource_ids:
		_missing_resource_ids.append(logical_id)
	resource_warnings.text = "MISSING RESOURCE: %s" % ", ".join(_missing_resource_ids)
	var image := Image.create_empty(fallback_size.x, fallback_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color("a22654"))
	return ImageTexture.create_from_image(image)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventMouseMotion:
		touch.handle_pointer_event(event)


func _notification(what: int) -> void:
	if not is_node_ready() or not is_instance_valid(touch) or not is_instance_valid(match_controller):
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_release_semantic_actions()
		touch.release_all_touches()
		match_controller.pause_match(true)
		print("FOREST_ARENA_INPUT_RESET reason=pause")
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		match_controller.pause_match(false)


func _release_semantic_actions() -> void:
	for action: StringName in SEMANTIC_ACTIONS:
		Input.action_release(action)


func _render_snapshot(snapshot: Dictionary) -> void:
	var fighters: Array = snapshot.get("fighters", [])
	if fighters.size() < 2:
		return
	var first: Dictionary = fighters[0]
	var second: Dictionary = fighters[1]
	var suffix := ""
	if int(snapshot.get("sudden_death_round", 0)) > 0:
		suffix = " · SUDDEN DEATH %d" % snapshot.sudden_death_round
	if not String(snapshot.get("winner_id", "")).is_empty():
		suffix = " · 승자: %s" % snapshot.winner_id
	readout.text = "자현 %d%% · %d STOCK    묘령 %d%% · %d STOCK%s" % [roundi(first.damage_percent), first.stocks, roundi(second.damage_percent), second.stocks, suffix]
	debug_readout.text = "tick %d  %s:%s  %s:%s" % [snapshot.tick, first.state, first.attack_id, second.state, second.attack_id]
