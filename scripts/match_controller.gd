class_name MatchController
extends Node

const CommandResolverScript = preload("res://scripts/command_resolver.gd")
const EffectControllerScript = preload("res://scripts/effect_controller.gd")
const EffectData = preload("res://scripts/data/combat_effect_data.gd")

signal snapshot_changed(snapshot: Dictionary)
signal match_ended(winner_id: StringName)

@export var rules: CombatRules
@export var player: FighterController
@export var training_dummy: FighterController
@export var loadout_catalog: LoadoutCatalog
@export var player_selection: LoadoutSelection
@export var training_dummy_selection: LoadoutSelection

var tick := 0
var paused := false
var winner_id: StringName
var sudden_death_round := 0
var is_draw := false
var _queued_intents: Array[CombatIntent] = []
var _hit_counts: Dictionary = {}
var _last_player_direction: CombatIntent.Direction = CombatIntent.Direction.NEUTRAL


func _ready() -> void:
	if player == null: player = get_node("../World/Player") as FighterController
	if training_dummy == null: training_dummy = get_node("../World/TrainingDummy") as FighterController
	if not _configure_fighters():
		paused = true
		push_error("Match did not start because loadout construction failed.")
		return
	reset_match()


func _physics_process(_delta: float) -> void:
	if not paused: step_fixed_tick()


func submit_intent(intent: CombatIntent) -> void:
	_queued_intents.append(intent)


func step_fixed_tick(poll_local_input := true) -> void:
	if paused or not winner_id.is_empty() or is_draw: return
	tick += 1
	if poll_local_input: _poll_player_input()
	_process_intents()
	player.step_tick(rules)
	training_dummy.step_tick(rules)
	_resolve_hits()
	_resolve_ring_outs()
	snapshot_changed.emit(snapshot())


func reset_match() -> void:
	tick = 0
	paused = false
	winner_id = &""
	sudden_death_round = 0
	is_draw = false
	_queued_intents.clear()
	_hit_counts.clear()
	_last_player_direction = CombatIntent.Direction.NEUTRAL
	player.reset_for_match(rules)
	training_dummy.reset_for_match(rules)
	snapshot_changed.emit(snapshot())


func _configure_fighters() -> bool:
	if loadout_catalog == null or player_selection == null or training_dummy_selection == null:
		push_error("Match requires a LoadoutCatalog and two LoadoutSelections.")
		return false
	var player_result := LoadoutBuilder.build(player_selection, loadout_catalog)
	var dummy_result := LoadoutBuilder.build(training_dummy_selection, loadout_catalog)
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
		player.input_direction = CombatIntent.Direction.NEUTRAL
		player.buffered_intent = null
		training_dummy.input_direction = CombatIntent.Direction.NEUTRAL
		training_dummy.buffered_intent = null


func snapshot() -> Dictionary:
	return {"tick": tick, "paused": paused, "winner_id": winner_id, "is_draw": is_draw, "fighters": [player.snapshot(), training_dummy.snapshot()]}


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
	for action: StringName in [&"jump", &"dash", &"attack_light", &"attack_heavy", &"attack_special"]:
		if Input.is_action_just_pressed(action):
			submit_intent(CombatIntent.new(tick, player.fighter_id, action, direction, CombatIntent.Edge.PRESS, _context_for(player)))
		elif Input.is_action_just_released(action):
			submit_intent(CombatIntent.new(tick, player.fighter_id, action, direction, CombatIntent.Edge.RELEASE, _context_for(player)))


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
	for intent: CombatIntent in CommandResolverScript.resolve(due):
		var fighter := _fighter_by_id(intent.fighter_id)
		if fighter != null: fighter.consume_intent(intent, rules)


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
			if target.invulnerability_ticks > 0 or target.state == FighterController.State.RING_OUT: continue
			candidates.append({
				"source": source, "target": target, "attack": source.active_attack, "key": key,
			})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return "%s:%s:%s" % [a.source.fighter_id, a.target.fighter_id, a.attack.attack_id] < "%s:%s:%s" % [b.source.fighter_id, b.target.fighter_id, b.attack.attack_id]
	)
	for hit: Dictionary in candidates:
		var attack: AttackData = hit.attack
		var target: FighterController = hit.target
		var context := HitContext.new(tick, hit.source, target, attack)
		context.source_position = hit.source.global_position
		context.target_position = target.global_position
		context.source_facing = hit.source.locked_facing
		context.source_direction = hit.source.locked_direction
		var result := HitResolver.resolve(context, rules)
		if result.landed(): hit.source.register_landed_hit(attack)
		_hit_counts[hit.key] = int(_hit_counts.get(hit.key, 0)) + 1
		_hit_counts["%s:last" % hit.key] = tick
	_resolve_final_losses()


func _resolve_ring_outs() -> void:
	var ring_outs: Array[FighterController] = []
	for fighter: FighterController in _fighters():
		var point := fighter.global_position
		if fighter.state != FighterController.State.RING_OUT and (point.x < rules.ring_left or point.x > rules.ring_right or point.y < rules.ring_top or point.y > rules.ring_bottom):
			ring_outs.append(fighter)
	if ring_outs.is_empty(): return
	for fighter: FighterController in ring_outs: fighter.ring_out(rules)
	_resolve_final_losses()


func _resolve_final_losses() -> void:
	for fighter: FighterController in _fighters():
		if fighter.state == FighterController.State.DEAD:
			EffectControllerScript.dispatch(EffectData.Trigger.ON_DEATH, fighter, _other_fighter(fighter), rules)
	if player.state == FighterController.State.DEAD and training_dummy.state == FighterController.State.DEAD:
		is_draw = true
		match_ended.emit(&"DRAW")
		return
	for fighter: FighterController in _fighters():
		if fighter.state == FighterController.State.DEAD:
			winner_id = training_dummy.fighter_id if fighter == player else player.fighter_id
			player.state = FighterController.State.MATCH_ENDED
			training_dummy.state = FighterController.State.MATCH_ENDED
			match_ended.emit(winner_id)
			return


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


func _other_fighter(fighter: FighterController) -> FighterController:
	return training_dummy if fighter == player else player
