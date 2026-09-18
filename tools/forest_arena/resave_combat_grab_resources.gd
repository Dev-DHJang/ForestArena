extends SceneTree

const PATHS := [
	"res://assets/combat/movesets/ja_hyun_moveset.tres",
	"res://assets/combat/movesets/myo_ryung_moveset.tres",
	"res://assets/combat/movesets/nabi_moveset.tres",
	"res://assets/combat/movesets/yu_ran_moveset.tres",
]


func _init() -> void:
	for path: String in PATHS:
		var move_set := load(path) as MoveSetData
		if move_set == null or not _add_grab(move_set) or not move_set.is_valid_definition() or ResourceSaver.save(move_set, path) != OK:
			push_error("Grab migration failed: %s" % path)
			quit(1)
			return
	print("COMBAT_GRAB_RESAVE: PASS")
	quit(0)


func _add_grab(move_set: MoveSetData) -> bool:
	var prefix := String(move_set.move_set_id).trim_suffix("-moveset")
	var id := StringName("%s-grab" % prefix)
	for slot: MoveSlotData in move_set.slots:
		if slot.slot_id == id:
			return true
	var source: AttackData
	for attack: AttackData in move_set.attacks():
		if attack.action_id == &"attack_light":
			source = attack
			break
	if source == null:
		return false
	var grab := source.duplicate(true) as AttackData
	grab.attack_id = id
	grab.action_id = &"grab"
	grab.input_direction = AttackData.InputDirection.OMNI
	grab.activation_context = AttackData.ActivationContext.GROUND
	grab.requires_dash = false
	grab.startup_ticks = 5
	grab.active_ticks = 2
	grab.recovery_ticks = 25
	grab.damage = 4.0
	grab.knockback = 250.0
	grab.fixed_hitstun_ticks = 12
	grab.guard_damage = 0.0
	grab.guard_hitstun_ticks = 0
	grab.guard_knockback = 0.0
	grab.hit_reaction = AttackData.HitReaction.KNOCKBACK
	grab.tags = [&"GRAB"]
	grab.hitbox_size = Vector2(42.0, 50.0)
	grab.hitbox_offset = Vector2(34.0, -30.0)
	grab.max_hits_per_target = 1
	grab.rehit_interval_ticks = 0
	grab.is_finisher = false
	grab.is_launcher = false
	grab.visual_state_id = &"grab_throw"
	var slot := MoveSlotData.new()
	slot.slot_id = id
	slot.attack = grab
	move_set.slots.append(slot)
	return true
