extends SceneTree

const Presentation = preload("res://scripts/local_fighter_presentation.gd")
const IDS = [&"ja-hyun", &"myo-ryung", &"nabi", &"yu-ran"]
const STATES = [FighterController.State.IDLE, FighterController.State.RUN, FighterController.State.JUMP, FighterController.State.FALL]

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var fighters = []
	root.size = Vector2i(1000,700)
	RenderingServer.set_default_clear_color(Color("263044"))
	for column in range(4):
		var title = Label.new()
		title.text = String(IDS[column])
		title.position = Vector2(55+column*240,15)
		root.add_child(title)
		for row in range(4):
			var fighter = FighterController.new()
			fighter.character_data = load("res://assets/character/%s/character.tres" % IDS[column])
			fighter.position = Vector2(100+column*240,140+row*165)
			root.add_child(fighter)
			fighters.append(fighter)
			fighter.set_physics_process(false)
			var profile = RuntimeCombatProfile.new()
			profile.character_id = IDS[column]
			profile.stats = fighter.character_data.base_stats
			fighter.runtime_profile = profile
			fighter.state = STATES[row]
			fighter.facing = -1 if row == 1 else 1
			fighter.velocity.y = -400 if row == 2 else (200 if row == 3 else 0)
			var presentation = Presentation.new()
			fighter.add_child(presentation)
			presentation.set_process(false)
			presentation.sync_visual(0.1)
			var label = Label.new()
			label.text = ["idle →", "run ←", "jump ascent →", "jump descent →"][row]
			label.position = Vector2(30+column*240,155+row*165)
			root.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	var error = image.save_png("res://_workspace/character-motion-visual-unification/installed-presentation.png")
	print("INSTALLED_PRESENTATION_CAPTURE: ", error)
	print("DESKTOP_PRESENTATION_METRICS: ", JSON.stringify({"texture_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "visible_sample_fighters": fighters.size(), "note": "desktop synthetic sample, not Android match"}))
	for fighter in fighters:
		fighter.scale = Vector2.ONE * 0.5
	await process_frame
	await RenderingServer.frame_post_draw
	image = root.get_texture().get_image()
	var zoom_error = image.save_png("res://_workspace/character-motion-visual-unification/installed-presentation-zoom-05.png")
	print("INSTALLED_PRESENTATION_ZOOM_05: ", zoom_error)
	if zoom_error != OK:
		error = zoom_error
	quit(error)
