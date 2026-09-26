extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func run() -> void:
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var controller := scene.get_node("MatchController") as MatchController
	controller.set_physics_process(false)
	var fighter := controller.player
	fighter.current_hp = 1.0
	fighter.ring_out(controller.rules)
	for tick: int in 45: fighter.step_tick(controller.rules)
	check(fighter.current_hp == fighter.runtime_profile.stats.max_hp, "ordinary stock return restores max HP")
	check(fighter.invulnerability_ticks == 60, "ordinary return grants 60 ticks")
	fighter.stocks = 1
	fighter.lose_stock(controller.rules)
	check(fighter.revive(controller.rules, 35.0), "effect schedules return")
	for tick: int in 45: fighter.step_tick(controller.rules)
	check(fighter.current_hp == 35.0 and fighter.runtime_state.pending_respawn_hp == 0.0, "effect HP applied once and pending cleared")
	fighter.stocks = 2
	fighter.lose_stock(controller.rules)
	for tick: int in 45: fighter.step_tick(controller.rules)
	check(fighter.current_hp == fighter.runtime_profile.stats.max_hp, "later ordinary return cannot inherit effect HP")
	fighter.runtime_state.pending_respawn_hp = 35.0
	controller.reset_match()
	check(fighter.runtime_state.pending_respawn_hp == 0.0 and not fighter.runtime_state.revive_used, "new match clears pending and used effect")
	scene.queue_free()
	for failure: String in failures: push_error(failure)
	print("QA_RESPAWN_HP: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
