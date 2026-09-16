extends SceneTree

const APPEARANCE_PATH := "res://docs/contracts/character-appearance-v01.json"
const MANIFEST_PATH := "res://assets/character/manifest.json"
const EXPECTED := {
	"ja-hyun": {
		"concept_asset_id": "ja-hyun-concept-v01",
		"approved_design_version": "v01",
		"gender_presentation": "adult male",
		"animal_motif": "mouse",
		"must_keep": ["two oversized round mouse ears", "one long thin hairless mouse tail", "human face hands feet and body", "long cobalt blue ribbons"],
		"must_not_add": ["animal muzzle", "fur-covered limbs", "paw feet", "digitigrade or animal legs", "additional tails"],
	},
	"myo-ryung": {
		"concept_asset_id": "myo-ryung-concept-v01",
		"approved_design_version": "v01",
		"gender_presentation": "adult female",
		"animal_motif": "rabbit",
		"must_keep": ["two very long white rabbit ears with pink inner ears", "human face hands feet and body", "flowing rose ribbons", "kick-led fighting posture"],
		"angle_conditional": ["one small round white rabbit tail is permitted only when a side or rear view exposes it", "the rabbit tail is not required in a front-facing silhouette"],
		"must_not_add": ["rabbit muzzle or animal face", "fur-covered limbs", "paw feet", "digitigrade or animal legs", "long tail"],
	},
	"nabi": {
		"concept_asset_id": "nabi-concept-v01",
		"approved_design_version": "v05-white-tail-chibi",
		"gender_presentation": "adult female",
		"animal_motif": "cat",
		"must_keep": ["two white cat ears", "one long full white cat tail", "human face hands feet and body", "short lavender claw guards"],
		"must_not_add": ["animal muzzle", "fur-covered limbs", "paw feet", "digitigrade or animal legs", "bell accessory", "ribbon accessory", "paw-print emblem", "cat-face emblem"],
	},
	"yu-ran": {
		"concept_asset_id": "yu-ran-concept-v01",
		"approved_design_version": "v01",
		"gender_presentation": "adult female",
		"animal_motif": "weasel",
		"must_keep": ["two round brown weasel ears with white inner tufts", "one oversized long brown and white ringed tail", "human face hands feet and body", "teal diamond gem accents"],
		"must_not_add": ["animal muzzle or animal face", "fur-covered limbs", "paw feet", "digitigrade or animal legs", "additional ears", "additional tails"],
	},
}
const REQUIRED_CHARACTER_FIELDS := [
	"character_id",
	"concept_asset_id",
	"approved_design_version",
	"gender_presentation",
	"body_form",
	"animal_motif",
	"palette",
	"outfit",
	"silhouette_anchors",
	"must_keep",
	"angle_conditional",
	"may_vary",
	"must_not_add",
	"small_screen_priority",
]


func _initialize() -> void:
	var failures: PackedStringArray = []
	var appearance := _load_json(APPEARANCE_PATH, "appearance contract", failures)
	var manifest := _load_json(MANIFEST_PATH, "character manifest", failures)
	_validate_root(appearance, failures)
	_validate_characters(appearance, manifest, failures)
	_validate_attack_boundary(failures)
	_finish(failures)


func _load_json(path: String, label: String, failures: PackedStringArray) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		failures.append("%s is not a JSON object" % label)
		return {}
	return parsed


func _validate_root(contract: Dictionary, failures: PackedStringArray) -> void:
	if contract.get("schema_version") != 1:
		failures.append("appearance schema version drift")
	if contract.get("contract_id") != "character-appearance-v01":
		failures.append("appearance contract ID drift")
	if contract.get("phase") != 0:
		failures.append("appearance contract must remain Phase 0")
	var boundary := String(contract.get("authority_boundary", ""))
	for prohibited_authority: String in ["combat timing", "hitboxes", "damage", "stats", "collision", "match results"]:
		if not boundary.contains(prohibited_authority):
			failures.append("appearance authority boundary is missing: %s" % prohibited_authority)
	var rules: Dictionary = contract.get("global_rules", {})
	if not String(rules.get("age_policy", "")).contains("art proportion, not an age signal"):
		failures.append("chibi age boundary is missing")
	if not String(rules.get("motif_policy", "")).contains("Do not automatically add ears, tails, fur"):
		failures.append("explicit animal-feature gate is missing")
	if not String(rules.get("originality_policy", "")).contains("original, unbranded abstract species motifs"):
		failures.append("original unbranded motif policy is missing")


func _validate_characters(contract: Dictionary, manifest: Dictionary, failures: PackedStringArray) -> void:
	var concepts := _manifest_concepts(manifest, failures)
	var seen: Dictionary = {}
	var characters: Array = contract.get("characters", [])
	if characters.size() != EXPECTED.size():
		failures.append("exactly three approved appearance profiles are required")
	for value: Variant in characters:
		if not (value is Dictionary):
			failures.append("appearance profile is not an object")
			continue
		var profile: Dictionary = value
		var character_id := String(profile.get("character_id", ""))
		if not EXPECTED.has(character_id) or seen.has(character_id):
			failures.append("unexpected or duplicate appearance character: %s" % character_id)
			continue
		seen[character_id] = true
		_validate_required_fields(profile, character_id, failures)
		_validate_profile(profile, EXPECTED[character_id], failures)
		_validate_sources(profile, concepts, failures)
	if seen.size() != EXPECTED.size():
		failures.append("appearance contract does not cover the full approved roster")
	if concepts.size() != EXPECTED.size():
		failures.append("appearance contract and concept manifest roster counts differ")


func _manifest_concepts(manifest: Dictionary, failures: PackedStringArray) -> Dictionary:
	var concepts: Dictionary = {}
	for value: Variant in manifest.get("assets", []):
		if value is Dictionary and value.get("type") == "concept":
			var entry: Dictionary = value
			var character_id := String(entry.get("character_id", ""))
			if concepts.has(character_id):
				failures.append("duplicate concept manifest character: %s" % character_id)
			else:
				concepts[character_id] = entry
	return concepts


func _validate_required_fields(profile: Dictionary, character_id: String, failures: PackedStringArray) -> void:
	for field: String in REQUIRED_CHARACTER_FIELDS:
		if not profile.has(field):
			failures.append("appearance profile is missing %s: %s" % [field, character_id])
	for array_field: String in ["outfit", "silhouette_anchors", "must_keep", "angle_conditional", "may_vary", "must_not_add", "small_screen_priority"]:
		if not (profile.get(array_field) is Array) or profile[array_field].is_empty():
			failures.append("appearance profile requires non-empty %s: %s" % [array_field, character_id])
	var palette: Variant = profile.get("palette")
	if not (palette is Dictionary):
		failures.append("appearance palette is invalid: %s" % character_id)
	else:
		for palette_role: String in ["primary", "secondary", "accent"]:
			if not (palette.get(palette_role) is Array) or palette[palette_role].is_empty():
				failures.append("appearance palette is missing %s: %s" % [palette_role, character_id])


func _validate_profile(profile: Dictionary, expected: Dictionary, failures: PackedStringArray) -> void:
	var character_id := String(profile.get("character_id", ""))
	for scalar_field: String in ["concept_asset_id", "approved_design_version", "gender_presentation", "animal_motif"]:
		if profile.get(scalar_field) != expected.get(scalar_field):
			failures.append("appearance %s drift: %s" % [scalar_field, character_id])
	if profile.get("body_form") != "three-head-tall human-form fighter":
		failures.append("human-form body boundary drift: %s" % character_id)
	for list_field: String in ["must_keep", "angle_conditional", "must_not_add"]:
		for phrase: String in expected.get(list_field, []):
			if phrase not in profile.get(list_field, []):
				failures.append("appearance %s is missing '%s': %s" % [list_field, phrase, character_id])
	var prohibited_lookup: Dictionary = {}
	for phrase: Variant in profile.get("must_not_add", []):
		prohibited_lookup[String(phrase)] = true
	for phrase: Variant in profile.get("must_keep", []):
		if prohibited_lookup.has(String(phrase)):
			failures.append("appearance rule is both required and prohibited: %s: %s" % [character_id, phrase])
	for prohibited_field: String in ["damage", "stats", "hitbox", "startup", "active", "recovery", "collision", "match_result"]:
		if profile.has(prohibited_field):
			failures.append("appearance profile must not own combat field '%s': %s" % [prohibited_field, character_id])


func _validate_sources(profile: Dictionary, concepts: Dictionary, failures: PackedStringArray) -> void:
	var character_id := String(profile.get("character_id", ""))
	var concept_asset_id := String(profile.get("concept_asset_id", ""))
	if not concepts.has(character_id):
		failures.append("appearance character is missing from manifest: %s" % character_id)
		return
	var concept: Dictionary = concepts[character_id]
	if concept.get("asset_id") != concept_asset_id:
		failures.append("appearance and manifest concept IDs differ: %s" % character_id)
	var character_path := "res://assets/character/%s/character.tres" % character_id
	var character := load(character_path) as CharacterData
	if character == null:
		failures.append("appearance CharacterData could not load: %s" % character_id)
		return
	if String(character.character_id) != character_id or String(character.concept_asset_id) != concept_asset_id:
		failures.append("appearance and CharacterData IDs differ: %s" % character_id)


func _validate_attack_boundary(failures: PackedStringArray) -> void:
	var attack := _load_json("res://docs/contracts/attack-system-v01.json", "attack concept", failures)
	for value: Variant in attack.get("characters", []):
		if value is Dictionary and value.has("appearance_guardrail"):
			failures.append("attack concept must not own appearance_guardrail")


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("CHARACTER_APPEARANCE_CONTRACT: PASS")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("CHARACTER_APPEARANCE_CONTRACT: FAIL (%d)" % failures.size())
	quit(1)
