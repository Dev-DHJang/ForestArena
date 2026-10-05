extends SceneTree

const Bot := preload("res://scripts/local_ai_command_source.gd")
const NABI := preload("res://scenes/fighters/nabi_fighter.tscn")
const YURAN := preload("res://scenes/fighters/yu_ran_fighter.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var controller := scene.get_node("MatchController") as MatchController
	controller.set_physics_process(false)
	var third := await _add_fighter(scene, NABI, &"third", &"nabi", Vector2(570, 520))
	var fourth := await _add_fighter(scene, YURAN, &"fourth", &"yu-ran", Vector2(710, 520))
	if third != null and fourth != null:
		_test_team_outcome(controller, third, fourth)
		_test_solo_outcome(controller, third, fourth)
		_test_team_ai_targeting(controller, third, fourth)
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("PHASE6_MULTIFIGHTER_MATCH: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _add_fighter(scene: Node2D, packed: PackedScene, id: StringName, character_id: StringName, position: Vector2) -> FighterController:
	var fighter := packed.instantiate() as FighterController
	fighter.name = id
	fighter.fighter_id = id
	fighter.character_data = (scene.get_node("MatchController") as MatchController).loadout_catalog.character_by_id(character_id)
	fighter.global_position = position
	scene.get_node("World").add_child(fighter)
	await process_frame
	var selection := LoadoutSelection.new()
	selection.character_id = character_id
	var result := LoadoutBuilder.build(selection, (scene.get_node("MatchController") as MatchController).loadout_catalog)
	_check(result.succeeded() and fighter.configure_profile(result.profile), "%s profile setup failed" % id)
	fighter.spawn_position = position
	return fighter


func _configure_team(controller: MatchController, third: FighterController, fourth: FighterController) -> void:
	controller.additional_fighters = [third, fourth]
	controller.local_match_mode = LocalMatchConfig.Mode.TEAM
	controller.team_by_fighter_id = {
		controller.player.fighter_id: &"alpha",
		controller.training_dummy.fighter_id: &"beta",
		third.fighter_id: &"alpha",
		fourth.fighter_id: &"beta",
	}
	controller.reset_match()


func _test_team_outcome(controller: MatchController, third: FighterController, fourth: FighterController) -> void:
	_configure_team(controller, third, fourth)
	var view := controller.snapshot()
	_check(view.fighters.size() == 4, "multifighter snapshot omitted participants")
	_check(StringName(view.fighters[2].team_id) == &"alpha" and StringName(view.fighters[3].team_id) == &"beta", "snapshot omitted team IDs")
	_check(controller.call("_are_allies", controller.player, third), "same-team fighters are not marked as allies")
	_check(not controller.call("_are_allies", controller.player, controller.training_dummy), "different-team fighters are marked as allies")
	controller.training_dummy.state = FighterController.State.DEAD
	fourth.state = FighterController.State.DEAD
	controller.call("_resolve_final_losses")
	_check(controller.winner_team_id == &"alpha" and controller.winner_id == controller.player.fighter_id, "last surviving team did not win")
	_check(controller.player.state == FighterController.State.MATCH_ENDED and third.state == FighterController.State.MATCH_ENDED, "team match end did not freeze surviving fighters")
	_configure_team(controller, third, fourth)
	for fighter: FighterController in [controller.player, controller.training_dummy, third, fourth]:
		fighter.state = FighterController.State.DEAD
	controller.call("_resolve_final_losses")
	_check(controller.is_draw and controller.winner_id.is_empty(), "simultaneous final team loss was not a draw")


func _test_solo_outcome(controller: MatchController, third: FighterController, fourth: FighterController) -> void:
	controller.additional_fighters = [third, fourth]
	controller.local_match_mode = LocalMatchConfig.Mode.SOLO
	controller.team_by_fighter_id = {}
	controller.reset_match()
	for fighter: FighterController in [controller.player, controller.training_dummy, third]:
		fighter.state = FighterController.State.DEAD
	controller.call("_resolve_final_losses")
	_check(controller.winner_id == fourth.fighter_id and controller.winner_team_id.is_empty(), "Solo did not select its last survivor")


func _test_team_ai_targeting(controller: MatchController, third: FighterController, fourth: FighterController) -> void:
	_configure_team(controller, third, fourth)
	controller.player.global_position = Vector2(500, 520)
	controller.training_dummy.global_position = Vector2(1020, 520)
	third.global_position = Vector2(640, 520)
	fourth.global_position = Vector2(760, 520)
	var bot := Bot.new(third.fighter_id, 80, {"team_id": &"alpha"})
	var commands := bot.commands_for_tick(1, controller.snapshot())
	_check(_has_move(commands, CombatIntent.Direction.RIGHT), "team AI targeted the nearer ally instead of an enemy")


func _has_move(commands: Array[CombatIntent], direction: CombatIntent.Direction) -> bool:
	for command: CombatIntent in commands:
		if command.action_id == &"move" and command.direction == direction: return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
