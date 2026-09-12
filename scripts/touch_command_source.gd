extends Control

## A single cardinal pad occupies the lower-left 42% inside the 6.5% safe edge.
const SAFE_EDGE_RATIO := 0.065
const DPAD_IDS := {
	&"": "fa.ui.combat.dpad.default",
	&"move_up": "fa.ui.combat.dpad.up",
	&"move_down": "fa.ui.combat.dpad.down",
	&"move_left": "fa.ui.combat.dpad.left",
	&"move_right": "fa.ui.combat.dpad.right",
}
const ACTION_DEFAULT_ID := "fa.ui.combat.action.default"
const ACTION_PRESSED_ID := "fa.ui.combat.action.pressed"
const ACTIONS: Array[StringName] = [&"dash", &"jump", &"attack_light", &"attack_heavy", &"attack_special", &"grab_support", &"ultimate"]
const ACTION_LABELS := ["ACTION", "JUMP", "LIGHT", "HEAVY", "SPECIAL", "GRAB", "ULT"]
## Normalized rectangles keep every action inside the right-hand safe area while
## preserving the Phase 1 five-button layout as a compact staggered cluster.
const ACTION_RECTS := {
	&"dash": Rect2(0.50, 0.79, 0.075, 0.14),
	&"jump": Rect2(0.59, 0.68, 0.075, 0.14),
	&"attack_light": Rect2(0.68, 0.79, 0.075, 0.14),
	&"attack_heavy": Rect2(0.77, 0.68, 0.075, 0.14),
	&"attack_special": Rect2(0.86, 0.79, 0.075, 0.14),
	&"grab_support": Rect2(0.86, 0.58, 0.075, 0.14),
	&"ultimate": Rect2(0.77, 0.49, 0.075, 0.14),
}
var _touch_actions: Dictionary[int, StringName] = {}
var _action_touch_counts: Dictionary[StringName, int] = {}
var _dpad_visual: TextureRect
var _action_visuals: Dictionary[StringName, TextureRect] = {}
var _textures: Dictionary[String, Texture2D] = {}
var _last_dpad_action: StringName = &""
var _missing_resource_ids: PackedStringArray = []
var _missing_label: Label
var _action_visibility: Dictionary[StringName, bool] = {}


func _ready() -> void:
	_ensure_phase3_input_actions()
	for action: StringName in ACTIONS:
		_action_visibility[action] = action != &"grab_support"
	_load_visual_resources()
	_build_visuals()
	_layout_visuals()
	_refresh_visuals()


func _load_visual_resources() -> void:
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
	label.add_theme_font_size_override("font_size", 26)
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
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color("142334"))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)


func _layout_visuals() -> void:
	var viewport_size := get_viewport_rect().size
	var pad := Rect2(viewport_size.x * SAFE_EDGE_RATIO, viewport_size.y * 0.58, viewport_size.x * 0.42, viewport_size.y * 0.355)
	var pad_side := minf(pad.size.x, pad.size.y) * 0.84
	_dpad_visual.position = pad.get_center() - Vector2.ONE * pad_side * 0.5
	_dpad_visual.size = Vector2.ONE * pad_side
	for index: int in ACTIONS.size():
		var action: StringName = ACTIONS[index]
		var visual: TextureRect = _action_visuals[action]
		var normalized: Rect2 = ACTION_RECTS[action]
		visual.position = normalized.position * viewport_size
		visual.size = normalized.size * viewport_size
	_missing_label.position = Vector2(viewport_size.x * 0.48, viewport_size.y * 0.70)
	_missing_label.size = Vector2(viewport_size.x * 0.50, 32.0)


func handle_pointer_event(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed: _assign(touch.index, touch.position)
		else: _release(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
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
		var next := _action_for(motion.position)
		if _touch_actions.get(-100, &"") != next:
			_release(-100)
			if not next.is_empty(): _press(-100, next)


func release_all_touches() -> void:
	for touch_index: int in _touch_actions.keys():
		_release(touch_index)
	# Also clear actions pressed by a keyboard/controller before focus loss. Main
	# repeats this defensively because mobile pause notifications can arrive in
	# either node order.
	for action: StringName in ACTIONS:
		Input.action_release(action)
		_action_touch_counts[action] = 0
	_last_dpad_action = &""
	_refresh_visuals()


func set_action_visible(action: StringName, visible: bool) -> void:
	if action not in ACTIONS:
		return
	_action_visibility[action] = visible
	var visual: TextureRect = _action_visuals.get(action)
	if visual != null:
		visual.visible = visible
	if not visible:
		for touch_index: int in _touch_actions.keys():
			if _touch_actions[touch_index] == action:
				_release(touch_index)


func is_action_visible(action: StringName) -> bool:
	return bool(_action_visibility.get(action, false))


func _ensure_phase3_input_actions() -> void:
	# project.godot remains the durable input contract. Runtime registration lets
	# this isolated UI stay safe while the v2 combat contract lands in parallel.
	for action: StringName in [&"grab_support", &"ultimate"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)


func _assign(index: int, position: Vector2) -> void:
	var action := _action_for(position)
	if not action.is_empty(): _press(index, action)


func _press(index: int, action: StringName) -> void:
	_touch_actions[index] = action
	var count: int = _action_touch_counts.get(action, 0) + 1
	_action_touch_counts[action] = count
	if count == 1: Input.action_press(action)
	if action in DPAD_IDS:
		_last_dpad_action = action
	_refresh_visuals()
	print("FOREST_ARENA_TOUCH action=%s edge=press pointer=%d" % [action, index])


func _release(index: int) -> void:
	if not _touch_actions.has(index): return
	var action: StringName = _touch_actions[index]
	_touch_actions.erase(index)
	var count := maxi(_action_touch_counts.get(action, 1) - 1, 0)
	_action_touch_counts[action] = count
	if count == 0: Input.action_release(action)
	if action == _last_dpad_action and count == 0:
		_last_dpad_action = _held_dpad_action()
	_refresh_visuals()
	print("FOREST_ARENA_TOUCH action=%s edge=release pointer=%d" % [action, index])


func _held_dpad_action() -> StringName:
	for action: StringName in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		if int(_action_touch_counts.get(action, 0)) > 0:
			return action
	return &""


func _refresh_visuals() -> void:
	if _dpad_visual == null:
		return
	_dpad_visual.texture = _textures.get(DPAD_IDS.get(_last_dpad_action, DPAD_IDS[&""]))
	for action: StringName in ACTIONS:
		var state_id := ACTION_PRESSED_ID if int(_action_touch_counts.get(action, 0)) > 0 else ACTION_DEFAULT_ID
		var visual := _action_visuals[action] as TextureRect
		visual.texture = _textures.get(state_id)
		visual.visible = bool(_action_visibility.get(action, true))


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
	var size := get_viewport_rect().size
	var normalized := position / size
	if normalized.x < SAFE_EDGE_RATIO or normalized.x > 1.0 - SAFE_EDGE_RATIO or normalized.y < 0.58: return &""
	var pad := Rect2(size.x * SAFE_EDGE_RATIO, size.y * 0.58, size.x * 0.42, size.y * 0.355)
	if pad.has_point(position):
		var delta := position - pad.get_center()
		if delta.length() < minf(pad.size.x, pad.size.y) * 0.20: return &""
		if absf(delta.x) >= absf(delta.y): return &"move_right" if delta.x > 0.0 else &"move_left"
		return &"move_down" if delta.y > 0.0 else &"move_up"
	for action: StringName in ACTIONS:
		if not bool(_action_visibility.get(action, true)):
			continue
		var normalized_rect: Rect2 = ACTION_RECTS[action]
		var action_rect := Rect2(normalized_rect.position * size, normalized_rect.size * size)
		if action_rect.has_point(position):
			return action
	return &""


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED: release_all_touches()
	elif what == NOTIFICATION_RESIZED and _dpad_visual != null:
		_layout_visuals()
