extends SceneTree
## Isolated review: real CombatIntents, fixed-tick match, terrain and presentation.
## Candidate pixels are injected only into this process, never the runtime manifest.
const Presentation := preload("res://scripts/local_fighter_presentation.gd")
const CandidateFrames := preload("res://tools/forest_arena/motion_review_candidate_frames.gd")
var catalog_path := "res://_workspace/motion-naturalness-v1/remaining-candidate-catalog.json"
var expected_catalog_sha256 := "b1345601da6a8c32f7d55342fc77f93cde68334d3c38208edd86a55493204efb"
var output := "res://_workspace/motion-naturalness-v1/qa/remaining-state-transitions-r01/headless"
var character_filter := ""
var scenario_filter := ""
var capture_stride := 1
var flipped := false
var small := false
var state_only := false
var raw_capture := false
var require_complete_display := false
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
			"--catalog", "--catalog-sha256", "--output", "--character", "--scenario", "--capture-stride":
				if index + 1 >= args.size():
					errors.append("missing value for " + args[index]); return
				match args[index]:
					"--catalog": catalog_path = args[index+1]
					"--catalog-sha256": expected_catalog_sha256 = args[index+1]
					"--output": output = args[index+1]
					"--character": character_filter = args[index+1]
					"--scenario": scenario_filter = args[index+1]
					"--capture-stride": capture_stride = int(args[index+1])
				index += 2
				continue
			"--flip": flipped = true
			"--small": small = true
			"--state-only": state_only = true
			"--raw-capture": raw_capture = true
			"--require-complete-display": require_complete_display = true
			_: errors.append("unknown argument: " + args[index])
		index += 1
	if character_filter not in ["", "ja-hyun", "nabi"]: errors.append("unknown character filter")
	if scenario_filter not in ["", "guard-release", "short-hitstun", "launch-land-wakeup", "ringout-respawn-death"]: errors.append("unknown scenario filter")
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
		if motion.is_empty() or (cid == "ja-hyun" and motion == "special_side"): continue
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
	var target_distance := 400.0
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
	var raw_file: FileAccess
	if raw_capture and not state_only:
		raw_file = FileAccess.open(folder.path_join("frames.rgba"),FileAccess.WRITE)
		check(raw_file != null,"open raw RGBA stream")
	var states: Array[Dictionary] = []
	var inputs: Array[Dictionary] = []
	var attacks_seen: Array[String] = []
	var queued_activations: Dictionary = {}
	var frame_count := 430 if scenario == "ringout-respawn-death" else (145 if scenario == "launch-land-wakeup" else 70)
	var state_counts: Dictionary = {}
	var motions_seen: Array[String] = []
	var triggers: Array[Dictionary] = []
	var respawn_events: Array[Dictionary] = []
	controller.player.presentation_event.connect(func(event_id: StringName, payload: Dictionary):
		if event_id == &"respawn": respawn_events.append({"tick":controller.tick,"event":String(event_id),"payload":payload}))
	var reaction_attack := controller.training_dummy.attacks[0].duplicate(true) as AttackData
	reaction_attack.damage = 1.0
	var launcher: AttackData
	for authored: AttackData in catalog.character_by_id(&"nabi").base_move_set.attacks():
		if authored.landing_knockdown and authored.hit_reaction == AttackData.HitReaction.LAUNCH: launcher = authored
	check(launcher != null,"authored Nabi air uppercut supplies launch/landing knockdown")
	var direction := CombatIntent.Direction.LEFT if flipped else CombatIntent.Direction.RIGHT
	var had_airborne := false
	var had_run := false
	var returned_to_ground := false
	var source_before := controller.player.global_position
	for frame: int in frame_count:
		await physics_frame
		if scenario == "guard-release":
			if frame == 12: queue_input(controller,&"guard",CombatIntent.Direction.DOWN,CombatIntent.Edge.PRESS,inputs,frame)
			elif frame > 12 and frame < 36: queue_input(controller,&"move",CombatIntent.Direction.DOWN,CombatIntent.Edge.HOLD,inputs,frame)
			elif frame == 36: queue_input(controller,&"move",CombatIntent.Direction.DOWN,CombatIntent.Edge.RELEASE,inputs,frame)
		elif scenario == "short-hitstun" and frame == 12:
			controller.player.apply_hit(reaction_attack,Vector2(30.0*sign_x,0),16,controller.rules)
			triggers.append({"frame":frame,"public_call":"apply_hit","stun_ticks":16,"reaction":"NORMAL_HIT"})
		elif scenario == "launch-land-wakeup" and frame == 12:
			controller.player.apply_hit(launcher,launcher.launch_vector.normalized()*launcher.knockback,launcher.fixed_hitstun_ticks,controller.rules)
			triggers.append({"frame":frame,"public_call":"apply_hit","attack_id":String(launcher.attack_id),"stun_ticks":launcher.fixed_hitstun_ticks})
		elif scenario == "ringout-respawn-death":
			if frame in [12,170]:
				controller.player.ring_out(controller.rules)
				triggers.append({"frame":frame,"public_call":"ring_out","stocks_after":controller.player.stocks})
			elif frame == 330:
				var lethal := reaction_attack.duplicate(true) as AttackData
				lethal.damage = controller.player.current_hp
				controller.player.apply_hit(lethal,Vector2.ZERO,16,controller.rules)
				triggers.append({"frame":frame,"public_call":"apply_hit","damage":lethal.damage,"purpose":"grounded HP loss and final match resolution"})
				lethal = null
		var tick_before := controller.tick
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
		var state_name: String = FighterController.State.keys()[player.state]
		state_counts[state_name] = int(state_counts.get(state_name,0)) + 1
		if not motions_seen.has(String(presentation.requested_motion)): motions_seen.append(String(presentation.requested_motion))
		states.append({"frame":frame,"time_seconds":float(frame)/60.0,"match":controller.network_snapshot(),"drawn":drawn,"snapshot_unchanged":before==controller.snapshot(),"match_tick_advanced":controller.tick>tick_before,"terminal_presentation_only":controller.tick==tick_before and (not controller.winner_id.is_empty() or controller.is_draw)})
		caption.text="승인 전 실제 입력 검토 · %s / %s · %s · %.2f초\n%s · 그림 %d/%d · 줌 %.2f%s" % [cid,scenario,FighterController.State.keys()[player.state],float(frame)/60.0,String(presentation.sprite.animation),presentation.sprite.frame+1,presentation.sprite.sprite_frames.get_frame_count(presentation.sprite.animation),camera.fixed_zoom," · 좌우 반전" if flipped else ""]
		if not state_only and frame % capture_stride == 0:
			await process_frame
			await RenderingServer.frame_post_draw
			var captured := root.get_texture().get_image()
			if raw_capture:
				captured.convert(Image.FORMAT_RGBA8)
				check(captured.get_size()==Vector2i(1280,720),"raw capture dimensions")
				raw_file.store_buffer(captured.get_data())
				check(raw_file.get_error()==OK,"write actual rendered RGBA frame")
			else:
				check(captured.save_png(folder.path_join("frame-%03d.png"%frame))==OK,"save actual rendered frame")
	if raw_file != null:
		raw_file.close()
		raw_file = null
	if scenario == "guard-release":
		check(int(state_counts.get("GUARD",0)) == 24,cid+": guard lasts exactly press/hold interval")
		check(controller.player.state==FighterController.State.IDLE,cid+": guard release returns to idle")
	elif scenario == "short-hitstun":
		check(int(state_counts.get("HITSTUN",0)) == 15,cid+": 16-tick hit includes entry before first step and 15 post-step displays")
		check(controller.player.state==FighterController.State.IDLE,cid+": hitstun naturally finishes")
	elif scenario == "launch-land-wakeup":
		check(state_counts.has("LAUNCH") and state_counts.has("KNOCK_DOWN") and state_counts.has("WAKE_UP"),cid+": launch and physical landing lead through down/wakeup")
		check(controller.player.state==FighterController.State.IDLE,cid+": wakeup finishes naturally")
	else:
		check(respawn_events.size()==2,cid+": two real respawn events")
		check(controller.player.stocks==0 and not controller.winner_id.is_empty(),cid+": final grounded HP loss finishes match")
		check(state_counts.has("RING_OUT") and state_counts.has("MATCH_ENDED"),cid+": ringout and terminal match shown")
		if require_complete_display:
			check(motions_seen.has("spawn") and motions_seen.has("death"),cid+": live respawn and final elimination request spawn/death")
			for motion: String in ["spawn","death"]:
				var covered := {}
				for sample: Dictionary in states:
					var shown: Dictionary = sample.drawn[0]
					if shown.shown_motion == motion: covered[int(shown.frame)] = true
				check(covered.size()==candidate_frames[cid][StringName(motion)].get_frame_count(StringName(motion)),cid+": full live frame coverage for "+motion)
			check(states[165].drawn[0].shown_motion=="idle" and states[325].drawn[0].shown_motion=="idle",cid+": each respawn naturally completes into idle before next loss")
	var result := {"name":name_key,"character_id":cid,"scenario":scenario,"frame_count":frame_count,"fps":60,"capture_stride":capture_stride,"raw_capture":raw_capture,"capture_dimensions":[1280,720],"actual_fixed_tick":true,"synthetic_phases":false,"camera_zoom":camera.fixed_zoom,"flipped":flipped,"small":small,"state_only":state_only,"inputs":inputs,"attacks_seen":attacks_seen,"triggers":triggers,"state_counts":state_counts,"motions_seen":motions_seen,"respawn_events":respawn_events,"states":states}
	scene.queue_free()
	await process_frame
	return result

func source_hashes() -> Dictionary:
	var sources := {}
	for path: String in ["scenes/main.tscn","scripts/main.gd","scripts/fighter_controller.gd","scripts/match_controller.gd","scripts/combat_camera.gd","scripts/arena_visual.gd","scripts/stage_controller.gd","scripts/combo_controller.gd","scripts/local_fighter_presentation.gd","scripts/fighter_attack_effects.gd","assets/character/ja-hyun/character.tres","assets/character/nabi/character.tres","assets/combat/stages/forest_ledge_stage.tres","assets/combat/movesets/two_fighter_ja_hyun_moveset.tres","assets/combat/movesets/two_fighter_nabi_moveset.tres","assets/combat/two_fighter_combat_rules.tres","tools/forest_arena/motion_review_candidate_frames.gd","_workspace/motion-naturalness-v1/render-state-transitions.gd"]:
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
	check(FileAccess.get_sha256(catalog_path)==expected_catalog_sha256,"explicitly pinned candidate catalog hash")
	var sources := source_hashes()
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var rows: Array[Dictionary] = []
	for cid: String in ["ja-hyun","nabi"]:
		if not character_filter.is_empty() and cid != character_filter: continue
		for scenario: String in ["guard-release","short-hitstun","launch-land-wakeup","ringout-respawn-death"]:
			if not scenario_filter.is_empty() and scenario != scenario_filter: continue
			var row: Dictionary = await run_clip(cid,scenario)
			check(row.has("states") and row.get("states", []).size()==int(row.get("frame_count",-1)),cid+" "+scenario+": complete clip captured")
			rows.append(row)
			if not state_only:
				var partial := FileAccess.open(output.path_join(row.name).path_join("clip-state-report.json"),FileAccess.WRITE)
				partial.store_string(JSON.stringify({"scenario":row,"errors_so_far":errors,"sources_at_start":sources},"\t")+"\n")
				partial.close()
				partial = null
	check(sources == source_hashes(),"source code and candidate assets stayed unchanged throughout capture")
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("state-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scenarios":rows,"errors":errors,"checks":check_count,"sources":sources,"approval_status":"pending","android_device_test":false,"platform_lifecycle_ignored_for_capture":true},"\t")+"\n")
	var audio := root.get_node_or_null("ForestArenaAudio")
	if audio != null: audio.shutdown()
	await process_frame
	for error: String in errors: push_error(error)
	print("STATE_TRANSITIONS_LIVE_RENDER: %s (%d checks, %d clips)" % ["PASS" if errors.is_empty() else "FAIL",check_count,rows.size()])
	quit(0 if errors.is_empty() else 1)
