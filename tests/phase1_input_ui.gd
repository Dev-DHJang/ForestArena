extends SceneTree


func _initialize() -> void:
	var failures: PackedStringArray = []
	var resources := root.get_node("ForestArenaResources")
	var instance := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(instance)
	await process_frame
	var controller := instance.get_node("MatchController") as MatchController
	controller.set_physics_process(false)
	var touch := instance.get_node("Interface/TouchCommandSource")
	var player := controller.player

	# The active combat surface consumes registered textures while labels remain native UI text.
	var background := instance.get_node("ArenaVisual/Background") as TextureRect
	var hud_panel := instance.get_node("Interface/HudPanel") as NinePatchRect
	var restart := instance.get_node("Interface/Restart") as Button
	var dpad_visual := touch.get_node("DPadVisual") as TextureRect
	var dash_visual := touch.get_node("DashVisual") as TextureRect
	if background.texture == null: failures.append("combat background resource was not applied")
	if hud_panel.texture == null: failures.append("HUD panel resource was not applied")
	var restart_style := restart.get_theme_stylebox("normal") as StyleBoxTexture
	if restart_style == null or restart_style.texture == null: failures.append("restart button resource was not applied")
	if dpad_visual.texture == null or dash_visual.texture == null: failures.append("touch control resources were not applied")
	if not (dash_visual.get_child(0) is Label) or (dash_visual.get_child(0) as Label).text != "DASH":
		failures.append("action button label is not native Godot text")
	if not (instance.get_node("Interface/ResourceWarnings") as Label).text.is_empty():
		failures.append("registered combat UI resources reported as missing")

	# Resource visuals follow the same press/release state as semantic input.
	touch.call("_press", 21, &"move_up")
	if dpad_visual.texture.resource_path != resources.resource_path("fa.ui.combat.dpad.up"):
		failures.append("D-pad pressed texture did not follow move_up")
	touch.call("_press", 22, &"dash")
	if dash_visual.texture.resource_path != resources.resource_path("fa.ui.combat.action.pressed"):
		failures.append("action pressed texture did not follow dash")
	touch.call("_release", 21)
	touch.call("_release", 22)
	if dpad_visual.texture.resource_path != resources.resource_path("fa.ui.combat.dpad.default"):
		failures.append("D-pad visual did not return to default")
	if dash_visual.texture.resource_path != resources.resource_path("fa.ui.combat.action.default"):
		failures.append("action visual did not return to default")

	# Only the quality-dependent backdrop changes across profiles.
	var original_quality: String = resources.quality
	var action_path: String = dash_visual.texture.resource_path
	for quality: String in ["high", "medium", "low"]:
		resources.set_quality(quality)
		if background.texture.resource_path != resources.resource_path("fa.background.combat.training.arena"):
			failures.append("combat background did not follow %s quality" % quality)
		if dash_visual.texture.resource_path != action_path:
			failures.append("common action texture changed with %s quality" % quality)
	resources.set_quality(original_quality)

	# Drag transitions release the previous pointer action and press one dominant axis.
	touch.call("_press", 20, &"move_left")
	var drag := InputEventScreenDrag.new()
	drag.index = 20
	var size: Vector2 = touch.get_viewport_rect().size
	drag.position = Vector2(size.x * 0.43, size.y * 0.75)
	touch.call("handle_pointer_event", drag)
	if Input.is_action_pressed(&"move_left") or not Input.is_action_pressed(&"move_right"): failures.append("D-pad drag transition failed")
	touch.release_all_touches()

	# Pause clears held movement and the one-slot buffered intent without advancing ticks.
	player.input_direction = CombatIntent.Direction.RIGHT
	player.buffered_intent = CombatIntent.new(1, player.fighter_id, &"attack_light")
	var paused_tick := controller.tick
	controller.pause_match(true)
	controller.step_fixed_tick(false)
	if player.input_direction != CombatIntent.Direction.NEUTRAL or player.buffered_intent != null: failures.append("pause did not clear fighter input")
	if controller.tick != paused_tick: failures.append("paused match advanced a fixed tick")
	controller.pause_match(false)
	controller.step_fixed_tick(false)
	if controller.tick != paused_tick + 1: failures.append("resume did not continue exactly one tick")

	# HUD rendering consumes a supplied snapshot but cannot mutate fighter authority state.
	var before := player.damage_percent
	var fake := controller.snapshot()
	fake.fighters[0].damage_percent = 87.0
	instance.call("_render_snapshot", fake)
	if player.damage_percent != before: failures.append("HUD mutated fighter damage")
	if not (instance.get_node("Interface/MatchReadout") as Label).text.contains("87%"):
		failures.append("HUD did not render snapshot damage")

	# Camera follows the pair and stays within its configured zoom bounds.
	player.global_position = Vector2(controller.rules.ring_left, 400)
	controller.training_dummy.global_position = Vector2(controller.rules.ring_right, 400)
	var camera := instance.get_node("Camera2D") as Camera2D
	camera.call("_process", 0.016)
	if camera.zoom.x < 0.779 or camera.zoom.x > 1.001: failures.append("camera zoom escaped limits")

	instance.queue_free()
	if failures.is_empty():
		print("PHASE1_INPUT_UI: PASS")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("PHASE1_INPUT_UI: FAIL (%d)" % failures.size())
		quit(1)
