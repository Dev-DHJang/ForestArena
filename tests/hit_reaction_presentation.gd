extends SceneTree
const Presentation := preload("res://scripts/local_fighter_presentation.gd")
var event_sequence := 1000
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
func event(fighter: FighterController, tick: int, result: String = "HIT", epoch: int = 1) -> Dictionary:
	event_sequence += 1
	return {"defender_id": String(fighter.fighter_id), "tick": tick, "result": result, "epoch": epoch, "event_seq": event_sequence}
func dispatch(visual: Node, payload: Dictionary) -> void:
	if visual.has_method("play_combat_event"): visual.play_combat_event(&"hit_resolved",payload)
	else: check(false,"LAN uses existing hit_resolved delivery")
func run() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	root.get_node("ForestArenaAudio").muted = true
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
		visual.name = "Presentation"
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
			# A fresh local reaction reaches its final drawing inside combat stun.
			for tick: int in range(1,new_duration):
				fighter.step_tick(controller.rules)
				observe(visual,fighter,1.0/60.0)
			check(visual.sprite.frame == visual.sprite.sprite_frames.get_frame_count(&"hitstun")-1, "last actionable-lock tick reaches final hit pose")
			fighter.step_tick(controller.rules)
			observe(visual,fighter,1.0/60.0)
			check(fighter.state == FighterController.State.IDLE and visual.requested_motion == &"idle", "real stun expiry immediately returns to idle")
		# LAUNCH must reach its final authored pose within the actual local stun.
		for duration: int in [6,16,22,30]:
			fighter.reset_for_match(controller.rules)
			fighter.position = Vector2(600,300)
			observe(visual,fighter,0)
			fighter.apply_hit(attack,Vector2(0,-180),duration,controller.rules,AttackData.HitReaction.LAUNCH)
			observe(visual,fighter,0)
			check(visual.requested_motion == &"launch" and visual.sprite.frame == 0,"launch starts from first pose")
			var seen := {visual.sprite.frame:true}
			for tick: int in range(1,duration):
				fighter.step_tick(controller.rules)
				observe(visual,fighter,1.0/60.0)
				seen[visual.sprite.frame] = true
				check(fighter.state == FighterController.State.LAUNCH,"presentation never shortens launch stun")
			check(visual.sprite.frame == visual.sprite.sprite_frames.get_frame_count(&"launch")-1,"last local launch tick shows final pose before falling")
			if duration>=16: check(seen.size()==16,"ordinary launch window displays all sixteen authored poses")
			fighter.step_tick(controller.rules)
			observe(visual,fighter,1.0/60.0)
			check(fighter.hitstun_ticks == 0 and visual.requested_motion != &"launch","stun expiry immediately uses the real new state")
		# A forwarded local event describes the same hit and must not restart twice.
		fighter.reset_for_match(controller.rules)
		observe(visual,fighter,0)
		fighter.apply_hit(attack,Vector2.ZERO,30,controller.rules)
		observe(visual,fighter,0)
		for tick: int in 6:
			fighter.step_tick(controller.rules)
			observe(visual,fighter,1.0/60.0)
		var before_local_event := visual.sprite.frame
		dispatch(visual,event(fighter,20))
		observe(visual,fighter,0)
		check(visual.sprite.frame == before_local_event, "local hit signal plus forwarded match event does not restart twice")
		# New LAN data is applied through its real public snapshot method.
		fighter.reset_for_match(controller.rules)
		observe(visual,fighter,0)
		fighter.apply_network_snapshot({"state":"HITSTUN","current_hp":100,"stocks":3})
		observe(visual,fighter,0.3)
		check(visual.sprite.frame > 0, "remote reaction advances before repeated hit")
		var remote_hit := event(fighter,50)
		controller.presentation_event.emit(&"hit_resolved",remote_hit)
		observe(visual,fighter,0)
		check(visual.sprite.frame == 0, "%s existing LAN HIT restarts same reaction from first frame (%d elapsed %.3f)" % [cid,visual.sprite.frame,visual._elapsed])
		observe(visual,fighter,0.2)
		var remote_frame := visual.sprite.frame
		for ignored: Dictionary in [remote_hit,event(fighter,49),event(fighter,51,"BLOCK"),event(fighter,52,"IMMUNE"),event(fighter,53,"ARMOR"),event(fighter,54,"HIT",0)]:
			dispatch(visual,ignored)
			observe(visual,fighter,0)
			check(visual.sprite.frame == remote_frame,"duplicate, old and non-HIT LAN events cannot restart")
		var wrong_target := event(fighter,55)
		wrong_target.defender_id = "someone-else"
		dispatch(visual,wrong_target)
		observe(visual,fighter,0)
		check(visual.sprite.frame == remote_frame,"another defender's hit cannot restart")
		fighter.apply_network_snapshot({"state":"HITSTUN","current_hp":99,"stocks":3})
		controller.snapshot_changed.emit({"tick":80,"fighters":[]})
		dispatch(visual,event(fighter,70))
		observe(visual,fighter,0)
		check(visual.sprite.frame == 0,"delayed unique HIT during current reaction restarts even after newer snapshot")
		for state_name: String in ["IDLE","DEAD","MATCH_ENDED"]:
			fighter.apply_network_snapshot({"state":state_name,"stocks":0 if state_name != "IDLE" else 3})
			observe(visual,fighter,0)
			dispatch(visual,event(fighter,90))
			observe(visual,fighter,0)
			check(visual.requested_motion != &"hitstun", "late LAN HIT cannot replace %s" % state_name)
		for reset_kind: String in ["match","profile"]:
			fighter.reset_for_match(controller.rules)
			fighter.apply_hit(attack,Vector2.ZERO,30,controller.rules)
			observe(visual,fighter,0.1)
			if reset_kind == "match": fighter.reset_for_match(controller.rules)
			else:
				fighter.configure_profile(LoadoutBuilder.build(selection,LocalPlayCatalog.new().combat).profile)
				fighter.set_physics_process(false)
			observe(visual,fighter,0)
			check(visual.requested_motion == &"idle" and visual.sprite.frame == 0,"%s clears pending reaction clock" % reset_kind)
		for reaction: int in [AttackData.HitReaction.LAUNCH,AttackData.HitReaction.KNOCK_DOWN]:
			fighter.reset_for_match(controller.rules)
			observe(visual,fighter,0)
			fighter.apply_hit(attack,Vector2.ZERO,30,controller.rules,reaction)
			observe(visual,fighter,0)
			for tick: int in 6:
				fighter.step_tick(controller.rules)
				observe(visual,fighter,1.0/60.0)
			check(visual.sprite.frame > 0,"airborne or down reaction advances with actual combat ticks")
			fighter.apply_hit(attack,Vector2.ZERO,30,controller.rules,reaction)
			observe(visual,fighter,0)
			check(visual.sprite.frame == 0,"repeated launch or down hit also restarts immediately")
		# HitResolver must not produce a restart for blocked, immune or armored damage.
		var attacker := controller.training_dummy
		for blocked_kind: String in ["guard","immune","armor"]:
			fighter.reset_for_match(controller.rules)
			observe(visual,fighter,0)
			var rule: CombatRuleData
			if blocked_kind == "guard":
				fighter.runtime_state.guarding = true
				fighter.state = FighterController.State.GUARD
			elif blocked_kind == "immune": fighter.invulnerability_ticks = 60
			else:
				rule = CombatRuleData.new()
				rule.kind = CombatRuleData.Kind.SUPER_ARMOR
				fighter.runtime_profile.combat_rules.append(rule)
			var context := HitContext.new(0,attacker,fighter,attack)
			var result := HitResolver.resolve(context,controller.rules)
			var expected := HitResult.Type.BLOCK if blocked_kind == "guard" else (HitResult.Type.IMMUNE if blocked_kind == "immune" else HitResult.Type.ARMOR)
			check(result.type == expected,"real resolver produces %s" % blocked_kind)
			observe(visual,fighter,0)
			check(not visual._reaction_restart_pending and visual.requested_motion != &"hitstun","%s does not start hit artwork" % blocked_kind)
			if rule != null: fighter.runtime_profile.combat_rules.erase(rule)
		# A real guard break still enters HITSTUN and reaches the authored first pose.
		fighter.reset_for_match(controller.rules)
		fighter.runtime_state.guarding = true
		fighter.runtime_state.guard_durability = 1
		fighter.state = FighterController.State.GUARD
		observe(visual,fighter,0)
		attack.guard_damage = 2
		var guard_context := HitContext.new(0,attacker,fighter,attack)
		check(HitResolver.resolve(guard_context,controller.rules).type == HitResult.Type.BLOCK,"real guard break retains BLOCK combat result")
		observe(visual,fighter,0)
		check(fighter.state == FighterController.State.HITSTUN and visual.sprite.frame == 0,"guard break enters first hit pose without a damage signal")
		visual.free()
	scene.queue_free()
	await process_frame
	root.get_node("ForestArenaAudio").shutdown()
	for failure: String in failures: push_error(failure)
	print("HIT_REACTION_RESTART: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
