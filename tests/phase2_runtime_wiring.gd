extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var match: MatchController = main.get_node("MatchController") as MatchController
	var player: FighterController = main.get_node("World/Player") as FighterController
	var dummy: FighterController = main.get_node("World/TrainingDummy") as FighterController
	if match == null or player.runtime_profile == null or dummy.runtime_profile == null:
		push_error("Phase 2 match wiring did not inject complete runtime profiles")
		quit(1)
		return
	if player.runtime_profile.character_id != &"ja-hyun" or dummy.runtime_profile.character_id != &"myo-ryung":
		push_error("Phase 2 default selections changed the main match")
		quit(1)
		return
	print("Phase 2 runtime wiring passed.")
	quit(0)
