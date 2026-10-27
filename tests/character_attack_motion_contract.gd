extends SceneTree

const MANIFEST_PATH := "res://assets/character/manifest.json"
const ATTACK_SYSTEM_PATH := "res://docs/contracts/attack-system-v01.json"
const REQUIRED_ATTACKS := {
	"attack_light_combo_01": {"combo_index": 1, "is_finisher": false, "acting_purpose": "low jab"},
	"attack_light_combo_02": {"combo_index": 2, "is_finisher": false, "acting_purpose": "ribbon-drawing side strike"},
	"attack_light_combo_03": {"combo_index": 3, "is_finisher": true, "acting_purpose": "open-arm ribbon spin sweep"},
}
const REQUIRED_MYO_ATTACKS := {
	"attack_light_combo_01": {"combo_index": 1, "is_finisher": false, "acting_purpose": "short hand strike"},
	"attack_light_combo_02": {"combo_index": 2, "is_finisher": false, "acting_purpose": "rising knee"},
	"attack_light_combo_03": {"combo_index": 3, "is_finisher": false, "acting_purpose": "spinning kick"},
	"attack_light_combo_04": {"combo_index": 4, "is_finisher": true, "acting_purpose": "leaping spin-kick with opened ears and ribbon"},
}
const REQUIRED_NABI_ATTACKS := {
	"attack_light_combo_01": {"combo_index": 1, "is_finisher": false, "acting_purpose": "claw jab while off-hand guards"},
	"attack_light_combo_02": {"combo_index": 2, "is_finisher": true, "acting_purpose": "large crossed claw rake"},
}
const REQUIRED_YU_RAN_ATTACKS := {
	"attack_light_combo_01": {"combo_index": 1, "is_finisher": false, "acting_purpose": "quick hand spacing check"},
	"attack_light_combo_02": {"combo_index": 2, "is_finisher": false, "acting_purpose": "short tail side check"},
	"attack_light_combo_03": {"combo_index": 3, "is_finisher": true, "acting_purpose": "wide ringed-tail sweep"},
}


func _initialize() -> void:
	var failures: PackedStringArray = []
	_validate_history_lookup(failures)
	var manifest := _load_json(MANIFEST_PATH, failures)
	var attack_system := _load_json(ATTACK_SYSTEM_PATH, failures)
	var expected_moves := _ja_hyun_attack_moves(attack_system, failures)
	var declared: Dictionary = {}
	for entry: Variant in manifest.get("assets", []):
		if entry is Dictionary and entry.get("character_id") == "ja-hyun" and entry.get("type") == "animation-runtime" and entry.has("visual_state_id"):
			var visual_state_id := String(entry.get("visual_state_id", ""))
			if declared.has(visual_state_id):
				failures.append("duplicate Ja-Hyun attack visual state: %s" % visual_state_id)
			else:
				declared[visual_state_id] = entry
	for visual_state_id: String in REQUIRED_ATTACKS:
		if not declared.has(visual_state_id):
			failures.append("missing Ja-Hyun runtime attack: %s" % visual_state_id)
			continue
		_validate_entry(visual_state_id, declared[visual_state_id], expected_moves, failures)
	if declared.has("attack_light_combo_04"):
		_validate_registered_action("attack_light_combo_04", declared["attack_light_combo_04"], "ja-hyun", "킥", failures)
	_validate_myo_ryung(manifest, attack_system, failures)
	var nabi_moves := _character_attack_moves("nabi", attack_system, failures)
	for motion: String in REQUIRED_NABI_ATTACKS:
		var matches: Array = manifest.assets.filter(func(entry: Dictionary) -> bool: return entry.get("character_id") == "nabi" and entry.get("visual_state_id") == motion)
		if matches.size() != 1:
			failures.append("missing or duplicate Nabi motion " + motion)
			continue
		_validate_entry_against(motion, matches[0], REQUIRED_NABI_ATTACKS[motion], nabi_moves, failures)
	var yu_ran_moves := _character_attack_moves("yu-ran", attack_system, failures)
	for motion: String in REQUIRED_YU_RAN_ATTACKS:
		var matches: Array = manifest.assets.filter(func(entry: Dictionary) -> bool: return entry.get("character_id") == "yu-ran" and entry.get("visual_state_id") == motion)
		if matches.size() != 1:
			failures.append("missing or duplicate Yu-Ran motion " + motion)
			continue
		_validate_entry_against(motion, matches[0], REQUIRED_YU_RAN_ATTACKS[motion], yu_ran_moves, failures)
	_finish(failures)


func _validate_myo_ryung(manifest: Dictionary, attack_system: Dictionary, failures: PackedStringArray) -> void:
	var moves := _character_attack_moves("myo-ryung", attack_system, failures)
	var declared: Dictionary = {}
	for entry: Variant in manifest.get("assets", []):
		if entry is Dictionary and entry.get("character_id") == "myo-ryung" and entry.get("type") == "animation-runtime" and entry.has("visual_state_id"):
			declared[String(entry.get("visual_state_id"))] = entry
	for visual_state_id: String in REQUIRED_MYO_ATTACKS:
		if not declared.has(visual_state_id):
			failures.append("missing Myo-Ryung runtime attack: %s" % visual_state_id)
			continue
		_validate_entry_against(visual_state_id, declared[visual_state_id], REQUIRED_MYO_ATTACKS[visual_state_id], moves, failures)


func _load_json(path: String, failures: PackedStringArray) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	failures.append("invalid JSON: %s" % path)
	return {}


func _ja_hyun_attack_moves(attack_system: Dictionary, failures: PackedStringArray) -> Dictionary:
	return _character_attack_moves("ja-hyun", attack_system, failures)


func _character_attack_moves(character_id: String, attack_system: Dictionary, failures: PackedStringArray) -> Dictionary:
	for character: Variant in attack_system.get("characters", []):
		if character is Dictionary and character.get("character_id") == character_id:
			var moves: Dictionary = {}
			for move: Variant in character.get("moves", []):
				if move is Dictionary and String(move.get("visual_state_id", "")).begins_with("attack_light_combo_"):
					moves[String(move.get("visual_state_id"))] = move
			return moves
	failures.append("missing attack moves in attack system: %s" % character_id)
	return {}


func _validate_entry(visual_state_id: String, entry: Dictionary, expected_moves: Dictionary, failures: PackedStringArray) -> void:
	var expected: Dictionary = REQUIRED_ATTACKS[visual_state_id]
	_validate_entry_against(visual_state_id, entry, expected, expected_moves, failures)


func _validate_entry_against(visual_state_id: String, entry: Dictionary, expected: Dictionary, expected_moves: Dictionary, failures: PackedStringArray) -> void:
	var expected_move: Dictionary = expected_moves.get(visual_state_id, {})
	var historical_entry: Dictionary = entry
	if entry.has("motion_registration"):
		historical_entry = _legacy_combo_contract(entry)
		if historical_entry.is_empty():
			failures.append("registered motion lost its previous contract: %s" % visual_state_id)
			return
		_validate_registered_action(visual_state_id, entry, String(entry.get("character_id", "")), "", failures)
	if historical_entry.get("combo_index") != expected["combo_index"] or historical_entry.get("is_finisher") != expected["is_finisher"]:
		failures.append("incorrect Ja-Hyun combo metadata: %s" % visual_state_id)
	if historical_entry.get("acting_purpose") != expected["acting_purpose"]:
		failures.append("incorrect Ja-Hyun acting purpose: %s" % visual_state_id)
	if historical_entry.get("combo_index") != expected_move.get("combo_index") or historical_entry.get("is_finisher") != expected_move.get("finisher") or historical_entry.get("acting_purpose") != expected_move.get("role"):
		failures.append("manifest and attack-system visual metadata disagree: %s" % visual_state_id)
	# Explicit visual_state_id is the contract; versioned sheet names may differ.
	if String(entry.get("visual_state_id", "")) != visual_state_id:
		failures.append("runtime visual state differs: %s" % visual_state_id)
	if entry.get("sprite_frames_path") != entry.get("consumer_path"):
		failures.append("SpriteFrames consumer mismatch: %s" % visual_state_id)


func _legacy_combo_contract(entry: Dictionary) -> Dictionary:
	# Re-registration appends the previous artwork; legacy rules remain earlier.
	var history: Array = entry.get("registration_history", [])
	for index: int in range(history.size() - 1, -1, -1):
		var previous: Variant = history[index]
		if previous is Dictionary and previous.has("combo_index") and previous.has("is_finisher") and previous.has("acting_purpose"):
			return previous
	return {}


func _validate_history_lookup(failures: PackedStringArray) -> void:
	var original := {"combo_index": 1, "is_finisher": false, "acting_purpose": "original action"}
	var previous := {"motion_registration": {"catalog_path": "prior-catalog.json"}}
	if _legacy_combo_contract({"registration_history": [original]}) != original or _legacy_combo_contract({"registration_history": [original, previous]}) != original:
		failures.append("legacy combo contract must survive repeated artwork registration")
	if not _legacy_combo_contract({"registration_history": [previous]}).is_empty():
		failures.append("missing legacy combo contract must remain a failure")


func _validate_registered_action(visual_state_id: String, entry: Dictionary, character_id: String, required_word: String, failures: PackedStringArray) -> void:
	var registration: Dictionary = entry.get("motion_registration", {})
	if registration.is_empty():
		failures.append("approved current motion has no registration: %s/%s" % [character_id, visual_state_id])
		return
	var catalog_path := "res://" + String(registration.get("catalog_path", ""))
	if not FileAccess.file_exists(catalog_path) or FileAccess.get_sha256(catalog_path) != String(registration.get("catalog_sha256", "")):
		failures.append("registered action catalog changed: %s/%s" % [character_id, visual_state_id])
		return
	var catalog := _load_json(catalog_path, failures)
	for candidate: Variant in catalog.get("assets", []):
		if candidate is Dictionary and candidate.get("character_id") == character_id and candidate.get("visual_state_id") == visual_state_id:
			if candidate.get("sha256") != entry.get("sha256") or candidate.get("frame_count") != entry.get("frame_count"):
				failures.append("registered action artwork differs: %s/%s" % [character_id, visual_state_id])
			var action := String(candidate.get("expected_action", ""))
			if action.is_empty() or candidate.get("action_source") != "_workspace/motion-naturalness-v1/02_expectations.md" or (not required_word.is_empty() and not action.contains(required_word)):
				failures.append("registered action intent missing: %s/%s" % [character_id, visual_state_id])
			return
	failures.append("registered action absent from approved catalog: %s/%s" % [character_id, visual_state_id])


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("CHARACTER_ATTACK_MOTION_CONTRACT: PASS")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("CHARACTER_ATTACK_MOTION_CONTRACT: FAIL (%d)" % failures.size())
	quit(1)
