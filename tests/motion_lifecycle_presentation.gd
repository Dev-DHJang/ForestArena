extends SceneTree
## Real stock/respawn paths; presentation never extends a combat state.
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
	check(before == fighter.snapshot(), "lifecycle artwork leaves the complete combat snapshot unchanged")

func run() -> void:
	var catalog := LocalPlayCatalog.new().combat
	var rules := load("res://assets/combat/two_fighter_combat_rules.tres") as CombatRules
	for cid: StringName in [&"ja-hyun", &"nabi"]:
		var fighter := FighterController.new()
		fighter.character_data = catalog.character_by_id(cid)
		fighter.fighter_id = &"lifecycle-fixture"
		root.add_child(fighter)
		var selection := LoadoutSelection.new()
		selection.character_id = cid
		check(fighter.configure_profile(LoadoutBuilder.build(selection,catalog).profile), "actual fighter profile loads")
		fighter.set_physics_process(false)
		fighter.reset_for_match(rules)
		var visual := Presentation.new()
		fighter.add_child(visual)
		visual.set_process(false)
		for repeat: int in 2:
			fighter.stocks = 2
			check(fighter.ring_out(rules), "public stock loss begins ring-out")
			observe(visual, fighter, 1.0/60.0)
			check(visual.requested_motion == &"ring_out", "stock loss shows the ring-out drawing")
			for tick: int in rules.respawn_delay_ticks:
				fighter.step_tick(rules)
				observe(visual, fighter, 1.0/60.0)
			check(fighter.state == FighterController.State.IDLE and fighter.current_hp > 0, "real respawn is immediately actionable IDLE")
			check(visual.requested_motion == &"spawn" and visual.sprite.frame == 0, "actual ring-out to respawn begins the entrance artwork")
			if repeat == 0:
				observe(visual, fighter, 2.0)
				observe(visual, fighter, 0.0)
				check(visual.requested_motion == &"idle", "entrance artwork returns to idle after its declared duration")
			else:
				fighter.state = FighterController.State.RUN
				observe(visual, fighter, 1.0/60.0)
				check(visual.requested_motion == &"run", "movement interrupts entrance artwork immediately")
				fighter.state = FighterController.State.IDLE
				observe(visual, fighter, 0.0)
		for reset_kind: String in ["match", "profile"]:
			fighter.stocks = 2
			fighter.ring_out(rules)
			observe(visual, fighter, 1.0/60.0)
			for tick: int in rules.respawn_delay_ticks:
				fighter.step_tick(rules)
				observe(visual, fighter, 1.0/60.0)
			observe(visual, fighter, 0.4)
			check(visual.requested_motion == &"spawn" and visual.sprite.frame > 0, "reset fixture starts midway through a real entrance")
			if reset_kind == "match": fighter.reset_for_match(rules)
			else:
				check(fighter.configure_profile(LoadoutBuilder.build(selection,catalog).profile), "same-character replacement profile loads")
				fighter.set_physics_process(false)
			observe(visual, fighter, 0.0)
			check(visual.requested_motion == &"idle" and visual.sprite.frame == 0, "fresh %s clears the previous match entrance timer" % reset_kind)
		fighter.stocks = 0
		fighter.state = FighterController.State.MATCH_ENDED
		observe(visual, fighter, 1.0/60.0)
		check(visual.requested_motion == &"death", "final eliminated fighter keeps death artwork after match resolution")
		check(visual.sprite.modulate == Color.WHITE, "ended match cannot freeze a leftover respawn transparency on death")
		observe(visual, fighter, 2.0)
		check(visual.sprite.frame == visual.sprite.sprite_frames.get_frame_count(&"death")-1, "death reaches and holds its final drawing")
		fighter.stocks = 1
		fighter.active_attack = fighter.runtime_profile.move_set.attacks()[0]
		observe(visual, fighter, 1.0/60.0)
		check(visual.requested_motion == &"idle", "surviving fighter returns to idle even if the ended simulation retains an attack")
		fighter.free()
	for failure: String in failures: push_error(failure)
	print("MOTION_LIFECYCLE_PRESENTATION: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
