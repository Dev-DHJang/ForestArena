extends SceneTree
const Paths := preload("res://_workspace/nabi-claw-vfx-v2/claw_paths.gd")
var errors: Array[String] = []
var checked := 0
func check(ok: bool, label: String) -> void:
	checked+=1
	if not ok: errors.append(label)
func _initialize() -> void:
	var frames := 0
	var visible := 0
	for motion: String in ["attack_heavy_up","attack_air_heavy","attack_air_light","special_side"]:
		var path := "res://_workspace/motion-naturalness-v1/candidates/remaining/nabi/%s_r06-claw.json" % motion
		var row: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var previous := {}
		for anchors: Dictionary in row.frame_anchors:
			frames+=1
			var trails := Paths.trails(anchors,previous)
			if not anchors.has("claw_tip"):
				check(trails.is_empty(),"occluded tip has no invented effect")
			else:
				visible+=1
				check(trails.size()==3,"visible claw fan has three residual scratches")
				var mirror := Paths.trails(anchors,previous,true)
				for i: int in 3:
					for key: String in ["start","control","control2","tip","central_tip"]:
						var original: Vector2=trails[i][key]
						check(mirror[i][key].is_equal_approx(Vector2(-original.x,original.y)),"every claw knot mirrors exactly once")
				check(trails[1].tip==trails[1].central_tip,"central scratch ends on the actual painted claw")
			previous=anchors
	check(frames==80 and visible==13,"all eighty frames and thirteen visible tips were checked")
	check(Paths.trails({"claw_hand":[60,60],"claw_tip":[129,60]},{}).is_empty(),"invalid cell point is rejected")
	check(Paths.trails({"claw_hand":[60,60],"claw_tip":[60,60]},{}).is_empty(),"collapsed claw cannot invent direction")
	for error: String in errors: push_error(error)
	print("NABI_CLAW_DRAFT: %s (%d checks)" % ["PASS" if errors.is_empty() else "FAIL",checked])
	quit(0 if errors.is_empty() else 1)
