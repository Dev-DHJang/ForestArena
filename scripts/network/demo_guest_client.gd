class_name DemoGuestClient
extends Node

# Demo identity is independent of device inventory and the development DB mode.
var session_path := "user://demo_guest_session.json"
var request_timeout := 8.0
var api_url := ""
var player_id := ""
var nickname := ""
var access_token := ""
var error := ""
var session_invalid := false
var busy := false
var refresh_token := ""
var pending_auth: Dictionary = {}
var _generation := 0
var _active: Request

class Request extends HTTPRequest:
	signal finished(value: Dictionary)
	var settled := false
	func settle(value: Dictionary) -> void:
		if settled: return
		settled = true
		finished.emit(value)

func cancel() -> void:
	_generation += 1
	busy = false
	error = "cancelled"
	access_token = ""
	var request := _active
	_active = null
	if is_instance_valid(request):
		request.cancel_request()
		request.settle({"error": "cancelled", "status": 0})

func _current(generation: int) -> bool:
	return generation == _generation

func _request(method: HTTPClient.Method, route: String, payload: Dictionary, authenticated: bool, generation: int) -> Dictionary:
	if not _current(generation): return {"error": "cancelled", "status": 0}
	var request := Request.new()
	request.timeout = request_timeout
	add_child(request)
	_active = request
	request.request_completed.connect(func(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		if result != HTTPRequest.RESULT_SUCCESS:
			request.settle({"error": "connection_failed", "status": 0})
			return
		var decoded: Variant = JSON.parse_string(body.get_string_from_utf8())
		if not decoded is Dictionary:
			request.settle({"error": "invalid_response", "status": status})
			return
		decoded.status = status
		request.settle(decoded)
	)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if authenticated: headers.append("Authorization: Bearer " + access_token)
	var started := request.request(api_url + route, headers, method, "" if method == HTTPClient.METHOD_GET else JSON.stringify(payload))
	if started != OK:
		request.queue_free()
		_active = null
		return {"error": "connection_failed", "status": 0}
	var response: Dictionary = await request.finished
	if _active == request: _active = null
	request.queue_free()
	if not _current(generation): return {"error": "cancelled", "status": 0}
	return response

func _write_session(value: Dictionary) -> bool:
	var file := FileAccess.open(session_path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value))
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	return ok and DirAccess.rename_absolute(session_path + ".tmp", session_path) == OK

func _save_session() -> bool:
	return _write_session({"api_url": api_url, "player_id": player_id, "refresh_token": refresh_token, "pending_auth": pending_auth})

func _fail(result: Dictionary, generation: int) -> bool:
	if not _current(generation): return false
	error = String(result.get("error", "invalid_response"))
	session_invalid = int(result.get("status", 0)) == 401
	if session_invalid: access_token = ""
	return false

func _authenticate(create: bool, generation: int) -> bool:
	var result: Dictionary
	if create:
		result = await _request(HTTPClient.METHOD_POST, "/v1/auth/guest", {}, false, generation)
	else:
		if pending_auth.is_empty():
			var successor := Marshalls.raw_to_base64(Crypto.new().generate_random_bytes(32)).replace("+", "-").replace("/", "_").trim_suffix("=")
			pending_auth = {"refresh_token": refresh_token, "next_refresh_token": successor}
			if not _save_session():
				pending_auth = {}
				return _fail({"error": "session_save_failed"}, generation)
		result = await _request(HTTPClient.METHOD_POST, "/v1/auth/refresh", pending_auth, false, generation)
	if not _current(generation): return false
	if result.has("error"): return _fail(result, generation)
	for field: String in ["access_token", "refresh_token", "player_id"]:
		if not result.get(field) is String or String(result[field]).is_empty(): return _fail({}, generation)
	if not create and result.player_id != player_id: return _fail({}, generation)
	var prior_token := refresh_token
	var prior_player := player_id
	var prior_auth := pending_auth.duplicate(true)
	refresh_token = result.refresh_token
	player_id = result.player_id
	pending_auth = {}
	if not _save_session():
		refresh_token = prior_token
		player_id = prior_player
		pending_auth = prior_auth
		access_token = ""
		return _fail({"error": "session_save_failed"}, generation)
	access_token = result.access_token
	return true

func _profile(method: HTTPClient.Method, payload: Dictionary, generation: int) -> bool:
	var result := await _request(method, "/v1/guest/profile", payload, true, generation)
	if not _current(generation): return false
	if int(result.get("status", 0)) == 401:
		if not await _authenticate(false, generation): return false
		result = await _request(method, "/v1/guest/profile", payload, true, generation)
	if not _current(generation): return false
	if result.has("error"): return _fail(result, generation)
	if int(result.get("status", 0)) != 200 or result.get("player_id") != player_id or not result.has("nickname") or (result.nickname != null and not result.nickname is String): return _fail({}, generation)
	nickname = "" if result.nickname == null else String(result.nickname)
	return true

func login(url: String, new_guest := false) -> bool:
	if busy: return false
	_generation += 1
	var generation := _generation
	busy = true
	error = ""
	session_invalid = false
	access_token = ""
	nickname = ""
	var endpoint := url.strip_edges().trim_suffix("/")
	if not endpoint.begins_with("http://") and not endpoint.begins_with("https://"):
		busy = false
		return _fail({"error": "invalid_url"}, generation)
	var create := new_guest or not FileAccess.file_exists(session_path)
	if not create:
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(session_path))
		if not saved is Dictionary or not saved.get("refresh_token") is String or String(saved.get("refresh_token", "")).is_empty() or not saved.get("player_id") is String or String(saved.get("player_id", "")).is_empty() or not saved.get("pending_auth", {}) is Dictionary:
			busy = false
			return _fail({"error": "session_invalid", "status": 401}, generation)
		if saved.get("api_url") != endpoint:
			busy = false
			return _fail({"error": "session_endpoint_mismatch"}, generation)
		refresh_token = saved.refresh_token
		player_id = saved.player_id
		pending_auth = saved.get("pending_auth", {})
		if not pending_auth.is_empty() and (pending_auth.get("refresh_token") != refresh_token or not pending_auth.get("next_refresh_token") is String or String(pending_auth.get("next_refresh_token", "")).is_empty()):
			busy = false
			return _fail({"error": "session_invalid", "status": 401}, generation)
	else:
		refresh_token = ""
		player_id = ""
		pending_auth = {}
	api_url = endpoint
	var ok := await _authenticate(create, generation)
	if ok: ok = await _profile(HTTPClient.METHOD_GET, {}, generation)
	if _current(generation): busy = false
	return ok and _current(generation)

func set_nickname(value: String) -> bool:
	if busy: return false
	if access_token.is_empty():
		error = "session_invalid"
		session_invalid = true
		return false
	_generation += 1
	var generation := _generation
	busy = true
	error = ""
	var ok := await _profile(HTTPClient.METHOD_PATCH, {"nickname": value}, generation)
	if _current(generation): busy = false
	return ok and _current(generation)
