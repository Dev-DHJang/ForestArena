extends Node2D
## Read-only presentation. Resource discovery stays outside combat calculations.
const MANIFEST_PATH := "res://assets/character/manifest.json"
const DISPLAY_LAYOUT_PATH := "res://forest_arena/data/character_display_layout_v01.json"
const STATE_MOTIONS := {
	FighterController.State.RUN: &"run", FighterController.State.DASH: &"run",
	FighterController.State.JUMP: &"jump", FighterController.State.FALL: &"jump",
	FighterController.State.GUARD: &"guard", FighterController.State.EVADE: &"evade",
	FighterController.State.CHARGE: &"attack_heavy_charge",
	FighterController.State.HITSTUN: &"hitstun", FighterController.State.LAUNCH: &"launch",
	FighterController.State.KNOCK_DOWN: &"knock_down", FighterController.State.WAKE_UP: &"wake_up",
	FighterController.State.DEAD: &"death", FighterController.State.RING_OUT: &"ring_out",
	FighterController.State.SPAWNING: &"spawn",
}

const ReleaseClock := preload("res://scripts/launch_release_clock.gd")
var release_clock := ReleaseClock.new()
var _release_selected_frame := -1

const AttackEffects := preload("res://scripts/fighter_attack_effects.gd")

var fighter: FighterController
var sprite: AnimatedSprite2D
var effects: Node2D
var character_id: StringName
var requested_motion: StringName = &"idle"
var missing_motion: StringName
var _motions: Dictionary = {}
var _motion_layouts: Dictionary = {}
var _artwork_hashes: Dictionary = {}
static var _display_layouts: Dictionary = {}
static var _display_layouts_loaded := false
var _elapsed := 0.0
var _last_motion: StringName
var _last_activation := -1
var _was_airborne := false
var _previous_vertical_speed := 0.0
var _previous_air_jumps := 0
var _previous_launcher_jump := false
var _jump_stage := -1
var _jump_stage_elapsed := 0.0
var _landing_elapsed := -1.0
var _run_distance := 0.0
var _last_position := Vector2.ZERO
var _position_known := false
var _previous_state := -1
var _spawn_elapsed := -1.0
var _reaction_restart_pending := false
var _reaction_duration_ticks := 0
var _reaction_first_delta := 0.0
var _local_hit_events_pending := 0
var _last_event_epoch := -1
var _last_event_sequence := -1
var _last_event_tick := -1


func _ready() -> void:
	name = "Presentation"
	fighter = get_parent() as FighterController
	fighter.presentation_reset.connect(_reset_playback)
	fighter.hit_reaction_started.connect(_on_hit_reaction_started)
	sprite = AnimatedSprite2D.new()
	sprite.name = "ApprovedCharacterSprite"
	# Existing normalized cells place the feet near their lower edge. The fighter
	# collision body extends 14 px below its origin.
	sprite.position = Vector2(0, -50)
	add_child(sprite)
	effects = AttackEffects.new()
	effects.name = "AttackReachEffects"
	effects.fighter = fighter
	effects.sprite = sprite
	add_child(effects)
	move_child(effects, 0) # Cloth reach stays behind the approved body and face.
	sync_visual(0.0)


func screen_bounds() -> Rect2:
	if sprite == null or not sprite.visible or sprite.sprite_frames == null:
		return Rect2()
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		return Rect2()
	var size := texture.get_size()
	var local_rect := Rect2(-size * 0.5 + sprite.offset, size)
	var transform := sprite.get_global_transform_with_canvas()
	var points := PackedVector2Array([
		transform * local_rect.position,
		transform * Vector2(local_rect.end.x, local_rect.position.y),
		transform * local_rect.end,
		transform * Vector2(local_rect.position.x, local_rect.end.y),
	])
	var result := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		result = result.expand(point)
	return result


static func approved_motion_paths(id: StringName) -> Dictionary:
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	var result := {}
	if not document is Dictionary:
		return result
	for entry: Dictionary in document.get("assets", []):
		if entry.get("type") != "animation-runtime" or entry.get("character_id") != String(id):
			continue
		var path: String = entry.get("sprite_frames_path", "")
		if path.is_empty():
			continue
		var motion := StringName(entry.get("visual_state_id", path.get_file().get_basename()))
		result[motion] = path
	return result


static func display_layout(entry: Dictionary) -> Dictionary:
	# The drawing calibration belongs to the approved sheet, not its path alone.
	# Reading manifest hashes also works after Android texture import/remapping.
	if not _display_layouts_loaded:
		_display_layouts_loaded = true
		var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(DISPLAY_LAYOUT_PATH))
		if document is Dictionary and int(document.get("schema_version", 0)) == 1:
			for row: Dictionary in document.get("motions", []):
				var key := "%s/%s" % [row.get("character_id", ""), row.get("motion_id", "")]
				_display_layouts[key] = row
	var key := "%s/%s" % [entry.get("character_id", ""), entry.get("visual_state_id", "")]
	var calibration: Dictionary = _display_layouts.get(key, {})
	var hash_matches: bool = not calibration.is_empty() and not String(entry.get("sha256", "")).is_empty() and calibration.get("asset_sha256") == entry.get("sha256")
	var result := {"scale": float(entry.get("presentation_scale", 1.0)), "foot_pivot_y": float(entry.get("foot_pivot_y", 128)), "calibrated": hash_matches}
	if hash_matches:
		result.merge({"scale": float(calibration.scale), "foot_pivot_y": float(calibration.foot_pivot_y), "descent_frame_range": calibration.get("descent_frame_range", []), "landing_frame_range": calibration.get("landing_frame_range", [13,16]), "landing_down_frame_range": calibration.get("landing_down_frame_range", [12,16])}, true)
	# Optional drawing data travels with the hashed artwork entry. Explicit entry
	# values win over a matching calibration, so a candidate can revise timing or
	# attachments even when the source PNG is intentionally unchanged.
	if not String(entry.get("sha256", "")).is_empty():
		for field: String in ["frame_count", "frame_durations", "jump_frame_ranges", "run_stride_px", "frame_anchors", "phase_frame_ranges", "descent_frame_range", "landing_frame_range", "landing_down_frame_range", "launch_release_frame_range", "launch_release_ticks", "hit_reaction_lead_frame_range", "hit_reaction_lead_ticks"]:
			if hash_matches and calibration.has(field): result[field] = calibration[field]
			if entry.has(field): result[field] = entry[field]
	return result


func _process(delta: float) -> void:
	sync_visual(delta)


func _reset_playback() -> void:
	release_clock.reset()
	_release_selected_frame = -1
	_elapsed = 0.0
	_last_motion = &""
	_last_activation = -1
	_was_airborne = false
	_previous_vertical_speed = 0.0
	_previous_air_jumps = 0
	_previous_launcher_jump = false
	_jump_stage = -1
	_jump_stage_elapsed = 0.0
	_landing_elapsed = -1.0
	_run_distance = 0.0
	_position_known = false
	_previous_state = -1
	_spawn_elapsed = -1.0
	_reaction_restart_pending = false
	_reaction_duration_ticks = 0
	_reaction_first_delta = 0.0
	_local_hit_events_pending = 0


func _on_hit_reaction_started() -> void:
	release_clock.cancel()
	# Observe the completed hit; never derive or extend its combat duration.
	_reaction_restart_pending = true
	_reaction_duration_ticks = maxi(fighter.hitstun_ticks, 1)
	_local_hit_events_pending += 1


func play_combat_event(event_id: StringName, payload: Dictionary) -> void:
	var epoch := int(payload.get("epoch", -1))
	var sequence := int(payload.get("event_seq", -1))
	var tick := int(payload.get("tick", -1))
	if epoch < 0 or sequence < 0 or epoch < _last_event_epoch: return
	if epoch == _last_event_epoch and (sequence <= _last_event_sequence or tick < _last_event_tick): return
	if epoch > _last_event_epoch:
		_last_event_sequence = -1
		_last_event_tick = -1
	_last_event_epoch = epoch
	_last_event_sequence = sequence
	_last_event_tick = tick
	if event_id != &"hit_resolved" or StringName(payload.get("defender_id", "")) != fighter.fighter_id or payload.get("result", "") != "HIT": return
	if _local_hit_events_pending > 0:
		# Local apply_hit has already restarted this drawing. Its forwarded match
		# event is the same observation, not a second hit.
		_local_hit_events_pending -= 1
		return
	if fighter.state not in [FighterController.State.HITSTUN, FighterController.State.LAUNCH, FighterController.State.KNOCK_DOWN]: return
	release_clock.cancel()
	_reaction_restart_pending = true
	# LAN3 has no remaining-hitstun field. Use authored drawing speed and obey
	# the next received state; presentation must not calculate missing combat data.
	_reaction_duration_ticks = 0


func sync_visual(delta: float) -> void:
	if fighter == null or sprite == null or fighter.runtime_profile == null:
		return
	var profile_id := fighter.runtime_profile.character_id
	if profile_id != character_id:
		character_id = profile_id
		_motions.clear()
		_motion_layouts.clear()
		_artwork_hashes.clear()
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		for entry: Dictionary in document.get("assets", []):
			if entry.get("character_id") == String(character_id) and entry.has("visual_state_id"):
				_motion_layouts[StringName(entry.visual_state_id)] = entry
		var paths := approved_motion_paths(character_id)
		for motion: StringName in paths:
			_motions[motion] = load(paths[motion]) as SpriteFrames
		_reset_playback()
	requested_motion = STATE_MOTIONS.get(fighter.state, &"idle")
	if _previous_state == FighterController.State.RING_OUT and fighter.state == FighterController.State.IDLE and fighter.stocks > 0:
		_spawn_elapsed = 0.0
		_landing_elapsed = -1.0
	_previous_state = fighter.state
	var airborne := fighter.state in [FighterController.State.JUMP, FighterController.State.FALL]
	if airborne:
		_landing_elapsed = -1.0
	elif _was_airborne and fighter.state == FighterController.State.IDLE and fighter.active_attack == null:
		_landing_elapsed = 0.0
	if _landing_elapsed >= 0.0:
		if fighter.state != FighterController.State.IDLE or fighter.active_attack != null:
			_landing_elapsed = -1.0
		elif _landing_elapsed < 0.25:
			requested_motion = &"jump"
		else:
			_landing_elapsed = -1.0
	if fighter.wakeup_protection_ticks > 0 and (fighter.state == FighterController.State.WAKE_UP or (fighter.state == FighterController.State.IDLE and fighter.is_on_floor())):
		requested_motion = &"wake_up"
	if _spawn_elapsed >= 0.0:
		if fighter.state != FighterController.State.IDLE or fighter.active_attack != null or not _motions.has(&"spawn"):
			_spawn_elapsed = -1.0
		else:
			var spawn_frames: SpriteFrames = _motions[&"spawn"]
			var spawn_layout: Dictionary = _motion_layouts.get(&"spawn", {})
			var spawn_weights: Array = spawn_layout.get("frame_durations", [])
			var units := float(spawn_frames.get_frame_count(&"spawn"))
			if not spawn_weights.is_empty():
				units = 0.0
				for weight: float in spawn_weights: units += weight
			var spawn_duration := float(spawn_layout.get("state_duration_ticks", 0)) / 60.0
			if spawn_duration <= 0.0: spawn_duration = units / maxf(spawn_frames.get_animation_speed(&"spawn"), 0.01)
			if _spawn_elapsed < spawn_duration:
				requested_motion = &"spawn"
				_spawn_elapsed += maxf(delta, 0.0)
			else:
				_spawn_elapsed = -1.0
	var present_attack := fighter.active_attack != null and fighter.state != FighterController.State.MATCH_ENDED
	if present_attack:
		requested_motion = fighter.active_attack.visual_state_id
		if fighter.active_attack.attack_movement == 1 and fighter.attack_travel_active:
			# The authored 32-frame special includes its own travel poses.
			# Older approved 16-frame specials continue to use the run cycle.
			var travel_frames: SpriteFrames = _motions.get(requested_motion)
			if requested_motion != &"special_side" or travel_frames == null or travel_frames.get_frame_count(requested_motion) != 32:
				requested_motion = &"run"
	if fighter.state == FighterController.State.MATCH_ENDED:
		requested_motion = &"death" if fighter.stocks <= 0 else &"idle"
	# Optional display-only release. Observe already-applied state/input results.
	var launch_frames: SpriteFrames = _motions.get(&"launch")
	var launch_count := launch_frames.get_frame_count(&"launch") if launch_frames != null else 0
	_release_selected_frame = release_clock.select({"state":fighter.state,"attack":fighter.active_attack != null,"activation":fighter.activation_serial,"air_jumps":fighter.air_jumps_remaining,"launcher_jump":fighter.launcher_jump_available,"velocity_y":fighter.velocity.y},_motion_layouts.get(&"launch",{}),launch_count,delta)
	if _release_selected_frame >= 0: requested_motion = &"launch"
	missing_motion = &"" if _motions.has(requested_motion) else requested_motion
	var shown := requested_motion if missing_motion.is_empty() else &"idle"
	if not _motions.has(shown):
		sprite.visible = false
		_position_known = false
		if effects != null:
			effects.frame_anchors = []
			effects.phase_frame_ranges = []
			effects.artwork_sha256 = ""
		return
	sprite.visible = true
	var layout: Dictionary = _motion_layouts.get(shown, {})
	var drawing := display_layout(layout)
	var display_scale := float(drawing.scale)
	sprite.scale = Vector2.ONE * display_scale
	sprite.position.x = 0.0
	sprite.position.y = fighter.ground_contact_offset_y() - (float(drawing.foot_pivot_y) - 64.0) * display_scale
	sprite.flip_h = fighter.facing < 0
	var reaction_motion := shown in [&"hitstun", &"launch", &"knock_down"]
	var restarted_motion := shown != _last_motion or fighter.activation_serial != _last_activation or (_reaction_restart_pending and reaction_motion)
	if shown in [&"hitstun", &"launch"] and shown != _last_motion and not _reaction_restart_pending:
		_reaction_duration_ticks = maxi(fighter.hitstun_ticks, 0)
	if _reaction_restart_pending and reaction_motion:
		_reaction_restart_pending = false
	elif not reaction_motion:
		_reaction_restart_pending = false
		_reaction_duration_ticks = 0
	if restarted_motion:
		_elapsed = 0.0
		_reaction_first_delta = maxf(delta, 0.0)
		_run_distance = 0.0
		_last_motion = shown
		_last_activation = fighter.activation_serial
		sprite.sprite_frames = _motions[shown]
		sprite.animation = shown
	_elapsed += delta
	var frames := sprite.sprite_frames.get_frame_count(shown)
	var weights: Array = drawing.get("frame_durations", [])
	# A remote HIT may arrive every six ticks. At authored FPS, restarting
	# can show only the opening poses and miss the visible impact. An authored lead is
	# drawing time only; it never supplies LAN's missing combat-stun duration.
	var lead_frame := -1
	if shown == &"hitstun" and _reaction_duration_ticks <= 0:
		lead_frame = hit_reaction_lead_frame(maxf(0.0, _elapsed - _reaction_first_delta), sprite.sprite_frames.get_animation_speed(shown), frames, drawing, weights)
	var position_delta := fighter.global_position - _last_position if _position_known else Vector2.ZERO
	_last_position = fighter.global_position
	_position_known = true
	if effects != null:
		effects.frame_anchors = drawing.get("frame_anchors", [])
		effects.phase_frame_ranges = drawing.get("phase_frame_ranges", [])
		effects.artwork_sha256 = _artwork_hash(layout)
	if _release_selected_frame >= 0:
		sprite.frame = _release_selected_frame
	elif shown in [&"hitstun", &"launch"] and _reaction_duration_ticks > 0:
		var elapsed_ticks := _reaction_duration_ticks - fighter.hitstun_ticks
		sprite.frame = timed_frame(elapsed_ticks, _reaction_duration_ticks, 0, frames) if weights.is_empty() else weighted_frame(float(elapsed_ticks) / maxi(_reaction_duration_ticks - 1, 1), 0, frames, weights)
	elif lead_frame >= 0:
		sprite.frame = lead_frame
	elif shown == &"knock_down" and fighter.landing_down_ticks > 0:
		var span: Array = drawing.get("landing_down_frame_range", [12,16])
		sprite.frame = timed_frame(18 - fighter.landing_down_ticks,18,int(span[0]),int(span[1])) if weights.is_empty() else weighted_frame(float(18-fighter.landing_down_ticks)/17.0,int(span[0]),int(span[1]),weights)
	elif shown == &"wake_up" and fighter.wakeup_protection_ticks > 0:
		sprite.frame = timed_frame(12 - fighter.wakeup_protection_ticks,12,0,frames) if weights.is_empty() else weighted_frame(float(12-fighter.wakeup_protection_ticks)/11.0,0,frames,weights)
	elif shown == &"jump" and missing_motion.is_empty() and fighter.active_attack == null:
		if airborne:
			var stage := 0 if fighter.velocity.y < -60.0 else (2 if fighter.velocity.y > 60.0 else 1)
			# Read the consumed jump allowance, including early same-stage air jumps.
			var jump_consumed := fighter.air_jumps_remaining < _previous_air_jumps or (_previous_launcher_jump and not fighter.launcher_jump_available)
			var restarted := _was_airborne and (jump_consumed or fighter.velocity.y < _previous_vertical_speed - 120.0)
			if stage != _jump_stage or not _was_airborne or restarted:
				_jump_stage_elapsed = 0.0
				_jump_stage = stage
			_jump_stage_elapsed += delta
			var jump_ranges: Dictionary = drawing.get("jump_frame_ranges", {})
			if jump_ranges.is_empty():
				sprite.frame = airborne_jump_frame(fighter.velocity.y, _jump_stage_elapsed, drawing.get("descent_frame_range", []))
			else:
				var stage_names := ["ascent", "apex", "descent"]
				var span: Array = jump_ranges[stage_names[stage]]
				sprite.frame = playback_frame(_jump_stage_elapsed, sprite.sprite_frames.get_animation_speed(shown), int(span[0]), int(span[1]), weights, false)
		else:
			var span: Array = drawing.get("jump_frame_ranges", {}).get("landing", drawing.get("landing_frame_range", [13,16]))
			sprite.frame = weighted_frame(_landing_elapsed / 0.25, int(span[0]), int(span[1]), weights)
			_landing_elapsed += delta
	elif present_attack and missing_motion.is_empty() and shown != &"run":
		sprite.frame = attack_frame(fighter.active_attack, fighter.state, fighter.attack_phase_tick, frames, drawing.get("phase_frame_ranges", layout.get("phase_frame_ranges", [])), weights)
	elif shown == &"run" and float(drawing.get("run_stride_px", 0.0)) > 0.0:
		var stride := float(drawing.run_stride_px)
		# Position is only observed. A teleport, respawn or fresh run starts a new
		# foot cycle; standing still never advances the distance-driven cycle.
		if restarted_motion or position_delta.length() > stride * 2.0:
			_run_distance = 0.0
		else:
			_run_distance = fposmod(_run_distance + absf(position_delta.x), stride)
		sprite.frame = weighted_frame(_run_distance / stride, 0, frames, weights)
	else:
		var index: int
		var state_duration_ticks := int(layout.get("state_duration_ticks", 0))
		if state_duration_ticks > 0:
			var duration_seconds := float(state_duration_ticks) / 60.0
			index = weighted_frame(_elapsed / duration_seconds, 0, frames, weights)
		else:
			index = int(_elapsed * sprite.sprite_frames.get_animation_speed(shown)) if weights.is_empty() else playback_frame(_elapsed, sprite.sprite_frames.get_animation_speed(shown), 0, frames, weights, sprite.sprite_frames.get_animation_loop(shown))
		if layout.has("state_hold_frame"):
			index = mini(index, int(layout.state_hold_frame))
		sprite.frame = index % frames if sprite.sprite_frames.get_animation_loop(shown) else mini(index, frames - 1)
	if fighter.state == FighterController.State.LAUNCH and shown == &"launch":
		release_clock.remember_actual_launch(sprite.frame)
	_was_airborne = airborne
	var frame_anchors: Array = drawing.get("frame_anchors", [])
	if frame_anchors.size() == frames:
		var anchors: Variant = frame_anchors[sprite.frame]
		if anchors is Dictionary and anchors.has("body_root") and AttackEffects._valid_pixel_point(anchors.body_root):
			var origin := Vector2(float(anchors.body_root[0]),float(anchors.body_root[1]))
			if origin.x >= 0.0 and origin.x <= 128.0 and origin.y >= 0.0 and origin.y <= 128.0:
				sprite.position.x = (64.0-origin.x) * display_scale * (-1.0 if sprite.flip_h else 1.0)
				sprite.position.y = fighter.ground_contact_offset_y() - (origin.y-64.0) * display_scale
	_previous_vertical_speed = fighter.velocity.y
	_previous_air_jumps = fighter.air_jumps_remaining
	_previous_launcher_jump = fighter.launcher_jump_available
	var show_protection := fighter.invulnerability_ticks > 0 and fighter.state not in [FighterController.State.DEAD, FighterController.State.MATCH_ENDED]
	sprite.modulate = Color(1, 1, 1, 0.45) if show_protection else Color.WHITE


func _artwork_hash(entry: Dictionary) -> String:
	# Exported production art has a manifest hash. Old private review candidates
	# may omit it; hash their original PNG once, never on every render tick.
	var declared := String(entry.get("sha256", ""))
	if not declared.is_empty(): return declared
	var path := String(entry.get("path", ""))
	if path.is_empty(): return ""
	if not _artwork_hashes.has(path):
		_artwork_hashes[path] = FileAccess.get_sha256("res://" + path.trim_prefix("res://"))
	return _artwork_hashes[path]


static func timed_frame(elapsed_ticks: int, duration_ticks: int, begin: int, end: int) -> int:
	return clampi(begin + roundi(float(elapsed_ticks) / maxi(duration_ticks - 1,1) * (end - begin - 1)),begin,end-1)


static func hit_reaction_lead_frame(elapsed: float, fps: float, count: int, layout: Dictionary, weights: Array = []) -> int:
	# Optional, hash-bound display data. Invalid or absent pairs keep legacy FPS.
	var span: Variant = layout.get("hit_reaction_lead_frame_range")
	var ticks: Variant = layout.get("hit_reaction_lead_ticks")
	if not span is Array or span.size() != 2: return -1
	for value: Variant in [span[0], span[1], ticks]:
		if not (value is int or value is float): return -1
		if not is_finite(float(value)) or float(value) != floorf(float(value)): return -1
	var begin := int(span[0])
	var end := int(span[1])
	var duration := int(ticks)
	if begin != 0 or end <= begin or end > count or duration < end - begin or duration > 12: return -1
	var lead_seconds := float(duration) / 60.0
	if elapsed < lead_seconds:
		return timed_frame(int(floorf(maxf(0.0, elapsed) * 60.0 + 0.000001)), duration, begin, end)
	if end == count: return count - 1
	return playback_frame(elapsed - lead_seconds, fps, end, count, weights)


static func airborne_jump_frame(vertical_speed: float, stage_elapsed: float, descent: Array = []) -> int:
	# Physics owns position. Airborne art never advances into grounded landing poses.
	var begin := 3 if vertical_speed < -60.0 else (10 if vertical_speed > 60.0 else 6)
	if vertical_speed > 60.0 and descent.size() == 2:
		return mini(int(descent[0]) + int(stage_elapsed * 12.0),int(descent[1])-1)
	var end := 5 if vertical_speed < -60.0 else (12 if vertical_speed > 60.0 else 9)
	return mini(begin + int(stage_elapsed * 12.0), end)


static func attack_frame(attack: AttackData, state: int, tick: int, count: int, ranges: Array = [], weights: Array = []) -> int:
	# Authored time drives visuals; changing frame rate never changes hit timing.
	var offset := 0.0
	var duration := attack.startup_ticks
	if state == FighterController.State.ATTACK_ACTIVE:
		offset = 1.0
		duration = attack.active_ticks
	elif state == FighterController.State.ATTACK_RECOVERY:
		offset = 2.0
		duration = attack.recovery_ticks
	if ranges.size() == 3:
		var span: Array = ranges[int(offset)]
		var begin := int(span[0])
		var end := int(span[1])
		if not weights.is_empty():
			return weighted_frame(float(tick) / maxi(duration - 1, 1), begin, end, weights)
		return clampi(begin + roundi(float(tick) / maxi(duration - 1, 1) * (end - begin - 1)), begin, end - 1)
	return clampi(int((offset + clampf(float(tick) / maxi(duration, 1), 0, 1)) / 3.0 * count), 0, count - 1)


static func weighted_frame(progress: float, begin: int, end: int, weights: Array = []) -> int:
	# Empty weights are uniform. Existing attack ranges deliberately keep their
	# original rounded mapping above; new authored weights use interval lengths.
	var total := _frame_weight_sum(begin, end, weights)
	var cursor := clampf(progress, 0.0, 0.999999) * total
	for index: int in range(begin, end):
		cursor -= _frame_weight(index, weights)
		if cursor < 0.0: return index
	return end - 1


static func playback_frame(elapsed: float, fps: float, begin: int, end: int, weights: Array = [], loop: bool = false) -> int:
	var total := _frame_weight_sum(begin, end, weights)
	var position := maxf(elapsed, 0.0) * fps
	if loop: position = fposmod(position, total)
	return weighted_frame(position / total, begin, end, weights)


static func _frame_weight(index: int, weights: Array) -> float:
	if index < weights.size() and (weights[index] is float or weights[index] is int):
		var value := float(weights[index])
		if is_finite(value) and value > 0.0: return value
	return 1.0


static func _frame_weight_sum(begin: int, end: int, weights: Array) -> float:
	var total := 0.0
	for index: int in range(begin, end): total += _frame_weight(index, weights)
	return maxf(total, 0.000001)
