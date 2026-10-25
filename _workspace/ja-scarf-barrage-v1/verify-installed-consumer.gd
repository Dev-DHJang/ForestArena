extends SceneTree
const Presentation := preload("res://scripts/local_fighter_presentation.gd")
var errors: Array[String] = []
func check(ok: bool, text: String) -> void:
	if not ok: errors.append(text)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var catalog := LocalPlayCatalog.new().combat
	var selection := LoadoutSelection.new()
	selection.character_id=&"ja-hyun"
	var fighter:=FighterController.new()
	fighter.fighter_id=&"installed-consumer"
	fighter.character_data=catalog.character_by_id(selection.character_id)
	root.add_child(fighter)
	fighter.set_physics_process(false)
	check(fighter.configure_profile(LoadoutBuilder.build(selection,catalog).profile),"profile")
	if fighter.runtime_profile==null:
		fighter.free()
		quit(1)
		return
	var visual:=Presentation.new()
	fighter.add_child(visual)
	visual.set_process(false)
	for attack: AttackData in fighter.runtime_profile.move_set.attacks():
		if attack.action_id==&"attack_special":fighter.active_attack=attack
	fighter.state=FighterController.State.ATTACK_ACTIVE
	fighter.attack_phase_tick=30
	var before:=fighter.snapshot()
	visual.sync_visual(0)
	check(before==fighter.snapshot(),"display does not mutate combat")
	check(visual.missing_motion.is_empty() and visual.sprite.animation==&"special_scarf_sweep","installed special is available without candidate injection")
	check(visual.sprite.sprite_frames.get_frame_count(visual.sprite.animation)==32,"thirty-two installed poses")
	check(visual.sprite.sprite_frames.resource_path=="res://assets/character/ja-hyun/animation/runtime/special_scarf_sweep.tres","runtime SpriteFrames consumer")
	var texture:=visual.sprite.sprite_frames.get_frame_texture(visual.sprite.animation,visual.sprite.frame) as AtlasTexture
	check(texture!=null and texture.atlas.resource_path=="res://assets/character/ja-hyun/animation/runtime/special_scarf_sweep_32f_barrage-v01.png","runtime atlas path")
	check(visual.effects.frame_anchors.size()==32,"registered attachments reach effects")
	var expected := [[0,4],[4,27],[27,32]]
	check(visual.effects.phase_frame_ranges.size()==3,"three registered display phases")
	for phase: int in 3:
		for edge: int in 2:
			check(int(visual.effects.phase_frame_ranges[phase][edge])==expected[phase][edge],"registered phase endpoint reaches effects")
	var record:Dictionary={"errors":errors,"sprite_frames_path":visual.sprite.sprite_frames.resource_path,"atlas_path":texture.atlas.resource_path,"frame_count":32,"displayed_frame":visual.sprite.frame,"phase_frame_ranges":visual.effects.phase_frame_ranges,"snapshot_unchanged":before==fighter.snapshot(),"candidate_injection":false}
	var file:=FileAccess.open("res://_workspace/ja-scarf-barrage-v1/qa/installed-consumer-r03.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(record,"\t")+"\n")
	fighter.free()
	for error:String in errors:push_error(error)
	print("INSTALLED_BARRAGE_CONSUMER: "+("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
