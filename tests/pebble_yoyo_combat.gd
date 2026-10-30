extends SceneTree

const RULES: CombatRules = preload("res://assets/combat/two_fighter_combat_rules.tres")
const EQUIPMENT: AccessoryData = preload("res://assets/loadouts/pebble_yoyo_accessory.tres")
var failures: PackedStringArray = []
var scene: Node
var controller: MatchController
var catalog: LoadoutCatalog
var hit_events: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	scene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	controller = scene.get_node("MatchController") as MatchController
	controller.set_physics_process(false)
	controller.bot_source = null
	controller.bot_sources.clear()
	controller.rules = RULES.duplicate(true)
	catalog = (load("res://assets/loadouts/default_loadout_catalog.tres") as LoadoutCatalog).duplicate(true)
	for index: int in catalog.characters.size(): catalog.characters[index] = catalog.characters[index].duplicate(true) as CharacterData
	catalog.character_by_id(&"ja-hyun").base_move_set = load("res://assets/combat/movesets/two_fighter_ja_hyun_moveset.tres")
	catalog.character_by_id(&"nabi").base_move_set = load("res://assets/combat/movesets/two_fighter_nabi_moveset.tres")
	if catalog.accessory_by_id(EQUIPMENT.accessory_id) == null: catalog.accessories.append(EQUIPMENT)
	controller.presentation_event.connect(func(id: StringName, payload: Dictionary) -> void:
		if id == &"hit_resolved" and payload.get("action_id") == &"use_equipment": hit_events.append(payload.duplicate(true)))
	_test_data_and_priority()
	_test_timing_and_cooldown()
	_test_swept_hit_and_return()
	_test_protection_and_exact_stun()
	_test_cast_locks_and_interrupt()
	_test_same_tick_incoming_hit()
	_test_air_and_stock()
	_test_teams_and_simultaneous()
	_test_multiple_targets()
	await _test_wall()
	await _test_one_way_platform()
	_test_ai_equipment_commands()
	_test_snapshot_and_determinism()
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("PEBBLE_YOYO_COMBAT: PASS")
		quit(0)
	else:
		for message: String in failures: push_error(message)
		quit(1)


func check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message): failures.append(message)


func profile(character: StringName, equipped := true) -> RuntimeCombatProfile:
	var selection := LoadoutSelection.new()
	selection.character_id = character
	selection.accessory_id = EQUIPMENT.accessory_id if equipped else &""
	var built := LoadoutBuilder.build(selection, catalog)
	check(built.succeeded(), "equipment profile builds")
	return built.profile


func setup(target_equipped := false) -> void:
	controller.additional_fighters.clear()
	controller.team_by_fighter_id.clear()
	controller.local_match_mode = LocalMatchConfig.Mode.AI
	controller.player.configure_profile(profile(&"ja-hyun"))
	controller.training_dummy.configure_profile(profile(&"nabi", target_equipped))
	controller.reset_match()
	controller.player.global_position = Vector2(600, 572)
	controller.training_dummy.global_position = Vector2(920, 572)
	controller.player.facing = 1
	controller.training_dummy.facing = -1
	steps(3)
	hit_events.clear()


func steps(count: int) -> void:
	for ignored: int in count: controller.step_fixed_tick(false)


func input_for(fighter: FighterController, action: StringName, direction := CombatIntent.Direction.NEUTRAL, edge := CombatIntent.Edge.PRESS) -> CombatIntent:
	return CombatIntent.new(controller.tick + 1, fighter.fighter_id, action, direction, edge, CombatIntent.Context.GROUND if fighter.is_on_floor() else CombatIntent.Context.AIR)


func press(fighter: FighterController, action: StringName, direction := CombatIntent.Direction.NEUTRAL) -> void:
	controller.submit_intent(input_for(fighter, action, direction))


func _test_data_and_priority() -> void:
	check(EQUIPMENT.is_valid_definition() and EQUIPMENT.active_ability.is_valid_definition(), "new active equipment validates")
	var first := profile(&"ja-hyun")
	first.active_ability.reach = 999.0
	check(EQUIPMENT.active_ability.reach == 180.0 and profile(&"nabi").active_ability.reach == 180.0, "source ability and profiles are independently copied")
	var invalid := EQUIPMENT.active_ability.duplicate(true) as AccessoryAbilityData
	invalid.return_ticks = 0
	check(not invalid.is_valid_definition(), "invalid ability timing rejected")
	var equip := CombatIntent.new(1, &"player", &"use_equipment")
	var light := CombatIntent.new(1, &"player", &"attack_light")
	var down := CombatIntent.new(1, &"player", &"move", CombatIntent.Direction.DOWN, CombatIntent.Edge.HOLD)
	var jump := CombatIntent.new(1, &"player", &"jump")
	var resolved := CommandResolver.resolve([equip, down])
	check(resolved[-1].action_id == &"use_equipment", "equipment precedes bare-down guard")
	resolved = CommandResolver.resolve([equip, light])
	check(resolved[-1].action_id == &"attack_light", "ordinary attack precedes equipment")
	resolved = CommandResolver.resolve([equip, down, jump])
	check(resolved[-1].action_id == &"drop_platform", "platform drop precedes equipment")


func _test_timing_and_cooldown() -> void:
	setup()
	var player := controller.player
	press(player, &"use_equipment")
	steps(1)
	check(player.state == FighterController.State.EQUIPMENT and player.equipment_phase == "startup" and player.runtime_state.equipment_cooldown_ticks == 599, "valid start consumes cooldown once")
	steps(5)
	check(player.equipment_phase == "startup", "six startup ticks")
	steps(1)
	check(player.equipment_phase == "extend", "outbound starts after startup")
	steps(17)
	check(player.equipment_phase == "extend" and is_equal_approx(player.equipment_position.x - player.equipment_origin().x, 180.0), "outbound reaches180 in18 ticks")
	steps(18)
	check(player.equipment_phase == "return" and player.equipment_position.is_equal_approx(player.equipment_origin()), "return reaches arm after18 ticks")
	steps(6)
	check(player.equipment_phase == "idle", "full action ends at48 ticks")
	steps(551)
	check(player.runtime_state.equipment_cooldown_ticks == 1, "one cooldown tick remains before boundary")
	press(player, &"use_equipment")
	steps(1)
	check(player.equipment_phase == "idle" and player.runtime_state.equipment_cooldown_ticks == 0, "input before ready boundary rejects without consumption")
	press(player, &"use_equipment")
	steps(1)
	check(player.equipment_phase == "startup" and player.runtime_state.equipment_cooldown_ticks == 599, "next press exactly600 ticks after start succeeds")


func _test_swept_hit_and_return() -> void:
	setup()
	var player := controller.player
	var target := controller.training_dummy
	target.global_position.x = 740
	var hp := target.current_hp
	press(player, &"use_equipment")
	steps(24)
	check(hit_events.size() == 1 and target.current_hp == hp, "outbound hits once without HP damage")
	check(target.hitstun_ticks > 0 and target.velocity.x == 0.0, "pure stun has no added horizontal knockback")
	steps(24)
	check(hit_events.size() == 1, "return and lingering overlap never hit twice")
	setup()
	target = controller.training_dummy
	target.global_position = Vector2(750, 250)
	press(controller.player, &"use_equipment")
	steps(25)
	target.global_position = Vector2(740, 572)
	steps(23)
	check(hit_events.is_empty(), "target entering only on return is not hit")
	setup()
	player = controller.player
	target = controller.training_dummy
	# A data-tuned fast extension proves swept detection rather than endpoint overlap.
	player.runtime_profile.active_ability.extend_ticks = 1
	target.global_position.x = 730
	press(player, &"use_equipment")
	steps(7)
	check(hit_events.size() == 1, "swept outbound finds target between endpoints")


func _test_protection_and_exact_stun() -> void:
	setup()
	var source := controller.player
	var target := controller.training_dummy
	var ability := source.equipment_ability()
	var hp := target.current_hp
	var air_jumps := target.air_jumps_remaining
	target.velocity = Vector2(42, -12)
	target.runtime_profile.stats.weight = 0.5
	var result := HitResolver.resolve_equipment(source, target, ability)
	check(result.type == HitResult.Type.HIT and target.hitstun_ticks == 30, "stun is exactly30 despite weight and current2x multiplier")
	check(target.current_hp == hp and target.velocity == Vector2(42, -12) and target.air_jumps_remaining == air_jumps, "pure stun preserves HP momentum and air budget")
	target.hitstun_ticks = 60
	HitResolver.resolve_equipment(source, target, ability)
	check(target.hitstun_ticks == 60, "equipment never shortens existing longer stun")
	setup()
	target = controller.training_dummy
	target.runtime_state.guarding = true
	target.state = FighterController.State.GUARD
	var durability := target.runtime_state.guard_durability
	result = HitResolver.resolve_equipment(controller.player, target, ability)
	check(result.type == HitResult.Type.BLOCK and target.hitstun_ticks == 0 and target.runtime_state.guard_durability == durability, "guard blocks with no durability cost or stun")
	target.runtime_state.guarding = false
	target.state = FighterController.State.IDLE
	for protected in ["invulnerability_ticks", "wakeup_protection_ticks"]:
		target.set(protected, 12)
		result = HitResolver.resolve_equipment(controller.player, target, ability)
		check(result.type == HitResult.Type.IMMUNE and target.hitstun_ticks == 0, "equipment respects " + protected)
		target.set(protected, 0)
	target.state = FighterController.State.KNOCK_DOWN
	result = HitResolver.resolve_equipment(controller.player, target, ability)
	check(result.type == HitResult.Type.MISS and target.state == FighterController.State.KNOCK_DOWN, "down protection remains")


func _test_cast_locks_and_interrupt() -> void:
	setup()
	var player := controller.player
	press(player, &"use_equipment")
	steps(1)
	var origin := player.global_position
	press(player, &"move", CombatIntent.Direction.LEFT)
	press(player, &"jump")
	press(player, &"attack_light")
	steps(3)
	check(player.state == FighterController.State.EQUIPMENT and player.global_position.is_equal_approx(origin) and player.active_attack == null and player.equipment_facing == 1 and player.facing == 1, "cast locks movement jump attack and facing")
	press(player, &"guard")
	steps(1)
	check(player.state == FighterController.State.EQUIPMENT and not player.runtime_state.guarding, "guard cannot start during equipment")
	var cooldown := player.runtime_state.equipment_cooldown_ticks
	var incoming := controller.training_dummy.attacks[0]
	player.apply_hit(incoming, Vector2.ZERO, 30, controller.rules)
	check(player.equipment_phase == "idle" and player.equipment_sweep_rect().size == Vector2.ZERO and player.runtime_state.equipment_cooldown_ticks == cooldown, "damage removes equipment without refund")
	player.state = FighterController.State.IDLE
	player.runtime_state.equipment_cooldown_ticks = 0
	player.runtime_state.guarding = true
	player.state = FighterController.State.GUARD
	press(player, &"use_equipment")
	steps(1)
	check(player.equipment_phase == "idle" and player.runtime_state.equipment_cooldown_ticks == 0, "guarded use rejects without cooldown")


func _test_air_and_stock() -> void:
	setup()
	var player := controller.player
	player.global_position = Vector2(600, 300)
	player.state = FighterController.State.FALL
	steps(1)
	var before_y := player.global_position.y
	var budget := player.air_jumps_remaining
	press(player, &"use_equipment")
	steps(10)
	check(player.state == FighterController.State.EQUIPMENT and player.global_position.y > before_y and player.velocity.x == 0.0 and player.air_jumps_remaining == budget, "air cast falls under gravity without consuming air actions")
	steps(38)
	check(player.equipment_phase == "idle", "landing preserves action clock until normal completion")
	var cooldown := player.runtime_state.equipment_cooldown_ticks
	player.lose_stock(controller.rules)
	check(player.runtime_state.equipment_cooldown_ticks == cooldown, "stock loss does not reset cooldown")
	steps(controller.rules.respawn_delay_ticks)
	check(player.runtime_state.equipment_cooldown_ticks > 0, "respawn preserves remaining cooldown")
	controller.reset_match()
	check(player.runtime_state.equipment_cooldown_ticks == 0 and player.equipment_phase == "idle", "new match resets equipment")


func _test_teams_and_simultaneous() -> void:
	setup(true)
	var player := controller.player
	var target := controller.training_dummy
	target.global_position.x = 740
	var opponent := _extra_fighter(&"enemy", Vector2(1000, 572))
	controller.local_match_mode = LocalMatchConfig.Mode.TEAM
	controller.team_by_fighter_id = {player.fighter_id: &"alpha", target.fighter_id: &"alpha", opponent.fighter_id: &"beta"}
	press(player, &"use_equipment")
	steps(48)
	check(hit_events.is_empty() and target.hitstun_ticks == 0, "equipment excludes teammates")
	controller.additional_fighters.clear()
	opponent.free()
	setup(true)
	player = controller.player
	target = controller.training_dummy
	target.global_position.x = 740
	press(player, &"use_equipment")
	press(target, &"use_equipment")
	steps(20)
	check(hit_events.size() == 2, "simultaneous equipment sweeps trade once per participant")


func _test_snapshot_and_determinism() -> void:
	var hashes: Array[String] = []
	for run_index: int in 2:
		setup()
		controller.training_dummy.global_position.x = 740
		press(controller.player, &"use_equipment")
		steps(12)
		var sent := controller.network_snapshot().fighters[0] as Dictionary
		check(sent.equipment_phase == "extend" and sent.equipment_tick == 12 and sent.equipment_cooldown_ticks == 588 and sent.accessory_id == "pebble-yoyo", "snapshot carries authoritative equipment state")
		var remote := FighterController.new()
		remote.character_data = controller.player.character_data
		remote.fighter_id = &"remote"
		remote.configure_profile(profile(&"ja-hyun"))
		remote.apply_network_snapshot(sent)
		check(remote.equipment_phase == "extend" and remote.equipment_tick == 12 and remote.equipment_phase_tick == 5 and remote.equipment_position == controller.player.equipment_position and remote.runtime_state.equipment_cooldown_ticks == 588, "network display restores equipment without simulating")
		remote.free()
		steps(40)
		hashes.append(controller.snapshot_hash())
	check(hashes[0] == hashes[1], "same seed and equipment inputs reproduce final state")


func _test_multiple_targets() -> void:
	setup()
	var extra := _extra_fighter(&"extra", Vector2(790, 572))
	controller.training_dummy.global_position.x = 730
	press(controller.player, &"use_equipment")
	steps(24)
	check(hit_events.size() == 2 and extra.hitstun_ticks > 0 and controller.training_dummy.hitstun_ticks > 0, "one outbound cast can hit two different enemies once each")
	controller.additional_fighters.clear()
	extra.free()


func _test_wall() -> void:
	setup()
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = Vector2(700, 470)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 240)
	collision.shape = shape
	wall.add_child(collision)
	scene.get_node("World").add_child(wall)
	await physics_frame
	controller.training_dummy.global_position = Vector2(770, 572)
	press(controller.player, &"use_equipment")
	steps(16)
	check(controller.player.equipment_phase == "return" and controller.player.equipment_position.x < 690, "solid terrain starts early retraction before crossing the wall")
	var wall_snapshot := controller.network_snapshot().fighters[0] as Dictionary
	check(wall_snapshot.equipment_phase_tick == controller.player.equipment_tick - controller.player._equipment_return_start - 1 and wall_snapshot.equipment_phase_tick < 18, "early wall return reports phase-local elapsed ticks for motion")
	steps(32)
	check(hit_events.is_empty(), "equipment cannot strike through solid wall")
	wall.free()


func _extra_fighter(id: StringName, location: Vector2) -> FighterController:
	var extra := (load("res://scenes/fighters/nabi_fighter.tscn") as PackedScene).instantiate() as FighterController
	extra.fighter_id = id
	extra.character_data = catalog.character_by_id(&"nabi")
	scene.get_node("World").add_child(extra)
	extra.configure_profile(profile(&"nabi", false))
	extra.global_position = location
	controller.additional_fighters.append(extra)
	return extra


func _test_one_way_platform() -> void:
	setup()
	var platform := StaticBody2D.new()
	platform.collision_layer = 1
	platform.collision_mask = 0
	platform.position = Vector2(700, 534)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(80, 12)
	collision.shape = shape
	collision.one_way_collision = true
	platform.add_child(collision)
	scene.get_node("World").add_child(platform)
	await physics_frame
	check(controller.player._equipment_terrain_fraction(Vector2(700, 500), Vector2(700, 550)) < 1.0, "one-way top blocks descending equipment")
	check(controller.player._equipment_terrain_fraction(Vector2(700, 560), Vector2(700, 500)) == 1.0, "one-way underside allows ascending equipment")
	# Equipment at y540 crosses a one-way platform from below/sideways.
	press(controller.player, &"use_equipment")
	steps(24)
	check(controller.player.equipment_phase == "extend" and is_equal_approx(controller.player.equipment_position.x - controller.player.equipment_origin().x, 180.0), "one-way underside and sides do not stop horizontal equipment")
	platform.free()


func _test_same_tick_incoming_hit() -> void:
	setup()
	var player := controller.player
	var target := controller.training_dummy
	target.global_position.x = 645
	press(target, &"attack_light", CombatIntent.Direction.LEFT)
	steps(1)
	press(player, &"use_equipment")
	steps(7)
	check(player.hitstun_ticks > 0 and player.equipment_phase == "idle" and target.hitstun_ticks == 0 and hit_events.is_empty(), "ordinary incoming hit cancels equipment before its same-tick outbound resolution")


func _test_ai_equipment_commands() -> void:
	var actor := {"id": "bot", "on_floor": true, "state": "IDLE", "position": Vector2(600, 572), "velocity": Vector2.ZERO, "air_jumps": 1, "stocks": 3, "special_cooldown_ticks": 0, "equipment_ability_id": "pebble-yoyo", "equipment_cooldown_ticks": 0, "equipment_reach": 180.0}
	var target := {"id": "target", "on_floor": true, "state": "IDLE", "position": Vector2(740, 572), "stocks": 3}
	var view := {"fighters": [actor, target]}
	var bot := LocalAICommandSource.new(&"bot", 79, {"simplified_combat": true})
	var casts := 0
	for tick: int in range(1, 601):
		for command: CombatIntent in bot.commands_for_tick(tick, view):
			if command.action_id == &"use_equipment": casts += 1
	check(casts > 0, "equipped AI uses equipment through the common intent path")
	actor.equipment_cooldown_ticks = 600
	bot.reset()
	for tick: int in range(1, 301):
		for command: CombatIntent in bot.commands_for_tick(tick, view):
			check(command.action_id != &"use_equipment", "AI respects visible equipment cooldown")
	actor.equipment_cooldown_ticks = 0
	actor.equipment_ability_id = ""
	bot.reset()
	for tick: int in range(1, 301):
		for command: CombatIntent in bot.commands_for_tick(tick, view):
			check(command.action_id != &"use_equipment", "unequipped AI never emits equipment action")
