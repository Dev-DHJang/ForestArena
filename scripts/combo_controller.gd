class_name ComboController
extends RefCounted

static func linked_attack(move_set: MoveSetData, active_attack: AttackData, intent: CombatIntent, recovery_tick: int, landed: bool) -> AttackData:
	if move_set == null or active_attack == null: return null
	for link: ComboLinkData in move_set.combo_links:
		if link.from_attack_id != active_attack.attack_id or link.input_action_id != intent.action_id:
			continue
		if recovery_tick < link.window_start_tick or recovery_tick > link.window_end_tick:
			continue
		if link.requires_hit and not landed: continue
		return _attack_by_id(move_set, link.next_attack_id)
	return null


static func opening_attack(move_set: MoveSetData, intent: CombatIntent, context: AttackData.ActivationContext, facing: int, dashing: bool) -> AttackData:
	if move_set == null: return null
	for attack: AttackData in move_set.attacks():
		if attack.action_id != intent.action_id or (attack.activation_context != context and attack.activation_context != AttackData.ActivationContext.BOTH): continue
		if attack.requires_dash != dashing: continue
		if intent.action_id == &"attack_light" and context == AttackData.ActivationContext.GROUND and not dashing and not move_set.opening_attack_ids.has(attack.attack_id): continue
		if _direction_matches(attack.input_direction, _relative_direction(intent.direction, facing)): return attack
	return null


static func _attack_by_id(move_set: MoveSetData, attack_id: StringName) -> AttackData:
	for attack: AttackData in move_set.attacks():
		if attack.attack_id == attack_id: return attack
	return null


static func _relative_direction(direction: CombatIntent.Direction, facing: int) -> AttackData.InputDirection:
	match direction:
		CombatIntent.Direction.UP: return AttackData.InputDirection.UP
		CombatIntent.Direction.DOWN: return AttackData.InputDirection.DOWN
		CombatIntent.Direction.LEFT: return AttackData.InputDirection.FORWARD if facing < 0 else AttackData.InputDirection.BACK
		CombatIntent.Direction.RIGHT: return AttackData.InputDirection.FORWARD if facing > 0 else AttackData.InputDirection.BACK
		_: return AttackData.InputDirection.NEUTRAL


static func _direction_matches(required: AttackData.InputDirection, actual: AttackData.InputDirection) -> bool:
	if required == AttackData.InputDirection.ANY_HORIZONTAL:
		return actual in [AttackData.InputDirection.NEUTRAL, AttackData.InputDirection.FORWARD, AttackData.InputDirection.BACK]
	return required == AttackData.InputDirection.OMNI or required == actual
