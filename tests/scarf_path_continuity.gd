extends SceneTree
const Paths := preload("res://scripts/scarf_attack_paths.gd")
const Presentation := preload("res://scripts/local_fighter_presentation.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func run() -> void:
	var catalog := LocalPlayCatalog.new()
	var selection := LoadoutSelection.new()
	selection.character_id = &"ja-hyun"
	var fighter := FighterController.new()
	fighter.fighter_id = &"scarf-check-player"
	fighter.character_data = catalog.combat.character_by_id(&"ja-hyun")
	check(fighter.configure_profile(LoadoutBuilder.build(selection, catalog.combat).profile), "approved Ja profile loads")
	root.add_child(fighter)
	fighter.set_physics_process(false)
	var visual := Presentation.new()
	fighter.add_child(visual)
	visual.set_process(false)
	for attack: AttackData in fighter.runtime_profile.move_set.attacks():
		if attack.visual_state_id not in [&"special_neutral", &"attack_air_light", &"attack_air_heavy"]: continue
		var duration := Vector3(attack.startup_ticks, attack.active_ticks, attack.recovery_ticks)
		var reach := attack.hitbox_offset.x + attack.hitbox_size.x * 0.40
		for mirrored: bool in [false, true]:
			for boundary: int in [0, 1]:
				var a := Paths.sample(attack.visual_state_id, boundary, duration[boundary], duration, reach, mirrored)
				var b := Paths.sample(attack.visual_state_id, boundary + 1, 0.0, duration, reach, mirrored)
				for key: String in ["control", "tip"]:
					check(a[key].is_equal_approx(b[key]), "cloth curve has no phase-boundary jump")
				for key: String in ["opacity", "width", "wave_strength", "clock_ticks"]:
					check(is_equal_approx(a[key], b[key]), "cloth length/folds/fade continue across attack phases")
			var last_tip := Vector2.ZERO
			var first := true
			for phase: int in 3:
				for tick: int in int(duration[phase]):
					var p := Paths.sample(attack.visual_state_id, phase, tick, duration, reach, mirrored)
					check(p.tip.is_finite() and p.control.is_finite(), "cloth geometry remains finite")
					check(p.opacity >= 0.0 and p.opacity <= 1.0, "cloth opacity stays bounded")
					if not first: check(p.tip.distance_to(last_tip) < 100.0, "one combat tick cannot teleport the relative scarf tip")
					first = false
					last_tip = p.tip
					var other := Paths.sample(attack.visual_state_id, phase, tick, duration, reach, not mirrored)
					check(p.tip.is_equal_approx(other.tip * Vector2(-1, 1)), "scarf tip mirrors in the same local coordinates")
					check(p.control.is_equal_approx(other.control * Vector2(-1, 1)), "curve bend mirrors with the tip")
				check(Paths.sample(attack.visual_state_id, 2, 7.0, duration, reach, mirrored).opacity == 0.0, "recovery cloth fully fades by seven ticks")
		fighter.active_attack = attack
		fighter.facing = 1
		for state: int in [FighterController.State.ATTACK_STARTUP, FighterController.State.ATTACK_ACTIVE, FighterController.State.ATTACK_RECOVERY]:
			fighter.state = state
			fighter.attack_phase_tick = 1
			visual.sync_visual(0)
			var before := fighter.snapshot()
			var anchors: Dictionary = visual.effects.current_frame_anchors()
			var path: Dictionary = visual.effects.continuous_scarf_path(anchors)
			check(not path.is_empty(), "actual registered pose supplies the current scarf attachment")
			var key := "scarf_hand" if attack.visual_state_id == &"attack_air_heavy" else "scarf_root"
			check(path.start.is_equal_approx(visual.effects._anchor(Vector2(anchors[key][0], anchors[key][1]))), "cloth starts exactly on the displayed hand or collar")
			check(before == fighter.snapshot(), "cloth path cannot change any combat field")
		fighter.state = FighterController.State.HITSTUN
		check(visual.effects.continuous_scarf_path({"scarf_hand":[64,64],"scarf_root":[64,64]}).is_empty(), "interruption cannot retain an old attack scarf")
	check(Paths.sample(&"special_scarf_sweep", 1, 1, Vector3(12,60,24), 200).is_empty(), "approved barrage uses its existing afterimages")
	check(Paths.sample(&"attack_air_heavy", 1, NAN, Vector3(12,5,20), 160).is_empty(), "nonfinite display time is rejected")
	check(Paths.sample(&"attack_air_light", 1, 0, Vector3(0,4,18), 160).is_empty(), "invalid display duration is rejected")
	fighter.free()
	for failure: String in failures: push_error(failure)
	print("SCARF_PATH_CONTINUITY: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
