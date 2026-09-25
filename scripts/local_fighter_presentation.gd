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
var _elapsed := 0.0
var _last_motion: StringName
var _last_activation := -1


func _ready() -> void:
	fighter = get_parent() as FighterController
	sprite = AnimatedSprite2D.new()
	sprite.name = "ApprovedCharacterSprite"
	# Existing normalized cells place the feet near their lower edge. The fighter
	# collision body extends 14 px below its origin.
	sprite.position = Vector2(0, -50)
	add_child(sprite)
	sync_visual(0.0)


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
		var paths := approved_motion_paths(character_id)
		for motion: StringName in paths:
			_motions[motion] = load(paths[motion]) as SpriteFrames
		_last_motion = &""
	requested_motion = STATE_MOTIONS.get(fighter.state, &"idle")
	if fighter.active_attack != null:
		requested_motion = fighter.active_attack.visual_state_id
	missing_motion = &"" if _motions.has(requested_motion) else requested_motion
	var shown := requested_motion if missing_motion.is_empty() else &"idle"
	if not _motions.has(shown):
		sprite.visible = false
		return
	sprite.visible = true
	sprite.flip_h = fighter.facing < 0
	if shown != _last_motion or fighter.activation_serial != _last_activation:
		_elapsed = 0.0
		_last_motion = shown
		_last_activation = fighter.activation_serial
		sprite.sprite_frames = _motions[shown]
		sprite.animation = shown
	_elapsed += delta
	var frames := sprite.sprite_frames.get_frame_count(shown)
	if fighter.active_attack != null and missing_motion.is_empty():
		sprite.frame = attack_frame(fighter.active_attack, fighter.state, fighter.attack_phase_tick, frames)
	else:
		var index := int(_elapsed * sprite.sprite_frames.get_animation_speed(shown))
		sprite.frame = index % frames if sprite.sprite_frames.get_animation_loop(shown) else mini(index, frames - 1)
	sprite.modulate = Color(1, 1, 1, 0.45) if fighter.invulnerability_ticks > 0 else Color.WHITE


static func attack_frame(attack: AttackData, state: int, tick: int, count: int) -> int:
	# Authored time drives visuals; changing frame rate never changes hit timing.
	var offset := 0.0
	var duration := attack.startup_ticks
	if state == FighterController.State.ATTACK_ACTIVE:
		offset = 1.0
		duration = attack.active_ticks
	elif state == FighterController.State.ATTACK_RECOVERY:
		offset = 2.0
		duration = attack.recovery_ticks
	return clampi(int((offset + clampf(float(tick) / maxi(duration, 1), 0, 1)) / 3.0 * count), 0, count - 1)
