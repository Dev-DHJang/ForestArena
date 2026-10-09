extends Node

const TIMEOUT_MSEC := 5000
const PROTOCOL_VERSION := 2

var websocket_url := "ws://127.0.0.1:17777"
var clients: Array[Dictionary] = []
var failed := false


func _ready() -> void:
	var configured := OS.get_environment("FOREST_ARENA_LAN_TEST_WS_URL")
	if not configured.is_empty(): websocket_url = configured
	_run()


func _process(_delta: float) -> void:
	for client: Dictionary in clients:
		var client_peer: WebSocketMultiplayerPeer = client.peer
		client_peer.poll()
		while client_peer.get_available_packet_count() > 0:
			var parsed: Variant = JSON.parse_string(client_peer.get_packet().get_string_from_utf8())
			if parsed is Dictionary: client.queue.append(parsed)


func _run() -> void:
	var wrong_version := await _open_client()
	_send_raw(wrong_version, {"type": "create_room", "protocol_version": 99, "selection": _selection("nabi", "")})
	_require((await _wait_message(wrong_version, "error")).code == "unsupported_protocol", "version_rejected")
	_close_client(wrong_version)
	for token: String in ["", "invalid", "expired", "unnamed"]:
		var unauth := await _open_client()
		_send(unauth, {"type": "create_room", "access_token": token, "selection": _selection("nabi", "")})
		var expected := "authentication_required" if token.is_empty() else ("nickname_required" if token == "unnamed" else "authentication_failed")
		_require((await _wait_message(unauth, "error")).code == expected, "invalid_auth_" + token)
		_close_client(unauth)
	var invalid_loadout := await _open_client()
	_send(invalid_loadout, {"type": "create_room", "access_token": "host", "selection": _selection("missing-character", "")})
	var loadout_error := await _wait_message(invalid_loadout, "error")
	_require(loadout_error.code == "invalid_loadout", "invalid_loadout_rejected:" + str(loadout_error))
	_close_client(invalid_loadout)
	var oversized := await _open_client()
	var oversized_peer: WebSocketMultiplayerPeer = oversized.peer
	_require(oversized_peer.put_packet("x".repeat(8193).to_utf8_buffer()) == OK, "oversized_send")
	_require((await _wait_message(oversized, "error")).code == "message_too_large", "oversized_rejected")
	_close_client(oversized)
	# A cancelled asynchronous authentication must not create an orphan room.
	var cancelled := await _open_client()
	_send(cancelled, {"type": "create_room", "access_token": "slow-host", "selection": _selection("nabi", "")})
	await get_tree().create_timer(0.1).timeout
	_close_client(cancelled)
	await get_tree().create_timer(0.4).timeout
	var host := await _open_client()
	_send(host, {"type": "create_room", "access_token": "host", "nickname": "공격자위조", "selection": _selection("nabi", "fixture-iron-armor")})
	var created := await _wait_message(host, "room_created")
	_require(LanInvite.parse_invite_code(String(created.invite_code)).room_code == created.room_code, "invite")
	await _wait_message(host, "room_waiting")
	var duplicate := await _open_client()
	_send(duplicate, {"type": "join_room", "access_token": "host", "room_code": created.room_code, "selection": _selection("yu-ran", "")})
	_require((await _wait_message(duplicate, "error")).code == "duplicate_guest", "same_guest_rejected")
	_close_client(duplicate)
	var guest := await _open_client()
	_send(guest, {"type": "join_room", "access_token": "guest", "nickname": "공격자위조", "room_code": created.room_code, "selection": _selection("yu-ran", "fixture-boxing-gloves")})
	var guest_joined := await _wait_message(guest, "joined")
	var host_ready := await _wait_message(host, "room_ready")
	var guest_ready := await _wait_message(guest, "room_ready")
	_require(host_ready.get("names") == {"1": "호스트숲", "2": "손님숲"} and guest_ready.get("names") == host_ready.get("names"), "both clients get normalized nicknames")
	_require(host_ready.loadouts["1"].character_id == "nabi" and guest_ready.loadouts["2"].character_id == "yu-ran", "loadouts")
	var host_start := await _wait_message(host, "match_start")
	await _wait_message(guest, "match_start")
	var snapshot := await _wait_message(host, "snapshot")
	_require(snapshot.state.fighters.size() == 2 and snapshot.state.fighters[0].id == "lan_host", "snapshot")
	_send(host, {"type": "input", "seq": 1, "action_id": "move", "direction": CombatIntent.Direction.RIGHT, "edge": CombatIntent.Edge.PRESS})
	_send(host, {"type": "input", "seq": 1, "action_id": "move", "direction": CombatIntent.Direction.LEFT, "edge": CombatIntent.Edge.PRESS})
	_send(host, {"type": "input", "seq": 2, "action_id": "not_an_action", "direction": CombatIntent.Direction.NEUTRAL, "edge": CombatIntent.Edge.PRESS})
	_require((await _wait_message(host, "error")).code == "invalid_input", "invalid_input_rejected")
	var advanced := await _wait_snapshot_after(host, int(snapshot.state.tick))
	_require(int(advanced.state.tick) > int(snapshot.state.tick), "input_tick")
	var third := await _open_client()
	_send(third, {"type": "join_room", "room_code": created.room_code, "access_token": "third", "selection": _selection("ja-hyun", "")})
	_require((await _wait_message(third, "error")).code == "room_full", "third_rejected")
	_close_client(third)
	_close_client(host)
	var peer_down := await _wait_message(guest, "peer_status")
	_require(peer_down.slot == 1 and not peer_down.connected, "disconnect_status")
	var stolen := await _open_client()
	_send(stolen, {"type": "resume", "access_token": "third", "reconnect_token": host_start.reconnect_token})
	_require((await _wait_message(stolen, "error")).code == "resume_rejected", "other_guest_resume_rejected")
	_close_client(stolen)
	var resumed := await _open_client()
	_send(resumed, {"type": "resume", "access_token": "host", "reconnect_token": host_start.reconnect_token})
	var resumed_joined := await _wait_message(resumed, "joined")
	_require(bool(resumed_joined.resumed) and resumed_joined.slot == 1, "resume")
	_require(resumed_joined.get("names") == host_ready.get("names"), "resume preserves names")
	await _wait_message(resumed, "snapshot")
	_send(guest, {"type": "leave"})
	var host_end := await _wait_message(resumed, "match_end")
	await _wait_message(guest, "match_end")
	_require(host_end.reason == "disconnect" and host_end.winner_slot == 1, "leave_forfeit")
	_send(resumed, {"type": "rematch", "ready": true})
	_send(guest, {"type": "rematch", "ready": true})
	await _wait_message(resumed, "rematch_state")
	await _wait_message(guest, "rematch_state")
	var rematch_ready := await _wait_message(resumed, "room_ready")
	_require(rematch_ready.get("names") == host_ready.get("names"), "rematch preserves names")
	await _wait_message(guest, "room_ready")
	await _wait_message(resumed, "match_start")
	await _wait_message(guest, "match_start")
	_send(guest, {"type": "leave"})
	await _wait_message(resumed, "match_end")
	await _wait_message(guest, "match_end")
	_send(resumed, {"type": "rematch", "ready": false})
	var closed := await _wait_closed_rematch(resumed)
	_require(bool(closed.closed), "room_close")
	_close_client(resumed)
	_close_client(guest)
	if failed: return
	print("LAN_RUNTIME: PASS")
	get_tree().quit(0)


func _selection(character_id: String, accessory_id: String) -> Dictionary:
	return {"schema_version": 1, "character_id": character_id, "job_id": "", "accessory_id": accessory_id}


func _open_client() -> Dictionary:
	var client := {"peer": WebSocketMultiplayerPeer.new(), "queue": []}
	clients.append(client)
	var client_peer: WebSocketMultiplayerPeer = client.peer
	_require(client_peer.create_client(websocket_url) == OK, "websocket_create")
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_require(client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "websocket_connect")
	return client


func _send(client: Dictionary, message: Dictionary) -> void:
	message.protocol_version = PROTOCOL_VERSION
	_send_raw(client, message)


func _send_raw(client: Dictionary, message: Dictionary) -> void:
	var client_peer: WebSocketMultiplayerPeer = client.peer
	_require(client_peer.put_packet(JSON.stringify(message).to_utf8_buffer()) == OK, "websocket_send")


func _wait_message(client: Dictionary, type: String, timeout_msec := TIMEOUT_MSEC) -> Dictionary:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < deadline:
		var queue: Array = client.queue
		for index: int in queue.size():
			if String(queue[index].get("type", "")) == type: return queue.pop_at(index)
		await get_tree().process_frame
	_require(false, "message_timeout_%s" % type)
	return {}


func _wait_snapshot_after(client: Dictionary, tick: int) -> Dictionary:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		var queue: Array = client.queue
		for index: int in queue.size():
			var message: Dictionary = queue[index]
			if message.get("type") == "snapshot" and int(message.state.tick) > tick: return queue.pop_at(index)
		await get_tree().process_frame
	_require(false, "snapshot_advance")
	return {}


func _wait_closed_rematch(client: Dictionary) -> Dictionary:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		var queue: Array = client.queue
		for index: int in range(queue.size() - 1, -1, -1):
			var message: Dictionary = queue[index]
			if message.get("type") == "rematch_state" and bool(message.get("closed", false)): return queue.pop_at(index)
		await get_tree().process_frame
	_require(false, "rematch_close_timeout")
	return {}


func _close_client(client: Dictionary) -> void:
	var client_peer: WebSocketMultiplayerPeer = client.peer
	client_peer.close()
	clients.erase(client)


func _require(condition: bool, label: String) -> void:
	if condition: return
	failed = true
	push_error("LAN_RUNTIME_FAIL %s" % label)
	get_tree().quit(1)
