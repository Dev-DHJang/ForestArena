class_name AndroidQaSession
extends Node
## Explicit debug-only mailbox. Observes normal app paths; never edits HP or positions.
const VERSION := 1
var app: Node
var run_id := ""
var device_alias := "device"
var directory := ""
var command_seq := 0
var command_error := ""
var case_id := "DEV-01"
var step := "ready"
var active := false
var autoplay := false
var allow_ultimate := true
var reset_snapshot: Dictionary = {}
var _fighter_signatures: Dictionary = {}
var peer_connected := true
var foreground := true
var latest_result: Dictionary = {}
var last_lan_error := ""
var snapshot: Dictionary = {}
var touch_events: Array[Dictionary] = []
var combat_events: Array[Dictionary] = []
var event_seq := 0
var touch_count := 0
var boot_id := ""
var input_reset_count := 0
var match_generation := 0
var performance: Dictionary = {}
var _elapsed := 0.0
var _controller: MatchController
var _bot: AndroidQaCommandSource
var _last_lan_tick := -1
var _last_screen := ""
var _state: Dictionary = {}

static func valid_identifier(value: String) -> bool:
	if value.is_empty() or value.length() > 64: return false
	for index: int in value.length():
		var c := value.unicode_at(index)
		if not (c >= 65 and c <= 90 or c >= 97 and c <= 122 or c >= 48 and c <= 57 or c == 45 or c == 95): return false
	return true

func configure(owner: Node, arguments: PackedStringArray, debug_build: bool) -> bool:
	if not debug_build or not OS.is_debug_build(): return false
	var found := 0
	for argument: String in arguments:
		if argument.begins_with("--qa-run="):
			run_id = argument.trim_prefix("--qa-run=")
			found += 1
		elif argument.begins_with("--qa-device="): device_alias = argument.trim_prefix("--qa-device=")
	if found != 1 or not valid_identifier(run_id) or not valid_identifier(device_alias): return false
	app = owner
	directory = "user://qa/" + run_id
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return false
	app.save_path = directory + "/local_player.json"
	app.db_session_path = directory + "/db_profile_session.json"
	app.demo_guest_session_path = directory + "/demo_guest_session.json"
	# Ignore demo features only in explicitly selected QA runs, retain normal LAN auth.
	app.demo_mode = false
	var prior: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory + "/state.json")) if FileAccess.file_exists(directory + "/state.json") else {}
	if prior is Dictionary and prior.get("run_id") == run_id:
		command_seq = int(prior.get("command_seq", 0))
		match_generation = int(prior.get("match_generation", 0))
	boot_id = str(OS.get_process_id()) + "-" + Crypto.new().generate_random_bytes(8).hex_encode()
	active = true
	return true

func _ready() -> void:
	if not active: set_process(false); return
	app.lan_client.set_meta("qa_active", true)
	app.lan_client.snapshot_received.connect(_lan_snapshot)
	app.lan_client.match_finished.connect(_lan_result)
	app.lan_client.peer_status_changed.connect(func(_slot: int, connected: bool) -> void: peer_connected = connected)
	app.lan_client.failed.connect(func(code: String) -> void: last_lan_error = code)
	app.lan_client.match_started.connect(func(_slot: int) -> void:
		_last_lan_tick = -1
		latest_result = {}
		last_lan_error = "")
	_publish()

func _process(delta: float) -> void:
	if not active: return
	_observe_match()
	_elapsed += delta
	if _elapsed < 0.25: return
	_elapsed = 0.0
	_read_command()
	_publish()

func _observe_match() -> void:
	var current := app.match_controller as MatchController
	if not is_instance_valid(current):
		_controller = null
		_bot = null
		return
	if current == _controller: return
	_controller = current
	match_generation += 1
	latest_result = {}
	last_lan_error = ""
	_bot = null
	current.snapshot_changed.connect(_snapshot_changed)
	current.presentation_event.connect(_combat_event)
	current.match_ended.connect(_local_result.bind(current))
	var touch: Node = app.match_scene.get_node("Interface/TouchCommandSource")
	touch.diagnostic_event.connect(_touch_event)
	var probe: Node
	for child: Node in app.match_scene.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/local_performance_probe.gd": probe = child
	if probe == null:
		probe = load("res://scripts/local_performance_probe.gd").new()
		probe.name = "AndroidQaPerformance"
		app.match_scene.add_child(probe)
	probe.sampled.connect(func(value: Dictionary) -> void:
		performance = value.duplicate(true)
		performance.msec = Time.get_ticks_msec()
		performance.generation = match_generation)
	_fighter_signatures.clear()
	snapshot = current.snapshot().duplicate(true)
	_enrich_snapshot()
	_capture_states()
	reset_snapshot = _json_value(snapshot)
	_apply_autoplay()

func _snapshot_changed(value: Dictionary) -> void:
	if app.screen == "lan_match": return
	snapshot = value.duplicate(true)
	_enrich_snapshot()
	_capture_states()

func _capture_states() -> void:
	for fighter: Dictionary in snapshot.get("fighters", []):
		var id := String(fighter.get("id", ""))
		var signature := "%s:%s:%s:%s" % [fighter.get("state", ""), fighter.get("attack_id", ""), fighter.get("stocks", 0), fighter.get("ultimate_used_this_stock", false)]
		if _fighter_signatures.get(id, "") == signature: continue
		_fighter_signatures[id] = signature
		event_seq += 1
		combat_events.append({"seq": event_seq, "id": "fighter_state", "fighter_id": id, "tick": int(snapshot.get("tick", 0)), "state": fighter.get("state", ""), "attack_id": String(fighter.get("attack_id", "")), "ultimate_gauge": fighter.get("ultimate_gauge", 0.0), "ultimate_used_this_stock": fighter.get("ultimate_used_this_stock", false)})
		if combat_events.size() > 128: combat_events.pop_front()

func _enrich_snapshot() -> void:
	if not is_instance_valid(_controller): return
	for value: Dictionary in snapshot.get("fighters", []):
		var fighter := _controller.call("_fighter_by_id", StringName(value.get("id", ""))) as FighterController
		if fighter == null or fighter.runtime_profile == null: continue
		value.character_id = String(fighter.runtime_profile.character_id)
		value.accessory_id = String(fighter.runtime_profile.accessory_id)
		value.input_direction = int(fighter.input_direction)
		value.buffered_action = "" if fighter.buffered_intent == null else String(fighter.buffered_intent.action_id)

func _lan_snapshot(value: Dictionary) -> void:
	snapshot = value.duplicate(true)
	_enrich_snapshot()
	_capture_states()
	var tick := int(value.get("tick", 0))
	if not autoplay or not foreground or _bot == null or tick <= _last_lan_tick or app.lan_client.qa_interrupted(): return
	_last_lan_tick = tick
	var input_snapshot := _vector_snapshot(value)
	for intent: CombatIntent in _bot.commands_for_tick(tick + 1, input_snapshot):
		app.lan_client.submit_qa_intent(intent)

func _vector_snapshot(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	for fighter: Dictionary in result.get("fighters", []):
		for key: String in ["position", "velocity"]:
			var vector: Variant = fighter.get(key, {})
			if vector is Dictionary: fighter[key] = Vector2(float(vector.get("x", 0.0)), float(vector.get("y", 0.0)))
	return result

func _local_result(winner: StringName, source: MatchController) -> void:
	if source != _controller or app.screen.begins_with("lan_"): return
	latest_result = {"winner_id": String(winner), "winner_team_id": String(source.winner_team_id), "final_tick": source.tick, "snapshot_hash": source.snapshot_hash(), "reason": "draw" if source.is_draw else "combat", "generation": match_generation}

func _lan_result(value: Dictionary) -> void:
	latest_result = {}
	for key: String in ["winner_slot", "final_tick", "snapshot_hash", "reason"]:
		if value.has(key): latest_result[key] = value[key]
	latest_result.generation = match_generation
	_release_bot()

func _combat_event(id: StringName, payload: Dictionary) -> void:
	event_seq += 1
	combat_events.append({"seq": event_seq, "id": String(id), "tick": int(snapshot.get("tick", 0)), "payload": _json_value(payload)})
	if combat_events.size() > 128: combat_events.pop_front()

func _touch_event(action: StringName, edge: String) -> void:
	touch_count += 1
	event_seq += 1
	touch_events.append({"seq": event_seq, "action": String(action), "edge": edge})
	if touch_events.size() > 128: touch_events.pop_front()

func _release_bot() -> void:
	if is_instance_valid(_controller) and _bot != null:
		_controller.bot_sources.erase(_bot)
		_controller.release_fighter_input(_bot.fighter_id)
	if _bot != null: _bot.reset()
	if is_instance_valid(app.lan_client):
		if app.lan_client.qa_autoplay: app.lan_client._release_inputs()
		app.lan_client.qa_autoplay = false
	_bot = null

func _apply_autoplay() -> void:
	_release_bot()
	if not autoplay or not foreground or not is_instance_valid(_controller): return
	if app.screen not in ["match", "lan_match"]: return
	var fighter_id: StringName = &"player"
	if app.screen == "lan_match": fighter_id = &"lan_host" if app.lan_local_slot == 1 else &"lan_guest"
	var team := StringName(_controller.team_by_fighter_id.get(fighter_id, &""))
	_bot = AndroidQaCommandSource.new(fighter_id, 7919 + match_generation, {"team_id": team, "stage_data": _controller.stage_data})
	_bot.allow_ultimate = allow_ultimate
	if app.screen == "lan_match": app.lan_client.qa_autoplay = true
	else: _controller.bot_sources.append(_bot)

func _notification(what: int) -> void:
	if not active: return
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		foreground = false
		input_reset_count += 1
		_release_bot()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		foreground = true
		_apply_autoplay()

func _read_command() -> void:
	var path := directory + "/command.json"
	if not FileAccess.file_exists(path): return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("run_id") != run_id or value.get("schema_version") != VERSION: return
	var seq_value: Variant = value.get("seq", 0)
	if not (seq_value is int or seq_value is float) or float(seq_value) != floor(float(seq_value)) or int(seq_value) <= command_seq: return
	# Consume before acting so a crash cannot replay an unacknowledged command.
	DirAccess.remove_absolute(path)
	command_seq = int(seq_value)
	command_error = ""
	case_id = String(value.get("case_id", case_id))
	var args: Variant = value.get("args", {})
	if not args is Dictionary:
		command_error = "invalid_arguments"
		return
	step = String(value.get("op", ""))
	match step:
		"context", "observe": pass
		"autoplay":
			autoplay = bool(args.get("enabled", false))
			allow_ultimate = bool(args.get("ultimate", true))
			if is_instance_valid(app.match_scene):
				app.match_scene.get_node("Interface/TouchCommandSource").release_all_touches()
				app.match_scene._release_semantic_actions()
			_apply_autoplay()
		"set_text":
			var control := _find_ui(String(args.get("id", ""))) as LineEdit
			if control == null: command_error = "input_not_found"
			else:
				control.text = String(args.get("value", ""))
				control.text_changed.emit(control.text)
		"choose":
			var control := _find_ui(String(args.get("id", ""))) as OptionButton
			var index := int(args.get("index", -1))
			if control == null or index < 0 or index >= control.item_count: command_error = "choice_not_found"
			else:
				control.select(index)
				control.item_selected.emit(index)
		"select_config": _select_config(args)
		"interrupt":
			var seconds := int(args.get("seconds", 0))
			if app.screen != "lan_match" or seconds not in [10, 65]: command_error = "invalid_interrupt"
			else:
				_release_bot()
				input_reset_count += 1
				app.lan_client.interrupt_qa_connection(seconds)
		_: command_error = "unknown_operation"

func _select_config(args: Dictionary) -> void:
	if app.screen != "prepare":
		command_error = "not_preparing"
		return
	var mode := int(args.get("mode", app.selected_mode))
	var solo := int(args.get("solo_count", app.solo_participant_count))
	var team := int(args.get("team_size", app.team_size))
	if mode < 0 or mode > 4 or solo not in [2, 4, 6, 8] or team < 1 or team > 4:
		command_error = "invalid_config"
		return
	var ok: bool = app.store.select(String(args.get("character", app.store.data.selected_character)), String(args.get("accessory", app.store.data.selected_accessory)), String(args.get("opponent", app.store.data.opponent_character)))
	if not ok:
		command_error = "selection_failed"
		return
	app.selected_mode = mode
	app.solo_participant_count = solo
	app.team_size = team
	app._show_prepare()

func _find_ui(id: String) -> Control:
	for control: Control in _controls(app.page):
		if String(control.get_meta("qa_id", "")) == id or control.name == id: return control
	return null

func _controls(node: Node) -> Array[Control]:
	var result: Array[Control] = []
	if not is_instance_valid(node): return result
	for child: Node in node.get_children():
		if child is Control: result.append(child)
		result.append_array(_controls(child))
	return result

func _ui() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for control: Control in _controls(app.page):
		if not control.is_visible_in_tree(): continue
		var kind := ""
		var text := ""
		if control is OptionButton: kind = "choice"; text = control.text
		elif control is LineEdit: kind = "input"; text = control.text
		elif control is Button: kind = "button"; text = control.text
		else: continue
		if control is BaseButton and control.disabled: continue
		var item := _geometry(control, String(control.get_meta("qa_id", "")), kind, text)
		item.node_name = String(control.name)
		if control is OptionButton:
			item.selected = control.selected
			item.options = []
			var ids: Array = control.get_meta("qa_values", [])
			for index: int in control.item_count:
				item.options.append({"id": String(ids[index]) if index < ids.size() else str(index), "text": control.get_item_text(index)})
		result.append(item)
	if is_instance_valid(app.match_scene) and app.screen in ["match", "lan_match"]:
		var touch: Control = app.match_scene.get_node("Interface/TouchCommandSource")
		var pad: Control = touch._dpad_visual
		for action: String in ["move_left", "move_right", "move_up", "move_down"]:
			var center := pad.get_global_rect().get_center()
			var offset := {"move_left": Vector2(-0.3, 0), "move_right": Vector2(0.3, 0), "move_up": Vector2(0, -0.3), "move_down": Vector2(0, 0.3)}
			center += offset[action] * pad.size
			var size := get_viewport().get_visible_rect().size
			result.append({"id": "touch/" + action, "kind": "touch", "text": action, "x": center.x / size.x, "y": center.y / size.y, "width": 0.02, "height": 0.02})
		for action: StringName in touch.ACTIONS:
			result.append(_geometry(touch._action_visuals[action], "touch/" + String(action), "touch", String(action)))
	return result

func _geometry(control: Control, id: String, kind: String, text: String) -> Dictionary:
	var rect := control.get_global_rect()
	var size := control.get_viewport_rect().size
	return {"id": id, "kind": kind, "text": text, "x": rect.get_center().x / size.x, "y": rect.get_center().y / size.y, "width": rect.size.x / size.x, "height": rect.size.y / size.y, "visible": _center_visible(control)}

func _center_visible(control: Control) -> bool:
	var center := control.get_global_rect().get_center()
	if not control.get_viewport_rect().has_point(center): return false
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer and not parent.get_global_rect().has_point(center): return false
		parent = parent.get_parent()
	return true

func _json_value(value: Variant) -> Variant:
	if value is Vector2: return {"x": value.x, "y": value.y}
	if value is Dictionary:
		var result := {}
		for key: Variant in value: result[String(key)] = _json_value(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_json_value(item))
		return result
	if value is StringName: return String(value)
	return value

func _publish() -> void:
	if not active or not is_instance_valid(app.store): return
	var size := get_viewport().get_visible_rect().size
	if is_instance_valid(_controller) and not String(app.screen).begins_with("lan_"):
		_snapshot_changed(_controller.snapshot())
	var held: Array[String] = []
	if is_instance_valid(app.match_scene):
		var touch: Node = app.match_scene.get_node("Interface/TouchCommandSource")
		for action: StringName in touch._action_touch_counts:
			if int(touch._action_touch_counts[action]) > 0: held.append(String(action))
	if _last_screen != app.screen:
		_last_screen = app.screen
		if app.screen not in ["match", "lan_match"]: _release_bot()
		elif autoplay and foreground: _apply_autoplay()
	if autoplay and foreground and app.screen == "lan_match" and not app.lan_client.qa_interrupted() and _bot == null: _apply_autoplay()
	_state = {
		"schema_version": VERSION, "run_id": run_id, "boot_id": boot_id,
		"device": device_alias, "case_id": case_id, "step": step,
		"command_seq": command_seq, "command_error": command_error,
		"msec": Time.get_ticks_msec(), "screen": app.screen,
		"viewport": {"width": size.x, "height": size.y}, "ui": _ui(),
		"profile": app.store.data.duplicate(true), "snapshot": _json_value(snapshot),
		"latest_result": latest_result, "last_lan_error": last_lan_error,
		"lan_invite": app.lan_current_invite, "lan_slot": app.lan_local_slot,
		"autocontrol": autoplay, "foreground": foreground,
		"input_reset_count": input_reset_count, "touch_events": touch_events,
		"combat_events": combat_events, "match_generation": match_generation,
		"performance": performance, "interrupt_active": app.lan_client.qa_interrupted(),
		"connected": app.lan_client.websocket.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED,
		"peer_connected": peer_connected, "reconnecting": app.lan_client._reconnecting,
		"reset_snapshot": reset_snapshot,
		"config": {"mode": app.selected_mode, "solo_count": app.solo_participant_count,
			"team_size": app.team_size, "character": app.store.data.selected_character,
			"accessory": app.store.data.selected_accessory, "opponent": app.store.data.opponent_character},
		"touch": {"active": held, "count": touch_count, "events": touch_events, "observations": combat_events},
		"qa_storage_path": ProjectSettings.globalize_path(directory)
	}
	var file := FileAccess.open(directory + "/state.json.tmp", FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(_state))
	file.close()
	DirAccess.rename_absolute(directory + "/state.json.tmp", directory + "/state.json")
