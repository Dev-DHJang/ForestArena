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
		if move_set == null:
			push_error("AttackData v3 migration load failed: %s" % path)
			quit(1)
			return
		for attack: AttackData in move_set.attacks():
			attack.schema_version = 3
			if attack.action_id == &"attack_heavy" and attack.activation_context == AttackData.ActivationContext.GROUND and not attack.requires_dash:
				attack.charge_min_ticks = 12
				attack.charge_max_ticks = 90
				attack.charge_damage_multiplier = 1.5
				attack.charge_knockback_multiplier = 1.4
				attack.charge_recovery_ticks_per_step = 3
		if not move_set.is_valid_definition() or ResourceSaver.save(move_set, path) != OK:
			push_error("AttackData v3 migration save failed: %s" % path)
			quit(1)
			return
	print("COMBAT_V3_RESAVE: PASS")
	quit(0)
