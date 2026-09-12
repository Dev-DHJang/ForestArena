class_name DeterministicBotCommandSource
extends RefCounted

## Produces semantic CombatIntents solely from seed + authoritative snapshot +
## tick. It owns no evolving RNG state, so rollback/replay callers can query any
## tick independently and receive the same result.

const _AIR_STATES: Array[String] = ["JUMP", "FALL", "EVADE_AIR"]
const _LOCKED_STATES: Array[String] = ["SPAWNING", "RING_OUT", "MATCH_ENDED", "HITSTUN", "KNOCKBACK", "GUARD_BREAK"]
const _ATTACK_STATES: Array[String] = ["ATTACK_STARTUP", "ATTACK_ACTIVE"]
const _HASH_MODULUS := 2147483647
const _ULTIMATE_READY := 100.0

var profile: BotCommandProfile
var seed: int
var fighter_id: StringName
var opponent_id: StringName


func _init(
	p_profile: BotCommandProfile = null,
	p_seed: int = 0,
	p_fighter_id: StringName = &"",
	p_opponent_id: StringName = &"",
) -> void:
	profile = p_profile
	seed = p_seed
	fighter_id = p_fighter_id
	opponent_id = p_opponent_id


func is_valid_configuration() -> bool:
	return profile != null \
		and profile.is_valid_definition() \
		and not fighter_id.is_empty() \
		and not opponent_id.is_empty() \
		and fighter_id != opponent_id


func commands_for_tick(tick: int, match_snapshot: Dictionary) -> Array[CombatIntent]:
	var commands: Array[CombatIntent] = []
	if not is_valid_configuration() or tick < 0:
		return commands
	var self_snapshot := _fighter_snapshot(match_snapshot, fighter_id)
	var opponent_snapshot := _fighter_snapshot(match_snapshot, opponent_id)
	if self_snapshot.is_empty() or opponent_snapshot.is_empty():
		return commands
	var state := String(self_snapshot.get("state", ""))
	if state in _LOCKED_STATES:
		return commands
	var context := CombatIntent.Context.AIR if state in _AIR_STATES else CombatIntent.Context.GROUND
	var direction := _horizontal_direction(self_snapshot, opponent_snapshot)
	var distance := _horizontal_distance(self_snapshot, opponent_snapshot)
	var opponent_state := String(opponent_snapshot.get("state", ""))
	var threatened := opponent_state in _ATTACK_STATES and distance <= profile.preferred_distance_min * 1.25
	if state == "CHARGE":
		if int(self_snapshot.get("charge_ticks", 0)) >= 30:
			commands.append(CombatIntent.new(tick, fighter_id, &"attack_heavy", direction, CombatIntent.Edge.RELEASE, CombatIntent.Context.GROUND))
		return commands

	if state == "GUARD":
		var edge := CombatIntent.Edge.HOLD if threatened else CombatIntent.Edge.RELEASE
		commands.append(CombatIntent.new(tick, fighter_id, &"dash", CombatIntent.Direction.NEUTRAL, edge, context))
		return commands

	commands.append(CombatIntent.new(tick, fighter_id, &"move", _movement_direction(direction, distance), CombatIntent.Edge.HOLD, context))
	if tick % profile.decision_interval_ticks != 0:
		return commands

	if threatened:
		var defense_roll := _roll(tick, match_snapshot, &"defense")
		if defense_roll < profile.evade_percent:
			commands.append(CombatIntent.new(tick, fighter_id, &"dash", _away_from(direction), CombatIntent.Edge.PRESS, context))
			return commands
		if defense_roll < profile.evade_percent + profile.guard_percent and context == CombatIntent.Context.GROUND:
			commands.append(CombatIntent.new(tick, fighter_id, &"dash", CombatIntent.Direction.NEUTRAL, CombatIntent.Edge.PRESS, context))
			return commands

	if _ultimate_is_ready(self_snapshot) and _roll(tick, match_snapshot, &"ultimate") < profile.ultimate_percent:
		commands.append(CombatIntent.new(tick, fighter_id, &"ultimate", direction, CombatIntent.Edge.PRESS, context))
		return commands

	if context == CombatIntent.Context.GROUND and _roll(tick, match_snapshot, &"jump") < profile.aerial_percent:
		commands.append(CombatIntent.new(tick, fighter_id, &"jump", CombatIntent.Direction.UP, CombatIntent.Edge.PRESS, context))
		return commands

	if distance > profile.preferred_distance_max or _roll(tick, match_snapshot, &"engage") >= profile.aggression_percent:
		return commands
	var action_roll := _roll(tick, match_snapshot, &"action")
	if action_roll < profile.special_percent:
		commands.append(CombatIntent.new(tick, fighter_id, &"attack_special", _attack_direction(tick, match_snapshot, context), CombatIntent.Edge.PRESS, context))
	elif action_roll < profile.special_percent + profile.heavy_percent:
		commands.append(CombatIntent.new(tick, fighter_id, &"attack_heavy", direction, CombatIntent.Edge.PRESS, context))
	else:
		commands.append(CombatIntent.new(tick, fighter_id, &"attack_light", direction, CombatIntent.Edge.PRESS, context))
	return commands


func _fighter_snapshot(match_snapshot: Dictionary, id: StringName) -> Dictionary:
	var fighters: Variant = match_snapshot.get("fighters", [])
	if fighters is not Array:
		return {}
	for candidate: Variant in fighters:
		if candidate is Dictionary and StringName(candidate.get("id", "")) == id:
			return candidate
	return {}


func _horizontal_distance(left: Dictionary, right: Dictionary) -> float:
	return absf(_position(left).x - _position(right).x)


func _horizontal_direction(left: Dictionary, right: Dictionary) -> CombatIntent.Direction:
	return CombatIntent.Direction.LEFT if _position(right).x < _position(left).x else CombatIntent.Direction.RIGHT


func _movement_direction(toward: CombatIntent.Direction, distance: float) -> CombatIntent.Direction:
	if distance < profile.preferred_distance_min:
		return _away_from(toward)
	if distance > profile.preferred_distance_max:
		return toward
	return CombatIntent.Direction.NEUTRAL


func _away_from(direction: CombatIntent.Direction) -> CombatIntent.Direction:
	return CombatIntent.Direction.RIGHT if direction == CombatIntent.Direction.LEFT else CombatIntent.Direction.LEFT


func _attack_direction(tick: int, snapshot: Dictionary, context: CombatIntent.Context) -> CombatIntent.Direction:
	var choice := _roll(tick, snapshot, &"special_direction") % 4
	if context == CombatIntent.Context.AIR and choice == 0:
		return CombatIntent.Direction.DOWN
	match choice:
		0: return CombatIntent.Direction.UP
		1: return CombatIntent.Direction.DOWN
		2: return CombatIntent.Direction.LEFT
		_: return CombatIntent.Direction.RIGHT


func _ultimate_is_ready(fighter_snapshot: Dictionary) -> bool:
	return float(fighter_snapshot.get("ultimate_gauge", 0.0)) >= _ULTIMATE_READY \
		and not bool(fighter_snapshot.get("ultimate_used_this_stock", fighter_snapshot.get("ultimate_used", false)))


func _position(fighter_snapshot: Dictionary) -> Vector2:
	var value: Variant = fighter_snapshot.get("position", Vector2.ZERO)
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO


func _roll(tick: int, snapshot: Dictionary, salt: StringName) -> int:
	var canonical := "%d|%d|%s|%s|%s" % [seed, tick, fighter_id, salt, JSON.stringify(snapshot, "", true)]
	var value := 1
	for byte: int in canonical.to_utf8_buffer():
		value = (value * 48271 + byte + 1) % _HASH_MODULUS
	return value % 100
