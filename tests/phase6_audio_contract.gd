extends SceneTree

var failures: Array[String] = []


func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)


func _initialize() -> void:
	var audio := CombatAudio.new()
	check(audio._tone_for(&"hit_resolved").frequency == 320.0, "hit tone is stable")
	check(audio._tone_for(&"ring_out").frequency == 120.0, "ring-out tone is stable")
	check(audio._tone_for(&"unknown").is_empty(), "unknown events stay silent")

	audio.play_combat_event(&"hit_resolved", {"result": "MISS"})
	check(audio.pending.is_empty(), "miss does not make sound")
	audio.play_combat_event(&"hit_resolved", {"result": "IMMUNE"})
	check(audio.pending.is_empty(), "immune hit does not make sound")
	audio.play_combat_event(&"hit_resolved", {"result": "HIT"})
	check(audio.pending.size() == 1, "hit queues presentation-only tone")
	audio.play_combat_event(&"ring_out", {})
	audio.play_combat_event(&"match_end", {})
	audio.play_combat_event(&"match_draw", {})
	check(audio.pending.size() == CombatAudio.MAX_PENDING_VOICES, "voice queue remains bounded")
	audio.muted = true
	audio.play_combat_event(&"match_end", {})
	check(audio.pending.size() == CombatAudio.MAX_PENDING_VOICES, "muted audio leaves queue unchanged")
	audio.free()

	for failure: String in failures:
		push_error(failure)
	print("PHASE6_AUDIO_CONTRACT: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
