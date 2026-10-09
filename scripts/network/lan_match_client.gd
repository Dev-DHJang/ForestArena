class_name LanMatchClient
extends Node

signal status_changed(text: String)
signal room_created(invite_code: String)
signal room_waiting()
signal room_ready(loadouts: Dictionary, local_slot: int)
signal match_started(local_slot: int)
signal snapshot_received(snapshot: Dictionary)
signal presentation_event_received(event_id: StringName, payload: Dictionary)
signal peer_status_changed(slot: int, connected: bool)
signal match_finished(result: Dictionary)
signal rematch_changed(ready_slots: Array, closed: bool)
signal failed(code: String)

const PROTOCOL_VERSION := 2
const RECONNECT_GRACE_MSEC := 60_000
const ACTIONS: Array[StringName] = [&"jump", &"dash", &"evade", &"ultimate", &"attack_light", &"attack_heavy", &"attack_special"]

var access_token_provider: Callable
var _refreshing_auth := false
var _session_generation := 0

var websocket := WebSocketMultiplayerPeer.new()
var websocket_url := ""
var room_code := ""
var reconnect_token := ""
var local_slot := 0
var participant_names: Dictionary = {"1": "참가자 1", "2": "참가자 2"}
var _nickname := ""
var _access_token := ""
var _request_deadline_msec := 0
const REQUEST_TIMEOUT_MSEC := 8000
var running := false
var active := false
var connecting := false
var _intent := ""
var _selection: Dictionary = {}
var _handshake_pending := false
var _reconnecting := false
var _reconnect_at_msec := 0
var _reconnect_deadline_msec := 0
var _seq := 0
var _last_direction := CombatIntent.Direction.NEUTRAL


func begin_host(host_code: String, selection: LoadoutSelection, nickname: String = "", access_token: String = "") -> bool:
	var parsed := LanInvite.parse_host_code(host_code)
	if parsed.has("error"):
		failed.emit(String(parsed.error))
		return false
	return _begin(String(parsed.websocket_url), "host", "", selection, nickname, access_token)


func begin_join(invite_code: String, selection: LoadoutSelection, nickname: String = "", access_token: String = "") -> bool:
	var parsed := LanInvite.parse_invite_code(invite_code)
	if parsed.has("error"):
		failed.emit(String(parsed.error))
		return false
	return _begin(String(parsed.websocket_url), "join", String(parsed.room_code), selection, nickname, access_token)


func _begin(url: String, intent: String, code: String, selection: LoadoutSelection, nickname: String = "", access_token: String = "") -> bool:
	stop()
	_access_token = access_token
	if access_token.is_empty():
		failed.emit("authentication_required")
		return false
	_nickname = nickname.strip_edges()
	if not nickname.is_empty() and _valid_nickname(nickname).is_empty():
		failed.emit("invalid_nickname")
		return false
	participant_names = {"1": "참가자 1", "2": "참가자 2"}
	websocket_url = url
	room_code = code
	_intent = intent
	_selection = {"schema_version": 1, "character_id": String(selection.character_id), "job_id": String(selection.job_id), "accessory_id": String(selection.accessory_id)}
	active = true
	connecting = true
	_handshake_pending = true
	_request_deadline_msec = Time.get_ticks_msec() + REQUEST_TIMEOUT_MSEC
	websocket = WebSocketMultiplayerPeer.new()
	var error := websocket.create_client(websocket_url)
	if error != OK:
		_fail("connect_start_failed")
		return false
	status_changed.emit("LAN 서버 연결 중")
	return true


func _process(_delta: float) -> void:
	if not active: return
	if _request_deadline_msec > 0 and Time.get_ticks_msec() >= _request_deadline_msec:
		if _reconnecting and Time.get_ticks_msec() < _reconnect_deadline_msec:
			websocket.close()
			_request_deadline_msec = 0
			_reconnect_at_msec = Time.get_ticks_msec() + 1000
		else:
			_fail("reconnect_timeout" if _reconnecting else "request_timeout")
			return
	websocket.poll()
	var state := websocket.get_connection_status()
	if state == MultiplayerPeer.CONNECTION_CONNECTED:
		if connecting and _handshake_pending:
			connecting = false
			_handshake_pending = false
			if _reconnecting:
				_send({"type": "resume", "reconnect_token": reconnect_token, "access_token": _access_token})
			else:
				var request := {"type": "create_room" if _intent == "host" else "join_room", "room_code": room_code, "selection": _selection, "access_token": _access_token}
				if not _nickname.is_empty(): request.nickname = _nickname
				_send(request)
		while websocket.get_available_packet_count() > 0:
			_handle_message(websocket.get_packet().get_string_from_utf8())
	elif state == MultiplayerPeer.CONNECTION_DISCONNECTED:
		if running and not reconnect_token.is_empty():
			if _reconnect_deadline_msec == 0: _reconnect_deadline_msec = Time.get_ticks_msec() + RECONNECT_GRACE_MSEC
			if Time.get_ticks_msec() < _reconnect_deadline_msec:
				if _reconnect_at_msec == 0: _reconnect_at_msec = Time.get_ticks_msec() + 1000
				if Time.get_ticks_msec() >= _reconnect_at_msec and not _refreshing_auth: _open_reconnect()
			else:
				_fail("reconnect_timeout")
		elif connecting or active:
			_fail("connection_lost")
	if running: _poll_input()


func _handle_message(raw: String) -> void:
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		_fail("invalid_server_message")
		return
	var message: Dictionary = parsed
	if int(message.get("protocol_version", 0)) != PROTOCOL_VERSION:
		_fail("unsupported_protocol")
		return
	match String(message.get("type", "")):
		"room_created":
			_request_deadline_msec = 0
			if message.has("names"): _apply_participant_names(message.names)
			local_slot = int(message.slot)
			reconnect_token = String(message.reconnect_token)
			room_created.emit(String(message.invite_code))
		"room_waiting":
			status_changed.emit("참가자를 기다리는 중")
			room_waiting.emit()
		"joined":
			_request_deadline_msec = 0
			if message.has("names"): _apply_participant_names(message.names)
			local_slot = int(message.slot)
			reconnect_token = String(message.reconnect_token)
			_reconnecting = false
			_reconnect_at_msec = 0
			_reconnect_deadline_msec = 0
			status_changed.emit("LAN 방에 연결됨")
		"room_ready":
			_apply_participant_names(message.get("names", {}))
			room_ready.emit(message.get("loadouts", {}), local_slot)
		"match_start":
			local_slot = int(message.slot)
			reconnect_token = String(message.reconnect_token)
			running = true
			_seq = 0
			_reconnect_deadline_msec = 0
			status_changed.emit("LAN 대전 진행 중")
			match_started.emit(local_slot)
		"snapshot": snapshot_received.emit(message.get("state", {}))
		"presentation_event": presentation_event_received.emit(StringName(message.get("event_id", "")), message.get("payload", {}))
		"peer_status":
			peer_status_changed.emit(int(message.slot), bool(message.connected))
			status_changed.emit("상대 재접속 대기 중" if not bool(message.connected) else "상대가 복귀했습니다")
		"match_end":
			running = false
			_release_inputs()
			match_finished.emit(message)
		"rematch_state": rematch_changed.emit(message.get("ready_slots", []), bool(message.get("closed", false)))
		"error": _fail(String(message.get("code", "server_error")))
		"pong": pass


func request_rematch(ready: bool) -> void:
	if active: _send({"type": "rematch", "ready": ready})


func leave() -> void:
	_session_generation += 1
	_refreshing_auth = false
	_release_inputs()
	running = false
	active = false
	connecting = false
	_handshake_pending = false
	_reconnecting = false
	_reconnect_at_msec = 0
	_reconnect_deadline_msec = 0
	_request_deadline_msec = 0
	_access_token = ""
	if websocket.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_send({"type": "leave"})
		_close_after_leave.call_deferred()
	else:
		websocket.close()


func _close_after_leave() -> void:
	# Give the WebSocket peer one frame to flush the explicit leave message so
	# the server can end the room immediately instead of waiting for reconnect.
	await get_tree().process_frame
	websocket.poll()
	websocket.close()


func stop(close_socket := true) -> void:
	_session_generation += 1
	_refreshing_auth = false
	_release_inputs()
	running = false
	active = false
	connecting = false
	_handshake_pending = false
	_reconnecting = false
	_reconnect_at_msec = 0
	_reconnect_deadline_msec = 0
	_request_deadline_msec = 0
	_access_token = ""
	if close_socket: websocket.close()


func _open_reconnect() -> void:
	_reconnect_at_msec = Time.get_ticks_msec() + 1000
	_request_deadline_msec = 0
	if access_token_provider.is_valid():
		_refreshing_auth = true
		var generation := _session_generation
		var refreshed: String = await access_token_provider.call()
		if not active or generation != _session_generation: return
		_refreshing_auth = false
		if refreshed.is_empty():
			# API/Wi-Fi may still be unavailable. Preserve the same identity and
			# retry within the original grace; never create another guest.
			_reconnect_at_msec = Time.get_ticks_msec() + 1000
			status_changed.emit("게스트 연결 복구 대기 중")
			return
		_access_token = refreshed
	websocket = WebSocketMultiplayerPeer.new()
	if websocket.create_client(websocket_url) != OK: return
	_reconnecting = true
	connecting = true
	_handshake_pending = true
	_request_deadline_msec = Time.get_ticks_msec() + REQUEST_TIMEOUT_MSEC
	status_changed.emit("LAN 서버에 재접속 중")


func _poll_input() -> void:
	var horizontal := Input.get_axis(&"move_left", &"move_right")
	var vertical := Input.get_axis(&"move_up", &"move_down")
	var direction := CombatIntent.Direction.NEUTRAL
	if absf(horizontal) >= absf(vertical) and not is_zero_approx(horizontal): direction = CombatIntent.Direction.RIGHT if horizontal > 0.0 else CombatIntent.Direction.LEFT
	elif not is_zero_approx(vertical): direction = CombatIntent.Direction.DOWN if vertical > 0.0 else CombatIntent.Direction.UP
	if direction != _last_direction:
		if _last_direction != CombatIntent.Direction.NEUTRAL: _send_input(&"move", _last_direction, CombatIntent.Edge.RELEASE)
		if direction != CombatIntent.Direction.NEUTRAL: _send_input(&"move", direction, CombatIntent.Edge.PRESS)
		_last_direction = direction
	elif direction != CombatIntent.Direction.NEUTRAL:
		_send_input(&"move", direction, CombatIntent.Edge.HOLD)
	for action: StringName in ACTIONS:
		var action_direction := CombatIntent.Direction.NEUTRAL if action == &"ultimate" else direction
		if Input.is_action_just_pressed(action): _send_input(action, action_direction, CombatIntent.Edge.PRESS)
		elif Input.is_action_just_released(action): _send_input(action, action_direction, CombatIntent.Edge.RELEASE)


func _send_input(action: StringName, direction: CombatIntent.Direction, edge: CombatIntent.Edge) -> void:
	_seq += 1
	_send({"type": "input", "seq": _seq, "action_id": String(action), "direction": direction, "edge": edge})


func _send(message: Dictionary) -> void:
	if websocket.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED: return
	message["protocol_version"] = PROTOCOL_VERSION
	websocket.put_packet(JSON.stringify(message).to_utf8_buffer())


func _release_inputs() -> void:
	if running and _last_direction != CombatIntent.Direction.NEUTRAL: _send_input(&"move", _last_direction, CombatIntent.Edge.RELEASE)
	_last_direction = CombatIntent.Direction.NEUTRAL
	for action: StringName in ACTIONS: Input.action_release(action)
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]: Input.action_release(action)


func _fail(code: String) -> void:
	stop()
	status_changed.emit("LAN 오류 · %s" % code)
	failed.emit(code)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]: _release_inputs()


static func _valid_nickname(value: Variant) -> String:
	if not value is String: return ""
	var trimmed: String = value.strip_edges()
	if trimmed.length() < 1 or trimmed.length() > 12: return ""
	for index: int in value.length():
		var codepoint: int = value.unicode_at(index)
		if codepoint < 32 or (codepoint >= 127 and codepoint <= 159) or codepoint in [0x2028, 0x2029]: return ""
	return trimmed


func _apply_participant_names(value: Variant) -> void:
	var source: Dictionary = value if value is Dictionary else {}
	for slot: int in [1, 2]:
		var key := str(slot)
		var nickname := _valid_nickname(source.get(key, ""))
		participant_names[key] = nickname if not nickname.is_empty() else "참가자 %d" % slot
