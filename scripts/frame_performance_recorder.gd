class_name FramePerformanceRecorder
extends RefCounted

## Development-only process-frame recorder. It consumes presentation deltas and
## never feeds data back into fixed-tick combat authority.
const SCHEMA_VERSION := 1
const OUTPUT_DIRECTORY := "user://phase5-validation"
const OUTPUT_PATH := OUTPUT_DIRECTORY + "/performance.jsonl"

var warmup_seconds := 5.0
var target_seconds := 600.0
var warmup_elapsed := 0.0
var collected_seconds := 0.0
var frame_deltas_ms: Array[float] = []
var interruption_periods: Array[Dictionary] = []
var completed := false
var last_error := ""
var _interruption_started_usec := -1


func sample(delta_seconds: float, active_foreground_combat: bool) -> void:
	if completed or delta_seconds <= 0.0:
		return
	if not active_foreground_combat:
		_begin_interruption()
		return
	_end_interruption()
	if warmup_elapsed < warmup_seconds:
		warmup_elapsed = minf(warmup_seconds, warmup_elapsed + delta_seconds)
		return
	frame_deltas_ms.append(delta_seconds * 1000.0)
	collected_seconds += delta_seconds
	if collected_seconds >= target_seconds:
		completed = write_result()


func write_result() -> bool:
	last_error = ""
	if frame_deltas_ms.is_empty():
		last_error = "no_frame_samples"
		return false
	_end_interruption()
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		last_error = "create_output_directory_failed:%d" % directory_error
		return false
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		last_error = "open_output_failed:%d" % FileAccess.get_open_error()
		return false
	file.seek_end()
	file.store_line(JSON.stringify({
		"schema_version": SCHEMA_VERSION,
		"recorded_at_utc": Time.get_datetime_string_from_system(true),
		"warmup_seconds": warmup_seconds,
		"target_seconds": target_seconds,
		"collected_seconds": collected_seconds,
		"statistics": calculate_statistics(frame_deltas_ms),
		"interruptions": interruption_periods,
	}, "", true))
	file.flush()
	return true


static func calculate_statistics(samples_ms: Array[float]) -> Dictionary:
	if samples_ms.is_empty():
		return {}
	var sorted := samples_ms.duplicate()
	sorted.sort()
	var total := 0.0
	var over_budget := 0
	for value: float in sorted:
		total += value
		if value > 16.7:
			over_budget += 1
	var average_ms := total / float(sorted.size())
	return {
		"sample_count": sorted.size(),
		"average_fps": 1000.0 / average_ms,
		"p50_ms": _percentile(sorted, 0.50),
		"p95_ms": _percentile(sorted, 0.95),
		"p99_ms": _percentile(sorted, 0.99),
		"frames_over_16_7_ms": over_budget,
	}


static func _percentile(sorted_samples: Array[float], quantile: float) -> float:
	var index := clampi(ceili(float(sorted_samples.size()) * quantile) - 1, 0, sorted_samples.size() - 1)
	return sorted_samples[index]


func _begin_interruption() -> void:
	if _interruption_started_usec < 0:
		_interruption_started_usec = Time.get_ticks_usec()


func _end_interruption() -> void:
	if _interruption_started_usec < 0:
		return
	var ended := Time.get_ticks_usec()
	interruption_periods.append({
		"started_usec": _interruption_started_usec,
		"ended_usec": ended,
		"duration_ms": float(ended - _interruption_started_usec) / 1000.0,
	})
	_interruption_started_usec = -1
