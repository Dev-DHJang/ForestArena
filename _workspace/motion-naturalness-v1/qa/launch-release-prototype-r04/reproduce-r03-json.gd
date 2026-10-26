extends SceneTree
const OriginalClock := preload("res://_workspace/motion-naturalness-v1/qa/launch-release-prototype-r01/release-clock.gd")
func _initialize() -> void:
	var original := {"sha256":"original-repro","launch_release_frame_range":[12,16],"launch_release_ticks":4}
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(original))
	var direct_result: Dictionary = OriginalClock.validated(original,16)
	var json_result: Dictionary = OriginalClock.validated(parsed,16)
	print("R03_JSON_DEFECT_REPRODUCTION: direct-integer metadata accepted=%s; parsed-JSON metadata accepted=%s; parsed ticks type=%s; parsed first-index type=%s" % [not direct_result.is_empty(),not json_result.is_empty(),type_string(typeof(parsed.launch_release_ticks)),type_string(typeof(parsed.launch_release_frame_range[0]))])
	if direct_result.is_empty() or not json_result.is_empty():
		push_error("Expected original r03 JSON defect was not reproduced")
		quit(1)
	else:
		print("REPRODUCED: original validator rejects valid integral JSON numbers; this is a preserved defect, not a successful release integration")
		quit(0)
