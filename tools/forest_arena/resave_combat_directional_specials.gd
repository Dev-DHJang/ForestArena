extends SceneTree

const MoveSet = preload("res://scripts/data/move_set_data.gd")
const Attack = preload("res://scripts/data/attack_data.gd")
const MoveSlot = preload("res://scripts/data/move_slot_data.gd")

const PATHS := [
	"res://assets/combat/movesets/ja_hyun_moveset.tres",
	"res://assets/combat/movesets/myo_ryung_moveset.tres",
	"res://assets/combat/movesets/nabi_moveset.tres",
	"res://assets/combat/movesets/yu_ran_moveset.tres",
]


func _init() -> void:
	for path: String in PATHS:
		var move_set := load(path) as MoveSet
		if move_set == null or not _add_missing_moves(move_set):
			push_error("Directional combat move migration failed: %s" % path)
			quit(1)
			return
		if not move_set.is_valid_definition() or ResourceSaver.save(move_set, path) != OK:
			push_error("Directional combat move save failed: %s" % path)
			quit(1)
			return
	print("COMBAT_DIRECTIONAL_SPECIALS_RESAVE: PASS")
	quit(0)


func _add_missing_moves(move_set: Resource) -> bool:
	var neutral := _find(move_set, &"attack_special", Attack.InputDirection.NEUTRAL)
	var heavy := _find(move_set, &"attack_heavy", Attack.InputDirection.ANY_HORIZONTAL)
	if neutral == null or heavy == null:
		return false
	var prefix := String(move_set.move_set_id).trim_suffix("-moveset")
	_add(move_set, _copy_attack(neutral, &"%s-special-side" % prefix, &"attack_special", Attack.InputDirection.ANY_HORIZONTAL, &"special_side", [&"SPECIAL", &"MELEE"]))
	_add(move_set, _copy_attack(neutral, &"%s-special-down" % prefix, &"attack_special", Attack.InputDirection.DOWN, &"special_down", [&"SPECIAL", &"MELEE"]))
	var ultimate := _copy_attack(heavy, &"%s-ultimate" % prefix, &"ultimate", Attack.InputDirection.NEUTRAL, &"ultimate", [&"ULTIMATE", &"UNBLOCKABLE"])
	ultimate.damage = maxf(ultimate.damage, 16.0)
	ultimate.knockback = maxf(ultimate.knockback, 340.0)
	ultimate.fixed_hitstun_ticks = max(ultimate.fixed_hitstun_ticks, 18)
	ultimate.is_finisher = true
	ultimate.activation_context = Attack.ActivationContext.BOTH
	_add(move_set, ultimate)
	return true


func _add(move_set: Resource, attack: Resource) -> void:
	for existing: Resource in move_set.attacks():
		if existing.attack_id == attack.attack_id:
			for slot: Resource in move_set.slots:
				if slot.slot_id == attack.attack_id:
					slot.attack = attack as Attack
			return
	var slot := MoveSlot.new()
	slot.slot_id = attack.attack_id
	slot.attack = attack as Attack
	move_set.slots.append(slot)


func _copy_attack(source: Resource, id: StringName, action: StringName, direction: int, visual: StringName, tags: Array[StringName]) -> Resource:
	var attack := source.duplicate() as Attack
	attack.attack_id = id
	attack.action_id = action
	attack.input_direction = direction
	attack.visual_state_id = visual
	attack.tags = tags
	attack.requires_dash = false
	return attack


func _find(move_set: Resource, action: StringName, direction: int) -> Resource:
	for attack: Resource in move_set.attacks():
		if attack.action_id == action and attack.input_direction == direction and not attack.requires_dash:
			return attack
	return null
