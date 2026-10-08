class_name LocalPlayerStore
extends RefCounted

const SCHEMA_VERSION := 3
const TEXT_SCALES := [1.0, 1.15, 1.3]
var catalog: LocalPlayCatalog
var path: String
var data: Dictionary = fresh_data()
var error := ""
var recovered := false

func _init(p_catalog: LocalPlayCatalog, p_path := "user://local_player.json") -> void:
	catalog = p_catalog
	path = p_path

static func fresh_data() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "first_granted": false, "characters": [], "accessories": [], "selected_character": "", "selected_accessory": "", "opponent_character": "ja-hyun", "accessibility": default_accessibility(), "nickname": "플레이어", "minimap": default_minimap()}


static func default_accessibility() -> Dictionary:
	return {"text_scale": 1.0, "reduce_visual_effects": false, "haptics_enabled": true}

func load_profile() -> bool:
	error = ""
	recovered = false
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		data = fresh_data()
		return true
	var candidate := _read(path)
	if _load_candidate(candidate):
		return true
	candidate = _read(path + ".bak")
	if _load_candidate(candidate):
		recovered = true
		return true
	error = "저장 파일을 읽을 수 없습니다. 다시 시도하거나 저장 초기화를 선택하세요."
	return false


func load_profile_read_only() -> bool:
	# Upgrade a copy for DB import without changing the device file.
	for file_path: String in [path, path + ".bak"]:
		var candidate := migrate_profile(_read(file_path))
		if not candidate.is_empty():
			data = candidate
			return true
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		data = fresh_data()
		return true
	return false

func migrate_profile(candidate: Dictionary) -> Dictionary:
	if valid(candidate):
		var normalized := candidate.duplicate(true)
		normalized.minimap.transparency = int(normalized.minimap.transparency)
		return normalized
	var version: Variant = candidate.get("schema_version")
	if (version != 1 and version != 2) or not _valid_base(candidate): return {}
	if version == 2 and not _valid_accessibility(candidate.get("accessibility")): return {}
	var migrated := candidate.duplicate(true)
	migrated.schema_version = SCHEMA_VERSION
	if version == 1: migrated.accessibility = default_accessibility()
	migrated.nickname = "플레이어"
	migrated.minimap = default_minimap()
	return migrated if valid(migrated) else {}

func _load_candidate(candidate: Dictionary) -> bool:
	var migrated := migrate_profile(candidate)
	if migrated.is_empty(): return false
	if candidate.get("schema_version") == SCHEMA_VERSION:
		data = migrated
		return true
	# Commit first: failed migration must not replace the in-memory profile.
	return _commit(migrated)

func valid(value: Dictionary) -> bool:
	return value.get("schema_version") == SCHEMA_VERSION and _valid_base(value) and _valid_accessibility(value.get("accessibility")) and valid_nickname(value.get("nickname")) and valid_minimap(value.get("minimap"))

static func default_minimap() -> Dictionary:
	return {"transparency": 30, "marker_style": "face", "show_names": true}

static func normalize_nickname(value: String) -> String:
	return value.strip_edges()

static func valid_nickname(value: Variant) -> bool:
	if not value is String or value != normalize_nickname(value) or value.length() < 1 or value.length() > 12: return false
	return not _has_control(value)

static func _has_control(value: String) -> bool:
	for index: int in value.length():
		var code: int = value.unicode_at(index)
		if code < 32 or (code >= 127 and code <= 159) or code == 0x2028 or code == 0x2029: return true
	return false

static func valid_minimap(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 3: return false
	var transparency: Variant = value.get("transparency")
	return (transparency is int or transparency is float) and float(transparency) == floor(float(transparency)) and transparency >= 0 and transparency <= 90 and value.get("marker_style") in ["face", "dot"] and value.get("show_names") is bool

static func _valid_accessibility(accessibility: Variant) -> bool:
	if not accessibility is Dictionary or not accessibility.get("reduce_visual_effects") is bool or not accessibility.get("haptics_enabled") is bool: return false
	var text_scale: Variant = accessibility.get("text_scale")
	return (text_scale is float or text_scale is int) and TEXT_SCALES.has(float(text_scale))

func _valid_base(value: Dictionary) -> bool:
	if not value.get("first_granted") is bool: return false
	for pair: Array in [["characters", "character"], ["accessories", "accessory"]]:
		if not value.get(pair[0]) is Array: return false
		var seen := {}
		for id: Variant in value[pair[0]]:
			if not id is String or not catalog.contains(id, pair[1]) or seen.has(id): return false
			seen[id] = true
	for key: String in ["selected_character", "selected_accessory", "opponent_character"]:
		if not value.get(key) is String: return false
	if not catalog.contains(value.opponent_character, "character"): return false
	if value.first_granted:
		if not value.selected_character in value.characters: return false
	elif not value.characters.is_empty() or not value.accessories.is_empty() or value.selected_character != "": return false
	return value.selected_accessory == "" or value.selected_accessory in value.accessories

func owns(id: String) -> bool:
	return id in data.characters or id in data.accessories

func grant_first(id: String) -> bool:
	if data.first_granted or not catalog.contains(id, "character"): return false
	var next := data.duplicate(true)
	next.first_granted = true
	next.characters.append(id)
	next.selected_character = id
	return _commit(next)

func purchase(id: String) -> bool:
	var item := catalog.product(id)
	if not data.first_granted or item.is_empty() or owns(id) or item.price != 0: return false
	var next := data.duplicate(true)
	next["characters" if item.kind == "character" else "accessories"].append(id)
	return _commit(next)

func select(character: String, accessory: String, opponent: String) -> bool:
	var next := data.duplicate(true)
	next.selected_character = character
	next.selected_accessory = accessory
	next.opponent_character = opponent
	return _commit(next)


func update_accessibility(text_scale: float, reduce_visual_effects: bool, haptics_enabled: bool) -> bool:
	var next := data.duplicate(true)
	next.accessibility = {"text_scale": text_scale, "reduce_visual_effects": reduce_visual_effects, "haptics_enabled": haptics_enabled}
	return _commit(next)

func update_identity(nickname: String) -> bool:
	var next := data.duplicate(true)
	next.nickname = normalize_nickname(nickname)
	if not valid_nickname(nickname.strip_edges()) or _has_control(nickname):
		error = "닉네임은 공백을 제외한 1~12자로 입력하고 줄바꿈·제어 문자는 사용할 수 없습니다."
		return false
	return _commit(next)

func update_minimap(settings: Dictionary) -> bool:
	var next := data.duplicate(true)
	next.minimap = settings.duplicate(true)
	return _commit(next)

func reset_profile() -> bool:
	return _commit(fresh_data())

func _read(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path): return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(file_path)) != OK: return {}
	var decoded: Variant = json.data
	return decoded if decoded is Dictionary else {}

func _commit(next: Dictionary) -> bool:
	error = ""
	if not valid(next):
		error = "보유하지 않은 장비이거나 잘못된 선택입니다."
		return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return _save_failed()
	file.store_string(JSON.stringify(next))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or not valid(_read(temporary)): return _save_failed()
	# Keep a valid previous snapshot; never replace the backup with corrupt input.
	if not migrate_profile(_read(path)).is_empty():
		if DirAccess.copy_absolute(path, path + ".bak") != OK: return _save_failed()
	if DirAccess.rename_absolute(temporary, path) != OK: return _save_failed()
	data = next
	return true

func _save_failed() -> bool:
	error = "저장에 실패했습니다. 변경은 적용되지 않았습니다. 저장 공간을 확인하고 다시 시도하세요."
	return false
