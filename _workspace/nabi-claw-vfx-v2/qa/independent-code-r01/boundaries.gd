extends SceneTree
const Presentation := preload("res://scripts/local_fighter_presentation.gd")
const Effects := preload("res://scripts/fighter_attack_effects.gd")
const Geometry := preload("res://scripts/claw_attack_paths.gd")
class Observed extends "res://scripts/fighter_attack_effects.gd":
	var legacy := 0
	var claws := 0
	var scarf := 0
	func _uppercut(_progress: float, _opacity: float) -> void: legacy += 1
	func _slash(_center: Vector2, _progress: float, _opacity: float) -> void: legacy += 1
	func _claw_afterimage(_trace: Dictionary) -> void: claws += 1
	func _scarf_afterimage(_trace: Dictionary) -> void: scarf += 1
var errors: Array[String] = []
var checks := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: errors.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var catalog := LocalPlayCatalog.new().combat
	for cid: StringName in [&"nabi", &"ja-hyun"]:
		var fighter := FighterController.new()
		fighter.character_data = catalog.character_by_id(cid)
		fighter.fighter_id = StringName("independent-" + String(cid))
		root.add_child(fighter)
		fighter.set_physics_process(false)
		var selection := LoadoutSelection.new()
		selection.character_id = cid
		check(fighter.configure_profile(LoadoutBuilder.build(selection,catalog).profile),"actual profile")
		var visual := Presentation.new()
		fighter.add_child(visual)
		visual.set_process(false)
		var motions: Array = [&"attack_heavy_up", &"attack_air_heavy", &"attack_air_light", &"special_side"] if cid==&"nabi" else [&"special_scarf_sweep"]
		for motion: StringName in motions:
			for attack: AttackData in fighter.runtime_profile.move_set.attacks():
				if attack.visual_state_id==motion: fighter.active_attack=attack
			check(fighter.active_attack!=null and fighter.active_attack.visual_state_id==motion,"actual move selected")
			fighter.state=FighterController.State.ATTACK_ACTIVE
			fighter.attack_phase_tick=20 if cid==&"ja-hyun" else 1
			fighter.attack_strike_ready=true
			visual.sync_visual(0)
			check(visual.missing_motion.is_empty() and visual.sprite.animation==motion,"real registered asset loaded")
			var observer := Observed.new()
			fighter.add_child(observer)
			observer.set_process(false)
			observer.fighter=fighter
			observer.sprite=visual.sprite
			observer.frame_anchors=visual.effects.frame_anchors.duplicate(true)
			observer.phase_frame_ranges=visual.effects.phase_frame_ranges.duplicate(true)
			observer.artwork_sha256=visual.effects.artwork_sha256
			var before := fighter.snapshot()
			observer._draw()
			if cid==&"nabi":
				check(not observer.has_authored_claws(),"installed Nabi still has no authored claw metadata")
				check(observer.legacy==1 and observer.claws==0,"real manifest loader retains legacy effects")
			else:
				check(observer.scarf>0 and observer.claws==0,"registered Ja barrage still uses its scarf branch")
			check(before==fighter.snapshot(),"actual consumer draw preserves combat state")
			observer.free()
		fighter.free()
	var anchors := {"claw_hand":[70,70],"claw_tip":[96,42]}
	var previous := {"claw_hand":[66,83]}
	for invalid: Variant in [null, [], [4], [4,5,6], ["4",5], [true,5], [-1,4], [129,4], [NAN,4], [INF,4]]:
		check(not Geometry.point(invalid),"malformed claw point rejected")
		check(Geometry.trails({"claw_hand":[70,70],"claw_tip":invalid},{},false,1.0).is_empty(),"invalid current tip cannot produce a trace")
	for invalid_scale: float in [0.0,-1.0,NAN,INF]:
		check(Geometry.trails(anchors,previous,false,invalid_scale).is_empty(),"nonpositive/nonfinite scale rejected")
	check(Geometry.trails({"claw_hand":[70,70],"claw_tip":[70,70]},previous).is_empty(),"collapsed hand/tip omitted")
	check(Geometry.trails({"claw_hand":[70,70]},previous).is_empty(),"hidden tip omitted")
	for scale: float in [0.55,1.0,2.2]:
		for mirrored: bool in [false,true]:
			var first := Geometry.trails(anchors,previous,mirrored,scale)
			check(first==Geometry.trails(anchors,previous,mirrored,scale),"same inputs preserve deterministic geometry")
			check(first.size()==3,"three stylized traces")
			var expected := Vector2(32,-22)*Vector2(-1 if mirrored else 1,1)*scale
			check(first[1].tip.is_equal_approx(expected),"center trace keeps declared actual tip at all tested scales and mirrors")
			for trace: Dictionary in first:
				for halo: int in 3:
					var arrays := Effects.claw_mesh(trace,halo).surface_get_arrays(0)
					for vertex: Vector2 in arrays[Mesh.ARRAY_VERTEX]: check(vertex.is_finite(),"strip vertices finite")
					for color: Color in arrays[Mesh.ARRAY_COLOR]: check(is_finite(color.a) and color.a>=0 and color.a<=1,"strip opacity bounded")
	var invalid_previous := Geometry.trails(anchors,{"claw_hand":[-2,80]},false,1.0)
	var absent_previous := Geometry.trails(anchors,{},false,1.0)
	check(invalid_previous==absent_previous,"invalid history does not invent a remote wrist")
	for error: String in errors: push_error(error)
	print("INDEPENDENT_CLAW_BOUNDARIES: %s (%d checks)" % ["PASS" if errors.is_empty() else "FAIL",checks])
	quit(0 if errors.is_empty() else 1)
