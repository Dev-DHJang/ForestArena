extends SceneTree
## Drives the actual MENU09 routes and buttons against a separate local profile.

var _app: Node
var _failures: Array[String] = []
var _output := ""
var _capture := "--ui-capture" in OS.get_cmdline_user_args()
var _profile_path := "user://menu09-life-qa-%d/profile.json" % Time.get_ticks_usec()


func _initialize() -> void:
	_output = OS.get_environment("FOREST_ARENA_VERIFY_OUTPUT").path_join("menu09-life")
	_run.call_deferred()
	create_timer(40).timeout.connect(func() -> void:
		push_error("MENU09 life runtime did not complete")
		quit(1), CONNECT_ONE_SHOT)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
		push_error(description)


func _settle() -> void:
	await create_timer(0.54).timeout
	await process_frame


func _control(qa_id: String) -> Control:
	for control: Control in _app.page.find_children("*", "Control", true, false):
		if String(control.get_meta("qa_id", "")) == qa_id:
			return control
	return null


func _press(qa_id: String) -> void:
	var button := _control(qa_id) as Button
	_check(is_instance_valid(button) and not button.disabled and button.is_visible_in_tree(), "available button: " + qa_id)
	if is_instance_valid(button) and not button.disabled:
		button.pressed.emit()
		await _settle()


func _disabled(qa_id: String) -> bool:
	var button := _control(qa_id) as Button
	return is_instance_valid(button) and button.disabled


func _labels() -> String:
	var lines: PackedStringArray = []
	for label: Label in _app.page.find_children("*", "Label", true, false):
		lines.append(label.text)
	return "\n".join(lines)


func _open(menu_id: String, params: Dictionary = {}) -> void:
	_app._show_premium_menu(menu_id, params)
	await _settle()
	_check(String(_app.menu_router.state.get("id", "")) == menu_id, "runtime menu opens: " + menu_id)


func _frame(name: String) -> void:
	if not _capture:
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_output)
	var error := root.get_texture().get_image().save_png(_output.path_join(name + ".png"))
	_check(error == OK, "capture saved: " + name)


func _mission_flow() -> void:
	await _open("mission", {"category": "daily"})
	_check(_control("menu/mission/mission/daily-play") != null, "daily mission uses the live local journal")
	await _frame("mission-daily")
	await _press("menu/mission/category/weekly")
	_check(_control("menu/mission/mission/weekly-play") != null, "weekly shows actual weekly record")
	await _press("menu/mission/category/attendance")
	var days: Array[Node] = _app.page.find_children("*", "PanelContainer", true, false)
	_check(days.filter(func(day: Node) -> bool: return day.has_meta("menu09_attendance_day")).size() == 28, "attendance shows 28 example cells")
	_check(_disabled("menu/mission/attendance_check"), "attendance cannot issue rewards or fake check-in")
	await _frame("attendance")
	await _press("menu/mission/attendance_info")
	_check(is_instance_valid(_app.menu_router.view.modal), "attendance operating info opens")
	await _press("menu/mission/modal_cancel")
	_check(_app.menu_router.state.category == "attendance", "close returns to attendance")
	await _press("menu/mission/open_achievement")
	_check(_control("menu/mission/achievement_group/combat") != null and _control("menu/mission/achievement_group/collection") != null and _control("menu/mission/achievement_group/skills") != null, "achievement landing exposes three distinct groups")
	await _frame("achievements")
	await _press("menu/mission/achievement_group/combat")
	_check(_control("menu/mission/mission/first-play") != null, "battle achievements read actual journal")
	await _press("menu/mission/achievement_group/collection")
	_check(_control("menu/mission/mission/first-play") == null and _disabled("menu/mission/achievement_reward"), "collection achievement is pending, without battle data or claims")
	await _press("menu/mission/achievement_group/skills")
	_check("기술 업적" in _labels() and _disabled("menu/mission/achievement_reward"), "skills has its own pending view")
	await _press("menu/mission/achievement_info")
	_check(is_instance_valid(_app.menu_router.view.modal) and _disabled("menu/mission/unavailable"), "achievement info has a disabled reward action")
	await _press("menu/mission/modal_cancel")
	_check(_app.menu_router.state.achievement_group == "skills", "closing info returns to the selected achievement group")
	await _press("menu/mission/back")
	_check(_app.menu_router.state.achievement_group.is_empty() and _control("menu/mission/achievement_group/combat") != null, "achievement detail back returns to its group menu")
	await _press("menu/mission/return_to_mission")
	_check(_app.menu_router.state.category == "attendance", "achievement return retains prior mission tab")


func _life_flow() -> void:
	await _open("social", {"category": "friends"})
	var field := _control("menu/social/search_input") as LineEdit
	_check(is_instance_valid(field) and field.max_length == 12, "native exact nickname search is present")
	await _frame("friends")
	await _press("menu/social/category/incoming")
	_check(_app.menu_router.state.category == "incoming" and _control("menu/social/search_input") != null, "incoming tab and common search coexist")
	await _press("menu/social/category/invites")
	_check(_app.menu_router.state.category == "invites", "native incoming LAN invite view is reachable")
	await _open("mail")
	_check(_app.page.get_meta("menu_screen_id") == "EXT_MENU09_Mailbox", "mail keeps approved screen ID")
	_check("표시할 우편이 없습니다" in _labels(), "mail shows an honest empty state")
	for id: String in ["mail_claim_all", "mail_delete", "mail_delete_all"]:
		_check(_disabled("menu/mail/" + id), "unavailable mail action: " + id)
	await _frame("mail")
	await _open("notices")
	_check(_app.page.get_meta("menu_screen_id") == "EXT_MENU09_Notices", "notices keeps approved screen ID")
	await _press("menu/notices/category/active")
	_check("표시할 진행 이벤트가 없습니다" in _labels(), "active events empty state")
	await _press("menu/notices/category/past")
	_check("표시할 지난 이벤트가 없습니다" in _labels(), "past events empty state")
	await _frame("notices")
	await _press("menu/notices/back")
	_check(_app.menu_router.state.id == "mail", "close returns through existing route stack")


func _settings_flow() -> void:
	_app.menu_router.reset()
	await _open("settings")
	_check(_app.menu_router.state.category == "effects", "settings first opens graphics")
	_check(_control("menu/settings/category/debug") != null and _control("menu/settings/draft/reduce_visual_effects") != null, "graphics displays existing accessibility-backed options")
	await _frame("settings-graphics")
	await _press("menu/settings/category/sound")
	var slider := _control("menu/settings/draft/music") as HSlider
	_check(is_instance_valid(slider), "sound uses existing native slider")
	if is_instance_valid(slider):
		slider.value = 0.15 if not is_equal_approx(slider.value, 0.15) else 0.65
	await _press("menu/settings/category/account")
	_check(_app.menu_router.state.category == "sound" and is_instance_valid(_app.menu_router.view.modal), "dirty sound asks before navigating to account")
	await _press("menu/settings/modal_cancel")
	await _press("menu/settings/settings_cancel")
	await _press("menu/settings/category/account")
	await _press("menu/settings/profile")
	_check(_app.menu_router.state.id == "profile", "account profile entry reaches existing profile")
	await _press("menu/profile/back")
	_check(_app.menu_router.state.id == "settings" and _app.menu_router.state.category == "account", "profile back returns to account")
	await _press("menu/settings/category/notifications")
	_check(_disabled("menu/settings/notifications_unavailable"), "unimplemented notification permission is unavailable")
	await _press("menu/settings/category/info")
	_check(_control("menu/settings/notices") != null, "info links to notices")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_profile_path.get_base_dir())
	var store := LocalPlayerStore.new(LocalPlayCatalog.new(), _profile_path)
	_check(store.grant_first("ja-hyun"), "isolated profile prepared")
	_app = (load("res://scenes/local_ai_app.tscn") as PackedScene).instantiate()
	_app.save_path = _profile_path
	_app.db_session_path = _profile_path.get_base_dir().path_join("db-session.json")
	_app.demo_guest_session_path = _profile_path.get_base_dir().path_join("demo-session.json")
	root.add_child(_app)
	await _settle()
	await _mission_flow()
	await _life_flow()
	await _settings_flow()
	_app.queue_free()
	await process_frame
	await process_frame
	print("MENU09_LIFE_RUNTIME: %s (%d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	quit(0 if _failures.is_empty() else 1)
