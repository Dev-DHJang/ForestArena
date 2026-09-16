extends SceneTree

const MANIFEST_PATH := "res://assets/character/manifest.json"
const FRAME_COUNT := 16
const CELL_SIZE := 128
const SHEET_SIZE := Vector2(CELL_SIZE * FRAME_COUNT, CELL_SIZE)
const REQUIRED_MOTIONS := {
	"ja-hyun/idle": {"fps": 8.0, "loop": true},
	"ja-hyun/run": {"fps": 12.0, "loop": true},
	"ja-hyun/jump": {"fps": 12.0, "loop": false},
	"myo-ryung/idle": {"fps": 8.0, "loop": true},
	"myo-ryung/run": {"fps": 12.0, "loop": true},
	"myo-ryung/jump": {"fps": 12.0, "loop": false},
	"nabi/idle": {"fps": 8.0, "loop": true},
	"nabi/run": {"fps": 12.0, "loop": true},
	"nabi/jump": {"fps": 12.0, "loop": false},
	"yu-ran/idle": {"fps": 8.0, "loop": true},
	"yu-ran/run": {"fps": 12.0, "loop": true},
	"yu-ran/jump": {"fps": 12.0, "loop": false},
}


func _initialize() -> void:
	var failures: PackedStringArray = []
	var manifest := _load_manifest(failures)
	var seen_asset_ids: Dictionary = {}
	var declared_motions: Dictionary = {}
	for entry: Variant in manifest.get("assets", []):
		if entry is Dictionary and entry.get("type") == "animation-runtime":
			_validate_motion(entry, seen_asset_ids, failures)
			var character_id := String(entry.get("character_id", ""))
			var motion_name := String(_motion_name_from_sheet("res://%s" % String(entry.get("path", ""))))
			var motion_key := "%s/%s" % [character_id, motion_name]
			if declared_motions.has(motion_key):
				failures.append("duplicate declared motion: %s" % motion_key)
			else:
				declared_motions[motion_key] = entry
	_validate_required_motions(declared_motions, failures)
	_finish(failures)


func _load_manifest(failures: PackedStringArray) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not (parsed is Dictionary):
		failures.append("character manifest is not a JSON object")
		return {}
	var manifest: Dictionary = parsed
	if manifest.get("schema_version") != 1 or not (manifest.get("assets") is Array):
		failures.append("character manifest has an invalid schema")
	return manifest


func _validate_motion(entry: Dictionary, seen_asset_ids: Dictionary, failures: PackedStringArray) -> void:
	var asset_id := String(entry.get("asset_id", ""))
	var character_id := String(entry.get("character_id", ""))
	var sheet_path := "res://%s" % String(entry.get("path", ""))
	var frame_path := String(entry.get("sprite_frames_path", ""))
	if asset_id.is_empty() or seen_asset_ids.has(asset_id):
		failures.append("missing or duplicate motion asset ID: %s" % asset_id)
		return
	seen_asset_ids[asset_id] = true
	if not _is_kebab_case(character_id):
		failures.append("motion character ID is not kebab-case: %s" % character_id)
	if not FileAccess.file_exists(sheet_path) or entry.get("sha256") != FileAccess.get_sha256(sheet_path):
		failures.append("motion sheet or manifest hash mismatch: %s" % asset_id)
		return
	if not frame_path.begins_with("res://"):
		failures.append("invalid SpriteFrames path: %s" % asset_id)
		return
	var motion_name := _motion_name_from_sheet(sheet_path)
	var sheet := load(sheet_path) as Texture2D
	var image := Image.load_from_file(ProjectSettings.globalize_path(sheet_path))
	var frames := load(frame_path) as SpriteFrames
	if sheet == null or sheet.get_size() != SHEET_SIZE:
		failures.append("invalid motion sheet size: %s" % sheet_path)
		return
	if image == null or image.detect_alpha() == Image.ALPHA_NONE:
		failures.append("motion sheet must contain alpha: %s" % sheet_path)
	if frames == null or motion_name.is_empty() or not frames.has_animation(motion_name):
		failures.append("missing SpriteFrames animation: %s" % frame_path)
		return
	if entry.get("frame_count") != FRAME_COUNT or frames.get_frame_count(motion_name) != FRAME_COUNT:
		failures.append("invalid frame count: %s" % asset_id)
	if not (entry.get("fps") is float or entry.get("fps") is int) or not is_equal_approx(frames.get_animation_speed(motion_name), float(entry.get("fps"))):
		failures.append("invalid animation speed: %s" % asset_id)
	if not (entry.get("loop") is bool) or frames.get_animation_loop(motion_name) != entry.get("loop"):
		failures.append("invalid animation loop: %s" % asset_id)
	for index: int in range(FRAME_COUNT):
		var atlas := frames.get_frame_texture(motion_name, index) as AtlasTexture
		if atlas == null or atlas.atlas == null or atlas.atlas.resource_path != sheet_path or atlas.region != Rect2(index * CELL_SIZE, 0, CELL_SIZE, CELL_SIZE):
			failures.append("invalid atlas frame %d for %s" % [index, asset_id])
			break
	if entry.get("consumer_path") != frame_path:
		failures.append("motion consumer path mismatch: %s" % asset_id)


func _validate_required_motions(declared_motions: Dictionary, failures: PackedStringArray) -> void:
	for motion_key: String in REQUIRED_MOTIONS:
		if not declared_motions.has(motion_key):
			failures.append("missing required runtime motion: %s" % motion_key)
			continue
		var entry: Dictionary = declared_motions[motion_key]
		var expected: Dictionary = REQUIRED_MOTIONS[motion_key]
		if not is_equal_approx(float(entry.get("fps", -1.0)), float(expected["fps"])):
			failures.append("required motion FPS mismatch: %s" % motion_key)
		if entry.get("loop") != expected["loop"]:
			failures.append("required motion loop mismatch: %s" % motion_key)


func _motion_name_from_sheet(sheet_path: String) -> StringName:
	var filename := sheet_path.get_file().get_basename()
	if not filename.ends_with("_16f"):
		return &""
	return StringName(filename.trim_suffix("_16f"))


func _is_kebab_case(value: String) -> bool:
	return value.is_valid_filename() \
		and value == value.to_lower() \
		and "_" not in value \
		and " " not in value \
		and not value.begins_with("-") \
		and not value.ends_with("-")


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("CHARACTER_MOTION_CONTRACT: PASS")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("CHARACTER_MOTION_CONTRACT: FAIL (%d)" % failures.size())
	quit(1)
