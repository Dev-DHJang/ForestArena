extends SceneTree
const SERVICE := "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
const PLAYER := "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
var app
var client: MenuServiceClient
var checks := 0
var failures: Array[String] = []
var path := "user://menu-service-client-unit-%d" % Time.get_ticks_usec()
var requests: Array[Dictionary] = []
var merges: Array[Dictionary] = []
var stored_merge: Dictionary = {}
var uploaded: Dictionary = {}
var operations: Array[Dictionary] = []
var drop_merge := false
var drop_progress := false
var drop_social := false
var mutate_account := false
var source_expired := false
var service_id := SERVICE
var malformed := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func api(_url: String, method: HTTPClient.Method, route: String, payload: Dictionary, _token: String) -> Dictionary:
	requests.append({"method": method, "route": route, "payload": payload.duplicate(true)})
	if route == "/v1/service": return {"status": 200, "service_id": service_id, "protocol_version": 1}
	if route == "/v1/identity/merge":
		check(not client.identity.intent.is_empty(), "merge intent exists before HTTP")
		check(FileAccess.file_exists(path + "/menu_identity_v01.json.bak"), "merge backup exists before HTTP")
		merges.append(payload.duplicate(true))
		if mutate_account:
			app.demo_generation += 1
			return {"status": 200, "service_id": SERVICE, "canonical_player_id": PLAYER, "player_id": PLAYER, "nickname": payload.nickname, "profile": payload.profile, "revision": 1}
		if source_expired: return {"status": 409, "error": "source_authentication_required"}
		if stored_merge.is_empty():
			var profile: Dictionary = payload.profile.duplicate(true)
			profile.nickname = payload.nickname
			stored_merge = {"status": 200, "service_id": SERVICE, "canonical_player_id": PLAYER, "player_id": PLAYER, "nickname": payload.nickname, "profile": profile, "revision": 1}
		if drop_merge:
			drop_merge = false
			return {"status": 0, "error": "connection_failed"}
		return stored_merge.duplicate(true)
	if route == "/v1/progress/offline":
		for item: Dictionary in payload.events: uploaded[item.event_id] = item.duplicate(true)
		return {"status": 200, "accepted": payload.events.map(func(item: Dictionary) -> String: return item.event_id)}
	if route == "/v1/progress":
		if drop_progress: return {"status": 0, "error": "connection_failed"}
		if malformed: return {"status": 200}
		var events: Array[Dictionary] = []
		for item: Dictionary in uploaded.values(): events.append(item)
		var result := MenuFeatureStore.summarize(events)
		result.character_ids = ["ja-hyun"] if not events.is_empty() else []
		result.status = 200
		return result
	if route.begins_with("/v1/social?"): return {"status": 200, "friends": [], "incoming": [], "outgoing": [], "recent": [], "invites": [], "search": []}
	if route == "/v1/social/action":
		check(not client.identity.operations.is_empty(), "social immutable operation exists before HTTP")
		operations.append(payload.duplicate(true))
		if drop_social:
			drop_social = false
			return {"status": 0, "error": "connection_failed"}
		return {"status": 200, "request_id": "request-result"}
	if route == "/v1/presence": return {"status": 200}
	if route.begins_with("/v1/leaderboard?"): return {"status": 200, "entries": [], "own": null, "page": 0, "has_more": false}
	return {"status": 404, "error": "unknown"}
func wait_refresh() -> void:
	for index: int in 30:
		await process_frame
		if not client._refreshing: break
func run() -> void:
	DirAccess.make_dir_recursive_absolute(path)
	app = load("res://scenes/local_ai_app.tscn").instantiate()
	app.save_path = path + "/profile.json"
	app.db_session_path = path + "/db.json"
	app.demo_guest_session_path = path + "/lan.json"
	root.add_child(app)
	await process_frame
	client = app.menu_service
	client.request_adapter = api
	check(requests.is_empty(), "configure performs no network")
	check(app.store.grant_first("ja-hyun"), "test profile first grant")
	# A pre-policy profile keeps archived ownership while new selection stays playable.
	app.store.data.characters.append("myo-ryung")
	app.store.data.accessories.append("fixture-iron-armor")
	check(app.store._commit(app.store.data.duplicate(true)), "historical inventory fixture persisted")
	check(app.store.select("ja-hyun", "", "nabi"), "test selected active loadout")
	app.db_client.api_url = "http://menu.test"
	app.db_address = "http://menu.test"
	app.db_client.player_id = PLAYER
	app.db_client.refresh_token = "test-refresh"
	app.db_client.access_token = "test-access"
	app.db_client.use_db = false
	check(app.db_client._save_session(), "existing DB account proof persisted")
	var config := LocalMatchConfig.from_store(app.store)
	config.mode = LocalMatchConfig.Mode.AI
	var controller := MatchController.new()
	controller.winner_id = &"player"
	check(client.record_offline(config, controller), "actual AI finish records locally")
	check(client.record_offline(config, controller) and client.journal.progress.events.size() == 1, "duplicate hook cannot duplicate local event")
	var invalid_config := LocalMatchConfig.new()
	check(not client.record_offline(invalid_config, controller), "invalid match cannot enter durable or volatile queue")
	controller.set_meta("menu_forfeit", true)
	check(not client.record_offline(config, controller), "forfeit does not count")
	config.mode = LocalMatchConfig.Mode.PRACTICE
	controller.remove_meta("menu_forfeit")
	check(not client.record_offline(config, controller), "practice does not count")
	controller.free()
	var original_profile: Dictionary = app.store.data.duplicate(true)
	check(app.menu_store.load_presets("device", {"character": original_profile.selected_character, "accessory": original_profile.selected_accessory}), "presets loaded before integration")
	check(app.menu_store.save_controls({"joystick_mode": "floating", "button_scale": 1.1, "button_transparency": 25}), "current device controls persisted")
	var original_slots: Array = app.menu_store.slots.duplicate(true)
	drop_merge = true
	var first := await client.perform("unify", {"api_url": "http://menu.test", "nickname": "검사통합"})
	check(first.has("error") and client.has_pending_merge(), "lost successful response retains pending identity")
	check(app.store.data == original_profile and not app.db_mode, "lost response leaves current app profile unchanged")
	var request_id: String = client.identity.intent.payload.request_id
	client.configure(app)
	check(client.identity.intent.payload.request_id == request_id, "restart reads exact original merge intent")
	var replay := await client.perform("retry_identity")
	check(not replay.has("error") and not client.has_pending_merge(), "same request resumes successful merge")
	check(merges.size() == 2 and merges[0] == merges[1], "response-loss retry sends identical body and UUID")
	check(app.store.data.nickname == "검사통합" and app.store.data.selected_character == original_profile.selected_character and app.store.data.selected_accessory == original_profile.selected_accessory, "unification applies final nickname and current loadout")
	check(app.store.data.characters == original_profile.characters and app.store.data.accessories == original_profile.accessories, "unification preserves archived inventory")
	check(app.store.data.accessibility == original_profile.accessibility and app.store.data.minimap == original_profile.minimap, "unification preserves current profile settings")
	var unified: String = client.identity.binding.owner_key
	check(app.menu_store.load_presets(unified, {"character": app.store.data.selected_character, "accessory": app.store.data.selected_accessory}) and app.menu_store.slots == original_slots, "all presets copied to unified owner")
	check(app.menu_store.controls == {"joystick_mode": "floating", "button_scale": 1.1, "button_transparency": 25}, "device controls remain unchanged")
	check(client._bound(), "unified binding agrees with actual current account")
	drop_progress = true
	client.refresh_menu("mission")
	await wait_refresh()
	check(client.journal.pending_events(SERVICE, PLAYER).size() == 1 and uploaded.size() == 1, "POST acknowledged plus failed GET keeps durable event pending")
	check(client.snapshot("mission").data.stats.offline.played == 1, "failed progress GET still shows local completed match once")
	drop_progress = false
	client.refresh_menu("mission")
	await wait_refresh()
	check(client.journal.pending_events(SERVICE, PLAYER).is_empty(), "progress cache and acknowledged event commit together")
	check(client.snapshot("profile").data.stats.offline.played == 1 and client._key("profile") == client._key("mission"), "profile and mission share progress snapshot without disappearance")
	var new_controller := MatchController.new()
	new_controller.winner_id = &"player"
	config.mode = LocalMatchConfig.Mode.AI
	check(client.record_offline(config, new_controller), "second actual match saved before synchronization")
	new_controller.free()
	var blocked_file := path + "/cache-blocked"
	var block_output := FileAccess.open(blocked_file, FileAccess.WRITE)
	block_output.store_string("file prevents directory writes")
	block_output.close()
	client.journal.base_dir = blocked_file
	client.refresh_menu("profile")
	await wait_refresh()
	check(client.snapshot("profile").data.stats.offline.played == 2 and client.journal.pending_events(SERVICE, PLAYER).size() == 1, "failed atomic cache save displays old cache plus pending once")
	client.journal.base_dir = path
	client.refresh_menu("mission")
	await wait_refresh()
	check(client.journal.pending_events(SERVICE, PLAYER).is_empty() and client.snapshot("profile").data.stats.offline.played == 2, "atomic retry confirms event and shared cache together")
	malformed = true
	client.refresh_menu("profile")
	await wait_refresh()
	check(client.snapshot("profile").status == "error", "malformed successful HTTP response is error rather than empty success")
	malformed = false
	drop_social = true
	var social := await client.perform("request", {"player_id": "cccccccc-cccc-4ccc-8ccc-cccccccccccc"})
	check(social.has("error") and client.identity.operations.size() == 1, "lost friend response retains exact operation")
	var social_replay := await client.perform("retry_social")
	check(not social_replay.has("error") and client.identity.operations.is_empty(), "friend retry confirms pending operation")
	check(operations.size() == 2 and operations[0] == operations[1] and operations[0].has("operation_id"), "friend retry uses same operation ID and exact body")
	app.lan_client.active = true
	var count_before := requests.size()
	var blocked := await client.perform("accept_invite", {"invite_id": "some-invite"})
	check(blocked.has("error") and requests.size() == count_before, "active LAN prevents invitation consumption before network")
	var rename := await client.perform("nickname", {"nickname": "다른이름"})
	check(rename.has("error") and requests.size() == count_before, "active LAN prevents profile identity changes")
	app.lan_client.active = false
	# A server receipt survives a failed local profile write and credential rotation.
	stored_merge = {}
	var profile_path: String = app.store.path
	app.store.path = blocked_file + "/profile.json"
	var local_failure := await client.perform("unify", {"api_url": "http://menu.test", "nickname": "회전복구"})
	check(local_failure.has("error") and not client.identity.intent.get("response", {}).is_empty(), "local failure retains successful server receipt")
	var before_resume_posts := merges.size()
	app.db_client.refresh_token = "rotated-refresh"
	app.db_client.access_token = "rotated-access"
	check(app.db_client._save_session(), "restart fixture persists newer authenticated credentials")
	app.store.path = profile_path
	client.configure(app)
	var rotated := await client.perform("retry_identity")
	check(not rotated.has("error") and merges.size() == before_resume_posts, "cached receipt resumes without sending merge again")
	check(app.db_client.refresh_token == "rotated-refresh" and client.identity.binding.session.refresh_token == "rotated-refresh", "cached receipt cannot overwrite rotated credentials")
	# LAN-only recovery has no DB session yet. Its latest pending rotation
	# successor belongs to DemoGuestClient and must never be replaced.
	var receipt: Dictionary = stored_merge.duplicate(true)
	receipt.session = {"api_url": "http://menu.test", "player_id": PLAYER, "refresh_token": "lan-old", "access_token": "lan-old-access"}
	var pending_intent := {"service_id": SERVICE, "api_url": "http://menu.test", "payload": {"request_id": DbProfileClient._uuid(), "nickname": receipt.nickname, "profile": receipt.profile.duplicate(true)}, "primary": receipt.session.duplicate(true), "origin_owner": "device", "origin_context": "prior-process", "origin_db_player_id": "", "origin_lan_player_id": PLAYER, "slots": app.menu_store.slots.duplicate(true), "selected_slot": app.menu_store.selected_slot, "response": receipt}
	var new_identity: Dictionary = client.identity.duplicate(true)
	new_identity.binding = {}
	new_identity.intent = pending_intent
	check(client.journal.save_identity(new_identity, true), "LAN-only cached receipt persists before restart")
	DirAccess.remove_absolute(app.db_session_path)
	var lan_document := {"api_url": "http://menu.test", "player_id": PLAYER, "refresh_token": "lan-rotated", "pending_auth": {"refresh_token": "lan-rotated", "next_refresh_token": "same-lan-successor"}}
	check(app.demo_guest._write_session(lan_document), "LAN-only successor is already durable")
	app.db_mode = false
	app.db_client.refresh_token = "lan-old"
	app.db_client.access_token = "old-access"
	client.configure(app)
	var latest: Dictionary = client._latest_primary_session(PLAYER, pending_intent.primary)
	check(latest.refresh_token == "lan-rotated" and latest.pending_auth == lan_document.pending_auth, "matching LAN journal supplies exact existing rotation successor")
	check(not client._can_reuse_auth(latest), "older live DB credentials cannot bypass a rotated LAN session")
	# The authentication fixture completes that same successor; replay then
	# consumes its newest live credentials without replaying the merge.
	lan_document.refresh_token = "same-lan-successor"
	lan_document.pending_auth = {}
	check(app.demo_guest._write_session(lan_document), "LAN successor completion persisted")
	app.db_client.refresh_token = "same-lan-successor"
	app.db_client.access_token = "same-lan-successor-access"
	app.db_client.pending_auth = {}
	var merge_count := merges.size()
	var lan_resume := await client.perform("retry_identity")
	check(not lan_resume.has("error") and merges.size() == merge_count, "LAN-only cached receipt resumes locally without new merge")
	check(client.identity.binding.session.refresh_token == "same-lan-successor" and app.db_client.refresh_token == "same-lan-successor", "LAN-only newest credentials survive callback and final binding")
	app.screen = "social"
	client._active_menu = "social"
	var social_count := requests.filter(func(item: Dictionary) -> bool: return String(item.route).begins_with("/v1/social?")).size()
	client._process(10.01)
	await wait_refresh()
	check(requests.filter(func(item: Dictionary) -> bool: return String(item.route).begins_with("/v1/social?")).size() > social_count, "foreground friends view polls within ten seconds")
	app.screen = "home"
	social_count = requests.filter(func(item: Dictionary) -> bool: return String(item.route).begins_with("/v1/social?")).size()
	client._process(31.0)
	await wait_refresh()
	check(requests.filter(func(item: Dictionary) -> bool: return String(item.route).begins_with("/v1/social?")).size() == social_count, "leaving friends stops background menu polling")
	service_id = "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
	var mismatch := await client.perform("unify", {"api_url": "http://menu.test", "nickname": "다른이름"})
	check(mismatch.has("error") and not client.has_pending_merge(), "changed service ID never starts automatic merge")
	service_id = SERVICE
	stored_merge = {}
	source_expired = true
	var expired := await client.perform("unify", {"api_url": "http://menu.test", "nickname": "새통합"})
	check(expired.get("error") == "source_authentication_required" and not client.has_pending_merge(), "uncommitted expired source proof clears intent for fresh authentication")
	source_expired = false
	mutate_account = true
	var before_identity: Dictionary = app.store.data.duplicate(true)
	var late := await client.perform("unify", {"api_url": "http://menu.test", "nickname": "뒤늦은응답"})
	check(late.has("error") and app.store.data == before_identity, "late result after account generation change cannot apply profile")
	app.queue_free()
	await process_frame
	_cleanup(path)
	for failure: String in failures: push_error(failure)
	print("MENU_SERVICE_CLIENT_UNIT: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
func _cleanup(directory: String) -> void:
	var dir := DirAccess.open(directory)
	if dir == null: return
	for child: String in dir.get_directories(): _cleanup(directory.path_join(child))
	for file: String in dir.get_files(): DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
