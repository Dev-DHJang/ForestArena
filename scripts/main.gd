extends Node2D

const SEMANTIC_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"dash", &"attack_light", &"attack_heavy", &"attack_special", &"ultimate"]
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
@onready var player_combat_readout: Label = $Interface/PlayerCombatReadout
@onready var dummy_combat_readout: Label = $Interface/DummyCombatReadout
@onready var player_status: Label = $Interface/PlayerStatus
@onready var dummy_status: Label = $Interface/DummyStatus
@onready var state_flash: ColorRect = $Interface/StateFlash
@onready var debug_launcher: Phase3DebugLauncher = $Interface/Phase3DebugLauncher
@onready var debug_launcher_button: Button = $Interface/DebugLauncherButton

var _missing_resource_ids: PackedStringArray = []
var _last_states: Array[String] = ["", ""]


func _ready() -> void:
	_apply_resource_ui()
	match_controller.snapshot_changed.connect(_render_snapshot)
	restart.pressed.connect(match_controller.reset_match)
	debug_launcher.configuration_requested.connect(_apply_debug_configuration)
	debug_launcher.dismissed.connect(func() -> void: _set_debug_launcher_visible(false))
	debug_launcher_button.visible = OS.is_debug_build()
	debug_launcher_button.pressed.connect(_toggle_debug_launcher)
	_render_snapshot(match_controller.snapshot())
	debug_readout.visible = OS.is_debug_build()
	if debug_launcher.visible:
		_set_debug_launcher_visible(true)


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
	debug_launcher.add_theme_stylebox_override("panel", _button_style(HUD_PANEL_ID))
	debug_launcher_button.add_theme_stylebox_override("normal", _button_style(RESTART_NORMAL_ID))
	debug_launcher_button.add_theme_stylebox_override("hover", _button_style(RESTART_NORMAL_ID))
	debug_launcher_button.add_theme_stylebox_override("pressed", _button_style(RESTART_PRESSED_ID))


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
	if debug_launcher.visible:
		return
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
		match_controller.pause_match(debug_launcher.visible)


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
	readout.text = "%s %d%% · %d STOCK    %s %d%% · %d STOCK%s" % [first.id, roundi(first.damage_percent), first.stocks, second.id, roundi(second.damage_percent), second.stocks, suffix]
	player_combat_readout.text = _combat_status_text(first)
	dummy_combat_readout.text = _combat_status_text(second)
	_update_status_badge(player_status, first, 0)
	_update_status_badge(dummy_status, second, 1)
	debug_readout.text = "tick %d  %s:%s evade %s  %s:%s evade %s" % [snapshot.tick, first.state, first.attack_id, _evade_text(first), second.state, second.attack_id, _evade_text(second)]


func _combat_status_text(fighter: Dictionary) -> String:
	var guard_max := float(fighter.get("guard_max_durability", _rule_number("guard_max_durability", 100.0)))
	var guard_value := float(fighter.get("guard_durability", 0.0))
	var guard_text := "GUARD %.0f/%.0f" % [guard_value, guard_max]
	if int(fighter.get("guard_break_ticks", 0)) > 0 or String(fighter.get("state", "")) == "GUARD_BREAK":
		guard_text += " · BREAK"
	var cooldown_text := _cooldown_text(fighter)
	var ultimate_max := float(fighter.get("ultimate_max_gauge", fighter.get("ultimate_max", 100.0)))
	var ultimate_value := float(fighter.get("ultimate_gauge", fighter.get("ultimate_meter", 0.0)))
	var ultimate_text := "필살기 %.0f/%.0f" % [ultimate_value, ultimate_max]
	if bool(fighter.get("ultimate_used", fighter.get("ultimate_used_this_stock", false))):
		ultimate_text += " · USED"
	return "%s · EVADE %s · %s · %s" % [guard_text, _evade_text(fighter), cooldown_text, ultimate_text]


func _evade_text(fighter: Dictionary) -> String:
	if fighter.has("evade_available"):
		return "READY" if bool(fighter.evade_available) else "WAIT %d" % int(fighter.get("evade_cooldown_ticks", 0))
	var cooldown := int(fighter.get("evade_cooldown_ticks", 0))
	if cooldown > 0:
		return "WAIT %d" % cooldown
	return "READY (%d AIR)" % int(fighter.get("aerial_evades", 0))


func _cooldown_text(fighter: Dictionary) -> String:
	var cooldowns: Dictionary = fighter.get("special_cooldowns", fighter.get("cooldowns", {}))
	if cooldowns.is_empty():
		var remaining := int(fighter.get("special_cooldown_ticks", 0))
		return "SPECIAL READY" if remaining <= 0 else "SPECIAL %d" % remaining
	var entries: PackedStringArray = []
	var groups: Array = cooldowns.keys()
	groups.sort()
	for group: Variant in groups:
		var ticks := int(cooldowns[group])
		entries.append("%s:%s" % [String(group).to_upper(), "READY" if ticks <= 0 else str(ticks)])
	return " / ".join(entries)


func _update_status_badge(label: Label, fighter: Dictionary, index: int) -> void:
	var state := String(fighter.get("state", "UNKNOWN"))
	var badge_text := state.replace("_", " ")
	var color := Color("dbe7f3")
	if state == "GUARD_BREAK":
		badge_text = "! GUARD BREAK !"
		color = Color("ff7085")
	elif state == "GUARD":
		badge_text = "◆ GUARD"
		color = Color("70b7ff")
	elif state.begins_with("EVADE"):
		badge_text = "» EVADE «"
		color = Color("72f1d1")
	elif float(fighter.get("ultimate_gauge", fighter.get("ultimate_meter", 0.0))) >= float(fighter.get("ultimate_max_gauge", fighter.get("ultimate_max", 100.0))) and not bool(fighter.get("ultimate_used", fighter.get("ultimate_used_this_stock", false))):
		badge_text = "★ ULT READY"
		color = Color("ffd66b")
	label.text = badge_text
	label.add_theme_color_override("font_color", color)
	if _last_states[index] != badge_text:
		_last_states[index] = badge_text
		if state == "GUARD_BREAK" or state.begins_with("EVADE") or state.begins_with("ULTIMATE") or badge_text.contains("ULT READY"):
			_flash(color)


func _flash(color: Color) -> void:
	state_flash.color = Color(color, 0.18)
	var tween := create_tween()
	tween.tween_property(state_flash, "color:a", 0.0, 0.18)


func _rule_number(property_name: StringName, fallback: float) -> float:
	if match_controller.rules == null:
		return fallback
	var value: Variant = match_controller.rules.get(property_name)
	return fallback if value == null else float(value)


func _apply_debug_configuration(configuration: Dictionary) -> void:
	# Phase 3 MatchController integration point. The launcher owns no loadout,
	# bot, scenario, or persistence state; it only sends stable logical IDs.
	var accepted := false
	if match_controller.has_method("configure_debug_match"):
		accepted = bool(match_controller.call("configure_debug_match", configuration))
	elif match_controller.has_method("apply_debug_configuration"):
		accepted = bool(match_controller.call("apply_debug_configuration", configuration))
	else:
		push_warning("MatchController does not expose configure_debug_match(Dictionary) yet.")
	debug_launcher.set_status("적용됨 · 전투 시작" if accepted else "구성을 적용할 수 없음", accepted)
	if accepted:
		_set_debug_launcher_visible(false)


func _toggle_debug_launcher() -> void:
	touch.release_all_touches()
	_set_debug_launcher_visible(not debug_launcher.visible)


func _set_debug_launcher_visible(value: bool) -> void:
	if value:
		touch.release_all_touches()
	debug_launcher.visible = value
	# The launcher is a pre-match development surface. Hide live HUD and touch
	# affordances while it is open so the 1280×720 landscape layout has one
	# readable hierarchy instead of overlapping match state behind the panel.
	for node: CanvasItem in [touch, hud_panel, readout, restart, debug_readout, resource_warnings, player_combat_readout, dummy_combat_readout, player_status, dummy_status]:
		node.visible = not value
	$Interface/PhaseLabel.visible = not value
	debug_launcher_button.visible = OS.is_debug_build() and not value
	match_controller.pause_match(value)
