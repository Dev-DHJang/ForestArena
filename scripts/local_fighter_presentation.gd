extends Node2D
## Read-only presentation. Resource discovery stays outside combat calculations.
const MANIFEST_PATH := "res://assets/character/manifest.json"
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

var fighter: FighterController
var sprite: AnimatedSprite2D
var character_id: StringName
var requested_motion: StringName = &"idle"
var missing_motion: StringName
var _motions: Dictionary = {}
var _motion_layouts: Dictionary = {}
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


func _ready() -> void:
	name = "Presentation"
	fighter = get_parent() as FighterController
	sprite = AnimatedSprite2D.new()
	sprite.name = "ApprovedCharacterSprite"
	# Existing normalized cells place the feet near their lower edge. The fighter
	# collision body extends 14 px below its origin.
	sprite.position = Vector2(0, -50)
	add_child(sprite)
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


func _process(delta: float) -> void:
	sync_visual(delta)


func sync_visual(delta: float) -> void:
	if fighter == null or sprite == null or fighter.runtime_profile == null:
		return
	var profile_id := fighter.runtime_profile.character_id
	if profile_id != character_id:
		character_id = profile_id
		_motions.clear()
		_motion_layouts.clear()
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		for entry: Dictionary in document.get("assets", []):
			if entry.get("character_id") == String(character_id) and entry.has("visual_state_id"):
				_motion_layouts[StringName(entry.visual_state_id)] = entry
		var paths := approved_motion_paths(character_id)
		for motion: StringName in paths:
			_motions[motion] = load(paths[motion]) as SpriteFrames
		_last_motion = &""
		_was_airborne = false
		_jump_stage = -1
		_landing_elapsed = -1.0
	requested_motion = STATE_MOTIONS.get(fighter.state, &"idle")
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
	if fighter.active_attack != null:
		requested_motion = fighter.active_attack.visual_state_id
	missing_motion = &"" if _motions.has(requested_motion) else requested_motion
	var shown := requested_motion if missing_motion.is_empty() else &"idle"
	if not _motions.has(shown):
		sprite.visible = false
		return
	sprite.visible = true
	var layout: Dictionary = _motion_layouts.get(shown, {})
	var display_scale := float(layout.get("presentation_scale", 1.0))
	sprite.scale = Vector2.ONE * display_scale
	sprite.position.y = fighter.ground_contact_offset_y() - (float(layout.get("foot_pivot_y", 128)) - 64.0) * display_scale
	sprite.flip_h = fighter.facing < 0
	if shown != _last_motion or fighter.activation_serial != _last_activation:
		_elapsed = 0.0
		_last_motion = shown
		_last_activation = fighter.activation_serial
		sprite.sprite_frames = _motions[shown]
		sprite.animation = shown
	_elapsed += delta
	var frames := sprite.sprite_frames.get_frame_count(shown)
	if shown == &"jump" and missing_motion.is_empty() and fighter.active_attack == null:
		if airborne:
			var stage := 0 if fighter.velocity.y < -60.0 else (2 if fighter.velocity.y > 60.0 else 1)
			# Read the consumed jump allowance, including early same-stage air jumps.
			var jump_consumed := fighter.air_jumps_remaining < _previous_air_jumps or (_previous_launcher_jump and not fighter.launcher_jump_available)
			var restarted := _was_airborne and (jump_consumed or fighter.velocity.y < _previous_vertical_speed - 120.0)
			if stage != _jump_stage or not _was_airborne or restarted:
				_jump_stage_elapsed = 0.0
				_jump_stage = stage
			_jump_stage_elapsed += delta
			sprite.frame = airborne_jump_frame(fighter.velocity.y, _jump_stage_elapsed)
		else:
			sprite.frame = mini(13 + int(_landing_elapsed * 12.0), 15)
			_landing_elapsed += delta
	elif fighter.active_attack != null and missing_motion.is_empty():
		sprite.frame = attack_frame(fighter.active_attack, fighter.state, fighter.attack_phase_tick, frames, layout.get("phase_frame_ranges", []))
	else:
		var index: int
		var state_duration_ticks := int(layout.get("state_duration_ticks", 0))
		if state_duration_ticks > 0:
			var duration_seconds := float(state_duration_ticks) / 60.0
			index = floori(clampf(_elapsed / duration_seconds, 0.0, 0.999999) * frames)
		else:
			index = int(_elapsed * sprite.sprite_frames.get_animation_speed(shown))
		if layout.has("state_hold_frame"):
			index = mini(index, int(layout.state_hold_frame))
		sprite.frame = index % frames if sprite.sprite_frames.get_animation_loop(shown) else mini(index, frames - 1)
	_was_airborne = airborne
	_previous_vertical_speed = fighter.velocity.y
	_previous_air_jumps = fighter.air_jumps_remaining
	_previous_launcher_jump = fighter.launcher_jump_available
	sprite.modulate = Color(1, 1, 1, 0.45) if fighter.invulnerability_ticks > 0 else Color.WHITE


static func airborne_jump_frame(vertical_speed: float, stage_elapsed: float) -> int:
	# Physics owns position. Airborne art never advances into grounded landing poses.
	var begin := 3 if vertical_speed < -60.0 else (10 if vertical_speed > 60.0 else 6)
	var end := 5 if vertical_speed < -60.0 else (12 if vertical_speed > 60.0 else 9)
	return mini(begin + int(stage_elapsed * 12.0), end)


static func attack_frame(attack: AttackData, state: int, tick: int, count: int, ranges: Array = []) -> int:
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
		return clampi(begin + roundi(float(tick) / maxi(duration - 1, 1) * (end - begin - 1)), begin, end - 1)
	return clampi(int((offset + clampf(float(tick) / maxi(duration, 1), 0, 1)) / 3.0 * count), 0, count - 1)
