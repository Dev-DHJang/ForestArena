extends SceneTree

var app: Node
var output := "res://_workspace/battle-minimap/screens"
var path := "user://minimap-visual-%d.json" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(output + "/" + name + ".png")
	print("MINIMAP_APP_RENDER " + name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280, 720)
	app = (load("res://scenes/local_ai_app.tscn") as PackedScene).instantiate()
	app.save_path = path
	app.db_session_path = path + ".session"
	root.add_child(app)
	await process_frame
	app.store.grant_first("ja-hyun")
	app.store.update_identity("숲지기")
	app.start_match()
	app.match_controller.set_physics_process(false)
	await capture("app-2-face-16x9")
	app._close_match()
	app.selected_mode = LocalMatchConfig.Mode.TEAM
	app.team_size = 4
	app.store.update_accessibility(1.3, false, true)
	app.start_match()
	app.match_controller.set_physics_process(false)
	var fighters: Array = app.match_controller.call("_fighters")
	for index: int in fighters.size():
		fighters[index].global_position = Vector2(-250 + index * 225, 520 if index % 2 == 0 else 270)
	app.match_controller.snapshot_changed.emit(app.match_controller.snapshot())
	await capture("app-8-team-large-16x9")
	app._close_match()
	root.size = Vector2i(1600, 720)
	app.selected_mode = LocalMatchConfig.Mode.SOLO
	app.solo_participant_count = 8
	app.store.update_minimap({"transparency": 30, "marker_style": "dot", "show_names": false})
	app.start_match()
	app.match_controller.set_physics_process(false)
	await capture("app-8-solo-dot-20x9")
	app._close_match()
	app._show_accessibility()
	await process_frame
	var scroll := app.body.get_parent() as ScrollContainer
	scroll.scroll_vertical = 510
	await capture("app-settings-preview")
	app.queue_free()
	await process_frame
	for suffix: String in ["", ".bak", ".tmp", ".session"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	quit()
