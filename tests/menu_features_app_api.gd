extends SceneTree
# Independent actual LocalAiApp -> HTTPRequest -> API -> isolated PostgreSQL.
var app
var client: MenuServiceClient
var checks: Array[Dictionary] = []
var directory := "user://qa/menu_features_actual_%d" % Time.get_ticks_usec()
var base := OS.get_environment("FOREST_ARENA_QA_API_URL")
var native_capture := "--ui-capture-connected" in OS.get_cmdline_user_args()
var capture_records: Array[Dictionary] = []
const CAPTURE_OUTPUT := "res://_workspace/premium-menu-features-v01/qa-connected-captures"
var original_hashes: Dictionary = {}
var primary: Dictionary = {}
var friend: Dictionary = {}
var nickname := "qa" + str(Time.get_ticks_usec()).right(9)
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"name": label, "pass": ok})
	if not ok: push_error(label)
func create_app() -> void:
	app = load("res://scenes/local_ai_app.tscn").instantiate()
	app.save_path = directory + "/profile.json"
	app.db_session_path = directory + "/db.json"
	app.demo_guest_session_path = directory + "/lan.json"
	root.add_child(app)
	await process_frame
	client = app.menu_service
func http(route: String, method := HTTPClient.METHOD_GET, body: Dictionary = {}, token := "", internal := false) -> Dictionary:
	if not internal: return await client._http(base, method, route, body, token)
	var request := HTTPRequest.new()
	request.timeout = 8
	root.add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json", "x-forest-arena-service-token: " + OS.get_environment("FOREST_ARENA_QA_SERVICE_TOKEN")])
	if request.request(base + route, headers, method, JSON.stringify(body)) != OK:
		request.queue_free()
		return {"error": "request_start_failed"}
	var response: Array = await request.request_completed
	request.queue_free()
	var value: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	if not value is Dictionary: return {"error": "invalid_json"}
	value.status = response[1]
	return value
func refresh(menu: String) -> Dictionary:
	client.refresh_menu(menu)
	for tick: int in 600:
		await create_timer(0.02).timeout
		if not client._refreshing: break
	var value := client.snapshot(menu)
	check(value.status == "ready", "actual " + menu + " response validates as ready")
	return value.get("data", {})
func finish_local(mode: LocalMatchConfig.Mode, winner: StringName, forfeit := false) -> bool:
	var config := LocalMatchConfig.from_store(app.store)
	config.mode = mode
	var controller := MatchController.new()
	controller.winner_id = winner
	if forfeit: controller.set_meta("menu_forfeit", true)
	var result := client.record_offline(config, controller)
	controller.free()
	return result
func run() -> void:
	if not base.begins_with("http://127.0.0.1:") or not OS.get_environment("FOREST_ARENA_QA_DATABASE_URL").contains("/forest_menu_qa_"):
		push_error("Explicit isolated QA environment required")
		quit(2)
		return
	original_hashes = ordinary_hashes()
	DirAccess.make_dir_recursive_absolute(directory)
	await create_app()
	check(not client.request_adapter.is_valid(), "actual HTTP client has no mock adapter")
	check(app.store.grant_first("ja-hyun"), "isolated current profile first grant")
	check(app.store.purchase("fixture-iron-armor"), "isolated current accessory")
	check(app.store.select("ja-hyun", "fixture-iron-armor", "myo-ryung"), "current selected loadout")
	var local: Dictionary = app.store.data.duplicate(true)
	check(app.menu_store.load_presets("device", {"character": local.selected_character, "accessory": local.selected_accessory}), "load current owner presets")
	check(app.menu_store.save_slot(3, "ja-hyun", "fixture-iron-armor") and app.menu_store.set_active_slot(3), "fourth preset selected")
	check(app.menu_store.save_controls({"joystick_mode":"floating", "button_scale":1.1, "button_transparency":25}), "persist device controls")
	var slots: Array = app.menu_store.slots.duplicate(true)
	primary = await http("/v1/auth/guest", HTTPClient.METHOD_POST)
	check(primary.get("status") == 201, "actual DB guest created")
	var db_profile: Dictionary = local.duplicate(true)
	db_profile.characters = ["nabi"]
	db_profile.selected_character = "nabi"
	var imported := await http("/v1/profile/import", HTTPClient.METHOD_POST, {"profile":db_profile}, primary.access_token)
	check(imported.get("status") == 200, "separate DB character profile imported")
	app.db_client.api_url = base
	app.db_address = base
	app.db_client.player_id = primary.player_id
	app.db_client.access_token = primary.access_token
	app.db_client.refresh_token = primary.refresh_token
	app.db_client.use_db = false
	check(app.db_client._save_session(), "existing DB primary session persisted in isolated directory")
	check(await app.demo_guest.login(base, true), "separate LAN guest authenticated")
	var source_id: String = app.demo_guest.player_id
	var lan_profile: Dictionary = local.duplicate(true)
	lan_profile.characters = ["yu-ran"]
	lan_profile.selected_character = "yu-ran"
	check((await http("/v1/profile/import", HTTPClient.METHOD_POST, {"profile":lan_profile}, app.demo_guest.access_token)).get("status") == 200, "separate LAN source profile imported")
	check(finish_local(LocalMatchConfig.Mode.AI, &"player"), "real service records completed AI event before linking")
	check(not finish_local(LocalMatchConfig.Mode.PRACTICE, &"player") and not finish_local(LocalMatchConfig.Mode.STORY, &"player") and not finish_local(LocalMatchConfig.Mode.AI, &"player", true), "practice story and forfeit excluded")
	check(client.snapshot("mission").status == "local" and client.snapshot("social").status == "unlinked", "offline progress and unlinked social separated")
	# Server commits, but the current profile cannot finish its local rename path.
	DirAccess.make_dir_absolute(app.save_path + ".tmp")
	var interrupted := await client.perform("unify", {"api_url":base, "nickname":nickname})
	check(interrupted.get("error") == "local_save_failed" and client.has_pending_merge() and not client.identity.intent.response.is_empty(), "real server receipt survives partial local callback failure")
	check(app.store.data == local and not app.db_mode, "failed local callback preserves current in-memory account")
	var receipt_refresh: String = client.identity.intent.response.session.refresh_token
	DirAccess.remove_absolute(app.save_path + ".tmp")
	app.queue_free()
	await process_frame
	await process_frame
	await create_app()
	for tick: int in 600:
		await create_timer(0.02).timeout
		if not app.db_client.busy and app.db_client.connected: break
	var rotated_refresh: String = app.db_client.refresh_token
	check(app.db_client.connected and rotated_refresh != receipt_refresh, "restart authenticates saved primary and rotates real refresh token before resume")
	check(client.has_pending_merge() and not client.identity.intent.response.is_empty(), "restart reloads immutable successful server receipt")
	var unified := await client.perform("retry_identity")
	check(not unified.has("error") and client._bound(), "actual cached receipt finishes app callback and durable binding")
	check(app.db_client.refresh_token == rotated_refresh and app.db_client.saved_connection().refresh_token == rotated_refresh, "cached receipt never restores stale refresh token after restart authentication")
	if unified.has("error"):
		await finish()
		return
	check(app.db_client.player_id == primary.player_id and app.demo_guest.player_id == primary.player_id and primary.player_id != source_id, "existing DB primary wins and LAN consumer switches same owner")
	check(app.store.owns("ja-hyun") and app.store.owns("nabi") and app.store.owns("yu-ran"), "local DB LAN ownership union reaches real app store")
	check(app.store.data.selected_character == local.selected_character and app.store.data.accessibility == local.accessibility and app.store.data.minimap == local.minimap, "current selection and settings survive actual merge")
	check(app.menu_store.load_presets(app._menu_owner_key(), {"character":app.store.data.selected_character, "accessory":app.store.data.selected_accessory}), "open unified owner preset storage after restart")
	check(app.menu_store.slots == slots and app.menu_store.selected_slot == 3 and app.menu_store.controls.joystick_mode == "floating", "four presets active slot and controls survive actual merge")
	var data := await refresh("mission")
	check(data.get("stats", {}).get("offline", {}).get("played") == 1 and data.get("stats", {}).get("lan", {}).get("played") == 0, "actual offline upload count stays separate from LAN")
	check(client.journal.pending_events(client.identity.binding.service_id, primary.player_id).is_empty(), "progress acknowledgement durably marks offline event sent")
	data = await refresh("profile")
	check(data.history.size() == 1 and data.history[0].source == "offline", "actual profile and mission share history")
	friend = await http("/v1/auth/guest", HTTPClient.METHOD_POST)
	var friend_profile: Dictionary = local.duplicate(true)
	var friend_name := "f" + nickname
	check((await http("/v1/identity/merge", HTTPClient.METHOD_POST, {"request_id":DbProfileClient._uuid(), "nickname":friend_name, "profile":friend_profile}, friend.access_token)).get("status") == 200, "real second player registers unique nickname")
	await client.perform("search", {"nickname":friend_name})
	data = await refresh("social")
	check(data.search.size() == 1 and data.search[0].player_id == friend.player_id, "actual nickname search maps real response")
	check(not (await client.perform("request", {"player_id":friend.player_id})).has("error"), "actual client sends UUID friend action")
	var social := await http("/v1/social", HTTPClient.METHOD_GET, {}, friend.access_token)
	check(social.incoming.size() == 1, "recipient sees one request")
	if not social.incoming.is_empty():
		check((await http("/v1/social/action", HTTPClient.METHOD_POST, {"operation_id":DbProfileClient._uuid(), "action":"accept", "request_id":social.incoming[0].request_id}, friend.access_token)).get("status") == 200, "real recipient accepts request")
	data = await refresh("social")
	check(data.friends.size() == 1 and data.friends[0].player_id == friend.player_id and client.identity.operations.is_empty(), "actual client confirms mutual friend and clears operation journal")
	var match_id := DbProfileClient._uuid()
	var register := {"participants":[{"player_id":primary.player_id,"slot":1,"character_id":"ja-hyun","accessory_id":""},{"player_id":friend.player_id,"slot":2,"character_id":"nabi","accessory_id":""}],"room_code":"QAACTUAL"}
	check((await http("/internal/v1/lan/matches/"+match_id+"/register", HTTPClient.METHOD_POST, register, "", true)).get("status") == 200, "actual service registers two authenticated identities")
	check((await http("/internal/v1/lan/matches/"+match_id+"/result", HTTPClient.METHOD_POST, {"reason":"combat","winner_player_id":primary.player_id,"final_tick":500,"snapshot_hash":"a".repeat(64)}, "", true)).get("status") == 200, "actual service persists normal LAN result")
	await client.perform("rank_scope", {"scope":"friends"})
	data = await refresh("rank")
	check(data.get("own") is Dictionary and data.own.wins == 1 and data.entries.size() == 2, "actual client renders friends rank with real normal LAN victory")
	data = await refresh("profile")
	check(data.stats.offline.played == 1 and data.stats.lan.played == 1 and data.history.size() == 2, "actual profile keeps sources separate after both paths")
	var canonical: String = client.identity.binding.canonical_player_id
	app.queue_free()
	await process_frame
	await process_frame
	await create_app()
	for tick: int in 600:
		await create_timer(0.02).timeout
		if not app.db_client.busy and app.db_client.connected: break
	check(app.db_mode and app.db_client.connected and client._bound(), "real app restart refreshes saved DB credentials and binding")
	check(app.db_client.player_id == primary.player_id and client.identity.binding.canonical_player_id == canonical and app.store.data.nickname == nickname, "restart retains credential owner canonical identity and nickname")
	data = await refresh("profile")
	check(data.stats.offline.played == 1 and data.stats.lan.played == 1 and client.journal.progress.events.size() == 1, "restart and refresh never duplicate uploaded event")
	var session := await client.lan_session(base)
	check(session.get("access_token", "") == app.db_client.access_token and session.get("nickname") == nickname, "LAN handoff uses current refreshed DB session and unified nickname")
	if native_capture: await capture_connected()
	for index: int in 51: check(finish_local(LocalMatchConfig.Mode.AI, &"player"), "append actual pending event beyond one API batch %d" % index)
	check(client.journal.pending_events(client.identity.binding.service_id, canonical, [], 0).size() == 51, "all fifty-one actual local events retained pending before flush")
	var pending_view := client.snapshot("mission")
	check(pending_view.data.stats.offline.played == 52, "snapshot includes all fifty-one pending events beyond POST batch limit")
	data = await refresh("mission")
	check(data.stats.offline.played == 52 and data.stats.lan.played == 1, "actual client flushes fifty-one events as multiple API-valid batches")
	check(client.journal.pending_events(client.identity.binding.service_id, canonical, [], 0).is_empty(), "all batch acknowledgements are durable")
	data = await refresh("mission")
	check(data.stats.offline.played == 52, "subsequent refresh never duplicates multi-batch upload")
	await test_lan_only_recovery()
	await finish()
func finish() -> void:
	check(ordinary_hashes() == original_hashes, "ordinary user profile sessions and menu files unchanged by actual API QA")
	var failed := checks.filter(func(row: Dictionary) -> bool: return not row.pass)
	var report := {"status":"pass" if failed.is_empty() else "fail", "checks":checks, "physical_device":"not_run", "network":"actual_http_isolated_postgresql", "request_adapter":false,"native_capture":native_capture,"captures":capture_records}
	var output := FileAccess.open("res://_workspace/premium-menu-features-v01/qa-app-api-report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  ") + "\n")
	output.close()
	print("MENU_FEATURES_ACTUAL_APP_API: %s (%d checks)" % [report.status.to_upper(), checks.size()])
	app.queue_free()
	await process_frame
	await process_frame
	cleanup(directory)
	quit(0 if failed.is_empty() else 1)

func cleanup(path: String) -> void:
	var folder := DirAccess.open(path)
	if folder == null: return
	for child: String in folder.get_directories(): cleanup(path.path_join(child))
	for file: String in folder.get_files(): DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
func settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.26).timeout
	await process_frame
func control(id: String) -> Control:
	for item: Node in app.page.find_children("*", "Control", true, false):
		if String(item.get_meta("qa_id", "")) == id: return item as Control
	return null
func labels() -> String:
	var text := ""
	for item: Node in app.page.find_children("*", "Label", true, false): text += item.text + "\n"
	return text
func visible_bounds(node: Control) -> Rect2:
	var bounds := root.get_visible_rect()
	var parent := node.get_parent()
	while parent != null and parent != app.page:
		if parent is ScrollContainer: bounds = bounds.intersection((parent as Control).get_global_rect())
		parent = parent.get_parent()
	return bounds
func capture_frame(name: String, semantic: String) -> void:
	await settle()
	var layout: Array[Dictionary] = []
	var viewport := root.get_visible_rect()
	check(viewport.encloses(app.menu_router.view.content.get_global_rect()), name+" canvas fits viewport")
	for node: Node in app.page.find_children("*", "Control", true, false):
		if not node is BaseButton and not node is LineEdit and not node is HSlider: continue
		var item := node as Control
		if not item.is_visible_in_tree(): continue
		var id := String(item.get_meta("qa_id", ""))
		var rect := item.get_global_rect()
		var clipped := visible_bounds(item)
		layout.append({"id":id,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"visible_area":[clipped.position.x,clipped.position.y,clipped.size.x,clipped.size.y]})
		check(rect.size.x >= 71.5 and rect.size.y >= 71.5, name+" 72px touch target "+id)
		if clipped == viewport: check(viewport.encloses(rect), name+" unscrolled control fits "+id)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(not image.is_empty(), name+" real native rendered pixels")
	var filename := CAPTURE_OUTPUT+"/"+name+".png"
	check(image.save_png(filename) == OK, name+" saved native frame")
	capture_records.append({"file":filename.trim_prefix("res://"),"size":[image.get_width(),image.get_height()],"menu":app.menu_router.state.id,"status":app.menu_service.snapshot(app.menu_router.state.id).status,"semantic":semantic,"sha256":FileAccess.get_sha256(filename),"controls":layout})
func open_capture(menu: String, name: String, params: Dictionary = {}) -> void:
	app.menu_router.reset()
	app._show_premium_menu(menu, params)
	await refresh(menu)
	await settle()
	if menu == "social": check(labels().contains("f"+nickname), name+" actual API friend nickname appears")
	if menu == "rank": check(labels().contains("1승") and labels().contains(nickname), name+" actual API rank and nickname appear")
	if menu == "mission": check(control("menu/mission/mission/daily-play") != null, name+" actual API daily mission button appears")
	if menu == "profile": check(labels().contains(nickname), name+" actual unified nickname appears")
	await capture_frame(name, "actual API-created QA players; no injected runtime data")
func capture_connected() -> void:
	check(DisplayServer.get_name() != "headless", "connected frames require actual native window")
	DirAccess.make_dir_recursive_absolute(CAPTURE_OUTPUT)
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = resolution
		DisplayServer.window_set_size(resolution)
		await settle()
		for menu: String in ["mission","social","rank","profile"]: await open_capture(menu,"connected-"+menu+"-"+str(resolution.x))
	root.size = Vector2i(1600,720)
	DisplayServer.window_set_size(root.size)
	await open_capture("social","connected-social-20x9")
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	app.store.data.accessibility.text_scale = 1.3
	for menu: String in ["mission","social","rank","profile"]: await open_capture(menu,"connected-"+menu+"-large-text")
	app.store.data.accessibility.text_scale = 1.0
	for category: String in ["daily","weekly","achievements"]:
		app.menu_router.reset()
		app._show_premium_menu("mission",{"category":category})
		await refresh("mission")
		await capture_frame("connected-mission-"+category,"actual current-period API mission values")
	app.menu_router.reset()
	app._show_premium_menu("mission",{"category":"daily"})
	await refresh("mission")
	await settle()
	var detail := control("menu/mission/mission/daily-play") as Button
	check(detail != null,"actual daily mission detail action exists")
	if detail != null:
		detail.pressed.emit()
		await settle()
		check(is_instance_valid(app.menu_router.view.modal),"actual mission detail opens native modal")
		await capture_frame("connected-mission-detail","native mission detail from actual API values")
	app.menu_router.reset()
	app._show_premium_menu("profile")
	await refresh("profile")
	await settle()
	for node: Node in app.page.find_children("*","ScrollContainer",true,false): (node as ScrollContainer).scroll_vertical = 100000
	await capture_frame("connected-profile-records","scroll to actual API mode stats and both source histories")
	check(labels().contains("오프라인 AI") and labels().contains("LAN"),"profile history labels contain actual offline and LAN entries")
	app.menu_router.reset()
	app._show_premium_menu("social",{"category":"search"})
	await refresh("social")
	await client.perform("search",{"nickname":"no"+nickname})
	var empty := await refresh("social")
	check(empty.search.is_empty(),"real API search for unused nickname is empty")
	await capture_frame("connected-social-search-empty","actual API empty search, not fabricated success")
	await client.perform("search",{"nickname":""})
	await refresh("social")
	app.menu_router.reset()
	app._show_premium_menu("social",{"category":"friends"})
	await refresh("social")
	var saved_url: String = client.identity.binding.api_url
	client.identity.binding.api_url = "http://127.0.0.1:1"
	client.refresh_menu("social")
	for tick: int in 600:
		await create_timer(0.02).timeout
		if not client._refreshing: break
	check(client.snapshot("social").status == "error", "real HTTP connection failure is error")
	await capture_frame("connected-social-connection-error","real unavailable loopback endpoint with retained prior social cache")
	client.identity.binding.api_url = saved_url
	await refresh("social")
	check(client.snapshot("social").status == "ready", "actual API retry recovers connection error")
	await capture_frame("connected-social-retry","actual HTTP recovery restores ready friend list")

func ordinary_hashes() -> Dictionary:
	var result: Dictionary = {}
	for filename: String in ["local_player.json","db_profile_session.json","demo_guest_session.json","menu_presets_v01.json","menu_controls_v01.json","menu_identity_v01.json","menu_progress_v01.json"]:
		for ending: String in ["", ".bak", ".tmp"]:
			var path := "user://"+filename+ending
			result[filename+ending] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	return result

func test_lan_only_recovery() -> void:
	app.queue_free()
	await process_frame
	await process_frame
	cleanup(directory)
	directory += "_lan_only"
	DirAccess.make_dir_recursive_absolute(directory)
	await create_app()
	check(app.store.grant_first("nabi"), "LAN-only recovery has isolated current profile")
	check(await app.demo_guest.login(base, true), "LAN-only original guest authenticated by real API")
	var raw_owner: String = app.demo_guest.player_id
	check(not FileAccess.file_exists(app.db_session_path), "LAN-only recovery starts with no DB session file")
	# A real successful merge receipt is durable before DB authentication needs
	# to save its next token. Blocking that save leaves the existing LAN token.
	DirAccess.make_dir_absolute(app.db_session_path + ".tmp")
	var interrupted := await client.perform("unify", {"api_url":base,"nickname":nickname+"x"})
	check(interrupted.has("error") and client.has_pending_merge() and not client.identity.intent.response.is_empty(), "LAN-only real successful receipt survives failed DB session save")
	check(not FileAccess.file_exists(app.db_session_path), "failed DB authentication creates no partial primary session")
	var receipt_refresh: String = client.identity.intent.response.session.refresh_token
	var revision: int = client.identity.intent.response.revision
	DirAccess.remove_absolute(app.db_session_path + ".tmp")
	app.queue_free()
	await process_frame
	await process_frame
	await create_app()
	check(client.has_pending_merge() and not app.db_mode, "LAN-only restart retains receipt and local mode without DB file")
	check(await app.demo_guest.login(base, false), "LAN-only latest credential actually rotates before receipt resume")
	check(app.demo_guest.refresh_token != receipt_refresh and app.demo_guest.player_id == raw_owner, "rotated LAN credential keeps raw owner while old receipt is stale")
	var resumed := await client.perform("retry_identity")
	check(not resumed.has("error") and client._bound() and not client.has_pending_merge(), "actual LAN-only cached receipt completes after fresh LAN rotation")
	check(app.db_client.player_id == raw_owner and app.demo_guest.player_id == raw_owner and app.db_client.revision == revision, "LAN-only resume keeps same owner and already committed revision")
	var db_saved: Dictionary = app.db_client.saved_connection()
	var lan_saved: Dictionary = client._read_session(app.demo_guest.session_path)
	check(db_saved.refresh_token == app.db_client.refresh_token and lan_saved.refresh_token == db_saved.refresh_token and db_saved.refresh_token != receipt_refresh, "LAN-only fresh refresh token is shared by durable DB and LAN sessions")
	app.db_client.access_token = ""
	check(await client._ensure_primary(true), "LAN-only resulting refresh token can authenticate again against real API")
	var identity := await client._authorized(HTTPClient.METHOD_GET, "/v1/identity")
	check(identity.get("canonical_player_id") == raw_owner, "LAN-only recovered credentials resolve same real canonical identity")
