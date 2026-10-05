extends Node2D

const PROTOCOL_VERSION := 1
const MainScene = preload("res://scenes/main.tscn")
const SESSION_PATH := "user://online_dev_session.json"
const ACTIONS: Array[StringName] = [&"jump", &"dash", &"evade", &"ultimate", &"attack_light", &"attack_heavy", &"attack_special"]

var arena: Node2D
var controller: MatchController
var http := HTTPRequest.new()
var websocket := WebSocketMultiplayerPeer.new()
var api_url := "http://127.0.0.1:3000"
var websocket_url := ""
var access_token := ""
var refresh_token := ""
var match_ticket := ""
var reconnect_token := ""
var queue_entry_id := ""
var slot := 0
var seq := 0
var running := false
var connecting := false
var ended := false
var reconnect_at_msec := 0
var last_direction := CombatIntent.Direction.NEUTRAL
var endpoint_edit: LineEdit
var status_label: Label
var connect_button: Button


func _ready() -> void:
	arena = MainScene.instantiate()
	arena.set("app_shell_mode", true)
	add_child(arena)
	controller = arena.get_node("MatchController") as MatchController
	controller.pause_match(true)
	controller.set_physics_process(false)
	controller.player.set_physics_process(false)
	controller.training_dummy.set_physics_process(false)
	add_child(http)
	_build_panel()
	var configured := OS.get_environment("FOREST_ARENA_API_URL")
	if not configured.is_empty(): api_url = configured
	endpoint_edit.text = api_url
	if "--auto-connect" in OS.get_cmdline_user_args(): _begin_connect()


func _build_panel() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(880, 620)
	panel.size = Vector2(388, 88)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	endpoint_edit = LineEdit.new()
	endpoint_edit.placeholder_text = "http://127.0.0.1:3000"
	endpoint_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(endpoint_edit)
	connect_button = Button.new()
	connect_button.text = "온라인 개발 연결"
	connect_button.pressed.connect(_begin_connect)
	row.add_child(connect_button)
	status_label = Label.new()
	status_label.text = "오프라인 기본 모드 · 개발 연결 대기"
	box.add_child(status_label)


func _begin_connect() -> void:
	if connecting or running: return
	api_url = endpoint_edit.text.trim_suffix("/")
	connecting = true
	connect_button.disabled = true
	_run_login_and_matchmaking()


func _run_login_and_matchmaking() -> void:
	_set_status("게스트 로그인 중")
	_load_session()
	var auth: Dictionary
	if not refresh_token.is_empty():
		auth = await _request_json(HTTPClient.METHOD_POST, "/v1/auth/refresh", {"refresh_token": refresh_token})
	if auth.is_empty() or auth.has("error"):
		auth = await _request_json(HTTPClient.METHOD_POST, "/v1/auth/guest", {})
	if auth.has("error") or not auth.has("access_token"):
		_fail("로그인 실패: %s" % auth.get("error", "network"))
		return
	access_token = String(auth.access_token)
	refresh_token = String(auth.refresh_token)
	_save_session()
	_set_status("2인 매칭 대기 중")
	var joined := await _request_json(HTTPClient.METHOD_POST, "/v1/matchmaking/join", {"queue": "duel_dev"}, true)
	if joined.has("error"):
		_fail("매칭 참가 실패: %s" % joined.error)
		return
	queue_entry_id = String(joined.queue_entry_id)
	while String(joined.get("status", "")) == "waiting":
		await get_tree().create_timer(0.5).timeout
		joined = await _request_json(HTTPClient.METHOD_GET, "/v1/matchmaking/%s" % queue_entry_id, {}, true)
		if joined.has("error"):
			_fail("매칭 조회 실패: %s" % joined.error)
			return
	match_ticket = String(joined.match_ticket)
	websocket_url = String(joined.websocket_url)
	slot = int(joined.slot)
	_set_status("게임 서버 연결 중 · slot %d" % slot)
	_open_websocket(false)


func _request_json(method: HTTPClient.Method, path: String, payload: Dictionary, authenticated := false) -> Dictionary:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if authenticated: headers.append("Authorization: Bearer %s" % access_token)
	var error := http.request("%s%s" % [api_url, path], headers, method, "" if method == HTTPClient.METHOD_GET else JSON.stringify(payload))
	if error != OK: return {"error": "request_start_%s" % error}
	var completed: Array = await http.request_completed
	var status := int(completed[1])
	var parsed: Variant = JSON.parse_string((completed[3] as PackedByteArray).get_string_from_utf8())
	if not parsed is Dictionary: return {"error": "invalid_response", "status": status}
	var result: Dictionary = parsed
	if status < 200 or status >= 300: result["status"] = status
	return result


func _open_websocket(resume: bool) -> void:
	websocket = WebSocketMultiplayerPeer.new()
	var error := websocket.create_client(websocket_url)
	if error != OK:
		_fail("WebSocket 시작 실패: %s" % error)
		return
	connecting = true
	set_meta("resume_on_open", resume)


func _process(_delta: float) -> void:
	websocket.poll()
	var state := websocket.get_connection_status()
	if state == MultiplayerPeer.CONNECTION_CONNECTED:
		if connecting:
			connecting = false
			var resume := bool(get_meta("resume_on_open", false))
			if resume:
				_send({"type": "resume", "reconnect_token": reconnect_token})
			else:
				_send({"type": "join", "match_ticket": match_ticket})
		while websocket.get_available_packet_count() > 0:
			_handle_message(websocket.get_packet().get_string_from_utf8())
	elif state == MultiplayerPeer.CONNECTION_DISCONNECTED and not ended and not reconnect_token.is_empty():
		if reconnect_at_msec == 0:
			running = false
			reconnect_at_msec = Time.get_ticks_msec() + 1000
			_set_status("연결 끊김 · 재접속 준비")
		elif Time.get_ticks_msec() >= reconnect_at_msec:
			reconnect_at_msec = 0
			_set_status("재접속 중")
			_open_websocket(true)
	if running: _poll_input()


func _handle_message(raw: String) -> void:
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary: return
	var message: Dictionary = parsed
	match String(message.get("type", "")):
		"joined":
			reconnect_token = String(message.reconnect_token)
			slot = int(message.slot)
			_set_status("서버 참가 완료 · slot %d" % slot)
		"match_start":
			running = true
			_set_status("온라인 전투 진행 중 · slot %d" % slot)
		"snapshot": _apply_snapshot(message.get("state", {}))
		"match_end":
			running = false
			ended = true
			_set_status("경기 종료 · %s" % message.get("reason", "unknown"))
		"error": _set_status("서버 오류 · %s" % message.get("code", "unknown"))


func _apply_snapshot(value: Variant) -> void:
	if not value is Dictionary: return
	var snapshot: Dictionary = value
	for fighter_value: Variant in snapshot.get("fighters", []):
		if not fighter_value is Dictionary: continue
		var fighter_data: Dictionary = fighter_value
		var fighter := controller.player if String(fighter_data.get("id", "")) == "ja-hyun" else controller.training_dummy
		fighter.apply_network_snapshot(fighter_data)
	controller.snapshot_changed.emit(snapshot)


func _poll_input() -> void:
	var horizontal := Input.get_axis(&"move_left", &"move_right")
	var vertical := Input.get_axis(&"move_up", &"move_down")
	var direction := CombatIntent.Direction.NEUTRAL
	if absf(horizontal) >= absf(vertical) and not is_zero_approx(horizontal): direction = CombatIntent.Direction.RIGHT if horizontal > 0.0 else CombatIntent.Direction.LEFT
	elif not is_zero_approx(vertical): direction = CombatIntent.Direction.DOWN if vertical > 0.0 else CombatIntent.Direction.UP
	if direction != last_direction:
		if last_direction != CombatIntent.Direction.NEUTRAL: _send_input(&"move", last_direction, CombatIntent.Edge.RELEASE)
		if direction != CombatIntent.Direction.NEUTRAL: _send_input(&"move", direction, CombatIntent.Edge.PRESS)
		last_direction = direction
	elif direction != CombatIntent.Direction.NEUTRAL:
		_send_input(&"move", direction, CombatIntent.Edge.HOLD)
	for action: StringName in ACTIONS:
		var action_direction := CombatIntent.Direction.NEUTRAL if action == &"ultimate" else direction
		if Input.is_action_just_pressed(action): _send_input(action, action_direction, CombatIntent.Edge.PRESS)
		elif Input.is_action_just_released(action): _send_input(action, action_direction, CombatIntent.Edge.RELEASE)


func _send_input(action: StringName, direction: CombatIntent.Direction, edge: CombatIntent.Edge) -> void:
	seq += 1
	_send({"type": "input", "seq": seq, "action_id": String(action), "direction": direction, "edge": edge})


func _send(message: Dictionary) -> void:
	message["protocol_version"] = PROTOCOL_VERSION
	websocket.put_packet(JSON.stringify(message).to_utf8_buffer())


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and running:
		if last_direction != CombatIntent.Direction.NEUTRAL: _send_input(&"move", last_direction, CombatIntent.Edge.RELEASE)
		last_direction = CombatIntent.Direction.NEUTRAL


func _load_session() -> void:
	if not FileAccess.file_exists(SESSION_PATH): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SESSION_PATH))
	if parsed is Dictionary: refresh_token = String(parsed.get("refresh_token", ""))


func _save_session() -> void:
	var file := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"refresh_token": refresh_token}))


func _set_status(value: String) -> void:
	status_label.text = value


func _fail(value: String) -> void:
	connecting = false
	connect_button.disabled = false
	_set_status(value)
