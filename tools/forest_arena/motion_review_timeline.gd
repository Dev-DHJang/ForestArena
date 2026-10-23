extends SceneTree
## Execute the project's real presentation; export only review data, never assets.
const Presentation := preload("res://scripts/local_fighter_presentation.gd")
var errors: Array[String] = []
var candidate_plan: Dictionary = {}
var candidate_textures: Array[Texture2D] = []
var warnings: Array[String] = []
var registered_sources: Dictionary = {}
var used_movesets: Array[MoveSetData] = []


func _initialize() -> void:
	call_deferred("_run")


func _sample(presentation: Node2D, fighter: FighterController, delta: float, phase: String) -> Dictionary:
	var before := fighter.snapshot()
	presentation.sync_visual(delta)
	if before != fighter.snapshot():
		errors.append("presentation changed combat snapshot")
	return {"frame": presentation.sprite.frame, "shown": String(presentation.sprite.animation), "phase": phase, "duration_ms": 1000.0 / 60.0, "position": [fighter.position.x, fighter.position.y]}


func _reset(presentation: Node2D, fighter: FighterController) -> void:
	fighter.active_attack = null
	fighter.landing_down_ticks = 0
	fighter.wakeup_protection_ticks = 0
	fighter.state = FighterController.State.IDLE
	presentation._last_motion = &""
	presentation._elapsed = 0.0
	presentation._was_airborne = false
	presentation._landing_elapsed = -1.0
	presentation._jump_stage = -1


func _install_candidates(presentation: Node2D, id: String) -> void:
	for entry: Dictionary in candidate_plan.get("rows", []):
		if entry.character_id != id: continue
		var frames: SpriteFrames = preload("res://tools/forest_arena/motion_review_candidate_frames.gd").load_frames(entry, errors, candidate_textures)
		if frames != null:
			var motion := StringName(entry.visual_state_id)
			presentation._motions[motion] = frames
			if not entry.get("reuse_approved_runtime", false): presentation._motion_layouts[motion] = entry.duplicate(true)


func _registered_moves(entry: Dictionary, id: String, fallback: MoveSetData) -> MoveSetData:
	var registration: Dictionary = entry.get("motion_registration", {})
	if registration.is_empty(): return fallback
	var source := String(registration.get("catalog_path", ""))
	if not source.begins_with("_workspace/") or ".." in source.split("/") or "\\" in source:
		errors.append("unsafe registered motion catalog: " + source)
		return fallback
	var path := "res://" + source
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != registration.get("catalog_sha256"):
		errors.append("registered motion catalog changed or missing: " + source)
		return fallback
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not document is Dictionary:
		errors.append("registered motion catalog is not an object: " + source)
		return fallback
	registered_sources[source] = FileAccess.get_sha256(path)
	var moves_path := String(document.get("character_movesets", {}).get(id, ""))
	var moves := load("res://" + moves_path.trim_prefix("res://")) as MoveSetData
	if moves == null:
		errors.append("registered motion has no recorded MoveSetData: " + id)
		return fallback
	return moves


func _run() -> void:
	var output := ""
	var catalog := ""
	var scope := ""
	var scope_digest := ""
	var args := OS.get_cmdline_user_args()
	for index in range(args.size() - 1):
		if args[index] == "--output": output = args[index + 1]
		elif args[index] == "--catalog": catalog = args[index + 1]
		elif args[index] == "--scope": scope = args[index + 1]
		elif args[index] == "--scope-sha256": scope_digest = args[index + 1]
	if output.is_empty():
		push_error("--output absolute JSON path is required")
		quit(1)
		return
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/character/manifest.json"))
	var ids: Array[String] = ["ja-hyun", "myo-ryung", "nabi", "yu-ran"]
	if not catalog.is_empty() or not scope.is_empty():
		if catalog.is_empty() or scope.is_empty():
			push_error("candidate timeline requires both --catalog and --scope")
			quit(1)
			return
		var arguments := PackedStringArray([ProjectSettings.globalize_path("res://tools/forest_arena/motion_review_candidates.py"), "--project-root", ProjectSettings.globalize_path("res://"), "--catalog", ProjectSettings.globalize_path(catalog), "--scope", ProjectSettings.globalize_path(scope)])
		if not scope_digest.is_empty(): arguments.append_array(["--scope-sha256", scope_digest])
		var captured: Array = []
		var code := OS.execute("python3", arguments, captured, true)
		var raw := "".join(captured)
		if code != 0:
			push_error(raw)
			quit(1)
			return
		var parsed: Variant = JSON.parse_string(raw)
		if not parsed is Dictionary:
			push_error("candidate preflight returned invalid JSON")
			quit(1)
			return
		candidate_plan = parsed
		document = {"assets": candidate_plan.rows}
		ids.clear()
		for row: Dictionary in candidate_plan.rows:
			if not ids.has(String(row.character_id)): ids.append(String(row.character_id))
		ids.sort()
	var motions: Array[Dictionary] = []
	for id: String in ids:
		var fighter := FighterController.new()
		fighter.character_data = load("res://assets/character/%s/character.tres" % id)
		fighter.fighter_id = StringName(id)
		root.add_child(fighter)
		fighter.set_physics_process(false)
		var profile := RuntimeCombatProfile.new()
		profile.character_id = StringName(id)
		profile.stats = fighter.character_data.base_stats
		profile.move_set = fighter.character_data.base_move_set
		if not candidate_plan.is_empty():
			profile.move_set = load("res://" + String(candidate_plan.character_movesets[id]).trim_prefix("res://")) as MoveSetData
			if profile.move_set == null:
				push_error("candidate character_movesets entry is not a MoveSetData: " + id)
				quit(1)
				return
		fighter.attacks = profile.move_set.attacks()
		fighter.runtime_profile = profile
		var presentation := Presentation.new()
		fighter.add_child(presentation)
		presentation.set_process(false)
		if not candidate_plan.is_empty(): _install_candidates(presentation, id)
		for entry: Dictionary in document.assets:
			if entry.get("type") not in ["animation-runtime", "animation-candidate"] or entry.get("character_id") != id: continue
			if candidate_plan.is_empty():
				profile.move_set = _registered_moves(entry, id, fighter.character_data.base_move_set)
				fighter.attacks = profile.move_set.attacks()
			if not used_movesets.has(profile.move_set): used_movesets.append(profile.move_set)
			var motion := String(entry.get("visual_state_id", String(entry.sprite_frames_path).get_file().get_basename()))
			var variants: Array[Dictionary] = []
			var review_attacks: Array[AttackData] = profile.move_set.attacks()
			if motion == "attack_heavy_charge":
				for base_attack: AttackData in profile.move_set.attacks():
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
				if not candidate_plan.is_empty() and not entry.get("reuse_approved_runtime", false) and int(entry.get("frame_count",16)) != 16 and not entry.has("phase_frame_ranges"):
					errors.append("variable-count attack requires explicit phase_frame_ranges: %s/%s" % [id,motion])
				if entry.has("phase_frame_ranges"):
					for phase_index: int in 3:
						var bounds: Array = entry.phase_frame_ranges[phase_index]
						if int(bounds[1]) - int(bounds[0]) > int(lengths[phase_index]):
							var message := "phase drawings exceed visible combat ticks: %s/%s %s" % [id, motion, ["startup", "active", "recovery"][phase_index]]
							if entry.get("reuse_approved_runtime", false) or candidate_plan.is_empty(): warnings.append(message)
							else: errors.append(message)
				for phase_index in range(3):
					fighter.state = phases[phase_index]
					for tick in range(lengths[phase_index]):
						fighter.attack_phase_tick = tick
						samples.append(_sample(presentation, fighter, 1.0 / 60.0, ["startup", "active", "recovery"][phase_index]))
				if not candidate_plan.is_empty() and not entry.get("reuse_approved_runtime", false):
					var all_visible := {}
					for sample: Dictionary in samples: all_visible[sample.frame] = true
					for frame_index: int in range(int(entry.get("frame_count",16))):
						if not all_visible.has(frame_index): errors.append("candidate authored drawing skipped by full attack playback: %s/%s frame %d" % [id,motion,frame_index])
				if not candidate_plan.is_empty() and not entry.get("reuse_approved_runtime", false) and entry.has("phase_frame_ranges"):
					for phase_index: int in 3:
						var phase_name: String = ["startup", "active", "recovery"][phase_index]
						var visible := {}
						for sample: Dictionary in samples:
							if sample.phase == phase_name: visible[sample.frame] = true
						var bounds: Array = entry.phase_frame_ranges[phase_index]
						for frame_index: int in range(int(bounds[0]),int(bounds[1])):
							if not visible.has(frame_index): errors.append("candidate authored drawing skipped by actual phase playback: %s/%s/%s frame %d" % [id,motion,phase_name,frame_index])
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
					var weights := float(entry.get("frame_count", 16))
					if entry.has("frame_durations"):
						weights = 0.0
						for weight: float in entry.frame_durations: weights += weight
					var state_ticks := ceili(weights / float(entry.fps) * 60.0) * 2 if entry.get("loop", false) else 120
					# Run review advances real displayed distance, not an artificial FPS counter.
					for tick in range(state_ticks):
						if motion == "run" and entry.has("run_stride_px"):
							fighter.position.x = float(tick) * float(entry.run_stride_px) * 2.0 / state_ticks
						samples.append(_sample(presentation, fighter, 1.0 / 60.0, motion))
				variants.push_front({"attack_id": "state:" + motion, "stimulus": "synthetic fixed state: 120 ticks or two complete loops; jump uses staged vertical speeds", "samples": samples})
			if not candidate_plan.is_empty() and motion in ["knock_down", "wake_up"]:
				_reset(presentation,fighter)
				var samples: Array[Dictionary] = []
				var duration := 18 if motion == "knock_down" else 12
				fighter.state = FighterController.State.KNOCK_DOWN if motion == "knock_down" else FighterController.State.WAKE_UP
				for remaining: int in range(duration,0,-1):
					if motion == "knock_down": fighter.landing_down_ticks=remaining
					else: fighter.wakeup_protection_ticks=remaining
					samples.append(_sample(presentation,fighter,1.0/60.0,motion))
				variants.append({"attack_id":"state:landing-down-18" if motion == "knock_down" else "state:wakeup-protection-12","stimulus":"current combat timer; actual grounded idle transition also covered by tests/two_fighter_presentation.gd", "samples":samples})
			var required_ids: Array[String] = []
			for variant: Dictionary in variants: required_ids.append(variant.attack_id)
			motions.append({"required_variant_ids": required_ids, "character_id": id, "motion": motion, "sheet_sha256": FileAccess.get_sha256("res://" + String(entry.path)), "variants": variants})
		fighter.free()
	var fingerprints := {}
	for source: String in ["assets/character/manifest.json", "scripts/local_fighter_presentation.gd", "scripts/fighter_controller.gd", "docs/contracts/attack-system-v01.json", "docs/gameplay/combat.md"]:
		fingerprints[source] = FileAccess.get_sha256("res://" + source)
	if FileAccess.file_exists("res://tools/forest_arena/motion_layout.py"):
		fingerprints["tools/forest_arena/motion_layout.py"] = FileAccess.get_sha256("res://tools/forest_arena/motion_layout.py")
	if FileAccess.file_exists("res://scripts/fighter_attack_effects.gd"):
		fingerprints["scripts/fighter_attack_effects.gd"] = FileAccess.get_sha256("res://scripts/fighter_attack_effects.gd")
	var presentation_constants := (load("res://scripts/local_fighter_presentation.gd") as GDScript).get_script_constant_map()
	var layout_path := String(presentation_constants.get("DISPLAY_LAYOUT_PATH", ""))
	if not layout_path.is_empty():
		fingerprints[layout_path.trim_prefix("res://")] = FileAccess.get_sha256(layout_path)
	for entry: Dictionary in document.assets:
		if entry.get("type") in ["animation-runtime", "animation-candidate"]:
			var path := String(entry.sprite_frames_path).trim_prefix("res://")
			fingerprints[path] = FileAccess.get_sha256("res://" + path)
	# AttackData can be an external or embedded resource; pin all source resources.
	for id: String in ids:
		var character: CharacterData = load("res://assets/character/%s/character.tres" % id)
		var selected_moves := character.base_move_set
		if not candidate_plan.is_empty(): selected_moves = load("res://" + String(candidate_plan.character_movesets[id]).trim_prefix("res://")) as MoveSetData
		for resource: Resource in [character, selected_moves] + selected_moves.attacks():
			var path := resource.resource_path.split("::")[0].trim_prefix("res://")
			if not path.is_empty(): fingerprints[path] = FileAccess.get_sha256("res://" + path)
	for moves: MoveSetData in used_movesets:
		for resource: Resource in [moves] + moves.attacks():
			var path := resource.resource_path.split("::")[0].trim_prefix("res://")
			if not path.is_empty(): fingerprints[path] = FileAccess.get_sha256("res://" + path)
	fingerprints.merge(registered_sources)
	for source: String in candidate_plan.get("required_sources", []):
		fingerprints[source] = FileAccess.get_sha256("res://" + source)
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("cannot write " + output)
		quit(1)
		return
	var result := {"schema_version": 1, "generator_sha256": FileAccess.get_sha256(get_script().resource_path), "sources": fingerprints, "motions": motions, "errors": errors, "warnings": warnings}
	if not candidate_plan.is_empty(): result["candidate_selection"] = candidate_plan.candidate_selection
	file.store_string(JSON.stringify(result, "\t") + "\n")
	for error in errors: push_error(error)
	print("MOTION_REVIEW_TIMELINE: %s (%d motions)" % ["PASS" if errors.is_empty() else "FAIL", motions.size()])
	quit(0 if errors.is_empty() else 1)
