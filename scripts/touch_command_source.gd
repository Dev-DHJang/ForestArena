extends Control
signal diagnostic_event(action: StringName, edge: String)

## A single cardinal pad occupies the lower-left 42% inside the 6.5% safe edge.
const SAFE_EDGE_RATIO := 0.065
const GEOMETRY := preload("res://scripts/combat_ui_geometry.gd")
var local_fighter_id: StringName = &"player"
var safe_area_override := Rect2()
var _status_labels: Dictionary = {}
var _guard_bar: ProgressBar
var _guard_label: Label
var _local_snapshot: Dictionary = {}
var _ultimate_max := 100.0
var _guard_max := 100.0
var _tick_rate := 60.0
const DPAD_IDS := {
	&"": "fa.ui.combat.dpad.default",
	&"move_up": "fa.ui.combat.dpad.up",
	&"move_down": "fa.ui.combat.dpad.down",
	&"move_left": "fa.ui.combat.dpad.left",
	&"move_right": "fa.ui.combat.dpad.right",
}
const ACTION_DEFAULT_ID := "fa.ui.combat.action.default"
const ACTION_PRESSED_ID := "fa.ui.combat.action.pressed"
var ACTIONS: Array[StringName] = [&"dash", &"jump", &"attack_light", &"attack_heavy", &"attack_special"]
var ACTION_LABELS := ["DASH", "JUMP", "LIGHT", "HEAVY", "SPECIAL"]
var extended_actions := false
@export var forestlight_controls := false
const NO_MOVEMENT_POINTER := -2147483648
const FORESTLIGHT_ACTIONS := {&"attack_light": "light", &"attack_heavy": "heavy", &"attack_special": "special", &"jump": "jump", &"dash": "dash", &"evade": "dash", &"ultimate": "special"}
var _movement_pointer := NO_MOVEMENT_POINTER
var _joystick_touch_rect := Rect2()
var _touch_positions: Dictionary[int, Vector2] = {}
var _joystick_knob: TextureRect
var _touch_actions: Dictionary[int, StringName] = {}
var _action_touch_counts: Dictionary[StringName, int] = {}
var _dpad_visual: TextureRect
var _action_visuals: Dictionary[StringName, TextureRect] = {}
var _textures: Dictionary[String, Texture2D] = {}
var _last_dpad_action: StringName = &""
var _missing_resource_ids: PackedStringArray = []
var _missing_label: Label
var text_scale := 1.0


func _ready() -> void:
	if extended_actions:
		ACTIONS = [&"evade", &"jump", &"attack_light", &"attack_heavy", &"attack_special", &"ultimate"]
		ACTION_LABELS = ["회피", "점프", "약", "강", "특수", "궁극기"]
	_load_visual_resources()
	_build_visuals()
	_layout_visuals()
	_refresh_visuals()


func _load_visual_resources() -> void:
	if forestlight_controls:
		for suffix: String in ["neutral", "active", "knob"]:
			var id := "fa.ui.forestlight.joystick." + suffix
			_textures[id] = _resource_texture(id)
		for action: StringName in ACTIONS:
			for state: String in ["default", "pressed", "disabled"]:
				var id := _forestlight_action_id(action, state)
				_textures[id] = _resource_texture(id)
		return
	for logical_id: String in DPAD_IDS.values():
		_textures[logical_id] = _resource_texture(logical_id)
	for logical_id: String in [ACTION_DEFAULT_ID, ACTION_PRESSED_ID]:
		_textures[logical_id] = _resource_texture(logical_id)


func _build_visuals() -> void:
	_dpad_visual = TextureRect.new()
	_dpad_visual.name = "DPadVisual"
	_dpad_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dpad_visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dpad_visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_dpad_visual)
	_add_dpad_label("↑", Vector4(0.4, 0.08, 0.6, 0.30))
	_add_dpad_label("↓", Vector4(0.4, 0.70, 0.6, 0.92))
	_add_dpad_label("←", Vector4(0.08, 0.4, 0.30, 0.6))
	_add_dpad_label("→", Vector4(0.70, 0.4, 0.92, 0.6))
	if forestlight_controls:
		_joystick_knob = TextureRect.new()
		_joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_joystick_knob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_joystick_knob.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_joystick_knob.texture = _textures["fa.ui.forestlight.joystick.knob"]
		add_child(_joystick_knob)
	for index: int in ACTIONS.size():
		var action := ACTIONS[index]
		var visual := TextureRect.new()
		visual.name = "%sVisual" % String(action).to_pascal_case()
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(visual)
		_action_visuals[action] = visual
		_add_centered_label(visual, ACTION_LABELS[index], 15)
	_missing_label = Label.new()
	_missing_label.name = "MissingResources"
	_missing_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_missing_label.add_theme_color_override("font_color", Color.WHITE)
	_missing_label.add_theme_color_override("font_outline_color", Color("72112f"))
	_missing_label.add_theme_constant_override("outline_size", 5)
	_missing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_missing_label)
	_update_missing_label()
	if forestlight_controls:
		_build_status_visuals()


func _add_dpad_label(text: String, anchors: Vector4) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_left = anchors.x
	label.anchor_top = anchors.y
	label.anchor_right = anchors.z
	label.anchor_bottom = anchors.w
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", roundi(26 * text_scale))
	label.add_theme_color_override("font_outline_color", Color("142334"))
	label.add_theme_constant_override("outline_size", 4)
	_dpad_visual.add_child(label)


func _add_centered_label(parent: Control, text: String, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", roundi(font_size * text_scale))
	label.add_theme_color_override("font_outline_color", Color("142334"))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)


func _layout_visuals() -> void:
	var viewport_size := get_viewport_rect().size
	if forestlight_controls:
		var safe := safe_area_override if safe_area_override.has_area() else GEOMETRY.safe_rect(get_viewport())
		var factor := viewport_size.y / 720.0
		_joystick_touch_rect = Rect2(Vector2(safe.position.x + 48 * factor, safe.end.y - 264 * factor), Vector2.ONE * 224 * factor)
		_dpad_visual.position = _joystick_touch_rect.position + Vector2.ONE * 5.333 * factor
		_dpad_visual.size = Vector2.ONE * 213.333 * factor
		_joystick_knob.size = Vector2.ONE * 74.667 * factor
		# Centers and diameters are the single source for the pictures and hit regions.
		var centers := {
			&"attack_light": Vector2(200, 160), &"attack_heavy": Vector2(90, 236),
			&"attack_special": Vector2(306, 208), &"jump": Vector2(104, 60),
			&"dash": Vector2(294, 60), &"evade": Vector2(294, 60),
			&"ultimate": Vector2(218, 310),
		}
		for action: StringName in ACTIONS:
			var diameter := 96.0 if action == &"attack_light" else (64.0 if action == &"ultimate" else 80.0)
			var extent := Vector2.ONE * diameter * factor
			_action_visuals[action].position = safe.end - centers[action] * factor - extent * 0.5
			_action_visuals[action].size = extent
		for action: StringName in _status_labels:
			var visual: TextureRect = _action_visuals[action]
			_status_labels[action].position = visual.position + Vector2(-12 * factor, visual.size.y + 2 * factor)
			_status_labels[action].size = Vector2(visual.size.x + 24 * factor, 28 * factor)
		_guard_bar.position = Vector2(_joystick_touch_rect.end.x + 18 * factor, safe.end.y - 144 * factor)
		_guard_bar.size = Vector2(116, 8) * factor
		_guard_label.position = _guard_bar.position - Vector2(0, 28 * factor)
		_guard_label.size = Vector2(116, 26) * factor
		_missing_label.position = Vector2(viewport_size.x * 0.48, 280 * factor)
		_missing_label.size = Vector2(viewport_size.x * 0.50, 32 * factor)
		_refresh_visuals()
		return
	var pad := Rect2(viewport_size.x * SAFE_EDGE_RATIO, viewport_size.y * 0.58, viewport_size.x * 0.42, viewport_size.y * 0.355)
	var pad_side := minf(pad.size.x, pad.size.y) * 0.84
	_dpad_visual.position = pad.get_center() - Vector2.ONE * pad_side * 0.5
	_dpad_visual.size = Vector2.ONE * pad_side
	for index: int in ACTIONS.size():
		var visual: TextureRect = _action_visuals[ACTIONS[index]]
		visual.position = Vector2(viewport_size.x * (0.51 + index * 0.095), viewport_size.y * 0.76)
		visual.size = Vector2(viewport_size.x * 0.08, viewport_size.y * 0.14)
		if extended_actions:
			visual.position = Vector2(viewport_size.x * (0.64 + (index % 3) * 0.10), viewport_size.y * (0.62 + (index / 3) * 0.17))
	_missing_label.position = Vector2(viewport_size.x * 0.48, viewport_size.y * 0.70)
	_missing_label.size = Vector2(viewport_size.x * 0.50, 32.0)


func handle_pointer_event(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and not touch.canceled: _assign(touch.index, touch.position)
		else: _release(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if forestlight_controls:
			_drag_owned(drag.index, drag.position)
			return
		var next := _action_for(drag.position)
		if _touch_actions.get(drag.index, &"") != next:
			_release(drag.index)
			if not next.is_empty(): _press(drag.index, next)
	elif event is InputEventMouseButton:
		if OS.has_feature("mobile"): return
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed: _assign(-100, button.position)
			else: _release(-100)
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		if OS.has_feature("mobile"): return
		var motion := event as InputEventMouseMotion
		if forestlight_controls:
			_drag_owned(-100, motion.position)
			return
		var next := _action_for(motion.position)
		if _touch_actions.get(-100, &"") != next:
			_release(-100)
			if not next.is_empty(): _press(-100, next)


func release_all_touches() -> void:
	for touch_index: int in _touch_actions.keys(): _release(touch_index)
	_touch_positions.clear()
	_movement_pointer = NO_MOVEMENT_POINTER


func apply_accessibility(settings: Dictionary) -> void:
	text_scale = float(settings.get("text_scale", 1.0))
	for label: Label in find_children("*", "Label", true, false):
		var base_size := 26 if label.text in ["↑", "↓", "←", "→"] else (15 if label.text in ACTION_LABELS else 16)
		label.add_theme_font_size_override("font_size", roundi(base_size * text_scale))


func _assign(index: int, position: Vector2) -> void:
	if forestlight_controls:
		if _touch_actions.has(index): return
		if _joystick_touch_rect.has_point(position):
			if _movement_pointer != NO_MOVEMENT_POINTER: return
			_movement_pointer = index
			_touch_actions[index] = &""
		_touch_positions[index] = position
	var action := _action_for(position)
	if not action.is_empty(): _press(index, action)
	elif forestlight_controls: _refresh_visuals()


func _drag_owned(index: int, position: Vector2) -> void:
	if not _touch_actions.has(index): return
	_touch_positions[index] = position
	if index != _movement_pointer: return # Action ownership survives leaving its button.
	var next := _joystick_action(position)
	if _touch_actions[index] != next:
		_release(index)
		_movement_pointer = index
		_touch_actions[index] = &""
		_touch_positions[index] = position
		if not next.is_empty(): _press(index, next)
	_refresh_visuals()


func _press(index: int, action: StringName) -> void:
	_touch_actions[index] = action
	var count: int = _action_touch_counts.get(action, 0) + 1
	_action_touch_counts[action] = count
	if count == 1: Input.action_press(action)
	if action in DPAD_IDS:
		_last_dpad_action = action
	_refresh_visuals()
	print("FOREST_ARENA_TOUCH action=%s edge=press pointer=%d" % [action, index])
	diagnostic_event.emit(action, "press")


func _release(index: int) -> void:
	if not _touch_actions.has(index): return
	var action: StringName = _touch_actions[index]
	_touch_actions.erase(index)
	_touch_positions.erase(index)
	if _movement_pointer == index: _movement_pointer = NO_MOVEMENT_POINTER
	if action.is_empty():
		_refresh_visuals()
		return
	var count := maxi(_action_touch_counts.get(action, 1) - 1, 0)
	_action_touch_counts[action] = count
	if count == 0: Input.action_release(action)
	if action == _last_dpad_action and count == 0:
		_last_dpad_action = _held_dpad_action()
	_refresh_visuals()
	print("FOREST_ARENA_TOUCH action=%s edge=release pointer=%d" % [action, index])
	diagnostic_event.emit(action, "release")


func _held_dpad_action() -> StringName:
	for action: StringName in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		if int(_action_touch_counts.get(action, 0)) > 0:
			return action
	return &""


func _refresh_visuals() -> void:
	if _dpad_visual == null:
		return
	if forestlight_controls:
		_dpad_visual.texture = _textures.get("fa.ui.forestlight.joystick.neutral" if _last_dpad_action.is_empty() else "fa.ui.forestlight.joystick.active")
		if _joystick_knob != null:
			var offset: Vector2 = _touch_positions.get(_movement_pointer, _joystick_touch_rect.get_center()) - _joystick_touch_rect.get_center()
			offset = offset.limit_length(29.333 * get_viewport_rect().size.y / 720.0)
			_joystick_knob.position = _joystick_touch_rect.get_center() + offset - _joystick_knob.size * 0.5
		for action: StringName in ACTIONS:
			_action_visuals[action].texture = _textures.get(_forestlight_action_id(action, "pressed" if int(_action_touch_counts.get(action, 0)) > 0 else ("disabled" if _is_action_unready(action) else "default")))
		return
	_dpad_visual.texture = _textures.get(DPAD_IDS.get(_last_dpad_action, DPAD_IDS[&""]))
	for action: StringName in ACTIONS:
		var state_id := ACTION_PRESSED_ID if int(_action_touch_counts.get(action, 0)) > 0 else ACTION_DEFAULT_ID
		(_action_visuals[action] as TextureRect).texture = _textures.get(state_id)


func _resource_texture(logical_id: String) -> Texture2D:
	var texture := ForestArenaResources.load_texture(logical_id)
	if texture != null:
		return texture
	if logical_id not in _missing_resource_ids:
		_missing_resource_ids.append(logical_id)
	var image := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color("a22654"))
	return ImageTexture.create_from_image(image)


func _update_missing_label() -> void:
	if _missing_label == null:
		return
	_missing_label.text = "MISSING RESOURCE: %s" % ", ".join(_missing_resource_ids) if not _missing_resource_ids.is_empty() else ""


func _action_for(position: Vector2) -> StringName:
	if forestlight_controls:
		var safe := safe_area_override if safe_area_override.has_area() else GEOMETRY.safe_rect(get_viewport())
		if not safe.has_point(position): return &""
		for action: StringName in ACTIONS:
			if Rect2(_action_visuals[action].position, _action_visuals[action].size).has_point(position): return action
		return _joystick_action(position) if _joystick_touch_rect.has_point(position) else &""
	var size := get_viewport_rect().size
	var normalized := position / size
	if normalized.x < SAFE_EDGE_RATIO or normalized.x > 1.0 - SAFE_EDGE_RATIO or normalized.y < 0.58: return &""
	if extended_actions and normalized.x >= 0.50:
		for action: StringName in ACTIONS:
			var visual: TextureRect = _action_visuals[action]
			if Rect2(visual.position, visual.size).has_point(position): return action
		return &""
	var pad := Rect2(size.x * SAFE_EDGE_RATIO, size.y * 0.58, size.x * 0.42, size.y * 0.355)
	if pad.has_point(position):
		var delta := position - pad.get_center()
		if delta.length() < minf(pad.size.x, pad.size.y) * 0.20: return &""
		if absf(delta.x) >= absf(delta.y): return &"move_right" if delta.x > 0.0 else &"move_left"
		return &"move_down" if delta.y > 0.0 else &"move_up"
	if extended_actions: return &""
	var usable := inverse_lerp(size.x * 0.50, size.x * (1.0 - SAFE_EDGE_RATIO), position.x)
	if usable < 0.20: return &"dash"
	if usable < 0.40: return &"jump"
	if usable < 0.60: return &"attack_light"
	if usable < 0.80: return &"attack_heavy"
	return &"attack_special"


func _joystick_action(position: Vector2) -> StringName:
	var offset := position - _joystick_touch_rect.get_center()
	if offset.length() < _joystick_touch_rect.size.x * 0.20: return &""
	if absf(offset.x) >= absf(offset.y): return &"move_right" if offset.x > 0 else &"move_left"
	return &"move_down" if offset.y > 0 else &"move_up"


func _forestlight_action_id(action: StringName, state: String) -> String:
	var key: String = FORESTLIGHT_ACTIONS[action]
	return "fa.ui.forestlight.%s.%s" % [key, state] if key == "primary" else "fa.ui.forestlight.action.%s.%s" % [key, state]


func diagnostic_regions() -> Dictionary:
	var result := {}
	var pad := _joystick_touch_rect if forestlight_controls else Rect2(get_viewport_rect().size * Vector2(SAFE_EDGE_RATIO, 0.58), get_viewport_rect().size * Vector2(0.42, 0.355))
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		var direction := {&"move_left": Vector2.LEFT, &"move_right": Vector2.RIGHT, &"move_up": Vector2.UP, &"move_down": Vector2.DOWN}[action] as Vector2
		var center := pad.get_center() + direction * minf(pad.size.x, pad.size.y) * 0.35
		result[action] = Rect2(center - Vector2.ONE * 12, Vector2.ONE * 24)
	for action: StringName in ACTIONS:
		result[action] = Rect2(_action_visuals[action].position, _action_visuals[action].size)
	return result


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED: release_all_touches()
	elif what in [NOTIFICATION_RESIZED, NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED] and _dpad_visual != null:
		if what == NOTIFICATION_RESIZED: release_all_touches()
		_layout_visuals()


func _build_status_visuals() -> void:
	for action: StringName in [&"attack_special", &"ultimate"]:
		if not _action_visuals.has(action): continue
		var label := Label.new()
		label.name = "SpecialReadiness" if action == &"attack_special" else "UltimateReadiness"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color("f4f9ee"))
		label.add_theme_color_override("font_outline_color", Color("122d38"))
		label.add_theme_constant_override("outline_size", 3)
		add_child(label)
		_status_labels[action] = label
	_guard_bar = ProgressBar.new()
	_guard_bar.name = "LocalGuardBar"
	_guard_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guard_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("9ad8e3")
	var track := StyleBoxFlat.new()
	track.bg_color = Color("163d35")
	_guard_bar.add_theme_stylebox_override("fill", fill)
	_guard_bar.add_theme_stylebox_override("background", track)
	add_child(_guard_bar)
	_guard_label = Label.new()
	_guard_label.name = "LocalGuardLabel"
	_guard_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guard_label.add_theme_color_override("font_color", Color("f4f9ee"))
	_guard_label.add_theme_color_override("font_outline_color", Color("122d38"))
	_guard_label.add_theme_constant_override("outline_size", 3)
	add_child(_guard_label)
	apply_accessibility({"text_scale": text_scale})


## Read-only readiness cues never block or synthesize a combat command.
func update_snapshot(snapshot: Dictionary) -> void:
	if not forestlight_controls: return
	_local_snapshot = {}
	for fighter: Dictionary in snapshot.get("fighters", []):
		if StringName(fighter.get("id", "")) == local_fighter_id:
			_local_snapshot = fighter.duplicate(true)
			break
	_guard_max = maxf(1, float(snapshot.get("guard_max", 100)))
	_ultimate_max = maxf(1, float(snapshot.get("ultimate_gauge_max", 100)))
	_tick_rate = maxf(1, float(snapshot.get("physics_ticks_per_second", 60)))
	_guard_bar.visible = not _local_snapshot.is_empty()
	_guard_label.visible = _guard_bar.visible
	if _local_snapshot.is_empty():
		for label: Label in _status_labels.values(): label.text = ""
		_refresh_visuals()
		return
	_guard_bar.max_value = _guard_max
	_guard_bar.value = float(_local_snapshot.get("guard_durability", 0))
	_guard_label.text = "가드 %d%%" % roundi(_guard_bar.value / _guard_max * 100)
	if _status_labels.has(&"attack_special"):
		var cooldown := int(_local_snapshot.get("special_cooldown_ticks", 0))
		_status_labels[&"attack_special"].text = "준비" if cooldown <= 0 else "%.1f초" % (float(cooldown) / _tick_rate)
	if _status_labels.has(&"ultimate"):
		var used := bool(_local_snapshot.get("ultimate_used_this_stock", false))
		var gauge := float(_local_snapshot.get("ultimate_gauge", 0))
		_status_labels[&"ultimate"].text = "사용함" if used else ("준비" if gauge >= _ultimate_max else "%d%%" % roundi(gauge / _ultimate_max * 100))
	_refresh_visuals()


func _is_action_unready(action: StringName) -> bool:
	if _local_snapshot.is_empty(): return false
	if action == &"attack_special": return int(_local_snapshot.get("special_cooldown_ticks", 0)) > 0
	if action == &"ultimate": return bool(_local_snapshot.get("ultimate_used_this_stock", false)) or float(_local_snapshot.get("ultimate_gauge", 0)) < _ultimate_max
	return false
