extends SceneTree
const Presentation := preload("res://scripts/local_fighter_presentation.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if not value: failures.append(label)
func run() -> void:
	var scene: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	var controller: MatchController=scene.get_node("MatchController")
	controller.set_physics_process(false)
	for cid: StringName in [&"ja-hyun",&"nabi"]:
		var fighter:=controller.player
		var selection:=LoadoutSelection.new()
		selection.character_id=cid
		check(fighter.configure_profile(LoadoutBuilder.build(selection,LocalPlayCatalog.new().combat).profile),"current profile builds")
		fighter.set_physics_process(false)
		fighter.position=Vector2(600,572)
		fighter.velocity=Vector2(0,1)
		fighter.move_and_slide()
		check(fighter.is_on_floor(),"actual ground contact for idle recovery")
		var visual:=Presentation.new()
		fighter.add_child(visual)
		visual.set_process(false)
		fighter.state=FighterController.State.FALL
		fighter.velocity.y=200
		visual.sync_visual(1.0)
		check(visual.sprite.sprite_frames.get_frame_count(&"jump")==24,"approved two-fighter jumps load all 24 drawings")
		check(visual.sprite.frame==15,"air descent holds its last airborne drawing before grounded poses16..23")
		fighter.state=FighterController.State.IDLE
		visual.sync_visual(0.24)
		check(visual.sprite.frame==16,"actual landing starts the first approved grounded pose")
		visual.sync_visual(0.0)
		check(visual.sprite.frame==23,"landing reaches the approved standing end within 0.25 seconds")
		fighter.state=FighterController.State.KNOCK_DOWN
		fighter.landing_down_duration_ticks=36
		for remaining: int in range(36,0,-1):
			fighter.landing_down_ticks=remaining
			var before:=fighter.snapshot()
			visual.sync_visual(1.0/60)
			check(visual.sprite.animation==&"knock_down" and visual.sprite.frame>=12,"36-tick landed down always uses grounded lying poses")
			check(before==fighter.snapshot(),"down presentation never changes combat timer")
		check(visual.sprite.frame==15,"down ends at the last lying pose")
		fighter.landing_down_ticks=0
		for remaining: int in range(12,0,-1):
			fighter.wakeup_protection_ticks=remaining
			fighter.state=FighterController.State.WAKE_UP if remaining==12 else FighterController.State.IDLE
			visual.sync_visual(1.0/60)
			check(visual.sprite.animation==&"wake_up","wakeup stays visible after core returns to idle")
		check(visual.sprite.frame==15,"12-tick protection reaches the standing end")
		fighter.state=FighterController.State.RUN
		visual.sync_visual(0)
		check(visual.sprite.animation==&"run","movement can interrupt visual recovery without new action locks")
		fighter.wakeup_protection_ticks=0
		fighter.state=FighterController.State.IDLE
		visual.sync_visual(0)
		check(visual.sprite.animation==&"idle","protection expiry restores ordinary idle")
		visual.free()
	scene.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	print("TWO_FIGHTER_PRESENTATION: "+("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
