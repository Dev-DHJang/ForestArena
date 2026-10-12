extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
 if not ok: failures.append(message)
func _initialize() -> void:
 call_deferred('run')
func run() -> void:
 root.size = Vector2i(1280,720)
 var touch: Control = load('res://scripts/touch_command_source.gd').new()
 touch.extended_actions = true
 touch.forestlight_controls = true
 root.add_child(touch)
 await process_frame
 var pad: Rect2 = touch._joystick_touch_rect
 var neutral := pad.get_center()
 var right := neutral + Vector2(pad.size.x*.35,0)
 var left := neutral - Vector2(pad.size.x*.35,0)
 var attack: Rect2 = touch.diagnostic_regions()[&'attack_light']
 touch._assign(1,neutral)
 touch._assign(2,left)
 check(touch._movement_pointer==1 and not Input.is_action_pressed(&'move_left'),'second movement finger cannot steal neutral owner')
 touch._drag_owned(1,right)
 check(Input.is_action_pressed(&'move_right'),'owned thumb drag produces cardinal direction')
 touch._assign(3,attack.get_center())
 check(Input.is_action_pressed(&'move_right') and Input.is_action_pressed(&'attack_light'),'physical movement and attack contacts coexist')
 touch._drag_owned(3,Vector2.ZERO)
 check(Input.is_action_pressed(&'attack_light'),'action pointer remains owned outside button')
 touch._release(3)
 check(not Input.is_action_pressed(&'attack_light') and Input.is_action_pressed(&'move_right'),'action release preserves owned movement')
 touch._drag_owned(1,attack.get_center())
 check(not Input.is_action_pressed(&'attack_light'),'movement thumb cannot turn into attack when leaving joystick')
 touch._release(1)
 check(touch._movement_pointer==touch.NO_MOVEMENT_POINTER and touch._touch_actions.is_empty() and not Input.is_action_pressed(&'move_right'),'release resets joystick ownership and semantic movement')
 touch._assign(4,left)
 touch._assign(5,attack.get_center())
 var cancel := InputEventScreenTouch.new()
 cancel.index=4
 cancel.canceled=true
 touch.handle_pointer_event(cancel)
 check(not Input.is_action_pressed(&'move_left') and Input.is_action_pressed(&'attack_light'),'pointer cancel releases only that contact')
 touch.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(touch._touch_actions.is_empty() and not Input.is_action_pressed(&'attack_light'),'focus loss clears all remaining contacts')
 check(touch._missing_resource_ids.is_empty(),'approved joystick and every action skin resolves')
 for action: StringName in touch.ACTIONS:
  var rect: Rect2=touch.diagnostic_regions()[action]
  check(touch._action_for(rect.get_center())==action and touch.get_viewport_rect().has_point(rect.get_center()),'actual diagnostic center hits '+String(action))
 touch.queue_free()
 await process_frame
 for failure: String in failures: push_error(failure)
 print('FORESTLIGHT_TOUCH_INPUT: '+('PASS' if failures.is_empty() else 'FAIL'))
 quit(0 if failures.is_empty() else 1)
