extends Node

var host: LanMatchClient
var guest: LanMatchClient
var failures: Array[String] = []
var refresh_attempts := 0
var checking := true

func _ready() -> void:
	_run()

func _refresh() -> String:
	refresh_attempts += 1
	if refresh_attempts == 1:
		# Simulate the API's eight-second connection deadline during Wi-Fi loss.
		await get_tree().create_timer(8.0).timeout
		return ""
	return "host"

func _run() -> void:
	host = LanMatchClient.new()
	guest = LanMatchClient.new()
	add_child(host)
	add_child(guest)
	host.access_token_provider = _refresh
	host.failed.connect(func(code: String) -> void: failures.append(code) if checking else null)
	guest.failed.connect(func(code: String) -> void: failures.append(code) if checking else null)
	var invite := []
	host.room_created.connect(func(code: String) -> void: invite.append(code))
	var selection := LoadoutSelection.new()
	selection.character_id = &"nabi"
	var url := OS.get_environment("FOREST_ARENA_LAN_TEST_WS_URL")
	if url.is_empty(): url = "ws://127.0.0.1:17777"
	host.begin_host(LanInvite.host_code(url, "http://127.0.0.1:18081"), selection, "", "host")
	await _wait(func() -> bool: return not invite.is_empty(), 5000)
	if not invite.is_empty(): guest.begin_join(invite[0], selection, "", "guest")
	await _wait(func() -> bool: return host.running and guest.running, 5000)
	var old_token := host.reconnect_token
	host.websocket.close()
	await _wait(func() -> bool: return refresh_attempts >= 2 and host.reconnect_token != old_token, 15000)
	if not host.active or not host.running or refresh_attempts < 2: failures.append("eight-second API failure cancelled reconnect grace")
	checking = false
	host.leave()
	await get_tree().create_timer(0.2).timeout
	guest.request_rematch(false)
	await get_tree().create_timer(0.2).timeout
	guest.stop()
	host.queue_free()
	guest.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("LAN_RECONNECT_AUTH: PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures: push_error(failure)
		get_tree().quit(1)

func _wait(predicate: Callable, duration: int) -> void:
	var deadline := Time.get_ticks_msec() + duration
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return
		await get_tree().process_frame
	failures.append("reconnect fixture timed out")
