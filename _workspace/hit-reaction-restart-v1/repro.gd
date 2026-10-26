extends SceneTree
const Presentation := preload("res://scripts/local_fighter_presentation.gd")
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func observe(visual: Node, fighter: FighterController, delta: float) -> void:
	var before := fighter.snapshot()
	visual.sync_visual(delta)
	check(before == fighter.snapshot(), "presentation leaves complete combat snapshot unchanged")
func run() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	var controller: MatchController = scene.get_node("MatchController")
	controller.set_physics_process(false)
	for cid: StringName in [&"ja-hyun", &"nabi"]:
		var fighter := controller.player
		var selection := LoadoutSelection.new()
		selection.character_id = cid
		check(fighter.configure_profile(LoadoutBuilder.build(selection, LocalPlayCatalog.new().combat).profile), "real profile loads")
		fighter.set_physics_process(false)
		var visual := Presentation.new()
		fighter.add_child(visual)
		visual.set_process(false)
		var attack := fighter.runtime_profile.move_set.attacks()[0].duplicate() as AttackData
		attack.damage = 0
		attack.hit_reaction = AttackData.HitReaction.NORMAL_HIT
		for new_duration: int in [30,10,6]:
			fighter.reset_for_match(controller.rules)
			fighter.position = Vector2(600,572)
			fighter.velocity = Vector2(0,1)
			fighter.move_and_slide()
			check(fighter.is_on_floor(), "real ground contact")
			observe(visual,fighter,0)
			fighter.apply_hit(attack,Vector2.ZERO,16,controller.rules)
			observe(visual,fighter,1.0/60.0)
			for tick: int in 6:
				fighter.step_tick(controller.rules)
				observe(visual,fighter,1.0/60.0)
			check(visual.sprite.frame > 0, "first reaction visibly advances")
			var previous_state := fighter.state
			var serial := fighter.activation_serial
			fighter.apply_hit(attack,Vector2.ZERO,new_duration,controller.rules)
			check(fighter.state == previous_state and fighter.activation_serial == serial, "public repeated hit preserves same state and attacker serial")
			observe(visual,fighter,0)
			check(visual.requested_motion == &"hitstun" and visual.sprite.frame == 0, "%s %d-tick repeated hit restarts on first frame" % [cid,new_duration])
		visual.free()
	scene.queue_free()
	await process_frame
	root.get_node("ForestArenaAudio").shutdown()
	for failure: String in failures: push_error(failure)
	print("HIT_REACTION_RESTART_REPRO: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
