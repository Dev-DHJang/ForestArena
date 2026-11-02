extends SceneTree
const STORE := preload("res://scripts/premium_menu/local_menu_state_store.gd")
const ROOT := "user://qa/menu_state_store_contract"
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func clear_files(dir: String) -> void:
	for filename: String in [STORE.PRESET_FILE, STORE.CONTROLS_FILE]:
		for suffix: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(dir.path_join(filename) + suffix)

func _initialize() -> void:
	var catalog := LocalPlayCatalog.new()
	DirAccess.make_dir_recursive_absolute(ROOT)
	clear_files(ROOT)
	var profile_path := ROOT.path_join("local_player.json")
	var profile_bytes := '{"schema_version":3,"nickname":"기존 저장 확인","unchanged":true}'
	write(profile_path, profile_bytes)
	var store := STORE.new(ROOT, catalog)
	var seed := {"character": "ja-hyun", "accessory": ""}
	check(store.load_presets("device", seed), "seed device presets")
	check(store.slots == [seed, {}, {}, {}] and store.selected_slot == 0, "four slots with current only in slot zero")
	for index: int in 4:
		check(store.save_slot(index, "ja-hyun", ""), "save each of four slots")
	check(store.save_slot(0, "ja-hyun", "pebble-yoyo") and store.slots[0].accessory == "pebble-yoyo", "active yo-yo preset survives save")
	check(store.set_active_slot(3), "select last slot")
	var reload := STORE.new(ROOT, catalog)
	check(reload.load_presets("device", seed) and reload.slots == store.slots and reload.selected_slot == 3, "presets survive re-instantiation")
	check(reload.load_presets("db:server-a:player-a", seed) and reload.slots == [seed, {}, {}, {}], "DB owner starts independently")
	check(reload.save_slot(2, "ja-hyun", "") and reload.set_active_slot(2), "store DB owner's data")
	check(reload.load_presets("db:server-b:player-a", seed) and reload.slots == [seed, {}, {}, {}], "same player at another server is independent")
	check(reload.load_presets("device", seed) and reload.selected_slot == 3 and reload.slots[2].accessory == "", "switching owners preserves device")
	check(not reload.save_slot(0, "myo-ryung", "") and not reload.save_slot(0, "ja-hyun", "fixture-iron-armor"), "new presets reject inactive character/accessory")
	var before: Array = reload.slots.duplicate(true)
	check(not reload.save_slot(4, "ja-hyun", "") and not reload.set_active_slot(-1), "slot indices stay bounded")
	check(not reload.save_slot(0, "missing", "") and not reload.save_slot(0, "ja-hyun", "missing") and reload.slots == before, "catalog rejects bad IDs without mutating memory")
	check(not reload.load_presets("invalid", {"character":"missing","accessory":""}) and reload.slots == before, "invalid seed keeps current owner state")
	var preset_path := ROOT.path_join(STORE.PRESET_FILE)
	write(preset_path, "{broken")
	check(reload.load_presets("device", seed) and reload.selected_slot == 3, "corrupt primary uses previous valid backup")
	check(reload.save_slot(0, "ja-hyun", ""), "save recovered document")
	var backup := FileAccess.get_file_as_string(preset_path + ".bak")
	check(JSON.parse_string(backup) is Dictionary, "saving recovery preserves valid backup")
	write(preset_path, '{"schema_version":99,"owners":{}}')
	before = reload.slots.duplicate(true)
	check(not reload.load_presets("device", seed) and reload.slots == before and not reload.save_slot(0, "ja-hyun", ""), "future version is rejected without downgrade")
	check(FileAccess.get_file_as_string(preset_path).contains('99'), "future file stays untouched")
	check(store.load_controls() and store.controls == STORE.default_controls(), "control defaults")
	var max_controls := {"joystick_mode": "floating", "button_scale": 1.2, "button_transparency": 50}
	check(store.save_controls(max_controls), "save maximum controls")
	check(store.save_controls({"joystick_mode":"fixed","button_scale":1.05,"button_transparency":5}), "valid settings steps")
	check(reload.load_controls() and reload.controls.button_scale == 1.05, "control settings survive restart")
	for invalid: Dictionary in [
		{"joystick_mode":"bad","button_scale":1.0,"button_transparency":0},
		{"joystick_mode":"fixed","button_scale":1.03,"button_transparency":0},
		{"joystick_mode":"fixed","button_scale":1.25,"button_transparency":0},
		{"joystick_mode":"fixed","button_scale":1.0,"button_transparency":51},
		{"joystick_mode":"fixed","button_scale":1.0,"button_transparency":3},
		{"joystick_mode":"fixed","button_scale":true,"button_transparency":0},
		{"joystick_mode":"fixed","button_scale":1.0,"button_transparency":0,"unknown":true}]:
		var old: Dictionary = reload.controls.duplicate(true)
		check(not reload.save_controls(invalid) and reload.controls == old, "invalid controls keep live data")
	var control_path := ROOT.path_join(STORE.CONTROLS_FILE)
	write(control_path, "[]")
	check(reload.load_controls() and reload.controls == max_controls, "controls recover previous valid snapshot")
	write(control_path + ".bak", '{}')
	var old: Dictionary = reload.controls.duplicate(true)
	check(not reload.load_controls() and reload.controls == old, "both unreadable controls preserve memory")
	write(control_path, '{"schema_version":1,"controls":{"joystick_mode":"fixed","button_scale":1.0,"button_transparency":0},"unknown":true}')
	check(not reload.load_controls(), "unknown document fields rejected")
	# A directory at the temporary filename reliably blocks writing on every OS.
	var blocker := ROOT.path_join("blocked_writes")
	DirAccess.make_dir_recursive_absolute(blocker)
	for name: String in [STORE.PRESET_FILE, STORE.CONTROLS_FILE]:
		DirAccess.make_dir_recursive_absolute(blocker.path_join(name) + ".tmp")
	var failed := STORE.new(blocker, catalog)
	check(not failed.load_presets("device", seed) and failed.slots == [{},{},{},{}], "initial preset write failure keeps defaults")
	check(not failed.save_controls(max_controls) and failed.controls == STORE.default_controls(), "failed controls write keeps live defaults")
	store.base_dir = blocker
	before = store.slots.duplicate(true)
	check(not store.save_slot(0, "ja-hyun", "") and store.slots == before and not store.set_active_slot(0) and store.selected_slot == 3, "failed preset save keeps slots and selected index")
	var blocker_file := ROOT.path_join("regular_file_blocker")
	write(blocker_file, "blocked")
	failed.base_dir = blocker_file
	check(not failed.save_controls(max_controls) and failed.controls == STORE.default_controls(), "ordinary file base directory returns a recoverable failure")
	DirAccess.remove_absolute(blocker_file)
	# Block final replacement after the temporary JSON was written and validated.
	var rename_dir := ROOT.path_join("blocked_rename")
	var rename_store := STORE.new(rename_dir, catalog)
	DirAccess.make_dir_recursive_absolute(rename_dir.path_join(STORE.PRESET_FILE))
	check(not rename_store.load_presets("device", seed) and rename_store.slots == [{},{},{},{}], "failed final preset rename preserves memory")
	DirAccess.make_dir_recursive_absolute(rename_dir.path_join(STORE.CONTROLS_FILE))
	check(not rename_store.save_controls(max_controls) and rename_store.controls == STORE.default_controls(), "failed final controls rename preserves memory")
	for name: String in [STORE.PRESET_FILE, STORE.CONTROLS_FILE]:
		DirAccess.remove_absolute(rename_dir.path_join(name))
	DirAccess.remove_absolute(rename_dir)
	# Backup copy failures must stop before replacing the primary file.
	var copy_dir := ROOT.path_join("blocked_backup")
	var copy_store := STORE.new(copy_dir, catalog)
	check(copy_store.load_presets("device", seed), "create baseline for failed backup copy")
	var primary := FileAccess.get_file_as_string(copy_dir.path_join(STORE.PRESET_FILE))
	DirAccess.make_dir_recursive_absolute(copy_dir.path_join(STORE.PRESET_FILE) + ".bak")
	check(not copy_store.save_slot(1, "ja-hyun", "") and copy_store.slots[1].is_empty(), "failed preset backup copy preserves memory")
	check(FileAccess.get_file_as_string(copy_dir.path_join(STORE.PRESET_FILE)) == primary, "failed preset backup copy preserves primary bytes")
	check(copy_store.save_controls(STORE.default_controls()), "create control baseline for failed backup copy")
	DirAccess.make_dir_recursive_absolute(copy_dir.path_join(STORE.CONTROLS_FILE) + ".bak")
	check(not copy_store.save_controls(max_controls) and copy_store.controls == STORE.default_controls(), "failed controls backup copy preserves memory")
	for name: String in [STORE.PRESET_FILE, STORE.CONTROLS_FILE]:
		DirAccess.remove_absolute(copy_dir.path_join(name) + ".bak")
	clear_files(copy_dir)
	DirAccess.remove_absolute(copy_dir)
	check(FileAccess.get_file_as_string(profile_path) == profile_bytes, "menu data never rewrites v3 profile bytes")
	# QA data follows the passed profile directory and cannot touch device data.
	var qa_dir := ROOT.path_join("qa_other")
	var qa := STORE.new(qa_dir, catalog)
	clear_files(qa_dir)
	var device_bytes := FileAccess.get_file_as_string(preset_path)
	check(qa.load_presets("device", seed) and qa.save_controls(max_controls), "QA directory usable independently")
	check(FileAccess.get_file_as_string(preset_path) == device_bytes and qa_dir != ROOT, "QA directory changes leave another device file intact")
	clear_files(qa_dir)
	DirAccess.remove_absolute(qa_dir)
	clear_files(ROOT)
	DirAccess.remove_absolute(profile_path)
	for name: String in [STORE.PRESET_FILE, STORE.CONTROLS_FILE]:
		DirAccess.remove_absolute(blocker.path_join(name) + ".tmp")
	DirAccess.remove_absolute(blocker)
	DirAccess.remove_absolute(ROOT)
	for failure: String in failures: push_error(failure)
	print("MENU_STATE_STORE: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
