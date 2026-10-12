extends SceneTree
## Named visual recheck MOTION-SIZE-02: draw current approved sheets through
## the actual presentation, beside the previous manifest layout. No art writes.
const Presentation := preload("res://scripts/local_fighter_presentation.gd")
const ROSTER := ["ja-hyun", "myo-ryung", "nabi", "yu-ran"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("MOTION-SIZE-02 requires a real renderer; dummy headless images are not evidence")
		quit(2)
		return
	var output := ProjectSettings.globalize_path("res://build/motion-size-review")
	var review_frame := 0
	if not OS.get_cmdline_user_args().is_empty():
		review_frame = clampi(int(OS.get_cmdline_user_args()[0]), 0, 15)
	DirAccess.make_dir_recursive_absolute(output)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Presentation.MANIFEST_PATH))
	var trace: Array = []
	for id: String in ROSTER:
		var rows: Array[Dictionary] = []
		for entry: Dictionary in manifest.assets:
			if entry.get("type") == "animation-runtime" and entry.get("character_id") == id:
				rows.append(entry)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1536, 168 * ceili(float(rows.size()) / 6.0))
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.transparent_bg = false
		root.add_child(viewport)
		var background := ColorRect.new()
		background.color = Color("2d3037")
		background.size = viewport.size
		viewport.add_child(background)
		for i: int in rows.size():
			var entry := rows[i]
			var motion := StringName(entry.visual_state_id)
			var origin := Vector2((i % 6) * 256, (i / 6) * 168)
			var before := AnimatedSprite2D.new()
			before.sprite_frames = load(entry.sprite_frames_path)
			before.animation = motion
			before.frame = review_frame
			before.scale = Vector2.ONE * float(entry.get("presentation_scale", 1.0))
			before.position = origin + Vector2(64, 124 - (float(entry.get("foot_pivot_y", 128)) - 64.0) * before.scale.y)
			viewport.add_child(before)
			var fighter := FighterController.new()
			fighter.character_data = load("res://assets/character/%s/character.tres" % id)
			fighter.show_debug_body = false
			fighter.position = origin + Vector2(192, 124 - fighter.ground_contact_offset_y())
			viewport.add_child(fighter)
			fighter.set_physics_process(false)
			var profile := RuntimeCombatProfile.new()
			profile.character_id = StringName(id)
			profile.stats = fighter.character_data.base_stats
			fighter.runtime_profile = profile
			var visual_attack := AttackData.new()
			visual_attack.visual_state_id = motion
			fighter.active_attack = visual_attack
			fighter.state = FighterController.State.ATTACK_STARTUP
			var presentation := Presentation.new()
			fighter.add_child(presentation)
			presentation.sync_visual(0.0)
			presentation.set_process(false)
			presentation.sprite.frame = review_frame
			var label := Label.new()
			label.position = origin + Vector2(2, 127)
			label.add_theme_font_size_override("font_size", 11)
			label.text = "%s\nprevious %.3f  corrected %.3f" % [motion, before.scale.x, presentation.sprite.scale.x]
			viewport.add_child(label)
			trace.append({"character_id": id, "motion_id": String(motion), "asset_sha256": entry.sha256, "previous_scale": before.scale.x, "corrected_scale": presentation.sprite.scale.x, "rendered_frame": presentation.sprite.frame, "foot_world_y": fighter.position.y + presentation.sprite.position.y + 60.0 * presentation.sprite.scale.y})
		await process_frame
		await RenderingServer.frame_post_draw
		var result := viewport.get_texture().get_image().save_png(output.path_join(id + "-godot-f%02d.png" % review_frame))
		if result != OK:
			push_error("MOTION-SIZE-02 cannot save real renderer output")
			quit(1)
			return
		viewport.free()
	var file := FileAccess.open(output.path_join("render-trace-f%02d.json" % review_frame), FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 1, "case_id": "MOTION-SIZE-02", "display_server": DisplayServer.get_name(), "headless": false, "has_rendering_device": RenderingServer.get_rendering_device() != null, "motions": trace}, "\t"))
	print("MOTION-SIZE-02: rendered 120 current approved motions beside previous layout")
	quit(0)
