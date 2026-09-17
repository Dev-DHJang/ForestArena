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
			push_error("MoveSet load failed: %s" % path)
			quit(1)
			return
		_add_data_links(move_set)
		if not move_set.is_valid_definition() or ResourceSaver.save(move_set, path) != OK:
			push_error("MoveSet D save failed: %s" % path)
			quit(1)
			return
	print("COMBAT_D_RESAVE: PASS")
	quit(0)


func _add_data_links(move_set: MoveSetData) -> void:
	var attacks := move_set.attacks()
	var special := _first_attack(attacks, &"attack_special")
	var heavy := _first_attack(attacks, &"attack_heavy")
	for attack: AttackData in attacks:
		if attack.action_id != &"attack_light" or attack.is_finisher or attack.activation_context != AttackData.ActivationContext.GROUND:
			continue
		_add_link(move_set, attack.attack_id, &"attack_heavy", heavy.attack_id)
		_add_link(move_set, attack.attack_id, &"attack_special", special.attack_id)
		_add_cancel(move_set, attack.attack_id, CancelRuleData.Kind.JUMP, false)
		_add_cancel(move_set, attack.attack_id, CancelRuleData.Kind.GUARD, false)
		_add_cancel(move_set, attack.attack_id, CancelRuleData.Kind.EVADE, false)
		_add_cancel(move_set, attack.attack_id, CancelRuleData.Kind.SPECIAL, true)
		_add_cancel(move_set, attack.attack_id, CancelRuleData.Kind.ULTIMATE, true)


func _first_attack(attacks: Array[AttackData], action: StringName) -> AttackData:
	for attack: AttackData in attacks:
		if attack.action_id == action and not attack.requires_dash:
			return attack
	return null


func _add_link(move_set: MoveSetData, from: StringName, action: StringName, next: StringName) -> void:
	if next.is_empty(): return
	for link: ComboLinkData in move_set.combo_links:
		if link.from_attack_id == from and link.input_action_id == action: return
	var link := ComboLinkData.new()
	link.from_attack_id = from
	link.input_action_id = action
	link.next_attack_id = next
	link.window_end_tick = 7
	link.requires_hit = true
	move_set.combo_links.append(link)


func _add_cancel(move_set: MoveSetData, from: StringName, kind: CancelRuleData.Kind, requires_hit: bool) -> void:
	for rule: CancelRuleData in move_set.cancel_rules:
		if rule.from_attack_id == from and rule.kind == kind: return
	var rule := CancelRuleData.new()
	rule.from_attack_id = from
	rule.kind = kind
	rule.window_end_tick = 7
	rule.requires_hit = requires_hit
	move_set.cancel_rules.append(rule)
