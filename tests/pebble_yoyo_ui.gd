extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var touch: Control = load("res://scripts/touch_command_source.gd").new()
	touch.forestlight_controls = true
	touch.simplified_controls = true
	root.add_child(touch)
	await process_frame
	check(touch.ACTIONS.has(&"use_equipment"), "equipment action exists")
	var actor := {"id":"player", "accessory_id":"pebble-yoyo", "state":"IDLE", "equipment_phase":"idle", "equipment_cooldown_ticks":0, "on_floor":true}
	for width: int in [1280,1600]:
		root.size = Vector2i(width,720)
		await process_frame
		for scale: float in [1.0,1.3]:
			touch.apply_accessibility({"text_scale":scale})
			touch.apply_menu_controls({"joystick_mode":"fixed","button_scale":1.2,"button_transparency":0})
			var safe: Rect2 = touch.GEOMETRY.safe_rect(root)
			var regions: Dictionary = touch.diagnostic_regions()
			var equipment: Rect2 = regions[&"use_equipment"]
			check(safe.encloses(equipment), "equipment hit region inside safe area")
			var label: Label = touch._status_labels[&"use_equipment"]
			check(safe.encloses(Rect2(label.position,label.size)), "equipment status inside safe area at max controls")
			for action: StringName in touch.ACTIONS:
				if action != &"use_equipment": check(not equipment.intersects(regions[action]), "equipment never overlaps other button")
	var snapshot := {"fighters":[actor],"physics_ticks_per_second":60}
	var before := snapshot.duplicate(true)
	touch.update_snapshot(snapshot)
	check(touch._status_labels[&"use_equipment"].text == "준비" and not touch._is_action_unready(&"use_equipment"), "equipped ready status")
	check(snapshot == before, "UI cannot mutate source snapshot")
	actor.equipment_cooldown_ticks = 600
	touch.update_snapshot(snapshot)
	check(touch._status_labels[&"use_equipment"].text == "10.0초" and touch._is_action_unready(&"use_equipment"), "cooldown uses server ticks")
	actor.equipment_phase = "extend"
	touch.update_snapshot(snapshot)
	check(touch._status_labels[&"use_equipment"].text == "사용 중" and touch._is_action_unready(&"jump"), "casting label and other action locks")
	actor.equipment_phase = "idle"
	actor.equipment_cooldown_ticks = 0
	actor.accessory_id = ""
	touch.update_snapshot(snapshot)
	check(touch._status_labels[&"use_equipment"].text == "미장착" and touch._is_action_unready(&"use_equipment"), "unequipped distinct from ready")
	actor.accessory_id = "pebble-yoyo"
	actor.state = "HITSTUN"
	touch.update_snapshot(snapshot)
	check(touch._status_labels[&"use_equipment"].text == "행동 불가", "stun unavailable status")
	var region: Rect2 = touch.diagnostic_regions()[&"use_equipment"]
	touch._assign(71, touch._joystick_touch_rect.get_center() + Vector2(60,0))
	touch._assign(72, region.get_center())
	check(Input.is_action_pressed(&"move_right") and Input.is_action_pressed(&"use_equipment"), "movement and equipment touches coexist")
	touch._drag_owned(72,Vector2.ZERO)
	check(Input.is_action_pressed(&"use_equipment"), "action owns contact outside region")
	touch.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not Input.is_action_pressed(&"use_equipment") and not Input.is_action_pressed(&"move_right"), "focus loss releases equipment and direction")
	check(touch._missing_resource_ids.is_empty(), "all button textures resolve")
	var arena: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	var controller: MatchController = arena.get_node("MatchController")
	controller.set_physics_process(false)
	var selection := LoadoutSelection.new()
	selection.character_id = &"ja-hyun"
	selection.accessory_id = &"pebble-yoyo"
	var profile := LoadoutBuilder.build(selection,LocalPlayCatalog.new().combat)
	var fighter := controller.player
	fighter.configure_profile(profile.profile)
	var effect: Node2D = load("res://scripts/equipment_visual.gd").new()
	effect.fighter = fighter
	fighter.add_child(effect)
	effect.has_hand_anchor = true
	effect.hand_local = Vector2(-5,-26)
	fighter.equipment_facing = 1
	fighter.equipment_phase = "extend"
	fighter.equipment_position = fighter.global_position + Vector2(150,-32)
	var state_before := fighter.snapshot().duplicate(true)
	check(effect.display_tip().is_equal_approx(Vector2(150,-32)), "outbound drawing exactly matches authoritative projectile")
	check(fighter.snapshot() == state_before, "display tip cannot change combat state")
	fighter.equipment_phase = "return"
	fighter.equipment_position = fighter.equipment_origin()
	fighter.equipment_phase_tick = 17
	check(effect.display_tip().is_equal_approx(effect.hand_local), "non-hitting return ends in animated palm")
	fighter.equipment_phase = "recovery"
	check(effect.display_tip().is_equal_approx(effect.hand_local), "catch does not jump on return to recovery")
	arena.queue_free()
	touch.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	print("PEBBLE_YOYO_UI: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
