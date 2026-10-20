extends "res://tests/two_fighter_combat_v2.gd"

func run() -> void:
	scene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	root.get_node("ForestArenaAudio").call("set_levels", 0.0, 0.0, true, false)
	controller = scene.get_node("MatchController") as MatchController
	controller.set_physics_process(false)
	controller.bot_source = null
	controller.rules = RULES.duplicate(true)
	catalog = LocalPlayCatalog.new().combat
	controller.presentation_event.connect(func(id: StringName, payload: Dictionary) -> void:
		if id == &"hit_resolved": events.append(payload.duplicate(true)))
	setup()
	var target := controller.training_dummy
	move_to_air(Vector2(600, 200), Vector2(1900, 200))
	target.apply_hit(attack_by_action(controller.player, &"attack_light", true), Vector2(0, -100), 30, controller.rules)
	target.air_lock_ticks = 2
	target.step_tick(controller.rules)
	target.step_tick(controller.rules)
	check(target.air_lock == 0 and target.air_lock_expired and target.hitstun_ticks == 28 and target.state == FighterController.State.HITSTUN, "timeout preserves ordinary hitstun independently")
	print("PROBE timeout: lock=%s ordinary=%s state=%s" % [target.air_lock, target.hitstun_ticks, target.state])
	setup()
	target = controller.training_dummy
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = Vector2(1940, 250)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(20, 500)
	shape.shape = rectangle
	wall.add_child(shape)
	scene.get_node("World").add_child(wall)
	await physics_frame
	move_to_air(Vector2(600, 200), Vector2(1900, 200))
	target.air_light_used = true
	target.air_heavy_used = true
	target.apply_hit(attack_by_action(controller.player, &"attack_light", true), Vector2(500, -100), 40, controller.rules)
	for ignored: int in 10: target.step_tick(controller.rules)
	check(target.is_on_wall() and not target.is_on_floor() and target.air_light_used and target.air_heavy_used and target.air_lock == 1 and target.air_lock_ticks == 110, "side wall contact does not restore flight budget or clear air status")
	print("PROBE wall: wall=%s floor=%s spent=%s/%s lock=%s ticks=%s" % [target.is_on_wall(), target.is_on_floor(), target.air_light_used, target.air_heavy_used, target.air_lock, target.air_lock_ticks])
	wall.queue_free()
	await physics_frame
	setup()
	var source := controller.player
	target = controller.training_dummy
	target.global_position.x = 1500
	press(source, &"attack_special")
	steps(45)
	target.global_position = Vector2(800, 572)
	var hp := target.current_hp
	steps(26)
	check(events.size() > 0 and events.size() < 10 and target.velocity.x > 0 and hp-target.current_hp == events.size()+4, "late entrant gets final global push, not its own tenth hit")
	print("PROBE late pulses: hits=%s damage=%s velocity=%s" % [events.size(), hp-target.current_hp, target.velocity])
	setup(&"nabi", &"ja-hyun")
	source = controller.player
	target = controller.training_dummy
	target.global_position.x = 720
	press(source, &"attack_special")
	steps(10)
	var fixed_end := source.attack_travel_end
	check(source.attack_travel_active and is_equal_approx(fixed_end.x, 784), "capture target endpoint at first active tick")
	target.global_position.x = 1100
	steps(23)
	check(is_equal_approx(source.global_position.x, fixed_end.x) and source.attack_travel_end == fixed_end and events.is_empty(), "moving target does not chase or move captured endpoint; back strike misses")
	print("PROBE endpoint: endpoint=%s actual=%s hits=%s" % [fixed_end, source.global_position, events.size()])
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("INDEPENDENT_CORE_BOUNDARIES: PASS")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)
