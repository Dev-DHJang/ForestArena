extends SceneTree
## Isolated review: real CombatIntents, fixed-tick match, terrain and presentation.
## Candidate pixels are injected only into this process, never the runtime manifest.
const Presentation := preload("res://scripts/local_fighter_presentation.gd")
const CandidateFrames := preload("res://tools/forest_arena/motion_review_candidate_frames.gd")
var catalog_path := "res://_workspace/ja-scarf-barrage-v1/candidate-catalog-r02.json"
var output := "res://_workspace/motion-naturalness-v1/review/live-pilot"
var character_filter := ""
var scenario_filter := ""
var capture_stride := 1
var flipped := false
var small := false
var state_only := false
var errors: Array[String] = []
var textures: Array[Texture2D] = []
var candidate_entries: Dictionary = {}
var candidate_frames: Dictionary = {}
var check_count := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	check_count += 1
	if not value: errors.append(label)

func arguments() -> void:
	var args := OS.get_cmdline_user_args()
	var index := 0
	while index < args.size():
		match args[index]:
			"--catalog", "--output", "--character", "--scenario", "--capture-stride":
				if index + 1 >= args.size():
					errors.append("missing value for " + args[index]); return
				match args[index]:
					"--catalog": catalog_path = args[index+1]
					"--output": output = args[index+1]
					"--character": character_filter = args[index+1]
					"--scenario": scenario_filter = args[index+1]
					"--capture-stride": capture_stride = int(args[index+1])
				index += 2
				continue
			"--flip": flipped = true
			"--small": small = true
			"--state-only": state_only = true
			_: errors.append("unknown argument: " + args[index])
		index += 1
	if character_filter not in ["", "ja-hyun", "nabi"]: errors.append("unknown character filter")
	if scenario_filter not in ["", "run-stop", "jump-land", "full-combo", "heavy-ground", "special", "air-heavy", "air-light"]: errors.append("unknown scenario filter")
	if capture_stride < 1 or capture_stride > 4: errors.append("capture stride must be 1–4")
	if not catalog_path.is_absolute_path(): catalog_path = "res://"+catalog_path
	if not output.is_absolute_path(): output = "res://"+output

func load_candidates() -> void:
	if not FileAccess.file_exists(catalog_path):
		errors.append("candidate catalog does not exist: " + catalog_path); return
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	if not catalog is Dictionary or not catalog.get("assets") is Array:
		errors.append("invalid candidate catalog"); return
	for raw_entry: Dictionary in catalog.assets:
		var entry := raw_entry.duplicate(true)
		var cid := String(entry.get("character_id", ""))
		if cid not in ["ja-hyun", "nabi"]: continue
		if not character_filter.is_empty() and cid != character_filter: continue
		var motion := String(entry.get("visual_state_id", ""))
		if motion.is_empty(): continue
		var image_path := "res://" + String(entry.path).trim_prefix("res://")
		if not entry.has("sha256"): entry.sha256 = FileAccess.get_sha256(image_path)
		check(FileAccess.get_sha256(image_path) == String(entry.get("sha256", "")), "candidate PNG hash: " + cid + "/" + motion)
		var frames := CandidateFrames.load_frames(entry, errors, textures)
		if frames == null: continue
		if not candidate_entries.has(cid):
			candidate_entries[cid] = {}
			candidate_frames[cid] = {}
		candidate_entries[cid][StringName(motion)] = entry
		candidate_frames[cid][StringName(motion)] = frames

func install_candidates(visual: Node, cid: String) -> void:
	visual.set_process(false)
	# Character discovery clears the cache on its first valid profile. Complete
	# that discovery before replacing it with process-local candidate resources.
	visual.sync_visual(0.0)
	for motion: StringName in candidate_frames.get(cid, {}):
		visual._motions[motion] = candidate_frames[cid][motion]
		visual._motion_layouts[motion] = candidate_entries[cid][motion]
	visual._last_motion = &""

func queue_input(controller: MatchController, action: StringName, direction: CombatIntent.Direction, edge: CombatIntent.Edge, rows: Array[Dictionary], frame: int) -> void:
	var context := CombatIntent.Context.GROUND if controller.player.is_on_floor() else CombatIntent.Context.AIR
	var intent := CombatIntent.new(controller.tick+1, controller.player.fighter_id, action, direction, edge, context)
	controller.submit_intent(intent)
	rows.append({"frame":frame,"tick":intent.tick,"fighter_id":String(intent.fighter_id),"action":String(action),"direction":CombatIntent.Direction.keys()[direction],"edge":CombatIntent.Edge.keys()[edge],"context":CombatIntent.Context.keys()[context]})

func run_clip(cid: String, scenario: String) -> Dictionary:
	var scene: Node2D = load("res://scenes/main.tscn").instantiate()
	# The actual root script is retained verbatim except for its platform notice
	# callback name. This background artwork fixture excludes OS focus pause;
	# lifecycle QA still runs the unmodified product script separately.
	var capture_script := GDScript.new()
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main_source.count("func _notification(what: int) -> void:")==1,"one explicit platform callback in the product root script")
	capture_script.source_code = main_source.replace("func _notification(what: int) -> void:","func _capture_platform_notice_ignored(what: int) -> void:")
	check(capture_script.reload()==OK,"compile capture root after product autoloads are ready")
	scene.set_script(capture_script)
	scene.app_shell_mode = true
	var controller := scene.get_node("MatchController") as MatchController
	controller.player = scene.get_node("World/Player") as FighterController
	controller.training_dummy = scene.get_node("World/TrainingDummy") as FighterController
	controller.set_physics_process(false)
	var catalog := LocalPlayCatalog.new().combat
	controller.rules = (load("res://assets/combat/two_fighter_combat_rules.tres") as CombatRules).duplicate(true)
	controller.loadout_catalog = catalog
	var stage := controller.stage_data.duplicate(true) as StageData
	var sign_x := -1.0 if flipped else 1.0
	var target_distance := 160.0 if scenario == "special" else (80.0 if scenario in ["full-combo", "heavy-ground", "air-heavy", "air-light"] else 400.0)
	stage.spawn_points[0] = Vector2(600,572)
	stage.spawn_points[1] = Vector2(600+target_distance*sign_x,572)
	controller.stage_data = stage
	for index: int in 2:
		var selection := LoadoutSelection.new()
		selection.character_id = StringName(cid) if index == 0 else (&"nabi" if cid == "ja-hyun" else &"ja-hyun")
		if index == 0: controller.player_selection = selection
		else: controller.training_dummy_selection = selection
		var fighter := controller.player if index == 0 else controller.training_dummy
		fighter.character_data = catalog.character_by_id(selection.character_id)
		fighter.fighter_id = &"pilot-player" if index == 0 else &"pilot-target"
		fighter.show_debug_body = false
		fighter.add_child(Presentation.new())
	scene.get_node("Interface/TouchCommandSource").simplified_controls = true
	scene.get_node("Interface/TouchCommandSource").forestlight_controls = true
	root.add_child(scene)
	controller.set_physics_process(false)
	scene.get_node("Interface/DebugReadout").hide()
	scene.get_node("Interface/Restart").hide()
	scene.get_node("ArenaVisual").set_process(false)
	var camera := scene.get_node("Camera2D") as Camera2D
	camera.set_process(false)
	camera.fixed_zoom = 0.75 if small else 1.50
	controller.player.facing = int(sign_x)
	controller.training_dummy.facing = -int(sign_x)
	for fighter: FighterController in [controller.player,controller.training_dummy]:
		fighter.set_physics_process(false)
		install_candidates(fighter.get_node("Presentation"),String(fighter.runtime_profile.character_id))
	var caption_layer := CanvasLayer.new()
	caption_layer.layer = 10
	var caption := Label.new()
	caption.position = Vector2(24,92)
	caption.add_theme_font_size_override("font_size",18)
	caption.add_theme_color_override("font_outline_color",Color("11242c"))
	caption.add_theme_constant_override("outline_size",5)
	caption_layer.add_child(caption)
	scene.add_child(caption_layer)
	for warmup: int in 4:
		await physics_frame
		controller.step_fixed_tick(false)
	check(controller.player.is_on_floor(),cid+" "+scenario+": actual ground contact before inputs")
	var name_key := cid+"__"+scenario
	var folder := output.path_join(name_key)
	if not state_only: DirAccess.make_dir_recursive_absolute(folder)
	var states: Array[Dictionary] = []
	var inputs: Array[Dictionary] = []
	var attacks_seen: Array[String] = []
	var queued_activations: Dictionary = {}
	var raw_file: FileAccess
	if not state_only: raw_file = FileAccess.open(folder.path_join("frames.rgba"),FileAccess.WRITE)
	var frame_count := 162 if scenario == "full-combo" else 120
	var direction := CombatIntent.Direction.LEFT if flipped else CombatIntent.Direction.RIGHT
	var had_airborne := false
	var had_run := false
	var returned_to_ground := false
	var source_before := controller.player.global_position
	for frame: int in frame_count:
		await physics_frame
		if scenario == "run-stop":
			if frame == 12: queue_input(controller,&"move",direction,CombatIntent.Edge.PRESS,inputs,frame)
			elif frame > 12 and frame < 72: queue_input(controller,&"move",direction,CombatIntent.Edge.HOLD,inputs,frame)
			elif frame == 72: queue_input(controller,&"move",direction,CombatIntent.Edge.RELEASE,inputs,frame)
		elif scenario == "jump-land" and frame == 12:
			queue_input(controller,&"jump",CombatIntent.Direction.NEUTRAL,CombatIntent.Edge.PRESS,inputs,frame)
		elif scenario == "full-combo":
			if frame == 12: queue_input(controller,&"attack_light",CombatIntent.Direction.NEUTRAL,CombatIntent.Edge.PRESS,inputs,frame)
			var fighter := controller.player
			if fighter.active_attack != null and not fighter.active_attack.is_finisher and fighter.state == FighterController.State.ATTACK_ACTIVE and fighter.attack_phase_tick >= fighter.active_attack.active_ticks-2 and not queued_activations.has(fighter.activation_serial):
				queue_input(controller,&"attack_light",CombatIntent.Direction.NEUTRAL,CombatIntent.Edge.PRESS,inputs,frame)
				queued_activations[fighter.activation_serial] = true
		elif scenario == "heavy-ground" and frame == 12:
			queue_input(controller,&"attack_heavy",CombatIntent.Direction.NEUTRAL,CombatIntent.Edge.PRESS,inputs,frame)
		elif scenario == "heavy-ground" and frame == 14:
			queue_input(controller,&"attack_heavy",CombatIntent.Direction.NEUTRAL,CombatIntent.Edge.RELEASE,inputs,frame)
		elif scenario == "special" and frame == 12:
			queue_input(controller,&"attack_special",CombatIntent.Direction.NEUTRAL,CombatIntent.Edge.PRESS,inputs,frame)
		elif scenario in ["air-heavy", "air-light"]:
			if frame == 12: queue_input(controller,&"jump",CombatIntent.Direction.NEUTRAL,CombatIntent.Edge.PRESS,inputs,frame)
			elif frame == 30: queue_input(controller,&"attack_heavy" if scenario == "air-heavy" else &"attack_light",CombatIntent.Direction.NEUTRAL,CombatIntent.Edge.PRESS,inputs,frame)
		controller.step_fixed_tick(false)
		check(not controller.paused,cid+" "+scenario+": match is advancing")
		var before := controller.snapshot()
		for fighter: FighterController in [controller.player,controller.training_dummy]:
			var visual := fighter.get_node("Presentation")
			visual.sync_visual(1.0/60.0)
			check(visual.missing_motion.is_empty(),cid+" "+scenario+": exact motion available for "+String(fighter.fighter_id))
			visual.effects.queue_redraw()
		camera.call("_process",1.0/60.0)
		scene.get_node("ArenaVisual").call("_process",1.0/60.0)
		scene.call("_render_snapshot",controller.snapshot())
		check(before==controller.snapshot(),cid+" "+scenario+": drawing preserves the complete match snapshot")
		var player := controller.player
		var presentation := player.get_node("Presentation")
		var attack_id := "" if player.active_attack == null else String(player.active_attack.attack_id)
		if not attack_id.is_empty() and not attacks_seen.has(attack_id): attacks_seen.append(attack_id)
		had_run = had_run or player.state == FighterController.State.RUN
		if not player.is_on_floor(): had_airborne = true
		elif had_airborne: returned_to_ground = true
		var drawn: Array[Dictionary] = []
		for fighter: FighterController in [controller.player,controller.training_dummy]:
			var visual := fighter.get_node("Presentation")
			drawn.append({"fighter_id":String(fighter.fighter_id),"requested_motion":String(visual.requested_motion),"shown_motion":String(visual.sprite.animation),"frame":visual.sprite.frame,"frame_count":visual.sprite.sprite_frames.get_frame_count(visual.sprite.animation),"missing_motion":String(visual.missing_motion),"scale":[visual.sprite.scale.x,visual.sprite.scale.y],"sprite_position":[visual.sprite.position.x,visual.sprite.position.y],"flip_h":visual.sprite.flip_h})
		states.append({"frame":frame,"time_seconds":float(frame)/60.0,"match":controller.network_snapshot(),"drawn":drawn,"snapshot_unchanged":before==controller.snapshot()})
		caption.text="승인 전 실제 입력 검토 · %s / %s · %s · %.2f초\n%s · 그림 %d/%d · 줌 %.2f%s" % [cid,scenario,FighterController.State.keys()[player.state],float(frame)/60.0,String(presentation.sprite.animation),presentation.sprite.frame+1,presentation.sprite.sprite_frames.get_frame_count(presentation.sprite.animation),camera.fixed_zoom," · 좌우 반전" if flipped else ""]
		if not state_only and frame % capture_stride == 0:
			await process_frame
			RenderingServer.force_draw(false)
			var captured := root.get_texture().get_image()
			captured.convert(Image.FORMAT_RGBA8)
			check(captured.get_size()==Vector2i(1280,720),"raw capture dimensions")
			raw_file.store_buffer(captured.get_data())
			check(raw_file.get_error()==OK,"write actual rendered RGBA frame")
	if raw_file != null: raw_file.close()
	if scenario == "run-stop":
		check(had_run and absf(controller.player.global_position.x-source_before.x)>200.0,cid+": actual ground running covers distance")
		check(controller.player.state==FighterController.State.IDLE and controller.player.velocity.x==0.0,cid+": release reaches stationary idle")
	elif scenario == "jump-land":
		check(had_airborne and returned_to_ground,cid+": actual jump leaves and returns to terrain")
		check(controller.player.state==FighterController.State.IDLE and controller.player.is_on_floor(),cid+": actual landing completes before clip end")
	elif scenario == "full-combo":
		check(attacks_seen.size()==(4 if cid=="ja-hyun" else 3),cid+": input buffer executes the complete authored combo")
		check(controller.player.active_attack==null and controller.player.state==FighterController.State.IDLE,cid+": complete combo returns to idle")
		check(controller.training_dummy.current_hp<controller.training_dummy.runtime_profile.stats.max_hp,cid+": real hit resolution damages the nearby target")
	else:
		check(attacks_seen.size()==1,cid+" "+scenario+": one real attack activates")
		check(controller.player.active_attack==null,cid+" "+scenario+": attack completes")
		if scenario in ["air-heavy", "air-light"]: check(had_airborne,cid+" "+scenario+": air context was reached")
	var result := {"name":name_key,"character_id":cid,"scenario":scenario,"frame_count":frame_count,"fps":60,"capture_stride":capture_stride,"actual_fixed_tick":true,"synthetic_phases":false,"camera_zoom":camera.fixed_zoom,"flipped":flipped,"small":small,"state_only":state_only,"raw_capture":not state_only,"capture_dimensions":[1280,720],"inputs":inputs,"attacks_seen":attacks_seen,"states":states}
	scene.queue_free()
	await process_frame
	return result

func source_hashes() -> Dictionary:
	var sources := {}
	for path: String in ["scenes/main.tscn","scripts/main.gd","scripts/fighter_controller.gd","scripts/match_controller.gd","scripts/combat_camera.gd","scripts/arena_visual.gd","scripts/stage_controller.gd","scripts/combo_controller.gd","scripts/local_fighter_presentation.gd","scripts/fighter_attack_effects.gd","assets/character/ja-hyun/character.tres","assets/character/nabi/character.tres","assets/combat/stages/forest_ledge_stage.tres","assets/combat/movesets/two_fighter_ja_hyun_moveset.tres","assets/combat/movesets/two_fighter_nabi_moveset.tres","assets/combat/two_fighter_combat_rules.tres","tools/forest_arena/motion_review_candidate_frames.gd","_workspace/ja-scarf-barrage-v1/render-live.gd"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
	for cid: String in candidate_entries:
		for entry: Dictionary in candidate_entries[cid].values():
			for path: String in [entry.path,entry.sprite_frames_path]:
				sources[path.trim_prefix("res://")] = FileAccess.get_sha256("res://"+path.trim_prefix("res://"))
	sources[Presentation.DISPLAY_LAYOUT_PATH.trim_prefix("res://")] = FileAccess.get_sha256(Presentation.DISPLAY_LAYOUT_PATH)
	sources[catalog_path.trim_prefix("res://")] = FileAccess.get_sha256(catalog_path)
	return sources

func run() -> void:
	arguments()
	if DisplayServer.get_name()=="headless" and not state_only: errors.append("image capture needs a rendering backend; headless checks must use --state-only")
	if FileAccess.file_exists(output.path_join("state-report.json")): errors.append("output already contains a report; choose a new versioned --output")
	if errors.is_empty(): load_candidates()
	if not errors.is_empty():
		for error: String in errors: push_error(error)
		quit(1); return
	var sources := source_hashes()
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var rows: Array[Dictionary] = []
	for cid: String in ["ja-hyun","nabi"]:
		if not character_filter.is_empty() and cid != character_filter: continue
		for scenario: String in ["run-stop","jump-land","full-combo","heavy-ground","special","air-heavy","air-light"]:
			if not scenario_filter.is_empty() and scenario != scenario_filter: continue
			var row: Dictionary = await run_clip(cid,scenario)
			check(row.has("states") and row.get("states", []).size()==int(row.get("frame_count",-1)),cid+" "+scenario+": complete clip captured")
			rows.append(row)
	check(sources == source_hashes(),"source code and candidate assets stayed unchanged throughout capture")
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("state-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scenarios":rows,"errors":errors,"checks":check_count,"sources":sources,"approval_status":"pending","android_device_test":false,"platform_lifecycle_ignored_for_capture":true},"\t")+"\n")
	for error: String in errors: push_error(error)
	print("PILOT_LIVE_RENDER: %s (%d checks, %d clips)" % ["PASS" if errors.is_empty() else "FAIL",check_count,rows.size()])
	var audio := root.get_node_or_null("AudioDirector")
	if audio != null: audio.shutdown()
	await process_frame
	quit(0 if errors.is_empty() else 1)
