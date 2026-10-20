extends SceneTree
## Called by the Python regression with an ephemeral _workspace fixture.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("one absolute fixture JSON path is required")
		quit(1)
		return
	var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var errors: Array[String] = []
	var textures: Array[Texture2D] = []
	var frames := preload("res://tools/forest_arena/motion_review_candidate_frames.gd").load_frames(entry, errors, textures)
	for error: String in errors: print(error)
	print("MOTION_CANDIDATE_FRAMES: " + ("PASS" if errors.is_empty() and frames != null else "FAIL"))
	quit(0 if errors.is_empty() and frames != null else 1)
