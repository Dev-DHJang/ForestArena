extends Node2D
## Read-only cloth and claw trails. Hit detection remains in FighterController.
const SCARF_TEXTURE_ID := "fa.ui.menu.v07.character.ja-hyun"
# The fallback coordinates below were inspected only on these exact drawings.
const LEGACY_ANCHOR_HASHES := {
	&"attack_air_heavy": "7099bc4b8d712d55fe3f02aa32fa45a968ded610d2e38941676d76d0548053f7",
	&"special_scarf_sweep": "60154607d07cfc1c948af936f5783541c722e5fec410c2224b4986a007912928",
	&"special_neutral": "681d4d2d977da5a8741696d81de7d85b076457b0bebc2086232a1d27ef280b3a",
	&"attack_air_light": "6ef21a90fdad3abf51c719870dcb04bf18bc0499309ddd1bbb9a50d443149bca",
}
# Cross-sections of the ACTUAL worn left scarf in the approved concept (1086×1448).
# UVs sample the blue cloth, white print and charcoal tip; no new scarf artwork.
const SCARF_LEFT := [Vector2(270,535), Vector2(220,543), Vector2(153,565), Vector2(95,603), Vector2(53,658), Vector2(80,704)]
const SCARF_RIGHT := [Vector2(278,548), Vector2(221,550), Vector2(175,582), Vector2(148,625), Vector2(125,682), Vector2(113,742)]
# Pixel anchors belong to the displayed 128px cells, not combat coordinates.
const AIR_HAND := [Vector2(61,29),Vector2(62,32),Vector2(69,22),Vector2(71,23),Vector2(69,79),Vector2(68,78),Vector2(69,85),Vector2(74,87),Vector2(69,94),Vector2(69,93),Vector2(53,45),Vector2(47,47),Vector2(58,38),Vector2(60,41),Vector2(50,55),Vector2(51,58)]
const SWEEP_COLLAR := [Vector2(58,84),Vector2(58,84),Vector2(58,84),Vector2(61,85),Vector2(53,84),Vector2(59,84),Vector2(60,87),Vector2(66,88),Vector2(61,86),Vector2(59,85),Vector2(57,84),Vector2(59,86),Vector2(59,85),Vector2(58,85),Vector2(58,85),Vector2(58,85)]
const SWEEP_TIPS := [[Vector2(38,95),Vector2(68,94)],[Vector2(38,97),Vector2(80,99)],[Vector2(45,102),Vector2(37,71)],[Vector2(35,73),Vector2(95,70)],[Vector2(10,94),Vector2(112,84)],[Vector2(43,85),Vector2(90,106)],[Vector2(27,94),Vector2(90,109)],[Vector2(37,87),Vector2(39,106)],[Vector2(36,67),Vector2(94,69)],[Vector2(25,70),Vector2(94,73)],[Vector2(13,81),Vector2(107,88)],[Vector2(33,80),Vector2(91,95)],[Vector2(27,65),Vector2(104,65)],[Vector2(43,95),Vector2(81,95)],[Vector2(38,95),Vector2(70,94)],[Vector2(38,95),Vector2(70,94)]]
var fighter: FighterController
var sprite: AnimatedSprite2D
# Supplied by the read-only presentation for the exact hashed artwork entry.
var frame_anchors: Array = []
var artwork_sha256 := ""
var _scarf: Texture2D
# Canvas commands hold RIDs: retain mesh resources until the next redraw.
var _meshes: Array[ArrayMesh] = []

func _process(_delta: float) -> void:
	queue_redraw()

func effect_envelope() -> Vector2:
	# x: normalised sweep time; y: opacity. Recovery has a brief diminishing tail.
	if fighter == null or fighter.active_attack == null: return Vector2.ZERO
	var attack := fighter.active_attack
	match fighter.state:
		FighterController.State.ATTACK_STARTUP:
			return Vector2(float(fighter.attack_phase_tick) / maxi(attack.startup_ticks, 1), 0.65)
		FighterController.State.ATTACK_ACTIVE:
			return Vector2(float(fighter.attack_phase_tick) / maxi(attack.active_ticks - 1, 1), 1.0)
		FighterController.State.ATTACK_RECOVERY:
			return Vector2(1.0, maxf(0.0, 1.0 - float(fighter.attack_phase_tick) / 7.0))
	return Vector2.ZERO

func _anchor(pixel: Vector2) -> Vector2:
	if sprite == null: return Vector2(-10 * fighter.facing, -44)
	var point := pixel - Vector2(64,64)
	if sprite.flip_h: point.x = -point.x
	return sprite.position + point * sprite.scale

func current_frame_anchors() -> Dictionary:
	if sprite == null or sprite.sprite_frames == null: return {}
	var count := sprite.sprite_frames.get_frame_count(sprite.animation)
	if frame_anchors.size() == count and sprite.frame < frame_anchors.size():
		var row: Variant = frame_anchors[sprite.frame]
		if row is Dictionary:
			for key: String in ["scarf_root", "scarf_hand"]:
				if row.has(key) and not _valid_pixel_point(row[key]): return {}
			if row.has("scarf_tips"):
				var tips: Variant = row.scarf_tips
				if not tips is Array or tips.size() != 2: return {}
				for tip: Variant in tips:
					if not _valid_pixel_point(tip): return {}
			return row
	# These coordinates were inspected on the old 16-frame sheets only. Never
	# clamp a 24/32-frame drawing to frame 15 of a different pose sequence.
	if count != 16 or not frame_anchors.is_empty() or artwork_sha256.is_empty() or LEGACY_ANCHOR_HASHES.get(sprite.animation) != artwork_sha256: return {}
	var frame := sprite.frame
	if sprite.animation == &"attack_air_heavy":
		return {"scarf_hand": [AIR_HAND[frame].x, AIR_HAND[frame].y]}
	if sprite.animation == &"special_scarf_sweep":
		return {"scarf_root": [SWEEP_COLLAR[frame].x, SWEEP_COLLAR[frame].y], "scarf_tips": [[SWEEP_TIPS[frame][0].x,SWEEP_TIPS[frame][0].y], [SWEEP_TIPS[frame][1].x,SWEEP_TIPS[frame][1].y]]}
	return {"scarf_root": [54,88]}

static func _pixel_point(value: Variant) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

static func _valid_pixel_point(value: Variant) -> bool:
	if not value is Array or value.size() != 2: return false
	for coordinate: Variant in value:
		if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)): return false
	return true

func _draw() -> void:
	_meshes.clear()
	if fighter == null or fighter.active_attack == null or fighter.runtime_profile == null: return
	var attack := fighter.active_attack
	if attack.schema_version < 4: return
	# A pending/missing pose must not attach cloth to the fallback idle artwork.
	if sprite != null and sprite.animation != attack.visual_state_id: return
	var envelope := effect_envelope()
	if envelope.y <= 0.0: return
	var preparing := fighter.state == FighterController.State.ATTACK_STARTUP
	var recovering := fighter.state == FighterController.State.ATTACK_RECOVERY
	var sign_x := float(fighter.facing)
	var id := String(fighter.runtime_profile.character_id)
	var progress := envelope.x
	if id == "ja-hyun":
		if _scarf == null: _scarf = get_node("/root/ForestArenaResources").load_texture(SCARF_TEXTURE_ID)
		var anchors := current_frame_anchors()
		if anchors.is_empty(): return
		var root_point := _anchor(_pixel_point(anchors.get("scarf_root", [54,88])))
		if attack.action_id == &"attack_special":
			# Extend the two worn tails along their current painted pose, rather than
			# adding independent ribbons. Preparation uses the original cloth alone.
			if preparing or not anchors.has("scarf_root") or not anchors.has("scarf_tips"): return
			root_point = _anchor(_pixel_point(anchors.scarf_root))
			for tail: int in 2:
				var painted_tip := _anchor(_pixel_point(anchors.scarf_tips[tail]))
				var direction := painted_tip-root_point
				var up_pose := sprite.frame in [3,8,9,12] if frame_anchors.is_empty() else direction.y < -absf(direction.x) * 0.6
				var side := -1.0 if direction.x < 0 else 1.0
				var offset := Vector2(side * (115.0 if up_pose else 226.0), -235.0 if up_pose else -12.0)
				var reach := 0.35 + 0.65*envelope.y if recovering else 1.0
				var control := root_point + direction * 2.0
				_cloth(root_point,control,root_point+offset*reach,envelope.y,0.9 if tail == 0 else 0.75)
		elif attack.action_id == &"attack_heavy" and attack.activation_context == AttackData.ActivationContext.AIR:
			if preparing or not anchors.has("scarf_hand"): return
			# The one tail held by the attacking hand continues the drawn downward
			# sweep. Its other worn tail remains the original character artwork.
			root_point = _anchor(_pixel_point(anchors.scarf_hand))
			var sweep := progress
			var tip := root_point + Vector2(lerpf(145,76,sweep)*sign_x,lerpf(-42,120,sweep))
			var control := root_point + Vector2(100*sign_x,lerpf(-96,18,sweep))
			_cloth(root_point,control,tip,envelope.y,0.90)
		elif attack.action_id == &"attack_heavy" or (attack.action_id == &"attack_light" and attack.activation_context == AttackData.ActivationContext.AIR):
			if not anchors.has("scarf_root"): return
			var reach := attack.hitbox_offset.x + attack.hitbox_size.x * 0.40
			var tip := Vector2(reach * sign_x, -36)
			var extension := 0.3 + progress * 0.7 if preparing else 1.0
			_cloth(root_point, root_point + Vector2(80*sign_x,-45), root_point.lerp(tip,extension), envelope.y, 0.85)
	elif id == "nabi":
		if attack.action_id == &"attack_heavy":
			# Anticipation is in the hand pose. The crescent starts with the actual swing.
			if not preparing: _uppercut(progress, envelope.y)
		elif not preparing and (attack.activation_context == AttackData.ActivationContext.AIR or (attack.action_id == &"attack_special" and fighter.attack_strike_ready)):
			var strike_progress := progress
			if attack.action_id == &"attack_special":
				strike_progress = clampf(float(fighter.attack_phase_tick - (attack.active_ticks - 4)) / 3.0,0.0,1.0) if not recovering else 1.0
			_slash(Vector2(38*sign_x,-48), strike_progress, envelope.y)

func _cloth(start: Vector2, control: Vector2, tip: Vector2, opacity: float, width_scale: float) -> void:
	if _scarf == null: return
	var texture_size := _scarf.get_size()
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var left_edge := PackedVector2Array()
	var right_edge := PackedVector2Array()
	for index: int in 33:
		var t := float(index) / 32.0
		var center := start.bezier_interpolate(control, control.lerp(tip,0.65), tip,t)
		var next_t := minf(1.0,t+0.01)
		var previous_t := maxf(0.0,t-0.01)
		var tangent := start.bezier_interpolate(control,control.lerp(tip,0.65),tip,next_t) - start.bezier_interpolate(control,control.lerp(tip,0.65),tip,previous_t)
		var normal := tangent.normalized().orthogonal()
		# Flat fabric with broad belly, twisting folds and a sharply cut cloth end.
		var width := (4.0 + 7.5 * sin(t*PI*0.88)) * width_scale
		width *= 0.62 + 0.38 * absf(cos(t*PI*1.6 + fighter.attack_phase_tick*0.10))
		if t > 0.92: width *= (1.0-t)/0.08
		var l := center + normal * width
		var r := center - normal * width
		var section := minf(t*5,4.9999)
		var k := int(section)
		var uv_l: Vector2 = SCARF_LEFT[k].lerp(SCARF_LEFT[k+1],section-k) / texture_size
		var uv_r: Vector2 = SCARF_RIGHT[k].lerp(SCARF_RIGHT[k+1],section-k) / texture_size
		vertices.append(l); vertices.append(r)
		uvs.append(uv_l); uvs.append(uv_r)
		var shade := 0.84 + 0.16 * sin(t*PI*3.0)
		colors.append(Color(shade,shade,shade,opacity)); colors.append(Color(shade,shade,shade,opacity))
		left_edge.append(l); right_edge.append(r)
		if index > 0:
			var v := index*2
			indices.append_array(PackedInt32Array([v-2,v,v+1,v-2,v+1,v-1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_COLOR]=colors; arrays[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_meshes.append(mesh)
	draw_mesh(mesh,_scarf)
	draw_polyline(left_edge,Color(0.38,0.56,1.0,opacity*0.7),0.7,true)
	draw_polyline(right_edge,Color(0.025,0.035,0.12,opacity*0.85),1.0,true)

func _uppercut(progress: float, opacity: float) -> void:
	# Three tapered crescents grow from the attacking side, sweep up, then dissipate.
	var sign_x := float(fighter.facing)
	var center := Vector2(7*sign_x,-48)
	for finger: int in 3:
		var radius := 66.0 + finger*12.0
		var head := lerpf(0.70,-1.45, minf(1.0, progress*1.35))
		var tail := head + lerpf(0.45,1.70,minf(1.0,progress*2.5))
		_crescent(center,radius,head,tail,sign_x,opacity,5.0-finger*0.65)

func _slash(center: Vector2, progress: float, opacity: float) -> void:
	for finger: int in 3:
		_crescent(center,42.0+finger*10,lerpf(-0.9,0.3,progress),1.65,float(fighter.facing),opacity,3.5)

func _crescent(center: Vector2, radius: float, head: float, tail: float, facing: float, opacity: float, thickness: float) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var highlight := PackedVector2Array()
	for index: int in 25:
		var t := float(index)/24.0
		var angle := lerpf(tail,head,t)
		var direction := Vector2(cos(angle)*facing,sin(angle))
		var width := pow(sin(t*PI),0.75)*thickness
		outer.append(center+direction*(radius+width))
		inner.append(center+direction*(radius-width))
		highlight.append(center+direction*(radius+width*0.38))
	inner.reverse();outer.append_array(inner)
	draw_colored_polygon(outer,Color(0.60,0.30,0.92,opacity*0.75))
	draw_polyline(highlight,Color(0.92,0.79,1.0,opacity*0.95),1.3,true)
