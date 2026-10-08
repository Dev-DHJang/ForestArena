extends SceneTree

var failures: Array[String] = []
var app: Node
var run_id := OS.get_environment("FOREST_ARENA_PROFILE_RUN_ID")
var phase := "write"
var source_path: String
var session_path: String

class CompletionWriteFailure extends DbProfileClient:
	var writes := 0
	func _write_session(value: Dictionary) -> bool:
		writes += 1
		if writes == 2: return false
		return super._write_session(value)

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func _initialize() -> void:
	call_deferred("run")
	call_deferred("watchdog")

func watchdog() -> void:
	await create_timer(90).timeout
	push_error("DB profile runtime watchdog expired")
	quit(1)

func wait_idle() -> void:
	var deadline := Time.get_ticks_msec() + 20000
	while app.storage_busy and Time.get_ticks_msec() < deadline:
		await create_timer(0.02).timeout
	check(not app.storage_busy, "request finishes before timeout")
	await process_frame

func button(text: String) -> Button:
	for node: Node in app.page.find_children("*", "Button", true, false):
		if node.text == text: return node as Button
	return null

func press(text: String) -> void:
	var target := button(text)
	check(target != null, "UI button exists: " + text)
	if target == null: return
	target.pressed.emit()
	await wait_idle()

func run() -> void:
	if run_id.is_empty():
		push_error("FOREST_ARENA_PROFILE_RUN_ID required")
		quit(1)
		return
	if "--restore" in OS.get_cmdline_user_args(): phase = "restore"
	source_path = "user://db-test-%s-local.json" % run_id
	session_path = "user://db-test-%s-session.json" % run_id
	if phase == "write":
		var source := LocalPlayerStore.new(LocalPlayCatalog.new(), source_path)
		check(source.grant_first("nabi"), "create existing local source")
	app = (load("res://scenes/local_ai_app.tscn") as PackedScene).instantiate()
	app.save_path = source_path
	app.db_session_path = session_path
	root.add_child(app)
	await process_frame
	await process_frame
	await wait_idle()
	if phase == "write":
		check(app.screen == "home", "existing device profile opens lobby")
		var source_bytes := FileAccess.get_file_as_bytes(source_path)
		await press("저장 모드 · 기기 저장")
		await press("로컬 DB 연결")
		check(app.db_mode and app.store.owns("nabi"), "actual app imports device profile")
		if not app.db_mode:
			finish()
			return
		check(app.db_client.revision == 1, "import revision")
		await press("상점 · 모두 0원")
		# Choose specific shop rows so the test is independent of catalog ordering.
		for item: Dictionary in app.catalog.products:
			if not app.store.owns(item.id):
				await press("0원 · 무료 구매")
		check(app.store.data.characters.size() == 4 and app.store.data.accessories.size() == 6, "shop UI persists full catalog")
		await press("로비")
		await press("오프라인 대전")
		await press("유란")
		check(app.store.data.selected_character == "yu-ran", "character UI saves selection")
		check(await app._change_profile("select", {"character": "yu-ran", "accessory": "fixture-thorns", "opponent": "myo-ryung"}), "accessory and opponent save")
		await press("로비")
		await press("접근성 설정")
		check(await app._change_profile("accessibility", {"text_scale": 1.3, "reduce_visual_effects": true, "haptics_enabled": false}), "settings save")
		check(FileAccess.get_file_as_bytes(source_path) == source_bytes, "device source remains byte-identical")
		var before: Dictionary = app.store.data.duplicate(true)
		var address: String = app.db_client.api_url
		app.db_client.api_url = "http://127.0.0.1:1"
		check(not await app._change_profile("select", {"character": "nabi", "accessory": "", "opponent": "ja-hyun"}), "disconnected request fails")
		check(app.store.data == before and app.db_mode, "failed save preserves state and DB mode")
		check(not app.db_client.pending.is_empty(), "uncertain request retained for retry")
		app.db_client.api_url = address
		# Server commits, but the app deliberately ignores this response: replay must not duplicate it.
		var committed: Dictionary = await app.db_client._request(HTTPClient.METHOD_POST, "/v1/profile/actions", app.db_client.pending)
		check(committed.get("revision", 0) == app.db_client.revision + 1, "server committed uncertain request once")
		check(app.store.data == before, "unobserved commit does not change local UI state")
		await app._retry_db()
		check(app.db_client.pending.is_empty() and app.store.data.selected_character == "nabi", "retry applies once")
		check(app.db_client.revision == int(committed.get("revision", -1)), "replay preserves committed revision")
		app.db_client.revision -= 1
		check(not await app._change_profile("select", {"character": "nabi", "accessory": "", "opponent": "yu-ran"}), "stale revision rejected")
		check(app.db_client.pending.is_empty() and app.db_client.error == "revision_conflict", "conflict refreshes latest DB and clears rejected request")
		app.db_client.access_token = "expired-token-for-runtime-test"
		check(await app._change_profile("select", {"character": "yu-ran", "accessory": "fixture-thorns", "opponent": "myo-ryung"}), "final selection saved")
		app._show_home()
		await press("오프라인 대전")
		await press("대전 시작")
		check(app.screen == "match", "DB loadout enters real match")
		app._close_match()
		# Persist rotation intent, let the server commit, and discard the response.
		app.db_client.pending_auth = {"refresh_token": app.db_client.refresh_token, "next_refresh_token": Marshalls.raw_to_base64(Crypto.new().generate_random_bytes(32)).replace("+", "-").replace("/", "_").trim_suffix("=")}
		check(app.db_client._save_session(), "rotation intent is saved before HTTP")
		var auth_commit: Dictionary = await app.db_client._request(HTTPClient.METHOD_POST, "/v1/auth/refresh", app.db_client.pending_auth, false)
		check(auth_commit.get("status") == 200, "rotation response lost after server commit")
		check(await app.db_client._login(false), "same rotation safely replays after lost response")
		# Fail the final session rename after another rotation; the next process
		# must recover from the durable intent rather than create another guest.
		var fault := CompletionWriteFailure.new()
		fault.session_path = session_path
		fault.api_url = address
		fault.player_id = app.db_client.player_id
		fault.refresh_token = app.db_client.refresh_token
		root.add_child(fault)
		check(not await fault._login(false) and fault.error == "session_save_failed", "rotation completion write fails")
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(session_path))
		check(saved is Dictionary and not saved.get("pending_auth", {}).is_empty(), "recoverable rotation intent survives completion failure")
		fault.queue_free()
		await test_first_grant_conflict()
	else:
		check(app.db_mode, "separate process automatically reconnects DB mode")
		check(app.store.data.selected_character == "yu-ran" and app.store.data.selected_accessory == "fixture-thorns" and app.store.data.opponent_character == "myo-ryung", "restart restores DB selection")
		check(app.store.data.characters.size() == 4 and app.store.data.accessories.size() == 6, "restart restores DB ownership")
		check(is_equal_approx(float(app.store.data.accessibility.text_scale), 1.3) and not app.store.data.accessibility.haptics_enabled, "restart restores settings")
		var source := LocalPlayerStore.new(LocalPlayCatalog.new(), source_path)
		check(source.load_profile() and source.data.characters == ["nabi"], "device data independent of DB")
	var report := FileAccess.open("/private/tmp/forest-db-profile-%s.json" % run_id, FileAccess.WRITE)
	report.store_string(JSON.stringify({"player_id": app.db_client.player_id, "revision": app.db_client.revision, "profile": app.store.data}))
	report.close()
	finish()

func test_first_grant_conflict() -> void:
	var previous := app
	app = (load("res://scenes/local_ai_app.tscn") as PackedScene).instantiate()
	app.save_path = "user://db-test-%s-fresh.json" % run_id
	app.db_session_path = "user://db-test-%s-fresh-session.json" % run_id
	root.add_child(app)
	await process_frame
	await app._connect_db(false)
	check(app.db_mode and app.screen == "first", "empty DB profile offers first character UI")
	var competing: Dictionary = await app.db_client._request(HTTPClient.METHOD_POST, "/v1/profile/actions", {"request_id": DbProfileClient._uuid(), "expected_revision": 1, "action": "grant_first", "payload": {"id": "ja-hyun"}})
	check(competing.get("status") == 200, "another client wins initial grant")
	await press("나비")
	check(app.screen == "home" and app.store.data.first_granted and app.store.data.selected_character == "ja-hyun", "first grant conflict opens lobby with latest DB profile")
	app.queue_free()
	await process_frame
	app = previous

func finish() -> void:
	print("DB_PROFILE_GAME_RUNTIME: " + ("PASS" if failures.is_empty() else "FAIL") + " phase=" + phase)
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
