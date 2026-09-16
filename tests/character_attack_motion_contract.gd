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


func _initialize() -> void:
	var failures: PackedStringArray = []
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
	_validate_myo_ryung(manifest, attack_system, failures)
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
	if entry.get("combo_index") != expected["combo_index"] or entry.get("is_finisher") != expected["is_finisher"]:
		failures.append("incorrect Ja-Hyun combo metadata: %s" % visual_state_id)
	if entry.get("acting_purpose") != expected["acting_purpose"]:
		failures.append("incorrect Ja-Hyun acting purpose: %s" % visual_state_id)
	if entry.get("combo_index") != expected_move.get("combo_index") or entry.get("is_finisher") != expected_move.get("finisher") or entry.get("acting_purpose") != expected_move.get("role"):
		failures.append("manifest and attack-system visual metadata disagree: %s" % visual_state_id)
	var sheet_name := String(entry.get("path", "")).get_file().get_basename().trim_suffix("_16f")
	if sheet_name != visual_state_id:
		failures.append("runtime sheet and visual state differ: %s" % visual_state_id)
	if entry.get("sprite_frames_path") != entry.get("consumer_path"):
		failures.append("SpriteFrames consumer mismatch: %s" % visual_state_id)


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("CHARACTER_ATTACK_MOTION_CONTRACT: PASS")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("CHARACTER_ATTACK_MOTION_CONTRACT: FAIL (%d)" % failures.size())
	quit(1)
