extends SceneTree
## Independent code-only boundary checks. Product and producer fixtures stay fixed.
const Presentation := preload("res://_workspace/motion-naturalness-v1/qa/launch-transition-proposal-r01/presentation-proposed.gd")
const OUTPUT := "res://_workspace/motion-naturalness-v1/qa/launch-transition-proposal-r01/independent-boundaries-r01.json"
var failures: Array[String] = []
var rows: Array[Dictionary] = []
var checks := 0
var sequence := 10000

func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func combat_value(fighter: FighterController) -> Dictionary:
	var runtime := {}
	for property: Dictionary in fighter.runtime_state.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			runtime[property.name] = fighter.runtime_state.get(property.name)
	return {"snapshot":fighter.snapshot(),"runtime_all_fields":runtime,"exact_position":fighter.position,"exact_velocity":fighter.velocity,"activation_serial":fighter.activation_serial,"active_attack":fighter.active_attack,"buffered_intent":fighter.buffered_intent,"hitstun_ticks":fighter.hitstun_ticks}

func observe(visual: Node, fighter: FighterController, delta: float) -> void:
	var before := combat_value(fighter)
	visual.sync_visual(delta)
	check(before == combat_value(fighter),"display preserves runtime fields, exact geometry, remaining stun and snapshot")

func remote_hit(visual: Node, fighter: FighterController) -> void:
	sequence += 1
	visual.play_combat_event(&"hit_resolved",{"defender_id":String(fighter.fighter_id),"tick":sequence,"event_seq":sequence,"epoch":5,"result":"HIT"})

func run() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	root.get_node("ForestArenaAudio").muted = true
	await physics_frame
	var controller: MatchController = scene.get_node("MatchController")
	controller.set_physics_process(false)
	# Main scene defaults are legacy rules; the two-character product enables
	# landing knockdown through this actual rules Resource.
	controller.rules = (load("res://assets/combat/two_fighter_combat_rules.tres") as CombatRules).duplicate(true)
	for cid: StringName in [&"ja-hyun",&"nabi"]:
		var fighter := controller.player
		var selection := LoadoutSelection.new()
		selection.character_id = cid
		var profile := LoadoutBuilder.build(selection,LocalPlayCatalog.new().combat).profile
		check(fighter.configure_profile(profile),"actual profile loads "+String(cid))
		fighter.set_physics_process(false)
		var visual := Presentation.new()
		fighter.add_child(visual)
		visual.set_process(false)
		var attack := fighter.runtime_profile.move_set.attacks()[0].duplicate(true) as AttackData
		attack.damage = 0
		attack.hit_reaction = AttackData.HitReaction.LAUNCH
		for duration: int in [6,24,30]:
			fighter.reset_for_match(controller.rules)
			fighter.position = Vector2(600,300)
			observe(visual,fighter,0)
			fighter.apply_hit(attack,Vector2(0,-180),30,controller.rules)
			observe(visual,fighter,0)
			for tick: int in 6:
				fighter.step_tick(controller.rules)
				observe(visual,fighter,1.0/60)
			check(fighter.hitstun_ticks == 24 and visual.sprite.frame > 0,"launch30 has exactly24 ticks left after6 combat ticks")
			var serial := fighter.activation_serial
			fighter.apply_hit(attack,Vector2(0,-180),duration,controller.rules)
			observe(visual,fighter,0)
			check(fighter.activation_serial == serial,"defender rehit does not require attacker activation serial")
			check(visual.requested_motion == &"launch" and visual.sprite.frame == 0 and visual._reaction_duration_ticks == duration,"shorter/equal/longer repeated launch reenters F1 with new actual duration")
			var seen: Array[int] = [visual.sprite.frame]
			for tick: int in range(1,duration):
				fighter.step_tick(controller.rules)
				observe(visual,fighter,1.0/60)
				seen.append(visual.sprite.frame)
				check(fighter.state == FighterController.State.LAUNCH and fighter.hitstun_ticks == duration-tick,"display does not expire repeated launch early")
			check(visual.sprite.frame == visual.sprite.sprite_frames.get_frame_count(&"launch")-1,"last remaining launch tick reaches last authored pose")
			fighter.step_tick(controller.rules)
			observe(visual,fighter,0)
			check(fighter.hitstun_ticks == 0 and visual.requested_motion != &"launch" and visual._reaction_duration_ticks == 0,"expiry immediately follows combat state and clears clock")
			rows.append({"character":String(cid),"case":"launch30-six-ticks-rehit","new_duration":duration,"frames_zero_based":seen,"state_after_expiry":FighterController.State.keys()[fighter.state]})
		# Real public snapshot has no remaining stun: no synthetic duration is added.
		fighter.reset_for_match(controller.rules)
		observe(visual,fighter,0)
		var network := {"state":"LAUNCH","current_hp":100,"stocks":3,"position":{"x":600,"y":300},"velocity":{"x":0,"y":100}}
		check(not network.has("hitstun_ticks") and not fighter.snapshot().has("hitstun_ticks"),"current snapshot contract has no remaining stun field")
		fighter.apply_network_snapshot(network)
		observe(visual,fighter,0)
		check(visual.requested_motion == &"launch" and visual._reaction_duration_ticks == 0 and visual.sprite.frame == 0,"LAN launch starts with no invented duration")
		observe(visual,fighter,0.3)
		check(visual.sprite.frame > 0 and visual._reaction_duration_ticks == 0,"LAN launch advances by authored FPS fallback")
		var before_remote := visual.sprite.frame
		remote_hit(visual,fighter)
		observe(visual,fighter,0)
		check(visual.sprite.frame == 0 and visual._reaction_duration_ticks == 0,"new LAN HIT reenters launch F1 without combat duration")
		observe(visual,fighter,0.2)
		check(visual.sprite.frame > 0,"restarted LAN launch advances")
		fighter.apply_network_snapshot({"state":"FALL","stocks":3,"velocity":{"x":0,"y":100}})
		observe(visual,fighter,0)
		check(visual.requested_motion == &"jump" and visual._reaction_duration_ticks == 0,"FALL snapshot immediately displays jump and clears reaction clock")
		rows.append({"character":String(cid),"case":"LAN-launch-zero-duration-HIT-FALL","frame_before_HIT":before_remote,"FALL_motion":String(visual.requested_motion)})
		# Actual launch landing/KO/reset must retain their independent clocks.
		fighter.reset_for_match(controller.rules)
		fighter.position = Vector2(600,500)
		observe(visual,fighter,0)
		attack.landing_knockdown = true
		fighter.apply_hit(attack,Vector2(0,180),30,controller.rules)
		observe(visual,fighter,0)
		var landed := false
		for tick: int in 90:
			fighter.step_tick(controller.rules)
			observe(visual,fighter,1.0/60)
			if fighter.landing_down_ticks > 0:
				landed = true
				break
		check(landed and fighter.landing_down_ticks == 18 and visual.requested_motion == &"knock_down","real landing starts existing18 tick knockdown")
		for tick: int in 17:
			fighter.step_tick(controller.rules)
			observe(visual,fighter,1.0/60)
		check(fighter.landing_down_ticks == 1 and visual.sprite.frame == visual.sprite.sprite_frames.get_frame_count(&"knock_down")-1,"landing down reaches last pose at final locked tick")
		fighter.step_tick(controller.rules)
		observe(visual,fighter,0)
		check(fighter.state == FighterController.State.WAKE_UP and fighter.wakeup_protection_ticks == 12 and visual.requested_motion == &"wake_up" and visual.sprite.frame == 0,"existing12 tick wakeup clock starts immediately")
		attack.landing_knockdown = false
		for stocks: int in [1,2]:
			fighter.reset_for_match(controller.rules)
			fighter.position = Vector2(600,300)
			observe(visual,fighter,0)
			fighter.apply_hit(attack,Vector2(0,-180),30,controller.rules)
			observe(visual,fighter,0)
			fighter.stocks = stocks
			var lethal := attack.duplicate(true) as AttackData
			lethal.damage = fighter.current_hp+1
			fighter.apply_hit(lethal,Vector2.ZERO,30,controller.rules)
			observe(visual,fighter,0)
			check(fighter.state == (FighterController.State.DEAD if stocks == 1 else FighterController.State.RING_OUT),"lethal hit preserves death/ringout combat state")
			check(visual.requested_motion == (&"death" if stocks == 1 else &"ring_out") and visual._reaction_duration_ticks == 0 and not visual._reaction_restart_pending,"KO supersedes launch and clears display duration")
		for reset_kind: String in ["match","profile"]:
			fighter.reset_for_match(controller.rules)
			fighter.apply_hit(attack,Vector2.ZERO,30,controller.rules)
			observe(visual,fighter,0.1)
			if reset_kind == "match": fighter.reset_for_match(controller.rules)
			else:
				fighter.configure_profile(profile)
				fighter.set_physics_process(false)
			observe(visual,fighter,0)
			check(visual.requested_motion == &"idle" and visual.sprite.frame == 0 and visual._reaction_duration_ticks == 0 and not visual._reaction_restart_pending and visual._local_hit_events_pending == 0,"launch "+reset_kind+" reset clears pending display clocks")
		visual.free()
	scene.queue_free()
	await process_frame
	root.get_node("ForestArenaAudio").shutdown()
	var file := FileAccess.open(OUTPUT,FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"pass" if failures.is_empty() else "fix","checks":checks,"failures":failures,"cases":rows,"scope":"code-only; fixed proposal clone, real public apply_hit/snapshot and fixed combat steps; no pixel or device claim"},"\t")+"\n")
	for failure: String in failures: push_error(failure)
	print("INDEPENDENT_LAUNCH_BOUNDARIES: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
