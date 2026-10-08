extends Node

const PROTOCOL_VERSION := 1
const SNAPSHOT_INTERVAL_TICKS := 3
const RECONNECT_GRACE_MSEC := 60_000
const REMATCH_GRACE_MSEC := 20_000
const MAX_PACKET_BYTES := 8192
const ALLOWED_ACTIONS: Array[String] = ["move", "jump", "dash", "evade", "ultimate", "attack_light", "attack_heavy", "attack_special"]
const MATCH_SCENE := preload("res://server/game/lan_authority_match.tscn")
const ROOM_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var peer := WebSocketMultiplayerPeer.new()
var match_root: Node2D
var controller: MatchController
var catalog: LoadoutCatalog
var clients: Dictionary = {}
var peer_to_slot: Dictionary = {}
var known_peers: Dictionary = {}
var pending_disconnects: Dictionary = {}
var room_code := ""
var running := false
var ended := false
var ending_reason := "combat"
var tick_accumulator := 0.0
var rematch_deadline_msec := 0
var match_seed := 0
var advertised_url := ""


func _ready() -> void:
	catalog = LocalPlayCatalog.new().combat
	var port := int(OS.get_environment("FOREST_ARENA_LAN_PORT"))
	if port <= 0: port = 7777
	var bind_host := OS.get_environment("FOREST_ARENA_LAN_BIND_HOST")
	if bind_host.is_empty(): bind_host = "127.0.0.1"
	advertised_url = OS.get_environment("FOREST_ARENA_LAN_ADVERTISED_WS_URL")
	if advertised_url.is_empty(): advertised_url = "ws://%s:%d" % [bind_host, port]
	if not LanInvite.valid_private_websocket_url(advertised_url):
		push_error("LAN advertised URL must use a private IPv4 address: %s" % advertised_url)
		get_tree().quit(2)
		return
	var error := peer.create_server(port, bind_host)
	if error != OK:
		push_error("LAN server could not bind %s:%d error=%s" % [bind_host, port, error])
		get_tree().quit(3)
		return
	peer.peer_connected.connect(_on_peer_connected)
	peer.peer_disconnected.connect(_on_peer_disconnected)
	match_root = MATCH_SCENE.instantiate()
	add_child(match_root)
	controller = match_root.get_node("MatchController") as MatchController
	controller.loadout_catalog = catalog
	controller.set_physics_process(false)
	controller.pause_match(true)
	controller.match_ended.connect(_on_match_ended)
	controller.presentation_event.connect(_on_presentation_event)
	print("FOREST_ARENA_LAN_READY %s" % LanInvite.host_code(advertised_url))


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
	_check_deadlines()


func _handle_packet(peer_id: int, raw: String) -> void:
	if raw.length() > MAX_PACKET_BYTES:
		_reject(peer_id, "message_too_large")
		return
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		_reject(peer_id, "invalid_json")
		return
	var message: Dictionary = parsed
	if int(message.get("protocol_version", 0)) != PROTOCOL_VERSION:
		_reject(peer_id, "unsupported_protocol")
		return
	match String(message.get("type", "")):
		"create_room": _create_room(peer_id, message.get("selection", {}), message.get("nickname"))
		"join_room": _join_room(peer_id, String(message.get("room_code", "")), message.get("selection", {}), message.get("nickname"))
		"resume": _resume(peer_id, String(message.get("reconnect_token", "")))
		"input": _input_message(peer_id, message)
		"rematch": _rematch(peer_id, bool(message.get("ready", false)))
		"leave": _leave(peer_id)
		"ping": _send(peer_id, {"type": "pong"})
		_: _send(peer_id, {"type": "error", "code": "unknown_message"})


func _create_room(peer_id: int, value: Variant, nickname_value: Variant = null) -> void:
	if not room_code.is_empty():
		_reject(peer_id, "server_busy")
		return
	var selection := _selection_from(value)
	if selection == null:
		_reject(peer_id, "invalid_loadout")
		return
	var nickname := _nickname_from(nickname_value, 1)
	if nickname.is_empty():
		_reject(peer_id, "invalid_nickname")
		return
	room_code = _new_room_code()
	_register_client(peer_id, 1, selection, nickname)
	_send(peer_id, {"type": "room_created", "room_code": room_code, "invite_code": LanInvite.invite_code(advertised_url, room_code), "slot": 1, "reconnect_token": clients[1].reconnect_token})
	_send(peer_id, {"type": "room_waiting", "room_code": room_code})


func _join_room(peer_id: int, requested_code: String, value: Variant, nickname_value: Variant = null) -> void:
	if room_code.is_empty() or requested_code.to_upper() != room_code:
		_reject(peer_id, "room_not_found")
		return
	if clients.has(2):
		_reject(peer_id, "room_full")
		return
	var selection := _selection_from(value)
	if selection == null:
		_reject(peer_id, "invalid_loadout")
		return
	var nickname := _nickname_from(nickname_value, 2)
	if nickname.is_empty():
		_reject(peer_id, "invalid_nickname")
		return
	_register_client(peer_id, 2, selection, nickname)
	_send(peer_id, {"type": "joined", "slot": 2, "reconnect_token": clients[2].reconnect_token})
	_start_match()


func _register_client(peer_id: int, slot: int, selection: LoadoutSelection, nickname: String) -> void:
	clients[slot] = {"peer_id": peer_id, "connected": true, "selection": selection, "nickname": nickname, "last_seq": -1, "reconnect_token": _new_token(), "deadline": 0, "rematch": false}
	peer_to_slot[peer_id] = slot


func _start_match() -> void:
	if clients.size() != 2: return
	var host_selection: LoadoutSelection = clients[1].selection
	var guest_selection: LoadoutSelection = clients[2].selection
	var host_result := LoadoutBuilder.build(host_selection, catalog)
	var guest_result := LoadoutBuilder.build(guest_selection, catalog)
	if not host_result.succeeded() or not guest_result.succeeded():
		_broadcast({"type": "error", "code": "loadout_build_failed"})
		_reset_room()
		return
	controller.player.fighter_id = &"lan_host"
	controller.training_dummy.fighter_id = &"lan_guest"
	controller.player.character_data = catalog.character_by_id(host_selection.character_id)
	controller.training_dummy.character_data = catalog.character_by_id(guest_selection.character_id)
	if not controller.player.configure_profile(host_result.profile) or not controller.training_dummy.configure_profile(guest_result.profile):
		_broadcast({"type": "error", "code": "profile_configuration_failed"})
		_reset_room()
		return
	match_seed = int(Time.get_ticks_usec() & 0x7fffffff)
	for slot: int in [1, 2]:
		var client: Dictionary = clients[slot]
		client.last_seq = -1
		client.rematch = false
		clients[slot] = client
	running = true
	ended = false
	ending_reason = "combat"
	tick_accumulator = 0.0
	rematch_deadline_msec = 0
	controller.reset_match()
	_broadcast({"type": "room_ready", "stage_id": "forest-ledge", "seed": match_seed, "names": _participant_names(), "loadouts": {"1": _selection_dict(host_selection), "2": _selection_dict(guest_selection)}})
	for slot: int in [1, 2]:
		_send(int(clients[slot].peer_id), {"type": "match_start", "slot": slot, "seed": match_seed, "reconnect_token": clients[slot].reconnect_token})


func _selection_from(value: Variant) -> LoadoutSelection:
	if not value is Dictionary: return null
	var source: Dictionary = value
	if int(source.get("schema_version", 0)) != 1: return null
	var selection := LoadoutSelection.new()
	selection.character_id = StringName(source.get("character_id", ""))
	selection.job_id = StringName(source.get("job_id", ""))
	selection.accessory_id = StringName(source.get("accessory_id", ""))
	if not selection.is_valid_definition(): return null
	if catalog.character_by_id(selection.character_id) == null: return null
	if not selection.job_id.is_empty() and catalog.job_by_id(selection.job_id) == null: return null
	if not selection.accessory_id.is_empty() and catalog.accessory_by_id(selection.accessory_id) == null: return null
	return selection if LoadoutBuilder.build(selection, catalog).succeeded() else null


func _selection_dict(selection: LoadoutSelection) -> Dictionary:
	return {"schema_version": 1, "character_id": String(selection.character_id), "job_id": String(selection.job_id), "accessory_id": String(selection.accessory_id)}


func _input_message(peer_id: int, message: Dictionary) -> void:
	if not running or not peer_to_slot.has(peer_id): return
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


func _resume(peer_id: int, token: String) -> void:
	for slot: int in clients:
		var client: Dictionary = clients[slot]
		if bool(client.connected) or int(client.deadline) < Time.get_ticks_msec() or not _secure_equal(String(client.reconnect_token), token): continue
		client.peer_id = peer_id
		client.connected = true
		client.deadline = 0
		client.last_seq = -1
		client.reconnect_token = _new_token()
		clients[slot] = client
		peer_to_slot[peer_id] = slot
		_send(peer_id, {"type": "joined", "slot": slot, "reconnect_token": client.reconnect_token, "resumed": true, "names": _participant_names()})
		_send(peer_id, {"type": "snapshot", "state": controller.network_snapshot()})
		_broadcast({"type": "peer_status", "slot": slot, "connected": true})
		return
	_reject(peer_id, "resume_rejected")


func _rematch(peer_id: int, ready: bool) -> void:
	if not ended or not peer_to_slot.has(peer_id): return
	var slot := int(peer_to_slot[peer_id])
	if not ready:
		_broadcast({"type": "rematch_state", "ready_slots": [], "closed": true})
		_reset_room()
		return
	var client: Dictionary = clients[slot]
	client.rematch = true
	clients[slot] = client
	var ready_slots: Array[int] = []
	for value_slot: int in clients:
		if bool(clients[value_slot].rematch): ready_slots.append(value_slot)
	_broadcast({"type": "rematch_state", "ready_slots": ready_slots, "closed": false})
	if ready_slots.size() == 2: _start_match()


func _leave(peer_id: int) -> void:
	if not peer_to_slot.has(peer_id): return
	if running:
		ending_reason = "disconnect"
		var loser := controller.player.fighter_id if int(peer_to_slot[peer_id]) == 1 else controller.training_dummy.fighter_id
		controller.finish_forfeit(loser)
	else:
		_broadcast({"type": "match_end", "reason": "room_closed", "winner_slot": 0, "final_tick": controller.tick})
		_reset_room()


func _on_match_ended(winner_id: StringName) -> void:
	if ended: return
	running = false
	ended = true
	rematch_deadline_msec = Time.get_ticks_msec() + REMATCH_GRACE_MSEC
	var winner_slot := 0
	if winner_id == &"lan_host": winner_slot = 1
	elif winner_id == &"lan_guest": winner_slot = 2
	var reason := "draw" if winner_id == &"DRAW" else ending_reason
	_broadcast({"type": "match_end", "reason": reason, "winner_slot": winner_slot, "final_tick": controller.tick, "snapshot_hash": controller.snapshot_hash()})


func _broadcast_snapshot() -> void:
	_broadcast({"type": "snapshot", "state": controller.network_snapshot()})


func _on_presentation_event(event_id: StringName, payload: Dictionary) -> void:
	if running: _broadcast({"type": "presentation_event", "event_id": String(event_id), "payload": payload})


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
	if running:
		controller.release_fighter_input(controller.player.fighter_id if slot == 1 else controller.training_dummy.fighter_id)
		_broadcast({"type": "peer_status", "slot": slot, "connected": false, "grace_seconds": 60})
	else:
		_reset_room()


func _check_deadlines() -> void:
	if running:
		for slot: int in clients:
			var client: Dictionary = clients[slot]
			if bool(client.connected) or int(client.deadline) <= 0 or Time.get_ticks_msec() <= int(client.deadline): continue
			ending_reason = "disconnect"
			controller.finish_forfeit(controller.player.fighter_id if slot == 1 else controller.training_dummy.fighter_id)
			return
	elif ended and rematch_deadline_msec > 0 and Time.get_ticks_msec() > rematch_deadline_msec:
		_broadcast({"type": "rematch_state", "ready_slots": [], "closed": true})
		_reset_room()


func _reset_room() -> void:
	for value: Dictionary in clients.values():
		var peer_id := int(value.get("peer_id", 0))
		if peer_id > 0 and known_peers.has(peer_id): pending_disconnects[peer_id] = Time.get_ticks_msec() + 100
	clients.clear()
	peer_to_slot.clear()
	room_code = ""
	running = false
	ended = false
	rematch_deadline_msec = 0
	controller.pause_match(true)


func _send(peer_id: int, message: Dictionary) -> void:
	var socket := peer.get_peer(peer_id)
	if socket == null or socket.get_ready_state() != WebSocketPeer.STATE_OPEN: return
	message["protocol_version"] = PROTOCOL_VERSION
	peer.set_target_peer(peer_id)
	peer.put_packet(JSON.stringify(message).to_utf8_buffer())


func _broadcast(message: Dictionary) -> void:
	for value: Dictionary in clients.values():
		var peer_id := int(value.get("peer_id", 0))
		if bool(value.connected) and known_peers.has(peer_id): _send(peer_id, message.duplicate(true))


func _reject(peer_id: int, code: String) -> void:
	_send(peer_id, {"type": "error", "code": code})
	pending_disconnects[peer_id] = Time.get_ticks_msec() + 100


func _flush_disconnects() -> void:
	for peer_id: int in pending_disconnects.keys():
		if Time.get_ticks_msec() < int(pending_disconnects[peer_id]): continue
		pending_disconnects.erase(peer_id)
		if known_peers.has(peer_id): peer.disconnect_peer(peer_id)


func _new_room_code() -> String:
	var bytes := Crypto.new().generate_random_bytes(LanInvite.ROOM_CODE_LENGTH)
	var result := ""
	for value: int in bytes: result += ROOM_ALPHABET[value % ROOM_ALPHABET.length()]
	return result


func _new_token() -> String:
	return Marshalls.raw_to_base64(Crypto.new().generate_random_bytes(32)).replace("+", "-").replace("/", "_").trim_suffix("=")


func _secure_equal(left: String, right: String) -> bool:
	var a := left.to_utf8_buffer()
	var b := right.to_utf8_buffer()
	if a.size() != b.size(): return false
	var difference := 0
	for index: int in a.size(): difference |= a[index] ^ b[index]
	return difference == 0


func _nickname_from(value: Variant, slot: int) -> String:
	if value == null: return "참가자 %d" % slot
	return LanMatchClient._valid_nickname(value)


func _participant_names() -> Dictionary:
	var names: Dictionary = {}
	for slot: int in clients:
		names[str(slot)] = String(clients[slot].nickname)
	return names
