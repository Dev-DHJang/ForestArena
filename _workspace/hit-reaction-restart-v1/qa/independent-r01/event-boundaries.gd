extends SceneTree
const Presentation = preload("res://scripts/local_fighter_presentation.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func event(fighter: FighterController, epoch: int, sequence: int, tick: int) -> Dictionary:
	return {"epoch":epoch,"event_seq":sequence,"tick":tick,"defender_id":String(fighter.fighter_id),"result":"HIT"}
func run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.get_node("ForestArenaAudio").muted = true
	await physics_frame
	var match_node: MatchController = main.get_node("MatchController")
	match_node.set_physics_process(false)
	var fighter := match_node.player
	fighter.set_physics_process(false)
	var visual := Presentation.new()
	fighter.add_child(visual)
	visual.set_process(false)
	# Use real network snapshot application, then the same match signal used by
	# local_ai_app._on_lan_presentation_event. No private restart method is called.
	fighter.apply_network_snapshot({"state":"HITSTUN","stocks":3})
	visual.sync_visual(0.25)
	check(visual.sprite.frame > 0,"remote existing hit pose advances")
	var first := event(fighter,7,100,40)
	var before := fighter.snapshot()
	match_node.presentation_event.emit(&"hit_resolved",first)
	visual.sync_visual(0)
	check(visual.sprite.frame == 0,"real main event forwarding restarts")
	check(before == fighter.snapshot(),"event forwarding leaves complete snapshot unchanged")
	visual.sync_visual(0.25)
	var old_frame: int = visual.sprite.frame
	# Duplicate at a later wall-clock point is still the same event.
	match_node.presentation_event.emit(&"hit_resolved",first)
	visual.sync_visual(0)
	check(visual.sprite.frame == old_frame,"same event cannot restart twice")
	match_node.presentation_event.emit(&"hit_resolved",event(fighter,7,101,40))
	visual.sync_visual(0)
	check(visual.sprite.frame == 0,"two distinct hits in the same tick restart separately")
	visual.sync_visual(0.25)
	# New round starts with a lower tick and sequence, as reset_match actually does.
	match_node.presentation_event.emit(&"hit_resolved",event(fighter,8,1,0))
	visual.sync_visual(0)
	check(visual.sprite.frame == 0,"new epoch accepts lower sequence and tick")
	visual.sync_visual(0.25)
	old_frame = visual.sprite.frame
	for stale: Dictionary in [event(fighter,7,10000,900),event(fighter,8,1,0),event(fighter,8,2,-1)]:
		match_node.presentation_event.emit(&"hit_resolved",stale)
		visual.sync_visual(0)
		check(visual.sprite.frame == old_frame,"old epoch, duplicate or decreasing tick does not restart")
	# Event first, then snapshot: the server broadcasts hit events inside its tick
	# and snapshots after the tick. An idle client must not invent a hit state.
	fighter.apply_network_snapshot({"state":"IDLE","stocks":3})
	visual.sync_visual(0)
	match_node.presentation_event.emit(&"hit_resolved",event(fighter,8,3,3))
	visual.sync_visual(0)
	check(visual.requested_motion == &"idle","early HIT event does not invent combat state")
	fighter.apply_network_snapshot({"state":"HITSTUN","stocks":3})
	visual.sync_visual(0)
	check(visual.requested_motion == &"hitstun" and visual.sprite.frame == 0,"subsequent real snapshot enters first hit pose")
	visual.sync_visual(0.25)
	match_node.presentation_event.emit(&"hit_resolved",event(fighter,8,4,4))
	visual.sync_visual(0)
	check(visual.sprite.frame == 0,"next server event restarts already-playing remote hit")
	check(before == fighter.snapshot(),"remote replay sequences leave combat snapshot invariant")
	main.queue_free()
	await process_frame
	root.get_node("ForestArenaAudio").shutdown()
	for failure: String in failures: push_error(failure)
	print("HIT_EVENT_BOUNDARIES: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
