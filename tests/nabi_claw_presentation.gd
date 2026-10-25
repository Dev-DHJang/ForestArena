extends SceneTree
const Draft := preload("res://scripts/fighter_attack_effects.gd")
class Observed extends "res://scripts/fighter_attack_effects.gd":
	var traces: Array[Dictionary] = []
	var legacy := 0
	func _claw_afterimage(trace: Dictionary) -> void: traces.append(trace)
	func _uppercut(_progress: float,_opacity: float) -> void: legacy+=1
	func _slash(_center: Vector2,_progress: float,_opacity: float) -> void: legacy+=1
var errors: Array[String] = []
var checks := 0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: errors.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var fighter := FighterController.new()
	fighter.fighter_id=&"draft-nabi"
	fighter.character_data=LocalPlayCatalog.new().combat.character_by_id(&"nabi")
	root.add_child(fighter)
	fighter.set_physics_process(false)
	var selection := LoadoutSelection.new()
	selection.character_id=&"nabi"
	fighter.configure_profile(LoadoutBuilder.build(selection,LocalPlayCatalog.new().combat).profile)
	var effect := Observed.new()
	fighter.add_child(effect)
	effect.set_process(false)
	effect.fighter=fighter
	var sprite := AnimatedSprite2D.new()
	effect.add_child(sprite)
	effect.sprite=sprite
	for motion: String in ["attack_heavy_up","attack_air_heavy","attack_air_light","special_side"]:
		var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/nabi_claw_anchors_v01.json"))
		var row: Dictionary
		for entry: Dictionary in fixture.motions:
			if entry.visual_state_id==motion:row=entry
		var frames := SpriteFrames.new()
		frames.remove_animation(&"default")
		frames.add_animation(&"idle")
		frames.add_frame(&"idle",GradientTexture2D.new())
		frames.add_animation(StringName(motion))
		for index: int in row.frame_count: frames.add_frame(StringName(motion),GradientTexture2D.new())
		sprite.sprite_frames=frames
		sprite.animation=StringName(motion)
		effect.frame_anchors=row.frame_anchors.duplicate(true)
		effect.phase_frame_ranges=row.phase_frame_ranges.duplicate(true)
		for attack: AttackData in fighter.runtime_profile.move_set.attacks():
			if String(attack.visual_state_id)==motion: fighter.active_attack=attack
		check(fighter.active_attack!=null and String(fighter.active_attack.visual_state_id)==motion,"authored move selected")
		for flipped: bool in [false,true]:
			sprite.flip_h=flipped
			fighter.facing=-1 if flipped else 1
			sprite.scale=Vector2.ONE*1.3
			sprite.position=Vector2(5,-40)
			for state: int in [FighterController.State.ATTACK_STARTUP,FighterController.State.ATTACK_ACTIVE,FighterController.State.ATTACK_RECOVERY,FighterController.State.HITSTUN]:
				fighter.state=state
				fighter.attack_phase_tick=0
				fighter.attack_strike_ready=true
				for frame: int in row.frame_count:
					sprite.frame=frame
					effect.traces.clear()
					effect.legacy=0
					var snapshot := fighter.snapshot()
					effect._draw()
					var visible: bool=state in [FighterController.State.ATTACK_ACTIVE,FighterController.State.ATTACK_RECOVERY] and row.frame_anchors[frame].has("claw_tip")
					check(effect.traces.size()==(3 if visible else 0),"only actual visible active/recovery claws emit")
					check(effect.legacy==0,"authored hidden poses never create legacy static crescents")
					check(snapshot==fighter.snapshot(),"drawing does not alter combat snapshot")
					if visible:
						var tip := Vector2(float(row.frame_anchors[frame].claw_tip[0]),float(row.frame_anchors[frame].claw_tip[1]))
						check(effect.traces[1].tip.is_equal_approx(effect._anchor(tip)),"central trace ends on actual displayed claw after scale/position/mirror")
						for halo: int in 3:
							var mesh := Draft.claw_mesh(effect.traces[1],halo)
							var arrays := mesh.surface_get_arrays(0)
							check(arrays[Mesh.ARRAY_VERTEX].size()==50 and arrays[Mesh.ARRAY_INDEX].size()==144,"explicit triangle strip avoids outline triangulation")
		fighter.state=FighterController.State.ATTACK_ACTIVE
		fighter.attack_phase_tick=1
		sprite.frame=7 if motion!="special_side" else 21
		if motion=="special_side":
			fighter.attack_strike_ready=false
			check(effect.claw_afterimages().is_empty(),"special travel/miss cannot show an impact trail")
			fighter.attack_strike_ready=true
		fighter.state=FighterController.State.ATTACK_RECOVERY
		fighter.attack_phase_tick=7
		check(effect.claw_afterimages().is_empty(),"recovery trails expire at tick seven")
		fighter.state=FighterController.State.ATTACK_ACTIVE
		fighter.attack_phase_tick=0
		var saved := effect.frame_anchors.duplicate(true)
		effect.frame_anchors[sprite.frame].claw_tip=[129,30]
		check(effect.claw_afterimages().is_empty(),"invalid point cannot create detached trail")
		effect.frame_anchors=saved
		sprite.animation=&"idle"
		check(effect.claw_afterimages().is_empty(),"fallback idle is not treated as an attack pose")
		sprite.animation=StringName(motion)
		effect.frame_anchors=[]
		effect.legacy=0
		effect._draw()
		check(effect.legacy==1,"legacy no-anchor artwork retains its original effect")
	fighter.active_attack=null
	check(effect.claw_afterimages().is_empty(),"completed attack cannot retain a stale trail")
	fighter.free()
	for error: String in errors: push_error(error)
	print("NABI_CLAW_PRESENTATION: %s (%d checks)"%["PASS" if errors.is_empty() else "FAIL",checks])
	quit(0 if errors.is_empty() else 1)
