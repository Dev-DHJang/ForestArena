class_name CommandResolver
extends RefCounted

## Groups same-tick input before a fighter sees it. This prevents platform drop,
## directional attacks and guard from depending on event arrival order.
static func resolve(intents: Array[CombatIntent]) -> Array[CombatIntent]:
	var by_fighter: Dictionary = {}
	for intent: CombatIntent in intents:
		if not by_fighter.has(intent.fighter_id): by_fighter[intent.fighter_id] = []
		by_fighter[intent.fighter_id].append(intent)
	var result: Array[CombatIntent] = []
	var fighter_ids: Array[StringName] = []
	for fighter_id: StringName in by_fighter: fighter_ids.append(fighter_id)
	fighter_ids.sort()
	for fighter_id: StringName in fighter_ids:
		var group: Array = by_fighter[fighter_id]
		group.sort_custom(func(a: CombatIntent, b: CombatIntent) -> bool: return String(a.action_id) < String(b.action_id))
		var down := group.any(func(intent: CombatIntent) -> bool: return intent.action_id == &"move" and intent.direction == CombatIntent.Direction.DOWN and intent.edge != CombatIntent.Edge.RELEASE)
		var jump: CombatIntent = _first_press(group, &"jump")
		var attack: CombatIntent = _first_attack(group)
		for intent: CombatIntent in group:
			if intent.action_id == &"move": result.append(intent)
		# Priority is platform drop, then down directional attack, then bare-down guard.
		if down and jump != null:
			result.append(CombatIntent.new(jump.tick, fighter_id, &"drop_platform", CombatIntent.Direction.DOWN, CombatIntent.Edge.PRESS, jump.context))
		elif attack != null:
			result.append(attack)
		elif down:
			var move: CombatIntent = group.filter(func(intent: CombatIntent) -> bool: return intent.action_id == &"move")[0]
			result.append(CombatIntent.new(move.tick, fighter_id, &"guard", CombatIntent.Direction.DOWN, CombatIntent.Edge.HOLD, move.context))
		elif jump != null:
			result.append(jump)
		else:
			for intent: CombatIntent in group:
				if intent.action_id != &"move": result.append(intent)
	return result


static func _first_press(intents: Array, action_id: StringName) -> CombatIntent:
	for intent: CombatIntent in intents:
		if intent.action_id == action_id and intent.edge == CombatIntent.Edge.PRESS: return intent
	return null


static func _first_attack(intents: Array) -> CombatIntent:
	for action_id: StringName in [&"attack_light", &"attack_heavy", &"attack_special", &"ultimate"]:
		var found := _first_press(intents, action_id)
		if found != null: return found
	return null
