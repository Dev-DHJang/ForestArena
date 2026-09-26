extends SceneTree

var failures: Array[String] = []
var app: Node
var controller: MatchController
var hit_events: Array[Dictionary] = []
var case_label := ""

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func ticks(count: int) -> void:
	for index: int in count:
		await physics_frame
		controller.step_fixed_tick(false)

func start_case(character_id: StringName, accessory_id: StringName) -> void:
	case_label = "%s/%s" % [character_id, accessory_id]
	check(app.store.select(String(character_id), String(accessory_id), "ja-hyun"), "owned selection")
	app.start_match()
	controller = app.match_controller
	controller.set_physics_process(false)
	check(controller.bot_source != null, "normal app builds AI opponent")
	# Freeze only the opponent command producer so the effect measurement is
	# reproducible; attacks still use ordinary intents, physics and hit resolution.
	controller.bot_source = null
	controller.player.spawn_position = Vector2(200, 520)
	controller.training_dummy.spawn_position = Vector2(245, 520)
	controller.reset_match()
	hit_events.clear()
	controller.presentation_event.connect(func(event_id: StringName, payload: Dictionary) -> void:
		if event_id == &"hit_resolved": hit_events.append(payload))
	await ticks(40)
	check(controller.player.runtime_profile.accessory_id == accessory_id, "purchased accessory reaches player profile")
	check(controller.training_dummy.runtime_profile.accessory_id.is_empty(), "AI has no accessory")

func strike(source: FighterController) -> AttackData:
	hit_events.clear()
	source.facing = 1 if source == controller.player else -1
	controller.submit_intent(CombatIntent.new(controller.tick + 1, source.fighter_id, &"attack_light", CombatIntent.Direction.NEUTRAL, CombatIntent.Edge.PRESS, CombatIntent.Context.GROUND))
	await ticks(1)
	var attack := source.active_attack
	check(attack != null, case_label + "/" + String(source.fighter_id) + " normal light intent starts an attack")
	if attack == null: return null
	for index: int in attack.startup_ticks + attack.active_ticks + 2:
		if not hit_events.is_empty(): break
		await ticks(1)
	check(not hit_events.is_empty(), case_label + " actual hitboxes must produce a hit event")
	return attack

func run() -> void:
	app = (load("res://scenes/local_ai_app.tscn") as PackedScene).instantiate()
	var path := "user://test-accessory-play-%d.json" % Time.get_ticks_usec()
	app.save_path = path
	root.add_child(app)
	await process_frame
	check(app.store.grant_first("nabi"), "first grant")
	for item: Dictionary in app.catalog.products:
		if not app.store.owns(item.id): check(app.store.purchase(item.id), "free purchase " + item.id)
	for character: CharacterData in app.catalog.combat.characters:
		for accessory: AccessoryData in app.catalog.combat.accessories:
			await start_case(character.character_id, accessory.accessory_id)
			var player := controller.player
			var enemy := controller.training_dummy
			var player_hp := player.current_hp
			var enemy_hp := enemy.current_hp
			var label := "%s/%s" % [character.character_id, accessory.accessory_id]
			match accessory.accessory_id:
				&"fixture-iron-armor":
					check(is_equal_approx(player.runtime_profile.stats.weight, character.base_stats.weight + 0.5), label + " weight")
					var attack := await strike(enemy)
					if attack != null:
						check(is_equal_approx(player.current_hp, player_hp - attack.damage), label + " receives damage")
						check(not hit_events.is_empty() and hit_events[0].result == "ARMOR", label + " armor result")
						check(player.hitstun_ticks == 0 and is_zero_approx(player.velocity.x), label + " prevents stagger/knockback")
				&"fixture-boxing-gloves":
					check(is_equal_approx(player.runtime_profile.stats.ground_speed, character.base_stats.ground_speed * 1.2), label + " speed")
					var attack := await strike(player)
					if attack != null:
						check(attack.attack_id == &"yu-ran-light-01", label + " replacement attack executes")
						check(player.runtime_profile.move_set.combo_links.size() == accessory.replacement_move_set.combo_links.size(), label + " replacement combo links")
				&"fixture-thorns":
					await strike(enemy)
					check(is_equal_approx(enemy.current_hp, enemy_hp - 3.0), label + " actual damage triggers reflection")
				&"fixture-explosive-gloves":
					var attack := await strike(player)
					if attack != null: check(is_equal_approx(enemy.current_hp, enemy_hp - attack.damage - 4.0), label + " actual hit adds explosion damage")
				&"fixture-ultimate-charm":
					var attack := await strike(player)
					if attack != null:
						var expected := attack.damage * controller.rules.ultimate_gauge_per_damage_dealt + attack.resource_gain + 12.0
						check(is_equal_approx(player.runtime_state.ultimate_gauge, expected), label + " actual hit adds gauge")
				&"fixture-phoenix-revive":
					player.stocks = 1
					player.current_hp = 1
					await strike(enemy)
					check(player.stocks == 1 and player.runtime_state.revive_used and player.current_hp == 35.0, label + " lethal hit triggers one revive")
					check(player.respawn_ticks == 45 and controller.winner_id.is_empty(), label + " normal revive delay before result")
					await ticks(44)
					check(player.state == FighterController.State.RING_OUT, label + " no early return")
					await ticks(1)
					check(player.current_hp == 35.0 and player.invulnerability_ticks == 60, label + " authored HP and return immunity")
					await ticks(61)
					player.current_hp = 1
					await strike(enemy)
					check(controller.winner_id == &"opponent" and player.stocks == 0, label + " second lethal hit ends match")
			app.start_match()
			controller = app.match_controller
			controller.set_physics_process(false)
			check(controller.player.stocks == 3 and controller.player.current_hp == character.base_stats.max_hp, label + " rematch restores HP and stocks")
			check(not controller.player.runtime_state.revive_used and controller.player.runtime_state.ultimate_gauge == 0, label + " rematch resets resources")
			check(character.base_stats.max_hp == player_hp, label + " source max HP unchanged")
	app.queue_free()
	await process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	for failure: String in failures: push_error(failure)
	print("LOCAL_ACCESSORY_PLAY: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
