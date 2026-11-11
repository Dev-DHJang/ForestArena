extends SceneTree

const CAPTURE_DIR := "res://build/menu09-match-preview"
var failures: Array[String] = []
var app
var capture := "--ui-capture" in OS.get_cmdline_user_args()

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, description: String) -> void:
	if not condition: failures.append(description)

func control(id: String) -> Control:
	for node: Node in app.page.find_children("*", "Control", true, false):
		if node.get_meta("qa_id", "") == id: return node as Control
	return null

func press(id: String) -> void:
	var button := control(id) as Button
	check(is_instance_valid(button) and not button.disabled, "available button: " + id)
	if is_instance_valid(button) and not button.disabled: button.pressed.emit()
	await process_frame
	await process_frame

func labels() -> String:
	var result := ""
	for node: Label in app.page.find_children("*", "Label", true, false):
		if node.is_visible_in_tree(): result += node.text + "\n"
	return result

func frame(name: String) -> void:
	await process_frame
	await process_frame
	if not capture: return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(not image.is_empty(), "viewport capture: " + name)
	if not image.is_empty(): image.save_png(CAPTURE_DIR + "/" + name + ".png")

func check_canvas() -> void:
	var canvas: Control = app.menu09_match_view.canvas
	var viewport := root.get_visible_rect()
	for node: Button in canvas.find_children("*", "Button", true, false):
		if not node.is_visible_in_tree() or node is OptionButton: continue
		var bounds := node.get_global_rect()
		check(viewport.encloses(bounds) and bounds.size.x >= 71 and bounds.size.y >= 71,
			"button within viewport with 72px touch area: " + node.text)

func run() -> void:
	root.size = Vector2i(1280, 720)
	if capture:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		DirAccess.make_dir_recursive_absolute(CAPTURE_DIR)
	app = (load("res://scenes/local_ai_app.tscn") as PackedScene).instantiate()
	app.save_path = "user://menu09-match-test-%d/profile.json" % Time.get_ticks_usec()
	app.db_session_path = app.save_path + ".session"
	app.demo_guest_session_path = app.save_path + ".demo-session"
	DirAccess.make_dir_recursive_absolute(app.save_path.get_base_dir())
	root.add_child(app)
	check(app.store.grant_first("ja-hyun") and app.store.purchase("nabi"), "real active character setup")
	app._show_home()
	await frame("lobby-1280")
	check(app.page.get_meta("menu_screen_id") == "SCR_03_Lobby" and "신기 · 미장착" in labels(), "approved lobby and current loadout")
	check_canvas()
	root.size = Vector2i(1600, 720)
	if capture: DisplayServer.window_set_size(Vector2i(1600, 720))
	await frame("lobby-20x9")
	check_canvas()
	root.size = Vector2i(1280, 720)
	if capture: DisplayServer.window_set_size(Vector2i(1280, 720))
	await press("home/button/일반대전/0")
	await frame("mode-select")
	check(app.screen == "mode_select" and app.page.get_meta("menu_screen_id") == "SCR_09_ModeSelect", "general mode selector")
	await press("mode_select/button/자동 매칭/0")
	check(is_instance_valid(app.menu09_match_view.overlay) and not app.lan_client.active, "unavailable matchmaking opens local information")
	app.handle_back_request(1000)
	check(app.screen == "mode_select" and not is_instance_valid(app.menu09_match_view.overlay), "Android back closes information first")
	await press("mode_select/button/AI/0")
	await frame("ai-room")
	check(app.screen == "prepare" and "참가자 2 / 8" in labels(), "actual AI participants occupy two room slots")
	await press("prepare/button/나비/0")
	check(app.store.data.selected_character == "nabi", "room quick selection applies owned character")
	await press("prepare/button/준비하기/0")
	var accessory := control("prepare/choice/장신구") as OptionButton
	check(is_instance_valid(accessory) and accessory.disabled, "ready state locks setup selectors")
	await press("prepare/button/준비 취소/0")
	check(not app._menu09_ready and not (control("prepare/choice/장신구") as OptionButton).disabled, "cancel ready restores setup")
	await press("prepare/button/준비하기/0")
	await press("prepare/button/대전 시작/0")
	check(app.screen == "match" and app.active_config.mode == LocalMatchConfig.Mode.AI and app.active_config.player.character_id == &"nabi", "ready AI starts the real selected match")
	app._close_match()
	app._show_mode_select()
	await press("mode_select/button/로비/0")
	await frame("room-list")
	check(app.screen == "lan_menu" and "공개 방 목록 준비 중" in labels(), "public room empty state")
	await press("lan_menu/button/팀전/0")
	check(app.menu09_room_filter == "팀전" and "팀전 공개 방 목록 준비 중" in labels(), "room filter applies to empty state")
	await press("lan_menu/button/초대 코드로 참가/0")
	await frame("invite-code")
	check(app.screen == "lan_join", "existing LAN code flow")
	await press("lan_join/button/방 참가/0")
	check(app.screen == "lan_menu" and app.menu09_room_filter == "팀전" and "LAN 연결 실패" in labels(), "invalid LAN code returns with reason and filter")
	await press("lan_menu/button/팀전 준비/0")
	for _index: int in 2: await press("prepare/button/AI 추가/0")
	await frame("team-room")
	check(app._build_match_config().participants.size() == 8 and "A팀 · 윗줄" in labels(), "four players per team and eight seats")
	check((control("prepare/button/AI 추가/0") as Button).disabled, "team capacity blocks another AI addition")
	await press("prepare/button/나가기/0")
	await press("prepare/button/취소/0")
	check(app.screen == "prepare", "cancel exit remains in current room")
	await press("prepare/button/나가기/0")
	var exit_buttons: Array[Node] = app.menu09_match_view.overlay.find_children("*", "Button", true, false)
	var confirm := exit_buttons.back() as Button
	await press(String(confirm.get_meta("qa_id")))
	check(app.screen == "lan_menu" and app.menu09_room_filter == "팀전", "confirm exit restores the originating filter")
	app._show_home()
	await press("home/button/랭킹대전/0")
	await frame("rank-lobby")
	check(app.screen == "rank_lobby" and "실버 3 · 예시" in labels() and "시즌" in labels(), "rank lobby labels example rank")
	check(app.menu09_match_view.canvas.find_children("*", "TextureRect", true, false).size() == 1, "rank lobby renders silver emblem")
	await press("rank_lobby/button/LAN 순위 보기/0")
	check(app.screen == "rank", "existing LAN ranking opens separately")
	await create_timer(0.25).timeout
	await press("menu/rank/back")
	check(app.screen == "rank_lobby", "LAN ranking back returns to rank lobby")
	app.queue_free()
	root.get_node("ForestArenaAudio").shutdown()
	await process_frame
	await process_frame
	for failure: String in failures: push_error(failure)
	print("MENU09_MATCH_RUNTIME: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
