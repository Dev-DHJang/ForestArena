extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var host := LanInvite.host_code("ws://192.168.45.10:7777", "http://192.168.45.10:8080")
	_check(host == "FAH2|http://192.168.45.10:8080|ws://192.168.45.10:7777|2", "host code", failures)
	_check(LanInvite.parse_host_code(host).websocket_url == "ws://192.168.45.10:7777", "host parse", failures)
	var invite := LanInvite.invite_code("ws://10.0.0.9:7777", "A1B2C3D4", "http://10.0.0.9:8080")
	var parsed := LanInvite.parse_invite_code(invite)
	_check(parsed.get("room_code") == "A1B2C3D4", "invite parse", failures)
	_check(LanInvite.parse_invite_code("FA2|http://8.8.8.8:8080|ws://8.8.8.8:7777|A1B2C3D4|2").error == "invalid_private_endpoint", "public address rejected", failures)
	_check(LanInvite.parse_invite_code("FA2|http://192.168.0.2:8080|ws://192.168.0.2:7777|SHORT|2").error == "invalid_room_code", "short room code rejected", failures)
	_check(LanInvite.parse_invite_code("FA2|http://192.168.0.2:8080|ws://192.168.0.2:7777|A1B2C3D4|3").error == "invalid_invite_code", "future version rejected", failures)
	_check(LanInvite.parse_host_code("FAH1|ws://127.0.0.1:7777|1").error == "unsupported_protocol", "old APK update required", failures)
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
	client.call("_handle_message", JSON.stringify({"type": "room_ready", "protocol_version": 2, "loadouts": {}}))
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
