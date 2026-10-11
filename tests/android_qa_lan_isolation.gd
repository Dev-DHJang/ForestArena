extends Node
## Four authenticated protocol clients; this is not a physical-device test.
const TIMEOUT_MSEC := 5000
var clients: Array[Dictionary] = []
var failed := false
func _ready() -> void:
	_run()
func _process(_delta: float) -> void:
	for client: Dictionary in clients:
		var peer: WebSocketMultiplayerPeer = client.peer
		peer.poll()
		while peer.get_available_packet_count() > 0:
			var value: Variant = JSON.parse_string(peer.get_packet().get_string_from_utf8())
			if value is Dictionary: client.queue.append(value)
func _run() -> void:
	var hosts: Array[Dictionary] = []
	var guests: Array[Dictionary] = []
	for pair: int in 2:
		var prefix := "FOREST_ARENA_QA_ISOLATION_" + str(pair) + "_"
		var url := OS.get_environment(prefix + "WS")
		var host := await _open(url)
		_send(host, {"type": "create_room", "access_token": OS.get_environment(prefix + "HOST"), "selection": _selection("ja-hyun")})
		var created := await _message(host, "room_created")
		if failed: return
		var guest := await _open(url)
		_send(guest, {"type": "join_room", "access_token": OS.get_environment(prefix + "GUEST"), "room_code": created.room_code, "selection": _selection("yu-ran")})
		await _message(host, "match_start")
		await _message(guest, "match_start")
		hosts.append(host)
		guests.append(guest)
	await get_tree().create_timer(1.0).timeout
	for host: Dictionary in hosts:
		host.queue = host.queue.filter(func(value: Dictionary) -> bool: return value.type != "snapshot")
	var first := await _message(hosts[0], "snapshot")
	var second := await _message(hosts[1], "snapshot")
	if failed: return
	var first_x := float(first.state.fighters[0].position.x)
	var second_x := float(second.state.fighters[0].position.x)
	_send(hosts[0], {"type": "input", "seq": 1, "action_id": "move", "direction": CombatIntent.Direction.RIGHT, "edge": CombatIntent.Edge.PRESS})
	await get_tree().create_timer(0.4).timeout
	var moved := await _snapshot_after(hosts[0], int(first.state.tick) + 15)
	var untouched := await _snapshot_after(hosts[1], int(second.state.tick) + 15)
	if failed: return
	_check(float(moved.state.fighters[0].position.x) > first_x + 20, "pair A input moves its host")
	_check(absf(float(untouched.state.fighters[0].position.x) - second_x) < 0.01, "pair A input does not cross to pair B")
	_send(hosts[0], {"type": "input", "seq": 2, "action_id": "move", "direction": CombatIntent.Direction.NEUTRAL, "edge": CombatIntent.Edge.RELEASE})
	_send(guests[0], {"type": "leave"})
	var ended := await _message(hosts[0], "match_end")
	if failed: return
	_check(ended.reason == "disconnect" and int(ended.winner_slot) == 1, "pair A ends independently")
	# Host runner terminates server A when it sees this marker.
	print("ANDROID_QA_ISOLATION_STOP_A")
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while hosts[0].peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(hosts[0].peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED, "server A was stopped")
	var continued := await _snapshot_after(hosts[1], int(untouched.state.tick) + 20)
	if failed: return
	_check(int(continued.state.tick) > int(untouched.state.tick) and not hosts[1].queue.any(func(value: Dictionary) -> bool: return value.type == "match_end"), "server B keeps its match after server A stops")
	_check(hosts[1].peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and guests[1].peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "both pair B clients remain connected")
	_send(guests[1], {"type": "leave"})
	var second_end := await _message(hosts[1], "match_end")
	if failed: return
	_check(second_end.reason == "disconnect" and int(second_end.winner_slot) == 1, "server B returns its own result")
	for client: Dictionary in clients: client.peer.close()
	if not failed:
		print("ANDROID_QA_LAN_ISOLATION: PASS (loopback fixture; no physical-device claim)")
		get_tree().quit(0)
func _selection(character: String) -> Dictionary:
	return {"schema_version": 1, "character_id": character, "job_id": "", "accessory_id": ""}
func _open(url: String) -> Dictionary:
	var client := {"peer": WebSocketMultiplayerPeer.new(), "queue": []}
	clients.append(client)
	_check(client.peer.create_client(url) == OK, "connection starts")
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while client.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	_check(client.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "connection opens")
	return client
func _send(client: Dictionary, value: Dictionary) -> void:
	value.protocol_version = 2
	_check(client.peer.put_packet(JSON.stringify(value).to_utf8_buffer()) == OK, "normal LAN v2 message sends")
func _message(client: Dictionary, kind: String) -> Dictionary:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		for index: int in client.queue.size():
			var value: Dictionary = client.queue[index]
			if value.type == "error":
				_check(false, "unexpected protocol error: " + String(value.get("code", "")))
				return {}
			if value.type == kind:
				client.queue.remove_at(index)
				return value
		await get_tree().process_frame
	_check(false, "timeout for " + kind)
	return {}
func _snapshot_after(client: Dictionary, tick: int) -> Dictionary:
	for _index: int in 100:
		var value := await _message(client, "snapshot")
		if failed: return {}
		if int(value.state.tick) > tick: return value
	_check(false, "snapshot did not advance")
	return {}
func _check(value: bool, label: String) -> void:
	if value or failed: return
	failed = true
	push_error("ANDROID_QA_LAN_ISOLATION: FAIL " + label)
	get_tree().quit(1)
