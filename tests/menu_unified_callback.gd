extends SceneTree
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func run() -> void:
	var directory := "user://qa/menu_callback_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var app := (load("res://scenes/local_ai_app.tscn") as PackedScene).instantiate()
	app.save_path = directory.path_join("profile.json")
	app.db_session_path = directory.path_join("db_session.json")
	app.demo_guest_session_path = directory.path_join("demo_session.json")
	root.add_child(app)
	await create_timer(0.25).timeout
	check(app.store.grant_first("nabi"), "seed current player")
	var before: Dictionary = app.store.data.duplicate(true)
	var profile := before.duplicate(true)
	profile.nickname = "통합검사"
	profile.characters.append("yu-ran")
	var session := {"api_url":"http://127.0.0.1:18888", "player_id":DbProfileClient._uuid(), "access_token":"test-access-not-real", "refresh_token":"test-refresh-not-real"}
	var receipt := {"session":session, "profile":profile, "revision":4, "canonical_player_id":session.player_id, "nickname":profile.nickname, "service_id":DbProfileClient._uuid()}
	check(not app.apply_unified_identity({}), "invalid receipt cannot mutate profile")
	DirAccess.make_dir_absolute(app.save_path + ".tmp")
	check(not app.apply_unified_identity(receipt), "local profile disk failure remains failure after session writes")
	check(app.store.data == before and not app.db_mode and app.db_client.access_token.is_empty(), "failed receipt keeps prior in-memory account")
	check(FileAccess.file_exists(app.db_session_path) and FileAccess.file_exists(app.demo_guest_session_path), "partial session writes survive for journal roll forward")
	DirAccess.remove_absolute(app.save_path + ".tmp")
	check(app.apply_unified_identity(receipt), "same immutable receipt can finish after storage recovery")
	check(app.db_mode and app.store.data == profile and app.db_client.revision == 4, "successful receipt publishes profile revision together")
	check(app.db_client.player_id == session.player_id and app.demo_guest.player_id == session.player_id, "both app consumers use the same raw credential owner")
	check(app.demo_guest.nickname == profile.nickname and app.demo_api_url == session.api_url, "LAN uses unified nickname and endpoint")
	var saved := LocalPlayerStore.new(app.catalog, app.save_path)
	check(saved.load_profile_read_only() and saved.data.nickname == profile.nickname and saved.owns("nabi") and saved.owns("yu-ran") and saved.data.selected_character == profile.selected_character and saved.data.accessibility == profile.accessibility and saved.data.minimap == profile.minimap, "unified profile survives restart")
	app.db_client.refresh_token = "current-rotated-refresh"
	app.db_client.access_token = "current-rotated-access"
	check(app.db_client._save_session(), "seed a rotation after cached server receipt")
	check(app.apply_unified_identity(receipt) and app.db_client.refresh_token == "current-rotated-refresh" and app.demo_guest.refresh_token == "current-rotated-refresh" and receipt.session.refresh_token == "current-rotated-refresh", "cached receipt cannot overwrite a later persisted rotation")
	app.menu_service.identity.intent = {"request_id":"pending"}
	check(not await app._change_profile("purchase", {"id":"ja-hyun"}) and app.store.data == profile, "pending merge prevents changes to immutable current profile")
	var old_guest: String = app.demo_guest.player_id
	var old_generation: int = app.demo_generation
	await app._demo_login("join", true)
	check(app.demo_guest.player_id == old_guest and app.demo_generation == old_generation and app.menu_router.state.get("id", "") == "profile", "pending merge blocks legacy LAN replacement and returns to recovery")
	app.menu_service.identity.intent = {}
	app.db_client.pending = {"request_id":"pending-action"}
	check(not app.apply_unified_identity(receipt), "existing profile write cannot be silently discarded by merge")
	app.db_client.pending = {}
	# A menu invite may never displace an existing game/room.
	app.lan_client.active = true
	check(not app.join_menu_invite("FA3|http://127.0.0.1:18888|ws://127.0.0.1:17777|ABC234|3"), "invitation cannot displace an active LAN session")
	app.lan_client.active = false
	app.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty(): print("menu_unified_callback: PASS (%d checks)" % checks)
	else:
		for label: String in failures: push_error(label)
	quit(0 if failures.is_empty() else 1)
