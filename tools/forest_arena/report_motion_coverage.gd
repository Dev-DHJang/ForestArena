extends SceneTree

const MANIFEST_PATH := "res://assets/character/manifest.json"
const CATALOG_PATH := "res://assets/loadouts/default_loadout_catalog.tres"
const REQUIRED_STATE_MOTIONS := [
	&"idle", &"run", &"jump", &"guard", &"evade", &"attack_heavy_charge",
	&"hitstun", &"launch", &"knock_down", &"wake_up", &"death", &"ring_out", &"spawn",
]


func _init() -> void:
	var output_path := ""
	var args := OS.get_cmdline_user_args()
	for index: int in range(args.size() - 1):
		if args[index] == "--output":
			output_path = args[index + 1]
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	var catalog := load(CATALOG_PATH) as LoadoutCatalog
	if not manifest is Dictionary or catalog == null:
		push_error("motion coverage inputs could not be loaded")
		quit(1)
		return
	var approved_by_character := {}
	for entry: Dictionary in manifest.get("assets", []):
		if entry.get("type") != "animation-runtime":
			continue
		var id := String(entry.get("character_id", ""))
		var sprite_frames_path := String(entry.get("sprite_frames_path", ""))
		var motion := String(entry.get("visual_state_id", sprite_frames_path.get_file().get_basename()))
		if id.is_empty() or motion.is_empty():
			continue
		if not approved_by_character.has(id):
			approved_by_character[id] = {}
		approved_by_character[id][motion] = true
	var characters := []
	for character: CharacterData in catalog.characters:
		var id := String(character.character_id)
		var approved: Dictionary = approved_by_character.get(id, {})
		var attack_ids := {}
		for attack: AttackData in character.base_move_set.attacks():
			if not attack.visual_state_id.is_empty():
				attack_ids[String(attack.visual_state_id)] = true
		var required_attacks: Array = attack_ids.keys()
		required_attacks.sort()
		var missing_attacks := required_attacks.filter(func(motion: String) -> bool: return not approved.has(motion))
		var missing_states := REQUIRED_STATE_MOTIONS.filter(func(motion: StringName) -> bool: return not approved.has(String(motion)))
		characters.append({
			"character_id": id,
			"required_attack_motion_count": required_attacks.size(),
			"approved_attack_motion_count": required_attacks.size() - missing_attacks.size(),
			"missing_attack_motions": missing_attacks,
			"required_state_motion_count": REQUIRED_STATE_MOTIONS.size(),
			"approved_state_motion_count": REQUIRED_STATE_MOTIONS.size() - missing_states.size(),
			"missing_state_motions": missing_states.map(func(value: StringName) -> String: return String(value)),
		})
	var report := {
		"schema_version": 1,
		"source_manifest": MANIFEST_PATH,
		"source_catalog": CATALOG_PATH,
		"characters": characters,
	}
	var encoded := JSON.stringify(report, "  ") + "\n"
	if not output_path.is_empty():
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		if file == null:
			push_error("could not write motion coverage: " + output_path)
			quit(1)
			return
		file.store_string(encoded)
	else:
		print(encoded)
	quit(0)
