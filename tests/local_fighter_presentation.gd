extends SceneTree

const Presentation := preload("res://scripts/local_fighter_presentation.gd")
const ROSTER := [&"ja-hyun", &"myo-ryung", &"nabi", &"yu-ran"]
var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(Presentation.airborne_jump_frame(-60.01, 0.0) == 3, "ascent just outside apex boundary")
	_check(Presentation.airborne_jump_frame(-60.0, 0.0) == 6, "negative apex boundary inclusive")
	_check(Presentation.airborne_jump_frame(60.0, 0.0) == 6, "positive apex boundary inclusive")
	_check(Presentation.airborne_jump_frame(60.01, 0.0) == 10, "descent just outside apex boundary")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Presentation.MANIFEST_PATH))
	var drawing_document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Presentation.DISPLAY_LAYOUT_PATH))
	_check(drawing_document.schema_version == 1 and drawing_document.motions.size() == 120, "MOTION-SIZE-01 covers the 120 approved sheets")
	var calibrated_entries := {}
	for entry: Dictionary in manifest.assets:
		if entry.get("type") == "animation-runtime":
			calibrated_entries["%s/%s" % [entry.character_id, entry.visual_state_id]] = entry
	for row: Dictionary in drawing_document.motions:
		var key := "%s/%s" % [row.character_id, row.motion_id]
		_check(calibrated_entries.has(key), "MOTION-SIZE-01 calibration targets a registered motion")
		var entry: Dictionary = calibrated_entries.get(key, {})
		var drawing := Presentation.display_layout(entry)
		var original_hash_matches: bool = row.asset_sha256 == entry.get("sha256", "")
		_check(drawing.calibrated == original_hash_matches, "MOTION-SIZE-01 applies only to the sheet it measured")
		if not original_hash_matches:
			_check(entry.has("motion_registration") and is_equal_approx(drawing.scale, float(entry.get("presentation_scale", 1.0))), "newly approved artwork uses its own layout")
		var stale := entry.duplicate(true)
		stale.sha256 = "different-approved-art-version"
		var fallback := Presentation.display_layout(stale)
		_check(not fallback.calibrated and is_equal_approx(fallback.scale, float(stale.get("presentation_scale", 1.0))), "MOTION-SIZE-01 never applies this artwork calibration to other sheets")
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
			var declared: Dictionary = calibrated_entries.get("%s/%s" % [id, motion], {})
			_check(resource != null and resource.get_frame_count(motion) == int(declared.get("frame_count", 16)), "%s frames load" % id)
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
		_check(is_equal_approx(presentation.sprite.position.y + 60.0 * presentation.sprite.scale.y, fighter.ground_contact_offset_y()), "%s basic motion uses approved 124px contact point" % id)
		_check(presentation.screen_bounds().has_area(), "%s exposes its actual visible screen bounds" % id)
		for row: Dictionary in drawing_document.motions:
			if row.character_id != String(id):
				continue
			var visual_attack := AttackData.new()
			visual_attack.visual_state_id = StringName(row.motion_id)
			fighter.active_attack = visual_attack
			fighter.state = FighterController.State.ATTACK_STARTUP
			var untouched := fighter.snapshot()
			for phase_tick: int in [0, 3, 7, 12]:
				fighter.attack_phase_tick = phase_tick
				presentation.sync_visual(0.1)
				_check(presentation.sprite.animation == StringName(row.motion_id), "MOTION-SIZE-01 shows the exact approved motion")
				var entry: Dictionary = calibrated_entries["%s/%s" % [id, row.motion_id]]
				var expected_scale := float(row.scale) if row.asset_sha256 == entry.get("sha256", "") else float(entry.get("presentation_scale", 1.0))
				_check(is_equal_approx(presentation.sprite.scale.x, expected_scale), "artwork body scale does not pulse between frames")
				_check_ground_anchor(presentation, fighter, "artwork attachment remains on fighter baseline")
				untouched.attack_phase_tick = phase_tick
				_check(untouched == fighter.snapshot(), "MOTION-SIZE-01 drawing keeps combat data read-only")
		fighter.active_attack = null
		fighter.state = FighterController.State.IDLE
		presentation.sync_visual(0.0)
		fighter.facing = -1
		presentation.sync_visual(0.01)
		_check(presentation.sprite.flip_h, "facing mirrors visuals")
		var before := fighter.snapshot()
		presentation.sync_visual(1.0)
		_check(before == fighter.snapshot(), "frame updates preserve combat snapshot")
		fighter.state = FighterController.State.JUMP
		fighter.velocity.y = -400.0
		presentation.sync_visual(0.01)
		var modern_jump: bool = presentation.sprite.sprite_frames.get_frame_count(&"jump") == 24
		var ascent_start := 0 if modern_jump else 3
		_check(presentation.sprite.frame == ascent_start, "%s takeoff begins airborne ascent" % id)
		_check_ground_anchor(presentation, fighter, "%s jump keeps its declared attachment" % id)
		presentation.sync_visual(1.0)
		_check(presentation.sprite.frame == 5, "%s ascent holds before apex" % id)
		fighter.velocity.y = 0.0
		presentation.sync_visual(0.01)
		_check(presentation.sprite.frame == 6, "%s apex begins its own frame range" % id)
		fighter.state = FighterController.State.FALL
		fighter.velocity.y = 200.0
		presentation.sync_visual(1.0)
		_check(presentation.sprite.frame == (15 if modern_jump else (10 if id == &"ja-hyun" else (11 if id == &"nabi" else 12))), "%s falling never shows grounded landing" % id)
		fighter.state = FighterController.State.JUMP
		fighter.velocity.y = -400.0
		presentation.sync_visual(0.01)
		_check(presentation.sprite.frame == ascent_start, "%s air jump restarts ascent" % id)
		fighter.air_jumps_remaining = 1
		fighter.velocity.y = -fighter.character_data.base_stats.jump_velocity + 20.0
		presentation.sync_visual(0.2)
		_check(presentation.sprite.frame == (2 if modern_jump else 5), "%s early ascent has advanced before air jump" % id)
		fighter._try_jump(CombatRules.new())
		var early_jump_snapshot := fighter.snapshot()
		presentation.sync_visual(0.01)
		_check(fighter.air_jumps_remaining == 0 and presentation.sprite.frame == ascent_start, "%s early real air jump restarts ascent despite small velocity change" % id)
		_check(early_jump_snapshot == fighter.snapshot(), "%s early air jump display is read-only" % id)
		presentation.sync_visual(0.2)
		fighter.launcher_jump_available = true
		presentation.sync_visual(0.0)
		fighter._try_jump(CombatRules.new())
		presentation.sync_visual(0.01)
		_check(not fighter.launcher_jump_available and presentation.sprite.frame == ascent_start, "%s launcher jump allowance restarts ascent" % id)
		fighter.state = FighterController.State.IDLE
		fighter.velocity.y = 0.0
		presentation.sync_visual(0.01)
		_check(presentation.sprite.frame == (16 if modern_jump else (12 if id in [&"ja-hyun",&"nabi"] else 13)), "%s landing begins only on ground state" % id)
		presentation.sync_visual(0.25)
		presentation.sync_visual(0.01)
		_check(presentation.sprite.animation == &"idle", "%s landing returns to idle after its duration" % id)
		fighter.state = FighterController.State.FALL
		fighter.velocity.y = 100.0
		presentation.sync_visual(0.01)
		fighter.state = FighterController.State.IDLE
		presentation.sync_visual(0.01)
		fighter.state = FighterController.State.RUN
		presentation.sync_visual(0.01)
		_check(presentation.sprite.animation == &"run", "%s movement interrupts landing immediately" % id)
		fighter.state = FighterController.State.FALL
		fighter.velocity.y = 100.0
		presentation.sync_visual(0.01)
		_check(presentation.sprite.frame == 10, "%s platform drop starts with descent" % id)
		var airborne_before := fighter.snapshot()
		presentation.sync_visual(0.2)
		_check(airborne_before == fighter.snapshot(), "%s jump presentation preserves physics" % id)
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
					_check_ground_anchor(presentation, fighter, "approved foot or body root stays on fighter baseline")
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
		if id == &"nabi":
			var old_special: SpriteFrames = presentation._motions[&"special_side"]
			var authored_travel := SpriteFrames.new()
			authored_travel.add_animation(&"special_side")
			for index: int in 32:
				authored_travel.add_frame(&"special_side", old_special.get_frame_texture(&"special_side", 0))
			var travel_attack := AttackData.new()
			travel_attack.visual_state_id = &"special_side"
			travel_attack.attack_movement = 1
			travel_attack.startup_ticks = 10
			travel_attack.active_ticks = 24
			travel_attack.recovery_ticks = 20
			fighter.active_attack = travel_attack
			fighter.state = FighterController.State.ATTACK_ACTIVE
			fighter.attack_travel_active = true
			fighter.attack_phase_tick = 10
			presentation._motions[&"special_side"] = authored_travel
			presentation._motion_layouts[&"special_side"] = {"phase_frame_ranges": [[0,4],[4,24],[24,32]]}
			var travel_before := fighter.snapshot()
			presentation.sync_visual(1.0/60.0)
			_check(presentation.sprite.animation == &"special_side" and presentation.sprite.frame >= 4 and presentation.sprite.frame < 24, "authored 32-frame special displays travel poses")
			_check(travel_before == fighter.snapshot(), "special travel display keeps combat data read-only")
			presentation._motions[&"special_side"] = old_special
			presentation.sync_visual(1.0/60.0)
			_check(presentation.sprite.animation == &"run", "approved 16-frame special still shows the run cycle during travel")
		fighter.free()
	if failures.is_empty():
		print("LOCAL_FIGHTER_PRESENTATION: PASS")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)


func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)


func _check_ground_anchor(presentation: Node, fighter: FighterController, message: String) -> void:
	var layout: Dictionary = presentation._motion_layouts.get(presentation.sprite.animation, {})
	var drawing: Dictionary = Presentation.display_layout(layout)
	var pivot := float(drawing.get("foot_pivot_y", 128.0))
	var anchors: Array = drawing.get("frame_anchors", [])
	if anchors.size() == presentation.sprite.sprite_frames.get_frame_count(presentation.sprite.animation):
		var frame: Variant = anchors[presentation.sprite.frame]
		if frame is Dictionary and frame.has("body_root"):
			pivot = float(frame.body_root[1])
	_check(is_equal_approx(presentation.sprite.position.y + (pivot - 64.0) * presentation.sprite.scale.y, fighter.ground_contact_offset_y()), message)
