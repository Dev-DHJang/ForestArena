extends SceneTree

const RULES: CombatRules = preload("res://assets/combat/two_fighter_combat_rules.tres")
const JA: MoveSetData = preload("res://assets/combat/movesets/two_fighter_ja_hyun_moveset.tres")
const NABI: MoveSetData = preload("res://assets/combat/movesets/two_fighter_nabi_moveset.tres")
var failures: PackedStringArray = []
var controller: MatchController
var scene: Node
var events: Array[Dictionary] = []
var catalog: LoadoutCatalog
var source_moves: MoveSetData


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	scene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	root.get_node("ForestArenaAudio").call("set_levels", 0.0, 0.0, true, false)
	controller = scene.get_node("MatchController") as MatchController
	controller.set_physics_process(false)
	controller.bot_source = null
	controller.rules = RULES.duplicate(true)
	var original := load("res://assets/loadouts/default_loadout_catalog.tres") as LoadoutCatalog
	source_moves = original.character_by_id(&"ja-hyun").base_move_set
	catalog = original.duplicate(true)
	for index: int in catalog.characters.size(): catalog.characters[index] = catalog.characters[index].duplicate(true) as CharacterData
	catalog.character_by_id(&"ja-hyun").base_move_set = JA
	catalog.character_by_id(&"nabi").base_move_set = NABI
	controller.presentation_event.connect(func(id: StringName, payload: Dictionary) -> void:
		if id == &"hit_resolved": events.append(payload.duplicate(true)))
	_test_data()
	_test_ground_inputs_and_combos()
	_test_heavy()
	_test_air_budget_and_timeout()
	_test_slam_landing()
	_test_pulses()
	_test_simultaneous()
	await _test_travel()
	_test_travel_speed_and_recovery()
	_test_snapshot_and_replay()
	check(original.character_by_id(&"ja-hyun").base_move_set == source_moves, "test fixture cannot replace the cached source CharacterData moveset")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("TWO_FIGHTER_COMBAT_V2: PASS")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)


func check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message): failures.append(message)


func profile(id: StringName) -> RuntimeCombatProfile:
	var selection := LoadoutSelection.new()
	selection.character_id = id
	var built := LoadoutBuilder.build(selection, catalog)
	check(built.succeeded(), "build new profile %s" % id)
	return built.profile


func setup(id: StringName = &"ja-hyun", target_id: StringName = &"nabi") -> void:
	controller.additional_fighters.clear()
	controller.team_by_fighter_id.clear()
	controller.local_match_mode = LocalMatchConfig.Mode.AI
	controller.player.configure_profile(profile(id))
	controller.training_dummy.configure_profile(profile(target_id))
	controller.reset_match()
	controller.player.global_position = Vector2(600, 572)
	controller.player.facing = 1
	controller.training_dummy.facing = -1
	controller.training_dummy.global_position = Vector2(900, 572)
	steps(3)
	events.clear()


func steps(count: int) -> void:
	for ignored: int in count: controller.step_fixed_tick(false)


func intent(fighter: FighterController, action: StringName, direction := CombatIntent.Direction.NEUTRAL, edge := CombatIntent.Edge.PRESS) -> CombatIntent:
	return CombatIntent.new(controller.tick + 1, fighter.fighter_id, action, direction, edge, CombatIntent.Context.GROUND if fighter.is_on_floor() else CombatIntent.Context.AIR)


func press(fighter: FighterController, action: StringName, direction := CombatIntent.Direction.NEUTRAL) -> void:
	controller.submit_intent(intent(fighter, action, direction))


func move_to_air(source: Vector2, target: Vector2) -> void:
	controller.player.global_position = source
	controller.training_dummy.global_position = target
	controller.player.velocity = Vector2.ZERO
	controller.training_dummy.velocity = Vector2.ZERO
	steps(1)


func attack_by_action(fighter: FighterController, action: StringName, air := false) -> AttackData:
	for attack: AttackData in fighter.attacks:
		if attack.action_id == action and attack.activation_context == (AttackData.ActivationContext.AIR if air else AttackData.ActivationContext.GROUND): return attack
	return null


func _test_data() -> void:
	check(RULES.is_valid_definition() and RULES.schema_version == 5 and RULES.simplified_combat and RULES.special_cooldown_ticks == 300, "new explicit rules v5")
	check(not (load("res://assets/combat/phase1_combat_rules.tres") as CombatRules).simplified_combat, "legacy rules stay separate")
	check(JA.is_valid_definition() and NABI.is_valid_definition(), "new movesets validate")
	check(JA.combo_count == 4 and NABI.combo_count == 3, "new four/three-stage combos")
	for moves: MoveSetData in [JA, NABI]:
		for attack: AttackData in moves.attacks():
			check(attack.schema_version == 4 and not attack.action_id in [&"dash", &"ultimate", &"evade"] and attack.charge_max_ticks == 0, "new attack data omits removed actions and charge")
	var bad := JA.slots[-1].attack.duplicate(true) as AttackData
	bad.hit_windows[0]["tick"] = 61
	check(not bad.is_valid_definition(), "out-of-range pulse rejected")
	bad = JA.slots[-1].attack.duplicate(true) as AttackData
	bad.hit_windows[0]["boxes"] = [Rect2()]
	check(not bad.is_valid_definition(), "empty hit area rejected")


func _test_ground_inputs_and_combos() -> void:
	for id: StringName in [&"ja-hyun", &"nabi"]:
		for direction: CombatIntent.Direction in [CombatIntent.Direction.NEUTRAL, CombatIntent.Direction.LEFT, CombatIntent.Direction.RIGHT, CombatIntent.Direction.UP, CombatIntent.Direction.DOWN]:
			setup(id)
			var fighter := controller.player
			press(fighter, &"attack_light", direction)
			steps(1)
			check(fighter.active_attack != null and String(fighter.active_attack.attack_id).ends_with("light-01"), "%s ground direction %s uses the same opening" % [id, direction])
		setup(id)
		var fighter := controller.player
		for action: StringName in [&"dash", &"evade", &"ultimate"]: fighter.consume_intent(intent(fighter, action), controller.rules)
		check(fighter.state == FighterController.State.IDLE and fighter.active_attack == null, "%s removed actions do nothing" % id)
		press(fighter, &"attack_heavy")
		steps(1)
		check(fighter.state == FighterController.State.ATTACK_STARTUP and fighter.charge_attack == null, "%s heavy starts without charging" % id)
		setup(id)
		fighter = controller.player
		controller.training_dummy.global_position.x = 655
		press(fighter, &"attack_light")
		var seen: Dictionary = {}
		for ignored: int in 160:
			if fighter.active_attack != null:
				seen[fighter.active_attack.attack_id] = true
				if not fighter.active_attack.is_finisher and fighter.state == FighterController.State.ATTACK_ACTIVE and fighter.attack_phase_tick == 2: press(fighter, &"attack_light")
			steps(1)
		check(seen.size() == fighter.runtime_profile.move_set.combo_count, "%s presses execute every combo stage" % id)
		check(events.size() == fighter.runtime_profile.move_set.combo_count, "%s stationary full combo lands once per stage" % id)


func _test_heavy() -> void:
	setup()
	var source := controller.player
	var target := controller.training_dummy
	target.global_position.x = 780
	var before := target.global_position.x
	press(source, &"attack_heavy")
	steps(35)
	check(target.current_hp == target._stats().max_hp - 10.0 and target.global_position.x < before - 50.0, "ranged scarf heavy lands once and actually pulls")
	check(source.global_position.x == 600.0, "ranged pull does not move the caster")
	setup(&"nabi", &"ja-hyun")
	target = controller.training_dummy
	target.global_position.x = 655
	press(controller.player, &"attack_heavy")
	steps(12)
	check(target.state == FighterController.State.LAUNCH and target.velocity.y < -250, "Nabi ground uppercut launches once")


func _test_air_budget_and_timeout() -> void:
	setup()
	move_to_air(Vector2(600, 250), Vector2(740, 250))
	var source := controller.player
	var target := controller.training_dummy
	press(source, &"attack_light")
	steps(8)
	check(events.size() == 1 and target.air_lock == 1 and source.air_light_used and not source.air_heavy_used, "long aerial light connects beyond old reach and spends only light")
	check(target.air_jumps_remaining == 1, "lock preserves the unused extra jump")
	# A widened test-only void separates the 120-tick status timeout from the
	# production ring-out boundary. Ordinary match ring-out remains unchanged.
	target.global_position = Vector2(1900, 200)
	target.air_light_used = true
	var initial := target.air_lock_ticks
	for ignored: int in 25: target.step_tick(controller.rules)
	check(target.air_lock_ticks == initial - 25, "air control timeout uses fixed ticks")
	target.consume_intent(intent(target, &"move", CombatIntent.Direction.LEFT), controller.rules)
	target.step_tick(controller.rules)
	check(target.velocity.x < 0, "after light hitstun, horizontal steering is possible")
	var budget := target.air_jumps_remaining
	target.consume_intent(intent(target, &"jump"), controller.rules)
	target.consume_intent(intent(target, &"attack_heavy"), controller.rules)
	check(target.air_jumps_remaining == budget and target.active_attack == null, "light lock blocks extra jump and attack")
	var remaining := target.air_lock_ticks
	var upper := attack_by_action(controller.player, &"attack_heavy", true).duplicate(true) as AttackData
	upper.air_lock = 2
	upper.landing_knockdown = true
	target.apply_hit(upper, Vector2(0, -200), 10, controller.rules)
	check(target.air_lock == 2 and target.air_lock_ticks == remaining, "later stronger hit upgrades the lock without extending its deadline")
	target.consume_intent(intent(target, &"move", CombatIntent.Direction.RIGHT), controller.rules)
	target.step_tick(controller.rules)
	check(target.velocity.x == 0, "full lock records held input without horizontal steering")
	target.consume_intent(intent(target, &"move", CombatIntent.Direction.RIGHT, CombatIntent.Edge.RELEASE), controller.rules)
	check(target.input_direction == CombatIntent.Direction.NEUTRAL, "full lock records release so movement cannot stick after unlocking")
	remaining -= 1
	for ignored: int in remaining: target.step_tick(controller.rules)
	check(target.air_lock == 0 and target.air_lock_ticks == 0 and target.air_lock_expired and not target.landing_knockdown_pending, "120 ticks clear the extra lock and pending landing effect")
	check(target.air_light_used and not target.air_heavy_used and target.air_jumps_remaining == budget, "timeout does not grant spent actions")
	target.apply_hit(upper, Vector2.ZERO, 1, controller.rules)
	check(target.air_lock == 0 and target.air_lock_expired, "new hits cannot rearm an expired lock in the same flight")
	target.step_tick(controller.rules)
	target.consume_intent(intent(target, &"attack_light"), controller.rules)
	check(target.active_attack == null, "spent light remains unavailable after timeout")
	target.consume_intent(intent(target, &"attack_heavy"), controller.rules)
	check(target.active_attack != null and target.air_heavy_used, "unused heavy is available after timeout")
	setup()
	move_to_air(Vector2(600, 250), Vector2(900, 250))
	press(controller.player, &"attack_special")
	steps(1)
	check(controller.player.active_attack == null and controller.player.runtime_state.special_cooldown_ticks == 0, "airborne special is rejected without cooldown")


func _test_slam_landing() -> void:
	for id: StringName in [&"ja-hyun", &"nabi"]:
		setup(id, &"ja-hyun")
		move_to_air(Vector2(600, 250), Vector2(655, 280))
		var source := controller.player
		var target := controller.training_dummy
		press(source, &"attack_heavy")
		steps(12)
		check(events.size() == 1 and source.air_heavy_used and not source.air_light_used and target.landing_knockdown_pending, "%s aerial heavy is a single hit with landing reaction" % id)
		if id == &"ja-hyun": check(target.velocity.y >= 900.0 and source.velocity.y < 500.0, "scarf slam dives the victim, not the caster")
		else: check(target.velocity.y < 0 and target.air_lock == 2, "Nabi aerial heavy launches and fully locks the victim")
		var landed := false
		for ignored: int in 110:
			steps(1)
			if target.landing_down_ticks > 0:
				landed = true
				break
		check(landed and target.state == FighterController.State.KNOCK_DOWN and target.landing_down_ticks == 18, "%s landing begins the exact 18-tick down" % id)
		target.consume_intent(intent(target, &"move", CombatIntent.Direction.LEFT), controller.rules)
		target.consume_intent(intent(target, &"move", CombatIntent.Direction.LEFT, CombatIntent.Edge.RELEASE), controller.rules)
		check(target.input_direction == CombatIntent.Direction.NEUTRAL, "down records movement release too")
		check(target.air_lock == 0 and not target.air_light_used and not target.air_heavy_used, "%s real landing clears locks and restores one of each action" % id)
		steps(18)
		check(target.wakeup_protection_ticks == 12, "%s waking provides 12-tick protection" % id)
		var hp := target.current_hp
		var context := HitContext.new(controller.tick, source, target, attack_by_action(source, &"attack_light"))
		check(HitResolver.resolve(context, controller.rules).type == HitResult.Type.IMMUNE and target.current_hp == hp, "wakeup protection blocks immediate repeat damage")
		press(target, &"attack_light")
		steps(1)
		check(target.wakeup_protection_ticks == 0, "starting an attack ends wakeup protection")


func extra(id: StringName, position: Vector2) -> FighterController:
	var fighter := (load("res://scenes/fighters/ja_hyun_fighter.tscn") as PackedScene).instantiate() as FighterController
	fighter.fighter_id = id
	scene.get_node("World").add_child(fighter)
	fighter.configure_profile(profile(&"ja-hyun"))
	fighter.reset_for_match(controller.rules)
	fighter.global_position = position
	controller.additional_fighters.append(fighter)
	return fighter


func _test_pulses() -> void:
	setup()
	var source := controller.player
	var right := controller.training_dummy
	right.global_position = Vector2(800, 572)
	var left := extra(&"left-target", Vector2(400, 572))
	var up := extra(&"up-target", Vector2(600, 300))
	var hp := [left.current_hp, right.current_hp, up.current_hp]
	press(source, &"attack_special")
	steps(71)
	var by_target: Dictionary = {}
	for event: Dictionary in events:
		var id := String(event.defender_id)
		if not by_target.has(id): by_target[id] = []
		by_target[id].append(int(event.tick))
	for target: FighterController in [left, right, up]:
		var hits: Array = by_target.get(String(target.fighter_id), [])
		check(hits.size() == 10, "left/right/up target %s gets exactly ten pulses: %s" % [target.fighter_id, hits])
		for index: int in range(1, hits.size()): check(hits[index] - hits[index - 1] == 6, "pulse schedule stays six ticks apart")
	check(left.velocity.x < 0 and right.velocity.x > 0 and up.velocity.y < 0, "last scheduled pulse pushes left/right/up targets outward")
	check(hp[0] - left.current_hp == 14 and hp[1] - right.current_hp == 14 and hp[2] - up.current_hp == 14, "pulse total damage is nine single points plus final five")
	check(controller.snapshot().simplified_combat, "snapshot exposes simplified combat")
	left.queue_free()
	up.queue_free()
	setup()
	source = controller.player
	var target := controller.training_dummy
	target.global_position.x = 655
	target.consume_intent(intent(target, &"guard"), controller.rules)
	var before := target.current_hp
	press(source, &"attack_special")
	steps(71)
	check(target.current_hp == before and target.runtime_state.guard_durability == 90.0 and target.pull_ticks_remaining == 0, "guard blocks every pulse without pulling or HP damage")
	var serial := source.activation_serial
	press(source, &"attack_special")
	steps(1)
	check(source.activation_serial == serial and source.runtime_state.special_cooldown_ticks > 0, "five-second cooldown prevents immediate restart")
	setup()
	source = controller.player
	target = controller.training_dummy
	target.global_position.x = 655
	press(source, &"attack_special")
	steps(17)
	check(events.size() == 1, "first pulse is active tick six, not active tick one")
	source.apply_hit(attack_by_action(target, &"attack_light"), Vector2.ZERO, 16, controller.rules)
	var cooldown := source.runtime_state.special_cooldown_ticks
	steps(65)
	check(events.size() == 1 and source.active_attack == null and source.runtime_state.special_cooldown_ticks == cooldown - 65, "being hit cancels remaining pulses without refunding cooldown")


func _test_travel() -> void:
	setup(&"nabi", &"ja-hyun")
	var source := controller.player
	var first := controller.training_dummy
	first.global_position.x = 720
	var farther := extra(&"farther", Vector2(850, 572))
	press(source, &"attack_special")
	steps(33)
	check(events.size() == 1 and String(events[0].defender_id) == String(first.fighter_id), "dash strikes only the first opponent once")
	check(is_equal_approx(source.global_position.x, 784.0) and source.attack_strike_ready and not source.attack_travel_active, "dash stops exactly 64 units behind the first target")
	check(farther.current_hp == farther._stats().max_hp, "farther opponent is untouched")
	farther.queue_free()
	setup(&"nabi", &"ja-hyun")
	source = controller.player
	controller.training_dummy.global_position.x = 1500
	press(source, &"attack_special")
	steps(33)
	check(events.is_empty() and is_equal_approx(source.global_position.x, 920.0) and not source.attack_strike_ready, "empty dash travels exactly 320 without damage x=%s ready=%s fail=%s active=%s events=%s" % [source.global_position.x, source.attack_strike_ready, source.attack_travel_failed, source.attack_travel_active, events])
	setup(&"nabi", &"ja-hyun")
	source = controller.player
	controller.training_dummy.global_position.x = 720
	var occupant := extra(&"occupied-end", Vector2(784, 572))
	press(source, &"attack_special")
	steps(33)
	check(events.is_empty() and source.attack_travel_failed and source.global_position.x < 680, "occupied endpoint fails without moving into another fighter x=%s fail=%s events=%s" % [source.global_position.x, source.attack_travel_failed, events])
	occupant.queue_free()
	setup(&"nabi", &"ja-hyun")
	source = controller.player
	controller.training_dummy.global_position.x = 720
	var guarded := controller.training_dummy
	guarded.consume_intent(intent(guarded, &"guard"), controller.rules)
	press(source, &"attack_special")
	steps(33)
	check(events.size() == 1 and events[0].result == "BLOCK" and guarded.current_hp == guarded._stats().max_hp, "back strike remains guardable")
	setup(&"nabi", &"ja-hyun")
	source = controller.player
	controller.training_dummy.global_position.x = 650
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = Vector2(690, 500)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(20, 200)
	shape.shape = rectangle
	wall.add_child(shape)
	scene.get_node("World").add_child(wall)
	await physics_frame
	press(source, &"attack_special")
	steps(33)
	check(events.is_empty() and source.attack_travel_failed and source.global_position.x <= 653.1, "terrain preflight prevents crossing an enemy into a wall or restoring pushboxes inside terrain x=%s fail=%s events=%s" % [source.global_position.x, source.attack_travel_failed, events])
	wall.queue_free()
	await physics_frame
	setup(&"nabi", &"ja-hyun")
	source = controller.player
	controller.training_dummy.global_position.x = 720
	press(source, &"attack_special")
	steps(10)
	check(source.attack_travel_active, "travel begins as an attack phase rather than DASH")
	source.apply_hit(attack_by_action(controller.training_dummy, &"attack_light"), Vector2.ZERO, 16, controller.rules)
	var stopped_at := source.global_position.x
	steps(30)
	check(not source.attack_travel_active and source.active_attack == null and source.global_position.x == stopped_at and events.is_empty(), "hit interruption stops dash and its pending back strike")


func _test_simultaneous() -> void:
	setup()
	var source := controller.player
	var target := controller.training_dummy
	target.global_position.x = 655
	source.call("_start_attack", attack_by_action(source, &"attack_special"), CombatIntent.Direction.NEUTRAL, controller.rules)
	target.call("_start_attack", attack_by_action(target, &"attack_light"), CombatIntent.Direction.NEUTRAL, controller.rules)
	source.state = FighterController.State.ATTACK_ACTIVE
	source.attack_phase_tick = 5
	target.state = FighterController.State.ATTACK_ACTIVE
	var source_hp := source.current_hp
	var target_hp := target.current_hp
	controller.call("_resolve_hits")
	check(source.current_hp == source_hp - 4.0 and target.current_hp == target_hp - 1.0, "same-tick captured attacks both resolve even when the first hit interrupts the other")
	check(source.active_attack == null and target.active_attack == null, "simultaneous hits interrupt both future attacks")
	var count := events.size()
	steps(65)
	check(events.size() == count, "interrupted simultaneous pulse does not generate later hits")
	setup()
	controller.training_dummy.global_position.x = 1500
	press(controller.player, &"attack_special")
	steps(71)
	check(events.is_empty() and controller.player.runtime_state.special_cooldown_ticks > 0, "empty pulse cast still spends cooldown without hitting")
	# The same occupied distance picks the same target even if the caller's
	# fighter array order changes. Movement and collision are still real.
	setup(&"nabi", &"ja-hyun")
	source = controller.player
	target = controller.training_dummy
	target.global_position.x = 720
	var other := extra(&"a-first-tie", Vector2(720, 572))
	var picked: Array[StringName] = []
	for reverse: bool in [false, true]:
		source.global_position = Vector2(600, 572)
		source.facing = 1
		source.call("_start_attack", attack_by_action(source, &"attack_special"), CombatIntent.Direction.RIGHT, controller.rules)
		source.state = FighterController.State.ATTACK_ACTIVE
		var targets: Array[FighterController] = [target, other]
		if reverse: targets.reverse()
		source.advance_attack_travel(targets, controller.rules)
		picked.append(source.attack_target_id)
	check(picked == [&"a-first-tie", &"a-first-tie"], "equal path distance uses fighter ID rather than array order")
	other.queue_free()


func _test_travel_speed_and_recovery() -> void:
	var special := NABI.slots[-1].attack
	check(special.travel_speed == 1200.0 and special.recovery_ticks == 20 and special.active_ticks == 24, "Nabi special uses the approved 1200 speed, 20 recovery, 24 active cap")
	for with_target: bool in [true, false]:
		setup(&"nabi", &"ja-hyun")
		var source := controller.player
		# The farthest searchable center needs 320+64 travel units, exactly
		# ceil(384/20)=20 movement ticks at the approved fixed 60 Hz speed.
		controller.training_dummy.global_position.x = 920 if with_target else 1500
		press(source, &"attack_special")
		var movement_ticks := 0
		var finished := false
		for ignored: int in 35:
			var before := source.global_position.x
			steps(1)
			var moved := source.global_position.x - before
			if moved > 0.01:
				movement_ticks += 1
				check(moved <= 20.001, "actual dash displacement never exceeds 1200/60=20 per tick")
				if source.attack_travel_active: check(is_equal_approx(moved, 20.0), "nonterminal travel tick moves exactly twenty units")
			if source.attack_strike_ready or source.state == FighterController.State.ATTACK_RECOVERY:
				finished = true
				break
		check(finished and movement_ticks == (20 if with_target else 16), "max-target/empty travel finishes after its actual 384/320 distance")
		if with_target:
			check(is_equal_approx(source.global_position.x, 984.0) and events.size() == 1, "max-range target receives one real hit at the 384-unit endpoint")
			steps(3)
			check(source.state == FighterController.State.ATTACK_ACTIVE and events.size() == 1, "arrival grants four active ticks without repeated hits")
			steps(1)
		check(source.state == FighterController.State.ATTACK_RECOVERY and source.attack_phase_tick == 0, "hit arrival after four ticks, or empty arrival immediately, starts recovery")
		steps(19)
		check(source.active_attack != null and source.state == FighterController.State.ATTACK_RECOVERY, "twenty-tick recovery cannot finish at nineteen")
		steps(1)
		check(source.active_attack == null, "twenty-tick recovery finishes exactly on its twentieth tick")
	# Nearby targets take the same four strike ticks and twenty recovery ticks;
	# unused long-distance movement time must not become an extra delay.
	setup(&"nabi", &"ja-hyun")
	var source := controller.player
	controller.training_dummy.global_position.x = 720
	press(source, &"attack_special")
	for ignored: int in 30:
		steps(1)
		if source.attack_strike_ready: break
	check(is_equal_approx(source.global_position.x, 784.0), "near target ends after only its real 184-unit travel")
	steps(4)
	check(source.state == FighterController.State.ATTACK_RECOVERY and source.attack_phase_tick == 0, "near arrival does not wait out unused active travel time")
	steps(20)
	check(source.active_attack == null, "near arrival still has exactly twenty recovery ticks")


func _test_snapshot_and_replay() -> void:
	var hashes: Array[String] = []
	for repeat: int in 2:
		setup()
		controller.training_dummy.global_position.x = 655
		press(controller.player, &"attack_special")
		steps(71)
		hashes.append(controller.snapshot_hash())
	check(hashes[0] == hashes[1], "the complete pulse match reproduces from the same state")
	var target := controller.training_dummy
	target.apply_network_snapshot({"air_light_used": true, "air_heavy_used": false, "air_lock": 2, "air_lock_ticks": 79, "air_lock_expired": false, "landing_knockdown_pending": true, "pull_ticks_remaining": 4, "pull_anchor": {"x": 123.0, "y": 456.0}, "attack_travel_active": true, "attack_target_id": "fixture", "attack_travel_end": {"x": 789.0, "y": 572.0}})
	check(target.air_light_used and not target.air_heavy_used and target.air_lock == 2 and target.air_lock_ticks == 79 and target.pull_anchor == Vector2(123, 456) and target.attack_travel_end.x == 789.0, "network snapshots restore all new statuses and movement state")
	target.apply_network_snapshot({})
	check(not target.air_light_used and target.air_lock == 0 and not target.attack_travel_active, "legacy snapshots default new fields explicitly")
	check(JA.slots[-1].attack.hit_windows[-1].damage == 5.0 and JA.slots[-1].attack.launch_mode == AttackData.LaunchMode.TOWARD_SOURCE, "per-pulse override leaves authored attack immutable")
