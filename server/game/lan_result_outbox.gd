class_name LanResultOutbox
extends Node

## Only the match server can submit these jobs. The service token is never saved.
signal sync_changed(match_id: String, state: String)
const SCHEMA_VERSION := 1
var storage_path := "user://lan_result_outbox_v01.json"
var api_url := ""
var service_token := ""
var jobs: Array[Dictionary] = []
var error := ""
var ready_to_send := false
var _request: HTTPRequest
var _active_id := ""
var _next_attempt_msec := 0
var _failures := 0
var _dirty := false

func configure(endpoint: String, token: String, path: String = "") -> bool:
	api_url = endpoint.trim_suffix("/")
	service_token = token
	if not path.is_empty(): storage_path = path
	if not _load(): return false
	ready_to_send = true
	return true

func enqueue(route: String, payload: Dictionary, match_id: String = "") -> bool:
	if not ready_to_send: return false
	var job := {"id": DbProfileClient._uuid(), "route": route, "payload": payload.duplicate(true), "match_id": match_id, "endpoint": api_url, "failed": false}
	jobs.append(job)
	_dirty = true
	var saved := _save()
	if saved: _dirty = false
	else: sync_changed.emit(match_id, "save_failed")
	return saved

func state_for(match_id: String) -> String:
	for job: Dictionary in jobs:
		if String(job.match_id) == match_id:
			if _dirty: return "save_failed"
			return "failed" if job.failed else "pending"
	return "stored"

func _process(_delta: float) -> void:
	if not ready_to_send or _request != null or Time.get_ticks_msec() < _next_attempt_msec: return
	if _dirty:
		if not _save():
			_next_attempt_msec = Time.get_ticks_msec() + 5000
			return
		_dirty = false
	for job: Dictionary in jobs:
		# A malformed registration must not let its result overtake it.
		if bool(job.failed) or _blocked(job): continue
		_request = HTTPRequest.new()
		_request.timeout = 8.0
		add_child(_request)
		_active_id = String(job.id)
		_request.request_completed.connect(_completed, CONNECT_ONE_SHOT)
		var started := _request.request(String(job.endpoint) + String(job.route), ["Content-Type: application/json", "x-forest-arena-service-token: " + service_token], HTTPClient.METHOD_POST, JSON.stringify(job.payload))
		if started != OK: _completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
		return

func _blocked(job: Dictionary) -> bool:
	if String(job.match_id).is_empty(): return false
	for earlier: Dictionary in jobs:
		if earlier.id == job.id: return false
		if earlier.match_id == job.match_id: return true
	return false

func _completed(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _request != null:
		_request.queue_free()
		_request = null
	var index := -1
	for position: int in jobs.size():
		if jobs[position].id == _active_id: index = position
	if index < 0: return
	var job: Dictionary = jobs[index]
	var parser := JSON.new()
	var decoded: Variant = parser.data if parser.parse(body.get_string_from_utf8()) == OK else null
	var succeeded: bool = result == HTTPRequest.RESULT_SUCCESS and status >= 200 and status < 300 and decoded is Dictionary and not decoded.has("error")
	if succeeded:
		jobs.remove_at(index)
		_failures = 0
		_next_attempt_msec = 0
		_dirty = not _save()
		if _dirty:
			error = "outbox_save_failed"
			sync_changed.emit(String(job.match_id), "save_failed")
		else:
			error = ""
			sync_changed.emit(String(job.match_id), state_for(String(job.match_id)))
	else:
		_failures += 1
		# Keep a rejected job and its dependent result for diagnosis/retry.
		# Temporary errors use capped backoff; permanent input/auth errors pause.
		if status >= 400 and status < 500 and status not in [408, 429]:
			jobs[index].failed = true
			_dirty = not _save()
			sync_changed.emit(String(job.match_id), "failed")
		else:
			sync_changed.emit(String(job.match_id), "pending")
		error = "http_%d" % status if status > 0 else "connection_failed"
		_next_attempt_msec = Time.get_ticks_msec() + mini(60, int(pow(2, mini(_failures, 6)))) * 1000
		print("FOREST_ARENA_LAN_SYNC " + JSON.stringify({"state": "failed" if bool(jobs[index].failed) else "pending", "status": status, "match_id": job.match_id}))
	_active_id = ""

func retry_failed() -> bool:
	for job: Dictionary in jobs: job.failed = false
	_dirty = true
	_next_attempt_msec = 0
	var saved := _save()
	if saved: _dirty = false
	return saved

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return {}
	return parser.data if parser.data is Dictionary else {}

func _valid(value: Dictionary) -> bool:
	if value.get("schema_version", 0) != SCHEMA_VERSION or not value.get("jobs") is Array: return false
	for job: Variant in value.jobs:
		if not job is Dictionary: return false
		for key: String in ["id", "route", "match_id", "endpoint"]:
			if not job.get(key) is String: return false
		if not job.get("payload") is Dictionary or not job.get("failed") is bool: return false
		if not String(job.route).begins_with("/internal/v1/lan/") or job.endpoint != api_url: return false
	return true

func _load() -> bool:
	if not FileAccess.file_exists(storage_path) and not FileAccess.file_exists(storage_path + ".bak"): return true
	var value := _read(storage_path)
	if value.has("schema_version") and value.schema_version != SCHEMA_VERSION:
		error = "unsupported_outbox_version"
		return false
	if not _valid(value): value = _read(storage_path + ".bak")
	if not _valid(value):
		error = "outbox_invalid_or_different_service"
		return false
	jobs.clear()
	for job: Dictionary in value.jobs: jobs.append(job.duplicate(true))
	# Explicit restart retries paused requests with the same payload and IDs.
	for job: Dictionary in jobs: job.failed = false
	return true

func _save() -> bool:
	var document := {"schema_version": SCHEMA_VERSION, "jobs": jobs}
	if not _valid(document):
		error = "outbox_invalid"
		return false
	var directory := storage_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory) and DirAccess.make_dir_recursive_absolute(directory) != OK: return false
	var previous := _read(storage_path)
	if previous.has("schema_version") and previous.schema_version != SCHEMA_VERSION: return false
	var file := FileAccess.open(storage_path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(document))
	file.flush()
	var saved := file.get_error() == OK
	file.close()
	if not saved or not _valid(_read(storage_path + ".tmp")): return false
	if _valid(previous) and DirAccess.copy_absolute(storage_path, storage_path + ".bak") != OK: return false
	if DirAccess.rename_absolute(storage_path + ".tmp", storage_path) != OK: return false
	return true
