class_name LocalAICommandSource
extends RefCounted

const DEFAULT_STAGE: StageData = preload("res://assets/combat/stages/forest_ledge_stage.tres")

## Snapshot-only normal opponent. No direct fighter access, resource mutation,
## movement teleport, or bypass of action/cooldown checks is available here.
var fighter_id: StringName
var team_id: StringName
var match_seed: int
var reaction_interval_ticks := 12
var preferred_distance := 62.0
var stage_data: StageData
var _direction := CombatIntent.Direction.NEUTRAL
var _heavy_release_tick := -1
var _next_reaction_tick := 1
var _rng := RandomNumberGenerator.new()


func _init(id: StringName = &"", seed_value: int = 1, settings: Dictionary = {}) -> void:
	fighter_id = id
	match_seed = seed_value
	team_id = StringName(settings.get("team_id", &""))
	reaction_interval_ticks = maxi(1, int(settings.get("reaction_interval_ticks", 12)))
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


func commands_for_tick(tick: int, match_snapshot: Dictionary) -> Array[CombatIntent]:
	var commands: Array[CombatIntent] = []
	var actor: Dictionary = {}
	var opponent: Dictionary = {}
	for fighter: Dictionary in match_snapshot.get("fighters", []):
		if StringName(fighter.id) == fighter_id: actor = fighter
	if actor.is_empty(): return commands
	var nearest_distance := INF
	for fighter: Dictionary in match_snapshot.get("fighters", []):
		if StringName(fighter.id) == fighter_id or (not team_id.is_empty() and StringName(fighter.get("team_id", &"")) == team_id): continue
		if String(fighter.get("state", "")) in ["DEAD", "MATCH_ENDED"]: continue
		var candidate_position: Vector2 = fighter.get("position", Vector2.ZERO)
		var actor_position: Vector2 = actor.get("position", Vector2.ZERO)
		var distance := candidate_position.distance_squared_to(actor_position)
		if distance < nearest_distance or (is_equal_approx(distance, nearest_distance) and (opponent.is_empty() or StringName(fighter.id) < StringName(opponent.id))):
			opponent = fighter
			nearest_distance = distance
	if actor.is_empty() or opponent.is_empty(): return commands
	var context := CombatIntent.Context.GROUND if actor.get("on_floor", false) else CombatIntent.Context.AIR
	if _heavy_release_tick >= 0 and tick >= _heavy_release_tick:
		commands.append(_intent(tick, &"attack_heavy", _direction, context, CombatIntent.Edge.RELEASE))
		_heavy_release_tick = -1
		_next_reaction_tick = tick + reaction_interval_ticks
		return commands
	if tick < _next_reaction_tick: return commands
	_next_reaction_tick = tick + reaction_interval_ticks
	if actor.state in ["DEAD", "MATCH_ENDED", "RING_OUT", "SPAWNING"]:
		_set_direction(commands, tick, CombatIntent.Direction.NEUTRAL, context)
		return commands
	var position: Vector2 = actor.position
	var target: Vector2 = opponent.position
	var velocity: Vector2 = actor.velocity
	var delta := target - position
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
			elif actor.get("up_special", false) and int(actor.get("special_cooldown_ticks", 0)) == 0:
				action = &"attack_special"
				action_direction = CombatIntent.Direction.UP
	elif delta.y < -85.0 and context == CombatIntent.Context.GROUND:
		# Pick the lowest useful platform above the actor, then approach its nearest edge.
		var climb := _next_climb_surface(position, target)
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
	elif absf(delta.x) < 105.0 and absf(delta.y) < 80.0:
		# Face the target before attacking; no instantaneous aim correction.
		direction = toward
		var choice := _rng.randi_range(0, 9)
		if opponent.state in ["ATTACK_STARTUP", "ATTACK_ACTIVE"] and context == CombatIntent.Context.GROUND and choice < 4:
			if choice == 0:
				direction = CombatIntent.Direction.LEFT if toward == CombatIntent.Direction.RIGHT else CombatIntent.Direction.RIGHT
				action = &"evade"
				action_direction = direction
			else:
				direction = CombatIntent.Direction.DOWN
		elif float(actor.get("ultimate_gauge", 0.0)) >= float(match_snapshot.get("ultimate_gauge_max", 100.0)) and not actor.get("ultimate_used_this_stock", false):
			action = &"ultimate"
			action_direction = CombatIntent.Direction.NEUTRAL
		elif choice == 8 and int(actor.get("special_cooldown_ticks", 0)) == 0:
			action = &"attack_special"
		elif choice == 9 and _heavy_release_tick < 0:
			action = &"attack_heavy"
			_heavy_release_tick = tick + reaction_interval_ticks
		else:
			action = &"attack_light"
	_set_direction(commands, tick, direction, context)
	if not action.is_empty(): commands.append(_intent(tick, action, action_direction, context))
	return commands


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
