class_name CombatAudio
extends Node

## Presentation-only procedural SFX. No external asset or combat timing is used.
const MAX_PENDING_VOICES := 3
var player := AudioStreamPlayer.new()
var playback: AudioStreamGeneratorPlayback
var pending: Array[Dictionary] = []
var muted := false

func _ready() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.12
	player.stream = stream
	player.bus = &"Master"
	add_child(player)
	player.play()
	playback = player.get_stream_playback()


func play_combat_event(event_id: StringName, payload: Dictionary) -> void:
	if muted or event_id == &"hit_resolved" and String(payload.get("result", "")) in ["MISS", "IMMUNE"]: return
	var tone := _tone_for(event_id)
	if tone.is_empty(): return
	if pending.size() >= MAX_PENDING_VOICES: pending.pop_front()
	pending.append(tone)


func apply_accessibility(settings: Dictionary) -> void:
	muted = bool(settings.get("reduce_visual_effects", false)) and bool(settings.get("mute_feedback", false))


func _process(_delta: float) -> void:
	if playback == null: return
	while playback.get_frames_available() > 0:
		var mixed := 0.0
		for voice: Dictionary in pending:
			if voice.samples_left <= 0: continue
			var age := float(voice.total - voice.samples_left) / float(voice.total)
			mixed += sin(TAU * voice.frequency * age * float(voice.total) / 22050.0) * voice.volume * (1.0 - age)
			voice.samples_left -= 1
		pending = pending.filter(func(voice: Dictionary) -> bool: return voice.samples_left > 0)
		playback.push_frame(Vector2.ONE * clampf(mixed, -0.45, 0.45))


func _tone_for(event_id: StringName) -> Dictionary:
	match event_id:
		&"hit_resolved": return {"frequency": 320.0, "volume": 0.16, "total": 900, "samples_left": 900}
		&"ring_out": return {"frequency": 120.0, "volume": 0.22, "total": 2600, "samples_left": 2600}
		&"match_end": return {"frequency": 520.0, "volume": 0.18, "total": 3600, "samples_left": 3600}
		&"match_draw": return {"frequency": 240.0, "volume": 0.16, "total": 3000, "samples_left": 3000}
	return {}
