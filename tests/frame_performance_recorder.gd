extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	var recorder := FramePerformanceRecorder.new()
	recorder.warmup_seconds = 0.05
	recorder.target_seconds = 0.10
	recorder.sample(0.02, true)
	recorder.sample(0.02, true)
	recorder.sample(0.02, false)
	recorder.sample(0.02, true)
	_check(recorder.frame_deltas_ms.is_empty(), "warm-up or interruption delta was collected")
	recorder.sample(0.010, true)
	recorder.sample(0.020, true)
	_check(recorder.frame_deltas_ms.size() == 2, "active foreground samples were not collected")
	_check(recorder.interruption_periods.size() == 1, "interruption interval was not recorded")
	var stats := FramePerformanceRecorder.calculate_statistics([10.0, 20.0, 30.0, 40.0])
	_check(is_equal_approx(float(stats.p50_ms), 20.0), "p50 nearest-rank calculation changed")
	_check(is_equal_approx(float(stats.p95_ms), 40.0), "p95 nearest-rank calculation changed")
	_check(int(stats.frames_over_16_7_ms) == 3, "frame-budget count changed")
	if failures.is_empty():
		print("FRAME_PERFORMANCE_RECORDER: PASS")
	else:
		for failure: String in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
