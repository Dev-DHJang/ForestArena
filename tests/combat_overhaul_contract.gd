extends SceneTree

const EffectControllerScript = preload("res://scripts/effect_controller.gd")
const EffectData = preload("res://scripts/data/combat_effect_data.gd")
const CommandResolverScript = preload("res://scripts/command_resolver.gd")

const FIXTURES := [
	"res://assets/loadouts/fixtures/iron_armor_accessory.tres",
	"res://assets/loadouts/fixtures/boxing_gloves_accessory.tres",
	"res://assets/loadouts/fixtures/thorns_accessory.tres",
	"res://assets/loadouts/fixtures/explosive_gloves_accessory.tres",
	"res://assets/loadouts/fixtures/ultimate_charm_accessory.tres",
	"res://assets/loadouts/fixtures/phoenix_revive_accessory.tres",
]


func _initialize() -> void:
	var failures: PackedStringArray = []
	for path: String in FIXTURES:
		var accessory := load(path) as AccessoryData
		if accessory == null or not accessory.is_valid_definition(): failures.append("invalid fixture: %s" % path)
	var instance := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(instance)
	await process_frame
	var controller := instance.get_node("MatchController") as MatchController
	controller.set_physics_process(false)
	var player := controller.player
	var dummy := controller.training_dummy
	var legacy_rules := CombatRules.new()
	if legacy_rules.is_valid_definition() or not controller.rules.is_valid_definition():
		failures.append("CombatRules v3 did not reject missing legacy schema")

	# Source profile is copied before an effect is attached.
	var original_count := player.character_data.base_move_set.combo_links.size()
	if player.runtime_profile.move_set.combo_links.size() != original_count: failures.append("runtime profile did not preserve combo links")
	# Bare down resolves to guard; down+attack wins over guard.
	var down := CombatIntent.new(1, player.fighter_id, &"move", CombatIntent.Direction.DOWN, CombatIntent.Edge.HOLD)
	var light := CombatIntent.new(1, player.fighter_id, &"attack_light", CombatIntent.Direction.DOWN, CombatIntent.Edge.PRESS)
	var commands: Array[CombatIntent] = CommandResolverScript.resolve([down, light])
	if commands.any(func(intent: CombatIntent) -> bool: return intent.action_id == &"guard") or not commands.any(func(intent: CombatIntent) -> bool: return intent.action_id == &"attack_light"):
		failures.append("down attack priority failed")
	var jump := CombatIntent.new(1, player.fighter_id, &"jump", CombatIntent.Direction.DOWN, CombatIntent.Edge.PRESS)
	commands = CommandResolverScript.resolve([down, light, jump])
	if not commands.any(func(intent: CombatIntent) -> bool: return intent.action_id == &"drop_platform") or commands.any(func(intent: CombatIntent) -> bool: return intent.action_id == &"attack_light"):
		failures.append("down jump platform priority failed")

	# Runtime state is the read-only HUD source, including guard release and resources.
	player.state = FighterController.State.GUARD
	player.runtime_state.guarding = true
	player.consume_intent(CombatIntent.new(1, player.fighter_id, &"move", CombatIntent.Direction.DOWN, CombatIntent.Edge.RELEASE), controller.rules)
	if player.runtime_state.guarding or player.state == FighterController.State.GUARD:
		failures.append("guard was not released with the down input")
	player.runtime_state.guard_durability = 64.0
	player.runtime_state.special_cooldown_ticks = 9
	player.runtime_state.ultimate_gauge = 33.0
	var hud_state := player.snapshot()
	if hud_state.guard_durability != 64.0 or hud_state.special_cooldown_ticks != 9 or hud_state.ultimate_gauge != 33.0:
		failures.append("combat resources were not exposed through snapshot")
	if not InputMap.has_action(&"evade") or not InputMap.has_action(&"ultimate"):
		failures.append("desktop compatibility actions for evade and ultimate are missing")

	# Data links own hit-only branches and cancellation; a finisher remains final.
	controller.reset_match()
	var opening: AttackData = player.runtime_profile.move_set.attacks().filter(func(attack: AttackData) -> bool: return attack.attack_id == &"ja-hyun-light-01")[0]
	player.call("_start_attack", opening, CombatIntent.Direction.NEUTRAL, controller.rules)
	player.state = FighterController.State.ATTACK_RECOVERY
	player.attack_phase_tick = 1
	player.attack_landed = false
	player.consume_intent(CombatIntent.new(1, player.fighter_id, &"attack_special", CombatIntent.Direction.NEUTRAL, CombatIntent.Edge.PRESS), controller.rules)
	if player.active_attack == null or player.active_attack.attack_id != opening.attack_id:
		failures.append("hit-only special cancel accepted a whiff")
	player.attack_landed = true
	player.consume_intent(CombatIntent.new(1, player.fighter_id, &"attack_special", CombatIntent.Direction.NEUTRAL, CombatIntent.Edge.PRESS), controller.rules)
	if player.active_attack == null or player.active_attack.action_id != &"attack_special":
		failures.append("data special cancel did not start the next move")
	var finisher: AttackData = player.runtime_profile.move_set.attacks().filter(func(attack: AttackData) -> bool: return attack.attack_id == &"ja-hyun-light-03")[0]
	player.call("_start_attack", finisher, CombatIntent.Direction.NEUTRAL, controller.rules)
	player.state = FighterController.State.ATTACK_RECOVERY
	player.attack_phase_tick = 1
	player.attack_landed = true
	player.consume_intent(CombatIntent.new(1, player.fighter_id, &"evade", CombatIntent.Direction.NEUTRAL, CombatIntent.Edge.PRESS), controller.rules)
	if player.active_attack == null or player.active_attack.attack_id != finisher.attack_id:
		failures.append("finisher cancellation was accepted")

	# A one-use OnDeath revive grants one stock and enters the ordinary delay.
	var revive_accessory := load("res://assets/loadouts/fixtures/phoenix_revive_accessory.tres") as AccessoryData
	player.runtime_profile.combat_effects = revive_accessory.combat_effects.duplicate(true)
	player.stocks = 1
	player.current_hp = 1.0
	player.lose_stock(controller.rules)
	controller.call("_resolve_final_losses")
	if player.stocks != 1 or player.state != FighterController.State.RING_OUT or player.current_hp != 35.0 or not player.runtime_state.revive_used:
		failures.append("OnDeath revive did not use normal stock return flow")
	player.state = FighterController.State.IDLE
	player.lose_stock(controller.rules)
	controller.call("_resolve_final_losses")
	if player.state != FighterController.State.MATCH_ENDED: failures.append("revive was consumed more than once")

	# Effect recursion uses the cause ID guard and cannot reflect indefinitely.
	controller.reset_match()
	var thorns := load("res://assets/loadouts/fixtures/thorns_accessory.tres") as AccessoryData
	dummy.runtime_profile.combat_effects = thorns.combat_effects.duplicate(true)
	var hp_before := player.current_hp
	EffectControllerScript.dispatch(EffectData.Trigger.ON_DAMAGED, dummy, player, controller.rules, &"fixture-thorns")
	if player.current_hp != hp_before: failures.append("effect reflected its own cause")
	EffectControllerScript.dispatch(EffectData.Trigger.ON_DAMAGED, dummy, player, controller.rules, &"other-cause")
	if player.current_hp != hp_before - 3.0: failures.append("effect reflection was not applied")

	instance.queue_free()
	if failures.is_empty():
		print("COMBAT_OVERHAUL_CONTRACT: PASS")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("COMBAT_OVERHAUL_CONTRACT: FAIL (%d)" % failures.size())
		quit(1)
