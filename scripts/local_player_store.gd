class_name LocalPlayerStore
extends RefCounted

var catalog: LocalPlayCatalog
var path: String
var data: Dictionary = fresh_data()
var error := ""
var recovered := false

func _init(p_catalog: LocalPlayCatalog, p_path := "user://local_player.json") -> void:
	catalog = p_catalog
	path = p_path

static func fresh_data() -> Dictionary:
	return {"schema_version": 1, "first_granted": false, "characters": [], "accessories": [], "selected_character": "", "selected_accessory": "", "opponent_character": "ja-hyun"}

func load_profile() -> bool:
	error = ""
	recovered = false
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		data = fresh_data()
		return true
	var candidate := _read(path)
	if valid(candidate):
		data = candidate
		return true
	candidate = _read(path + ".bak")
	if valid(candidate):
		data = candidate
		recovered = true
		return true
	error = "저장 파일을 읽을 수 없습니다. 다시 시도하거나 저장 초기화를 선택하세요."
	return false

func valid(value: Dictionary) -> bool:
	if value.get("schema_version") != 1 or not value.get("first_granted") is bool: return false
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
	if valid(_read(path)):
		if DirAccess.copy_absolute(path, path + ".bak") != OK: return _save_failed()
	if DirAccess.rename_absolute(temporary, path) != OK: return _save_failed()
	data = next
	return true

func _save_failed() -> bool:
	error = "저장에 실패했습니다. 변경은 적용되지 않았습니다. 저장 공간을 확인하고 다시 시도하세요."
	return false
