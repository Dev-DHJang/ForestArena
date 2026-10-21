extends SceneTree
## Synthetic frame resources test playback rules, never serve as character art.
const Presentation := preload("res://scripts/local_fighter_presentation.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func fixture_frames(motion: StringName, count: int, weights: Array = []) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(motion)
	frames.set_animation_speed(motion, 12.0)
	frames.set_animation_loop(motion, motion == &"run")
	var texture := GradientTexture2D.new()
	texture.width = 128
	texture.height = 128
	for index: int in count:
		frames.add_frame(motion, texture, float(weights[index]) if not weights.is_empty() else 1.0)
	return frames

func run() -> void:
	var weights: Array = []
	for index: int in 24: weights.append(1.0)
	weights[0] = 3.0
	var attack := AttackData.new()
	attack.startup_ticks = 8
	attack.active_ticks = 4
	attack.recovery_ticks = 18
	var ranges := [[0,6],[6,10],[10,24]]
	check(Presentation.attack_frame(attack,FighterController.State.ATTACK_STARTUP,1,24,ranges,weights)==0,"authored anticipation weight holds the first pose")
	check(Presentation.attack_frame(attack,FighterController.State.ATTACK_STARTUP,7,24,ranges,weights)==5,"startup reaches its final authored pose")
	for tick: int in 4:
		check(Presentation.attack_frame(attack,FighterController.State.ATTACK_ACTIVE,tick,24,ranges,weights)==6+tick,"four active ticks expose the four impact drawings exactly once")
	check(Presentation.attack_frame(attack,FighterController.State.ATTACK_RECOVERY,17,24,ranges,weights)==23,"recovery reaches the last drawing without extending combat")
	check(Presentation.attack_frame(attack,FighterController.State.ATTACK_ACTIVE,0,16,[[0,5],[5,9],[9,16]])==5,"legacy phase mapping starts at its original frame")
	check(Presentation.attack_frame(attack,FighterController.State.ATTACK_ACTIVE,1,16,[[0,5],[5,9],[9,16]])==6,"legacy phase mapping keeps the rounded selection")
	check(Presentation.playback_frame(0.1,12,0,24,weights)==0,"ordinary weighted playback holds its long first frame")
	check(Presentation.playback_frame(3.0,12,0,24,weights)==23,"non-loop weighted playback holds the final frame")
	check(Presentation.playback_frame(26.0/12.0,12,0,24,weights,true)==0,"weighted looping wraps at the sum of frame durations")
	var fighter := FighterController.new()
	fighter.character_data = load("res://assets/character/ja-hyun/character.tres")
	fighter.fighter_id = &"variable-motion-fixture"
	root.add_child(fighter)
	fighter.set_physics_process(false)
	var selection := LoadoutSelection.new()
	selection.character_id = &"ja-hyun"
	check(fighter.configure_profile(LoadoutBuilder.build(selection,LocalPlayCatalog.new().combat).profile),"fixture uses the actual character profile")
	var visual := Presentation.new()
	fighter.add_child(visual)
	visual.set_process(false)
	var uniform: Array = []
	for index: int in 24: uniform.append(1.0)
	var anchors: Array = []
	for index: int in 24:
		anchors.append({"scarf_root": [64,index], "scarf_hand": [index,64], "scarf_tips": [[40,80],[80,80]]})
	for motion: StringName in [&"run", &"jump", &"attack_air_heavy"]:
		visual._motions[motion] = fixture_frames(motion,24,uniform)
		visual._motion_layouts[motion] = {"character_id":"ja-hyun","visual_state_id":String(motion),"sha256":"fixture-art-hash","frame_count":24,"frame_durations":uniform,"foot_pivot_y":124,"run_stride_px":96.0,"jump_frame_ranges":{"ascent":[0,6],"apex":[6,10],"descent":[10,16],"landing":[16,24]},"phase_frame_ranges":ranges,"frame_anchors":anchors}
	fighter.state = FighterController.State.RUN
	visual.sync_visual(0.0)
	check(visual.sprite.frame==0,"distance-driven run starts a fresh foot cycle")
	fighter.position.x += 24.0
	var before := fighter.snapshot()
	visual.sync_visual(0.0)
	check(visual.sprite.frame==6,"24 world pixels advance a quarter of the 96-pixel stride")
	check(before==fighter.snapshot(),"stride selection cannot change combat or position")
	visual.sync_visual(1.0)
	check(visual.sprite.frame==6,"standing in run state does not slide the feet with time")
	fighter.position.x += 72.0
	visual.sync_visual(0.0)
	check(visual.sprite.frame==0,"a complete 96-pixel stride closes the left-right foot loop")
	fighter.position.x += 384.0
	visual.sync_visual(0.0)
	check(visual.sprite.frame==0,"teleport resets the foot cycle")
	fighter.position.x += 48.0
	visual.sync_visual(0.0)
	check(visual.sprite.frame==12,"ordinary movement resumes after teleport")
	fighter.state = FighterController.State.IDLE
	visual.sync_visual(0.0)
	fighter.position.x += 48.0
	fighter.state = FighterController.State.RUN
	visual.sync_visual(0.0)
	check(visual.sprite.frame==0,"a fresh run never inherits the previous run or idle displacement")
	fighter.activation_serial += 1
	fighter.position.x += 24.0
	visual.sync_visual(0.0)
	check(visual.sprite.frame==0,"new fighter activation resets stride")
	fighter.state = FighterController.State.JUMP
	fighter.velocity.y = -400.0
	visual.sync_visual(0.0)
	check(visual.sprite.frame==0,"new 24-frame jump begins in its authored ascent range")
	visual.sync_visual(1.0)
	check(visual.sprite.frame==5,"ascent holds its last airborne pose")
	fighter.velocity.y = 0.0
	visual.sync_visual(0.0)
	check(visual.sprite.frame==6,"apex has a separately restarted frame range")
	fighter.state = FighterController.State.FALL
	fighter.velocity.y = 200.0
	visual.sync_visual(0.0)
	check(visual.sprite.frame==10,"descent begins in its own authored range")
	visual.sync_visual(1.0)
	check(visual.sprite.frame==15,"long descent never advances into grounded landing art")
	fighter.state = FighterController.State.IDLE
	before = fighter.snapshot()
	visual.sync_visual(0.24)
	check(visual.sprite.frame==16,"actual ground state starts the first landing drawing")
	visual.sync_visual(0.0)
	check(visual.sprite.frame==23,"the expanded landing fits the existing quarter-second display window")
	check(before==fighter.snapshot(),"expanded jump/landing art keeps physics read-only")
	fighter.active_attack = attack
	attack.visual_state_id = &"attack_air_heavy"
	fighter.state = FighterController.State.ATTACK_RECOVERY
	fighter.attack_phase_tick = 17
	visual.sync_visual(0.0)
	check(visual.sprite.frame==23,"24-frame attack reaches its exact authored final pose")
	var effect := visual.get_node("AttackReachEffects")
	check(effect.current_frame_anchors().scarf_hand==[23,64],"effect uses the actual current frame beyond legacy frame 15")
	check(effect._anchor(Vector2(23,64)).is_equal_approx(visual.sprite.position+Vector2(-41,0)),"attachment follows the shown sprite pivot")
	fighter.facing = -1
	visual.sync_visual(0.0)
	check(effect._anchor(Vector2(23,64)).is_equal_approx(visual.sprite.position+Vector2(41,0)),"attachment mirrors with the actual displayed sprite")
	visual._motion_layouts[&"attack_air_heavy"].erase("frame_anchors")
	visual.sync_visual(0.0)
	check(effect.current_frame_anchors().is_empty(),"new 24-frame art cannot borrow old 16-frame scarf coordinates")
	visual._motion_layouts[&"attack_air_heavy"].frame_anchors = anchors.slice(0,16)
	visual.sync_visual(0.0)
	check(effect.current_frame_anchors().is_empty(),"wrong-count anchors are not silently clamped or reused")
	var malformed_anchors := anchors.duplicate(true)
	malformed_anchors[23].scarf_hand = ["invalid",64]
	visual._motion_layouts[&"attack_air_heavy"].frame_anchors = malformed_anchors
	visual.sync_visual(0.0)
	check(effect.current_frame_anchors().is_empty(),"malformed attachment data is safely omitted")
	malformed_anchors[23].scarf_hand = [23,INF]
	visual.sync_visual(0.0)
	check(effect.current_frame_anchors().is_empty(),"infinite attachment positions cannot reach the cloth mesh")
	var no_hash := {"frame_count":24,"frame_durations":uniform,"run_stride_px":96,"frame_anchors":anchors}
	check(not Presentation.display_layout(no_hash).has("frame_anchors"),"new layout metadata requires an artwork hash")
	var calibration_key := "fixture-character/jump"
	Presentation._display_layouts[calibration_key] = {"asset_sha256":"same-png-hash","scale":1.0,"foot_pivot_y":124,"run_stride_px":64,"frame_anchors":[{"scarf_hand":[1,2]}]}
	var explicit_entry := {"character_id":"fixture-character","visual_state_id":"jump","sha256":"same-png-hash","run_stride_px":96,"frame_anchors":anchors}
	var explicit_drawing := Presentation.display_layout(explicit_entry)
	check(explicit_drawing.run_stride_px==96 and explicit_drawing.frame_anchors==anchors,"explicit candidate timing and anchors override matching older calibration for the same PNG")
	explicit_entry.sha256 = "changed-png-hash"
	explicit_entry.erase("run_stride_px")
	check(not Presentation.display_layout(explicit_entry).has("run_stride_px"),"a stale calibration cannot supply movement metadata to changed artwork")
	Presentation._display_layouts.erase(calibration_key)
	# A newly drawn 16-frame sheet is just as different as a 24/32-frame one.
	# Old per-pose scarf coordinates must stay tied to their inspected PNG.
	visual._motions[&"attack_air_heavy"] = fixture_frames(&"attack_air_heavy",16)
	visual._motion_layouts[&"attack_air_heavy"] = {"sha256":"new-sixteen-art","frame_count":16}
	fighter.active_attack = attack
	fighter.state = FighterController.State.ATTACK_ACTIVE
	fighter.attack_phase_tick = 0
	visual._last_motion = &""
	visual.sync_visual(0.0)
	check(effect.current_frame_anchors().is_empty(),"new 16-frame art cannot borrow another drawing's scarf coordinates")
	visual._motion_layouts[&"attack_air_heavy"].sha256 = Presentation.AttackEffects.LEGACY_ANCHOR_HASHES[&"attack_air_heavy"]
	visual.sync_visual(0.0)
	check(effect.current_frame_anchors().has("scarf_hand"),"the exact inspected 16-frame PNG retains its old attachment")
	visual._motion_layouts[&"attack_air_heavy"].sha256 = "new-sixteen-art"
	visual._motion_layouts[&"attack_air_heavy"].frame_anchors = anchors.slice(0,16)
	visual.sync_visual(0.0)
	check(effect.current_frame_anchors().scarf_hand==[visual.sprite.frame,64],"new 16-frame art accepts its own explicit per-pose attachments")
	visual._motion_layouts[&"attack_air_heavy"].erase("frame_anchors")
	visual._motion_layouts[&"attack_air_heavy"].erase("sha256")
	visual.sync_visual(0.0)
	check(effect.current_frame_anchors().is_empty(),"missing artwork identity cannot enable a legacy attachment")
	for count: int in [24,32]:
		var loop_frames := fixture_frames(&"run",count)
		visual._motions[&"run"] = loop_frames
		visual._motion_layouts[&"run"] = {"sha256":"count-fixture","frame_count":count,"run_stride_px":96}
		fighter.active_attack = null
		fighter.state = FighterController.State.RUN
		visual._last_motion = &""
		visual.sync_visual(0.0)
		fighter.position.x += 95.0
		visual.sync_visual(0.0)
		check(visual.sprite.frame==count-1,"both 24 and 32 frame resources expose their last real frame")
	var finisher_weights: Array = []
	for index: int in 32: finisher_weights.append(1.0)
	attack.startup_ticks = 10
	attack.recovery_ticks = 22
	check(Presentation.attack_frame(attack,FighterController.State.ATTACK_RECOVERY,21,32,[[0,8],[8,12],[12,32]],finisher_weights)==31,"expanded 32-frame finisher reaches its last recovery drawing")
	fighter.free()
	for failure: String in failures: push_error(failure)
	print("VARIABLE_MOTION_PRESENTATION: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
