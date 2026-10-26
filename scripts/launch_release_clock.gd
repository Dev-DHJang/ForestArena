extends RefCounted
## Display-only bridge. No fighter/inputs/combat duration reference is stored here.
var active := false
var elapsed := 0.0
var begin := 0
var end := 0
var duration := 0.0
var artwork_hash := ""
var last_launch_frame := -1
var previous := {}
var started_count := 0

static func integral_number(value: Variant) -> bool:
	# JSON.parse_string produces floats, even for integer-valued tokens.
	# bool is deliberately excluded before any numeric conversion.
	if not (value is int or value is float): return false
	var number := float(value)
	return is_finite(number) and number == floor(number)

static func validated(entry: Dictionary, count: int) -> Dictionary:
	if String(entry.get("sha256", "")).is_empty(): return {}
	var span: Variant = entry.get("launch_release_frame_range")
	var ticks: Variant = entry.get("launch_release_ticks")
	if not span is Array or span.size() != 2 or not integral_number(ticks): return {}
	if not integral_number(span[0]) or not integral_number(span[1]): return {}
	# Check bounds before narrowing floats to int, including huge finite input.
	if span[0] < 0 or span[0] >= span[1] or span[1] > count: return {}
	if ticks < 1 or ticks > 12 or ticks < span[1]-span[0]: return {}
	return {"begin":int(span[0]), "end":int(span[1]), "ticks":int(ticks)}

func reset() -> void:
	active = false
	elapsed = 0.0
	last_launch_frame = -1
	previous = {}

func cancel() -> void:
	active = false
	elapsed = 0.0
	# A fresh hit/result may arrive between snapshots. Do not treat its later
	# airborne state as the continuation of an older launch.
	previous = {}
	last_launch_frame = -1

func select(observation: Dictionary, entry: Dictionary, count: int, delta: float) -> int:
	var config := validated(entry,count)
	var in_air: bool = observation.state in [FighterController.State.JUMP,FighterController.State.FALL]
	var new_jump := false
	if not previous.is_empty():
		new_jump = int(observation.air_jumps) < int(previous.air_jumps) or (bool(previous.launcher_jump) and not bool(observation.launcher_jump))
		new_jump = new_jump or float(observation.velocity_y) < float(previous.velocity_y)-120.0
		new_jump = new_jump or (previous.state == FighterController.State.FALL and observation.state == FighterController.State.JUMP)
	var new_activation: bool = not previous.is_empty() and observation.activation != previous.activation
	var invalid := config.is_empty() or not in_air or bool(observation.attack) or new_jump or new_activation
	if active and String(entry.get("sha256", "")) != artwork_hash: invalid = true
	if active:
		if invalid:
			active = false
		else:
			# Clocks measure seconds, not calls. First transition sample is t=0.
			elapsed += maxf(delta,0.0) if is_finite(delta) else 0.0
			if elapsed + 0.0000001 >= duration: active = false
	elif not invalid and not previous.is_empty() and previous.state == FighterController.State.LAUNCH:
		if last_launch_frame >= 0 and last_launch_frame < count-1 and last_launch_frame < int(config.end)-1:
			begin = maxi(int(config.begin),last_launch_frame+1)
			end = int(config.end)
			duration = float(config.ticks)/60.0
			artwork_hash = String(entry.sha256)
			elapsed = 0.0
			active = begin < end
			if active: started_count += 1
	previous = observation.duplicate()
	if not active: return -1
	# Frame durations of the optional short release are uniform by contract.
	# At 30 FPS four 60-Hz poses cannot all be sampled; time is never stretched.
	return clampi(begin+int(floor(elapsed/duration*float(end-begin)+0.0000001)),begin,end-1)

func remember_actual_launch(frame: int) -> void:
	last_launch_frame = frame
