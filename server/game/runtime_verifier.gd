extends Node

const PROTOCOL_VERSION := 1
const TIMEOUT_MSEC := 5_000

var api_url := ""
var websocket_url := ""
var service_token := ""
var clients: Array[Dictionary] = []
var failed := false


func _ready() -> void:
	api_url = OS.get_environment("FOREST_ARENA_RUNTIME_API_URL")
	websocket_url = OS.get_environment("FOREST_ARENA_RUNTIME_WS_URL")
	service_token = OS.get_environment("FOREST_ARENA_SERVICE_TOKEN")
	if api_url.is_empty(): api_url = "http://api:3000"
	if websocket_url.is_empty(): websocket_url = "ws://game-server:7777"
	_run()


func _process(_delta: float) -> void:
	for client: Dictionary in clients:
		var peer: WebSocketMultiplayerPeer = client.peer
		peer.poll()
		while peer.get_available_packet_count() > 0:
			var parsed: Variant = JSON.parse_string(peer.get_packet().get_string_from_utf8())
			if parsed is Dictionary: client.queue.append(parsed)


func _run() -> void:
	var guest1 := await _request(HTTPClient.METHOD_POST, "/v1/auth/guest", {})
	var guest2 := await _request(HTTPClient.METHOD_POST, "/v1/auth/guest", {})
	_require(guest1.status == 201 and guest2.status == 201, "guest_auth")
	var refresh := await _request(HTTPClient.METHOD_POST, "/v1/auth/refresh", {"refresh_token": guest1.body.refresh_token})
	var refresh_replay := await _request(HTTPClient.METHOD_POST, "/v1/auth/refresh", {"refresh_token": guest1.body.refresh_token})
	_require(refresh.status == 200 and refresh_replay.status == 401, "refresh_rotation")

	var joined1 := await _request(HTTPClient.METHOD_POST, "/v1/matchmaking/join", {"queue": "duel_dev"}, String(refresh.body.access_token))
	var joined2 := await _request(HTTPClient.METHOD_POST, "/v1/matchmaking/join", {"queue": "duel_dev"}, String(guest2.body.access_token))
	_require(joined1.body.status == "waiting" and joined2.body.status == "matched", "matchmaking_pair")
	var matched1 := await _request(HTTPClient.METHOD_GET, "/v1/matchmaking/%s" % joined1.body.queue_entry_id, {}, String(refresh.body.access_token))
	_require(matched1.body.slot == 1 and matched1.body.character_id == "ja-hyun", "slot_one")
	_require(joined2.body.slot == 2 and joined2.body.character_id == "myo-ryung", "slot_two")
	_require(matched1.body.match_id == joined2.body.match_id, "match_identity")

	var first := await _open_client()
	var second := await _open_client()
	_send(first, {"type": "join", "match_ticket": matched1.body.match_ticket})
	_send(second, {"type": "join", "match_ticket": joined2.body.match_ticket})
	var first_joined := await _wait_message(first, "joined")
	await _wait_message(second, "joined")
	await _wait_message(first, "match_start")
	await _wait_message(second, "match_start")
	var first_snapshot := await _wait_message(first, "snapshot")
	_require(first_snapshot.state.fighters.size() == 2, "snapshot_fighters")

	_send(first, {"type": "input", "seq": 1, "action_id": "move", "direction": 2, "edge": 0})
	var advanced := await _wait_snapshot_after(first, int(first_snapshot.state.tick))
	_require(int(advanced.state.tick) > 0, "snapshot_advanced")

	var replay := await _open_client()
	_send(replay, {"type": "join", "match_ticket": matched1.body.match_ticket})
	var replay_error := await _wait_message(replay, "error")
	_require(replay_error.code == "match_ticket_rejected", "ticket_replay")
	_close_client(replay)

	_close_client(first)
	await get_tree().create_timer(0.25).timeout
	var resumed := await _open_client()
	_send(resumed, {"type": "resume", "reconnect_token": first_joined.reconnect_token})
	var resumed_joined := await _wait_message(resumed, "joined")
	_require(bool(resumed_joined.get("resumed", false)), "resume_joined")
	await _wait_message(resumed, "snapshot")

	var invalid_winner := await _request(
		HTTPClient.METHOD_POST,
		"/internal/v1/matches/%s/result" % matched1.body.match_id,
		{"winner_player_id": "00000000-0000-4000-8000-000000000001", "reason": "combat", "final_tick": advanced.state.tick, "snapshot_hash": "a".repeat(64)},
		"",
		true,
	)
	_require(invalid_winner.status == 400 and invalid_winner.body.error == "winner_not_participant", "invalid_winner")
	_close_client(second)
	var ended := await _wait_message(resumed, "match_end", 65_000)
	_require(ended.reason == "disconnect" and ended.winner_player_id == refresh.body.player_id, "disconnect_forfeit")
	await get_tree().create_timer(0.5).timeout
	var result_body := {"winner_player_id": refresh.body.player_id, "reason": "disconnect", "final_tick": ended.final_tick, "snapshot_hash": "b".repeat(64)}
	var duplicate := await _request(HTTPClient.METHOD_POST, "/internal/v1/matches/%s/result" % matched1.body.match_id, result_body, "", true)
	_require(duplicate.body.status == "duplicate", "game_server_result")

	_close_client(resumed)
	if failed: return
	print("FOREST_ARENA_ONLINE_RUNTIME_OK match=%s tick=%s" % [matched1.body.match_id, ended.final_tick])
	get_tree().quit(0)


func _request(method: HTTPClient.Method, path: String, payload: Dictionary, token := "", internal := false) -> Dictionary:
	var request := HTTPRequest.new()
	add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not token.is_empty(): headers.append("Authorization: Bearer %s" % token)
	if internal: headers.append("X-Forest-Arena-Service-Token: %s" % service_token)
	var body := "" if method == HTTPClient.METHOD_GET else JSON.stringify(payload)
	var start_error := request.request("%s%s" % [api_url, path], headers, method, body)
	_require(start_error == OK, "http_request_start")
	if failed:
		request.queue_free()
		return {"status": 0, "body": {}}
	var completed: Array = await request.request_completed
	request.queue_free()
	var parsed: Variant = JSON.parse_string((completed[3] as PackedByteArray).get_string_from_utf8())
	_require(parsed is Dictionary, "http_response_json")
	return {"status": int(completed[1]), "body": parsed}


func _open_client() -> Dictionary:
	var client := {"peer": WebSocketMultiplayerPeer.new(), "queue": []}
	clients.append(client)
	var peer: WebSocketMultiplayerPeer = client.peer
	_require(peer.create_client(websocket_url) == OK, "websocket_create")
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_require(peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "websocket_connect")
	return client


func _send(client: Dictionary, message: Dictionary) -> void:
	message.protocol_version = PROTOCOL_VERSION
	var peer: WebSocketMultiplayerPeer = client.peer
	_require(peer.put_packet(JSON.stringify(message).to_utf8_buffer()) == OK, "websocket_send")


func _wait_message(client: Dictionary, type: String, timeout_msec := TIMEOUT_MSEC) -> Dictionary:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < deadline:
		var queue: Array = client.queue
		for index: int in queue.size():
			if String(queue[index].get("type", "")) == type:
				return queue.pop_at(index)
		await get_tree().process_frame
	_require(false, "message_timeout_%s" % type)
	return {}


func _wait_snapshot_after(client: Dictionary, tick: int) -> Dictionary:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		var queue: Array = client.queue
		for index: int in queue.size():
			var message: Dictionary = queue[index]
			if message.get("type", "") == "snapshot" and int(message.state.tick) > tick:
				return queue.pop_at(index)
		await get_tree().process_frame
	_require(false, "snapshot_timeout")
	return {}


func _close_client(client: Dictionary) -> void:
	var peer: WebSocketMultiplayerPeer = client.peer
	peer.close()
	clients.erase(client)


func _require(condition: bool, label: String) -> void:
	if condition: return
	failed = true
	push_error("FOREST_ARENA_ONLINE_RUNTIME_FAIL %s" % label)
	get_tree().quit(1)
