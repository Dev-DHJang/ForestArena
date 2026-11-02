extends SceneTree
## Candidate images are loaded in memory only, never written into runtime/manifest.
const Presentation = preload("res://scripts/local_fighter_presentation.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var arena: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await physics_frame
	var match_controller: MatchController = arena.get_node("MatchController")
	match_controller.set_physics_process(false)
	match_controller.bot_source = null
	match_controller.bot_sources.clear()
	match_controller.rules = load("res://assets/combat/two_fighter_combat_rules.tres").duplicate(true)
	var catalog := LocalPlayCatalog.new()
	var result := {"kind":"actual-combat-and-presentation-code-timeline", "tick_rate":60, "motions":[]}
	for character: String in ["ja-hyun","nabi"]:
		for mode: String in ["ground","air"]:
			var directory := "res://_workspace/pebble-yoyo/motions/%s/%s/r02" % [character,mode]
			var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+"/candidate.json"))
			var selection := LoadoutSelection.new()
			selection.character_id = StringName(character)
			selection.accessory_id = &"pebble-yoyo"
			var built := LoadoutBuilder.build(selection,catalog.combat)
			assert(built.succeeded())
			var actor := match_controller.player
			actor.configure_profile(built.profile)
			match_controller.reset_match()
			match_controller.training_dummy.global_position = Vector2(1800,572)
			actor.global_position = Vector2(900,572)
			actor.facing = 1
			for i: int in 3: match_controller.step_fixed_tick(false)
			if mode == "air":
				actor.global_position.y = -400
				actor.velocity = Vector2.ZERO
				actor.move_and_slide()
				actor.state = FighterController.State.FALL
			var visual: Node = actor.get_node_or_null("Presentation")
			if visual == null:
				visual = Presentation.new()
				actor.add_child(visual)
			visual.set_process(false)
			visual.sync_visual(0.0)
			var image := Image.load_from_file(directory+"/sheet-128.png")
			assert(image != null)
			var texture := ImageTexture.create_from_image(image)
			var frames := SpriteFrames.new()
			var id := StringName(metadata.motion_id)
			frames.add_animation(id)
			frames.set_animation_loop(id,false)
			frames.set_animation_speed(id,20)
			for index: int in 16:
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2((index % int(metadata.columns))*128,(index / int(metadata.columns))*128,128,128)
				frames.add_frame(id,atlas)
			visual._motions[id] = frames
			var layout := metadata.duplicate(true)
			layout.sha256 = metadata.sheet_sha256
			visual._motion_layouts[id] = layout
			var trace := {"character":character,"mode":mode,"motion_id":id,"metadata":metadata,"frames":[]}
			match_controller.submit_intent(CombatIntent.new(match_controller.tick+1,actor.fighter_id,&"use_equipment"))
			for tick: int in 49:
				match_controller.step_fixed_tick(false)
				visual.sync_visual(1.0/60.0)
				var sprite: AnimatedSprite2D = visual.sprite
				var hand: Vector2 = visual.equipment_effects.hand_local
				var rendered_tip: Vector2 = visual.equipment_effects.display_tip()
				trace.frames.append({"tick":tick,"motion":String(sprite.animation),"frame":sprite.frame,"sprite_x":sprite.position.x,"sprite_y":sprite.position.y,"scale":sprite.scale.x,"hand_x":hand.x,"hand_y":hand.y,"actor_x":actor.position.x,"actor_y":actor.position.y,"phase":actor.equipment_phase,"phase_tick":actor.equipment_phase_tick,"rendered_tip_x":rendered_tip.x,"rendered_tip_y":rendered_tip.y,"tip_x":actor.equipment_position.x-actor.position.x,"tip_y":actor.equipment_position.y-actor.position.y})
			result.motions.append(trace)
	var file := FileAccess.open("res://_workspace/pebble-yoyo/game-timeline.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	arena.queue_free()
	await process_frame
	print("PEBBLE_YOYO_PREVIEW_TIMELINE: PASS")
	quit()
