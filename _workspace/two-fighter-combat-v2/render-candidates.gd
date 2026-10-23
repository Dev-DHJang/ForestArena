extends SceneTree
## Isolated visual review only: synthetic attack phases, real presentation/FX.
const Presentation := preload("res://scripts/local_fighter_presentation.gd")
const CandidateFrames := preload("res://tools/forest_arena/motion_review_candidate_frames.gd")
var errors: Array[String] = []
var textures: Array[Texture2D] = []
var output := "res://_workspace/two-fighter-combat-v2/review/rendered"

func _initialize() -> void: call_deferred("run")
func make_fighter(cid: String, parent: Node2D, pos: Vector2) -> FighterController:
	var fighter := FighterController.new()
	fighter.character_data = load("res://assets/character/%s/character.tres" % cid)
	fighter.fighter_id = StringName(cid+str(parent.get_child_count()))
	fighter.show_debug_body = false
	parent.add_child(fighter)
	fighter.set_physics_process(false)
	var selection := LoadoutSelection.new()
	selection.character_id = StringName(cid)
	var profile := LoadoutBuilder.build(selection, LocalPlayCatalog.new().combat).profile
	assert(fighter.configure_profile(profile))
	fighter.set_physics_process(false)
	fighter.position = pos
	fighter.state = FighterController.State.IDLE
	var presentation := Presentation.new()
	fighter.add_child(presentation)
	presentation.set_process(false)
	return fighter
func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var bg := ColorRect.new()
	bg.color = Color("29464a")
	bg.size = Vector2(1280,720)
	root.add_child(bg)
	var heading := Label.new()
	heading.position = Vector2(28,28)
	heading.add_theme_font_size_override("font_size",24)
	root.add_child(heading)
	var note := Label.new()
	note.text = "승인 전 시안 / 합성 상태의 실제 표현 코드·효과 / 왼쪽 시안, 오른쪽 승인 idle / 1.50배"
	note.position = Vector2(28,74)
	root.add_child(note)
	var line := Line2D.new()
	line.points = PackedVector2Array([Vector2(60,561),Vector2(1220,561)])
	line.width = 2
	line.default_color = Color("739888")
	root.add_child(line)
	var world := Node2D.new()
	world.scale = Vector2.ONE*1.50
	root.add_child(world)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://_workspace/two-fighter-combat-v2/candidate-catalog.json"))
	var records: Array[Dictionary] = []
	for entry: Dictionary in catalog.assets:
		if entry.get("type") != "animation-candidate" and not ((entry.character_id == "ja-hyun" and entry.visual_state_id == "special_neutral") or entry.visual_state_id == "attack_air_light"): continue
		var cid := String(entry.character_id)
		var motion := StringName(entry.visual_state_id)
		var fighter := make_fighter(cid,world,Vector2(320,360))
		var idle := make_fighter(cid,world,Vector2(650,360))
		var presentation := fighter.get_node("Presentation")
		var idle_presentation := idle.get_node("Presentation")
		var frames := CandidateFrames.load_frames(entry,errors,textures)
		presentation._motions[motion] = frames
		presentation._motion_layouts[motion] = entry
		var attack: AttackData
		for candidate: AttackData in fighter.runtime_profile.move_set.attacks():
			if candidate.visual_state_id == motion: attack=candidate;break
		if attack==null:
			errors.append("no current attack for "+String(motion));continue
		var dir := output.path_join(cid+"__"+String(motion))
		DirAccess.make_dir_recursive_absolute(dir)
		fighter.active_attack = attack
		var lengths := [attack.startup_ticks,attack.active_ticks,attack.recovery_ticks]
		var states := [FighterController.State.ATTACK_STARTUP,FighterController.State.ATTACK_ACTIVE,FighterController.State.ATTACK_RECOVERY]
		var count := 0
		for phase: int in 3:
			fighter.state = states[phase]
			for tick: int in lengths[phase]:
				fighter.attack_phase_tick=tick
				heading.text="%s / %s / %s %d/%d" % [cid,motion,["준비","공격 판정","회복"][phase],tick+1,lengths[phase]]
				var before := fighter.snapshot()
				presentation.sync_visual(1.0/60.0)
				idle_presentation.sync_visual(1.0/60.0)
				if before != fighter.snapshot(): errors.append("presentation changed combat")
				for effect: Node in presentation.get_children():
					if effect is Node2D and effect.name=="AttackReachEffects": effect.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(dir.path_join("frame-%03d.png"%count))
				count+=1
		records.append({"character_id":cid,"motion":String(motion),"frames":count,"phase_ticks":lengths,"synthetic_phases":true,"actual_presentation_and_fx":true,"camera_equivalent_zoom":1.50})
		fighter.free();idle.free()
	var file := FileAccess.open(output.path_join("render-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"errors":errors,"motions":records},"\t")+"\n")
	print("CANDIDATE_RENDER: "+("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
