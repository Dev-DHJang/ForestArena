extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1184,720)
	DisplayServer.window_set_size(root.size)
	print("LOGICAL_VIEWPORT=", root.get_visible_rect())
	var app = load("res://scenes/local_ai_app.tscn").instantiate()
	var directory := "user://premium-font-qa-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	app.save_path = directory + "/profile.json"
	app.db_session_path = directory + "/session.json"
	root.add_child(app)
	await process_frame
	app.store.grant_first("ja-hyun")
	app._show_premium_menu("shop")
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var png := root.get_texture().get_image()
	png.save_png("res://_workspace/premium-menu-v07-runtime/qa-captures/narrow-font-proof.png")
	app.queue_free()
	await process_frame
	var folder := DirAccess.open(directory)
	for file: String in folder.get_files(): DirAccess.remove_absolute(directory + "/" + file)
	DirAccess.remove_absolute(directory)
	quit()
