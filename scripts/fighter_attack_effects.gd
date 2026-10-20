extends Node2D
## Attack reach is drawn from authored data. This layer never resolves hits.
var fighter: FighterController

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if fighter == null or fighter.active_attack == null or fighter.runtime_profile == null: return
	var attack := fighter.active_attack
	if attack.schema_version < 4: return
	var id := String(fighter.runtime_profile.character_id)
	var active := fighter.state == FighterController.State.ATTACK_ACTIVE
	var preparing := fighter.state == FighterController.State.ATTACK_STARTUP
	if not active and not preparing: return
	var strength := 1.0 if active else 0.2 + 0.3 * float(fighter.attack_phase_tick) / maxi(attack.startup_ticks, 1)
	var sign_x := float(fighter.facing)
	var origin := Vector2(16 * sign_x, -42)
	if id == "ja-hyun" and attack.action_id == &"attack_special":
		# All three authored areas share the same global pulse. No downwards arc.
		var phase := (fighter.attack_phase_tick + 1) % 6
		strength *= 1.0 if phase in [0, 1] else 0.42
		_ribbon(origin, Vector2(-235, -30), strength)
		_ribbon(origin, Vector2(235, -30), strength)
		_ribbon(origin, Vector2(0, -260), strength)
	elif id == "ja-hyun" and attack.action_id == &"attack_heavy":
		var endpoint := attack.hitbox_offset + Vector2(attack.hitbox_size.x * 0.42, 0)
		endpoint.x *= sign_x
		if attack.activation_context == AttackData.ActivationContext.AIR:
			_ribbon(Vector2(12 * sign_x, -106), Vector2(62 * sign_x, 42), strength)
		else:
			_ribbon(origin, endpoint, strength)
	elif attack.activation_context == AttackData.ActivationContext.AIR and attack.action_id == &"attack_light":
		var reach := (attack.hitbox_offset.x + attack.hitbox_size.x * 0.4) * sign_x
		if id == "ja-hyun": _ribbon(origin, Vector2(reach, -36), strength)
		else: _claws(Vector2(reach - 32 * sign_x, -36), Vector2(46 * sign_x, -12), strength)
	elif id == "nabi" and attack.action_id == &"attack_heavy":
		_claws(Vector2(30 * sign_x, -34), Vector2(16 * sign_x, -92), strength)
	elif id == "nabi" and attack.action_id == &"attack_special" and fighter.attack_strike_ready:
		_claws(origin, Vector2(76 * sign_x, -12), strength)

func _ribbon(start: Vector2, finish: Vector2, opacity: float) -> void:
	var axis := finish - start
	var normal := axis.normalized().orthogonal()
	var tick := fighter.attack_phase_tick
	var pulse := float((tick + 1) % 6) / 6.0
	var extension := 1.0 if pulse < 0.17 else 0.78 + 0.22 * pulse
	if fighter.active_attack.action_id != &"attack_special": extension = 1.0
	var tip := start + axis * extension
	var points := PackedVector2Array()
	var edges := PackedVector2Array()
	var back := PackedVector2Array()
	for index: int in 17:
		var t := float(index) / 16.0
		var bend := sin(t * PI) * (16.0 + 13.0 * sin(t * TAU + tick * 0.6))
		var point := start.lerp(tip, t) + normal * bend
		var half_width := lerpf(4.0, 1.0, t) + sin(t * PI) * 3.0
		points.append(point)
		edges.append(point + normal * half_width)
		back.append(point - normal * half_width)
	back.reverse()
	edges.append_array(back)
	draw_colored_polygon(edges, Color(0.10, 0.25, 0.75, opacity))
	draw_polyline(points, Color(0.22, 0.54, 1.0, opacity), 3.0, true)
	draw_polyline(points, Color(0.64, 0.83, 1, opacity * 0.6), 0.8, true)

func _claws(start: Vector2, sweep: Vector2, opacity: float) -> void:
	var normal := sweep.normalized().orthogonal()
	for finger: int in 3:
		var offset := normal * (finger - 1) * 9.0
		var points := PackedVector2Array([start + offset, start + sweep * 0.4 + offset + normal * 8, start + sweep + offset])
		draw_polyline(points, Color(0.72, 0.48, 1, opacity * 0.8), 6.0, true)
		draw_polyline(points, Color(0.94, 0.87, 1, opacity), 2.0, true)
