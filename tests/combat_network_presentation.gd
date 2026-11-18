extends "res://tests/two_fighter_combat_v2.gd"
const Visual := preload("res://scripts/local_fighter_presentation.gd")
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	super.check(ok,message)

func observe(visual: Node, fighter: FighterController, delta: float) -> void:
	var before := fighter.snapshot()
	visual.sync_visual(delta)
	check(before == fighter.snapshot(),"display never modifies authoritative fighter snapshot")

func run() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	root.get_node("ForestArenaAudio").call("set_levels",0.0,0.0,true,false)
	controller = scene.get_node("MatchController")
	controller.set_physics_process(false)
	controller.bot_source = null
	controller.rules = RULES.duplicate(true)
	catalog = LocalPlayCatalog.new().combat
	for cid: StringName in [&"ja-hyun",&"nabi"]:
		setup(cid)
		var fighter := controller.player
		var visual := Visual.new()
		fighter.add_child(visual)
		visual.set_process(false)
		var attack := attack_by_action(fighter,&"attack_light")
		for fps: int in [30,60,120]:
			fighter.reset_for_match(controller.rules)
			observe(visual,fighter,0)
			var sample := {"state":"ATTACK_STARTUP","attack_id":String(attack.attack_id),"attack_phase_tick":0,"on_floor":true}
			fighter.apply_network_snapshot(sample)
			observe(visual,fighter,0)
			var initial_frame: int = visual.sprite.frame
			for frame: int in fps / 10: observe(visual,fighter,1.0/fps)
			check(visual.effects.presentation_phase_tick == 3,"body and effects use the same capped display clock")
			check(visual.sprite.frame > initial_frame,"%s %dfps progresses between 20Hz packets"%[cid,fps])
			check(fighter.state == FighterController.State.ATTACK_STARTUP and fighter.attack_phase_tick==0,"interpolation never advances combat")
			var capped_frame: int = visual.sprite.frame
			observe(visual,fighter,5.0)
			check(visual.sprite.frame == capped_frame,"packet loss caps extrapolation at one receive interval")
			fighter.apply_network_snapshot(sample)
			observe(visual,fighter,0)
			check(visual.sprite.frame==capped_frame,"duplicate packet cannot rewind a pose")
			sample.attack_phase_tick = 6
			fighter.apply_network_snapshot(sample)
			observe(visual,fighter,0)
			observe(visual,fighter,1.0)
			check(visual.sprite.frame<=3 and fighter.state==FighterController.State.ATTACK_STARTUP,"last startup drawing waits for received active state")
			fighter.apply_network_snapshot({"state":"HITSTUN","hitstun_ticks":30,"on_floor":true})
			observe(visual,fighter,0)
			initial_frame = visual.sprite.frame
			for frame: int in fps / 10: observe(visual,fighter,1.0/fps)
			check(visual.sprite.frame>initial_frame,"remaining-stun packets advance smoothly between arrivals")
			# A repeated hit event can precede its timer snapshot over LAN.
			visual.play_combat_event(&"hit_resolved",{"epoch":fps,"event_seq":1,"tick":10,"defender_id":String(fighter.fighter_id),"result":"HIT"})
			observe(visual,fighter,0)
			check(visual.sprite.frame==0,"LAN repeated hit restarts on first drawing after interpolation")
			observe(visual,fighter,0.05)
			check(visual.sprite.frame==0,"old remaining timer cannot advance a new impact")
			fighter.apply_network_snapshot({"state":"HITSTUN","hitstun_ticks":27,"on_floor":true})
			observe(visual,fighter,0)
			for frame: int in fps / 10: observe(visual,fighter,1.0/fps)
			var hit_frame: int = visual.sprite.frame
			check(hit_frame>0,"new hit timer advances after first snapshot")
			visual.play_combat_event(&"hit_resolved",{"epoch":fps,"event_seq":1,"tick":10,"defender_id":String(fighter.fighter_id),"result":"HIT"})
			observe(visual,fighter,0)
			check(visual.sprite.frame==hit_frame,"duplicate HIT does not restart or rewind")
			fighter.apply_network_snapshot({"state":"IDLE","on_floor":true})
			observe(visual,fighter,0)
			check(visual.requested_motion==&"idle","received unlocked state replaces reaction immediately")
		# Grounded finisher shows falling poses, then prone, then waking up.
		fighter.reset_for_match(controller.rules)
		fighter.position=Vector2(600,572)
		fighter.velocity=Vector2(0,1)
		fighter.move_and_slide()
		observe(visual,fighter,0)
		var finisher: AttackData
		for entry: AttackData in fighter.attacks:
			if entry.is_finisher and entry.activation_context==AttackData.ActivationContext.GROUND: finisher=entry
		fighter.apply_hit(finisher,Vector2(100,0),36,controller.rules)
		observe(visual,fighter,0)
		check(visual.requested_motion==&"knock_down" and visual.sprite.frame==0,"ground down starts with authored fall, not prone teleport")
		for tick: int in 35:
			fighter.step_tick(controller.rules)
			observe(visual,fighter,1.0/60.0)
		check(visual.sprite.frame==visual.sprite.sprite_frames.get_frame_count(&"knock_down")-1,"ground down reaches final prone pose")
		fighter.step_tick(controller.rules)
		observe(visual,fighter,0)
		check(visual.requested_motion==&"wake_up" and visual.sprite.frame==0,"wakeup starts at its first pose")
		fighter.consume_intent(intent(fighter,&"attack_light"),controller.rules)
		observe(visual,fighter,0)
		check(visual.requested_motion==attack.visual_state_id,"new attack replaces wakeup immediately")
		visual.queue_free()
		await process_frame
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("COMBAT_NETWORK_PRESENTATION: PASS (%d checks)"%checks)
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)
