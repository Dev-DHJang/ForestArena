class_name LocalMenuStateStore
extends RefCounted

## Device menu data is deliberately separate from the v3 player profile.
const SCHEMA_VERSION := 1
const PRESET_FILE := "menu_presets_v01.json"
const CONTROLS_FILE := "menu_controls_v01.json"
var error := ""
var slots: Array[Dictionary] = [{}, {}, {}, {}]
var selected_slot := 0
var controls: Dictionary = default_controls()
var base_dir: String
var catalog: LocalPlayCatalog
var _owners: Dictionary = {}
var _owner := ""

func _init(p_base_dir: String = "user://", p_catalog: LocalPlayCatalog = null) -> void:
	base_dir = p_base_dir
	catalog = p_catalog if p_catalog != null else LocalPlayCatalog.new()

static func default_controls() -> Dictionary:
	return {"joystick_mode": "fixed", "button_scale": 1.0, "button_transparency": 0}

func load_presets(owner: String, current: Dictionary) -> bool:
	error = ""
	if owner.is_empty(): return _invalid("저장 사용자 이름이 비어 있습니다.")
	var document := _load_document(_path(PRESET_FILE), true)
	if not error.is_empty(): return false
	var next_owners: Dictionary = document.get("owners", {}).duplicate(true)
	if not next_owners.has(owner):
		var seed := current.duplicate(true)
		if seed == {"character": "", "accessory": ""}: seed = {}
		if not _valid_slot(seed): return _invalid("현재 장비가 올바르지 않습니다.")
		next_owners[owner] = {"slots": [seed, {}, {}, {}], "selected_slot": 0}
		if not _write_document(_path(PRESET_FILE), {"schema_version": SCHEMA_VERSION, "owners": next_owners}, true): return false
	_owners = next_owners
	_owner = owner
	_publish_owner()
	return true

func save_slot(index: int, character: String, accessory: String) -> bool:
	error = ""
	if _owner.is_empty() or index < 0 or index >= 4: return _invalid("프리셋 슬롯을 다시 선택하세요.")
	var slot := {"character": character, "accessory": accessory}
	if not _valid_slot(slot) or not catalog.is_playable_character(StringName(character)) or (not accessory.is_empty() and not catalog.is_playable_accessory(StringName(accessory))): return _invalid("현재 전투의 캐릭터와 활성 장신구만 저장할 수 있습니다.")
	var next := _owners.duplicate(true)
	next[_owner].slots[index] = slot
	return _commit_presets(next)

func set_active_slot(index: int) -> bool:
	error = ""
	if _owner.is_empty() or index < 0 or index >= 4: return _invalid("프리셋 슬롯을 다시 선택하세요.")
	var next := _owners.duplicate(true)
	next[_owner].selected_slot = index
	return _commit_presets(next)

func load_controls() -> bool:
	error = ""
	var document := _load_document(_path(CONTROLS_FILE), false)
	if not error.is_empty(): return false
	controls = _normalized_controls(document.get("controls", default_controls()))
	return true

func save_controls(next: Dictionary) -> bool:
	error = ""
	if not valid_controls(next): return _invalid("조작 설정의 값이나 간격이 올바르지 않습니다.")
	var document := {"schema_version": SCHEMA_VERSION, "controls": next.duplicate(true)}
	if not _write_document(_path(CONTROLS_FILE), document, false): return false
	controls = _normalized_controls(next)
	return true

static func _normalized_controls(value: Dictionary) -> Dictionary:
	return {"joystick_mode": value.joystick_mode, "button_scale": float(value.button_scale), "button_transparency": int(value.button_transparency)}

static func valid_controls(value: Variant) -> bool:
	if not value is Dictionary or not _exact_keys(value, ["joystick_mode", "button_scale", "button_transparency"]): return false
	if value.joystick_mode not in ["fixed", "floating"]: return false
	var scale: Variant = value.button_scale
	var transparency: Variant = value.button_transparency
	if not _number(scale) or not _number(transparency): return false
	return float(scale) >= 1.0 and float(scale) <= 1.2 and is_equal_approx(float(scale) * 20.0, roundf(float(scale) * 20.0)) and float(transparency) >= 0 and float(transparency) <= 50 and is_equal_approx(float(transparency) / 5.0, roundf(float(transparency) / 5.0))

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size(): return false
	for key: String in keys:
		if not value.has(key): return false
	return true

func _valid_slot(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if not _exact_keys(value, ["character", "accessory"]): return false
	return value.character is String and value.accessory is String and catalog.contains(value.character, "character") and (value.accessory == "" or catalog.contains(value.accessory, "accessory"))

func _valid_document(value: Dictionary, presets: bool) -> bool:
	if not _exact_keys(value, ["schema_version", "owners" if presets else "controls"]): return false
	if not _number(value.schema_version) or value.schema_version != SCHEMA_VERSION: return false
	if not presets: return valid_controls(value.controls)
	if not value.owners is Dictionary: return false
	for owner: Variant in value.owners:
		if not owner is String or owner.is_empty(): return false
		var entry: Variant = value.owners[owner]
		if not entry is Dictionary or not _exact_keys(entry, ["slots", "selected_slot"]): return false
		if not entry.slots is Array or entry.slots.size() != 4: return false
		if not _number(entry.selected_slot) or float(entry.selected_slot) != floorf(float(entry.selected_slot)) or entry.selected_slot < 0 or entry.selected_slot >= 4: return false
		for slot: Variant in entry.slots:
			if not _valid_slot(slot): return false
	return true

func _load_document(path: String, presets: bool) -> Dictionary:
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"): return {}
	var candidate := _read(path)
	# Never downgrade or overwrite a document from a different application version.
	if candidate.has("schema_version") and candidate.schema_version != SCHEMA_VERSION:
		_invalid("이 메뉴 저장 파일의 버전은 지원하지 않습니다.")
		return {}
	if _valid_document(candidate, presets): return candidate
	candidate = _read(path + ".bak")
	if _valid_document(candidate, presets): return candidate
	_invalid("메뉴 저장 파일과 백업을 읽을 수 없습니다. 다시 시도하세요.")
	return {}

func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var source := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF: return {}
	var parser := JSON.new()
	if parser.parse(source) != OK or not parser.data is Dictionary: return {}
	return parser.data

func _write_document(path: String, document: Dictionary, presets: bool) -> bool:
	if not _valid_document(document, presets): return _invalid("메뉴 저장 형식이 올바르지 않습니다.")
	# A later version that appeared after loading must also stay intact.
	var previous := _read(path)
	if previous.has("schema_version") and previous.schema_version != SCHEMA_VERSION: return _invalid("이 메뉴 저장 파일의 버전은 지원하지 않습니다.")
	if FileAccess.file_exists(base_dir): return _save_failed()
	if not DirAccess.dir_exists_absolute(base_dir) and DirAccess.make_dir_recursive_absolute(base_dir) != OK: return _save_failed()
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return _save_failed()
	file.store_string(JSON.stringify(document))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or not _valid_document(_read(temporary), presets):
		DirAccess.remove_absolute(temporary)
		return _save_failed()
	# Corrupt primary files must never replace the last usable backup.
	if _valid_document(previous, presets):
		if DirAccess.dir_exists_absolute(path + ".bak") or DirAccess.copy_absolute(path, path + ".bak") != OK:
			DirAccess.remove_absolute(temporary)
			return _save_failed()
	if DirAccess.rename_absolute(temporary, path) != OK:
		DirAccess.remove_absolute(temporary)
		return _save_failed()
	return true

func _commit_presets(next: Dictionary) -> bool:
	if not _write_document(_path(PRESET_FILE), {"schema_version": SCHEMA_VERSION, "owners": next}, true): return false
	_owners = next
	_publish_owner()
	return true

func _publish_owner() -> void:
	slots.clear()
	for slot: Dictionary in _owners[_owner].slots: slots.append(slot.duplicate(true))
	selected_slot = int(_owners[_owner].selected_slot)

func _path(file: String) -> String:
	return base_dir.path_join(file)

func _invalid(message: String) -> bool:
	error = message
	return false

func _save_failed() -> bool:
	return _invalid("메뉴 저장에 실패했습니다. 변경은 적용되지 않았습니다. 저장 공간을 확인하고 다시 시도하세요.")

func import_owner_snapshot(owner: String, source_slots: Array, active: int) -> bool:
	error = ""
	if owner.is_empty() or source_slots.size() != 4 or active < 0 or active >= 4: return _invalid("편성 이전 정보가 올바르지 않습니다.")
	for slot: Variant in source_slots:
		if not _valid_slot(slot): return _invalid("편성 이전 정보가 올바르지 않습니다.")
	var document := _load_document(_path(PRESET_FILE), true)
	if not error.is_empty(): return false
	var next: Dictionary = document.get("owners", {}).duplicate(true)
	next[owner] = {"slots": source_slots.duplicate(true), "selected_slot": active}
	if not _write_document(_path(PRESET_FILE), {"schema_version": SCHEMA_VERSION, "owners": next}, true): return false
	_owners = next
	# Keep the previous active owner until the app accepts the identity.
	return true
