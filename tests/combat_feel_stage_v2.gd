extends SceneTree

const PushboxResolverScript = preload("res://scripts/pushbox_resolver.gd")
var failures: PackedStringArray = []


func _initialize() -> void:
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	var controller := scene.get_node("MatchController") as MatchController
	controller.set_physics_process(false)
	var stage := controller.stage_data
	_check(stage != null and stage.is_valid_definition(), "StageData v1 is invalid")
	_check(stage.stage_id == &"forest-ledge", "stage ID drifted")
	_check(stage.main_floor().rect == Rect2(-440, 586, 2160, 48), "2160-wide main floor drifted")
	var expected := [
		Rect2(-300, 470, 380, 24), Rect2(120, 380, 420, 24),
		Rect2(760, 430, 520, 24), Rect2(1330, 350, 280, 24),
	]
	for index: int in expected.size():
		_check(stage.surfaces[index + 1].rect == expected[index] and stage.surfaces[index + 1].one_way, "asymmetric platform %d drifted" % index)
	_check(stage.ring_bounds == Rect2(-760, -360, 2800, 1260), "ring-out bounds drifted")
	_check(stage.spawn_points.size() == 8, "eight local spawn points are required")

	var player := controller.player
	var opponent := controller.training_dummy
	controller.reset_match()
	for ignored: int in 45:
		await physics_frame
		player.step_tick(controller.rules)
		opponent.step_tick(controller.rules)
	_check(player.is_on_floor(), "player did not settle on expanded ground")
	_check(absf(player.global_position.y + player.ground_contact_offset_y() - stage.main_floor().rect.position.y) <= 0.1, "fighter foot baseline does not touch collision floor")

	player.global_position = Vector2(640, 572)
	opponent.global_position = Vector2(640, 572)
	player.state = FighterController.State.IDLE
	opponent.state = FighterController.State.IDLE
	PushboxResolverScript.resolve([opponent, player])
	_check(not player.get_pushbox_rect().intersects(opponent.get_pushbox_rect()), "equal-center pushboxes remained overlapped")
	_check((player.fighter_id < opponent.fighter_id) == (player.global_position.x < opponent.global_position.x), "fighter ID tie-break is not deterministic: %s=%s %s=%s" % [player.fighter_id, player.global_position.x, opponent.fighter_id, opponent.global_position.x])
	var first_positions := [player.global_position, opponent.global_position]
	player.global_position = Vector2(640, 572)
	opponent.global_position = Vector2(640, 572)
	PushboxResolverScript.resolve([player, opponent])
	_check(first_positions == [player.global_position, opponent.global_position], "pushbox result changed with input array order")
	var crowd: Array[FighterController] = []
	for index: int in 8:
		var fighter := FighterController.new()
		fighter.fighter_id = StringName("crowd-%02d" % index)
		fighter.character_data = player.character_data
		fighter.global_position = Vector2(640, 572)
		root.add_child(fighter)
		fighter.set_physics_process(false)
		fighter.state = FighterController.State.IDLE
		crowd.append(fighter)
	PushboxResolverScript.resolve(crowd)
	for first: int in crowd.size():
		for second: int in range(first + 1, crowd.size()):
			_check(not crowd[first].get_pushbox_rect().intersects(crowd[second].get_pushbox_rect()), "eight-fighter pushbox crowd remained overlapped: %s=%s %s=%s" % [crowd[first].fighter_id, crowd[first].global_position.x, crowd[second].fighter_id, crowd[second].global_position.x])
	for fighter: FighterController in crowd:
		fighter.queue_free()

	for attack: AttackData in player.runtime_profile.move_set.attacks():
		if attack.action_id == &"attack_light" and String(attack.visual_state_id).begins_with("attack_light_combo_") and not attack.is_finisher:
			_check(attack.startup_ticks + attack.active_ticks + attack.recovery_ticks == 22, "non-finisher combo attack is not 22 ticks")
			_check(CombatMath.hitstun_ticks(attack, 1.05, controller.rules) >= 19, "combo hitstun is still too short")
	for link: ComboLinkData in player.runtime_profile.move_set.combo_links:
		_check(link.schema_version == 2 and link.window_start_tick == -2 and link.window_end_tick == 10, "combo buffer window was not migrated")

	scene.queue_free()
	if failures.is_empty():
		print("COMBAT_FEEL_STAGE_V2: PASS")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
