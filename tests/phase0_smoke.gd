extends SceneTree

const REQUIRED_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"dash", &"attack_light", &"attack_heavy", &"attack_special"
]


func _initialize() -> void:
	var failures: PackedStringArray = []
	if ProjectSettings.get_setting("display/window/handheld/orientation") != 0:
		failures.append("Android orientation is not landscape")
	if ProjectSettings.get_setting("display/window/stretch/aspect") != "expand":
		failures.append("wide-screen stretch aspect is not expand")
	if not ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc", false):
		failures.append("Android ETC2/ASTC texture import is disabled")
	for action: StringName in REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			failures.append("missing InputMap action: %s" % action)
	if InputMap.has_action(&"grab"):
		failures.append("removed grab InputMap action remains")

	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	if packed_scene == null:
		failures.append("main scene could not be loaded")
	else:
		var instance := packed_scene.instantiate()
		root.add_child(instance)
		await process_frame
		for node_path: NodePath in [
			NodePath("World/Ground"), NodePath("World/Platform"), NodePath("World/Player"),
			NodePath("World/TrainingDummy"), NodePath("World/KillVolumes/Left"), NodePath("World/KillVolumes/Right"),
			NodePath("World/KillVolumes/Top"), NodePath("World/KillVolumes/Bottom"), NodePath("MatchController"),
			NodePath("Camera2D"), NodePath("Interface/TouchCommandSource"), NodePath("Interface/DebugReadout")
		]:
			if instance.get_node_or_null(node_path) == null:
				failures.append("missing scene node: %s" % node_path)
		var touch_source := instance.get_node("Interface/TouchCommandSource")
		var viewport_size: Vector2 = touch_source.get_viewport_rect().size
		if touch_source.call("_action_for", Vector2(viewport_size.x * 0.02, viewport_size.y * 0.9)) != &"":
			failures.append("safe edge accepted a touch action")
		if touch_source.call("_action_for", Vector2(viewport_size.x * 0.1, viewport_size.y * 0.9)) != &"move_left":
			failures.append("left touch region mapping is incorrect")
		if touch_source.call("_action_for", Vector2(viewport_size.x * 0.43, viewport_size.y * 0.75)) != &"move_right":
			failures.append("right touch region mapping is incorrect")
		if touch_source.call("_action_for", Vector2(viewport_size.x * 0.275, viewport_size.y * 0.62)) != &"move_up":
			failures.append("up touch region mapping is incorrect")
		if touch_source.call("_action_for", Vector2(viewport_size.x * 0.275, viewport_size.y * 0.91)) != &"move_down":
			failures.append("down touch region mapping is incorrect")
		if touch_source.call("_action_for", Vector2(viewport_size.x * 0.275, viewport_size.y * 0.757)) != &"":
			failures.append("D-pad dead zone accepted an action")
		touch_source.call("_press", 10, &"jump")
		touch_source.call("_press", 11, &"jump")
		touch_source.call("_press", 12, &"move_right")
		touch_source.call("_release", 10)
		if not Input.is_action_pressed(&"jump"):
			failures.append("releasing one pointer cleared another pointer action")
		if not Input.is_action_pressed(&"move_right"):
			failures.append("direction and action multitouch did not coexist")
		touch_source.call("release_all_touches")
		if Input.is_action_pressed(&"jump"):
			failures.append("release_all_touches left a synthetic action pressed")
		if Input.is_action_pressed(&"move_right"):
			failures.append("release_all_touches left movement pressed")
		instance.queue_free()

	if failures.is_empty():
		print("PHASE0_SMOKE: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("PHASE0_SMOKE: FAIL (%d)" % failures.size())
		quit(1)
