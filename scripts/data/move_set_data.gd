class_name MoveSetData
extends Resource

@export var schema_version: int = 2
@export var move_set_id: StringName
@export var slots: Array[MoveSlotData] = []
@export_range(1, 4, 1) var combo_count: int = 2


func is_valid_definition() -> bool:
	if schema_version != 2 or move_set_id.is_empty() or slots.is_empty() or combo_count < 1:
		return false
	var seen: Dictionary = {}
	for slot: MoveSlotData in slots:
		if slot == null or not slot.is_valid_definition() or seen.has(slot.slot_id):
			return false
		seen[slot.slot_id] = true
		if slot.attack.action_id == &"attack_special" and slot.attack.input_direction not in [AttackData.InputDirection.NEUTRAL, AttackData.InputDirection.FORWARD, AttackData.InputDirection.UP, AttackData.InputDirection.DOWN]:
			return false
	for direction: AttackData.InputDirection in [AttackData.InputDirection.NEUTRAL, AttackData.InputDirection.FORWARD, AttackData.InputDirection.UP, AttackData.InputDirection.DOWN]:
		var count := attacks().filter(func(attack: AttackData) -> bool: return attack.action_id == &"attack_special" and attack.input_direction == direction).size()
		if count != 1:
			return false
	return true


func attacks() -> Array[AttackData]:
	var result: Array[AttackData] = []
	for slot: MoveSlotData in slots:
		result.append(slot.attack)
	return result


func replace_slot(slot_id: StringName, replacement: AttackData) -> bool:
	for slot: MoveSlotData in slots:
		if slot.slot_id == slot_id:
			slot.attack = replacement
			return true
	return false


func attack_for_slot(slot_id: StringName) -> AttackData:
	for slot: MoveSlotData in slots:
		if slot.slot_id == slot_id:
			return slot.attack
	return null
