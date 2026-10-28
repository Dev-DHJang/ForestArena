extends "res://tests/two_fighter_combat_v2.gd"
## Regression coverage for the approved combat feel and falling elimination rules.
const VISUAL := preload("res://scripts/local_fighter_presentation.gd")
var ring_events := 0


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
		if id == &"hit_resolved": events.append(payload.duplicate(true))
		if id == &"ring_out": ring_events += 1)
	_test_doubled_times()
	_test_buffer_boundaries()
	_test_held_guard()
	_test_falling_elimination()
	_test_snapshot_geometry()
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("COMBAT_INPUT_RINGOUT: PASS")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)


func _test_doubled_times() -> void:
	var legacy := controller.rules.duplicate(true) as CombatRules
	legacy.hitstun_multiplier = 1
	for source_id: StringName in [&"ja-hyun", &"nabi"]:
		for target_id: StringName in [&"ja-hyun", &"nabi"]:
			setup(source_id, target_id)
			for attack: AttackData in controller.player.attacks:
				for weight: float in [0.1, controller.training_dummy._stats().weight, 10.0]:
					check(CombatMath.hitstun_ticks(attack, weight, controller.rules) == 2 * CombatMath.hitstun_ticks(attack, weight, legacy), "%s/%s exact weighted/clamped 2x" % [source_id, target_id])
			var source := controller.player
			var target := controller.training_dummy
			var attack := attack_by_action(source, &"attack_light")
			var hit := HitResolver.resolve(HitContext.new(controller.tick, source, target, attack), controller.rules)
			for ignored: int in hit.hitstun_ticks - 1:
				target.consume_intent(intent(target, &"attack_light"), controller.rules)
				check(target.active_attack == null, "hitstun rejects counterattack throughout doubled duration")
				target.step_tick(controller.rules)
			check(target.state == FighterController.State.HITSTUN, "hitstun stays locked before final tick")
			target.step_tick(controller.rules)
			check(target.state == FighterController.State.IDLE, "hitstun unlocks on exact final tick")
			setup(source_id, target_id)
			target = controller.training_dummy
			target.consume_intent(intent(target, &"guard"), controller.rules)
			target.runtime_state.guard_durability = 1.0
			HitResolver.resolve(HitContext.new(controller.tick, controller.player, target, attack), controller.rules)
			check(target.hitstun_ticks == 60 and not target.runtime_state.guarding, "guard break is 60 ticks and clears effective guard")
			for ignored: int in 59: target.step_tick(controller.rules)
			check(target.state == FighterController.State.HITSTUN, "guard break remains locked through tick59")
			target.step_tick(controller.rules)
			check(target.state == FighterController.State.IDLE, "guard break ends at tick60")
	setup()
	var immune_target := controller.training_dummy
	immune_target.apply_hit(attack_by_action(controller.player, &"attack_light"), Vector2.ZERO, 0, controller.rules)
	immune_target.step_tick(controller.rules)
	check(immune_target.state == FighterController.State.IDLE and int(immune_target.snapshot().hitstun_ticks) == 0, "zero-duration reaction releases without sending negative remaining ticks")
	# Execute complete grounded chains while the target keeps requesting a counter.
	for source_id: StringName in [&"ja-hyun", &"nabi"]:
		for target_id: StringName in [&"ja-hyun", &"nabi"]:
			setup(source_id, target_id)
			var source := controller.player
			var target := controller.training_dummy
			target.global_position.x = 655
			press(source, &"attack_light")
			for ignored: int in 125:
				if source.active_attack != null and not source.active_attack.is_finisher and source.buffered_intent == null:
					press(source, &"attack_light")
				if not events.is_empty(): press(target, &"attack_light")
				steps(1)
			var landed := events.filter(func(event: Dictionary) -> bool: return event.attacker_id == source.fighter_id and event.result == "HIT")
			check(landed.size() == source.runtime_profile.move_set.combo_count, "%s/%s queued chain lands before requested counter connects" % [source_id, target_id])
			var counters := events.filter(func(event: Dictionary) -> bool: return event.attacker_id == target.fighter_id and event.result == "HIT")
			if not counters.is_empty() and not landed.is_empty(): check(int(counters[0].tick) > int(landed[-1].tick), "first counter cannot connect before final combo hit")


func _test_buffer_boundaries() -> void:
	for id: StringName in [&"ja-hyun", &"nabi"]:
		for phase: Array in [[FighterController.State.ATTACK_STARTUP, 0], [FighterController.State.ATTACK_STARTUP, 7], [FighterController.State.ATTACK_ACTIVE, 0], [FighterController.State.ATTACK_ACTIVE, 3], [FighterController.State.ATTACK_RECOVERY, 0], [FighterController.State.ATTACK_RECOVERY, 17]]:
			setup(id)
			var fighter := controller.player
			fighter.consume_intent(intent(fighter, &"attack_light"), controller.rules)
			var first := fighter.active_attack
			fighter.state = phase[0]
			fighter.attack_phase_tick = phase[1]
			fighter.consume_intent(intent(fighter, &"attack_light", CombatIntent.Direction.NEUTRAL, CombatIntent.Edge.HOLD), controller.rules)
			check(fighter.buffered_intent == null, "held button never reserves combo")
			var accepted := intent(fighter, &"attack_light")
			fighter.consume_intent(accepted, controller.rules)
			fighter.consume_intent(intent(fighter, &"attack_light", CombatIntent.Direction.LEFT), controller.rules)
			check(fighter.buffered_intent == accepted and fighter.active_attack == first, "%s phase %s accepts exactly one input without early attack" % [id, phase])
			while fighter.active_attack == first: fighter.step_tick(controller.rules)
			check(fighter.active_attack != null and fighter.active_attack.attack_id != first.attack_id, "buffer starts only after full recovery")
		setup(id)
		var fighter := controller.player
		fighter.consume_intent(intent(fighter, &"attack_light"), controller.rules)
		fighter.consume_intent(intent(fighter, &"attack_light"), controller.rules)
		fighter.apply_hit(attack_by_action(controller.training_dummy, &"attack_light"), Vector2.ZERO, 30, controller.rules)
		check(fighter.buffered_intent == null and fighter.active_attack == null, "being hit clears queued chain")
		for attack: AttackData in fighter.attacks:
			if not attack.is_finisher: continue
			fighter.active_attack = attack
			fighter.state = FighterController.State.ATTACK_RECOVERY
			fighter.attack_phase_tick = 1
			fighter.consume_intent(intent(fighter, &"attack_light"), controller.rules)
			check(fighter.buffered_intent == null, "finisher cannot reserve continuation")


func _test_held_guard() -> void:
	for id: StringName in [&"ja-hyun", &"nabi"]:
		setup(id)
		var fighter := controller.player
		var visual := VISUAL.new()
		fighter.add_child(visual)
		controller.submit_intent(intent(fighter, &"move", CombatIntent.Direction.DOWN))
		steps(1)
		for ignored: int in 300: fighter.step_tick(controller.rules)
		visual.sync_visual(5.0)
		check(fighter.state == FighterController.State.GUARD and fighter.runtime_state.guarding and visual.sprite.frame == 11, "%s down holds approved pose after five seconds" % id)
		fighter.consume_intent(intent(fighter, &"move", CombatIntent.Direction.RIGHT, CombatIntent.Edge.HOLD), controller.rules)
		visual.sync_visual(0.01)
		check(fighter.state != FighterController.State.GUARD and not fighter.runtime_state.guarding and visual.sprite.animation != &"guard", "direction change releases both guard and motion")
		for release_mode: String in ["release", "pause", "disconnect"]:
			fighter.consume_intent(intent(fighter, &"guard"), controller.rules)
			if release_mode == "release": fighter.consume_intent(intent(fighter, &"move", CombatIntent.Direction.DOWN, CombatIntent.Edge.RELEASE), controller.rules)
			elif release_mode == "pause": controller.pause_match(true); controller.pause_match(false)
			else: controller.release_fighter_input(fighter.fighter_id)
			check(not fighter.runtime_state.guarding and fighter.state != FighterController.State.GUARD, "%s clears effective and visible guard" % release_mode)
		visual.free()


func _test_falling_elimination() -> void:
	setup()
	var fighter := controller.player
	var bounds := controller.stage_data.ring_bounds
	# Cross during real movement with overlapping active attacks. Neither may hit
	# after the crossing, even though hit resolution runs later in the same tick.
	var target := controller.training_dummy
	for actor: FighterController in [fighter, target]:
		actor.global_position = Vector2(600, bounds.end.y - 1)
		actor.velocity = Vector2(0, 600)
		actor.active_attack = attack_by_action(actor, &"attack_light")
		actor.state = FighterController.State.ATTACK_ACTIVE
		actor.attack_phase_tick = 0
		actor.current_hp = 1
	steps(1)
	check(fighter.state == FighterController.State.FALLING_OUT and target.state == FighterController.State.FALLING_OUT and fighter.stocks == 3 and target.stocks == 3 and fighter.current_hp == 1 and target.current_hp == 1, "crossing tick clears attacks before collisions or lethal hits")
	setup()
	fighter = controller.player
	for point: Vector2 in [Vector2(bounds.position.x - 1, 100), Vector2(bounds.end.x + 1, 100), Vector2(600, bounds.position.y - 1)]:
		fighter.global_position = point
		controller.call("_resolve_ring_outs")
		fighter.consume_intent(intent(fighter, &"move", CombatIntent.Direction.RIGHT), controller.rules)
		check(fighter.stocks == 3 and fighter.state != FighterController.State.FALLING_OUT and fighter.input_direction == CombatIntent.Direction.RIGHT, "side/top crossing remains controllable")
	fighter.global_position = Vector2(600, bounds.end.y)
	fighter.velocity = Vector2(20, 100)
	controller.call("_resolve_ring_outs")
	var start_y := fighter.global_position.y
	var hp := fighter.current_hp
	check(fighter.state == FighterController.State.FALLING_OUT and fighter.stocks == 3 and not fighter.ring_out_hidden, "bottom crossing begins fall without stock loss or hiding")
	fighter.consume_intent(intent(fighter, &"attack_light"), controller.rules)
	fighter.consume_intent(intent(fighter, &"jump"), controller.rules)
	fighter.step_tick(controller.rules)
	check(fighter.global_position.y > start_y and fighter.velocity.y > 100 and fighter.active_attack == null, "fall keeps gravity/momentum and rejects actions")
	var result := HitResolver.resolve(HitContext.new(controller.tick, controller.training_dummy, fighter, attack_by_action(controller.training_dummy, &"attack_light")), controller.rules)
	check(not result.landed() and fighter.current_hp == hp and fighter.get_debug_geometry().hurtbox.is_empty(), "falling fighter cannot receive hits and has no debug combat geometry")
	var ai := LocalAICommandSource.new()
	ai.fighter_id = controller.training_dummy.fighter_id
	check(not bool(ai.call("_valid_target", fighter.snapshot())), "AI excludes falling opponent")
	var visual := VISUAL.new()
	fighter.add_child(visual)
	visual.sync_visual(0.01)
	check(visual.sprite.animation == &"jump" and visual.sprite.visible, "elimination displays falling before hidden line")
	var camera := scene.get_node("Camera2D") as Camera2D
	camera.call("_process", 0.01)
	check(camera.position.y == controller.stage_data.main_floor().rect.position.y, "camera stops following below main floor")
	fighter.global_position.y = bounds.end.y + controller.rules.ring_out_hide_margin - 1
	controller.call("_resolve_ring_outs")
	check(not fighter.ring_out_hidden and fighter.ring_out_pending_ticks == 0, "timer does not start above hidden line")
	fighter.global_position.y += 1
	controller.call("_resolve_ring_outs")
	visual.sync_visual(0.01)
	check(fighter.ring_out_hidden and fighter.ring_out_pending_ticks == 60 and not visual.sprite.visible and fighter.stocks == 3, "hidden line starts full 60-tick delay and hides existing fall motion")
	var count := ring_events
	fighter.runtime_state.special_cooldown_ticks = 100
	for ignored: int in 59:
		fighter.step_tick(controller.rules)
		controller.call("_resolve_ring_outs")
	check(fighter.stocks == 3 and fighter.ring_out_pending_ticks == 1, "no loss or result before tick60")
	fighter.step_tick(controller.rules)
	controller.call("_resolve_ring_outs")
	check(fighter.runtime_state.special_cooldown_ticks == 40, "falling delay keeps the ordinary cooldown clock running")
	check(fighter.stocks == 2 and fighter.state == FighterController.State.RING_OUT and ring_events == count + 1, "tick60 confirms exactly one stock and event")
	controller.call("_resolve_ring_outs")
	check(fighter.stocks == 2 and ring_events == count + 1, "confirmed loss cannot repeat")
	for ignored: int in controller.rules.respawn_delay_ticks: fighter.step_tick(controller.rules)
	visual.sync_visual(0.01)
	check(not fighter.ring_out_hidden and fighter.ring_out_pending_ticks == 0 and visual.sprite.visible, "respawn restores visibility and clears pending state")
	visual.free()
	setup()
	for actor: FighterController in [controller.player, controller.training_dummy]:
		actor.stocks = 1
		actor.global_position = Vector2(600, bounds.end.y + 256)
	controller.call("_resolve_ring_outs")
	for ignored: int in 59: controller.call("_resolve_ring_outs")
	check(not controller.is_draw and controller.winner_id.is_empty(), "final losses stay undecided throughout delay")
	controller.call("_resolve_ring_outs")
	check(controller.is_draw and controller.player.stocks == 0 and controller.training_dummy.stocks == 0, "simultaneous confirmed final losses draw as one batch")
	controller.reset_match()
	check(not controller.player.ring_out_hidden and controller.player.ring_out_pending_ticks == 0, "match reset clears hidden elimination")
	controller.player.current_hp = 1
	HitResolver.resolve(HitContext.new(controller.tick, controller.training_dummy, controller.player, attack_by_action(controller.training_dummy, &"attack_light")), controller.rules)
	check(controller.player.stocks == 2 and controller.player.state == FighterController.State.RING_OUT and not controller.player.ring_out_hidden, "HP exhaustion preserves immediate existing stock loss")


func _test_snapshot_geometry() -> void:
	setup()
	var fighter := controller.player
	fighter.facing = -1
	fighter.consume_intent(intent(fighter, &"attack_special"), controller.rules)
	fighter.state = FighterController.State.ATTACK_ACTIVE
	fighter.attack_phase_tick = 5
	var geometry := fighter.get_debug_geometry()
	check(geometry.hitboxes.size() == 3, "all three authored barrage areas are included")
	for index: int in 3:
		check(geometry.hitboxes[index] == FighterController._debug_rect(fighter.attack_hit_windows()[0].boxes[index]), "debug geometry uses actual mirrored resolver box")
	var transmitted := controller.network_snapshot().fighters[0] as Dictionary
	var remote := controller.training_dummy
	remote.apply_network_snapshot(transmitted)
	check(remote.get_debug_geometry() == geometry and remote.hitstun_ticks == fighter.hitstun_ticks and remote.landing_down_duration_ticks == 36, "LAN applies authoritative geometry and doubled timing fields")
	remote.state = FighterController.State.FALLING_OUT
	remote.ring_out_hidden = true
	remote.ring_out_pending_ticks = 37
	var pending: Dictionary = controller.network_snapshot().fighters[1]
	fighter.apply_network_snapshot(pending)
	check(fighter.ring_out_hidden and fighter.ring_out_pending_ticks == 37 and fighter.state == FighterController.State.FALLING_OUT, "LAN applies exact hidden pending state")
	controller.reset_match()
	check(not fighter.ring_out_hidden and fighter.get_debug_geometry().hurtbox.size() == 4, "reset clears network geometry override")
