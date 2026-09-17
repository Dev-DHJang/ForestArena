class_name MoveSetData
extends Resource

@export var schema_version: int = 2
@export var move_set_id: StringName
@export var slots: Array[MoveSlotData] = []
@export_range(1, 4, 1) var combo_count: int = 2
@export var opening_attack_ids: Array[StringName] = []
@export var combo_links: Array[ComboLinkData] = []
@export var cancel_rules: Array[CancelRuleData] = []


func is_valid_definition() -> bool:
	if schema_version != 2 or move_set_id.is_empty() or slots.is_empty() or combo_count < 1:
		return false
	var seen: Dictionary = {}
	for slot: MoveSlotData in slots:
		if slot == null or not slot.is_valid_definition() or seen.has(slot.slot_id):
			return false
		seen[slot.slot_id] = true
	var attack_ids: Dictionary = {}
	for slot: MoveSlotData in slots: attack_ids[slot.attack.attack_id] = true
	for attack_id: StringName in opening_attack_ids:
		if not attack_ids.has(attack_id): return false
	for link: ComboLinkData in combo_links:
		if link == null or not link.is_valid_definition(attack_ids): return false
	for rule: CancelRuleData in cancel_rules:
		if rule == null or not rule.is_valid_definition() or not attack_ids.has(rule.from_attack_id): return false
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
