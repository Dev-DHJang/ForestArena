class_name DbProfileClient
extends Node

var api_url := "http://127.0.0.1:3000"
var session_path := "user://db_profile_session.json"
var request_timeout := 8.0
var http: HTTPRequest
var access_token := ""
var refresh_token := ""
var player_id := ""
var revision := 0
var profile: Dictionary = {}
var pending: Dictionary = {}
var pending_auth: Dictionary = {}
var error := ""
var busy := false
var session_invalid := false
var use_db := true
var connected := false

func saved_connection() -> Dictionary:
	if not FileAccess.file_exists(session_path): return {}
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(session_path))
	return saved if saved is Dictionary else {}

func _ready() -> void:
	http = HTTPRequest.new()
	http.timeout = request_timeout
	add_child(http)

func _request(method: HTTPClient.Method, route: String, payload := {}, authenticated := true) -> Dictionary:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if authenticated: headers.append("Authorization: Bearer " + access_token)
	var started := http.request(api_url + route, headers, method, "" if method == HTTPClient.METHOD_GET else JSON.stringify(payload))
	if started != OK: return {"error": "connection_failed", "status": 0}
	var response: Array = await http.request_completed
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS: return {"error": "connection_failed", "status": 0}
	var decoded: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	if not decoded is Dictionary: return {"error": "invalid_response", "status": 0}
	decoded.status = int(response[1])
	if authenticated and int(response[1]) == 401:
		if not await _login(false): return {"error": error, "status": 401}
		return await _request_once(method, route, payload)
	return decoded

func _request_once(method: HTTPClient.Method, route: String, payload: Dictionary) -> Dictionary:
	# The second authenticated attempt must not recursively refresh.
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + access_token])
	if http.request(api_url + route, headers, method, "" if method == HTTPClient.METHOD_GET else JSON.stringify(payload)) != OK: return {"error": "connection_failed", "status": 0}
	var response: Array = await http.request_completed
	var decoded: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS or not decoded is Dictionary: return {"error": "connection_failed", "status": 0}
	decoded.status = int(response[1])
	return decoded

func _save_session() -> bool:
	return _write_session({"api_url": api_url, "player_id": player_id, "refresh_token": refresh_token, "pending": pending, "pending_auth": pending_auth, "use_db": use_db})

func _write_session(value: Dictionary) -> bool:
	var file := FileAccess.open(session_path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value))
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	return ok and DirAccess.rename_absolute(session_path + ".tmp", session_path) == OK

func _login(create: bool) -> bool:
	var result: Dictionary
	if refresh_token.is_empty():
		if not create:
			error = "session_invalid"
			return false
		result = await _request(HTTPClient.METHOD_POST, "/v1/auth/guest", {}, false)
	else:
		if pending_auth.is_empty():
			var next_token := Marshalls.raw_to_base64(Crypto.new().generate_random_bytes(32)).replace("+", "-").replace("/", "_").trim_suffix("=")
			pending_auth = {"refresh_token": refresh_token, "next_refresh_token": next_token}
			if not _save_session():
				pending_auth = {}
				error = "session_save_failed"
				return false
		result = await _request(HTTPClient.METHOD_POST, "/v1/auth/refresh", pending_auth, false)
	if result.has("error"):
		error = String(result.error)
		session_invalid = int(result.get("status", 0)) == 401
		return false
	if not result.get("access_token") is String or not result.get("refresh_token") is String or not result.get("player_id") is String:
		error = "invalid_response"
		return false
	access_token = result.access_token
	var prior_token := refresh_token
	var prior_auth := pending_auth.duplicate(true)
	refresh_token = result.refresh_token
	player_id = result.player_id
	pending_auth = {}
	if not _save_session():
		refresh_token = prior_token
		pending_auth = prior_auth
		error = "session_save_failed"
		return false
	return true

func connect_profile(url: String, local: LocalPlayerStore, new_guest := false) -> bool:
	if busy: return false
	busy = true
	connected = false
	error = ""
	session_invalid = false
	api_url = url.strip_edges().trim_suffix("/")
	use_db = true
	if not api_url.begins_with("http://") and not api_url.begins_with("https://"):
		error = "invalid_url"
		busy = false
		return false
	if new_guest:
		refresh_token = ""
		pending = {}
		pending_auth = {}
		player_id = ""
	elif FileAccess.file_exists(session_path):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(session_path))
		if not saved is Dictionary or not saved.get("refresh_token") is String or saved.get("refresh_token", "").is_empty() or not saved.get("pending", {}) is Dictionary or not saved.get("pending_auth", {}) is Dictionary:
			error = "session_invalid"
			session_invalid = true
			busy = false
			return false
		if saved.get("api_url") != api_url:
			error = "session_endpoint_mismatch"
			busy = false
			return false
		refresh_token = saved.refresh_token
		pending = saved.get("pending", {})
		pending_auth = saved.get("pending_auth", {})
		if not pending_auth.is_empty() and (pending_auth.get("refresh_token") != refresh_token or not pending_auth.get("next_refresh_token") is String):
			error = "session_invalid"
			session_invalid = true
			busy = false
			return false
	if not await _login(true):
		busy = false
		return false
	var result := await _request(HTTPClient.METHOD_GET, "/v1/profile")
	if result.get("error") == "profile_missing":
		# Use a copy so reading/migrating a v1 local file cannot modify its source.
		var candidate := local.data.duplicate(true)
		if not local.valid(candidate):
			error = "invalid_local_profile"
			busy = false
			return false
		result = await _request(HTTPClient.METHOD_POST, "/v1/profile/import", {"profile": candidate})
	var ok := _accept(result, local)
	connected = ok
	busy = false
	return ok

func choose_device_mode() -> bool:
	var saved := saved_connection()
	if saved.is_empty(): return true
	saved.use_db = false
	var ok := _write_session(saved)
	if ok:
		use_db = false
		connected = false
	return ok

func _accept(result: Dictionary, local: LocalPlayerStore) -> bool:
	if result.has("error"):
		error = String(result.error)
		return false
	if not result.get("profile") is Dictionary or not local.valid(result.profile) or not (result.get("revision") is int or result.get("revision") is float) or int(result.revision) < 1:
		error = "invalid_response"
		return false
	profile = local.migrate_profile(result.profile)
	revision = int(result.revision)
	local.data = profile.duplicate(true)
	return true

func change(action: String, payload: Dictionary, local: LocalPlayerStore) -> bool:
	if busy: return false
	if not pending.is_empty():
		error = "pending_retry_required"
		return false
	pending = {"request_id": _uuid(), "expected_revision": revision, "action": action, "payload": payload.duplicate(true)}
	if not _save_session():
		pending = {}
		error = "session_save_failed"
		return false
	return await retry(local)

func retry(local: LocalPlayerStore) -> bool:
	if busy or pending.is_empty(): return false
	busy = true
	error = ""
	var result := await _request(HTTPClient.METHOD_POST, "/v1/profile/actions", pending)
	var ok := false
	if int(result.get("status", 0)) == 200:
		# Read latest state after replay; another client may have made later changes.
		var latest := await _request(HTTPClient.METHOD_GET, "/v1/profile")
		ok = _accept(latest, local)
		if ok: pending = {}
	elif result.get("error") == "revision_conflict":
		var latest := await _request(HTTPClient.METHOD_GET, "/v1/profile")
		if _accept(latest, local): pending = {}
		error = "revision_conflict"
	else:
		error = String(result.get("error", "invalid_response"))
		if int(result.get("status", 0)) == 400: pending = {}
	if not _save_session():
		error = "session_save_failed"
		ok = false
	busy = false
	return ok

static func _uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
