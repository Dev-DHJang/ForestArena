extends SceneTree

const Client = preload("res://scripts/network/demo_guest_client.gd")
var failures: Array[String] = []

class FakeClient extends Client:
	var replies: Array[Dictionary] = []
	var calls: Array[Dictionary] = []
	var fail_write_at := 0
	var writes := 0
	var delayed := false
	func _request(method: HTTPClient.Method, route: String, payload: Dictionary, authenticated: bool, generation: int) -> Dictionary:
		calls.append({"method": method, "route": route, "payload": payload.duplicate(true), "authenticated": authenticated})
		if delayed: await get_tree().process_frame
		if not _current(generation): return {"error": "cancelled"}
		return replies.pop_front() if not replies.is_empty() else {"error": "missing_fixture"}
	func _write_session(value: Dictionary) -> bool:
		writes += 1
		if writes == fail_write_at: return false
		return super._write_session(value)

func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
		push_error(label)

func auth(token := "r1") -> Dictionary:
	return {"access_token": "a1", "refresh_token": token, "player_id": "p1", "status": 200}

func profile(name: Variant = null) -> Dictionary:
	return {"player_id": "p1", "nickname": name, "status": 200}

func fixture() -> FakeClient:
	var client := FakeClient.new()
	client.session_path = "user://demo-client-test-%s.json" % Crypto.new().generate_random_bytes(6).hex_encode()
	root.add_child(client)
	return client

func clean(client: FakeClient) -> void:
	DirAccess.remove_absolute(client.session_path)
	DirAccess.remove_absolute(client.session_path + ".tmp")
	client.queue_free()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var client := fixture()
	client.replies = [auth(), profile()]
	check(await client.login("http://127.0.0.1:3000"), "fresh guest logs in")
	check(client.nickname.is_empty() and client.player_id == "p1", "unset nickname preserves guest identity")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(client.session_path))
	check(not saved.has("access_token") and not saved.has("profile"), "disk stores no access token or inventory")
	var bytes := FileAccess.get_file_as_bytes(client.session_path)
	check(not await client.login("http://127.0.0.1:3001"), "address changes require explicit new guest")
	check(client.error == "session_endpoint_mismatch" and FileAccess.get_file_as_bytes(client.session_path) == bytes, "address mismatch preserves session bytes")
	client.replies = [auth("r2"), profile("숲지기")]
	check(await client.login("http://127.0.0.1:3000"), "saved guest refreshes")
	check(client.calls[-2].route == "/v1/auth/refresh" and client.calls[-2].payload.refresh_token == "r1", "refresh uses predecessor")
	client.replies = [{"error": "nickname_taken", "status": 409}]
	check(not await client.set_nickname("숲지기2") and client.nickname == "숲지기", "duplicate nickname preserves previous display")
	client.replies = [profile("새이름")]
	check(await client.set_nickname("새이름") and client.nickname == "새이름", "nickname patch accepts confirmed value")
	client.replies = [{"error": "connection_failed", "status": 0}]
	check(not await client.login("http://127.0.0.1:3000"), "uncertain refresh fails safely")
	var predecessor: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(client.session_path))
	check(not predecessor.pending_auth.is_empty(), "predecessor and successor persist before refresh")
	var pending: Dictionary = predecessor.pending_auth.duplicate(true)
	client.replies = [auth("r3"), profile("새이름")]
	check(await client.login("http://127.0.0.1:3000"), "uncertain refresh retries")
	check(client.calls[-2].payload == pending, "retry reuses exact successor")
	client.replies = [{"error": "session_expired", "status": 401}]
	var count := client.calls.size()
	check(not await client.login("http://127.0.0.1:3000") and client.session_invalid, "expired refresh requires explicit recovery")
	check(client.calls.size() == count + 1 and client.access_token.is_empty(), "expired refresh never auto creates guest")
	clean(client)

	client = fixture()
	client.fail_write_at = 1
	client.replies = [auth()]
	check(not await client.login("http://127.0.0.1:3000") and client.error == "session_save_failed" and client.access_token.is_empty(), "failed initial persistence blocks online access")
	clean(client)

	client = fixture()
	client.replies = [auth(), profile("복원")]
	check(await client.login("http://127.0.0.1:3000"), "rotation failure fixture")
	client.fail_write_at = client.writes + 2
	client.replies = [auth("next")]
	check(not await client.login("http://127.0.0.1:3000") and client.access_token.is_empty(), "failed successor persistence blocks access")
	var retry_record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(client.session_path))
	check(retry_record.refresh_token == "r1" and not retry_record.pending_auth.is_empty(), "failed successor save preserves predecessor replay record")
	client.fail_write_at = 0
	client.replies = [auth("next"), profile("복원")]
	check(await client.login("http://127.0.0.1:3000") and client.calls[-2].payload == retry_record.pending_auth, "completion save failure retries original refresh pair")
	clean(client)

	client = fixture()
	check(client._write_session({"api_url": "http://127.0.0.1:3000", "refresh_token": "bad"}), "corrupt session fixture")
	check(not await client.login("http://127.0.0.1:3000") and client.session_invalid and client.calls.is_empty(), "malformed session never auto creates guest")
	clean(client)

	client = fixture()
	client.replies = [auth(), profile("이름")]
	check(await client.login("http://127.0.0.1:3000"), "cancellation fixture login")
	bytes = FileAccess.get_file_as_bytes(client.session_path)
	client.delayed = true
	client.replies = [profile("늦은이름")]
	client.set_nickname("늦은이름")
	client.cancel()
	await process_frame
	check(client.error == "cancelled" and not client.busy and client.nickname == "이름", "cancelled late response cannot mutate UI")
	check(FileAccess.get_file_as_bytes(client.session_path) == bytes, "cancelled response cannot mutate session")
	clean(client)
	client = fixture()
	client.delayed = true
	client.replies = [auth(), profile("늦은로그인")]
	client.login("http://127.0.0.1:3000")
	client.cancel()
	await process_frame
	check(not FileAccess.file_exists(client.session_path) and client.access_token.is_empty() and client.player_id.is_empty(), "cancelled guest response cannot save identity")
	clean(client)
	print("demo_guest_client: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
