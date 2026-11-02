extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var host := LanInvite.host_code("ws://192.168.45.10:7777", "http://192.168.45.10:8080")
	_check(host == "FAH5|http://192.168.45.10:8080|ws://192.168.45.10:7777|5", "host code", failures)
	_check(LanInvite.parse_host_code(host).websocket_url == "ws://192.168.45.10:7777", "host parse", failures)
	var invite := LanInvite.invite_code("ws://10.0.0.9:7777", "A1B2C3D4", "http://10.0.0.9:8080")
	var parsed := LanInvite.parse_invite_code(invite)
	_check(parsed.get("room_code") == "A1B2C3D4", "invite parse", failures)
	_check(LanInvite.parse_invite_code("FA5|http://8.8.8.8:8080|ws://8.8.8.8:7777|A1B2C3D4|5").error == "invalid_private_endpoint", "public address rejected", failures)
	_check(LanInvite.parse_invite_code("FA5|http://192.168.0.2:8080|ws://192.168.0.2:7777|SHORT|5").error == "invalid_room_code", "short room code rejected", failures)
	_check(LanInvite.parse_invite_code("FA5|http://192.168.0.2:8080|ws://192.168.0.2:7777|A1B2C3D4|6").error == "invalid_invite_code", "future version rejected", failures)
	_check(LanInvite.parse_host_code("FAH1|ws://127.0.0.1:7777|1").error == "unsupported_protocol", "old APK update required", failures)
	_check(LanInvite.parse_host_code("FAH3|http://127.0.0.1:3001|ws://127.0.0.1:7778|3").error == "unsupported_protocol", "LAN3 host update required", failures)
	_check(LanInvite.parse_invite_code("FA3|http://127.0.0.1:3001|ws://127.0.0.1:7778|A1B2C3D4|3").error == "unsupported_protocol", "LAN3 invitation update required", failures)
	for old_version: int in [1, 2, 3, 4]:
		_check(LanInvite.parse_host_code("FAH%d|http://127.0.0.1:3001|ws://127.0.0.1:7778|%d" % [old_version, old_version]).error == "unsupported_protocol", "legacy host rejected %d" % old_version, failures)
		_check(LanInvite.parse_invite_code("FA%d|http://127.0.0.1:3001|ws://127.0.0.1:7778|A1B2C3D4|%d" % [old_version, old_version]).error == "unsupported_protocol", "legacy invite rejected %d" % old_version, failures)
	_check(LanInvite.host_code("ws://10.0.0.1:7777", "http://10.0.0.2:8080").is_empty(), "same server host required", failures)
	_check(LanInvite.address_in_cidr("192.168.1.20", "192.168.1.0/24") and not LanInvite.address_in_cidr("192.168.2.20", "192.168.1.0/24"), "source CIDR boundary", failures)
	var catalog := LocalPlayCatalog.new().combat
	for character: CharacterData in catalog.characters:
		for accessory_id: StringName in _accessory_ids(catalog):
			var selection := LoadoutSelection.new()
			selection.character_id = character.character_id
			selection.accessory_id = accessory_id
			_check(LoadoutBuilder.build(selection, catalog).succeeded(), "LAN loadout %s/%s" % [character.character_id, accessory_id], failures)
	var client := LanMatchClient.new()
	client.call("_handle_message", JSON.stringify({"type": "room_ready", "protocol_version": 5, "loadouts": {}}))
	_check(client.participant_names == {"1": "참가자 1", "2": "참가자 2"}, "old server names default", failures)
	_check(client.call("_valid_nickname", "  숲지기  ") == "숲지기", "LAN nickname trims", failures)
	for invalid_name: String in ["a\nb", "a\u2028b", "a\u2029b", "", "  ", "1234567890123"]:
		_check(client.call("_valid_nickname", invalid_name) == "", "invalid LAN name", failures)
	var observed_error := []
	client.failed.connect(func(code: String) -> void: observed_error.append(code))
	client.active = true
	client.set("_request_deadline_msec", Time.get_ticks_msec() - 1)
	Input.action_press(&"move_right")
	client.call("_process", 0.0)
	_check(observed_error == ["request_timeout"] and not client.active and not Input.is_action_pressed(&"move_right"), "request timeout releases input", failures)
	observed_error.clear()
	var received_snapshots := []
	client.snapshot_received.connect(func(value: Dictionary) -> void: received_snapshots.append(value))
	client.call("_handle_message", JSON.stringify({"type": "snapshot", "protocol_version": 3, "state": {}}))
	_check(observed_error == ["unsupported_protocol"] and received_snapshots.is_empty(), "LAN3 server snapshot is rejected before delivery", failures)
	observed_error.clear()
	var equipment_snapshot := {"fighters": [{"id": "lan_host", "equipment_cooldown_ticks": 543, "equipment_phase": "return", "equipment_tick": 26, "equipment_phase_tick": 2, "equipment_facing": -1, "equipment_position": {"x": 10, "y": -32}, "equipment_activation_serial": 2, "equipment_airborne": true}]}
	client.call("_handle_message", JSON.stringify({"type": "snapshot", "protocol_version": 5, "state": equipment_snapshot}))
	# JSON numbers become floats on receipt; compare to the actual wire-normalized shape.
	var wire_snapshot: Dictionary = JSON.parse_string(JSON.stringify(equipment_snapshot))
	_check(observed_error.is_empty() and received_snapshots.size() == 1 and received_snapshots[0] == wire_snapshot, "LAN5 equipment state is delivered unchanged", failures)
	_check(&"use_equipment" in LanMatchClient.ACTIONS, "equipment action offered by LAN client", failures)
	client.set("_seq", 0)
	client.call("_send_input", &"use_equipment", CombatIntent.Direction.RIGHT, CombatIntent.Edge.HOLD)
	_check(client.get("_seq") == 0, "equipment hold not sent", failures)
	client.call("_send_input", &"use_equipment", CombatIntent.Direction.RIGHT, CombatIntent.Edge.PRESS)
	_check(client.get("_seq") == 1, "equipment press sent once", failures)
	var server: Variant = load("res://server/game/lan_game_server.gd").new()
	server.catalog = catalog
	var allowed := {"schema_version": 1, "character_id": "nabi", "job_id": "", "accessory_id": "pebble-yoyo"}
	_check(server.call("_selection_from", allowed) != null, "server permits yo-yo loadout", failures)
	for inactive: String in ["fixture-thorns", "missing", "fixture-boxing-gloves"]:
		var rejected := allowed.duplicate()
		rejected.accessory_id = inactive
		_check(server.call("_selection_from", rejected) == null, "server rejects inactive accessory " + inactive, failures)
	server.free()
	client.free()
	if failures.is_empty():
		print("LAN_CONTRACT: PASS")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)


func _accessory_ids(catalog: LoadoutCatalog) -> Array[StringName]:
	var ids: Array[StringName] = [&""]
	for accessory: AccessoryData in catalog.accessories: ids.append(accessory.accessory_id)
	return ids


func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition: failures.append(label)
