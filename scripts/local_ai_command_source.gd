class_name LocalAICommandSource
extends RefCounted

const DEFAULT_STAGE: StageData = preload("res://assets/combat/stages/forest_ledge_stage.tres")

## Snapshot-only normal opponent. No direct fighter access, resource mutation,
## movement teleport, or bypass of action/cooldown checks is available here.
var fighter_id: StringName
var team_id: StringName
var match_seed: int
var reaction_interval_ticks := 18
var preferred_distance := 62.0
var simplified_combat := false
var heavy_range := 105.0
var stage_data: StageData
var _direction := CombatIntent.Direction.NEUTRAL
var _heavy_release_tick := -1
var _next_reaction_tick := 1
enum Tactic { APPROACH, KEEP_DISTANCE, RETREAT, WAIT, DEFEND }
const TARGET_HOLD_TICKS := 90
const TACTIC_MIN_TICKS := 36
const TACTIC_MAX_TICKS := 72
var _tactic := Tactic.APPROACH
var _tactic_until_tick := 0
var _target_id: StringName = &""
var _target_until_tick := 0
var _climb_surface: StageSurfaceData
var _rng := RandomNumberGenerator.new()


func _init(id: StringName = &"", seed_value: int = 1, settings: Dictionary = {}) -> void:
	fighter_id = id
	match_seed = seed_value
	team_id = StringName(settings.get("team_id", &""))
	simplified_combat = bool(settings.get("simplified_combat", false))
	heavy_range = maxf(105, float(settings.get("heavy_range", 105)))
	reaction_interval_ticks = maxi(1, int(settings.get("reaction_interval_ticks", 18)))
	preferred_distance = clampf(float(settings.get("preferred_distance", 62.0)), 40.0, 100.0)
	stage_data = settings.get("stage_data", DEFAULT_STAGE) as StageData
	if stage_data == null or not stage_data.is_valid_definition():
		stage_data = DEFAULT_STAGE
	reset()


func reset() -> void:
	_rng.seed = match_seed
	_direction = CombatIntent.Direction.NEUTRAL
	_heavy_release_tick = -1
	_next_reaction_tick = 1
	_tactic = Tactic.APPROACH
	_tactic_until_tick = 0
	_target_id = &""
	_target_until_tick = 0
	_climb_surface = null


func commands_for_tick(tick: int, match_snapshot: Dictionary) -> Array[CombatIntent]:
	var use_simplified := simplified_combat or bool(match_snapshot.get("simplified_combat", false))
	if use_simplified: _heavy_release_tick = -1
	var commands: Array[CombatIntent] = []
	var actor: Dictionary = {}
	var opponent: Dictionary = {}
	for fighter: Dictionary in match_snapshot.get("fighters", []):
		if StringName(fighter.id) == fighter_id: actor = fighter
	if actor.is_empty(): return commands
	var previous_target := _target_id
	opponent = _select_target(tick, actor, match_snapshot.get("fighters", []))
	if previous_target != _target_id:
		_next_reaction_tick = mini(_next_reaction_tick, tick)
		_tactic_until_tick = 0
	var context := CombatIntent.Context.GROUND if actor.get("on_floor", false) else CombatIntent.Context.AIR
	if _heavy_release_tick >= 0 and tick >= _heavy_release_tick:
		commands.append(_intent(tick, &"attack_heavy", _direction, context, CombatIntent.Edge.RELEASE))
		_heavy_release_tick = -1
		_next_reaction_tick = tick + reaction_interval_ticks
		return commands
	if tick < _next_reaction_tick: return commands
	_next_reaction_tick = tick + reaction_interval_ticks
	if actor.state in ["DEAD", "MATCH_ENDED", "RING_OUT", "SPAWNING", "FALLING_OUT"]:
		_set_direction(commands, tick, CombatIntent.Direction.NEUTRAL, context)
		return commands
	var position: Vector2 = actor.position
	var target: Vector2 = position if opponent.is_empty() else opponent.position
	var velocity: Vector2 = actor.velocity
	var delta := target - position
	if context == CombatIntent.Context.GROUND:
		_climb_surface = null
	var floor := stage_data.main_floor()
	var ground_left := floor.rect.position.x
	var ground_right := floor.rect.end.x
	var ground_center := floor.rect.get_center().x
	var toward := CombatIntent.Direction.RIGHT if delta.x >= 0.0 else CombatIntent.Direction.LEFT
	var action: StringName = &""
	var action_direction := toward
	var direction := toward if absf(delta.x) > preferred_distance else CombatIntent.Direction.NEUTRAL
	# Recover toward the stage before considering attacks. Preserve horizontal
	# movement while issuing UP special, which the fighter may reject normally.
	if position.x < ground_left + 40.0 or position.x > ground_right - 40.0:
		direction = CombatIntent.Direction.RIGHT if position.x < ground_center else CombatIntent.Direction.LEFT
		if context == CombatIntent.Context.AIR and velocity.y > -60.0:
			if int(actor.get("air_jumps", 0)) > 0:
				action = &"jump"
			elif not use_simplified and actor.get("up_special", false) and int(actor.get("special_cooldown_ticks", 0)) == 0:
				action = &"attack_special"
				action_direction = CombatIntent.Direction.UP
	elif opponent.is_empty():
		direction = CombatIntent.Direction.NEUTRAL
	elif context == CombatIntent.Context.AIR and _climb_surface != null:
		# Keep aiming at the intermediate landing surface throughout a jump.
		# Chasing the final target mid-air used to overshoot narrow platforms.
		var landing_x := clampf(target.x, _climb_surface.rect.position.x + 45.0, _climb_surface.rect.end.x - 45.0)
		direction = CombatIntent.Direction.NEUTRAL if absf(landing_x - position.x) < 20.0 else (CombatIntent.Direction.RIGHT if landing_x > position.x else CombatIntent.Direction.LEFT)
		if velocity.y > -160.0 and position.y + 14.0 > _climb_surface.rect.position.y and int(actor.get("air_jumps", 0)) > 0:
			action = &"jump"
	elif delta.y < -50.0 and context == CombatIntent.Context.GROUND:
		# Pick the lowest useful platform above the actor, then approach its nearest edge.
		var climb := _next_climb_surface(position, target)
		_climb_surface = climb
		if climb != null:
			if position.x < climb.rect.position.x + 30.0: direction = CombatIntent.Direction.RIGHT
			elif position.x > climb.rect.end.x - 30.0: direction = CombatIntent.Direction.LEFT
			else:
				direction = toward
			if _should_jump_toward_surface(position, climb):
				action = &"jump"
	elif delta.y < -35.0 and context == CombatIntent.Context.AIR and velocity.y > -160.0 and int(actor.get("air_jumps", 0)) > 0:
		# The upper floor is higher than a single jump for some profiles.
		action = &"jump"
	elif delta.y > 85.0 and context == CombatIntent.Context.GROUND and position.y < 450.0:
		direction = CombatIntent.Direction.DOWN
		action_direction = CombatIntent.Direction.DOWN
		action = &"jump"
	else:
		if tick >= _tactic_until_tick:
			_choose_tactic(tick, actor, opponent, delta)
		var close := absf(delta.x) < 105.0 and absf(delta.y) < 80.0
		var threat: bool = close and opponent.state in ["ATTACK_STARTUP", "ATTACK_ACTIVE"]
		# React to a visible wind-up, not hidden future commands. A failed guard
		# or evade is rejected through the same fighter rules as human input.
		if threat and context == CombatIntent.Context.GROUND and _rng.randi_range(0, 9) < 5:
			_tactic = Tactic.DEFEND
			_tactic_until_tick = tick + TACTIC_MIN_TICKS
		var away := CombatIntent.Direction.LEFT if toward == CombatIntent.Direction.RIGHT else CombatIntent.Direction.RIGHT
		match _tactic:
			Tactic.APPROACH:
				direction = toward if absf(delta.x) > preferred_distance else CombatIntent.Direction.NEUTRAL
			Tactic.KEEP_DISTANCE:
				if absf(delta.x) < preferred_distance - 18.0 and _safe_retreat(position, away): direction = away
				elif absf(delta.x) > preferred_distance + 24.0: direction = toward
				else: direction = CombatIntent.Direction.NEUTRAL
			Tactic.RETREAT:
				direction = away if _safe_retreat(position, away) else CombatIntent.Direction.NEUTRAL
			Tactic.WAIT:
				direction = CombatIntent.Direction.NEUTRAL
			Tactic.DEFEND:
				direction = CombatIntent.Direction.DOWN if context == CombatIntent.Context.GROUND else CombatIntent.Direction.NEUTRAL
				if not use_simplified and threat and _rng.randi_range(0, 3) == 0 and _safe_retreat(position, away):
					direction = away
					action = &"evade"
					action_direction = away
		# Counter a recovery opening immediately at the next reaction. Attack
		# variety stays modest, preserving the normal opponent difficulty.
		var counter: bool = close and opponent.state == "ATTACK_RECOVERY"
		var can_attack: bool = close and (_tactic == Tactic.APPROACH or (_tactic == Tactic.KEEP_DISTANCE and direction != away) or counter)
		if can_attack and action.is_empty():
			direction = toward
			var choice := _rng.randi_range(0, 11)
			if not use_simplified and float(actor.get("ultimate_gauge", 0.0)) >= float(match_snapshot.get("ultimate_gauge_max", 100.0)) and not actor.get("ultimate_used_this_stock", false):
				action = &"ultimate"
				action_direction = CombatIntent.Direction.NEUTRAL
			elif choice == 8 and int(actor.get("special_cooldown_ticks", 0)) == 0 and (not use_simplified or context == CombatIntent.Context.GROUND):
				action = &"attack_special"
			elif choice == 9 and _heavy_release_tick < 0:
				action = &"attack_heavy"
				if not use_simplified: _heavy_release_tick = tick + reaction_interval_ticks
			elif choice == 10 and context == CombatIntent.Context.GROUND and not counter:
				action = &"jump"
			elif choice < 11 or counter:
				action = &"attack_light"
	if use_simplified:
		if context == CombatIntent.Context.GROUND and not opponent.is_empty() and absf(delta.y) < 80 and absf(delta.x) >= 105 and absf(delta.x) <= heavy_range and _tactic == Tactic.APPROACH:
			action = &"attack_heavy"
			direction = toward
			action_direction = toward
		if int(actor.get("air_lock", 0)) > 0:
			action = &""
			if int(actor.get("air_lock", 0)) == 2: direction = CombatIntent.Direction.NEUTRAL
		if context == CombatIntent.Context.AIR:
			if action == &"attack_special": action = &""
			if action == &"attack_light" and actor.get("air_light_used", false): action = &"attack_heavy" if not actor.get("air_heavy_used", false) else &""
			if action == &"attack_heavy" and actor.get("air_heavy_used", false): action = &"attack_light" if not actor.get("air_light_used", false) else &""
	_set_direction(commands, tick, direction, context)
	if not action.is_empty(): commands.append(_intent(tick, action, action_direction, context))
	return commands


func _valid_target(candidate: Dictionary) -> bool:
	return StringName(candidate.get("id", &"")) != fighter_id and int(candidate.get("stocks", 1)) > 0 and not String(candidate.get("state", "")) in ["DEAD", "MATCH_ENDED", "RING_OUT", "SPAWNING", "FALLING_OUT"] and (team_id.is_empty() or StringName(candidate.get("team_id", &"")) != team_id)


func _select_target(tick: int, actor: Dictionary, fighters: Array) -> Dictionary:
	if tick < _target_until_tick:
		for candidate: Dictionary in fighters:
			if StringName(candidate.get("id", &"")) == _target_id and _valid_target(candidate): return candidate
	var nearest: Dictionary = {}
	var nearest_distance := INF
	var position: Vector2 = actor.get("position", Vector2.ZERO)
	for candidate: Dictionary in fighters:
		if not _valid_target(candidate): continue
		var target_position: Vector2 = candidate.get("position", Vector2.ZERO)
		var distance := target_position.distance_squared_to(position)
		if distance < nearest_distance or (is_equal_approx(distance, nearest_distance) and (nearest.is_empty() or StringName(candidate.id) < StringName(nearest.id))):
			nearest = candidate
			nearest_distance = distance
	_target_id = &"" if nearest.is_empty() else StringName(nearest.id)
	_target_until_tick = tick + TARGET_HOLD_TICKS
	return nearest


func _choose_tactic(tick: int, actor: Dictionary, opponent: Dictionary, delta: Vector2) -> void:
	_tactic_until_tick = tick + _rng.randi_range(TACTIC_MIN_TICKS, TACTIC_MAX_TICKS)
	if absf(delta.x) > 165.0 or absf(delta.y) > 80.0:
		_tactic = Tactic.APPROACH
		return
	var choice := _rng.randi_range(0, 9)
	if choice < 5: _tactic = Tactic.APPROACH
	elif choice < 7: _tactic = Tactic.KEEP_DISTANCE
	elif choice == 7: _tactic = Tactic.RETREAT
	elif choice == 8: _tactic = Tactic.WAIT
	else: _tactic = Tactic.DEFEND
	if opponent.state == "ATTACK_RECOVERY": _tactic = Tactic.APPROACH
	elif opponent.state == "ATTACK_STARTUP" and float(actor.get("guard_durability", 100.0)) > 20.0:
		_tactic = Tactic.DEFEND


func _safe_retreat(position: Vector2, direction: CombatIntent.Direction) -> bool:
	var support := _support_surface(position)
	if support == null: support = stage_data.main_floor()
	# Keep a body and one reaction interval of movement inside this platform.
	var next_x := position.x + (-90.0 if direction == CombatIntent.Direction.LEFT else 90.0)
	return next_x >= support.rect.position.x + 40.0 and next_x <= support.rect.end.x - 40.0


func _set_direction(commands: Array[CombatIntent], tick: int, direction: CombatIntent.Direction, context: CombatIntent.Context) -> void:
	# One move edge per tick avoids ambiguous release/press sorting. Leaving
	# guard explicitly releases DOWN before starting a new horizontal hold.
	if direction != _direction and _direction == CombatIntent.Direction.DOWN:
		direction = CombatIntent.Direction.NEUTRAL
	if direction == CombatIntent.Direction.NEUTRAL and _direction != CombatIntent.Direction.NEUTRAL:
		commands.append(_intent(tick, &"move", _direction, context, CombatIntent.Edge.RELEASE))
	if direction != CombatIntent.Direction.NEUTRAL:
		commands.append(_intent(tick, &"move", direction, context, CombatIntent.Edge.HOLD if direction == _direction else CombatIntent.Edge.PRESS))
	_direction = direction


func _intent(tick: int, action: StringName, direction: CombatIntent.Direction, context: CombatIntent.Context, edge: CombatIntent.Edge = CombatIntent.Edge.PRESS) -> CombatIntent:
	return CombatIntent.new(tick, fighter_id, action, direction, edge, context)


func _next_climb_surface(position: Vector2, target: Vector2) -> StageSurfaceData:
	var result: StageSurfaceData
	var best_score := INF
	for surface: StageSurfaceData in stage_data.surfaces:
		if not surface.one_way or surface.rect.position.y >= position.y + 14.0:
			continue
		# Prefer reachable intermediate heights and surfaces that advance toward the target.
		var vertical := position.y + 14.0 - surface.rect.position.y
		var horizontal := absf(clampf(target.x, surface.rect.position.x, surface.rect.end.x) - position.x)
		var score := vertical + horizontal * 0.35
		if score < best_score:
			best_score = score
			result = surface
	return result


func _should_jump_toward_surface(position: Vector2, climb: StageSurfaceData) -> bool:
	# Jump below the destination when it overlaps the current floor. When two
	# upper platforms have a horizontal gap, jump at the edge of the platform
	# that currently supports the fighter instead of walking off it first.
	if position.x >= climb.rect.position.x + 30.0 and position.x <= climb.rect.end.x - 30.0:
		return true
	var support := _support_surface(position)
	if support == null or not support.one_way:
		return false
	if climb.rect.position.x >= support.rect.end.x:
		return position.x >= support.rect.end.x - 45.0
	if climb.rect.end.x <= support.rect.position.x:
		return position.x <= support.rect.position.x + 45.0
	return true


func _support_surface(position: Vector2) -> StageSurfaceData:
	var foot_y := position.y + 14.0
	for surface: StageSurfaceData in stage_data.surfaces:
		if position.x >= surface.rect.position.x - 2.0 and position.x <= surface.rect.end.x + 2.0 and absf(foot_y - surface.rect.position.y) <= 4.0:
			return surface
	return null
