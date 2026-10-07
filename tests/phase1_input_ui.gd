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
	var visual := instance.get_node("ArenaVisual")
	controller.presentation_event.emit(&"hit_resolved", {})
	if not visual.has_method("play_combat_event") or visual.get("_last_event") != &"hit_resolved":
		failures.append("presentation event boundary is missing")
	if player.get_pushbox_rect() == player.get_hurtbox_rect(): failures.append("pushbox was not distinct from hurtbox")

	# The active combat surface consumes registered textures while labels remain native UI text.
	var background := instance.get_node("ArenaVisual/Background") as TextureRect
	var terrain := instance.get_node("ArenaVisual/Terrain") as TextureRect
	var hud_panel := instance.get_node("Interface/HudPanel") as NinePatchRect
	var restart := instance.get_node("Interface/Restart") as Button
	var dpad_visual := touch.get_node("DPadVisual") as TextureRect
	var dash_visual := touch.get_node("DashVisual") as TextureRect
	if background.texture == null: failures.append("combat background resource was not applied")
	if not terrain.visible or terrain.texture == null: failures.append("expanded five-surface terrain image was not applied")
	elif terrain.texture.resource_path != resources.resource_path(controller.stage_data.terrain_asset_id): failures.append("stage terrain logical ID was not applied")
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

	# Only registered quality-dependent stage art changes across profiles.
	var original_quality: String = resources.quality
	var action_path: String = dash_visual.texture.resource_path
	for quality: String in ["high", "medium", "low"]:
		resources.set_quality(quality)
		if background.texture.resource_path != resources.resource_path("fa.background.combat.training.arena"):
			failures.append("combat background did not follow %s quality" % quality)
		if terrain.texture.resource_path != resources.resource_path("fa.terrain.combat.forest-ledge"):
			failures.append("combat terrain did not follow %s quality" % quality)
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
	var before := player.current_hp
	var fake := controller.snapshot()
	fake.fighters[0].current_hp = 87.0
	instance.call("_render_snapshot", fake)
	if player.current_hp != before: failures.append("HUD mutated fighter HP")
	if not (instance.get_node("Interface/MatchReadout") as Label).text.contains("87/"):
		failures.append("HUD did not render snapshot HP")
	if not (instance.get_node("Interface/MatchReadout") as Label).text.contains("G ") or not (instance.get_node("Interface/MatchReadout") as Label).text.contains("U "):
		failures.append("HUD did not render guard and ultimate resources")

	# Camera keeps the local fighter centered at the fixed ten-character framing.
	player.global_position = Vector2(controller.stage_data.ring_bounds.position.x, 400)
	controller.training_dummy.global_position = Vector2(controller.stage_data.ring_bounds.end.x, 400)
	var camera := instance.get_node("Camera2D") as Camera2D
	camera.call("_process", 0.016)
	if not is_equal_approx(camera.zoom.x, 1.25): failures.append("camera did not retain fixed 1.25 zoom")
	if camera.position != player.global_position: failures.append("camera did not target the local fighter")
	controller.training_dummy.global_position = Vector2(controller.stage_data.ring_bounds.position.x, 400)
	camera.call("_process", 0.016)
	if camera.position != player.global_position: failures.append("opponent movement changed the camera target")

	# The arrow is confined above touch controls and points toward a fully hidden opponent.
	var indicator := instance.get_node("Interface/OffscreenOpponentIndicator") as OffscreenOpponentIndicator
	var safe := OffscreenOpponentIndicator.safe_rect(Vector2(1280, 720), 0.085, 0.21, 0.50)
	var right_edge := OffscreenOpponentIndicator.edge_position(safe.get_center(), Vector2.RIGHT, safe)
	var upper_left := OffscreenOpponentIndicator.edge_position(safe.get_center(), Vector2(-1, -1), safe)
	var left_edge := OffscreenOpponentIndicator.edge_position(safe.get_center(), Vector2.LEFT, safe)
	var lower_edge := OffscreenOpponentIndicator.edge_position(safe.get_center(), Vector2.DOWN, safe)
	if not is_equal_approx(right_edge.x, safe.end.x): failures.append("right arrow did not reach the safe edge")
	if upper_left.x < safe.position.x or upper_left.y < safe.position.y: failures.append("diagonal arrow escaped the safe region")
	if not is_equal_approx(left_edge.x, safe.position.x): failures.append("left arrow did not reach the safe edge")
	if not is_equal_approx(lower_edge.y, safe.end.y): failures.append("lower arrow did not reach the safe edge")
	camera.position_smoothing_enabled = false
	player.global_position = Vector2(640, 520)
	controller.training_dummy.global_position = Vector2(1900, 520)
	camera.call("_process", 0.016)
	await process_frame
	indicator.update_indicator()
	if not indicator.visible: failures.append("fully offscreen opponent did not show an arrow")
	var actual_safe := OffscreenOpponentIndicator.safe_rect(indicator.get_viewport_rect().size, 0.085, 0.21, 0.50)
	if not actual_safe.grow(0.1).has_point(indicator.arrow_position): failures.append("opponent arrow overlapped unsafe UI region")
	var presentation_hash := controller.snapshot_hash()
	indicator.update_indicator()
	camera.call("_process", 0.016)
	if controller.snapshot_hash() != presentation_hash: failures.append("camera or arrow mutated combat state")
	# A sprite that still clips the viewport edge is visible and must not get an arrow.
	controller.training_dummy.global_position = Vector2(1145, 520)
	await process_frame
	indicator.update_indicator()
	if indicator.visible: failures.append("partly visible opponent kept an offscreen arrow")
	controller.training_dummy.state = FighterController.State.MATCH_ENDED
	controller.training_dummy.global_position = Vector2(1900, 520)
	indicator.update_indicator()
	if indicator.visible: failures.append("match end kept an offscreen arrow")

	instance.queue_free()
	if failures.is_empty():
		print("PHASE1_INPUT_UI: PASS")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("PHASE1_INPUT_UI: FAIL (%d)" % failures.size())
		quit(1)
