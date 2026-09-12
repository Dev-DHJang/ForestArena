extends SceneTree

const FIGHTERS := ["res://scenes/fighters/ja_hyun_fighter.tscn", "res://scenes/fighters/myo_ryung_fighter.tscn", "res://scenes/fighters/nabi_fighter.tscn"]
const EXPECTED_COMBOS := {"ja-hyun": 3, "myo-ryung": 4, "nabi": 2}
const TIMINGS := {
	"light": [4, 3, 7, 4.0, 120.0, 1.6], "finisher": [6, 3, 12, 7.0, 210.0, 2.4],
	"directional_light": [5, 3, 9, 5.0, 150.0, 1.8], "heavy": [10, 4, 16, 10.0, 260.0, 3.0],
	"dash_light": [5, 3, 9, 6.0, 170.0, 2.0], "dash_heavy": [8, 4, 14, 10.0, 240.0, 2.8],
	"air_light": [5, 3, 9, 5.0, 150.0, 1.8], "air_heavy": [8, 4, 14, 9.0, 230.0, 2.7],
	"special": [8, 4, 16, 8.0, 220.0, 2.6], "up_special": [6, 5, 18, 7.0, 190.0, 2.3],
}


func _initialize() -> void:
	var failures: PackedStringArray = []
	var global_ids: Dictionary = {}
	for path: String in FIGHTERS:
		var fighter := (load(path) as PackedScene).instantiate() as FighterController
		root.add_child(fighter)
		await process_frame
		var id := String(fighter.fighter_id)
		if fighter.character_data.character_id != fighter.fighter_id: failures.append("CharacterData mismatch: %s" % id)
		if fighter.combo_count != EXPECTED_COMBOS[id]: failures.append("incorrect combo count: %s" % id)
		if fighter.attacks.size() < EXPECTED_COMBOS[id] + 11: failures.append("incomplete move family: %s" % id)
		if fighter.get_node_or_null("Hurtbox/CollisionShape2D") == null or fighter.get_node_or_null("Hitbox/CollisionShape2D") == null: failures.append("missing authority debug geometry: %s" % id)
		for attack: AttackData in fighter.attacks:
			if not attack.is_valid_definition(): failures.append("invalid attack: %s" % attack.attack_id)
			if global_ids.has(attack.attack_id): failures.append("duplicate global attack ID: %s" % attack.attack_id)
			global_ids[attack.attack_id] = true
		_validate_family(fighter, failures)
		fighter.queue_free()
	if failures.is_empty():
		print("PHASE1_COMBAT_CONTRACT: PASS")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("PHASE1_COMBAT_CONTRACT: FAIL (%d)" % failures.size())
		quit(1)


func _validate_family(fighter: FighterController, failures: PackedStringArray) -> void:
	var combo: Array[AttackData] = fighter.attacks.filter(func(a: AttackData) -> bool: return a.combo_step > 0)
	combo.sort_custom(func(a: AttackData, b: AttackData) -> bool: return a.combo_step < b.combo_step)
	for index: int in combo.size():
		_expect(combo[index], "finisher" if index == combo.size() - 1 else "light", failures)
	for direction: AttackData.InputDirection in [AttackData.InputDirection.UP, AttackData.InputDirection.DOWN]:
		_expect(_find(fighter, &"attack_light", direction, false, AttackData.ActivationContext.GROUND), "directional_light", failures)
	for direction: AttackData.InputDirection in [AttackData.InputDirection.ANY_HORIZONTAL, AttackData.InputDirection.UP, AttackData.InputDirection.DOWN]:
		_expect(_find(fighter, &"attack_heavy", direction, false, AttackData.ActivationContext.GROUND), "heavy", failures)
	_expect(_find(fighter, &"attack_light", AttackData.InputDirection.ANY_HORIZONTAL, true, AttackData.ActivationContext.GROUND), "dash_light", failures)
	_expect(_find(fighter, &"attack_heavy", AttackData.InputDirection.ANY_HORIZONTAL, true, AttackData.ActivationContext.GROUND), "dash_heavy", failures)
	_expect(_find(fighter, &"attack_light", AttackData.InputDirection.OMNI, false, AttackData.ActivationContext.AIR), "air_light", failures)
	_expect(_find(fighter, &"attack_heavy", AttackData.InputDirection.OMNI, false, AttackData.ActivationContext.AIR), "air_heavy", failures)
	var neutral := _find(fighter, &"attack_special", AttackData.InputDirection.NEUTRAL, false, AttackData.ActivationContext.BOTH)
	if fighter.fighter_id == &"myo-ryung":
		if neutral == null or neutral.max_hits_per_target != 3 or neutral.rehit_interval_ticks != 3 or neutral.damage != 3.0: failures.append("Myo-Ryung multi-hit contract mismatch")
	elif neutral == null:
		failures.append("missing neutral special: %s" % fighter.fighter_id)
	else:
		_expect(neutral, "special", failures)
	if fighter.fighter_id == &"ja-hyun" and neutral.launch_mode != AttackData.LaunchMode.TOWARD_SOURCE: failures.append("Ja-Hyun neutral special must pull")
	if fighter.fighter_id == &"nabi" and neutral.launch_mode != AttackData.LaunchMode.VECTOR: failures.append("Nabi neutral special must launch forward")
	var up_special := _find(fighter, &"attack_special", AttackData.InputDirection.UP, false, AttackData.ActivationContext.BOTH)
	_expect(up_special, "up_special", failures)
	if up_special == null or up_special.self_impulse != Vector2(0, -440): failures.append("up special self impulse mismatch: %s" % fighter.fighter_id)


func _find(fighter: FighterController, action: StringName, direction: AttackData.InputDirection, dash: bool, context: AttackData.ActivationContext) -> AttackData:
	for attack: AttackData in fighter.attacks:
		if attack.action_id == action and attack.input_direction == direction and attack.requires_dash == dash and attack.activation_context == context and attack.combo_step == 0:
			return attack
	return null


func _expect(attack: AttackData, family: String, failures: PackedStringArray) -> void:
	if attack == null:
		failures.append("missing attack family: %s" % family)
		return
	var expected: Array = TIMINGS[family]
	var actual := [attack.startup_ticks, attack.active_ticks, attack.recovery_ticks, attack.damage, attack.base_knockback, attack.knockback_growth]
	if actual != expected: failures.append("%s values mismatch: %s" % [attack.attack_id, actual])
