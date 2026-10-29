extends SceneTree
## Replay observed presentation transforms with the actual effect renderer.
## This isolated audit scene does not simulate a match or change production assets.
const Presentation := preload("res://scripts/local_fighter_presentation.gd")
var output := ""
var timeline := ""

func _initialize() -> void: call_deferred("run")

func install(sample: Dictionary, visual: Node2D, motion: String, flipped: bool) -> void:
	var fighter: FighterController = visual.fighter
	fighter.state = int(sample.state)
	fighter.attack_phase_tick = int(sample.phase_tick)
	fighter.facing = -1 if flipped else 1
	fighter.attack_strike_ready = bool(sample.attack_strike_ready)
	fighter.active_attack = null
	if sample.has("effect_attack"):
		var attack := AttackData.new()
		for key: String in sample.effect_attack:
			var value: Variant = sample.effect_attack[key]
			if key in ["hitbox_offset", "hitbox_size"]: value = Vector2(value[0],value[1])
			elif key in ["attack_id", "visual_state_id", "action_id"]: value = StringName(value)
			attack.set(key, value)
		fighter.active_attack = attack
	var sprite: AnimatedSprite2D = visual.sprite
	sprite.sprite_frames = visual._motions[StringName(motion)]
	sprite.animation = StringName(motion)
	sprite.frame = int(sample.frame)
	sprite.scale = Vector2(sample.sprite_scale[0],sample.sprite_scale[1])
	sprite.position = Vector2(sample.sprite_position[0] * (-1 if flipped else 1),sample.sprite_position[1])
	sprite.offset = Vector2(sample.sprite_offset[0],sample.sprite_offset[1])
	sprite.flip_h = flipped
	var entry: Dictionary = visual._motion_layouts[StringName(motion)]
	var drawing := Presentation.display_layout(entry)
	visual.effects.frame_anchors = drawing.get("frame_anchors",[])
	visual.effects.phase_frame_ranges = drawing.get("phase_frame_ranges",[])
	visual.effects.artwork_sha256 = entry.get("sha256","")
	visual.effects.queue_redraw()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()-1):
		if args[i] == "--output": output=args[i+1]
		if args[i] == "--timeline": timeline=args[i+1]
	if output.is_empty() or timeline.is_empty() or DisplayServer.get_name() == "headless":
		push_error("Real renderer, --timeline and --output required"); quit(1); return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(timeline))
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1280,512)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color=Color("8f9da8");background.size=Vector2(1280,512);viewport.add_child(background)
	var output_rows: Array[Dictionary] = []
	for row: Dictionary in data.motions:
		var visuals: Array[Node2D] = []
		for index: int in 4:
			var fighter := FighterController.new()
			fighter.character_data=load("res://assets/character/%s/character.tres" % row.character_id)
			fighter.fighter_id=StringName(row.character_id)
			var profile:=RuntimeCombatProfile.new()
			profile.character_id=StringName(row.character_id);profile.stats=fighter.character_data.base_stats;profile.move_set=fighter.character_data.base_move_set
			fighter.runtime_profile=profile
			fighter.show_debug_body=false
			viewport.add_child(fighter);fighter.set_physics_process(false)
			fighter.position=Vector2(320+640*(index%2),350) if index<2 else Vector2(100+640*(index%2),490)
			fighter.scale=Vector2.ONE*(2.0 if index<2 else 1.0)
			var visual:=Presentation.new();fighter.add_child(visual);visual.set_process(false);visual.effects.set_process(false)
			visuals.append(visual)
		var directory := output.path_join(row.character_id+"--"+row.motion)
		DirAccess.make_dir_recursive_absolute(directory)
		var idle_row: Dictionary = {}
		for candidate: Dictionary in data.motions:
			if candidate.character_id==row.character_id and candidate.motion=="idle":idle_row=candidate;break
		var jobs: Array[Dictionary] = []
		for i: int in 15: jobs.append({"sample":idle_row.variants[0].samples[i*2],"motion":"idle","segment":"idle-before"})
		for variant: Dictionary in row.variants:
			for i in range(0,variant.samples.size(),2): jobs.append({"sample":variant.samples[i],"motion":row.motion,"segment":variant.attack_id})
		for i: int in 15: jobs.append({"sample":idle_row.variants[0].samples[i*2],"motion":"idle","segment":"idle-after"})
		for index in jobs.size():
			var job: Dictionary=jobs[index]
			for i: int in 4: install(job.sample,visuals[i],job.motion,i%2==1)
			await process_frame
			await RenderingServer.frame_post_draw
			var code:=viewport.get_texture().get_image().save_png(directory.path_join("%05d.png" % index))
			if code != OK: push_error("capture failed");quit(1);return
		output_rows.append({"character_id":row.character_id,"motion_id":row.motion,"frames":jobs.size(),"fps":30,"jobs":jobs})
		for visual: Node2D in visuals: visual.fighter.free()
		print("CAPTURED ",row.character_id,"/",row.motion," ",jobs.size())
	var file:=FileAccess.open(output.path_join("capture-index.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(),"timeline_sha256":FileAccess.get_sha256(timeline),"motions":output_rows},"\t"))
	quit(0)
