extends Node

const TIMEOUT_MSEC := 5000
const PROTOCOL_VERSION := 5

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
	for rejected_version: int in [1, 2, 3, 4, 99]:
		var wrong_version := await _open_client()
		_send_raw(wrong_version, {"type": "create_room", "protocol_version": rejected_version, "selection": _selection("nabi", "")})
		_require((await _wait_message(wrong_version, "error")).code == "unsupported_protocol", "version_rejected_%d" % rejected_version)
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
	var inactive_accessory := await _open_client()
	_send(inactive_accessory, {"type": "create_room", "access_token": "host", "selection": _selection("nabi", "fixture-thorns")})
	_require((await _wait_message(inactive_accessory, "error")).code == "invalid_loadout", "legacy_accessory_rejected")
	_close_client(inactive_accessory)
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
	_send(host, {"type": "create_room", "access_token": "host", "nickname": "공격자위조", "selection": _selection("nabi", "pebble-yoyo")})
	var created := await _wait_message(host, "room_created")
	_require(LanInvite.parse_invite_code(String(created.invite_code)).room_code == created.room_code, "invite")
	await _wait_message(host, "room_waiting")
	var duplicate := await _open_client()
	_send(duplicate, {"type": "join_room", "access_token": "host", "room_code": created.room_code, "selection": _selection("ja-hyun", "")})
	_require((await _wait_message(duplicate, "error")).code == "duplicate_guest", "same_guest_rejected")
	_close_client(duplicate)
	var guest := await _open_client()
	_send(guest, {"type": "join_room", "access_token": "guest", "nickname": "공격자위조", "room_code": created.room_code, "selection": _selection("ja-hyun", "")})
	var guest_joined := await _wait_message(guest, "joined")
	var host_ready := await _wait_message(host, "room_ready")
	var guest_ready := await _wait_message(guest, "room_ready")
	_require(host_ready.get("names") == {"1": "호스트숲", "2": "손님숲"} and guest_ready.get("names") == host_ready.get("names"), "both clients get normalized nicknames")
	_require(host_ready.loadouts["1"].character_id == "nabi" and guest_ready.loadouts["2"].character_id == "ja-hyun", "loadouts")
	_require(host_ready.loadouts["1"].accessory_id == "pebble-yoyo", "equipped accessory reaches room_ready")
	var host_start := await _wait_message(host, "match_start")
	await _wait_message(guest, "match_start")
	var snapshot := await _wait_message(host, "snapshot")
	_require(snapshot.state.fighters.size() == 2 and snapshot.state.fighters[0].id == "lan_host", "snapshot")
	_require(int(snapshot.get("protocol_version", 0)) == 5, "snapshot protocol five")
	_check_combat_fields(snapshot.state)
	var guest_snapshot := await _wait_message(guest, "snapshot")
	_check_combat_fields(guest_snapshot.state)
	_send(host, {"type": "input", "seq": 1, "action_id": "move", "direction": CombatIntent.Direction.RIGHT, "edge": CombatIntent.Edge.PRESS})
	_send(host, {"type": "input", "seq": 1, "action_id": "move", "direction": CombatIntent.Direction.LEFT, "edge": CombatIntent.Edge.PRESS})
	_send(host, {"type": "input", "seq": 2, "action_id": "not_an_action", "direction": CombatIntent.Direction.NEUTRAL, "edge": CombatIntent.Edge.PRESS})
	_require((await _wait_message(host, "error")).code == "invalid_input", "invalid_input_rejected")
	var advanced := await _wait_snapshot_after(host, int(snapshot.state.tick))
	_require(int(advanced.state.tick) > int(snapshot.state.tick), "input_tick")
	# A fixed-tick server must move by velocity / 60 per authority tick,
	# independently of the headless render rate used to poll WebSockets.
	var steady_before := await _wait_state(host, func(state: Dictionary) -> bool:
		var actor := _fighter(state, "lan_host")
		return bool(actor.on_floor) and is_equal_approx(float(actor.velocity.x), 335.0), "steady_ground_movement")
	var steady_after := await _wait_snapshot_after(host, int(steady_before.tick) + 12)
	var ticks_moved := int(steady_after.state.tick) - int(steady_before.tick)
	var distance_moved := float(_fighter(steady_after.state, "lan_host").position.x) - float(_fighter(steady_before, "lan_host").position.x)
	_require(absf(distance_moved - 335.0 * float(ticks_moved) / 60.0) < 1.0, "authority movement uses fixed physics delta")
	# Move into range using ordinary commands, then cast through the real authority.
	var close_state := await _wait_state(host, func(state: Dictionary) -> bool:
		return _fighter(state, "lan_guest")["position"]["x"] - _fighter(state, "lan_host")["position"]["x"] <= 150.0, "move_into_equipment_range")
	_send(host, {"type": "input", "seq": 3, "action_id": "move", "direction": CombatIntent.Direction.RIGHT, "edge": CombatIntent.Edge.RELEASE})
	await _wait_state(host, func(state: Dictionary) -> bool: return _fighter(state, "lan_host").state == "IDLE", "stop_before_cast")
	var guest_hp := float(_fighter(close_state, "lan_guest")["current_hp"])
	_send(host, {"type": "input", "seq": 4, "action_id": "use_equipment", "direction": CombatIntent.Direction.RIGHT, "edge": CombatIntent.Edge.PRESS})
	var equipment_started := await _wait_state(host, func(state: Dictionary) -> bool: return int(_fighter(state, "lan_host").equipment_cooldown_ticks) > 0, "equipment_started")
	var casting := _fighter(equipment_started, "lan_host")
	_require(casting.equipment_cooldown_ticks <= 600 and casting.equipment_cooldown_ticks > 550, "server starts ten-second cooldown")
	var hit_state := await _wait_state(host, func(state: Dictionary) -> bool: return int(_fighter(state, "lan_guest").hitstun_ticks) > 0, "equipment_hit")
	var hit_guest := _fighter(hit_state, "lan_guest")
	_require(int(hit_guest.hitstun_ticks) <= 30 and float(hit_guest["current_hp"]) == guest_hp, "LAN yo-yo stuns without HP damage")
	_send(host, {"type": "input", "seq": 5, "action_id": "use_equipment", "direction": CombatIntent.Direction.RIGHT, "edge": CombatIntent.Edge.HOLD})
	_require((await _wait_message(host, "error")).code == "invalid_input", "equipment hold input rejected")
	_send(host, {"type": "input", "seq": 6, "action_id": "use_equipment", "direction": CombatIntent.Direction.RIGHT, "edge": CombatIntent.Edge.PRESS})
	var cooldown_state := await _wait_snapshot_after(host, int(hit_state.tick))
	_require(_fighter(cooldown_state.state, "lan_host").equipment_activation_serial == casting.equipment_activation_serial, "cooldown recast does not restart ability")
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
	var restored := await _wait_message(resumed, "snapshot")
	var restored_host := _fighter(restored.state, "lan_host")
	_require(restored_host.accessory_id == "pebble-yoyo" and restored_host.equipment_cooldown_ticks > 0, "resume restores equipped cooldown")
	_require(restored_host.equipment_activation_serial == casting.equipment_activation_serial, "resume preserves activation identity")
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


func _check_combat_fields(state: Dictionary) -> void:
	for fighter: Dictionary in state.get("fighters", []):
		for field: String in ["hitstun_ticks", "landing_down_duration_ticks", "ring_out_hidden", "ring_out_pending_ticks", "debug_geometry", "equipment_cooldown_ticks", "equipment_phase", "equipment_tick", "equipment_phase_tick", "equipment_facing", "equipment_position", "equipment_activation_serial", "equipment_airborne"]:
			_require(fighter.has(field), "LAN5 fighter field " + field)
		_require(fighter.get("hitstun_ticks", -1) >= 0 and fighter.get("ring_out_pending_ticks", -1) >= 0, "nonnegative combat countdown")
		_require(fighter.get("ring_out_hidden") is bool, "hidden flag type")
		var geometry: Dictionary = fighter.get("debug_geometry", {})
		_require(geometry.has("hurtbox") and geometry.has("hitboxes"), "authoritative geometry collections")
		var boxes: Array = geometry.get("hitboxes", []).duplicate()
		if not geometry.get("hurtbox", {}).is_empty(): boxes.append(geometry.hurtbox)
		for box: Dictionary in boxes:
			_require(box.has("x") and box.has("y") and box.has("w") and box.has("h") and float(box.w) > 0 and float(box.h) > 0, "world rectangle fields")



func _fighter(state: Dictionary, id: String) -> Dictionary:
	for fighter: Dictionary in state.get("fighters", []):
		if fighter.id == id: return fighter
	return {}


func _wait_state(client: Dictionary, predicate: Callable, label: String) -> Dictionary:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	var latest: Dictionary = {}
	while Time.get_ticks_msec() < deadline:
		var queue: Array = client.queue
		for index: int in range(queue.size() - 1, -1, -1):
			var message: Dictionary = queue[index]
			if message.get("type") == "snapshot":
				queue.remove_at(index)
				latest = message.state
				if predicate.call(message.state): return message.state
		await get_tree().process_frame
	var actors: Array[Dictionary] = []
	for fighter: Dictionary in latest.get("fighters", []):
		actors.append({"id": fighter.id, "state": fighter.state, "position": fighter.position, "velocity": fighter.velocity, "equipment_phase": fighter.get("equipment_phase", "missing"), "equipment_cooldown_ticks": fighter.get("equipment_cooldown_ticks", -1), "hitstun_ticks": fighter.get("hitstun_ticks", -1)})
	print("LAN_RUNTIME_STATE ", JSON.stringify({"condition": label, "tick": latest.get("tick", -1), "fighters": actors}))
	_require(false, "equipment_snapshot_condition:" + label)
	return {}

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
