extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var preparer = load("res://scripts/ui_resource_preparer.gd").new()
	root.add_child(preparer)
	var path: String = root.get_node("ForestArenaResources").resource_path("fa.background.title.forest")
	var paths: Array[String] = [path]
	preparer.prepare(paths)
	preparer.cancel()
	var ok: bool = await preparer.prepare(paths)
	print("QA-LOADER-CANCEL samepath immediate retry=%s error=%s" % [ok, preparer.error])
	await create_timer(0.2).timeout
	var later: bool = await preparer.prepare(paths)
	print("QA-LOADER-CANCEL samepath later retry=%s error=%s" % [later, preparer.error])
	preparer.queue_free()
	await process_frame
	quit(0 if ok and later else 1)
