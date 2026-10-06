extends SceneTree

const Presentation := preload("res://scripts/local_fighter_presentation.gd")
const ROSTER := [&"ja-hyun", &"myo-ryung", &"nabi", &"yu-ran"]
var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for id: StringName in ROSTER:
		var paths := Presentation.approved_motion_paths(id)
		if id == &"nabi":
			_check(paths.has(&"attack_light_combo_01") and paths.has(&"attack_light_combo_02"), "both approved Nabi combo steps registered")
		if id == &"yu-ran":
			_check(paths.has(&"attack_light_combo_01") and paths.has(&"attack_light_combo_02") and paths.has(&"attack_light_combo_03"), "all approved Yu-Ran combo steps registered")
			_check(paths.has(&"guard") and paths.has(&"evade"), "approved Yu-Ran guard and evade registered")
		if id == &"ja-hyun":
			_check(paths.has(&"guard") and paths.has(&"evade"), "approved Ja-Hyun guard and evade registered")
		for motion: StringName in [&"idle", &"run", &"jump"]:
			_check(paths.has(motion), "%s approved %s exists" % [id, motion])
			var resource := load(paths[motion]) as SpriteFrames
			_check(resource != null and resource.get_frame_count(motion) == 16, "%s frames load" % id)
		var fighter := FighterController.new()
		fighter.character_data = load("res://assets/character/%s/character.tres" % id)
		fighter.fighter_id = &"local-player-slot"
		root.add_child(fighter)
		fighter.set_physics_process(false)
		var profile := RuntimeCombatProfile.new()
		profile.character_id = id
		profile.stats = fighter.character_data.base_stats
		fighter.runtime_profile = profile
		var presentation := Presentation.new()
		fighter.add_child(presentation)
		presentation.sync_visual(0.01)
		_check(presentation.character_id == id, "appearance uses profile identity, not participant slot")
		_check(presentation.sprite.visible, "%s has visible approved sprite" % id)
		_check(presentation.screen_bounds().has_area(), "%s exposes its actual visible screen bounds" % id)
		fighter.facing = -1
		presentation.sync_visual(0.01)
		_check(presentation.sprite.flip_h, "facing mirrors visuals")
		var before := fighter.snapshot()
		presentation.sync_visual(1.0)
		_check(before == fighter.snapshot(), "frame updates preserve combat snapshot")
		fighter.state = FighterController.State.GUARD
		presentation.sync_visual(0.01)
		if paths.has(&"guard"):
			_check(presentation.missing_motion.is_empty() and presentation.sprite.animation == &"guard", "%s approved guard is shown" % id)
			var guard_before := fighter.snapshot()
			presentation.sync_visual(1.0)
			var guard_layout: Dictionary = presentation._motion_layouts[&"guard"]
			if guard_layout.has("state_hold_frame"):
				_check(presentation.sprite.frame == int(guard_layout.state_hold_frame), "%s guard freezes on authored hold pose" % id)
			else:
				_check(presentation.sprite.frame == 15, "%s guard reaches its final hold pose" % id)
			_check(guard_before == fighter.snapshot(), "%s guard playback cannot mutate combat" % id)
			fighter.state = FighterController.State.EVADE
			presentation.sync_visual(0.1)
			_check(presentation.sprite.animation == &"evade" and presentation.sprite.frame == 8, "%s evade advances through authored frames" % id)
			var evade_before := fighter.snapshot()
			presentation.sync_visual(0.1)
			_check(presentation.sprite.frame == 15, "%s evade reaches its last authored frame" % id)
			_check(evade_before == fighter.snapshot(), "%s evade playback cannot mutate combat" % id)
		else:
			_check(presentation.missing_motion == &"guard", "unapproved guard pose remains explicit")
		for attack: AttackData in fighter.character_data.base_move_set.attacks():
			fighter.active_attack = attack
			fighter.state = FighterController.State.ATTACK_ACTIVE
			presentation.sync_visual(0.01)
			_check(presentation.requested_motion == attack.visual_state_id, "exact move visual ID used")
			if paths.has(attack.visual_state_id):
				_check(presentation.sprite.animation == attack.visual_state_id, "approved combo uses exact step")
				var layout: Dictionary = presentation._motion_layouts[attack.visual_state_id]
				if String(layout.get("path", "")).contains("/local_ai_v01/"):
					_check(is_equal_approx(presentation.sprite.position.y + 60.0 * presentation.sprite.scale.y, fighter.ground_contact_offset_y()), "normalized approved foot pivot stays on fighter baseline")
					if layout.has("phase_frame_ranges"):
						for phase: int in [FighterController.State.ATTACK_STARTUP, FighterController.State.ATTACK_ACTIVE, FighterController.State.ATTACK_RECOVERY]:
							fighter.state = phase
							var span: Array = layout.phase_frame_ranges[[FighterController.State.ATTACK_STARTUP, FighterController.State.ATTACK_ACTIVE, FighterController.State.ATTACK_RECOVERY].find(phase)]
							for phase_tick: int in range(1, 22):
								fighter.attack_phase_tick = phase_tick
								var combat_before := fighter.snapshot()
								presentation.sync_visual(0.1)
								_check(presentation.sprite.frame >= int(span[0]) and presentation.sprite.frame < int(span[1]), "approved frame stays in authored phase range")
								_check(combat_before == fighter.snapshot(), "approved phase playback cannot mutate combat")
			else:
				_check(presentation.missing_motion == attack.visual_state_id, "missing motion explicitly exposed")
		fighter.free()
	if failures.is_empty():
		print("LOCAL_FIGHTER_PRESENTATION: PASS")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)


func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
