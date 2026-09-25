extends Node
## Debug-only, aggregate rendering diagnostics. Never participates in combat.
var samples: Array[float] = []
var elapsed := 0.0
func _process(delta: float) -> void:
	samples.append(delta * 1000.0)
	elapsed += delta
	if samples.size() < 300: return
	var sorted := samples.duplicate()
	sorted.sort()
	print("FOREST_ARENA_PERFORMANCE " + JSON.stringify({"frames": samples.size(), "fps": samples.size() / elapsed, "frame_p95_ms": sorted[int(sorted.size() * 0.95)], "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "texture_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)}))
	samples.clear()
	elapsed = 0.0
