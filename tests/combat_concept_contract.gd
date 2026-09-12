extends SceneTree

const CONCEPT_PATH := "res://docs/attack-system-v01.json"
const EXPECTED_COMBO_COUNTS := {"ja-hyun": 3, "myo-ryung": 4, "nabi": 2}
const REQUIRED_ACTIONS := ["attack_light", "attack_heavy", "attack_special"]
const REQUIRED_EDGES := ["press", "hold", "release"]
const REQUIRED_COMMON_MOVE_IDS := [
	"base_light_combo", "light_up", "light_down", "strong_side", "strong_up", "strong_down",
	"strong_charge", "dash_light", "dash_heavy", "air_light", "air_heavy", "grab_throw",
]
const REQUIRED_CHARACTER_MOVE_IDS := [
	"ja-hyun-special-neutral", "ja-hyun-special-side", "ja-hyun-special-up", "ja-hyun-special-down", "ja-hyun-ultimate",
	"myo-ryung-special-neutral", "myo-ryung-special-side", "myo-ryung-special-up", "myo-ryung-special-down", "myo-ryung-ultimate",
	"nabi-special-neutral", "nabi-special-side", "nabi-special-up", "nabi-special-down", "nabi-ultimate",
]
const REQUIRED_MOVE_FIELDS := ["id", "input", "state", "role", "link_condition", "resource", "launch_direction", "finisher", "visual_state_id"]


func _initialize() -> void:
	var failures: PackedStringArray = []
	var concept := _load_concept(failures)
	_validate_input_contract(concept, failures)
	_validate_system_rules(concept, failures)
	_validate_common_families(concept, failures)
	_validate_future_defense_action(concept, failures)
	_validate_visual_production_policy(concept, failures)
	_validate_characters(concept, failures)
	_finish(failures)


func _load_concept(failures: PackedStringArray) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONCEPT_PATH))
	if not (parsed is Dictionary):
		failures.append("combat concept is not a JSON object")
		return {}
	var concept: Dictionary = parsed
	if concept.get("schema_version") != 1 or concept.get("status") != "concept" or concept.get("phase") != "pre-phase-1":
		failures.append("combat concept schema or phase is invalid")
	return concept


func _validate_input_contract(concept: Dictionary, failures: PackedStringArray) -> void:
	var contract: Dictionary = concept.get("input_contract", {})
	if contract.get("left_hand") != "four-way direction pad":
		failures.append("combat concept must specify a four-way direction pad")
	for action: String in REQUIRED_ACTIONS:
		if action not in contract.get("right_hand", []):
			failures.append("missing right-hand action: %s" % action)
	if "jump" not in contract.get("separate_buttons", []):
		failures.append("jump must remain a separate button")
	for button: String in ["action", "grab_support", "ultimate"]:
		if button not in contract.get("separate_buttons", []):
			failures.append("missing future separate button: %s" % button)
	for edge: String in REQUIRED_EDGES:
		if edge not in contract.get("edge_states", []):
			failures.append("missing input edge: %s" % edge)
	var direction_lock := String(contract.get("direction_lock", ""))
	if direction_lock.is_empty() or not direction_lock.contains("never auto-track or auto-turn"):
		failures.append("direction-lock policy is missing")
	if not String(contract.get("action_button_evolution", "")).contains("dash action") or not String(contract.get("action_button_evolution", "")).contains("neutral hold guards"):
		failures.append("action button evolution is missing")
	if not String(contract.get("grab_support_visibility", "")).contains("post-guard grace"):
		failures.append("grab support visibility rule is missing")


func _validate_system_rules(concept: Dictionary, failures: PackedStringArray) -> void:
	var rules: Dictionary = concept.get("system_rules", {})
	if rules.get("damage_model") != "cumulative-percent-knockback" or rules.get("stocks_per_fighter") != 3 or rules.get("ring_out") != true:
		failures.append("damage, stock, or ring-out rule drift")
	if rules.get("max_buffered_inputs") != 1:
		failures.append("exactly one buffered input is required")
	if rules.get("aerial_attack_limit_per_airtime") != 2:
		failures.append("aerial attack limit must be two")
	if rules.get("default_aerial_route") != ["air_light", "air_heavy"]:
		failures.append("default aerial route drift")
	if rules.get("pre_finisher_hit_branches") != ["next_light", "directional_heavy", "special"]:
		failures.append("pre-finisher branch options drift")
	if not String(rules.get("side_light_mobility", "")).contains("same base combo"):
		failures.append("side-light base combo rule is missing")
	if not String(rules.get("combo_length_damage_policy", "")).contains("does not by itself"):
		failures.append("combo length damage policy is missing")
	if rules.get("finisher_cancels") != false:
		failures.append("finishers must not be cancelable")
	for safeguard: String in ["combo_proration", "same_move_repeat_proration", "limited_di", "no_action_restore_on_hit", "victim_no_attack_cancel", "finisher_separation"]:
		if safeguard not in rules.get("anti_infinite", []):
			failures.append("missing anti-infinite safeguard: %s" % safeguard)
	if not String(rules.get("special_cooldown", "")).contains("Ground and air") or not String(rules.get("up_special_limit", "")).contains("Once per airtime"):
		failures.append("special cooldown or aerial recovery limit is missing")
	if not String(rules.get("ultimate", "")).contains("one per stock"):
		failures.append("ultimate stock limit is missing")
	if not String(rules.get("ultimate_capture_sequence", "")).contains("first capture hit"):
		failures.append("ultimate capture sequence rule is missing")


func _validate_common_families(concept: Dictionary, failures: PackedStringArray) -> void:
	var ids: Dictionary = {}
	for move_value: Variant in concept.get("common_move_families", []):
		if not (move_value is Dictionary):
			failures.append("common move family is invalid")
			continue
		var move: Dictionary = move_value
		_validate_move(move, ids, failures)
	if ids.size() != REQUIRED_COMMON_MOVE_IDS.size():
		failures.append("common move family count drift")
	for required_id: String in REQUIRED_COMMON_MOVE_IDS:
		if not ids.has(required_id):
			failures.append("required common move family is missing: %s" % required_id)
	for aerial_id: String in ["air_light", "air_heavy"]:
		var aerial: Dictionary = _move_by_id(concept.get("common_move_families", []), aerial_id)
		if aerial.get("directions") != ["neutral", "forward", "back", "up", "down"]:
			failures.append("five-direction aerial contract drift: %s" % aerial_id)
	var charge: Dictionary = _move_by_id(concept.get("common_move_families", []), "strong_charge")
	if not String(charge.get("risk", "")).contains("recovery both increase"):
		failures.append("charged strong risk rule is missing")


func _validate_future_defense_action(concept: Dictionary, failures: PackedStringArray) -> void:
	var defense: Dictionary = concept.get("future_defense_action", {})
	for required_key: String in ["neutral_hold", "side_press", "side_hold_after_evade", "air", "guard_to_grab", "guard_rules"]:
		if not defense.has(required_key) or str(defense[required_key]).is_empty():
			failures.append("future defense rule is missing: %s" % required_key)
	if not String(defense.get("guard_rules", "")).contains("no high/low guard"):
		failures.append("initial guard exclusions are missing")
	if not String(defense.get("guard_rules", "")).contains("deplete durability"):
		failures.append("guard durability and break rule is missing")


func _validate_visual_production_policy(concept: Dictionary, failures: PackedStringArray) -> void:
	var policy: Dictionary = concept.get("visual_production_policy", {})
	if policy.get("order") != ["ja-hyun", "myo-ryung", "nabi"]:
		failures.append("attack visual production order drift")
	if not String(policy.get("approval_gate", "")).contains("explicit user approval"):
		failures.append("attack visual approval gate is missing")
	if not String(policy.get("existing_candidate", "")).contains("not runtime registered"):
		failures.append("existing Ja-Hyun candidate preservation is missing")
	if not String(policy.get("review_animation", "")).contains("Actual limb, leg, and torso pose changes"):
		failures.append("attack animation pose-change requirement is missing")


func _validate_characters(concept: Dictionary, failures: PackedStringArray) -> void:
	var character_ids: Dictionary = {}
	var all_move_ids: Dictionary = {}
	for character_value: Variant in concept.get("characters", []):
		if not (character_value is Dictionary):
			failures.append("character combat profile is invalid")
			continue
		var character: Dictionary = character_value
		var character_id := String(character.get("character_id", ""))
		if not EXPECTED_COMBO_COUNTS.has(character_id) or character_ids.has(character_id):
			failures.append("unexpected or duplicate character combat profile: %s" % character_id)
			continue
		character_ids[character_id] = true
		if character.get("base_combo_count") != EXPECTED_COMBO_COUNTS[character_id]:
			failures.append("base combo count drift: %s" % character_id)
		for profile_key: String in ["identity", "aerial_profile", "directional_attack_profile", "throws"]:
			if not character.has(profile_key) or str(character[profile_key]).is_empty():
				failures.append("character attack profile is missing %s: %s" % [profile_key, character_id])
		var combo_indices: Dictionary = {}
		var combo_finishers: Dictionary = {}
		for move_value: Variant in character.get("moves", []):
			if not (move_value is Dictionary):
				failures.append("character move is invalid: %s" % character_id)
				continue
			var move: Dictionary = move_value
			_validate_move(move, all_move_ids, failures)
			if move.has("combo_index"):
				var combo_index := int(move["combo_index"])
				combo_indices[combo_index] = true
				combo_finishers[combo_index] = move.get("finisher")
		for combo_index: int in range(1, int(EXPECTED_COMBO_COUNTS[character_id]) + 1):
			if not combo_indices.has(combo_index):
				failures.append("missing base combo step %d: %s" % [combo_index, character_id])
			elif combo_finishers[combo_index] != (combo_index == int(EXPECTED_COMBO_COUNTS[character_id])):
				failures.append("base combo finisher placement drift: %s step %d" % [character_id, combo_index])
	if character_ids.size() != EXPECTED_COMBO_COUNTS.size():
		failures.append("three approved character combat profiles are required")
	for required_id: String in REQUIRED_CHARACTER_MOVE_IDS:
		if not all_move_ids.has(required_id):
			failures.append("required character move is missing: %s" % required_id)


func _validate_move(move: Dictionary, ids: Dictionary, failures: PackedStringArray) -> void:
	for field: String in REQUIRED_MOVE_FIELDS:
		if not move.has(field) or str(move.get(field, "")).is_empty():
			failures.append("move is missing required field '%s': %s" % [field, move.get("id", "<unnamed>")])
	var move_id := str(move.get("id", ""))
	if move_id.is_empty() or ids.has(move_id):
		failures.append("missing or duplicate move ID: %s" % move_id)
	else:
		ids[move_id] = true
	for prohibited_field: String in ["damage", "knockback", "hitbox", "startup", "active", "recovery"]:
		if move.has(prohibited_field):
			failures.append("concept move must not own runtime '%s': %s" % [prohibited_field, move_id])


func _move_by_id(moves: Array, move_id: String) -> Dictionary:
	for move_value: Variant in moves:
		if move_value is Dictionary and str(move_value.get("id", "")) == move_id:
			return move_value
	return {}


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("COMBAT_CONCEPT_CONTRACT: PASS")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("COMBAT_CONCEPT_CONTRACT: FAIL (%d)" % failures.size())
	quit(1)
