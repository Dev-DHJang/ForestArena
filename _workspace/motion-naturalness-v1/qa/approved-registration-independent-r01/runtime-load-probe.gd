extends SceneTree
const CandidateFrames := preload("res://_workspace/motion-naturalness-v1/import-parity-candidate-frames.gd")
const Presentation := preload("res://scripts/local_fighter_presentation.gd")
const OUT := "res://_workspace/motion-naturalness-v1/qa/approved-registration-independent-r01/runtime-load-proof.json"
var errors: Array[String] = []
var checks := 0
var kept_textures: Array[Texture2D] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: errors.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if FileAccess.file_exists(OUT):
		push_error("independent output already exists"); quit(1); return
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://_workspace/motion-naturalness-v1/qa/approved-registration-r10/ready-plan.json")).plan
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://_workspace/motion-naturalness-v1/remaining-candidate-catalog-r10.json"))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/character/manifest.json"))
	var candidates := {}
	var installed := {}
	for entry: Dictionary in catalog.assets:
		candidates[String(entry.character_id)+"/"+String(entry.visual_state_id)] = entry
	for entry: Dictionary in manifest.assets:
		if entry.get("type")=="animation-runtime": installed[String(entry.character_id)+"/"+String(entry.visual_state_id)] = entry
	var fighters: Array[FighterController] = []
	var visuals := {}
	for cid: String in ["ja-hyun","nabi"]:
		var fighter := FighterController.new()
		fighter.fighter_id = StringName("registered-"+cid)
		fighter.character_data = LocalPlayCatalog.new().combat.character_by_id(StringName(cid))
		root.add_child(fighter)
		var selection := LoadoutSelection.new(); selection.character_id=StringName(cid)
		check(fighter.configure_profile(LoadoutBuilder.build(selection,LocalPlayCatalog.new().combat).profile),cid+" configure profile")
		fighter.set_physics_process(false)
		var visual := Presentation.new(); fighter.add_child(visual); visual.set_process(false)
		visual.sync_visual(0)
		visuals[cid]=visual; fighters.append(fighter)
	var results: Array[Dictionary] = []
	var frame_total := 0
	for target: Dictionary in plan.motions:
		var key := String(target.character_id)+"/"+String(target.motion)
		var entry: Dictionary = candidates[key]
		var row: Dictionary = installed[key]
		var motion := StringName(target.motion)
		var visual: Node = visuals[String(target.character_id)]
		var paths := Presentation.approved_motion_paths(StringName(target.character_id))
		check(paths.get(motion)==target.sprite_frames_path,key+" public manifest discovery")
		check(visual._motion_layouts[motion]==row,key+" public presentation consumes actual runtime metadata without candidate overrides")
		var current: SpriteFrames = visual._motions[motion]
		check(current!=null and current.resource_path==target.sprite_frames_path,key+" public loaded registered SpriteFrames")
		var candidate: SpriteFrames = CandidateFrames.load_frames(entry,errors,kept_textures)
		check(candidate!=null,key+" review import-parity frames load")
		if current==null or candidate==null: continue
		var count := int(entry.frame_count)
		check(current.get_frame_count(motion)==count,key+" frame count")
		check(is_equal_approx(current.get_animation_speed(motion),candidate.get_animation_speed(motion)) and current.get_animation_loop(motion)==candidate.get_animation_loop(motion),key+" fps/loop")
		for index: int in count:
			var actual := current.get_frame_texture(motion,index) as AtlasTexture
			var expected := candidate.get_frame_texture(motion,index) as AtlasTexture
			check(actual!=null and expected!=null,key+" atlas type")
			if actual==null or expected==null: continue
			check(actual.atlas.resource_path=="res://"+String(target.png_path),key+" real imported atlas uses registered PNG")
			check(actual.region==expected.region and actual.margin==expected.margin,key+" atlas region/margin %d"%index)
			check(is_equal_approx(current.get_frame_duration(motion,index),candidate.get_frame_duration(motion,index)),key+" frame duration %d"%index)
			var actual_image := actual.get_image()
			var expected_image := expected.get_image()
			check(actual_image.get_size()==Vector2i(128,128) and actual_image.get_format()==expected_image.get_format() and actual_image.get_data()==expected_image.get_data(),key+" imported frame RGBA equals reviewed import-parity frame %d"%index)
			frame_total += 1
		results.append({"character_id":target.character_id,"motion":target.motion,"frame_count":count,"public_runtime_path":current.resource_path,"actual_imported_frame_pixels_compared":count})
	for fighter: FighterController in fighters: fighter.free()
	var result := {"status":"pass" if errors.is_empty() else "fix","checks":checks,"errors":errors,"motions":results,"actual_imported_frames":frame_total,"scope":"headless real ResourceLoader and public presentation discovery, no candidate table override; runtime textures compared to prior Godot import-parity review loader; no GPU/HUD/socket/device claim","manifest_sha256":FileAccess.get_sha256("res://assets/character/manifest.json")}
	FileAccess.open(OUT,FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	for message: String in errors: push_error(message)
	print("REGISTERED_RUNTIME_INDEPENDENT: %s (%d checks, %d frames)"%[result.status,checks,frame_total])
	root.get_node("ForestArenaAudio").shutdown()
	quit(0 if errors.is_empty() else 1)
