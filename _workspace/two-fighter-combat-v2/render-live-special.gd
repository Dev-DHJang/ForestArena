extends SceneTree
## Actual fixed-tick match + existing product rendering, isolated review profile.
var output := "res://_workspace/two-fighter-combat-v2/review/live-special"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	var rows: Array[Dictionary] = []
	for scenario: String in ["success","whiff","blocked"]:
		var app: Node=load("res://scenes/local_ai_app.tscn").instantiate()
		app.save_path="user://qa/live-special-%d/profile.json"%Time.get_ticks_usec()
		DirAccess.make_dir_recursive_absolute(app.save_path.get_base_dir())
		app.db_session_path=app.save_path+".session"
		app.demo_guest_session_path=app.save_path+".demo-session"
		root.add_child(app)
		await process_frame
		assert(app.store.grant_first("nabi"))
		app.start_match()
		await process_frame
		var controller: MatchController=app.match_controller
		controller.set_physics_process(false)
		controller.bot_source=null
		controller.bot_sources.clear()
		controller.player.spawn_position=Vector2(600,572)
		controller.training_dummy.spawn_position=Vector2(800 if scenario=="success" else (1100 if scenario=="whiff" else 760),572)
		controller.reset_match()
		controller.player.facing=1
		controller.training_dummy.facing=-1
		if scenario=="blocked":
			var wall:=StaticBody2D.new()
			wall.position=Vector2(815,520)
			wall.collision_layer=1
			wall.collision_mask=0
			var shape:=CollisionShape2D.new()
			var rect:=RectangleShape2D.new()
			rect.size=Vector2(30,132)
			shape.shape=rect
			wall.add_child(shape)
			var visual:=Polygon2D.new()
			visual.polygon=PackedVector2Array([Vector2(-15,-66),Vector2(15,-66),Vector2(15,66),Vector2(-15,66)])
			visual.color=Color("75888c")
			wall.add_child(visual)
			app.match_scene.add_child(wall)
		for warmup: int in 3:
			await physics_frame
			controller.step_fixed_tick(false)
		var layer:=CanvasLayer.new()
		var caption:=Label.new()
		caption.position=Vector2(22,160)
		caption.add_theme_font_size_override("font_size",20)
		layer.add_child(caption)
		app.add_child(layer)
		var folder:=output.path_join(scenario)
		DirAccess.make_dir_recursive_absolute(folder)
		var states: Array[Dictionary]=[]
		controller.submit_intent(CombatIntent.new(controller.tick+1,controller.player.fighter_id,&"attack_special",CombatIntent.Direction.NEUTRAL,CombatIntent.Edge.PRESS,CombatIntent.Context.GROUND))
		for tick: int in 65:
			await physics_frame
			controller.step_fixed_tick(false)
			app.match_scene._render_snapshot(controller.snapshot())
			caption.text="실제 경기 검토 / 나비 특수 %s / %d tick / HP %.0f" % [scenario,tick,controller.training_dummy.current_hp]
			states.append({"tick":tick,"player":controller.player.snapshot(),"target":controller.training_dummy.snapshot()})
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder.path_join("frame-%03d.png"%tick))
		rows.append({"scenario":scenario,"states":states,"actual_fixed_tick":true})
		var save: String=app.save_path
		app.queue_free()
		await process_frame
		for suffix: String in ["",".bak",".tmp"]: DirAccess.remove_absolute(save+suffix)
	DirAccess.make_dir_recursive_absolute(output)
	var file:=FileAccess.open(output.path_join("state-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scenarios":rows},"\t")+"\n")
	print("LIVE_SPECIAL_RENDER: PASS")
	quit()
