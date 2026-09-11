extends Control

## A single cardinal pad occupies the lower-left 42% inside the 6.5% safe edge.
const SAFE_EDGE_RATIO := 0.065
var _touch_actions: Dictionary[int, StringName] = {}
var _action_touch_counts: Dictionary[StringName, int] = {}


func _ready() -> void:
	queue_redraw()


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
	for touch_index: int in _touch_actions.keys(): _release(touch_index)


func _assign(index: int, position: Vector2) -> void:
	var action := _action_for(position)
	if not action.is_empty(): _press(index, action)


func _press(index: int, action: StringName) -> void:
	_touch_actions[index] = action
	var count: int = _action_touch_counts.get(action, 0) + 1
	_action_touch_counts[action] = count
	if count == 1: Input.action_press(action)
	print("FOREST_ARENA_TOUCH action=%s edge=press pointer=%d" % [action, index])


func _release(index: int) -> void:
	if not _touch_actions.has(index): return
	var action: StringName = _touch_actions[index]
	_touch_actions.erase(index)
	var count := maxi(_action_touch_counts.get(action, 1) - 1, 0)
	_action_touch_counts[action] = count
	if count == 0: Input.action_release(action)
	print("FOREST_ARENA_TOUCH action=%s edge=release pointer=%d" % [action, index])


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
	var usable := inverse_lerp(size.x * 0.50, size.x * (1.0 - SAFE_EDGE_RATIO), position.x)
	if usable < 0.20: return &"dash"
	if usable < 0.40: return &"jump"
	if usable < 0.60: return &"attack_light"
	if usable < 0.80: return &"attack_heavy"
	return &"attack_special"


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED: release_all_touches()


func _draw() -> void:
	var size := get_viewport_rect().size
	var pad := Rect2(size.x * SAFE_EDGE_RATIO, size.y * 0.58, size.x * 0.42, size.y * 0.355)
	draw_circle(pad.get_center(), minf(pad.size.x, pad.size.y) * 0.42, Color(0.13, 0.18, 0.28, 0.72))
	for item: Dictionary in [{"text": "↑", "offset": Vector2(-8, -42)}, {"text": "↓", "offset": Vector2(-8, 52)}, {"text": "←", "offset": Vector2(-68, 6)}, {"text": "→", "offset": Vector2(48, 6)}]:
		draw_string(ThemeDB.fallback_font, pad.get_center() + item.offset, item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	var labels := ["ACTION", "JUMP", "LIGHT", "HEAVY", "SPECIAL"]
	for index: int in 5:
		var rect := Rect2(size.x * (0.51 + index * 0.095), size.y * 0.76, size.x * 0.08, size.y * 0.14)
		draw_rect(rect, Color(0.13, 0.18, 0.28, 0.72), true)
		draw_rect(rect, Color(0.62, 0.72, 0.86, 0.65), false, 2.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.58), labels[index], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 15, Color.WHITE)
