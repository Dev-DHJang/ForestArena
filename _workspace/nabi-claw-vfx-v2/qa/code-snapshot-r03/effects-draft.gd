extends "res://scripts/fighter_attack_effects.gd"
## Review-only consumer. Production behavior for Ja-hyun and legacy Nabi is inherited.
const ClawPaths := preload("res://_workspace/nabi-claw-vfx-v2/claw_paths.gd")

func has_authored_claws() -> bool:
	for row: Variant in frame_anchors:
		if row is Dictionary and (row.has("claw_hand") or row.has("claw_tip")): return true
	return false

func current_frame_anchors() -> Dictionary:
	var anchors := super.current_frame_anchors()
	for key: String in ["claw_hand", "claw_tip"]:
		if anchors.has(key) and not _valid_pixel_point(anchors[key]): return {}
	return anchors

func claw_afterimages() -> Array[Dictionary]:
	var traces: Array[Dictionary] = []
	if fighter == null or fighter.runtime_profile == null or sprite == null or fighter.active_attack == null: return traces
	var attack := fighter.active_attack
	if String(fighter.runtime_profile.character_id) != "nabi" or attack.schema_version<4: return traces
	if sprite.animation != attack.visual_state_id: return traces
	if fighter.state not in [FighterController.State.ATTACK_ACTIVE,FighterController.State.ATTACK_RECOVERY]: return traces
	if attack.action_id == &"attack_special":
		if not fighter.attack_strike_ready: return traces
	elif attack.action_id != &"attack_heavy" and not (attack.action_id == &"attack_light" and attack.activation_context == AttackData.ActivationContext.AIR):
		return traces
	if not sprite.position.is_finite() or not is_equal_approx(sprite.scale.x,sprite.scale.y): return traces
	var opacity := effect_envelope().y
	if opacity<=0.0: return traces
	var anchors := current_frame_anchors()
	if not _valid_pixel_point(anchors.get("claw_hand")) or not _valid_pixel_point(anchors.get("claw_tip")): return traces
	var previous := {}
	var previous_index := sprite.frame-3
	if previous_index>=0 and previous_index<frame_anchors.size() and frame_anchors[previous_index] is Dictionary:
		previous=frame_anchors[previous_index]
	traces=ClawPaths.trails(anchors,previous,sprite.flip_h,sprite.scale.x)
	for trace: Dictionary in traces:
		for key: String in ["start","control","control2","tip","central_tip"]:
			trace[key]+=sprite.position
		trace.opacity*=opacity
	return traces

func _draw() -> void:
	if fighter == null or fighter.runtime_profile == null or String(fighter.runtime_profile.character_id)!="nabi" or not has_authored_claws():
		super._draw()
		return
	# An authored but hidden/invalid tip never falls back to the old body-centred crescent.
	_meshes.clear()
	for trace: Dictionary in claw_afterimages(): _claw_afterimage(trace)

func _claw_afterimage(trace: Dictionary) -> void:
	for halo: int in 3:
		var mesh := claw_mesh(trace,halo)
		_meshes.append(mesh)
		draw_mesh(mesh,null)

static func claw_mesh(trace: Dictionary, halo: int) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for index: int in 25:
		var u := float(index)/24.0
		var t := lerpf(float(trace.from),float(trace.to),u)
		var center: Vector2=trace.start.bezier_interpolate(trace.control,trace.control2,trace.tip,t)
		var before: Vector2=trace.start.bezier_interpolate(trace.control,trace.control2,trace.tip,maxf(t-0.005,0.0))
		var after: Vector2=trace.start.bezier_interpolate(trace.control,trace.control2,trace.tip,minf(t+0.005,1.0))
		var normal := (after-before).normalized().orthogonal()
		var taper := pow(maxf(0.0,sin(u*PI)),0.8)
		var width: float=float(trace.width)*[1.7,0.75,0.20][halo]*taper
		vertices.append(center+normal*width)
		vertices.append(center-normal*width)
		var color := Color(0.57,0.30,0.90) if halo<2 else Color(0.94,0.90,1.0)
		color.a=float(trace.opacity)*[0.28,0.85,0.92][halo]*taper
		colors.append(color)
		colors.append(color)
		if index>0:
			var v := index*2
			indices.append_array(PackedInt32Array([v-2,v,v+1,v-2,v+1,v-1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
