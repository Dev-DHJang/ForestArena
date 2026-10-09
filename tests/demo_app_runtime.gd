extends Node

const TIMEOUT_MSEC := 8000
var failures: Array[String] = []
var app: LocalAiApp
var guest_app: LocalAiApp
var files: Array[String] = []
var run_id := str(Time.get_unix_time_from_system()).replace(".", "").right(9)
var host_name := "H" + run_id
var guest_name := "G" + run_id
var api_url := "http://127.0.0.1:3001"
var websocket_url := "ws://127.0.0.1:7778"

func _ready() -> void:
	_run()

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func _wait(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await get_tree().process_frame
	return false

func _button(target: LocalAiApp, text: String) -> Button:
	for node: Node in target.page.find_children("*", "Button", true, false):
		if node.text == text: return node as Button
	return null

func _press(target: LocalAiApp, text: String) -> bool:
	var button := _button(target, text)
	_check(button != null and not button.disabled, "enabled UI button: " + text)
	if button == null or button.disabled: return false
	button.pressed.emit()
	return true

func _nickname_input(target: LocalAiApp) -> LineEdit:
	for node: Node in target.page.find_children("*", "LineEdit", true, false):
		if node.placeholder_text == "닉네임": return node as LineEdit
	return null

func _labels_contain(target: LocalAiApp, text: String) -> bool:
	for node: Node in target.page.find_children("*", "Label", true, false):
		if node.text.contains(text): return true
	return false

func _create_app(suffix: String, character: String) -> LocalAiApp:
	var target := LocalAiApp.new()
	target.demo_mode = true
	target.save_path = "user://demo-runtime-%s-%s.json" % [run_id, suffix]
	target.db_session_path = target.save_path + ".db"
	target.demo_guest_session_path = target.save_path + ".guest"
	files.append_array([target.save_path, target.save_path + ".bak", target.demo_guest_session_path, target.demo_guest_session_path + ".tmp"])
	add_child(target)
	_check(target.store.grant_first(character), "device first character " + character)
	target._show_home()
	return target

func _set_nickname(target: LocalAiApp, value: String) -> bool:
	var input := _nickname_input(target)
	_check(input != null, "nickname field")
	if input == null: return false
	input.text = value
	_press(target, "닉네임 저장")
	return await _wait(func() -> bool: return not target.demo_guest.busy)

func _run() -> void:
	var configured := OS.get_environment("FOREST_ARENA_DEMO_TEST_API_URL")
	if not configured.is_empty(): api_url = configured
	configured = OS.get_environment("FOREST_ARENA_DEMO_TEST_WS_URL")
	if not configured.is_empty(): websocket_url = configured
	app = _create_app("host", "nabi")
	await get_tree().process_frame
	_check(not app.db_mode and _button(app, "저장 모드 · 기기 저장") == null, "demo home hides development DB mode")
	app._show_prepare()
	var modes := PackedStringArray()
	for node: Node in app.page.find_children("*", "OptionButton", true, false):
		for index: int in node.item_count: modes.append(node.get_item_text(index))
	for value: String in ["스토리 프롤로그 · 첫 기록인장", "Solo · 각자전", "Team · 팀전", "AI · 1대1", "연습"]:
		_check(value in modes, "offline demo mode retained: " + value)
	app._show_lan_host()
	app.lan_host_code = LanInvite.host_code(websocket_url, api_url)
	_press(app, "방 생성")
	var logged_in := await _wait(func() -> bool: return app.screen == "demo_nickname" or app.screen == "demo_guest_error")
	_check(logged_in and app.screen == "demo_nickname", "actual guest login opens nickname UI: " + app.demo_guest.error)
	if app.screen != "demo_nickname":
		await _finish()
		return
	_check(_button(app, "이 닉네임으로 계속").disabled, "nickname required before room creation")
	_check(await _set_nickname(app, host_name) and app.demo_guest.nickname == host_name, "host nickname persists through API")
	var player_id := app.demo_guest.player_id
	var restored := DemoGuestClient.new()
	restored.session_path = app.demo_guest_session_path
	add_child(restored)
	_check(await restored.login(api_url) and restored.player_id == player_id and restored.nickname == host_name, "new client restores same DB guest and nickname")
	restored.queue_free()
	_press(app, "이 닉네임으로 계속")
	var waiting := await _wait(func() -> bool: return app.screen == "lan_waiting")
	_check(waiting and not app.lan_current_invite.is_empty(), "authenticated host room waiting")
	if not waiting:
		await _finish()
		return
	_check(_labels_contain(app, host_name), "waiting screen shows verified host nickname")
	guest_app = _create_app("guest", "yu-ran")
	guest_app._show_lan_join()
	guest_app.lan_invite_code = app.lan_current_invite
	_press(guest_app, "방 참가")
	_check(await _wait(func() -> bool: return guest_app.screen == "demo_nickname" or guest_app.screen == "demo_guest_error"), "guest login finishes within 8 seconds")
	if guest_app.screen != "demo_nickname":
		_check(false, "second actual guest login: " + guest_app.demo_guest.error)
		await _finish()
		return
	_check(await _set_nickname(guest_app, host_name), "duplicate nickname request completes")
	_check(guest_app.demo_guest.nickname.is_empty() and _labels_contain(guest_app, "이미 사용 중"), "duplicate nickname displays useful rejection")
	_check(await _set_nickname(guest_app, guest_name) and guest_app.demo_guest.nickname == guest_name, "guest distinct nickname saves")
	_press(guest_app, "이 닉네임으로 계속")
	var matched := await _wait(func() -> bool: return app.screen == "lan_match" and guest_app.screen == "lan_match")
	_check(matched, "both actual app clients enter LAN match")
	if matched:
		var map := app.match_scene.get_node("Interface/BattleMinimap") as BattleMinimap
		_check(map.participants[&"lan_host"].nickname == host_name and map.participants[&"lan_guest"].nickname == guest_name, "verified nicknames reach match minimap")
		_check(_button(app, "닉네임 저장") == null, "nickname mutation unavailable during match")
		guest_app.lan_client._send({"type": "leave"})
		_check(await _wait(func() -> bool: return app.screen == "lan_result"), "guest leave produces host result UI")
		_check(_labels_contain(app, host_name) and _labels_contain(app, guest_name), "result UI shows both verified nicknames")
	app.lan_client.stop()
	guest_app.lan_client.stop()
	app._show_lan_host()
	app.lan_host_code = LanInvite.host_code("ws://127.0.0.1:1", "http://127.0.0.1:1")
	_press(app, "방 생성")
	if app.screen == "demo_guest_error":
		_press(app, "새 게스트 시작 안내")
		_press(app, "새 게스트 시작")
	_press(app, "취소")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(app.screen == "lan_menu" and not app.demo_guest.busy, "cancel UI returns to LAN menu without busy state")
	await _finish()

func _finish() -> void:
	for target: LocalAiApp in [app, guest_app]:
		if target != null:
			target.demo_guest.cancel()
			target.lan_client.stop()
			target.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	for path: String in files: DirAccess.remove_absolute(path)
	print("DEMO_APP_RUNTIME: " + ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)
