extends "res://tests/two_fighter_combat_v2.gd"
## Real match input regressions: action windows, displacement, down and recovery.
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	super.check(ok, message)

func run() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	root.get_node("ForestArenaAudio").call("set_levels", 0.0, 0.0, true, false)
	controller = scene.get_node("MatchController")
	controller.set_physics_process(false)
	controller.bot_source = null
	controller.rules = RULES.duplicate(true)
	catalog = LocalPlayCatalog.new().combat
	controller.presentation_event.connect(func(id: StringName, payload: Dictionary) -> void:
		if id == &"hit_resolved": events.append(payload.duplicate(true)))
	_test_continuous_chains()
	_test_down_and_wakeup()
	_test_edge_displacement()
	_test_cancelled_reservation()
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("COMBAT_MOTION_NATURALNESS: PASS (%d checks)" % checks)
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)

func landed_by(fighter: FighterController) -> Array[Dictionary]:
	return events.filter(func(e: Dictionary) -> bool: return e.attacker_id == fighter.fighter_id and e.result == "HIT")

func _test_continuous_chains() -> void:
	for source_id: StringName in [&"ja-hyun", &"nabi"]:
		for target_id: StringName in [&"ja-hyun", &"nabi"]:
			for facing: int in [-1, 1]:
				for distance: float in [55.0, 65.0]:
					for escape: StringName in [&"attack_light", &"guard", &"jump", &"move"]:
						setup(source_id, target_id)
						var source := controller.player
						var target := controller.training_dummy
						source.facing = facing
						target.global_position.x = source.global_position.x + distance * facing
						var previous_hits := 0
						var first_tick := -1
						press(source, &"attack_light")
						for tick: int in 130:
							var hit_count := landed_by(source).size()
							if hit_count == source.runtime_profile.move_set.combo_count: break
							if hit_count > 0:
								check(target.state == FighterController.State.HITSTUN, "no actionable gap %s/%s %s distance%d %s" % [source_id,target_id,facing,distance,escape])
								press(target, escape, CombatIntent.Direction.LEFT if facing < 0 else CombatIntent.Direction.RIGHT)
							if source.active_attack != null and not source.active_attack.is_finisher and source.buffered_intent == null:
								press(source, &"attack_light")
							steps(1)
							var hits := landed_by(source)
							if hits.size() > previous_hits:
								if first_tick < 0: first_tick = controller.tick
								elif hits.size() < source.runtime_profile.move_set.combo_count:
									check(controller.tick - int(hits[-2].tick) == 24, "middle hits use 24-tick cadence")
								previous_hits = hits.size()
						check(landed_by(source).size() == source.runtime_profile.move_set.combo_count, "full in-range chain %s/%s %s distance%d %s" % [source_id,target_id,facing,distance,escape])

func _test_down_and_wakeup() -> void:
	for source_id: StringName in [&"ja-hyun", &"nabi"]:
		for target_id: StringName in [&"ja-hyun", &"nabi"]:
			setup(source_id, target_id)
			var source := controller.player
			var target := controller.training_dummy
			var finisher: AttackData
			for attack: AttackData in source.attacks:
				if attack.is_finisher and attack.activation_context == AttackData.ActivationContext.GROUND: finisher = attack
			var context := HitContext.new(controller.tick, source, target, finisher)
			HitResolver.resolve(context, controller.rules)
			check(target.state == FighterController.State.KNOCK_DOWN and target.landing_down_ticks == 36 and target.hitstun_ticks == 36, "ground finisher starts exact 36-tick down independent of weight")
			var hp := target.current_hp
			var reaction := target.state
			var heavy := attack_by_action(source, &"attack_heavy")
			var result := HitResolver.resolve(HitContext.new(controller.tick,source,target,heavy),controller.rules)
			check(result.type == HitResult.Type.IMMUNE and target.current_hp == hp and target.state == reaction and target.hitstun_ticks == 36, "down cannot be damaged, relaunched or extended")
			for tick: int in 35: target.step_tick(controller.rules)
			check(target.state == FighterController.State.KNOCK_DOWN and target.hitstun_ticks == 1, "down remains through its final tick")
			target.step_tick(controller.rules)
			check(target.state == FighterController.State.WAKE_UP and target.wakeup_protection_ticks == 12, "ground finisher grants wakeup protection")
			result = HitResolver.resolve(HitContext.new(controller.tick,source,target,heavy),controller.rules)
			check(result.type == HitResult.Type.IMMUNE and target.current_hp == hp, "wakeup protects from immediate repeat attack")
			# Wake-up drawing must not delay a valid player action.
			target.consume_intent(intent(target,&"attack_light"),controller.rules)
			check(target.active_attack != null and target.wakeup_protection_ticks == 0, "valid wakeup attack consumes protection")
			# Airborne finisher remains airborne until actual floor contact.
			setup(source_id,target_id)
			target = controller.training_dummy
			target.position = Vector2(650,300)
			target.velocity = Vector2.ZERO
			target.move_and_slide()
			HitResolver.resolve(HitContext.new(controller.tick,controller.player,target,finisher),controller.rules)
			check(target.landing_down_ticks == 0 and target.landing_knockdown_pending, "air finisher schedules down on real landing")
			for tick: int in 100:
				target.step_tick(controller.rules)
				if target.landing_down_ticks > 0: break
			check(target.is_on_floor() and target.landing_down_ticks == 36, "air finisher enters complete grounded down on landing")

func _test_edge_displacement() -> void:
	setup()
	var source := controller.player
	var target := controller.training_dummy
	# Default 60-wide hitbox ends at x=674; target half-width=18.
	target.position.x = 690
	var start_x := target.position.x
	press(source,&"attack_light")
	for tick: int in 70:
		if source.active_attack != null and not source.active_attack.is_finisher and source.buffered_intent == null: press(source,&"attack_light")
		steps(1)
	check(target.position.x > start_x, "middle hit retains physical pushback")
	check(landed_by(source).size() > 0, "edge case actually hits")
	check(is_equal_approx(target.position.y,572.0), "middle ground hit does not produce an unintended hop")
	check(is_equal_approx(source.position.x,600.0), "chain never teleports or chases target")

func _test_cancelled_reservation() -> void:
	setup()
	var source := controller.player
	press(source,&"attack_light")
	steps(1)
	press(source,&"attack_light")
	steps(1)
	check(source.buffered_intent != null,"real input queued a followup")
	source.apply_hit(attack_by_action(controller.training_dummy,&"attack_light"),Vector2.ZERO,30,controller.rules)
	check(source.active_attack == null and source.buffered_intent == null,"incoming hit cancels attack and reservation")
	steps(40)
	check(source.active_attack == null,"cancelled reservation cannot attack after recovery")
