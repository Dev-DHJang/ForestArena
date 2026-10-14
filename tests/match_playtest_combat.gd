extends SceneTree

const Catalog = preload("res://scripts/local_play_catalog.gd")
const LOCKED_STATES := [FighterController.State.HITSTUN, FighterController.State.LAUNCH, FighterController.State.KNOCK_DOWN]
var failures: PackedStringArray = []
var pair_count := 0
var smallest_gap := 1000


func _initialize() -> void:
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	root.get_node("ForestArenaAudio").call("set_levels", 0.0, 0.0, true, false)
	var controller := scene.get_node("MatchController") as MatchController
	controller.set_physics_process(false)
	controller.bot_source = null
	var catalog := Catalog.new().combat
	var profiles: Array[RuntimeCombatProfile] = []
	var accessory_ids: Array[StringName] = [&""]
	for accessory: AccessoryData in catalog.accessories: accessory_ids.append(accessory.accessory_id)
	for character: CharacterData in catalog.characters:
		for accessory_id: StringName in accessory_ids:
			var selection := LoadoutSelection.new()
			selection.character_id = character.character_id
			selection.accessory_id = accessory_id
			var built := LoadoutBuilder.build(selection, catalog)
			_check(built.succeeded(), "%s/%s profile builds" % [character.character_id, accessory_id])
			if built.succeeded(): profiles.append(built.profile)
	_check(profiles.size() == 28, "four characters with no accessory or each of six sold accessories are covered")
	var data_before := _data_signature(catalog)
	for source: RuntimeCombatProfile in profiles:
		controller.player.configure_profile(source)
		for target: RuntimeCombatProfile in profiles:
			controller.training_dummy.configure_profile(target)
			var first := _repeated_light_gap(controller)
			var second := _repeated_light_gap(controller)
			_check(first == second, "%s -> %s reproduces its full combat trace" % [_label(source), _label(target)])
			pair_count += 1
	_test_defensive_actions(controller, catalog)
	_test_cancel_phase(controller)
	_test_cancel_restarts(controller)
	_test_restart_lock_lifecycle(controller)
	_test_hold_and_finisher(controller)
	_check(data_before == _data_signature(catalog), "runtime combat leaves all authored attack Resources unchanged")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("MATCH_PLAYTEST_COMBAT: PASS (%d profile pairs, minimum %d actionable ticks)" % [pair_count, smallest_gap])
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)


func _settle(controller: MatchController) -> void:
	controller.reset_match()
	controller.player.global_position = Vector2(600, 572)
	controller.training_dummy.global_position = Vector2(800, 572)
	for ignored: int in 3: controller.step_fixed_tick(false)


func _repeated_light_gap(controller: MatchController) -> String:
	_settle(controller)
	var player := controller.player
	var target := controller.training_dummy
	var label := "%s -> %s" % [_label(player.runtime_profile), _label(target.runtime_profile)]
	controller.submit_intent(_intent(controller, player, &"attack_light"))
	controller.step_fixed_tick(false)
	var attack := player.active_attack
	_check(attack != null, label + " opening starts")
	if attack == null: return "missing opening"
	# Put the opponent into range only on the last active tick. This gives less
	# escape time than an early hit, while all damage still uses real hitboxes.
	for ignored: int in attack.startup_ticks + attack.active_ticks:
		if player.state == FighterController.State.ATTACK_ACTIVE and player.attack_phase_tick == attack.active_ticks - 2: break
		controller.step_fixed_tick(false)
	_check(player.state == FighterController.State.ATTACK_ACTIVE and player.attack_phase_tick == attack.active_ticks - 2, label + " reaches the final active setup tick")
	target.global_position = Vector2(player.global_position.x + 55.0, 572)
	var hp_before := target.current_hp
	controller.step_fixed_tick(false)
	_check(target.current_hp < hp_before and target.state in LOCKED_STATES, label + " late active tick lands")
	var first_hp := target.current_hp
	controller.submit_intent(_intent(controller, player, &"attack_light"))
	var available_ticks := 0
	var next_hit := false
	var traces: Array[String] = []
	for ignored: int in 60:
		if target.state not in LOCKED_STATES: available_ticks += 1
		controller.step_fixed_tick(false)
		traces.append(controller.snapshot_hash())
		if target.current_hp < first_hp:
			next_hit = true
			break
	_check(next_hit, label + " buffered next stage produces a real second hit")
	_check(available_ticks >= 6, "%s has only %d actionable ticks between hits" % [label, available_ticks])
	smallest_gap = mini(smallest_gap, available_ticks)
	return JSON.stringify([available_ticks, traces]).sha256_text()


func _test_defensive_actions(controller: MatchController, catalog: LoadoutCatalog) -> void:
	# The smallest supported weight maximizes hitstun. Verify that leaving the
	# action lock enables real commands, rather than only changing a counter.
	var selection := LoadoutSelection.new()
	selection.character_id = &"myo-ryung"
	selection.accessory_id = &"fixture-explosive-gloves"
	controller.training_dummy.configure_profile(LoadoutBuilder.build(selection, catalog).profile)
	for action: StringName in [&"move", &"guard", &"evade"]:
		_settle(controller)
		var source := controller.player
		var target := controller.training_dummy
		target.global_position = Vector2(655, 572)
		controller.submit_intent(_intent(controller, source, &"attack_light"))
		for ignored: int in 8: controller.step_fixed_tick(false)
		_check(target.state in LOCKED_STATES, "%s starts from a real landed hit" % action)
		controller.submit_intent(_intent(controller, source, &"attack_light"))
		for ignored: int in controller.rules.hitstun_max_ticks + 1:
			if target.state not in LOCKED_STATES: break
			controller.step_fixed_tick(false)
		_check(target.state not in LOCKED_STATES, "%s hitstun ends before the follow-up" % action)
		var hp_after := target.current_hp
		if action == &"evade": controller.submit_intent(_intent(controller, target, &"move", CombatIntent.Direction.RIGHT))
		controller.submit_intent(_intent(controller, target, action, CombatIntent.Direction.RIGHT))
		controller.step_fixed_tick(false)
		if action == &"move": _check(target.velocity.x > 0.0, "movement accelerates during the defensive gap")
		elif action == &"guard": _check(target.state == FighterController.State.GUARD, "guard becomes active during the defensive gap")
		else: _check(target.state == FighterController.State.EVADE and target.invulnerability_ticks > 0, "evade grants its normal movement and immunity during the gap")
		for ignored: int in 14: controller.step_fixed_tick(false)
		_check(is_equal_approx(target.current_hp, hp_after), "%s avoids damage from the buffered follow-up" % action)


func _test_cancel_phase(controller: MatchController) -> void:
	var fighter := controller.player
	for phase: FighterController.State in [FighterController.State.ATTACK_STARTUP, FighterController.State.ATTACK_ACTIVE]:
		for action: StringName in [&"jump", &"guard", &"evade", &"attack_special", &"ultimate"]:
			_settle(controller)
			var attack := fighter.runtime_profile.move_set.slots[0].attack
			fighter.call("_start_attack", attack, CombatIntent.Direction.RIGHT, controller.rules)
			fighter.state = phase
			fighter.attack_phase_tick = 0
			fighter.attack_landed = true
			fighter.runtime_state.ultimate_gauge = controller.rules.ultimate_gauge_max
			fighter.consume_intent(_intent(controller, fighter, action), controller.rules)
			_check(fighter.active_attack == attack and fighter.state == phase, "%s cannot cancel %s" % [action, FighterController.State.keys()[phase]])
	for recovery_tick: int in [0, 7, 8]:
		_settle(controller)
		var attack := fighter.runtime_profile.move_set.slots[0].attack
		fighter.call("_start_attack", attack, CombatIntent.Direction.RIGHT, controller.rules)
		fighter.state = FighterController.State.ATTACK_RECOVERY
		fighter.attack_phase_tick = recovery_tick
		fighter.consume_intent(_intent(controller, fighter, &"guard"), controller.rules)
		_check((fighter.state == FighterController.State.GUARD) == (recovery_tick <= 7), "guard cancel keeps the authored recovery 0..7 window")


func _test_cancel_restarts(controller: MatchController) -> void:
	for cancel_action: StringName in [&"guard", &"evade"]:
		_settle(controller)
		var source := controller.player
		var target := controller.training_dummy
		controller.submit_intent(_intent(controller, source, &"attack_light"))
		controller.step_fixed_tick(false)
		var attack := source.active_attack
		for ignored: int in attack.startup_ticks + attack.active_ticks:
			if source.state == FighterController.State.ATTACK_ACTIVE and source.attack_phase_tick == attack.active_ticks - 2: break
			controller.step_fixed_tick(false)
		target.global_position = Vector2(source.global_position.x + 55.0, 572)
		var initial_hp := target.current_hp
		controller.step_fixed_tick(false)
		_check(target.current_hp < initial_hp, "%s restart scenario begins with a real late hit" % cancel_action)
		var first_hp := target.current_hp
		var ready_ticks := 0
		var hit_gaps: Array[int] = []
		for ignored: int in 220:
			if target.state not in LOCKED_STATES: ready_ticks += 1
			if source.state == FighterController.State.ATTACK_RECOVERY and source.active_attack != null:
				source.consume_intent(_intent(controller, source, &"move", CombatIntent.Direction.RIGHT), controller.rules)
				source.consume_intent(_intent(controller, source, cancel_action), controller.rules)
				if cancel_action == &"evade": _check(source.state == FighterController.State.EVADE and source.invulnerability_ticks > 0, "recovery evade cancel actually evades")
				source.consume_intent(CombatIntent.new(controller.tick + 1, source.fighter_id, &"move", CombatIntent.Direction.RIGHT, CombatIntent.Edge.RELEASE), controller.rules)
				source.consume_intent(_intent(controller, source, &"attack_light"), controller.rules)
			elif source.active_attack == null:
				source.consume_intent(_intent(controller, source, &"attack_light"), controller.rules)
			controller.step_fixed_tick(false)
			if target.current_hp < first_hp:
				hit_gaps.append(ready_ticks)
				_check(ready_ticks >= 6, "%s cancel/release/light restart provides only %d actionable ticks" % [cancel_action, ready_ticks])
				first_hp = target.current_hp
				ready_ticks = 0
		_check(hit_gaps.size() >= 4, "%s repeated cancel restarts produce at least four real follow-up hits" % cancel_action)
		print("MATCH_PLAYTEST_CANCEL_RESTART: %s actionable_ticks=%s" % [cancel_action, hit_gaps])


func _test_restart_lock_lifecycle(controller: MatchController) -> void:
	var fighter := controller.player
	_settle(controller)
	var light := fighter.runtime_profile.move_set.slots[0].attack
	fighter.call("_start_attack", light, CombatIntent.Direction.RIGHT, controller.rules)
	fighter.state = FighterController.State.ATTACK_RECOVERY
	fighter.attack_phase_tick = 0
	fighter.consume_intent(_intent(controller, fighter, &"guard"), controller.rules)
	_check(fighter.attack_restart_lock_ticks == light.recovery_ticks, "defensive cancel preserves the full remaining recovery")
	fighter.runtime_state.ultimate_gauge = controller.rules.ultimate_gauge_max
	for action: StringName in [&"attack_light", &"attack_heavy", &"attack_special", &"ultimate"]:
		fighter.consume_intent(_intent(controller, fighter, action), controller.rules)
		_check(fighter.active_attack == null and fighter.charge_attack == null, "%s cannot restart during the defensive cancel lock" % action)
	_check(not fighter.runtime_state.ultimate_used_this_stock and fighter.runtime_state.ultimate_gauge == controller.rules.ultimate_gauge_max, "locked ultimate leaves gauge and stock use intact")
	_check(fighter.snapshot().get("attack_restart_lock_ticks") == light.recovery_ticks, "snapshot includes the deterministic attack restart lock")
	fighter.apply_hit(light, Vector2.ZERO, 10, controller.rules)
	_check(fighter.attack_restart_lock_ticks == light.recovery_ticks, "being hit does not restore the canceled attack opportunity")
	fighter.step_tick(controller.rules)
	_check(fighter.attack_restart_lock_ticks == light.recovery_ticks - 1, "restart lock decreases exactly once during hitstun")
	fighter.apply_network_snapshot({"attack_restart_lock_ticks": 12})
	_check(fighter.attack_restart_lock_ticks == 12, "network presentation restores the optional lock field")
	fighter.apply_network_snapshot({})
	_check(fighter.attack_restart_lock_ticks == 0, "legacy snapshots default the lock to zero")
	fighter.attack_restart_lock_ticks = 12
	fighter.lose_stock(controller.rules)
	_check(fighter.attack_restart_lock_ticks == 0, "stock loss clears the lock")
	fighter.attack_restart_lock_ticks = 12
	fighter.call("_respawn", controller.rules)
	_check(fighter.attack_restart_lock_ticks == 0, "stock return clears the lock")
	fighter.attack_restart_lock_ticks = 12
	controller.reset_match()
	_check(fighter.attack_restart_lock_ticks == 0, "rematch clears the lock")
	# Hit branches retain their immediate start, while a failed branch leaves the
	# current attack and its already-buffered light input intact.
	for action: StringName in [&"attack_special", &"ultimate"]:
		_settle(controller)
		fighter.call("_start_attack", light, CombatIntent.Direction.RIGHT, controller.rules)
		fighter.state = FighterController.State.ATTACK_RECOVERY
		fighter.attack_phase_tick = 0
		fighter.attack_landed = true
		fighter.runtime_state.ultimate_gauge = controller.rules.ultimate_gauge_max
		fighter.consume_intent(_intent(controller, fighter, action), controller.rules)
		_check(fighter.active_attack != null and fighter.active_attack.action_id == action and fighter.attack_restart_lock_ticks == 0, "%s hit cancel retains its immediate authored branch" % action)
		_settle(controller)
		fighter.call("_start_attack", light, CombatIntent.Direction.RIGHT, controller.rules)
		fighter.state = FighterController.State.ATTACK_RECOVERY
		fighter.attack_phase_tick = 0
		fighter.attack_landed = true
		fighter.buffered_intent = _intent(controller, fighter, &"attack_light")
		if action == &"attack_special": fighter.runtime_state.special_cooldown_ticks = 100
		fighter.consume_intent(_intent(controller, fighter, action), controller.rules)
		_check(fighter.active_attack == light and fighter.state == FighterController.State.ATTACK_RECOVERY and fighter.buffered_intent != null, "%s unavailable cancel preserves the attack and buffer" % action)
	for action: StringName in [&"jump", &"guard", &"evade"]:
		_settle(controller)
		fighter.global_position = Vector2(600, 250)
		fighter.step_tick(controller.rules)
		fighter.air_jumps_remaining = 0
		fighter.launcher_jump_available = false
		fighter.call("_start_attack", light, CombatIntent.Direction.RIGHT, controller.rules)
		fighter.state = FighterController.State.ATTACK_RECOVERY
		fighter.attack_phase_tick = 0
		fighter.consume_intent(_intent(controller, fighter, action), controller.rules)
		_check(fighter.active_attack == light and fighter.attack_restart_lock_ticks == 0, "unavailable airborne %s cancel keeps the current attack" % action)
	_settle(controller)
	fighter.call("_start_attack", light, CombatIntent.Direction.RIGHT, controller.rules)
	fighter.state = FighterController.State.ATTACK_RECOVERY
	fighter.consume_intent(_intent(controller, fighter, &"evade"), controller.rules)
	_check(fighter.active_attack == light, "neutral evade cancel keeps the current attack")
	fighter.consume_intent(_intent(controller, fighter, &"jump"), controller.rules)
	_check(fighter.state == FighterController.State.JUMP and fighter.attack_restart_lock_ticks == light.recovery_ticks, "normal jump cancel jumps immediately while retaining attack recovery")


func _test_hold_and_finisher(controller: MatchController) -> void:
	_settle(controller)
	var fighter := controller.player
	controller.submit_intent(_intent(controller, fighter, &"attack_light"))
	controller.step_fixed_tick(false)
	var activation := fighter.activation_serial
	for ignored: int in 50:
		controller.submit_intent(CombatIntent.new(controller.tick + 1, fighter.fighter_id, &"attack_light", CombatIntent.Direction.NEUTRAL, CombatIntent.Edge.HOLD))
		controller.step_fixed_tick(false)
	_check(fighter.active_attack == null and fighter.activation_serial == activation, "holding light cannot restart or advance the combo")
	for attack: AttackData in fighter.runtime_profile.move_set.attacks():
		if not attack.is_finisher or attack.action_id != &"attack_light": continue
		fighter.call("_start_attack", attack, CombatIntent.Direction.RIGHT, controller.rules)
		fighter.state = FighterController.State.ATTACK_RECOVERY
		fighter.attack_phase_tick = 0
		fighter.consume_intent(_intent(controller, fighter, &"guard"), controller.rules)
		_check(fighter.active_attack == attack, "finisher cannot cancel into guard")
		fighter.consume_intent(_intent(controller, fighter, &"attack_light"), controller.rules)
		_check(fighter.buffered_intent == null, "finisher cannot queue another combo stage")


func _intent(controller: MatchController, fighter: FighterController, action: StringName, direction := CombatIntent.Direction.NEUTRAL) -> CombatIntent:
	return CombatIntent.new(controller.tick + 1, fighter.fighter_id, action, direction, CombatIntent.Edge.PRESS, CombatIntent.Context.GROUND)


func _label(profile: RuntimeCombatProfile) -> String:
	return "%s/%s" % [profile.character_id, profile.accessory_id]


func _data_signature(catalog: LoadoutCatalog) -> String:
	var values: Array = []
	for character: CharacterData in catalog.characters:
		for attack: AttackData in character.base_move_set.attacks():
			values.append([attack.attack_id, attack.startup_ticks, attack.active_ticks, attack.recovery_ticks, attack.fixed_hitstun_ticks, attack.damage, attack.knockback])
	return JSON.stringify(values)


func _check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message): failures.append(message)
