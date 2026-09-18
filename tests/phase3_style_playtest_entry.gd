extends SceneTree

const PLAYTEST_SCENE := "res://scenes/debug/phase3_style_playtest.tscn"
const STYLE_IDS: Array[StringName] = [&"ja-hyun", &"myo-ryung", &"nabi", &"yu-ran"]

var failures: PackedStringArray = []


func _initialize() -> void:
	for style_id: StringName in STYLE_IDS:
		var playtest := (load(PLAYTEST_SCENE) as PackedScene).instantiate()
		playtest.set("style_id", style_id)
		root.add_child(playtest)
		await physics_frame
		await physics_frame
		var match: MatchController = playtest.get("match_controller") as MatchController
		var player: FighterController = playtest.get("player_fighter") as FighterController
		var rival: FighterController = playtest.get("rival_fighter") as FighterController
		_check(match != null, "%s creates a match controller" % style_id)
		_check(player != null and player.runtime_profile != null, "%s creates a player runtime profile" % style_id)
		_check(rival != null and rival.runtime_profile != null, "%s creates a rival runtime profile" % style_id)
		if player != null:
			_check(player.fighter_id == style_id, "%s keeps its authored player ID" % style_id)
		if rival != null:
			_check(rival.fighter_id == &"playtest-rival", "%s gives the rival a distinct debug identity" % style_id)
		playtest.queue_free()
		await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PHASE3_STYLE_PLAYTEST_ENTRY: PASS")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("PHASE3_STYLE_PLAYTEST_ENTRY: FAIL (%d)" % failures.size())
	quit(1)
