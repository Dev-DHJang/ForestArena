extends SceneTree
## Presentation-only guarantees at real attack phase boundaries and interruption.
const Presentation := preload("res://scripts/local_fighter_presentation.gd")
class ObservedEffects extends "res://scripts/fighter_attack_effects.gd":
	var paths: Array[Dictionary] = []
	func _scarf_afterimage(trace: Dictionary) -> void:
		paths.append(trace)
	func _cloth(start: Vector2, _control: Vector2, tip: Vector2, _opacity: float, _width_scale: float, _wave_strength := 0.0, _flat_end := false) -> void:
		paths.append({"start":start,"tip":tip})
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if not value: failures.append(label)
func run() -> void:
	var material_path: String = root.get_node("ForestArenaResources").resource_path(Presentation.AttackEffects.SCARF_TEXTURE_ID)
	check(FileAccess.get_sha256(material_path)=="a4dcff0f9fdeb592ee86a209603c5dc97ca059f2a461b7f61576b1acf3ce3311","scarf UVs stay bound to the actual approved worn scarf artwork")
	for cid: StringName in [&"ja-hyun",&"nabi"]:
		var fighter := FighterController.new()
		fighter.fighter_id = StringName("vfx-"+String(cid))
		fighter.character_data = load("res://assets/character/%s/character.tres" % cid)
		root.add_child(fighter)
		fighter.set_physics_process(false)
		var selection := LoadoutSelection.new()
		selection.character_id = cid
		check(fighter.configure_profile(LoadoutBuilder.build(selection,LocalPlayCatalog.new().combat).profile),"profile")
		var visual := Presentation.new()
		fighter.add_child(visual)
		visual.set_process(false)
		var effect := visual.get_node("AttackReachEffects")
		check(effect.sprite == visual.sprite,"cloth attachment uses the actual displayed sprite/pivot")
		if cid == &"ja-hyun":
			var held_anchors := {"scarf_root":[64,80],"scarf_hand":[72,72],"scarf_tips":[[110,60],null]}
			visual.sprite.flip_h = false
			var path: Dictionary = effect.held_scarf_path(held_anchors)
			check(path.start.is_equal_approx(effect._anchor(Vector2(72,72))),"barrage cloth begins at the real gripping hand")
			check(path.tip.x > path.start.x and path.tip.y < path.start.y,"held cloth continues the painted outward-up direction")
			visual.sprite.flip_h = true
			var mirrored: Dictionary = effect.held_scarf_path(held_anchors)
			check(is_equal_approx(mirrored.start.x,-path.start.x) and is_equal_approx(mirrored.tip.x,-path.tip.x),"grip and full cloth path mirror together")
			check(is_equal_approx(mirrored.tip.y,path.tip.y),"mirroring preserves upward sweep height")
			var faded: Dictionary = effect.held_scarf_path(held_anchors,0.35)
			check(faded.start==mirrored.start and faded.tip.distance_to(effect._anchor(Vector2(64,80))) < mirrored.tip.distance_to(effect._anchor(Vector2(64,80))),"recovery retracts cloth while preserving its grip")
			var hanging_anchors := {"scarf_root":[64,80],"scarf_hand":[72,72],"scarf_tips":[[72,110],null]}
			var recovery: Dictionary = effect.held_scarf_path(hanging_anchors,1.0,held_anchors)
			check(recovery.tip.y < recovery.start.y,"recovery keeps the last active heading instead of creating a new downward strike")
			var retracted: Dictionary = effect.held_scarf_path(hanging_anchors,0.0,held_anchors)
			check(retracted.start==effect._anchor(Vector2(72,72)) and retracted.tip==effect._anchor(Vector2(72,110)),"recovery returns exactly to the short painted tail")
			held_anchors.scarf_tips[0] = null
			check(effect.held_scarf_path(held_anchors).is_empty(),"hidden held tail never invents an attachment")
			held_anchors.scarf_tips[0] = [72,72]
			check(effect.held_scarf_path(held_anchors).is_empty(),"collapsed painted tail cannot create an arbitrary direction")
			held_anchors.scarf_tips[0] = [129,60]
			check(effect.held_scarf_path(held_anchors).is_empty(),"out-of-cell anchors cannot create a detached sweep")
			var center := Presentation.AttackEffects.cloth_center
			check(center.call(Vector2.ZERO,Vector2(80,0),Vector2(200,0),0.0,Vector2.DOWN,0.7,14.0).is_equal_approx(Vector2.ZERO),"fabric folds keep the grip fixed")
			check(center.call(Vector2.ZERO,Vector2(80,0),Vector2(200,0),1.0,Vector2.DOWN,0.7,14.0).is_equal_approx(Vector2(200,0)),"fabric folds keep the authored tip fixed")
			var folded: Vector2 = center.call(Vector2.ZERO,Vector2(80,0),Vector2(200,0),0.25,Vector2.DOWN,0.7,14.0)
			check(absf(folded.y)>5.0,"worn scarf has a visible travelling bend rather than a straight blade")
			var mirrored_fold: Vector2 = center.call(Vector2.ZERO,Vector2(-80,0),Vector2(-200,0),0.25,Vector2.DOWN,0.7,14.0)
			check(mirrored_fold.is_equal_approx(Vector2(-folded.x,folded.y)),"fabric folds mirror with the worn scarf")
			var observed := ObservedEffects.new()
			observed.fighter = fighter
			for attack: AttackData in fighter.runtime_profile.move_set.attacks():
				if attack.action_id == &"attack_special": fighter.active_attack = attack
			fighter.state = FighterController.State.ATTACK_RECOVERY
			fighter.attack_phase_tick = 0
			var probe_sprite := AnimatedSprite2D.new()
			var probe_frames := SpriteFrames.new()
			probe_frames.remove_animation(&"default")
			probe_frames.add_animation(fighter.active_attack.visual_state_id)
			for index: int in 32: probe_frames.add_frame(fighter.active_attack.visual_state_id,GradientTexture2D.new())
			probe_sprite.sprite_frames = probe_frames
			probe_sprite.animation = fighter.active_attack.visual_state_id
			probe_sprite.frame = 27
			observed.sprite = probe_sprite
			observed.phase_frame_ranges = [[0,4],[4,27],[27,32]]
			for index: int in 32: observed.frame_anchors.append(hanging_anchors.duplicate(true))
			for index: int in [24,25,26]: observed.frame_anchors[index] = {}
			fighter.add_child(observed)
			observed.add_child(probe_sprite)
			observed.set_process(false)
			var recovery_snapshot := fighter.snapshot()
			observed._draw()
			check(observed.paths.is_empty(),"occluded last active pose omits recovery extension instead of inventing a downward strike")
			observed.frame_anchors[26] = {"scarf_root":[64,80],"scarf_hand":[72,72],"scarf_tips":[[110,60],null]}
			observed._draw()
			check(observed.paths.size()==1 and observed.paths[0].tip.y < observed.paths[0].start.y,"valid last active pose preserves the actual recovery sweep")
			check(recovery_snapshot==fighter.snapshot(),"missing-anchor recovery drawing remains read-only")
			check(observed.paths[0].opacity <= 0.32,"special uses translucent traces instead of opaque cloth")
			observed.paths.clear()
			fighter.attack_phase_tick = 5
			observed._draw()
			check(observed.paths.is_empty(),"special afterimages disappear within five recovery ticks")
			fighter.state = FighterController.State.ATTACK_ACTIVE
			fighter.attack_phase_tick = 20
			probe_sprite.frame = 26
			for index: int in [24,25]: observed.frame_anchors[index] = observed.frame_anchors[26].duplicate(true)
			var traces: Array[Dictionary] = observed.scarf_afterimages()
			check(traces.size()==3 and traces[0].opacity>traces[1].opacity and traces[1].opacity>traces[2].opacity,"three authored afterimages fade by age")
			check(traces==observed.scarf_afterimages(),"same pose and fixed tick produce the same afterimages")
			fighter.state = FighterController.State.ATTACK_STARTUP
			check(observed.scarf_afterimages().is_empty(),"preparation has no premature speed trails")
			observed.free()
		for attack: AttackData in fighter.runtime_profile.move_set.attacks():
			fighter.active_attack=attack
			for facing: int in [-1,1]:
				fighter.facing=facing
				for state: int in [FighterController.State.ATTACK_STARTUP,FighterController.State.ATTACK_ACTIVE,FighterController.State.ATTACK_RECOVERY]:
					fighter.state=state
					for tick: int in [0,1,3,6,7,20]:
						fighter.attack_phase_tick=tick
						var before := fighter.snapshot()
						visual.sync_visual(0)
						var envelope: Vector2 = effect.effect_envelope()
						check(envelope.y>=0 and envelope.y<=1,"effect opacity stays bounded")
						if state == FighterController.State.ATTACK_RECOVERY and tick>=7: check(envelope.y==0,"recovery trail expires within seven ticks")
						check(before==fighter.snapshot(),"drawing never changes simulation or resources")
			fighter.state=FighterController.State.HITSTUN
			check(effect.effect_envelope()==Vector2.ZERO,"hit interruption clears the attack effect immediately")
			fighter.active_attack=null
			check(effect.effect_envelope()==Vector2.ZERO,"ended attack cannot leave a stale trail")
		fighter.free()
	for failure: String in failures: push_error(failure)
	print("TWO_FIGHTER_VFX: "+("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
