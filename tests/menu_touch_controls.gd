extends SceneTree
const STORE := preload("res://scripts/premium_menu/local_menu_state_store.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func contact(touch: Control, index: int, point: Vector2, pressed: bool = true, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	touch.handle_pointer_event(event)

func drag(touch: Control, index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	touch.handle_pointer_event(event)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var touch: Control = load("res://scripts/touch_command_source.gd").new()
	touch.extended_actions = true
	touch.forestlight_controls = true
	# The API can be called before visual nodes exist.
	touch.apply_menu_controls(STORE.default_controls())
	root.add_child(touch)
	await process_frame
	var safe: Rect2 = touch.GEOMETRY.safe_rect(root)
	var factor: float = touch.get_viewport_rect().size.y / 720.0
	var original_pad := Rect2(Vector2(safe.position.x + 48 * factor, safe.end.y - 264 * factor), Vector2.ONE * 224 * factor)
	check(touch._joystick_touch_rect.is_equal_approx(original_pad), "default joystick geometry stays exactly compatible")
	var original_light: Rect2 = touch.diagnostic_regions()[&"attack_light"]
	check(original_light.size.is_equal_approx(Vector2.ONE * 96 * factor) and original_light.get_center().is_equal_approx(safe.end - Vector2(200, 160) * factor), "default curved action layout remains compatible")
	var max_settings := {"joystick_mode": "fixed", "button_scale": 1.2, "button_transparency": 50}
	touch.apply_menu_controls(max_settings)
	check(touch.diagnostic_regions()[&"attack_light"].size.is_equal_approx(original_light.size * 1.2), "maximum setting enlarges actual attack hit region")
	check(touch._joystick_touch_rect.size.is_equal_approx(original_pad.size * 1.2), "joystick art and input scale together")
	check(is_equal_approx(touch._dpad_visual.modulate.a, 0.5) and is_equal_approx(touch._joystick_knob.modulate.a, 0.5), "joystick opacity follows saved transparency")
	for action: StringName in touch.ACTIONS:
		var region: Rect2 = touch.diagnostic_regions()[action]
		var picture: TextureRect = touch._action_visuals[action]
		check(Rect2(picture.position, picture.size).is_equal_approx(region), "picture matches hit area for " + String(action))
		check(is_equal_approx(picture.modulate.a, 0.5), "maximum transparency keeps button label at least half opacity")
		contact(touch, 1, region.get_center())
		check(Input.is_action_pressed(action), "actual action center presses " + String(action))
		contact(touch, 1, Vector2.ZERO, false)
		check(not Input.is_action_pressed(action), "pointer release clears " + String(action))
	check(is_equal_approx(touch._guard_label.modulate.a, 1.0) and is_equal_approx(touch._status_labels[&"ultimate"].modulate.a, 1.0), "guard and readiness text keep full legibility")
	# Hit the newly added edge, beyond the previous size.
	var expanded: Rect2 = touch.diagnostic_regions()[&"attack_light"]
	var added_edge := expanded.get_center() + Vector2(expanded.size.x * 0.46, 0)
	check(not original_light.has_point(added_edge), "edge test reaches outside old attack region")
	contact(touch, 2, added_edge)
	check(Input.is_action_pressed(&"attack_light"), "enlarged picture edge is a real touch target")
	touch.apply_menu_controls(STORE.default_controls())
	check(not Input.is_action_pressed(&"attack_light") and touch._touch_actions.is_empty(), "applying settings releases previous contact")
	var unchanged: Dictionary = touch.menu_controls.duplicate(true)
	touch.apply_menu_controls({"joystick_mode":"fixed","button_scale":1.03,"button_transparency":0})
	check(touch.menu_controls == unchanged, "invalid preview does not change controls")
	# Different contacts retain movement, action and per-action reference counts.
	var pad: Rect2 = touch._joystick_touch_rect
	var right := pad.get_center() + Vector2(pad.size.x * 0.35, 0)
	var light: Rect2 = touch.diagnostic_regions()[&"attack_light"]
	contact(touch, 10, right)
	contact(touch, 11, light.get_center())
	contact(touch, 12, light.get_center())
	contact(touch, 11, Vector2.ZERO, false)
	check(Input.is_action_pressed(&"attack_light") and Input.is_action_pressed(&"move_right"), "one action contact release preserves another contact and movement")
	contact(touch, 10, Vector2.ZERO, false, true)
	check(not Input.is_action_pressed(&"move_right") and Input.is_action_pressed(&"attack_light"), "cancel movement finger preserves action finger")
	touch.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(touch._touch_actions.is_empty() and not Input.is_action_pressed(&"attack_light"), "focus loss releases every semantic input")
	# Wide landscape with a simulated left notch and right gesture inset.
	root.size = Vector2i(1600, 720)
	await process_frame
	var screen: Rect2 = touch.get_viewport_rect()
	touch.safe_area_override = Rect2(Vector2(96, 48), screen.size - Vector2(144, 96))
	max_settings.joystick_mode = "floating"
	touch.apply_menu_controls(max_settings)
	var activation: Rect2 = touch._floating_activation_rect
	var start := activation.position + Vector2(8, 8)
	contact(touch, 20, start)
	check(touch._movement_pointer == 20 and touch._touch_actions[20] == &"", "first floating contact starts neutral even at safe-region edge")
	var floating_pad: Rect2 = touch._joystick_touch_rect
	check(activation.encloses(floating_pad) and touch.safe_area_override.encloses(floating_pad), "maximum floating joystick remains inside reserved safe region")
	contact(touch, 21, activation.end - Vector2.ONE * 8)
	check(touch._movement_pointer == 20 and not touch._touch_actions.has(21), "second movement finger cannot steal floating owner")
	var attack: Rect2 = touch.diagnostic_regions()[&"attack_light"]
	contact(touch, 22, attack.get_center())
	drag(touch, 20, start + Vector2(floating_pad.size.x * 0.4, 0))
	check(Input.is_action_pressed(&"move_right") and Input.is_action_pressed(&"attack_light"), "floating thumb movement coexists with another action contact")
	check(touch._joystick_touch_rect.is_equal_approx(floating_pad), "cardinal changes retain floating origin")
	drag(touch, 20, start + Vector2(-floating_pad.size.x * 0.4, 0))
	check(Input.is_action_pressed(&"move_left") and not Input.is_action_pressed(&"move_right"), "floating drag reverses cardinal direction")
	drag(touch, 22, Vector2.ZERO)
	check(Input.is_action_pressed(&"attack_light"), "action ownership survives dragging outside safe area")
	contact(touch, 20, Vector2.ZERO, false, true)
	check(touch._movement_pointer == touch.NO_MOVEMENT_POINTER and not Input.is_action_pressed(&"move_left") and Input.is_action_pressed(&"attack_light"), "floating cancel releases just the owned movement")
	contact(touch, 22, Vector2.ZERO, false)
	contact(touch, 23, Vector2(activation.end.x + 10, activation.get_center().y))
	check(touch._movement_pointer == touch.NO_MOVEMENT_POINTER, "floating cannot start beyond reserved left region")
	contact(touch, 23, Vector2.ZERO, false)
	contact(touch, 24, activation.get_center())
	drag(touch, 24, activation.get_center() + Vector2(120, 0))
	touch.notification(Control.NOTIFICATION_RESIZED)
	check(touch._movement_pointer == touch.NO_MOVEMENT_POINTER and touch._touch_actions.is_empty() and not Input.is_action_pressed(&"move_right"), "screen resize clears floating inputs")
	for action: StringName in touch.ACTIONS:
		check(touch.safe_area_override.encloses(touch.diagnostic_regions()[action]), "maximum action size fits 20:9 notch safe region")
	contact(touch, 25, activation.get_center())
	drag(touch, 25, activation.get_center() + Vector2(120, 0))
	touch.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(touch._touch_actions.is_empty() and not Input.is_action_pressed(&"move_right"), "application pause releases movement")
	touch.queue_free()
	await process_frame
	var legacy: Control = load("res://scripts/touch_command_source.gd").new()
	root.add_child(legacy)
	await process_frame
	var old_region: Rect2 = legacy.diagnostic_regions()[&"attack_light"]
	legacy.apply_menu_controls(max_settings)
	check(legacy.diagnostic_regions()[&"attack_light"].is_equal_approx(old_region) and is_equal_approx(legacy._action_visuals[&"attack_light"].modulate.a, 1.0), "legacy non-Forestlight control layout is unchanged")
	legacy.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	print("MENU_TOUCH_CONTROLS: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
