extends Node

const PROTOCOL_VERSION := 1
const SNAPSHOT_INTERVAL_TICKS := 3
const RECONNECT_GRACE_MSEC := 60_000
const ALLOWED_ACTIONS: Array[String] = ["move", "jump", "dash", "evade", "ultimate", "attack_light", "attack_heavy", "attack_special"]
const AuthorityMatchScene = preload("res://server/game/authority_match.tscn")

var peer := WebSocketMultiplayerPeer.new()
var match_root: Node2D
var controller: MatchController
var clients: Dictionary = {}
var peer_to_slot: Dictionary = {}
var known_peers: Dictionary = {}
var used_nonces: Dictionary = {}
var pending_disconnects: Dictionary = {}
var current_match_id := ""
var running := false
var result_sent := false
var ending_reason := "combat"
var tick_accumulator := 0.0
var http_request: HTTPRequest
var token_secret := ""
var service_token := ""
var api_url := ""


func _ready() -> void:
	if FileAccess.file_exists("/tmp/forest_arena_game_ready"):
		DirAccess.remove_absolute("/tmp/forest_arena_game_ready")
	token_secret = OS.get_environment("FOREST_ARENA_TOKEN_SECRET")
	service_token = OS.get_environment("FOREST_ARENA_SERVICE_TOKEN")
	api_url = OS.get_environment("FOREST_ARENA_INTERNAL_API_URL")
	if api_url.is_empty(): api_url = "http://127.0.0.1:3000"
	if token_secret.length() < 32 or service_token.length() < 32:
		push_error("game server secrets must contain at least 32 characters")
		get_tree().quit(2)
		return
	var port := int(OS.get_environment("FOREST_ARENA_GAME_PORT"))
	if port <= 0: port = 7777
	var bind_host := OS.get_environment("FOREST_ARENA_GAME_HOST")
	if bind_host.is_empty(): bind_host = "127.0.0.1"
	var error := peer.create_server(port, bind_host)
	if error != OK:
		push_error("cannot start WebSocket server: %s" % error)
		get_tree().quit(3)
		return
	peer.peer_connected.connect(_on_peer_connected)
	peer.peer_disconnected.connect(_on_peer_disconnected)
	match_root = AuthorityMatchScene.instantiate()
	add_child(match_root)
	controller = match_root.get_node("MatchController") as MatchController
	controller.set_physics_process(false)
	controller.pause_match(true)
	controller.match_ended.connect(_on_match_ended)
	http_request = HTTPRequest.new()
	add_child(http_request)
	var health_file := FileAccess.open("/tmp/forest_arena_game_ready", FileAccess.WRITE)
	if health_file == null:
		push_error("cannot create game server health marker")
		get_tree().quit(4)
		return
	health_file.store_string("ready\n")
	health_file.close()
	print("FOREST_ARENA_GAME_SERVER_READY port=%d bind=%s" % [port, bind_host])


func _process(delta: float) -> void:
	peer.poll()
	while peer.get_available_packet_count() > 0:
		var sender := peer.get_packet_peer()
		var packet := peer.get_packet()
		_handle_packet(sender, packet.get_string_from_utf8())
	_flush_disconnects()
	if running:
		tick_accumulator += delta
		var tick_seconds := 1.0 / float(controller.rules.physics_ticks_per_second)
		while tick_accumulator >= tick_seconds and running:
			tick_accumulator -= tick_seconds
			controller.step_fixed_tick(false)
			if controller.tick % SNAPSHOT_INTERVAL_TICKS == 0: _broadcast_snapshot()
	_check_reconnect_deadlines()


func _handle_packet(peer_id: int, raw: String) -> void:
	if raw.length() > 8192:
		_reject(peer_id, "message_too_large")
		return
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		_send(peer_id, {"type": "error", "code": "invalid_json"})
		return
	var message: Dictionary = parsed
	if int(message.get("protocol_version", 0)) != PROTOCOL_VERSION:
		_reject(peer_id, "unsupported_protocol")
		return
	match String(message.get("type", "")):
		"join": _join(peer_id, String(message.get("match_ticket", "")))
		"resume": _resume(peer_id, String(message.get("reconnect_token", "")))
		"input": _input_message(peer_id, message)
		"ping": _send(peer_id, {"type": "pong", "protocol_version": PROTOCOL_VERSION})
		_: _send(peer_id, {"type": "error", "code": "unknown_message"})


func _join(peer_id: int, ticket: String) -> void:
	var claims := OnlineTokenVerifier.verify_match_token(ticket, token_secret, int(Time.get_unix_time_from_system()))
	if claims.is_empty():
		_reject(peer_id, "invalid_match_ticket")
		return
	var nonce := String(claims.nonce)
	var slot := int(claims.slot)
	if used_nonces.has(nonce) or (not current_match_id.is_empty() and current_match_id != String(claims.match_id)) or clients.has(slot):
		_reject(peer_id, "match_ticket_rejected")
		return
	if (slot == 1 and claims.character_id != "ja-hyun") or (slot == 2 and claims.character_id != "myo-ryung"):
		_reject(peer_id, "slot_character_mismatch")
		return
	used_nonces[nonce] = true
	current_match_id = String(claims.match_id)
	clients[slot] = {
		"peer_id": peer_id, "player_id": String(claims.sub), "connected": true,
		"last_seq": -1, "reconnect_token": _new_token(), "deadline": 0,
	}
	peer_to_slot[peer_id] = slot
	_send(peer_id, {"type": "joined", "protocol_version": PROTOCOL_VERSION, "match_id": current_match_id, "slot": slot, "reconnect_token": clients[slot].reconnect_token})
	if clients.size() == 2:
		controller.reset_match()
		running = true
		result_sent = false
		ending_reason = "combat"
		_broadcast({"type": "match_start", "protocol_version": PROTOCOL_VERSION, "match_id": current_match_id, "tick": controller.tick})


func _resume(peer_id: int, reconnect_token: String) -> void:
	for slot: int in clients:
		var client: Dictionary = clients[slot]
		if not bool(client.connected) and int(client.deadline) >= Time.get_ticks_msec() and _secure_equal(String(client.reconnect_token), reconnect_token):
			client.peer_id = peer_id
			client.connected = true
			client.deadline = 0
			client.reconnect_token = _new_token()
			client.last_seq = -1
			clients[slot] = client
			peer_to_slot[peer_id] = slot
			_send(peer_id, {"type": "joined", "protocol_version": PROTOCOL_VERSION, "match_id": current_match_id, "slot": slot, "reconnect_token": client.reconnect_token, "resumed": true})
			_send(peer_id, {"type": "snapshot", "protocol_version": PROTOCOL_VERSION, "match_id": current_match_id, "state": controller.network_snapshot()})
			return
	_reject(peer_id, "resume_rejected")


func _input_message(peer_id: int, message: Dictionary) -> void:
	if not peer_to_slot.has(peer_id) or not running: return
	var slot := int(peer_to_slot[peer_id])
	var client: Dictionary = clients[slot]
	var seq := int(message.get("seq", -1))
	if seq <= int(client.last_seq): return
	var action := String(message.get("action_id", ""))
	var direction := int(message.get("direction", -1))
	var edge := int(message.get("edge", -1))
	if action not in ALLOWED_ACTIONS or direction < 0 or direction > CombatIntent.Direction.DOWN or edge < 0 or edge > CombatIntent.Edge.RELEASE:
		_send(peer_id, {"type": "error", "code": "invalid_input"})
		return
	client.last_seq = seq
	clients[slot] = client
	var fighter := controller.player if slot == 1 else controller.training_dummy
	var context := CombatIntent.Context.GROUND if fighter.is_on_floor() else CombatIntent.Context.AIR
	controller.submit_intent(CombatIntent.new(controller.tick + 1, fighter.fighter_id, StringName(action), direction as CombatIntent.Direction, edge as CombatIntent.Edge, context))


func _on_peer_connected(peer_id: int) -> void:
	known_peers[peer_id] = true


func _on_peer_disconnected(peer_id: int) -> void:
	known_peers.erase(peer_id)
	pending_disconnects.erase(peer_id)
	if not peer_to_slot.has(peer_id): return
	var slot := int(peer_to_slot[peer_id])
	peer_to_slot.erase(peer_id)
	if not clients.has(slot): return
	var client: Dictionary = clients[slot]
	if not bool(client.connected): return
	client.connected = false
	client.deadline = Time.get_ticks_msec() + RECONNECT_GRACE_MSEC
	clients[slot] = client
	controller.release_fighter_input(&"ja-hyun" if slot == 1 else &"myo-ryung")


func _check_reconnect_deadlines() -> void:
	if not running: return
	for slot: int in clients:
		var client: Dictionary = clients[slot]
		if not bool(client.connected) and int(client.deadline) > 0 and Time.get_ticks_msec() > int(client.deadline):
			ending_reason = "disconnect"
			controller.finish_forfeit(&"ja-hyun" if slot == 1 else &"myo-ryung")
			return


func _broadcast_snapshot() -> void:
	_broadcast({"type": "snapshot", "protocol_version": PROTOCOL_VERSION, "match_id": current_match_id, "state": controller.network_snapshot()})


func _on_match_ended(winner_id: StringName) -> void:
	if result_sent: return
	running = false
	result_sent = true
	var winner_player_id: Variant = null
	var reason := "draw" if winner_id == &"DRAW" else ending_reason
	if winner_id != &"DRAW":
		var slot := 1 if winner_id == &"ja-hyun" else 2
		winner_player_id = clients[slot].player_id
	var end_message := {"type": "match_end", "protocol_version": PROTOCOL_VERSION, "match_id": current_match_id, "winner_player_id": winner_player_id, "reason": reason, "final_tick": controller.tick}
	_broadcast(end_message)
	_submit_result(winner_player_id, reason)


func _submit_result(winner_player_id: Variant, reason: String) -> void:
	var payload := JSON.stringify({"winner_player_id": winner_player_id, "reason": reason, "final_tick": controller.tick, "snapshot_hash": controller.snapshot_hash()})
	var headers := PackedStringArray(["Content-Type: application/json", "X-Forest-Arena-Service-Token: %s" % service_token])
	var error := http_request.request("%s/internal/v1/matches/%s/result" % [api_url, current_match_id], headers, HTTPClient.METHOD_POST, payload)
	if error != OK: push_error("result request failed to start: %s" % error)


func _send(peer_id: int, message: Dictionary) -> void:
	peer.set_target_peer(peer_id)
	peer.put_packet(JSON.stringify(message).to_utf8_buffer())


func _broadcast(message: Dictionary) -> void:
	for value: Dictionary in clients.values():
		if bool(value.connected): _send(int(value.peer_id), message)


func _reject(peer_id: int, code: String) -> void:
	_send(peer_id, {"type": "error", "protocol_version": PROTOCOL_VERSION, "code": code})
	pending_disconnects[peer_id] = Time.get_ticks_msec() + 100


func _flush_disconnects() -> void:
	for peer_id: int in pending_disconnects.keys():
		if Time.get_ticks_msec() < int(pending_disconnects[peer_id]): continue
		pending_disconnects.erase(peer_id)
		if known_peers.has(peer_id): peer.disconnect_peer(peer_id)


func _new_token() -> String:
	return Marshalls.raw_to_base64(Crypto.new().generate_random_bytes(32)).replace("+", "-").replace("/", "_").trim_suffix("=")


func _secure_equal(left: String, right: String) -> bool:
	var a := left.to_utf8_buffer()
	var b := right.to_utf8_buffer()
	if a.size() != b.size(): return false
	var difference := 0
	for index: int in a.size(): difference |= a[index] ^ b[index]
	return difference == 0
