class_name MenuServiceClient
extends Node

signal changed(menu_id: String)
const JOURNAL = preload("res://scripts/premium_menu/menu_feature_store.gd")
const ONLINE_MENUS := ["mission", "social", "rank", "profile"]
var app: Node
var journal: MenuFeatureStore
var identity: Dictionary = {"schema_version": 1, "binding": {}, "intent": {}, "operations": []}
var error := ""
var busy := false
var request_timeout := 8.0
var request_adapter: Callable
var _states: Dictionary = {}
var _generation := 0
var _active_menu := ""
var _foreground := true
var _presence_clock := 0.0
var _social_clock := 0.0
var _refreshing := false
var _params := {"search": "", "scope": "all", "page": 0}
var _volatile: Array[Dictionary] = []
var _pending_acks: Array = []

func configure(owner: Node) -> void:
	app = owner
	_generation += 1
	journal = JOURNAL.new(String(app.save_path).get_base_dir())
	if not journal.load_all(): error = journal.error
	identity = journal.identity
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

func _process(delta: float) -> void:
	if not _foreground or not _bound() or busy: return
	_presence_clock += delta
	if String(app.screen) == "social" and _active_menu == "social":
		_social_clock += delta
		if _social_clock >= 10 and not _refreshing:
			_social_clock = 0
			refresh_menu("social")
	else: _social_clock = 0
	if _presence_clock >= 30:
		_presence_clock = 0
		_heartbeat()

func _context() -> String:
	return String(app._menu_owner_key()) + ":" + str(app.db_mode) + ":" + str(app.get("demo_generation")) + ":" + String(app.db_client.api_url) + ":" + String(app.db_client.player_id)

func _account_anchor() -> String:
	return JSON.stringify([app.db_mode, app.get("demo_generation"), app.db_address, app.store.data]).sha256_text()

func _guard(generation: int, context: String) -> bool:
	return generation == _generation and is_instance_valid(app) and _context() == context

func _bound() -> bool:
	var binding: Dictionary = identity.get("binding", {})
	return not binding.is_empty() and bool(app.db_mode) and String(app.db_client.player_id) == String(binding.get("player_id", "")) and String(app._menu_owner_key()) == String(binding.get("owner_key", ""))

func has_pending_merge() -> bool:
	return not identity.get("intent", {}).is_empty()

func foreground(value: bool) -> void:
	_foreground = value
	if not is_inside_tree(): return
	_presence_clock = 0
	_retry_volatile()
	if _bound(): _heartbeat()

func _heartbeat() -> void:
	if busy: return
	await _authorized(HTTPClient.METHOD_POST, "/v1/presence", {"state": "online" if _foreground else "offline"})
	if _foreground and _active_menu in ONLINE_MENUS and String(app.screen) == _active_menu: refresh_menu(_active_menu)

func record_offline(config: LocalMatchConfig, controller: MatchController) -> bool:
	if config == null or controller == null or not config.is_valid_definition() or controller.get_meta("menu_forfeit", false): return false
	if config.mode not in [LocalMatchConfig.Mode.AI, LocalMatchConfig.Mode.SOLO, LocalMatchConfig.Mode.TEAM]: return false
	if controller.winner_id.is_empty() and not controller.is_draw: return false
	if config.participants.is_empty() or not config.participants[0].human_controlled: return false
	var event_id: String = String(controller.get_meta("menu_offline_event_id", ""))
	if event_id.is_empty():
		event_id = DbProfileClient._uuid()
		controller.set_meta("menu_offline_event_id", event_id)
	var team: StringName = config.participants[0].team_id
	var won := controller.winner_id == config.participants[0].participant_id or (not team.is_empty() and controller.winner_team_id == team)
	var binding: Dictionary = identity.get("binding", {}) if _bound() else {}
	var event := {"event_id": event_id, "owner": app._menu_owner_key(), "service_id": binding.get("service_id", ""), "canonical_player_id": binding.get("canonical_player_id", ""), "sent": false, "mode": {LocalMatchConfig.Mode.AI: "ai", LocalMatchConfig.Mode.SOLO: "solo", LocalMatchConfig.Mode.TEAM: "team"}[config.mode], "outcome": "draw" if controller.is_draw else ("win" if won else "loss"), "character_id": String(config.participants[0].selection.character_id), "ended_at": Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system())) + "Z"}
	if not journal.append_offline(event, event_id):
		error = journal.error
		if not _volatile.any(func(item: Dictionary) -> bool: return item.event_id == event_id): _volatile.append(event)
		return false
	changed.emit("mission")
	changed.emit("profile")
	return true

func _retry_volatile() -> void:
	for index: int in range(_volatile.size() - 1, -1, -1):
		if journal.append_offline(_volatile[index], _volatile[index].event_id): _volatile.remove_at(index)

func _owner_aliases() -> Array:
	var result: Array = [app._menu_owner_key()]
	if _bound():
		for owner: Variant in identity.binding.get("local_owners", []):
			if owner not in result: result.append(owner)
	return result

func _key(menu_id: String) -> String:
	if menu_id in ["mission", "profile"]: return "%s/%s/progress" % [identity.get("binding", {}).get("service_id", "local"), identity.get("binding", {}).get("canonical_player_id", app._menu_owner_key())]
	return "%s/%s/%s/%s/%s/%s" % [identity.get("binding", {}).get("service_id", "local"), identity.get("binding", {}).get("canonical_player_id", app._menu_owner_key()), menu_id, _params.scope, _params.page, _params.search]

func snapshot(menu_id: String) -> Dictionary:
	if journal == null: return {"status": "error", "error": "메뉴 기록을 아직 읽지 못했습니다.", "data": {}}
	if journal.blocked: return {"status": "error", "error": journal.error, "data": {}}
	if not _bound():
		if menu_id in ["mission", "profile"]:
			return {"status": "local", "data": journal.local_progress(_owner_aliases()), "error": error, "pending": _volatile.size(), "binding": identity.get("binding", {}), "intent": has_pending_merge()}
		return {"status": "unlinked", "data": {}, "error": error, "intent": has_pending_merge()}
	var key := _key(menu_id)
	var current: Dictionary = _states.get(key, {"status": "idle", "data": journal.progress.cache.get(key, {}), "error": ""}).duplicate(true)
	if menu_id in ["mission", "profile"]:
		var pending := journal.pending_events(identity.binding.service_id, identity.binding.canonical_player_id, [], 0)
		current.pending = pending.size() + _volatile.size()
		if current.get("data", {}).is_empty():
			current.data = journal.local_progress(_owner_aliases())
			current.local_only = true
		else:
			current.data = _include_pending(current.data, pending)
	current.binding = identity.binding.duplicate(true)
	current.intent = has_pending_merge()
	return current

func _include_pending(server: Dictionary, events: Array[Dictionary]) -> Dictionary:
	var result := server.duplicate(true)
	var local := JOURNAL.summarize(events)
	if result.get("stats") is Dictionary:
		for metric: String in ["played", "wins", "losses", "draws"]: result.stats.offline[metric] = int(result.stats.offline.get(metric, 0)) + int(local.stats.offline[metric])
	var modes: Dictionary = result.stats.get("modes", {})
	for mode: String in ["ai", "solo", "team"]:
		if not modes.has(mode): modes[mode] = JOURNAL.zero_stats()
		for metric: String in ["played", "wins", "losses", "draws"]: modes[mode][metric] = int(modes[mode].get(metric, 0)) + int(local.stats.modes[mode][metric])
	result.stats.modes = modes
	for mission: Dictionary in result.get("missions", []):
		for addition: Dictionary in local.missions:
			if mission.id == addition.id and mission.id != "all-characters":
				if mission.category in ["daily", "weekly"] and String(mission.get("period", "")) != String(addition.period):
					mission.current = 0
					mission.period = addition.period
					result.stale_period = true
				mission.current = int(mission.current) + int(addition.current)
				mission.completed = mission.current >= mission.target
	# Character completion is a set union, never an arithmetic count.
	if result.get("character_ids") is Array:
		var seen: Array = result.character_ids.duplicate()
		for event: Dictionary in events:
			if event.character_id not in seen: seen.append(event.character_id)
		for mission: Dictionary in result.get("missions", []):
			if mission.id == "all-characters":
				mission.current = seen.size()
				mission.completed = seen.size() >= int(mission.target)
	var history: Array = local.history + result.get("history", [])
	history.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.ended_at) > String(b.ended_at))
	if history.size() > 50: history.resize(50)
	result.history = history
	return result

func refresh_menu(menu_id: String) -> void:
	if menu_id not in ONLINE_MENUS: return
	_active_menu = menu_id
	if _refreshing or busy or not _bound():
		changed.emit(menu_id)
		return
	_refreshing = true
	var generation := _generation
	var context := _context()
	var key := _key(menu_id)
	_states[key] = {"status": "loading", "error": "", "data": journal.progress.cache.get(key, {})}
	changed.emit(menu_id)
	var ok := await _verify_service()
	_pending_acks = []
	if ok and menu_id in ["mission", "profile"]: ok = await _flush_offline()
	var response: Dictionary = {}
	if ok:
		var route := "/v1/progress"
		if menu_id == "social": route = "/v1/social?search=" + String(_params.search).uri_encode()
		elif menu_id == "rank": route = "/v1/leaderboard?scope=%s&page=%d" % [_params.scope, int(_params.page)]
		response = await _authorized(HTTPClient.METHOD_GET, route)
	if not _guard(generation, context):
		_refreshing = false
		return
	if ok and not response.has("error") and not _valid_snapshot(menu_id, response): response = {"error": "invalid_response"}
	if not ok or response.has("error"):
		_states[key] = {"status": "error", "error": error if not ok else _error_text(response.error), "data": journal.progress.cache.get(key, {})}
	else:
		response.erase("status")
		response.fetched_at = Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system())) + "Z"
		var committed := journal.cache_and_accept(key, response, _pending_acks, identity.binding.service_id, identity.binding.canonical_player_id) if menu_id in ["mission", "profile"] else journal.cache_response(key, response)
		if committed: _states[key] = {"status": "ready", "error": "", "data": response}
		else: _states[key] = {"status": "error", "error": journal.error, "data": journal.progress.cache.get(key, {})}
	_refreshing = false
	if menu_id in ["mission", "profile"]:
		changed.emit("mission")
		changed.emit("profile")
	else: changed.emit(menu_id)

func _valid_counter(value: Variant) -> bool:
	if not value is Dictionary: return false
	for field: String in ["played", "wins", "losses", "draws"]:
		if not value.get(field) is int and not value.get(field) is float: return false
		if float(value[field]) < 0 or float(value[field]) != floorf(float(value[field])): return false
	return true

func _valid_snapshot(menu_id: String, response: Dictionary) -> bool:
	if menu_id in ["mission", "profile"]:
		if not response.get("missions") is Array or not response.get("stats") is Dictionary or not response.get("history") is Array: return false
		if not _valid_counter(response.stats.get("offline")) or not _valid_counter(response.stats.get("lan")) or not response.stats.get("modes") is Dictionary: return false
		for counter: Variant in response.stats.modes.values():
			if not _valid_counter(counter): return false
		for mission: Variant in response.missions:
			if not mission is Dictionary: return false
			if not mission.get("id") is String or mission.get("category") not in ["daily", "weekly", "achievements"] or not mission.get("title") is String or not mission.get("completed") is bool or not mission.get("period") is String: return false
			if (not mission.get("current") is float and not mission.get("current") is int) or (not mission.get("target") is float and not mission.get("target") is int): return false
		for entry: Variant in response.history:
			if not entry is Dictionary or entry.get("source") not in ["offline", "lan"] or not entry.get("ended_at") is String: return false
		return true
	if menu_id == "social":
		for field: String in ["friends", "incoming", "outgoing", "recent", "invites", "search"]:
			if not response.get(field) is Array: return false
			for entry: Variant in response[field]:
				if not entry is Dictionary or not entry.get("player_id") is String or not entry.get("nickname") is String: return false
				if field in ["incoming", "outgoing"] and not entry.get("request_id") is String: return false
				if field == "invites" and not entry.get("invite_id") is String: return false
		return true
	if not response.get("entries") is Array or not response.get("has_more") is bool or (response.get("own") != null and not response.get("own") is Dictionary): return false
	for entry: Variant in response.entries:
		if not entry is Dictionary or not _valid_counter(entry) or not entry.get("nickname") is String or (not entry.get("rank") is float and not entry.get("rank") is int): return false
	return true

func _http(url: String, method: HTTPClient.Method, route: String, payload: Dictionary = {}, token := "") -> Dictionary:
	if request_adapter.is_valid(): return await request_adapter.call(url, method, route, payload.duplicate(true), token)
	if not is_inside_tree(): return {"error": "cancelled", "status": 0}
	var request := HTTPRequest.new()
	request.timeout = request_timeout
	add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not token.is_empty(): headers.append("Authorization: Bearer " + token)
	if request.request(url.trim_suffix("/") + route, headers, method, "" if method == HTTPClient.METHOD_GET else JSON.stringify(payload)) != OK:
		request.queue_free()
		return {"error": "connection_failed", "status": 0}
	var received: Array = await request.request_completed
	request.queue_free()
	if int(received[0]) != HTTPRequest.RESULT_SUCCESS: return {"error": "connection_failed", "status": 0}
	var parser := JSON.new()
	if parser.parse((received[3] as PackedByteArray).get_string_from_utf8()) != OK or not parser.data is Dictionary: return {"error": "invalid_response", "status": int(received[1])}
	var result: Dictionary = parser.data
	result.status = int(received[1])
	if int(received[1]) >= 400 and not result.has("error"): result.error = "http_error"
	return result

func _authorized(method: HTTPClient.Method, route: String, payload: Dictionary = {}) -> Dictionary:
	if not _bound(): return {"error": "identity_required", "status": 401}
	var generation := _generation
	var context := _context()
	if not await _ensure_primary(): return {"error": error, "status": 401}
	if not _guard(generation, context): return {"error": "account_changed", "status": 0}
	var response := await _http(identity.binding.api_url, method, route, payload, app.db_client.access_token)
	if not _guard(generation, context): return {"error": "account_changed", "status": 0}
	if int(response.get("status", 0)) == 401:
		if not await _ensure_primary(true): return {"error": error, "status": 401}
		if not _guard(generation, context): return {"error": "account_changed", "status": 0}
		response = await _http(identity.binding.api_url, method, route, payload, app.db_client.access_token)
	if not _guard(generation, context): return {"error": "account_changed", "status": 0}
	return response

func _ensure_primary(force := false) -> bool:
	if not force and not String(app.db_client.access_token).is_empty(): return true
	if app.db_client.busy:
		error = "이전 계정 요청이 끝난 뒤 다시 시도하세요."
		return false
	var session: Dictionary = app.db_client.saved_connection()
	if session.is_empty(): session = identity.binding.get("session", {}).duplicate(true)
	if not await _authenticate_db(session, force): return false
	return true

func _latest_primary_session(player_id: String, fallback: Dictionary) -> Dictionary:
	for saved: Dictionary in [app.db_client.saved_connection(), _read_session(app.demo_guest.session_path)]:
		if saved.get("player_id", "") == player_id and not String(saved.get("refresh_token", "")).is_empty(): return saved.duplicate(true)
	return fallback.duplicate(true)

func _can_reuse_auth(saved: Dictionary, force := false) -> bool:
	return not force and not String(app.db_client.access_token).is_empty() and String(app.db_client.player_id) == String(saved.get("player_id", "")) and String(app.db_client.api_url) == String(saved.get("api_url", "")) and String(app.db_client.refresh_token) == String(saved.get("refresh_token", "")) and saved.get("pending_auth", {}).is_empty() and app.db_client.pending_auth.is_empty()

func _authenticate_db(saved: Dictionary, force := false) -> bool:
	if app.db_client.busy:
		error = "이전 인증 요청이 끝난 뒤 다시 시도하세요."
		return false
	if _can_reuse_auth(saved, force): return true
	if saved.get("refresh_token", "").is_empty():
		error = "계정 인증을 복구할 수 없습니다. 저장된 계정을 확인하세요."
		return false
	var client: DbProfileClient = app.db_client
	client.api_url = String(saved.get("api_url", app.db_address))
	client.refresh_token = String(saved.refresh_token)
	client.pending_auth = saved.get("pending_auth", {}).duplicate(true)
	client.player_id = String(saved.get("player_id", client.player_id))
	client.use_db = bool(saved.get("use_db", app.db_mode))
	client.busy = true
	var ok: bool = await client._login(false)
	client.busy = false
	if not ok: error = _error_text(client.error)
	return ok

func _verify_service() -> bool:
	var response := await _http(identity.binding.api_url, HTTPClient.METHOD_GET, "/v1/service")
	if response.has("error"):
		error = _error_text(response.error)
		return false
	if response.get("service_id", "") != identity.binding.service_id:
		error = "서버의 서비스 ID가 바뀌었습니다. 다른 서버에는 자동으로 통합하거나 기록을 보내지 않습니다."
		return false
	return true

func _flush_offline() -> bool:
	var binding: Dictionary = identity.binding
	for batch: int in 20:
		var pending := journal.pending_events(binding.service_id, binding.canonical_player_id, _pending_acks)
		if pending.is_empty(): return true
		var events: Array[Dictionary] = []
		for original: Dictionary in pending:
			var event := original.duplicate(true)
			for field: String in ["owner", "service_id", "canonical_player_id", "sent"]: event.erase(field)
			events.append(event)
		var result := await _authorized(HTTPClient.METHOD_POST, "/v1/progress/offline", {"events": events})
		if result.has("error") or not result.get("accepted") is Array:
			error = _error_text(result.get("error", "invalid_response"))
			return false
		for id: Variant in result.accepted:
			if id not in _pending_acks: _pending_acks.append(id)
		if result.accepted.is_empty(): return true
	return true

func lan_session(url: String) -> Dictionary:
	if busy or has_pending_merge(): return {"error": "identity_pending"}
	if not _bound(): return {"error": "identity_required"}
	var endpoint := url.strip_edges().trim_suffix("/")
	var response := await _http(endpoint, HTTPClient.METHOD_GET, "/v1/service")
	if response.get("service_id", "") != identity.binding.service_id: return {"error": "service_mismatch"}
	if not await _ensure_primary(): return {"error": error}
	return {"access_token": app.db_client.access_token, "nickname": identity.binding.nickname}

func perform(action: String, payload: Dictionary = {}) -> Dictionary:
	if busy or _refreshing: return {"error": "busy", "message": "이전 요청을 확인 중입니다."}
	busy = true
	error = ""
	var result: Dictionary
	match action:
		"unify": result = await _unify(payload)
		"retry_identity": result = await _resume_merge()
		"refresh":
			busy = false
			refresh_menu(String(payload.get("menu_id", _active_menu)))
			return {"ok": true}
		"search":
			_params.search = String(payload.get("nickname", "")).strip_edges()
			busy = false
			refresh_menu("social")
			return {"ok": true}
		"rank_scope":
			_params.scope = String(payload.get("scope", "all"))
			_params.page = maxi(0, int(payload.get("page", 0)))
			busy = false
			refresh_menu("rank")
			return {"ok": true}
		"nickname":
			result = await _unify({"nickname": payload.get("nickname", ""), "api_url": identity.get("binding", {}).get("api_url", app.db_address)})
		"retry_social": result = await _replay_social()
		_:
			if action in ["request", "accept", "reject", "cancel", "remove", "invite", "accept_invite", "reject_invite"]: result = await _social_action(action, payload)
			else: result = {"error": "unknown_action"}
	busy = false
	if result.has("error"):
		error = String(result.get("message", _error_text(result.error)))
		result.message = error
	else:
		changed.emit("profile")
		changed.emit("social")
		changed.emit("rank")
	return result

func _session(client: Node) -> Dictionary:
	return {"api_url": client.api_url, "player_id": client.player_id, "refresh_token": client.refresh_token, "access_token": client.access_token}

func _same_service(url: String, service_id: String) -> bool:
	var result := await _http(url, HTTPClient.METHOD_GET, "/v1/service")
	if result.get("service_id", "") != service_id:
		error = "저장된 계정의 서버를 확인하지 못했습니다. 같은 서비스의 계정만 통합할 수 있습니다."
		return false
	return true

func _unify(payload: Dictionary) -> Dictionary:
	if app.lan_client.active: return {"error": "lan_active", "message": "LAN 방을 닫은 뒤 프로필 통합이나 닉네임 변경을 진행하세요."}
	if journal.blocked: return {"error": "local_save_failed", "message": journal.error}
	if has_pending_merge(): return await _resume_merge()
	var nickname := String(payload.get("nickname", "")).strip_edges()
	var url := String(payload.get("api_url", app.db_address)).strip_edges().trim_suffix("/")
	if not LocalPlayerStore.valid_nickname(nickname): return {"error": "invalid_nickname"}
	if not url.begins_with("http://") and not url.begins_with("https://"): return {"error": "invalid_url"}
	if not app.db_client.pending.is_empty() or not app.db_client.pending_auth.is_empty(): return {"error": "pending_retry_required"}
	var generation := _generation
	var context := _context()
	var anchor := _account_anchor()
	var service := await _http(url, HTTPClient.METHOD_GET, "/v1/service")
	if not _guard(generation, context): return {"error": "account_changed"}
	if service.has("error") or not service.get("service_id") is String: return {"error": service.get("error", "invalid_response")}
	if not identity.binding.is_empty() and identity.binding.service_id != service.service_id: return {"error": "service_mismatch"}
	var primary: Dictionary = {}
	var source := ""
	var db_saved: Dictionary = app.db_client.saved_connection()
	var lan_saved: Dictionary = _read_session(app.demo_guest.session_path)
	for entry: Array in [[app.db_client.session_path, db_saved], [app.demo_guest.session_path, lan_saved]]:
		if not FileAccess.file_exists(String(entry[0])): continue
		var saved_session: Dictionary = entry[1]
		for field: String in ["api_url", "player_id", "refresh_token"]:
			if not saved_session.get(field) is String or String(saved_session[field]).is_empty(): return {"error": "session_invalid"}
	if not db_saved.is_empty():
		if not await _same_service(String(db_saved.get("api_url", url)), service.service_id): return {"error": "service_mismatch", "message": error}
		if not await _authenticate_db(db_saved): return {"error": "authentication_failed", "message": error}
		primary = _session(app.db_client)
		if generation != _generation or anchor != _account_anchor(): return {"error": "account_changed"}
		context = _context()
		if not lan_saved.is_empty() and lan_saved.get("player_id") != primary.player_id:
			if not await _same_service(String(lan_saved.get("api_url", url)), service.service_id): return {"error": "service_mismatch", "message": error}
			if not await app.demo_guest.login(String(lan_saved.api_url), false): return {"error": app.demo_guest.error}
			source = String(app.demo_guest.access_token)
	else:
		var guest_url := String(lan_saved.get("api_url", url))
		if not await _same_service(guest_url, service.service_id): return {"error": "service_mismatch", "message": error}
		if not await app.demo_guest.login(guest_url, lan_saved.is_empty()): return {"error": app.demo_guest.error}
		primary = _session(app.demo_guest)
	if not _guard(generation, context): return {"error": "account_changed"}
	var owner: String = app._menu_owner_key()
	if not app.menu_store.load_presets(owner, {"character": app.store.data.selected_character, "accessory": app.store.data.selected_accessory}): return {"error": "local_save_failed", "message": app.menu_store.error}
	var body := {"request_id": DbProfileClient._uuid(), "nickname": nickname, "profile": app.store.data.duplicate(true)}
	if not source.is_empty(): body.source_access_token = source
	var intent := {"service_id": service.service_id, "api_url": url, "payload": body, "primary": primary, "origin_owner": owner, "origin_context": context, "origin_db_player_id": app.db_client.saved_connection().get("player_id", ""), "origin_lan_player_id": _read_session(app.demo_guest.session_path).get("player_id", ""), "slots": app.menu_store.slots.duplicate(true), "selected_slot": app.menu_store.selected_slot, "response": {}}
	if not journal.begin_merge(intent): return {"error": "local_save_failed", "message": journal.error}
	identity = journal.identity
	return await _resume_merge()

func _read_session(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary: return {}
	return parser.data

func _resume_merge() -> Dictionary:
	if not has_pending_merge(): return {"error": "no_pending_identity"}
	var intent: Dictionary = identity.intent.duplicate(true)
	var generation := _generation
	var context := _context()
	var saved_db: Dictionary = app.db_client.saved_connection()
	var saved_lan: Dictionary = _read_session(app.demo_guest.session_path)
	var primary_id: String = String(intent.primary.player_id)
	var allowed_db: Array = [String(intent.get("origin_db_player_id", primary_id)), primary_id]
	var allowed_lan: Array = [String(intent.get("origin_lan_player_id", saved_lan.get("player_id", ""))), primary_id]
	if String(saved_db.get("player_id", "")) not in allowed_db or String(saved_lan.get("player_id", "")) not in allowed_lan: return {"error": "account_changed"}
	if app.db_mode and not String(app.db_client.player_id).is_empty() and String(app.db_client.player_id) != primary_id: return {"error": "account_changed"}
	var service := await _http(intent.api_url, HTTPClient.METHOD_GET, "/v1/service")
	if service.get("service_id", "") != intent.service_id: return {"error": "service_mismatch"}
	if not _guard(generation, context): return {"error": "account_changed"}
	var primary: Dictionary = intent.primary.duplicate(true)
	var response: Dictionary = intent.get("response", {}).duplicate(true)
	if response.is_empty():
		var saved := _latest_primary_session(primary_id, primary)
		var refreshed: bool = String(saved.get("refresh_token", "")) != String(primary.get("refresh_token", "")) or not saved.get("pending_auth", {}).is_empty()
		if String(saved.get("api_url", intent.api_url)) != String(intent.api_url):
			if not await _same_service(String(saved.api_url), intent.service_id): return {"error": "service_mismatch", "message": error}
			if not _guard(generation, context): return {"error": "account_changed"}
		primary.merge(saved, true)
		if refreshed: primary.access_token = ""
		if String(primary.get("access_token", "")).is_empty():
			var replay_anchor := _account_anchor()
			if not await _authenticate_db(primary): return {"error": "authentication_failed", "message": error}
			if generation != _generation or replay_anchor != _account_anchor(): return {"error": "account_changed"}
			primary = _session(app.db_client)
			context = _context()
		response = await _http(intent.api_url, HTTPClient.METHOD_POST, "/v1/identity/merge", intent.payload, primary.access_token)
		if int(response.get("status", 0)) == 401:
			var refresh_anchor := _account_anchor()
			if not await _authenticate_db(primary, true): return {"error": "authentication_failed", "message": error}
			if generation != _generation or refresh_anchor != _account_anchor(): return {"error": "account_changed"}
			primary = _session(app.db_client)
			context = _context()
			response = await _http(intent.api_url, HTTPClient.METHOD_POST, "/v1/identity/merge", intent.payload, primary.access_token)
		if not _guard(generation, context): return {"error": "account_changed"}
		if response.has("error"):
			if response.error in ["source_authentication_required", "nickname_taken", "invalid_nickname", "invalid_profile"]:
				if journal.finish_merge(identity.binding): identity = journal.identity
			return response
		if response.get("service_id") != intent.service_id or not response.get("profile") is Dictionary or not app.store.valid(response.profile) or not response.get("canonical_player_id") is String: return {"error": "invalid_response"}
		response.session = primary.duplicate(true)
		response.session.api_url = intent.api_url
		if not journal.save_receipt(response): return {"error": "local_save_failed", "message": journal.error}
		identity = journal.identity
	var latest := _latest_primary_session(primary_id, intent.primary)
	if not await _same_service(String(latest.get("api_url", intent.api_url)), intent.service_id): return {"error": "service_mismatch", "message": error}
	if not _guard(generation, context): return {"error": "account_changed"}
	var auth_anchor := _account_anchor()
	if not await _authenticate_db(latest): return {"error": "authentication_failed", "message": error}
	if generation != _generation or auth_anchor != _account_anchor(): return {"error": "account_changed"}
	context = _context()
	response.session = _session(app.db_client)
	response.session.api_url = intent.api_url
	response.profile = app.store.migrate_profile(response.profile)
	var owner := "unified:%s:%s" % [response.service_id, response.canonical_player_id]
	if not app.menu_store.import_owner_snapshot(owner, intent.slots, int(intent.selected_slot)): return {"error": "local_save_failed", "message": app.menu_store.error}
	if not _guard(generation, context): return {"error": "account_changed"}
	var accepted: bool = await app.apply_unified_identity(response)
	if not accepted: return {"error": "local_save_failed", "message": "서버 통합은 확인했지만 기기 저장이 끝나지 않았습니다. 같은 요청으로 다시 확인하세요."}
	var aliases: Array = identity.binding.get("local_owners", []).duplicate()
	if intent.origin_owner not in aliases: aliases.append(intent.origin_owner)
	if owner not in aliases: aliases.append(owner)
	if not journal.bind_events(aliases, response.service_id, response.canonical_player_id): return {"error": "local_save_failed", "message": journal.error}
	var binding := {"service_id": response.service_id, "api_url": intent.api_url, "player_id": response.session.player_id, "canonical_player_id": response.canonical_player_id, "nickname": response.nickname, "session": response.session.duplicate(true), "owner_key": owner, "local_owners": aliases}
	if not journal.finish_merge(binding): return {"error": "local_save_failed", "message": journal.error}
	identity = journal.identity
	_generation += 1
	_states.clear()
	return {"ok": true, "nickname": response.nickname, "player_id": response.canonical_player_id}

func _social_action(action: String, payload: Dictionary) -> Dictionary:
	if action == "accept_invite" and (app.lan_client.active or is_instance_valid(app.match_scene)): return {"error": "lan_active", "message": "현재 대전을 끝내거나 LAN 방을 닫은 뒤 초대를 수락하세요."}
	if not _bound(): return {"error": "identity_required"}
	if not identity.operations.is_empty(): return {"error": "pending_social"}
	var body := payload.duplicate(true)
	body.action = action
	body.operation_id = DbProfileClient._uuid()
	var operation := {"operation_id": body.operation_id, "service_id": identity.binding.service_id, "canonical_player_id": identity.binding.canonical_player_id, "api_url": identity.binding.api_url, "payload": body}
	if not journal.add_operation(operation): return {"error": "local_save_failed", "message": journal.error}
	identity = journal.identity
	return await _replay_social()

func _replay_social() -> Dictionary:
	if not _bound(): return {"error": "identity_required"}
	if identity.operations.is_empty(): return {"error": "no_pending_social"}
	var operation: Dictionary = identity.operations[0]
	if operation.payload.action == "accept_invite" and (app.lan_client.active or is_instance_valid(app.match_scene)): return {"error": "lan_active", "message": "현재 대전을 끝내거나 LAN 방을 닫은 뒤 초대를 다시 확인하세요."}
	if operation.service_id != identity.binding.service_id or operation.canonical_player_id != identity.binding.canonical_player_id: return {"error": "account_changed"}
	if not await _verify_service(): return {"error": "service_mismatch", "message": error}
	var result := await _authorized(HTTPClient.METHOD_POST, "/v1/social/action", operation.payload)
	if result.has("error"):
		if int(result.get("status", 0)) >= 400 and int(result.get("status", 0)) < 500 and int(result.get("status", 0)) not in [401, 408, 429]:
			journal.remove_operation(operation.operation_id)
			identity = journal.identity
		return result
	if not journal.remove_operation(operation.operation_id): return {"error": "local_save_failed", "message": journal.error}
	identity = journal.identity
	if operation.payload.action == "accept_invite" and result.get("invite_code") is String:
		if not app.join_menu_invite(result.invite_code): return {"error": "join_failed"}
	return result

func _error_text(code: Variant) -> String:
	var messages := {"connection_failed": "서버에 연결하지 못했습니다. 주소와 연결을 확인하고 다시 시도하세요.", "invalid_response": "서버 응답을 읽을 수 없습니다.", "service_mismatch": "다른 서비스에는 자동으로 통합하지 않습니다. 기존 서버 주소를 확인하세요.", "identity_required": "먼저 프로필에서 계정을 연결하세요.", "invalid_nickname": "닉네임은 공백을 제외한 1~12자로 입력하세요.", "nickname_taken": "이미 사용 중인 닉네임입니다. 다른 이름을 입력하세요.", "account_changed": "계정이 바뀌어 이전 응답을 적용하지 않았습니다.", "pending_retry_required": "이전 DB 저장 요청을 먼저 다시 확인하세요.", "pending_social": "이전 친구 요청의 처리 결과를 먼저 다시 확인하세요.", "invalid_url": "올바른 서버 주소를 입력하세요.", "session_invalid": "계정을 다시 인증해야 합니다.", "session_save_failed": "계정 인증 저장에 실패했습니다. 저장 공간을 확인하세요.", "source_authentication_required": "원본 계정을 다시 인증해야 합니다. 통합을 다시 시도하세요.", "already_friends": "이미 친구로 등록되어 있습니다.", "stale_request": "이 친구 요청은 이미 처리되었거나 만료되었습니다.", "stale_invite": "이 대전 초대는 이미 처리되었거나 만료되었습니다.", "room_not_waiting": "이 LAN 방은 더 이상 대기 중이 아닙니다.", "request_pending": "이미 친구 요청을 확인 중입니다.", "join_failed": "초대는 수락했지만 LAN 방에 참가하지 못했습니다. 기존 방을 닫고 다시 확인하세요."}
	return String(messages.get(String(code), "요청을 처리하지 못했습니다. 다시 시도하세요. (%s)" % String(code)))
