extends SceneTree
## Execute the project's real presentation; export only review data, never assets.
const Presentation := preload("res://scripts/local_fighter_presentation.gd")
var errors: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _sample(presentation: Node2D, fighter: FighterController, delta: float, phase: String) -> Dictionary:
	var before := fighter.snapshot()
	presentation.sync_visual(delta)
	if before != fighter.snapshot():
		errors.append("presentation changed combat snapshot")
	return {"frame": presentation.sprite.frame, "shown": String(presentation.sprite.animation), "phase": phase, "duration_ms": 1000.0 / 60.0}


func _reset(presentation: Node2D, fighter: FighterController) -> void:
	fighter.active_attack = null
	fighter.state = FighterController.State.IDLE
	presentation._last_motion = &""
	presentation._elapsed = 0.0
	presentation._was_airborne = false
	presentation._landing_elapsed = -1.0
	presentation._jump_stage = -1


func _run() -> void:
	var output := ""
	var args := OS.get_cmdline_user_args()
	for index in range(args.size() - 1):
		if args[index] == "--output": output = args[index + 1]
	if output.is_empty():
		push_error("--output absolute JSON path is required")
		quit(1)
		return
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/character/manifest.json"))
	var motions: Array[Dictionary] = []
	for id: String in ["ja-hyun", "myo-ryung", "nabi", "yu-ran"]:
		var fighter := FighterController.new()
		fighter.character_data = load("res://assets/character/%s/character.tres" % id)
		fighter.fighter_id = StringName(id)
		root.add_child(fighter)
		fighter.set_physics_process(false)
		var profile := RuntimeCombatProfile.new()
		profile.character_id = StringName(id)
		profile.stats = fighter.character_data.base_stats
		profile.move_set = fighter.character_data.base_move_set
		fighter.runtime_profile = profile
		var presentation := Presentation.new()
		fighter.add_child(presentation)
		presentation.set_process(false)
		for entry: Dictionary in document.assets:
			if entry.get("type") != "animation-runtime" or entry.get("character_id") != id: continue
			var motion := String(entry.get("visual_state_id", String(entry.sprite_frames_path).get_file().get_basename()))
			var variants: Array[Dictionary] = []
			var review_attacks: Array[AttackData] = fighter.character_data.base_move_set.attacks()
			if motion == "attack_heavy_charge":
				for base_attack: AttackData in fighter.character_data.base_move_set.attacks():
					if base_attack.action_id != &"attack_heavy" or base_attack.activation_context != AttackData.ActivationContext.GROUND or base_attack.charge_max_ticks <= 0: continue
					for held_ticks: int in [base_attack.charge_min_ticks, base_attack.charge_max_ticks]:
						fighter.charge_attack = base_attack
						fighter.runtime_state.charge_ticks = held_ticks
						fighter._release_charge(CombatRules.new())
						var charged := fighter.active_attack.duplicate(true) as AttackData
						charged.attack_id = StringName("%s#charged-%d" % [base_attack.attack_id, held_ticks])
						review_attacks.append(charged)
			for attack: AttackData in review_attacks:
				if String(attack.visual_state_id) != motion: continue
				_reset(presentation, fighter)
				fighter.active_attack = attack
				var samples: Array[Dictionary] = []
				var phases := [FighterController.State.ATTACK_STARTUP, FighterController.State.ATTACK_ACTIVE, FighterController.State.ATTACK_RECOVERY]
				var lengths := [attack.startup_ticks, attack.active_ticks, attack.recovery_ticks]
				for phase_index in range(3):
					fighter.state = phases[phase_index]
					for tick in range(lengths[phase_index]):
						fighter.attack_phase_tick = tick
						samples.append(_sample(presentation, fighter, 1.0 / 60.0, ["startup", "active", "recovery"][phase_index]))
				variants.append({"attack_id": String(attack.attack_id), "phase_ticks": lengths, "self_impulse": [attack.self_impulse.x, attack.self_impulse.y], "samples": samples})
			if variants.is_empty() or motion == "attack_heavy_charge":
				_reset(presentation, fighter)
				var samples: Array[Dictionary] = []
				if motion == "jump":
					for stage in range(4):
						fighter.state = FighterController.State.IDLE if stage == 3 else (FighterController.State.FALL if stage == 2 else FighterController.State.JUMP)
						fighter.velocity.y = [-400.0, 0.0, 200.0, 0.0][stage]
						for tick in range([20, 12, 20, 16][stage]):
							samples.append(_sample(presentation, fighter, 1.0 / 60.0, ["ascent", "apex", "descent", "landing"][stage]))
				else:
					var found := motion == "idle"
					for state: int in Presentation.STATE_MOTIONS:
						if String(Presentation.STATE_MOTIONS[state]) == motion:
							fighter.state = state
							found = true
							break
					if not found: errors.append("no runtime state or attack for %s/%s" % [id, motion])
					var state_ticks := ceili(16.0 / float(entry.fps) * 60.0) * 2 if entry.get("loop", false) else 120
					for tick in range(state_ticks): samples.append(_sample(presentation, fighter, 1.0 / 60.0, motion))
				variants.push_front({"attack_id": "state:" + motion, "stimulus": "synthetic fixed state: 120 ticks or two complete loops; jump uses staged vertical speeds", "samples": samples})
			var required_ids: Array[String] = []
			for variant: Dictionary in variants: required_ids.append(variant.attack_id)
			motions.append({"required_variant_ids": required_ids, "character_id": id, "motion": motion, "sheet_sha256": FileAccess.get_sha256("res://" + String(entry.path)), "variants": variants})
		fighter.free()
	var fingerprints := {}
	for source: String in ["assets/character/manifest.json", "scripts/local_fighter_presentation.gd", "scripts/fighter_controller.gd", "docs/contracts/attack-system-v01.json", "docs/gameplay/combat.md"]:
		fingerprints[source] = FileAccess.get_sha256("res://" + source)
	var presentation_constants := (load("res://scripts/local_fighter_presentation.gd") as GDScript).get_script_constant_map()
	var layout_path := String(presentation_constants.get("DISPLAY_LAYOUT_PATH", ""))
	if not layout_path.is_empty():
		fingerprints[layout_path.trim_prefix("res://")] = FileAccess.get_sha256(layout_path)
	for entry: Dictionary in document.assets:
		if entry.get("type") == "animation-runtime":
			var path := String(entry.sprite_frames_path).trim_prefix("res://")
			fingerprints[path] = FileAccess.get_sha256("res://" + path)
	# AttackData can be an external or embedded resource; pin all source resources.
	for id: String in ["ja-hyun", "myo-ryung", "nabi", "yu-ran"]:
		var character: CharacterData = load("res://assets/character/%s/character.tres" % id)
		for resource: Resource in [character, character.base_move_set] + character.base_move_set.attacks():
			var path := resource.resource_path.split("::")[0].trim_prefix("res://")
			if not path.is_empty(): fingerprints[path] = FileAccess.get_sha256("res://" + path)
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("cannot write " + output)
		quit(1)
		return
	file.store_string(JSON.stringify({"schema_version": 1, "generator_sha256": FileAccess.get_sha256(get_script().resource_path), "sources": fingerprints, "motions": motions, "errors": errors}, "\t") + "\n")
	for error in errors: push_error(error)
	print("MOTION_REVIEW_TIMELINE: %s (%d motions)" % ["PASS" if errors.is_empty() else "FAIL", motions.size()])
	quit(0 if errors.is_empty() else 1)
