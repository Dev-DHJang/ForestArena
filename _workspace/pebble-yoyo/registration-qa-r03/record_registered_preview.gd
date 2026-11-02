extends SceneTree
## Registration QA: actual runtime resources, no candidate texture/frames/layout injection.
const Presentation = preload("res://scripts/local_fighter_presentation.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var arena: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await physics_frame
	var controller: MatchController = arena.get_node("MatchController")
	controller.set_physics_process(false)
	controller.bot_source = null
	controller.bot_sources.clear()
	controller.rules = load("res://assets/combat/two_fighter_combat_rules.tres").duplicate(true)
	var catalog := LocalPlayCatalog.new()
	var result := {"kind":"actual-combat-and-presentation-code-timeline", "tick_rate":60,"preroll_ticks":27,"postroll_ticks":24,"motions":[],"idle_entry_probes":[]}
	for direction: int in [1,-1]:
		for character: String in ["ja-hyun","nabi"]:
			for mode: String in ["ground","air"]:
				var directory := "res://_workspace/pebble-yoyo/motions/%s/%s/r03" % [character,mode]
				var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+"/candidate.json"))
				var selection := LoadoutSelection.new()
				selection.character_id = StringName(character)
				selection.accessory_id = &"pebble-yoyo"
				var built := LoadoutBuilder.build(selection,catalog.combat)
				assert(built.succeeded())
				var actor := controller.player
				actor.configure_profile(built.profile)
				controller.reset_match()
				controller.training_dummy.global_position = Vector2(1800,572)
				actor.global_position = Vector2(900,572)
				actor.facing = direction
				for i: int in 3: controller.step_fixed_tick(false)
				if mode == "air":
					actor.global_position.y = -4000
					actor.velocity = Vector2.ZERO
					actor.move_and_slide()
					actor.state = FighterController.State.FALL
				var visual: Node = actor.get_node_or_null("Presentation")
				if visual == null:
					visual = Presentation.new()
					actor.add_child(visual)
				visual.set_process(false)
				visual._reset_playback()
				visual.sync_visual(0.0)
				var id := StringName(metadata.motion_id)
				assert(visual._motions.has(id), "registered runtime motion missing")
				assert(visual._motions[id].get_frame_count(id) == 16, "registered runtime frame count differs")
				var trace := {"character":character,"mode":mode,"motion_id":id,"facing":direction,"metadata":metadata,"frames":[]}
				for tick: int in range(-27,72):
					if tick == 0: controller.submit_intent(CombatIntent.new(controller.tick+1,actor.fighter_id,&"use_equipment"))
					controller.step_fixed_tick(false)
					visual.sync_visual(1.0/60.0)
					var sprite: AnimatedSprite2D = visual.sprite
					var hand: Vector2 = visual.equipment_effects.hand_local
					var rendered_tip: Vector2 = visual.equipment_effects.display_tip()
					trace.frames.append({"tick":tick,"motion":String(sprite.animation),"frame":sprite.frame,"sprite_x":sprite.position.x,"sprite_y":sprite.position.y,"scale":sprite.scale.x,"sprite_flip_h":sprite.flip_h,"hand_x":hand.x,"hand_y":hand.y,"actor_x":actor.position.x,"actor_y":actor.position.y,"phase":actor.equipment_phase,"phase_tick":actor.equipment_phase_tick,"rendered_tip_x":rendered_tip.x,"rendered_tip_y":rendered_tip.y,"display_rotation":visual.equipment_effects.display_rotation(),"tip_x":actor.equipment_position.x-actor.position.x,"tip_y":actor.equipment_position.y-actor.position.y})
				if mode == "air":
					var seen_frames := {}
					var seen_phases := {}
					for sample: Dictionary in trace.frames:
						if sample.phase != "idle":
							assert(sample.motion == "equipment_yoyo_air", "active airborne phase must show air motion")
							seen_frames[int(sample.frame)] = true
							seen_phases[String(sample.phase)] = true
						if int(sample.tick) >= 48: assert(sample.motion == "jump", "post-roll must remain airborne")
					for expected_frame: int in 16: assert(seen_frames.has(expected_frame), "missing airborne drawing")
					for expected_phase: String in ["startup","extend","return","recovery"]: assert(seen_phases.has(expected_phase), "missing airborne phase")
				result.motions.append(trace)
				if character == "nabi" and mode == "ground":
					for source_frame: int in 16:
						controller.reset_match()
						actor.global_position = Vector2(900,572)
						actor.facing = direction
						controller.training_dummy.global_position = Vector2(1800,572)
						for settle: int in 3: controller.step_fixed_tick(false)
						visual._reset_playback()
						visual.sync_visual(0.0)
						visual._elapsed = float(source_frame) / 8.0 + .01
						visual._last_motion = &"idle"
						visual.sync_visual(0.0)
						var probe := {"facing":direction,"source_idle_frame":source_frame,"before":probe_sample(visual),"cast":[]}
						controller.submit_intent(CombatIntent.new(controller.tick+1,actor.fighter_id,&"use_equipment"))
						for probe_tick: int in 49:
							controller.step_fixed_tick(false)
							visual.sync_visual(1.0/60.0)
							probe.cast.append(probe_sample(visual))
						result.idle_entry_probes.append(probe)
	var file := FileAccess.open("res://_workspace/pebble-yoyo/registration-qa-r03/runtime-timeline.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	arena.queue_free()
	await process_frame
	print("PEBBLE_YOYO_REGISTERED_TIMELINE_R03: PASS")
	call_deferred("quit")

func probe_sample(visual: Node) -> Dictionary:
	var sprite: AnimatedSprite2D = visual.sprite
	return {"motion":String(sprite.animation),"frame":sprite.frame,"sprite_x":sprite.position.x,"sprite_y":sprite.position.y,"scale":sprite.scale.x,"flip_h":sprite.flip_h}
