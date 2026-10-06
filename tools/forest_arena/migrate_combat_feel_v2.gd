extends SceneTree

const MOVE_SET_PATHS := [
	"res://assets/combat/movesets/ja_hyun_moveset.tres",
	"res://assets/combat/movesets/myo_ryung_moveset.tres",
	"res://assets/combat/movesets/nabi_moveset.tres",
	"res://assets/combat/movesets/yu_ran_moveset.tres",
]


func _initialize() -> void:
	for path: String in MOVE_SET_PATHS:
		var move_set := load(path) as MoveSetData
		if move_set == null:
			push_error("Missing MoveSetData: %s" % path)
			quit(1)
			return
		for link: ComboLinkData in move_set.combo_links:
			link.schema_version = 2
			link.window_start_tick = -2
			link.window_end_tick = 10
		for attack: AttackData in move_set.attacks():
			_apply_timing(attack)
		if not move_set.is_valid_definition():
			push_error("Migrated MoveSetData is invalid: %s" % path)
			quit(1)
			return
		var error := ResourceSaver.save(move_set, path)
		if error != OK:
			push_error("Could not save %s: %s" % [path, error_string(error)])
			quit(1)
			return
	print("COMBAT_FEEL_V2_MIGRATION: PASS")
	quit(0)


func _apply_timing(attack: AttackData) -> void:
	match attack.action_id:
		&"attack_light":
			attack.active_ticks = 4
			if String(attack.visual_state_id).begins_with("attack_light_combo_"):
				if attack.is_finisher:
					attack.startup_ticks = 8
					attack.recovery_ticks = 16
					attack.fixed_hitstun_ticks = 18
				else:
					attack.startup_ticks = 6
					attack.recovery_ticks = 12
					attack.fixed_hitstun_ticks = 20
			else:
				attack.startup_ticks = 6
				attack.recovery_ticks = 12
				attack.fixed_hitstun_ticks = 16
		&"attack_heavy":
			attack.startup_ticks = 10 if attack.requires_dash or attack.activation_context == AttackData.ActivationContext.AIR else 12
			attack.active_ticks = 5
			attack.recovery_ticks = 16 if attack.requires_dash or attack.activation_context == AttackData.ActivationContext.AIR else 18
			attack.fixed_hitstun_ticks = 22
		&"attack_special":
			attack.startup_ticks = 10
			attack.active_ticks = maxi(attack.active_ticks, 6)
			attack.recovery_ticks = 18
			attack.fixed_hitstun_ticks = 18
		&"ultimate":
			attack.startup_ticks = 14
			attack.active_ticks = 6
			attack.recovery_ticks = 22
			attack.fixed_hitstun_ticks = 30
