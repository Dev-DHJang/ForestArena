extends Node

const PROTOCOL_VERSION := 2
const TIMEOUT_MSEC := 60_000

var peer := WebSocketMultiplayerPeer.new()
var connected := false
var match_running := false
var round_index := 0
var round_started_msec := 0
var input_seq := 0
var attack_sent := false
var leave_sent := false
var deadline_msec := 0


func _ready() -> void:
	var url := OS.get_environment("FOREST_ARENA_LAN_ANDROID_WS_URL")
	var room_code := OS.get_environment("FOREST_ARENA_LAN_ANDROID_ROOM_CODE")
	if url.is_empty() or room_code.is_empty():
		_fail("missing environment")
		return
	deadline_msec = Time.get_ticks_msec() + TIMEOUT_MSEC
	if peer.create_client(url) != OK:
		_fail("connect start")
		return
	set_meta("room_code", room_code)


func _process(_delta: float) -> void:
	peer.poll()
	if Time.get_ticks_msec() >= deadline_msec:
		_fail("timeout")
		return
	if not connected and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		connected = true
		_send({"type": "join_room", "access_token": OS.get_environment("FOREST_ARENA_LAN_ANDROID_ACCESS_TOKEN"), "room_code": get_meta("room_code"), "selection": {"schema_version": 1, "character_id": "yu-ran", "job_id": "", "accessory_id": "fixture-boxing-gloves"}})
	while peer.get_available_packet_count() > 0:
		_handle(peer.get_packet().get_string_from_utf8())
	if not match_running: return
	var elapsed := Time.get_ticks_msec() - round_started_msec
	if not attack_sent and elapsed >= 750:
		input_seq += 1
		_send({"type": "input", "seq": input_seq, "action_id": "attack_light", "direction": CombatIntent.Direction.LEFT, "edge": CombatIntent.Edge.PRESS})
		attack_sent = true
	if not leave_sent and elapsed >= 3000:
		_send({"type": "leave"})
		leave_sent = true


func _handle(raw: String) -> void:
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		_fail("invalid message")
		return
	var message: Dictionary = parsed
	match String(message.get("type", "")):
		"joined": print("LAN_ANDROID_GUEST: JOINED")
		"room_ready": pass
		"match_start":
			round_index += 1
			match_running = true
			round_started_msec = Time.get_ticks_msec()
			attack_sent = false
			leave_sent = false
			print("LAN_ANDROID_GUEST: ROUND_%d_READY" % round_index)
		"match_end":
			match_running = false
			print("LAN_ANDROID_GUEST: ROUND_%d_END" % round_index)
			if round_index == 1: _send({"type": "rematch", "ready": true})
			else: _send({"type": "rematch", "ready": false})
		"rematch_state":
			if bool(message.get("closed", false)):
				if round_index >= 2:
					print("LAN_ANDROID_GUEST: PASS")
					get_tree().quit(0)
				else: _fail("closed before rematch")
			elif round_index == 1:
				print("LAN_ANDROID_GUEST: WAITING_FOR_ANDROID_REMATCH")
		"error": _fail(String(message.get("code", "server error")))


func _send(message: Dictionary) -> void:
	message["protocol_version"] = PROTOCOL_VERSION
	if peer.put_packet(JSON.stringify(message).to_utf8_buffer()) != OK: _fail("send")


func _fail(reason: String) -> void:
	push_error("LAN_ANDROID_GUEST: FAIL " + reason)
	get_tree().quit(1)
