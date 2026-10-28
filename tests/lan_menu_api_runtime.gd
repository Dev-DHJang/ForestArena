extends SceneTree
## Actual protocol clients, actual LAN authority and PostgreSQL; no forced result.
var clients: Array[Dictionary] = []
var checks := 0
var failed := false
var api_url := OS.get_environment("FOREST_ARENA_API_URL")
var host_token := OS.get_environment("FOREST_ARENA_LAN_RUNTIME_HOST_TOKEN")
var guest_token := OS.get_environment("FOREST_ARENA_LAN_RUNTIME_GUEST_TOKEN")
var endpoint := OS.get_environment("FOREST_ARENA_LAN_ADVERTISED_WS_URL")
var stocks_seen: Array[int] = []

func _initialize() -> void:
	call_deferred("run")
	call_deferred("watchdog")

func watchdog() -> void:
	await create_timer(80).timeout
	check(false, "overall bounded runtime")

func check(value: bool, label: String) -> void:
	checks += 1
	if value or failed: return
	failed = true
	push_error("LAN_MENU_API_RUNTIME: " + label)
	quit(1)

func pump() -> void:
	for client: Dictionary in clients:
		var peer: WebSocketMultiplayerPeer = client.peer
		peer.poll()
		while peer.get_available_packet_count() > 0:
			var value: Variant = JSON.parse_string(peer.get_packet().get_string_from_utf8())
			if value is Dictionary:
				if value.get("type") == "error": check(false, "protocol error " + String(value.get("code", "")))
				client.queue.append(value)

func open_client() -> Dictionary:
	var client := {"peer": WebSocketMultiplayerPeer.new(), "queue": []}
	clients.append(client)
	check(client.peer.create_client(endpoint) == OK, "WebSocket starts")
	var deadline := Time.get_ticks_msec() + 5000
	while client.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING and Time.get_ticks_msec() < deadline:
		pump()
		await process_frame
	check(client.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "WebSocket connects")
	return client

func send(client: Dictionary, message: Dictionary) -> void:
	message.protocol_version = 4
	check(client.peer.put_packet(JSON.stringify(message).to_utf8_buffer()) == OK, "normal LAN v2 input sends")

func message(client: Dictionary, kind: String) -> Dictionary:
	var deadline := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < deadline and not failed:
		pump()
		for index: int in client.queue.size():
			if client.queue[index].get("type") == kind: return client.queue.pop_at(index)
		await process_frame
	check(false, "message timeout " + kind)
	return {}

func selection(character: String) -> Dictionary:
	return {"schema_version": 1, "character_id": character, "job_id": "", "accessory_id": ""}

func request(route: String, token := "") -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 1.0
	root.add_child(http)
	var headers := PackedStringArray()
	if not token.is_empty(): headers.append("Authorization: Bearer " + token)
	var error := http.request(api_url + route, headers)
	if error != OK:
		http.queue_free()
		return {"status": 0, "data": {}}
	var response: Array = await http.request_completed
	http.queue_free()
	var data: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8()) if not (response[3] as PackedByteArray).is_empty() else {}
	return {"status": int(response[1]), "data": data if data is Dictionary else {}}

func play_left(host: Dictionary) -> Dictionary:
	var deadline := Time.get_ticks_msec() + 27000
	var seq := 0
	stocks_seen.clear()
	while Time.get_ticks_msec() < deadline and not failed:
		send(host, {"type": "input", "seq": seq, "action_id": "move", "direction": CombatIntent.Direction.LEFT, "edge": CombatIntent.Edge.PRESS if seq == 0 else CombatIntent.Edge.HOLD})
		seq += 1
		pump()
		var queue: Array = host.queue
		while not queue.is_empty():
			var value: Dictionary = queue.pop_front()
			if value.get("type") == "snapshot":
				var stock := int(value.state.fighters[0].stocks)
				if stock not in stocks_seen: stocks_seen.append(stock)
			elif value.get("type") == "match_end":
				check(value.reason == "combat" and int(value.winner_slot) == 2, "movement causes actual combat defeat")
				check(3 in stocks_seen and 2 in stocks_seen and 1 in stocks_seen, "all three stocks observed through snapshots")
				return value
		await process_frame
	check(false, "normal movement combat deadline")
	return {}

func progress_count(count: int) -> Dictionary:
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline and not failed:
		var state := await request("/v1/progress", guest_token)
		if state.status == 200 and int(state.data.get("stats", {}).get("lan", {}).get("played", 0)) == count: return state.data
		await create_timer(0.1).timeout
	check(false, "actual API progress count " + str(count))
	return {}

func run() -> void:
	check(not host_token.is_empty() and not guest_token.is_empty(), "environment credentials exist")
	var host := await open_client()
	send(host, {"type": "create_room", "access_token": host_token, "selection": selection("nabi")})
	var created := await message(host, "room_created")
	if failed: return
	var guest := await open_client()
	send(guest, {"type": "join_room", "room_code": created.room_code, "access_token": guest_token, "selection": selection("ja-hyun")})
	var ready := await message(host, "room_ready")
	check(String(ready.names["1"]).begins_with("LanHost") and String(ready.names["2"]).begins_with("LanGuest"), "actual API nicknames reach server")
	check(ready.loadouts["1"].character_id == "nabi" and ready.loadouts["2"].character_id == "ja-hyun", "approved selections reach actual server")
	var first_start := await message(host, "match_start")
	await message(guest, "match_start")
	var first := await play_left(host)
	await message(guest, "match_end")
	if failed: return
	check(first.match_id == first_start.match_id, "normal result uses registered match UUID")
	var progress := await progress_count(1)
	check(int(progress.get("stats", {}).get("lan", {}).get("wins", 0)) == 1, "actual API awards LAN win")
	var ranks := await request("/v1/leaderboard", guest_token)
	check(ranks.status == 200 and int(ranks.data.own.wins) == 1, "actual leaderboard includes authority result")
	print("LAN_MENU_API_PAUSE_API")
	var stop_deadline := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < stop_deadline:
		if (await request("/health/live")).status != 200: break
		await create_timer(0.05).timeout
	check((await request("/health/live")).status != 200, "temporary API outage observed")
	send(host, {"type": "rematch", "ready": true})
	send(guest, {"type": "rematch", "ready": true})
	var second_start := await message(host, "match_start")
	await message(guest, "match_start")
	check(second_start.match_id != first_start.match_id, "rematch gets a new UUID")
	var second := await play_left(host)
	await message(guest, "match_end")
	if failed: return
	check(second.result_sync == "pending", "offline API result remains visibly pending")
	var path := OS.get_environment("FOREST_ARENA_LAN_OUTBOX_PATH")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var jobs: Array = saved.jobs.filter(func(job: Dictionary) -> bool: return job.match_id == second.match_id)
	check(jobs.size() == 2 and String(jobs[0].route).ends_with("/register") and String(jobs[1].route).ends_with("/result"), "registration and combat result are durably ordered")
	check(not FileAccess.get_file_as_string(path).contains(OS.get_environment("FOREST_ARENA_SERVICE_TOKEN")), "outbox contains no service credential")
	for client: Dictionary in clients: client.peer.close()
	print("LAN_MENU_API_RESTART_SERVER")
	var restored := await progress_count(2)
	check(int(restored.get("stats", {}).get("lan", {}).get("wins", 0)) == 2, "restart replays durable result exactly once")
	var final_rank := await request("/v1/leaderboard", guest_token)
	check(final_rank.status == 200 and int(final_rank.data.own.wins) == 2, "rank reflects both real normal results")
	var history: Array = restored.history
	check(history.any(func(item: Dictionary) -> bool: return item.match_id == first.match_id) and history.any(func(item: Dictionary) -> bool: return item.match_id == second.match_id), "both distinct authority match IDs persisted")
	if failed: return
	print("LAN_MENU_API_RUNTIME: PASS checks=%d (normal inputs, two actual combat outcomes, PostgreSQL, process restart replay; no physical-device claim)" % checks)
	quit(0)
