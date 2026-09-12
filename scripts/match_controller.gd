class_name MatchController
extends Node

signal snapshot_changed(snapshot: Dictionary)
signal match_ended(winner_id: StringName)

@export var rules: CombatRules
@export var player: FighterController
@export var training_dummy: FighterController
@export var loadout_catalog: LoadoutCatalog
@export var player_selection: LoadoutSelection
@export var training_dummy_selection: LoadoutSelection
@export var phase3_debug_match: Phase3DebugMatchConfig
@export var bot_profile: BotCommandProfile
@export var bot_seed: int = 3001
@export var playtest_scenario_id: StringName = &"manual"
@export var telemetry_enabled := false

const BOT_PROFILE_PATHS := {
	&"spacing": "res://assets/combat/bots/spacing_profile.tres",
	&"aerial": "res://assets/combat/bots/aerial_profile.tres",
	&"close": "res://assets/combat/bots/close_profile.tres",
}

var tick := 0
var paused := false
var winner_id: StringName
var sudden_death_round := 0
var _queued_intents: Array[CombatIntent] = []
var _hit_counts: Dictionary = {}
var _last_player_direction: CombatIntent.Direction = CombatIntent.Direction.NEUTRAL
var _bot_source: DeterministicBotCommandSource
var _telemetry := Phase3PlaytestTelemetry.new()


func _ready() -> void:
	if player == null: player = get_node("../World/Player") as FighterController
	if training_dummy == null: training_dummy = get_node("../World/TrainingDummy") as FighterController
	_apply_phase3_debug_match()
	if not _configure_fighters():
		paused = true
		push_error("Match did not start because loadout construction failed.")
		return
	_configure_bot()
	reset_match()


func _apply_phase3_debug_match() -> void:
	if phase3_debug_match == null:
		return
	if not OS.is_debug_build() or not phase3_debug_match.is_valid_definition():
		push_error("Phase 3 debug match is only valid in a debug build with two fighter scenes.")
		return
	var world := player.get_parent()
	var player_position := player.global_position
	var dummy_position := training_dummy.global_position
	world.remove_child(player)
	world.remove_child(training_dummy)
	player.queue_free()
	training_dummy.queue_free()
	player = phase3_debug_match.player_fighter_scene.instantiate() as FighterController
	training_dummy = phase3_debug_match.training_dummy_fighter_scene.instantiate() as FighterController
	player.name = "Player"
	training_dummy.name = "TrainingDummy"
	world.add_child(player)
	world.add_child(training_dummy)
	player.global_position = player_position
	training_dummy.global_position = dummy_position
	var player_loadout := LoadoutSelection.new()
	player_loadout.character_id = player.fighter_id
	var dummy_loadout := LoadoutSelection.new()
	dummy_loadout.character_id = training_dummy.fighter_id
	player_selection = player_loadout
	training_dummy_selection = dummy_loadout


func _physics_process(_delta: float) -> void:
	if not paused: step_fixed_tick()


func submit_intent(intent: CombatIntent) -> void:
	_queued_intents.append(intent)


func step_fixed_tick(poll_local_input := true) -> void:
	if paused or not winner_id.is_empty(): return
	tick += 1
	if poll_local_input: _poll_player_input()
	if _bot_source != null:
		for intent: CombatIntent in _bot_source.commands_for_tick(tick, snapshot()):
			submit_intent(intent)
	_process_intents()
	player.step_tick(rules)
	training_dummy.step_tick(rules)
	_resolve_hits()
	_resolve_ring_outs()
	snapshot_changed.emit(snapshot())


func reset_match() -> void:
	if _telemetry.is_match_active():
		_telemetry.cancel_match()
	tick = 0
	paused = false
	winner_id = &""
	sudden_death_round = 0
	_queued_intents.clear()
	_hit_counts.clear()
	_last_player_direction = CombatIntent.Direction.NEUTRAL
	player.reset_for_match(rules)
	training_dummy.reset_for_match(rules)
	if telemetry_enabled:
		_telemetry.begin_match(playtest_scenario_id, bot_seed, [
			{"slot": &"player", "character_id": player_selection.character_id, "job_id": player_selection.job_id},
			{"slot": &"dummy", "character_id": training_dummy_selection.character_id, "job_id": training_dummy_selection.job_id, "bot_profile_id": &"" if bot_profile == null else bot_profile.profile_id},
		], rules.physics_ticks_per_second)
	snapshot_changed.emit(snapshot())


func configure_debug_match(config: Dictionary) -> bool:
	if not OS.is_debug_build() or loadout_catalog == null:
		return false
	var player_character := StringName(config.get("player_character_id", &""))
	var dummy_character := StringName(config.get("dummy_character_id", &""))
	var selected_bot := StringName(config.get("bot_profile_id", &"spacing"))
	if loadout_catalog.character_by_id(player_character) == null or loadout_catalog.character_by_id(dummy_character) == null or not BOT_PROFILE_PATHS.has(selected_bot):
		return false
	player_selection.character_id = player_character
	player_selection.job_id = StringName(config.get("player_job_id", &""))
	training_dummy_selection.character_id = dummy_character
	training_dummy_selection.job_id = StringName(config.get("dummy_job_id", &""))
	player.fighter_id = player_character
	player.character_data = loadout_catalog.character_by_id(player_character)
	training_dummy.fighter_id = dummy_character
	training_dummy.character_data = loadout_catalog.character_by_id(dummy_character)
	bot_profile = load(BOT_PROFILE_PATHS[selected_bot]) as BotCommandProfile
	bot_seed = int(config.get("seed", 3001))
	playtest_scenario_id = StringName(config.get("scenario_id", &"manual"))
	telemetry_enabled = true
	if not _configure_fighters():
		return false
	_configure_bot()
	reset_match()
	return true


func _configure_bot() -> void:
	_bot_source = null
	if bot_profile != null and bot_profile.is_valid_definition():
		_bot_source = DeterministicBotCommandSource.new(bot_profile, bot_seed, training_dummy.fighter_id, player.fighter_id)


func _configure_fighters() -> bool:
	if loadout_catalog == null or player_selection == null or training_dummy_selection == null:
		push_error("Match requires a LoadoutCatalog and two LoadoutSelections.")
		return false
	var player_result := LoadoutBuilder.build(player_selection, loadout_catalog, rules.combat_tuning)
	var dummy_result := LoadoutBuilder.build(training_dummy_selection, loadout_catalog, rules.combat_tuning)
	if not player_result.succeeded() or not dummy_result.succeeded():
		push_error("Loadout build failed: player=%s dummy=%s" % [player_result.error_codes, dummy_result.error_codes])
		return false
	if not player.configure_profile(player_result.profile) or not training_dummy.configure_profile(dummy_result.profile):
		push_error("Loadout build produced a profile for the wrong fighter.")
		return false
	return true


func pause_match(value: bool) -> void:
	paused = value
	if value:
		_queued_intents.clear()
		_last_player_direction = CombatIntent.Direction.NEUTRAL
		player.release_transient_input(rules)
		training_dummy.release_transient_input(rules)


func snapshot() -> Dictionary:
	return {"tick": tick, "paused": paused, "winner_id": winner_id, "sudden_death_round": sudden_death_round, "fighters": [player.snapshot(), training_dummy.snapshot()]}


func snapshot_hash() -> String:
	return JSON.stringify(snapshot(), "", true).sha256_text()


func _poll_player_input() -> void:
	var direction := _current_direction()
	if direction != _last_player_direction:
		if _last_player_direction != CombatIntent.Direction.NEUTRAL:
			submit_intent(CombatIntent.new(tick, player.fighter_id, &"move", _last_player_direction, CombatIntent.Edge.RELEASE, _context_for(player)))
		if direction != CombatIntent.Direction.NEUTRAL:
			submit_intent(CombatIntent.new(tick, player.fighter_id, &"move", direction, CombatIntent.Edge.PRESS, _context_for(player)))
		_last_player_direction = direction
	elif direction != CombatIntent.Direction.NEUTRAL:
		submit_intent(CombatIntent.new(tick, player.fighter_id, &"move", direction, CombatIntent.Edge.HOLD, _context_for(player)))
	for action: StringName in [&"jump", &"dash", &"attack_light", &"attack_heavy", &"attack_special", &"grab_support", &"ultimate"]:
		if Input.is_action_just_pressed(action):
			submit_intent(CombatIntent.new(tick, player.fighter_id, action, direction, CombatIntent.Edge.PRESS, _context_for(player)))
		elif Input.is_action_just_released(action):
			submit_intent(CombatIntent.new(tick, player.fighter_id, action, direction, CombatIntent.Edge.RELEASE, _context_for(player)))
		elif action == &"dash" and Input.is_action_pressed(action):
			submit_intent(CombatIntent.new(tick, player.fighter_id, action, direction, CombatIntent.Edge.HOLD, _context_for(player)))


func _process_intents() -> void:
	var due: Array[CombatIntent] = []
	for intent: CombatIntent in _queued_intents:
		if intent.tick <= tick: due.append(intent)
	for intent: CombatIntent in due: _queued_intents.erase(intent)
	due.sort_custom(func(a: CombatIntent, b: CombatIntent) -> bool:
		var left := "%010d:%s:%s:%d" % [a.tick, a.fighter_id, a.action_id, a.edge]
		var right := "%010d:%s:%s:%d" % [b.tick, b.fighter_id, b.action_id, b.edge]
		return left < right
	)
	for intent: CombatIntent in due:
		var fighter := _fighter_by_id(intent.fighter_id)
		if fighter == null:
			continue
		var was_ultimate_used := fighter.ultimate_used
		var charge_before := fighter.charge_ticks
		fighter.consume_intent(intent, rules)
		if _telemetry.is_match_active():
			if intent.edge == CombatIntent.Edge.PRESS:
				_telemetry.record_action(intent.action_id)
			if intent.action_id == &"dash" and intent.edge == CombatIntent.Edge.PRESS and intent.direction in [CombatIntent.Direction.LEFT, CombatIntent.Direction.RIGHT]:
				_telemetry.record_evade(false)
			elif intent.action_id == &"dash" and intent.edge == CombatIntent.Edge.PRESS and intent.direction == CombatIntent.Direction.NEUTRAL:
				_telemetry.record_guard(false)
			elif intent.action_id == &"grab_support" and intent.edge == CombatIntent.Edge.PRESS:
				_telemetry.record_grab(false)
			elif intent.action_id == &"attack_heavy" and intent.edge == CombatIntent.Edge.RELEASE:
				var tuning := fighter.runtime_profile.combat_tuning
				var stage := &"normal" if charge_before < tuning.charge_start_ticks else &"maximum" if charge_before >= tuning.charge_max_ticks else &"charged"
				_telemetry.record_charge_stage(stage)
			elif intent.action_id == &"attack_special" and fighter.diagnostic == "special_cooldown_active":
				_telemetry.record_special_cooldown_violation()
			if not was_ultimate_used and fighter.ultimate_used:
				_telemetry.record_ultimate_use()


func _resolve_hits() -> void:
	var candidates: Array[Dictionary] = []
	for source: FighterController in _fighters():
		for target: FighterController in _fighters():
			if source == target or source.active_attack == null or source.state != FighterController.State.ATTACK_ACTIVE: continue
			if not source.get_hitbox_rect().intersects(target.get_hurtbox_rect()): continue
			var key := "%s:%d:%s" % [source.fighter_id, source.activation_serial, target.fighter_id]
			var count: int = _hit_counts.get(key, 0)
			if count >= source.active_attack.max_hits_per_target: continue
			var last_tick: int = _hit_counts.get("%s:last" % key, -999)
			if count > 0 and tick - last_tick < source.active_attack.rehit_interval_ticks: continue
			if target.state == FighterController.State.RING_OUT: continue
			if target.is_invulnerable():
				if _telemetry.is_match_active() and target.state in [FighterController.State.EVADE_GROUND, FighterController.State.EVADE_AIR]:
					_telemetry.record_evade(true)
				continue
			candidates.append({
				"source": source, "target": target, "attack": source.active_attack, "key": key,
				"activation_serial": source.activation_serial,
				"source_position": source.global_position, "target_position": target.global_position,
				"source_facing": source.locked_facing, "target_damage": target.damage_percent,
				"source_direction": source.locked_direction,
				"target_direction": target.input_direction,
			})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left_priority := 1 if a.attack.is_grab() else 0
		var right_priority := 1 if b.attack.is_grab() else 0
		return "%d:%s:%s:%s" % [left_priority, a.source.fighter_id, a.target.fighter_id, a.attack.attack_id] < "%d:%s:%s:%s" % [right_priority, b.source.fighter_id, b.target.fighter_id, b.attack.attack_id]
	)
	for hit: Dictionary in candidates:
		var attack: AttackData = hit.attack
		var source: FighterController = hit.source
		var target: FighterController = hit.target
		if source.active_attack != attack or source.activation_serial != int(hit.activation_serial) or source.state != FighterController.State.ATTACK_ACTIVE:
			continue
		var resolved_damage := source.resolved_attack_damage()
		if target.state == FighterController.State.GUARD and not attack.is_grab():
			target.apply_guarded_hit(attack, rules, resolved_damage)
			if not attack.is_ultimate(): source.register_landed_hit(attack)
			if _telemetry.is_match_active(): _telemetry.record_guard(true)
			_hit_counts[hit.key] = int(_hit_counts.get(hit.key, 0)) + 1
			_hit_counts["%s:last" % hit.key] = tick
			continue
		var damage_after := float(hit.target_damage) + resolved_damage
		var speed := (source.resolved_attack_base_knockback() + damage_after * attack.knockback_growth) / target._stats().weight
		var direction := _launch_direction(attack, hit.source_position, hit.target_position, hit.source_facing, hit.source_direction)
		direction = direction.rotated(_di_angle(hit.target_direction))
		var stun := clampi(roundi(speed / 20.0), rules.hitstun_min_ticks, rules.hitstun_max_ticks)
		target.apply_hit(attack, direction * speed, stun, resolved_damage)
		source.register_landed_hit(attack)
		source.add_ultimate_from_damage(resolved_damage, true)
		target.add_ultimate_from_damage(resolved_damage, false)
		if _telemetry.is_match_active():
			_telemetry.record_ultimate_charge(resolved_damage * (source.runtime_profile.combat_tuning.ultimate_dealt_damage_gain_multiplier + target.runtime_profile.combat_tuning.ultimate_received_damage_gain_multiplier))
			if attack.is_grab(): _telemetry.record_grab(true)
			if attack.is_ultimate(): _telemetry.record_ultimate_hit()
		_hit_counts[hit.key] = int(_hit_counts.get(hit.key, 0)) + 1
		_hit_counts["%s:last" % hit.key] = tick


func _resolve_ring_outs() -> void:
	var ring_outs: Array[FighterController] = []
	for fighter: FighterController in _fighters():
		var point := fighter.global_position
		if fighter.state != FighterController.State.RING_OUT and (point.x < rules.ring_left or point.x > rules.ring_right or point.y < rules.ring_top or point.y > rules.ring_bottom):
			ring_outs.append(fighter)
	if ring_outs.is_empty(): return
	var final_simultaneous := ring_outs.size() == 2 and player.stocks == 1 and training_dummy.stocks == 1
	for fighter: FighterController in ring_outs:
		fighter.ring_out(rules)
		if _telemetry.is_match_active(): _telemetry.record_ring_out(fighter.fighter_id)
	if final_simultaneous:
		sudden_death_round += 1
		player.begin_sudden_death(rules)
		training_dummy.begin_sudden_death(rules)
		return
	for fighter: FighterController in _fighters():
		if fighter.stocks <= 0:
			winner_id = training_dummy.fighter_id if fighter == player else player.fighter_id
			player.state = FighterController.State.MATCH_ENDED
			training_dummy.state = FighterController.State.MATCH_ENDED
			match_ended.emit(winner_id)
			if _telemetry.is_match_active(): _telemetry.finish_match(winner_id, tick, snapshot_hash())
			return


func _launch_direction(attack: AttackData, source_position: Vector2, target_position: Vector2, source_facing: int, source_direction: CombatIntent.Direction) -> Vector2:
	if attack.launch_mode == AttackData.LaunchMode.TOWARD_SOURCE:
		return (source_position - target_position).normalized()
	var result := attack.launch_vector
	if attack.input_direction == AttackData.InputDirection.OMNI:
		match source_direction:
			CombatIntent.Direction.UP: result = Vector2(0.2, -1.0)
			CombatIntent.Direction.DOWN: result = Vector2(0.2, 1.0)
			CombatIntent.Direction.LEFT:
				if source_facing > 0: result.x = -absf(result.x)
			CombatIntent.Direction.RIGHT:
				if source_facing < 0: result.x = -absf(result.x)
	result.x *= source_facing
	return result.normalized()


func _di_angle(direction: CombatIntent.Direction) -> float:
	var amount := 0.0
	if direction in [CombatIntent.Direction.LEFT, CombatIntent.Direction.UP]: amount = -1.0
	elif direction in [CombatIntent.Direction.RIGHT, CombatIntent.Direction.DOWN]: amount = 1.0
	return deg_to_rad(amount * rules.di_max_degrees)


func _current_direction() -> CombatIntent.Direction:
	var horizontal := Input.get_axis(&"move_left", &"move_right")
	var vertical := Input.get_axis(&"move_up", &"move_down")
	if absf(horizontal) >= absf(vertical) and not is_zero_approx(horizontal):
		return CombatIntent.Direction.RIGHT if horizontal > 0.0 else CombatIntent.Direction.LEFT
	if not is_zero_approx(vertical): return CombatIntent.Direction.DOWN if vertical > 0.0 else CombatIntent.Direction.UP
	return CombatIntent.Direction.NEUTRAL


func _context_for(fighter: FighterController) -> CombatIntent.Context:
	return CombatIntent.Context.GROUND if fighter.is_on_floor() else CombatIntent.Context.AIR


func _fighter_by_id(id: StringName) -> FighterController:
	if player.fighter_id == id: return player
	if training_dummy.fighter_id == id: return training_dummy
	return null


func _fighters() -> Array[FighterController]:
	return [player, training_dummy]
