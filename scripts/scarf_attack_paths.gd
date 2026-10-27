extends RefCounted
## Display-only continuous cloth paths. Coordinates are relative to the painted grip.

static func _ease(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func sample(motion: StringName, phase: int, tick: float, durations: Vector3, reach: float, mirrored := false) -> Dictionary:
	if motion not in [&"special_neutral", &"attack_air_light", &"attack_air_heavy"]: return {}
	if phase < 0 or phase > 2 or not is_finite(tick) or tick < 0.0: return {}
	if not durations.is_finite() or durations.x <= 0.0 or durations.y <= 0.0 or durations.z <= 0.0: return {}
	if not is_finite(reach) or reach <= 0.0: return {}
	var windup := _ease(tick / durations.x) if phase == 0 else 1.0
	var swing := _ease(tick / durations.y) if phase == 1 else (1.0 if phase == 2 else 0.0)
	var settle := _ease(tick / minf(durations.z, 7.0)) if phase == 2 else 0.0
	var extension := windup * (1.0 - settle)
	var opacity := windup * (1.0 - settle)
	var clock := tick + (durations.x if phase > 0 else 0.0) + (durations.y if phase > 1 else 0.0)
	var sign_x := -1.0 if mirrored else 1.0
	var angle: float
	var length: float
	var bow: float
	if motion == &"attack_air_heavy":
		# The overhead held tail sweeps down, then folds downwards as it returns.
		angle = lerpf(-72.0, -30.0, windup) if phase == 0 else lerpf(-30.0, 65.0, swing)
		if phase == 2: angle = lerpf(65.0, 88.0, settle)
		length = lerpf(14.0, 160.0, extension)
		bow = lerpf(-36.0, 22.0, swing) * extension
	else:
		# Pull and aerial whip share a continuous extension, rather than a fixed rod.
		var start_angle := -14.0 if motion == &"special_neutral" else -28.0
		var end_angle := -8.0 if motion == &"special_neutral" else 18.0
		angle = lerpf(-105.0, start_angle, windup) if phase == 0 else lerpf(start_angle, end_angle, swing)
		if phase == 2: angle = lerpf(end_angle, 75.0, settle)
		length = lerpf(14.0, clampf(reach, 40.0, 240.0), extension)
		bow = lerpf(-32.0, 12.0, swing) * extension
	var direction := Vector2.from_angle(deg_to_rad(angle))
	var tip := direction * length
	var control := direction * length * 0.50 + direction.orthogonal() * bow
	# Both relative vectors mirror together; the caller attaches to the exact current pose.
	return {"control": control * Vector2(sign_x, 1.0), "tip": tip * Vector2(sign_x, 1.0),
		"opacity": opacity, "width": lerpf(0.50, 0.82, extension),
		"wave_strength": 3.2 * extension, "clock_ticks": clock}
