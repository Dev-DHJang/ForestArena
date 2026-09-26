extends SceneTree

const Presentation := preload("res://scripts/local_fighter_presentation.gd")
const ROSTER := [&"ja-hyun", &"myo-ryung", &"nabi", &"yu-ran"]
var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for id: StringName in ROSTER:
		var paths := Presentation.approved_motion_paths(id)
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
		fighter.facing = -1
		presentation.sync_visual(0.01)
		_check(presentation.sprite.flip_h, "facing mirrors visuals")
		var before := fighter.snapshot()
		presentation.sync_visual(1.0)
		_check(before == fighter.snapshot(), "frame updates preserve combat snapshot")
		fighter.state = FighterController.State.GUARD
		presentation.sync_visual(0.01)
		_check(presentation.missing_motion == &"guard", "unapproved guard pose remains explicit")
		for attack: AttackData in fighter.character_data.base_move_set.attacks():
			fighter.active_attack = attack
			fighter.state = FighterController.State.ATTACK_ACTIVE
			presentation.sync_visual(0.01)
			_check(presentation.requested_motion == attack.visual_state_id, "exact move visual ID used")
			if paths.has(attack.visual_state_id):
				_check(presentation.sprite.animation == attack.visual_state_id, "approved combo uses exact step")
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
