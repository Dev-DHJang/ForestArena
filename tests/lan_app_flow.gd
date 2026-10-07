extends Node

const TIMEOUT_MSEC := 7000

var failures: Array[String] = []
var app: LocalAiApp
var guest: LanMatchClient
var save_path := "user://test-lan-app-%d.json" % Time.get_ticks_usec()


func _ready() -> void:
	_run()


func _run() -> void:
	app = LocalAiApp.new()
	app.save_path = save_path
	add_child(app)
	app.lan_client.failed.connect(func(code: String) -> void: print("LAN_APP_FLOW_CLIENT_ERROR " + code))
	await get_tree().process_frame
	_check(app.store.grant_first("nabi"), "first grant")
	for item: Dictionary in app.catalog.products:
		if not app.store.owns(item.id): _check(app.store.purchase(item.id), "purchase %s" % item.id)
	_check(app.store.select("nabi", "fixture-iron-armor", "yu-ran"), "host selection")
	var host_selection := LoadoutSelection.new()
	host_selection.character_id = &"nabi"
	host_selection.accessory_id = &"fixture-iron-armor"
	_check(app.lan_client.begin_host("FAH1|ws://127.0.0.1:17777|1", host_selection), "host connect")
	_check(await _wait_until(func() -> bool: return not app.lan_current_invite.is_empty()), "room invite")
	app.call("_copy_lan_invite")
	_check(app.lan_status_label != null and app.lan_status_label.text.contains("복사했습니다"), "invite copy feedback")
	guest = LanMatchClient.new()
	add_child(guest)
	var guest_selection := LoadoutSelection.new()
	guest_selection.character_id = &"yu-ran"
	guest_selection.accessory_id = &"fixture-boxing-gloves"
	_check(guest.begin_join(app.lan_current_invite, guest_selection), "guest connect")
	var entered_match := await _wait_until(func() -> bool: return app.screen == "lan_match" and app.match_controller != null)
	_check(entered_match, "LAN match screen (screen=%s)" % app.screen)
	if not entered_match:
		await _finish()
		return
	_check(await _wait_until(func() -> bool: return app.match_controller != null and app.match_controller.player.runtime_profile.character_id == &"nabi" and app.match_controller.training_dummy.runtime_profile.character_id == &"yu-ran"), "network loadouts")
	var camera := app.match_scene.get_node("Camera2D") as Camera2D
	_check(camera.player == app.match_controller.player, "host camera target")
	_check(not app.match_controller.is_physics_processing() and app.match_controller.paused, "client is presentation only")
	guest.call("_send", {"type": "leave"})
	_check(await _wait_until(func() -> bool: return app.screen == "lan_result"), "LAN result")
	_check(app.body.get_child_count() > 0, "result UI")
	await _finish()


func _finish() -> void:
	if app != null:
		app.lan_client.stop()
		app.queue_free()
	if guest != null:
		guest.stop()
		guest.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + ".bak"))
	if failures.is_empty():
		print("LAN_APP_FLOW: PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures: push_error(failure)
		get_tree().quit(1)


func _wait_until(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await get_tree().process_frame
	return false


func _check(condition: bool, label: String) -> void:
	if not condition: failures.append(label)
