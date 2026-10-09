extends SceneTree

const MANIFEST_PATH := "res://assets/character/manifest.json"


func _initialize() -> void:
	var failures: PackedStringArray = []
	var manifest := _load_manifest(failures)
	var seen_asset_ids: Dictionary = {}
	var seen_character_ids: Dictionary = {}
	for entry: Variant in manifest.get("assets", []):
		if entry is Dictionary and entry.get("type") == "concept":
			_validate_concept(entry, seen_asset_ids, seen_character_ids, failures)
	_finish(failures)


func _load_manifest(failures: PackedStringArray) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not (parsed is Dictionary):
		failures.append("character asset manifest is not a JSON object")
		return {}
	var manifest: Dictionary = parsed
	if manifest.get("schema_version") != 1 or not (manifest.get("assets") is Array):
		failures.append("character asset manifest has an invalid schema")
	return manifest


func _validate_concept(entry: Dictionary, seen_asset_ids: Dictionary, seen_character_ids: Dictionary, failures: PackedStringArray) -> void:
	var asset_id := String(entry.get("asset_id", ""))
	var character_id := String(entry.get("character_id", ""))
	var asset_path := "res://%s" % String(entry.get("path", ""))
	if asset_id.is_empty() or seen_asset_ids.has(asset_id):
		failures.append("missing or duplicate concept asset ID: %s" % asset_id)
		return
	seen_asset_ids[asset_id] = true
	if not _is_kebab_case(character_id) or seen_character_ids.has(character_id):
		failures.append("missing, duplicate, or non-kebab-case character ID: %s" % character_id)
		return
	seen_character_ids[character_id] = true
	if not FileAccess.file_exists(asset_path):
		failures.append("missing concept image: %s" % asset_path)
		return
	if entry.get("sha256") != FileAccess.get_sha256(asset_path):
		failures.append("manifest hash mismatch: %s" % character_id)
	var image := Image.load_from_file(asset_path)
	if image == null or image.get_format() != Image.FORMAT_RGBA8 or image.detect_alpha() == Image.ALPHA_NONE:
		failures.append("concept must be a real transparent RGBA PNG: %s" % character_id)
	elif image.get_pixel(0, 0).a != 0.0 or image.get_pixel(image.get_width()-1, image.get_height()-1).a != 0.0:
		failures.append("concept background corners must be transparent: %s" % character_id)
	var character_path := "res://assets/character/%s/character.tres" % character_id
	var character := load(character_path) as CharacterData
	if character == null:
		failures.append("could not load CharacterData: %s" % character_path)
		return
	if not character.is_valid_definition():
		failures.append("invalid CharacterData definition: %s" % character_path)
	if String(character.character_id) != character_id or String(character.concept_asset_id) != asset_id:
		failures.append("CharacterData ID mismatch: %s" % character_id)
	if character.concept_image == null or character.concept_image.resource_path != asset_path:
		failures.append("CharacterData image reference mismatch: %s" % character_id)
	if entry.get("consumer_path") != character_path:
		failures.append("concept consumer path mismatch: %s" % character_id)


func _is_kebab_case(value: String) -> bool:
	return value.is_valid_filename() \
		and value == value.to_lower() \
		and "_" not in value \
		and " " not in value \
		and not value.begins_with("-") \
		and not value.ends_with("-")


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("CHARACTER_DATA_CONTRACT: PASS")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("CHARACTER_DATA_CONTRACT: FAIL (%d)" % failures.size())
	quit(1)
