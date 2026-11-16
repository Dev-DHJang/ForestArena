extends SceneTree

var app: Node
var audio: Node
var checks: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var failures := 0
var fixture := "user://menu09-video-independent-qa-%d" % OS.get_process_id()
var output_dir := OS.get_environment("MENU09_QA_OUTPUT")

func _initialize() -> void:
	call_deferred("run")

func settle(seconds := 0.27) -> void:
	await process_frame
	await create_timer(seconds).timeout
	await process_frame

func check(condition: bool, name: String) -> void:
	checks.append({"name": name, "pass": condition})
	if not condition:
		failures += 1
		printerr(name)

func press(id: String) -> void:
	for node: Node in app.page.find_children("*", "Button", true, false):
		var button := node as Button
		if button.get_meta("qa_id", "") == id and not button.disabled:
			button.pressed.emit()
			await settle()
			return
	check(false, "control is available: " + id)

func player() -> VideoStreamPlayer:
	return app.page.find_child("Menu09Video", true, false) as VideoStreamPlayer

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless" or output_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	check(screenshot.save_png(output_dir.path_join(name + ".png")) == OK, "native render saved: " + name)

func open_video(key: String) -> VideoStreamPlayer:
	await press("menu/media/play/" + key)
	var node := player()
	check(is_instance_valid(node), "app opens video player: " + key)
	if node == null:
		return null
	var resources := root.get_node("ForestArenaResources")
	var stream: VideoStream = resources.load_video("fa.ui.menu09.video." + key)
	check(stream is VideoStreamTheora and node.stream is VideoStreamTheora, "resource manager and app use native Theora: " + key)
	check(stream.resource_path == node.stream.resource_path and node.get_meta("media_key") == key, "logical ID resolves the selected app clip: " + key)
	check(node.is_playing() and node.stream_position > 0.05, "app stream is advancing: " + key)
	var texture := node.get_video_texture()
	check(texture != null and texture.get_width() == 960 and texture.get_height() == 540, "native 960x540 video texture: " + key)
	samples.append({"key": key, "position": node.stream_position, "resource_path": node.stream.resource_path})
	return node

func erase_fixture(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for child: String in directory.get_directories():
		erase_fixture(path.path_join(child))
	for file: String in directory.get_files():
		directory.remove(file)
	DirAccess.remove_absolute(path)

func run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(fixture)
	audio = root.get_node("ForestArenaAudio")
	var original_audio_path: String = audio.settings_path
	audio.settings_path = fixture.path_join("audio.cfg")
	app = load("res://scenes/local_ai_app.tscn").instantiate()
	app.save_path = fixture.path_join("profile.json")
	app.db_session_path = fixture.path_join("db-session.json")
	app.demo_guest_session_path = fixture.path_join("demo-session.json")
	root.add_child(app)
	await settle()
	check(app.store.grant_first("ja-hyun"), "isolated fixture grants Ja-hyun")
	app._show_home()
	await settle()
	app._show_premium_menu("character_collection")
	await settle()
	await press("menu/character_collection/detail")
	var ja := await open_video("ja-hyun.light")
	if is_instance_valid(ja):
		await capture("character-video-playing")
		await press("menu/media/toggle")
		var paused_at := ja.stream_position
		await settle(0.4)
		check(ja.paused and absf(ja.stream_position - paused_at) < 0.06, "pause holds the stream position")
		await capture("character-video-paused")
		await press("menu/media/toggle")
		check(not ja.paused and ja.stream_position > paused_at + 0.05, "resume advances the same stream")
		app.handle_back_request()
		await settle()
		check(player() == null and not is_instance_valid(app.menu_router.view.modal), "Android back handler closes the player modal")
		check(app.menu_router.state.id == "character_detail" and app.menu_router.state.selected_id == "ja-hyun", "back restores the current technique screen")
		check(not is_instance_valid(ja), "modal close frees the player")
	app.menu_router.reset()
	app._show_premium_menu("accessory_collection", {"filter": "defense"})
	await settle()
	check(app.menu_router.state.selected_id == "fixture-iron-armor", "defense category opens iron armor")
	var armor := await open_video("accessory.iron-armor")
	if is_instance_valid(armor):
		var deadline := Time.get_ticks_msec() + 6000
		while armor.is_playing() and Time.get_ticks_msec() < deadline:
			await settle(0.1)
		check(not armor.is_playing() and app.menu_router.view._media_status.text == "재생 완료", "iron armor reaches the app completion state")
		await capture("artifact-video-completed")
		await press("menu/media/toggle")
		check(armor.is_playing() and armor.stream_position > 0.05 and armor.stream_position < 1.0, "replay restarts the ended clip")
		await press("menu/media/close")
		check(player() == null and not is_instance_valid(armor), "explicit close releases the video player")
	app.menu_router.reset()
	app._show_premium_menu("shop", {"category": "character"})
	await settle()
	await press("menu/shop/detail/nabi")
	await press("menu/shop_detail/technique/heavy")
	var nabi := await open_video("nabi.heavy")
	if is_instance_valid(nabi):
		await capture("shop-video-playing")
		app.page.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		check(nabi.paused, "application pause notification pauses the app player")
		await press("menu/media/close")
		check(app.menu_router.state.id == "shop_detail" and app.menu_router.state.product_id == "nabi", "shop video close retains selected product")
		await press("menu/shop_detail/back")
		check(app.menu_router.state.id == "shop" and app.menu_router.state.category == "character", "shop detail returns to the character list")
	if not output_dir.is_empty():
		var output := FileAccess.open(output_dir.path_join("native-video-report.json"), FileAccess.WRITE)
		output.store_string(JSON.stringify({"checks": checks, "failures": failures, "samples": samples, "display": DisplayServer.get_name(), "android_device": "not-run"}, "\t") + "\n")
	app.queue_free()
	await process_frame
	await process_frame
	audio.settings_path = original_audio_path
	erase_fixture(fixture)
	print("MENU09_INDEPENDENT_VIDEO_PROBE %d checks, %d failures" % [checks.size(), failures])
	quit(0 if failures == 0 else 1)
