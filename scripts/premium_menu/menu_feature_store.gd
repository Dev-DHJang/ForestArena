class_name MenuFeatureStore
extends RefCounted

## Versioned menu journals do not change the existing player profile schema.
var base_dir: String
var error := ""
var blocked := false
var identity: Dictionary = {"schema_version": 1, "binding": {}, "intent": {}, "operations": []}
var progress: Dictionary = {"schema_version": 1, "events": [], "recorded_matches": [], "cache": {}}

func _init(directory := "user://") -> void:
	base_dir = directory

func load_all() -> bool:
	error = ""
	var first := _load("menu_identity_v01.json", identity)
	var second := _load("menu_progress_v01.json", progress)
	if first.is_empty() or second.is_empty():
		blocked = true
		return false
	blocked = false
	identity = first
	progress = second
	return true

func _valid(value: Dictionary, kind: String) -> bool:
	if value.get("schema_version") != 1: return false
	if kind == "identity":
		return value.get("binding") is Dictionary and value.get("intent") is Dictionary and value.get("operations") is Array
	return value.get("events") is Array and value.get("recorded_matches") is Array and value.get("cache") is Dictionary and value.events.all(func(item: Variant) -> bool: return _valid_event(item))

func _valid_event(value: Variant) -> bool:
	if not value is Dictionary: return false
	return value.get("event_id") is String and value.get("owner") is String and value.get("service_id") is String and value.get("canonical_player_id") is String and value.get("sent") is bool and value.get("mode") in ["ai", "solo", "team"] and value.get("outcome") in ["win", "loss", "draw"] and value.get("character_id") in ["ja-hyun", "myo-ryung", "nabi", "yu-ran"] and value.get("ended_at") is String

func _read(path: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary: return {}
	return parser.data

func _load(file: String, fallback: Dictionary) -> Dictionary:
	var path := base_dir.path_join(file)
	var kind := "identity" if file.contains("identity") else "progress"
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"): return fallback.duplicate(true)
	var candidate := _read(path) if FileAccess.file_exists(path) else {}
	if candidate.has("schema_version") and candidate.schema_version != 1:
		error = "지원하지 않는 메뉴 기록 버전입니다. 기존 파일을 유지했습니다."
		return {}
	if _valid(candidate, kind): return candidate
	if FileAccess.file_exists(path + ".bak"):
		candidate = _read(path + ".bak")
		if _valid(candidate, kind): return candidate
	error = "메뉴 기록과 백업을 읽을 수 없습니다. 저장 공간을 확인하세요."
	return {}

func _save(file: String, value: Dictionary, journal_backup := false) -> bool:
	if blocked:
		error = "메뉴 기록을 읽지 못해 저장을 중지했습니다. 원본과 백업을 복구한 뒤 다시 시도하세요."
		return false
	error = ""
	var kind := "identity" if file.contains("identity") else "progress"
	if not _valid(value, kind):
		error = "메뉴 기록 형식이 올바르지 않습니다."
		return false
	if FileAccess.file_exists(base_dir) or (not DirAccess.dir_exists_absolute(base_dir) and DirAccess.make_dir_recursive_absolute(base_dir) != OK): return _failed()
	var path := base_dir.path_join(file)
	var previous := _read(path) if FileAccess.file_exists(path) else {}
	if previous.has("schema_version") and previous.schema_version != 1:
		error = "지원하지 않는 메뉴 기록 버전입니다. 기존 파일을 유지했습니다."
		return false
	var temporary := path + ".tmp"
	var output := FileAccess.open(temporary, FileAccess.WRITE)
	if output == null: return _failed()
	output.store_string(JSON.stringify(value))
	output.flush()
	var ok := output.get_error() == OK
	output.close()
	if not ok or not _valid(_read(temporary), kind): return _failed()
	if _valid(previous, kind) and DirAccess.copy_absolute(path, path + ".bak") != OK: return _failed()
	if DirAccess.rename_absolute(temporary, path) != OK: return _failed()
	# The network may only start once the same immutable intent has two copies.
	if journal_backup and DirAccess.copy_absolute(path, path + ".bak") != OK: return _failed()
	return true

func _failed() -> bool:
	error = "메뉴 기록 저장에 실패했습니다. 저장 공간을 확인하고 다시 시도하세요."
	return false

func save_identity(next: Dictionary, backup := false) -> bool:
	if not _save("menu_identity_v01.json", next, backup): return false
	identity = _read(base_dir.path_join("menu_identity_v01.json"))
	return true

func save_progress(next: Dictionary) -> bool:
	if not _save("menu_progress_v01.json", next): return false
	progress = next.duplicate(true)
	return true

func begin_merge(intent: Dictionary) -> bool:
	if not identity.intent.is_empty():
		error = "이전 프로필 통합을 먼저 다시 확인하세요."
		return false
	var next := identity.duplicate(true)
	next.intent = intent.duplicate(true)
	return save_identity(next, true)

func save_receipt(response: Dictionary) -> bool:
	var next := identity.duplicate(true)
	next.intent.response = response.duplicate(true)
	return save_identity(next, true)

func finish_merge(binding: Dictionary) -> bool:
	var next := identity.duplicate(true)
	next.binding = binding.duplicate(true)
	next.intent = {}
	return save_identity(next, true)

func append_offline(event: Dictionary, match_key: String) -> bool:
	if match_key in progress.recorded_matches: return true
	if not _valid_event(event): return false
	var next := progress.duplicate(true)
	next.events.append(event.duplicate(true))
	next.recorded_matches.append(match_key)
	return save_progress(next)

func bind_events(owners: Array, service_id: String, canonical_id: String) -> bool:
	var next := progress.duplicate(true)
	for event: Dictionary in next.events:
		if event.owner in owners and event.service_id.is_empty():
			event.service_id = service_id
			event.canonical_player_id = canonical_id
	return save_progress(next)

func pending_events(service_id: String, canonical_id: String, excluding: Array = [], limit := 50) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in progress.events:
		if not event.sent and event.service_id == service_id and event.canonical_player_id == canonical_id and event.event_id not in excluding:
			result.append(event.duplicate(true))
			if limit > 0 and result.size() >= limit: break
	return result

func accept_events(ids: Array, service_id: String, canonical_id: String) -> bool:
	var next := progress.duplicate(true)
	for event: Dictionary in next.events:
		if event.event_id in ids and event.service_id == service_id and event.canonical_player_id == canonical_id: event.sent = true
	return save_progress(next)

func cache_response(key: String, value: Dictionary) -> bool:
	var next := progress.duplicate(true)
	next.cache[key] = value.duplicate(true)
	return save_progress(next)

func cache_and_accept(key: String, value: Dictionary, accepted: Array, service_id: String, canonical_id: String) -> bool:
	var next := progress.duplicate(true)
	next.cache[key] = value.duplicate(true)
	for event: Dictionary in next.events:
		if event.event_id in accepted and event.service_id == service_id and event.canonical_player_id == canonical_id: event.sent = true
	return save_progress(next)

func add_operation(operation: Dictionary) -> bool:
	var next := identity.duplicate(true)
	next.operations.append(operation.duplicate(true))
	return save_identity(next, true)

func remove_operation(operation_id: String) -> bool:
	var next := identity.duplicate(true)
	for index: int in range(next.operations.size() - 1, -1, -1):
		if next.operations[index].operation_id == operation_id: next.operations.remove_at(index)
	return save_identity(next, true)

static func zero_stats() -> Dictionary:
	return {"played": 0, "wins": 0, "losses": 0, "draws": 0}

func local_progress(owners: Array, pending_only := false, service_id := "", canonical_id := "") -> Dictionary:
	var selected: Array[Dictionary] = []
	for event: Dictionary in progress.events:
		if event.owner not in owners: continue
		if pending_only and (event.sent or event.service_id != service_id or event.canonical_player_id != canonical_id): continue
		selected.append(event)
	return summarize(selected)

static func summarize(events: Array[Dictionary], now := -1) -> Dictionary:
	var clock: int = int(Time.get_unix_time_from_system()) if now < 0 else int(now)
	var offline := zero_stats()
	var modes := {"ai": zero_stats(), "solo": zero_stats(), "team": zero_stats()}
	var daily := zero_stats()
	var weekly := zero_stats()
	var characters := {}
	var today := int(floor((clock + 32400) / 86400.0))
	var monday := today - posmod(today + 3, 7)
	var history: Array = []
	for event: Dictionary in events:
		var ended := int(Time.get_unix_time_from_datetime_string(String(event.ended_at).trim_suffix("Z")))
		var day := int(floor((ended + 32400) / 86400.0))
		_tally(offline, event.outcome)
		_tally(modes[event.mode], event.outcome)
		if day == today: _tally(daily, event.outcome)
		if day >= monday and day <= today: _tally(weekly, event.outcome)
		characters[event.character_id] = true
		history.push_front({"source": "offline", "mode": event.mode, "outcome": event.outcome, "character_id": event.character_id, "ended_at": event.ended_at, "match_id": event.event_id})
	if history.size() > 50: history.resize(50)
	var missions: Array[Dictionary] = []
	for row: Array in [["daily-play", "daily", "하루 한 경기 완료", daily.played, 1, Time.get_date_string_from_unix_time(today * 86400)], ["daily-win", "daily", "하루 첫 승리", daily.wins, 1, Time.get_date_string_from_unix_time(today * 86400)], ["weekly-play", "weekly", "한 주에 다섯 경기 완료", weekly.played, 5, Time.get_date_string_from_unix_time(monday * 86400)], ["weekly-win", "weekly", "한 주에 세 번 승리", weekly.wins, 3, Time.get_date_string_from_unix_time(monday * 86400)], ["first-play", "achievements", "첫 경기 완료", offline.played, 1, "all"], ["ten-play", "achievements", "열 경기 완료", offline.played, 10, "all"], ["all-characters", "achievements", "네 캐릭터로 경기 완료", characters.size(), 4, "all"]]:
		missions.append({"id": row[0], "category": row[1], "title": row[2], "current": int(row[3]), "target": int(row[4]), "completed": int(row[3]) >= int(row[4]), "period": row[5]})
	return {"missions": missions, "stats": {"offline": offline, "lan": zero_stats(), "modes": modes}, "modes": modes, "history": history, "sync_status": "local"}

static func _tally(stats: Dictionary, outcome: String) -> void:
	stats.played += 1
	stats[{"win": "wins", "loss": "losses", "draw": "draws"}[outcome]] += 1
