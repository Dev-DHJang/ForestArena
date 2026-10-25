extends SceneTree

const IDS := ["ja-hyun", "myo-ryung", "nabi", "yu-ran"]


func _initialize() -> void:
	var failures: PackedStringArray = []
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/character/manifest.json"))
	var appearance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/contracts/character-appearance-v01.json"))
	var ids: Dictionary = {}
	var variants: Dictionary = {}
	var canonical: Dictionary = {}
	for entry: Dictionary in manifest.assets:
		if ids.has(entry.asset_id):
			failures.append("duplicate asset ID: %s" % entry.asset_id)
		ids[entry.asset_id] = true
		if entry.type == "concept":
			canonical[entry.character_id] = entry
		if entry.type != "concept-variant":
			continue
		var cid := String(entry.character_id)
		if not IDS.has(cid) or variants.has(cid):
			failures.append("unexpected/duplicate personality variant: %s" % cid)
		variants[cid] = entry
		if entry.asset_id != cid + "-concept-personality-v01" or entry.variant != "personality":
			failures.append("personality ID/type drift: %s" % cid)
		if entry.reference_concept_asset_id != cid + "-concept-v01":
			failures.append("canonical reference drift: %s" % cid)
		var path := "res://" + String(entry.path)
		if FileAccess.get_sha256(path) != entry.sha256:
			failures.append("personality image hash mismatch: %s" % cid)
		var texture := load(path) as Texture2D
		var image: Image = texture.get_image() if texture != null else null
		if texture == null or image == null or image.get_size() != Vector2i(1024, 1536):
			failures.append("personality PNG import/size failed: %s" % cid)
		elif image.get_format() != Image.FORMAT_RGBA8 or image.is_invisible() or image.detect_alpha() == Image.ALPHA_NONE:
			failures.append("personality PNG must have actual RGBA alpha: %s" % cid)
		if not FileAccess.file_exists("res://" + String(entry.consumer_path)):
			failures.append("personality design record missing: %s" % cid)
	if canonical.size() != 4 or variants.size() != 4:
		failures.append("four canonical concepts and four personality variants required")
	for cid: String in IDS:
		var character := load("res://assets/character/%s/character.tres" % cid) as CharacterData
		if character == null or String(character.concept_asset_id) != cid + "-concept-v01":
			failures.append("CharacterData canonical ID changed: %s" % cid)
		elif character.concept_image.resource_path != "res://assets/character/%s/concept/%s-concept-v01.png" % [cid, cid]:
			failures.append("CharacterData canonical image changed: %s" % cid)
	var policy: Dictionary = appearance.global_rules.get("non_combat_pose_policy", {})
	if policy.get("scope") != {"type":"concept-variant", "variant":"personality"}:
		failures.append("static-only personality pose exception missing")
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("CHARACTER_PERSONALITY_CONCEPT_CONTRACT: PASS (4 imported variants; canonical CharacterData unchanged)")
	quit(0)
