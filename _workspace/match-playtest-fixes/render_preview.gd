extends SceneTree
var app
func _initialize() -> void:
	call_deferred("run")
func capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://_workspace/match-playtest-fixes/" + label + ".jpg", 0.90)
func run() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	app = load("res://scenes/local_ai_app.tscn").instantiate()
	app.save_path = "user://match-preview-%d.json" % Time.get_ticks_usec()
	root.add_child(app)
	await process_frame
	app.store.grant_first("nabi")
	for product: Dictionary in app.catalog.products: app.store.purchase(String(product.id))
	app.store.select("nabi", "", "ja-hyun")
	app.selected_mode = LocalMatchConfig.Mode.PRACTICE
	app.start_match()
	for i: int in 50: await physics_frame
	app.match_controller.set_physics_process(false)
	app.match_controller.training_dummy.global_position = app.match_controller.player.global_position + Vector2(120, 0)
	app.match_controller.snapshot_changed.emit(app.match_controller.snapshot())
	await capture("battle-2-16x9")
	app.selected_mode = LocalMatchConfig.Mode.TEAM
	app.team_size = 4
	app.start_match()
	for i: int in 45: await physics_frame
	app.match_controller.set_physics_process(false)
	await capture("battle-8-16x9")
	root.size = Vector2i(1600, 720)
	DisplayServer.window_set_size(root.size)
	await capture("battle-8-20x9")
	app.match_scene.apply_accessibility({"text_scale": 1.3})
	await capture("battle-8-large-text")
	app.queue_free()
	await process_frame
	quit()
