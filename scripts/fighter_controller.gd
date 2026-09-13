class_name FighterController
extends CharacterBody2D

## Fixed-tick Phase 1 fighter. Geometry and visual state mirror the authority
## state for debugging, but physics overlap and animation never decide hits.
enum State { SPAWNING, IDLE, RUN, JUMP, FALL, DASH, GUARD, GUARD_BREAK, EVADE_GROUND, EVADE_AIR, ATTACK_STARTUP, ATTACK_ACTIVE, ATTACK_RECOVERY, HITSTUN, KNOCKBACK, RING_OUT, MATCH_ENDED }

@export var fighter_id: StringName
@export var character_data: CharacterData
var attacks: Array[AttackData] = []
var combo_count: int = 2
@export var controlled_by_input: bool = false
@export var body_color: Color = Color("43c782")

var state: State = State.SPAWNING
var damage_percent := 0.0
var stocks := 3
var facing := 1
var input_direction: CombatIntent.Direction = CombatIntent.Direction.NEUTRAL
var spawn_position: Vector2
var spawn_facing := 1
var air_jumps_remaining := 0
var aerial_attacks_remaining := 2
var up_special_available := true
var launcher_jump_available := false
var invulnerability_ticks := 0
var respawn_ticks := 0
var hitstun_ticks := 0
var dash_ticks := 0
var guard_durability := 0.0
var guard_regen_delay_ticks := 0
var guard_held := false
var guard_break_ticks := 0
var guard_hold_ticks := 0
var evade_ticks := 0
var evade_elapsed_ticks := 0
var evade_cooldown_ticks := 0
var evade_direction := 1
var action_held := false
var action_hold_direction: CombatIntent.Direction = CombatIntent.Direction.NEUTRAL
var aerial_evades_remaining := 0
var attack_damage_scale := 1.0
var special_cooldowns: Dictionary = {}
var ultimate_gauge := 0.0
var ultimate_used := false
var ultimate_followup_pending := false
var active_attack: AttackData
var attack_phase_tick := 0
var attack_landed := false
var combo_index := 0
var buffered_intent: CombatIntent
var activation_serial := 0
var diagnostic := ""
var locked_facing := 1
var locked_direction: CombatIntent.Direction = CombatIntent.Direction.NEUTRAL
var runtime_profile: RuntimeCombatProfile
var passive_cooldowns: Dictionary = {}
var passive_damage_multiplier := 1.0
var passive_damage_ticks := 0


func _ready() -> void:
	spawn_position = global_position
	spawn_facing = facing
	if character_data == null:
		push_error("Fighter scene requires CharacterData: %s" % fighter_id)
		set_physics_process(false)
		return
	# Expose authored external moves to contract inspection; authority still starts
	# only after MatchController injects a RuntimeCombatProfile.
	if character_data.base_move_set != null:
		attacks = character_data.base_move_set.attacks()
		combo_count = character_data.base_move_set.combo_count
	state = State.SPAWNING
	_sync_debug_hitbox()
	queue_redraw()


func configure_profile(profile: RuntimeCombatProfile) -> bool:
	if profile == null or profile.character_id != fighter_id or not profile.is_valid_definition():
		diagnostic = "invalid_runtime_profile"
		return false
	runtime_profile = profile
	attacks = profile.move_set.attacks()
	combo_count = profile.move_set.combo_count
	air_jumps_remaining = _stats().air_jump_count
	guard_durability = 0.0
	state = State.IDLE
	set_physics_process(true)
	return true


func reset_for_match(rules: CombatRules) -> void:
	if runtime_profile == null:
		return
	damage_percent = 0.0
	stocks = rules.stocks_per_fighter
	global_position = spawn_position
	velocity = Vector2.ZERO
	facing = spawn_facing
	locked_facing = spawn_facing
	locked_direction = CombatIntent.Direction.NEUTRAL
	active_attack = null
	buffered_intent = null
	combo_index = 0
	activation_serial = 0
	attack_phase_tick = 0
	attack_landed = false
	dash_ticks = 0
	diagnostic = ""
	input_direction = CombatIntent.Direction.NEUTRAL
	air_jumps_remaining = _stats().air_jump_count
	aerial_attacks_remaining = 2
	up_special_available = true
	launcher_jump_available = false
	guard_durability = _tuning(rules).guard_max_durability
	guard_regen_delay_ticks = 0
	guard_held = false
	guard_break_ticks = 0
	guard_hold_ticks = 0
	evade_ticks = 0
	evade_elapsed_ticks = 0
	evade_cooldown_ticks = 0
	evade_direction = facing
	action_held = false
	action_hold_direction = CombatIntent.Direction.NEUTRAL
	aerial_evades_remaining = _tuning(rules).aerial_evades_per_airtime
	attack_damage_scale = 1.0
	special_cooldowns.clear()
	ultimate_gauge = 0.0
	ultimate_used = false
	ultimate_followup_pending = false
	passive_cooldowns.clear()
	passive_damage_multiplier = 1.0
	passive_damage_ticks = 0
	invulnerability_ticks = 0
	respawn_ticks = 0
	hitstun_ticks = 0
	state = State.IDLE
	# CharacterBody2D retains floor contact from its last physics move. Refreshing
	# at the spawn coordinate keeps a reset/replay from inheriting a prior match's
	# grounded state before its first intent is consumed.
	move_and_slide()
	_sync_debug_hitbox()


func consume_intent(intent: CombatIntent, rules: CombatRules) -> void:
	if intent.action_id == &"move":
		input_direction = CombatIntent.Direction.NEUTRAL if intent.edge == CombatIntent.Edge.RELEASE else intent.direction
		return
	if intent.action_id == &"dash":
		_consume_action_intent(intent, rules)
		return
	if intent.edge != CombatIntent.Edge.PRESS or state in [State.SPAWNING, State.RING_OUT, State.MATCH_ENDED, State.HITSTUN, State.KNOCKBACK, State.GUARD, State.GUARD_BREAK, State.EVADE_GROUND, State.EVADE_AIR]:
		return
	if _try_cancel(intent): return
	if intent.action_id == &"ultimate":
		_try_ultimate(intent, rules)
		return
	if intent.action_id == &"jump":
		_try_jump()
		return
	if intent.action_id not in [&"attack_light", &"attack_heavy", &"attack_special"]:
		return
	var next := _select_attack(intent)
	if next == null:
		return
	if active_attack != null:
		var in_link_window := state == State.ATTACK_RECOVERY and attack_phase_tick < rules.combo_link_window_ticks
		if in_link_window and not active_attack.is_finisher and buffered_intent == null:
			if intent.action_id == &"attack_light" or attack_landed:
				buffered_intent = intent
		return
	_start_attack(next, intent.direction)


func step_tick(rules: CombatRules) -> void:
	if runtime_profile == null:
		return
	diagnostic = ""
	_step_resource_timers()
	if invulnerability_ticks > 0:
		invulnerability_ticks -= 1
	_step_guard_hold_start(rules)
	if state == State.RING_OUT:
		respawn_ticks -= 1
		if respawn_ticks <= 0:
			_respawn(rules)
		_finish_tick()
		return
	if state == State.GUARD:
		_step_guard(rules)
		_finish_tick()
		return
	if state == State.GUARD_BREAK:
		_step_guard_break(rules)
		_finish_tick()
		return
	if state in [State.EVADE_GROUND, State.EVADE_AIR]:
		_step_evade(rules)
		_finish_tick()
		return
	if state in [State.HITSTUN, State.KNOCKBACK]:
		hitstun_ticks -= 1
		_apply_gravity(rules)
		move_and_slide()
		if hitstun_ticks <= 0:
			state = State.IDLE if is_on_floor() else State.FALL
		_finish_tick()
		return
	if active_attack != null:
		_advance_attack(rules)
		_apply_gravity(rules)
		move_and_slide()
	else:
		_step_movement(rules)
	_finish_tick()


func get_hitbox_rect() -> Rect2:
	if state != State.ATTACK_ACTIVE or active_attack == null:
		return Rect2()
	var offset := active_attack.hitbox_offset
	var resolved_direction := active_attack.input_direction
	if resolved_direction == AttackData.InputDirection.OMNI:
		resolved_direction = _relative_direction(locked_direction)
	if resolved_direction == AttackData.InputDirection.UP:
		offset = Vector2(0.0, -86.0)
	elif resolved_direction == AttackData.InputDirection.DOWN:
		offset = Vector2(0.0, 20.0)
	else:
		offset.x *= locked_facing
	return Rect2(global_position + offset - active_attack.hitbox_size * 0.5, active_attack.hitbox_size)


func get_hurtbox_rect() -> Rect2:
	return Rect2(global_position + Vector2(-27.0, -82.0), Vector2(54.0, 96.0))


func register_landed_hit(attack: AttackData) -> void:
	attack_landed = true
	if attack.is_launcher:
		launcher_jump_available = true
	if attack.is_ultimate() and not attack.ultimate_followup:
		ultimate_followup_pending = true
	_trigger_passives(PassiveData.Trigger.ON_ATTACK_HIT, attack)


func is_invulnerable() -> bool:
	if invulnerability_ticks > 0:
		return true
	return state in [State.EVADE_GROUND, State.EVADE_AIR] and _active_tuning().is_evade_invulnerable(evade_elapsed_ticks)


func resolved_attack_damage() -> float:
	return active_attack.damage * attack_damage_scale if active_attack != null else 0.0


func resolved_attack_base_knockback() -> float:
	return active_attack.base_knockback if active_attack != null else 0.0


func add_ultimate_from_damage(damage: float, dealt: bool) -> void:
	if damage <= 0.0 or ultimate_used:
		return
	var tuning := _active_tuning()
	var multiplier := tuning.ultimate_dealt_damage_gain_multiplier if dealt else tuning.ultimate_received_damage_gain_multiplier
	ultimate_gauge = minf(tuning.ultimate_max_gauge, ultimate_gauge + damage * multiplier)


func apply_hit(attack: AttackData, knockback_velocity: Vector2, stun_ticks: int, resolved_damage := -1.0) -> void:
	damage_percent += attack.damage if resolved_damage < 0.0 else resolved_damage
	velocity = knockback_velocity
	hitstun_ticks = stun_ticks
	active_attack = null
	buffered_intent = null
	air_jumps_remaining = 0
	launcher_jump_available = false
	guard_held = false
	action_held = false
	guard_regen_delay_ticks = 0
	state = State.KNOCKBACK


func apply_guarded_hit(attack: AttackData, rules: CombatRules, resolved_damage := -1.0) -> void:
	if state != State.GUARD:
		return
	_trigger_passives(PassiveData.Trigger.ON_GUARDED_HIT, attack)
	var tuning := _tuning(rules)
	var damage := attack.damage if resolved_damage < 0.0 else resolved_damage
	var cost := maxf(tuning.guard_hit_minimum_cost, damage * tuning.guard_hit_damage_multiplier * attack.guard_damage_multiplier)
	guard_durability = maxf(0.0, guard_durability - cost)
	guard_regen_delay_ticks = tuning.guard_regen_delay_ticks
	if is_zero_approx(guard_durability):
		_begin_guard_break(rules)


func release_transient_input(rules: CombatRules) -> void:
	input_direction = CombatIntent.Direction.NEUTRAL
	buffered_intent = null
	action_held = false
	action_hold_direction = CombatIntent.Direction.NEUTRAL
	guard_hold_ticks = 0
	if state == State.GUARD:
		guard_held = false
		guard_regen_delay_ticks = _tuning(rules).guard_regen_delay_ticks
		state = State.IDLE if is_on_floor() else State.FALL


func ring_out(rules: CombatRules) -> bool:
	if state == State.RING_OUT:
		return false
	stocks -= 1
	damage_percent = 0.0
	velocity = Vector2.ZERO
	active_attack = null
	buffered_intent = null
	combo_index = 0
	input_direction = CombatIntent.Direction.NEUTRAL
	launcher_jump_available = false
	guard_held = false
	action_held = false
	guard_hold_ticks = 0
	guard_regen_delay_ticks = 0
	aerial_evades_remaining = 0
	ultimate_gauge = 0.0
	ultimate_used = false
	ultimate_followup_pending = false
	respawn_ticks = rules.respawn_delay_ticks
	state = State.RING_OUT
	return true


func begin_sudden_death(rules: CombatRules) -> void:
	stocks = 1
	damage_percent = 0.0
	velocity = Vector2.ZERO
	launcher_jump_available = false
	guard_held = false
	action_held = false
	aerial_evades_remaining = 0
	ultimate_gauge = 0.0
	ultimate_used = false
	ultimate_followup_pending = false
	respawn_ticks = rules.respawn_delay_ticks
	state = State.RING_OUT


func snapshot() -> Dictionary:
	return {
		"id": String(fighter_id), "state": State.keys()[state], "damage_percent": snappedf(damage_percent, 0.001),
		"stocks": stocks, "position": Vector2(snappedf(global_position.x, 0.001), snappedf(global_position.y, 0.001)),
		"velocity": Vector2(snappedf(velocity.x, 0.001), snappedf(velocity.y, 0.001)), "facing": facing,
		"attack_id": &"" if active_attack == null else active_attack.attack_id, "attack_phase_tick": attack_phase_tick,
		"invulnerability_ticks": invulnerability_ticks, "respawn_ticks": respawn_ticks,
		"air_jumps": air_jumps_remaining, "air_attacks": aerial_attacks_remaining, "up_special": up_special_available,
		"guard_durability": snappedf(guard_durability, 0.001), "guard_regen_delay_ticks": guard_regen_delay_ticks,
		"guard_max_durability": snappedf(_active_tuning().guard_max_durability, 0.001),
		"evade_available": evade_cooldown_ticks <= 0, "evade_cooldown_ticks": evade_cooldown_ticks, "aerial_evades": aerial_evades_remaining,
		"ultimate_gauge": snappedf(ultimate_gauge, 0.001), "ultimate_max_gauge": snappedf(_active_tuning().ultimate_max_gauge, 0.001), "ultimate_used": ultimate_used,
	}


func _try_jump() -> void:
	if active_attack != null:
		if not (state == State.ATTACK_RECOVERY and attack_landed and active_attack.is_launcher and launcher_jump_available):
			return
		active_attack = null
		launcher_jump_available = false
	if state in [State.DASH, State.GUARD, State.GUARD_BREAK, State.EVADE_GROUND, State.EVADE_AIR]:
		return
	if is_on_floor():
		velocity.y = -_stats().jump_velocity
		state = State.JUMP
	elif air_jumps_remaining > 0 or launcher_jump_available:
		if launcher_jump_available:
			launcher_jump_available = false
		else:
			air_jumps_remaining -= 1
		velocity.y = -_stats().jump_velocity
		state = State.JUMP


func _try_dash() -> void:
	if active_attack != null or not is_on_floor():
		return
	var horizontal := _horizontal_input()
	var direction := horizontal if horizontal != 0 else facing
	facing = direction
	velocity.x = _stats().dash_speed * direction
	dash_ticks = maxi(1, roundi(_stats().dash_duration_seconds * 60.0))
	state = State.DASH


func _step_resource_timers() -> void:
	for passive_id: Variant in passive_cooldowns.keys():
		passive_cooldowns[passive_id] = maxi(0, int(passive_cooldowns[passive_id]) - 1)
	if passive_damage_ticks > 0:
		passive_damage_ticks -= 1
		if passive_damage_ticks == 0: passive_damage_multiplier = 1.0
	if evade_cooldown_ticks > 0:
		evade_cooldown_ticks -= 1
	for group: StringName in special_cooldowns.keys():
		var remaining := int(special_cooldowns[group]) - 1
		if remaining <= 0:
			special_cooldowns.erase(group)
		else:
			special_cooldowns[group] = remaining


func _step_guard_hold_start(rules: CombatRules) -> void:
	if not action_held or action_hold_direction != CombatIntent.Direction.NEUTRAL:
		guard_hold_ticks = 0
		return
	if state not in [State.IDLE, State.RUN] or not is_on_floor():
		return
	guard_hold_ticks += 1
	if guard_hold_ticks >= _tuning(rules).guard_hold_delay_ticks:
		guard_held = true
		velocity.x = 0.0
		state = State.GUARD


func _consume_action_intent(intent: CombatIntent, rules: CombatRules) -> void:
	if intent.edge == CombatIntent.Edge.RELEASE:
		action_held = false
		action_hold_direction = CombatIntent.Direction.NEUTRAL
		if state == State.GUARD:
			guard_held = false
			guard_regen_delay_ticks = _tuning(rules).guard_regen_delay_ticks
			state = State.IDLE if is_on_floor() else State.FALL
		guard_hold_ticks = 0
		return
	if state in [State.SPAWNING, State.RING_OUT, State.MATCH_ENDED, State.HITSTUN, State.KNOCKBACK, State.GUARD_BREAK]:
		return
	if intent.edge == CombatIntent.Edge.HOLD:
		action_held = true
		action_hold_direction = intent.direction
		if state == State.GUARD and intent.direction == CombatIntent.Direction.NEUTRAL:
			guard_held = true
		return
	if intent.edge != CombatIntent.Edge.PRESS or active_attack != null:
		return
	action_held = true
	action_hold_direction = intent.direction
	if is_on_floor():
		if intent.direction == CombatIntent.Direction.NEUTRAL:
			guard_hold_ticks = 0
			return
		if intent.direction in [CombatIntent.Direction.LEFT, CombatIntent.Direction.RIGHT]:
			if evade_cooldown_ticks > 0:
				return
			_start_evade(false, intent.direction, rules)
		return
	if aerial_evades_remaining <= 0:
		return
	_start_evade(true, intent.direction, rules)


func _start_evade(airborne: bool, direction: CombatIntent.Direction, rules: CombatRules) -> void:
	var tuning := _tuning(rules)
	evade_direction = -1 if direction == CombatIntent.Direction.LEFT else 1 if direction == CombatIntent.Direction.RIGHT else facing
	facing = evade_direction
	evade_ticks = tuning.evade_total_ticks
	evade_elapsed_ticks = 0
	evade_cooldown_ticks = tuning.evade_cooldown_ticks
	if airborne:
		aerial_evades_remaining -= 1
		state = State.EVADE_AIR
	else:
		state = State.EVADE_GROUND


func _try_ultimate(intent: CombatIntent, rules: CombatRules) -> void:
	if active_attack != null or ultimate_used:
		return
	var attack := _select_attack(intent)
	if attack == null or not attack.is_ultimate():
		return
	var cost := attack.ultimate_cost if attack.ultimate_cost > 0.0 else _tuning(rules).ultimate_max_gauge
	if ultimate_gauge < cost:
		diagnostic = "ultimate_not_ready"
		return
	ultimate_gauge = 0.0
	ultimate_used = true
	_start_attack(attack, intent.direction)


func _step_guard(rules: CombatRules) -> void:
	var tuning := _tuning(rules)
	if not is_on_floor() or not guard_held:
		guard_held = false
		guard_regen_delay_ticks = tuning.guard_regen_delay_ticks
		state = State.FALL if not is_on_floor() else State.IDLE
		return
	guard_durability = maxf(0.0, guard_durability - tuning.guard_hold_drain_per_tick(rules.physics_ticks_per_second))
	velocity.x = 0.0
	move_and_slide()
	if is_zero_approx(guard_durability):
		_begin_guard_break(rules)


func _begin_guard_break(rules: CombatRules) -> void:
	guard_held = false
	action_held = false
	guard_break_ticks = _tuning(rules).guard_break_ticks
	state = State.GUARD_BREAK


func _step_guard_break(rules: CombatRules) -> void:
	guard_break_ticks -= 1
	_apply_gravity(rules)
	move_and_slide()
	if guard_break_ticks <= 0:
		guard_durability = _tuning(rules).guard_max_durability
		guard_regen_delay_ticks = _tuning(rules).guard_regen_delay_ticks
		state = State.IDLE if is_on_floor() else State.FALL


func _step_evade(rules: CombatRules) -> void:
	var tuning := _tuning(rules)
	evade_ticks -= 1
	evade_elapsed_ticks += 1
	velocity.x = tuning.evade_speed * evade_direction
	if state == State.EVADE_AIR:
		_apply_gravity(rules)
	move_and_slide()
	if evade_ticks > 0:
		return
	_trigger_passives(PassiveData.Trigger.ON_EVADE_END, null)
	if action_held and action_hold_direction in [CombatIntent.Direction.LEFT, CombatIntent.Direction.RIGHT]:
		velocity.x = _stats().dash_speed * evade_direction
		dash_ticks = maxi(1, roundi(_stats().dash_duration_seconds * 60.0))
		state = State.DASH
		return
	state = State.IDLE if is_on_floor() else State.FALL


func _select_attack(intent: CombatIntent) -> AttackData:
	var context := AttackData.ActivationContext.GROUND if is_on_floor() else AttackData.ActivationContext.AIR
	if context == AttackData.ActivationContext.AIR and intent.action_id != &"attack_special" and aerial_attacks_remaining <= 0:
		return null
	var special_turn := intent.action_id == &"attack_special" and intent.direction in [CombatIntent.Direction.LEFT, CombatIntent.Direction.RIGHT]
	if special_turn:
		facing = 1 if intent.direction == CombatIntent.Direction.RIGHT else -1
	var relative := AttackData.InputDirection.FORWARD if special_turn else _relative_direction(intent.direction)
	if intent.action_id == &"attack_special" and relative == AttackData.InputDirection.UP and not up_special_available:
		return null
	if intent.action_id == &"attack_light" and context == AttackData.ActivationContext.GROUND and state != State.DASH and relative in [AttackData.InputDirection.NEUTRAL, AttackData.InputDirection.FORWARD, AttackData.InputDirection.BACK]:
		var wanted_step := clampi(combo_index + 1, 1, combo_count)
		for attack: AttackData in attacks:
			if attack.action_id == intent.action_id and attack.combo_step == wanted_step:
				return attack
	for attack: AttackData in attacks:
		if attack.action_id != intent.action_id or (attack.activation_context != context and attack.activation_context != AttackData.ActivationContext.BOTH):
			continue
		if attack.ultimate_followup:
			continue
		if attack.requires_dash != (state == State.DASH):
			continue
		if attack.combo_step > 0:
			continue
		if attack.action_id == &"attack_special" and not attack.cooldown_group.is_empty() and int(special_cooldowns.get(attack.cooldown_group, 0)) > 0:
			diagnostic = "special_cooldown_active"
			continue
		if _direction_matches(attack.input_direction, relative):
			return attack
	return null


func _start_attack(next: AttackData, direction: CombatIntent.Direction) -> void:
	attack_damage_scale = passive_damage_multiplier
	passive_damage_multiplier = 1.0
	passive_damage_ticks = 0
	active_attack = next
	activation_serial += 1
	attack_phase_tick = 0
	attack_landed = false
	locked_facing = facing
	locked_direction = direction
	if next.combo_step > 0:
		combo_index = next.combo_step
	else:
		combo_index = 0
	if next.activation_context == AttackData.ActivationContext.AIR and next.action_id in [&"attack_light", &"attack_heavy"]:
		aerial_attacks_remaining -= 1
	if next.action_id == &"attack_special" and next.input_direction == AttackData.InputDirection.UP:
		up_special_available = false
		var impulse_scale := _active_tuning().aerial_special_impulse_multiplier if not is_on_floor() else 1.0
		velocity += next.self_impulse * impulse_scale
	if next.action_id == &"attack_special" and not next.cooldown_group.is_empty():
		special_cooldowns[next.cooldown_group] = next.cooldown_ticks
	state = State.ATTACK_STARTUP


func _try_cancel(intent: CombatIntent) -> bool:
	if active_attack == null or state != State.ATTACK_RECOVERY or not attack_landed or active_attack.is_finisher or active_attack.is_ultimate(): return false
	var context := AttackData.ActivationContext.GROUND if is_on_floor() else AttackData.ActivationContext.AIR
	for rule: CancelRuleData in runtime_profile.cancel_rules:
		if rule.from_action_id != active_attack.action_id or rule.to_action_id != intent.action_id or attack_phase_tick < rule.recovery_start_tick or attack_phase_tick > rule.recovery_end_tick: continue
		if rule.from_context != AttackData.ActivationContext.BOTH and rule.from_context != context: continue
		var next := _select_attack(intent)
		if next == null: return false
		active_attack = null
		_start_attack(next, intent.direction)
		return true
	return false


func _trigger_passives(trigger: PassiveData.Trigger, attack: AttackData) -> void:
	if runtime_profile == null: return
	for passive: PassiveData in runtime_profile.passives:
		if passive.trigger != trigger or int(passive_cooldowns.get(passive.passive_id, 0)) > 0: continue
		if not passive.action_filter.is_empty() and (attack == null or attack.action_id != passive.action_filter): continue
		if passive.requires_dash and (attack == null or not attack.requires_dash): continue
		passive_cooldowns[passive.passive_id] = passive.cooldown_ticks
		match passive.effect:
			PassiveData.Effect.NEXT_ATTACK_DAMAGE_MULTIPLIER:
				passive_damage_multiplier = passive.value
				passive_damage_ticks = passive.duration_ticks
			PassiveData.Effect.SPECIAL_COOLDOWN_REDUCTION:
				for group: Variant in special_cooldowns.keys(): special_cooldowns[group] = maxi(0, int(special_cooldowns[group]) - roundi(passive.value))
			PassiveData.Effect.GUARD_RESTORE:
				guard_durability = minf(_active_tuning().guard_max_durability, guard_durability + passive.value)
			PassiveData.Effect.EVADE_COOLDOWN_REDUCTION:
				evade_cooldown_ticks = maxi(0, evade_cooldown_ticks - roundi(passive.value))


func _advance_attack(rules: CombatRules) -> void:
	attack_phase_tick += 1
	var tuning := _tuning(rules)
	var startup_limit := active_attack.startup_ticks
	var active_limit := active_attack.active_ticks
	var recovery_limit := active_attack.recovery_ticks
	if state == State.ATTACK_STARTUP and attack_phase_tick >= startup_limit:
		state = State.ATTACK_ACTIVE
		attack_phase_tick = 0
	elif state == State.ATTACK_ACTIVE and attack_phase_tick >= active_limit:
		if ultimate_followup_pending and active_attack.is_ultimate() and not active_attack.ultimate_followup:
			ultimate_followup_pending = false
			var followup := _ultimate_followup()
			if followup != null:
				_start_attack(followup, locked_direction)
				return
		state = State.ATTACK_RECOVERY
		attack_phase_tick = 0
	elif state == State.ATTACK_RECOVERY and attack_phase_tick >= recovery_limit:
		var queued := buffered_intent
		active_attack = null
		attack_damage_scale = 1.0
		buffered_intent = null
		if queued != null:
			var next := _select_attack(queued)
			if next != null:
				_start_attack(next, queued.direction)
				return
		combo_index = 0
		state = State.IDLE if is_on_floor() else State.FALL


func _step_movement(rules: CombatRules) -> void:
	var tuning := _tuning(rules)
	_apply_gravity(rules)
	if guard_regen_delay_ticks > 0:
		guard_regen_delay_ticks -= 1
	elif guard_durability < tuning.guard_max_durability:
		guard_durability = minf(tuning.guard_max_durability, guard_durability + tuning.guard_regen_per_tick(rules.physics_ticks_per_second))
	if state == State.DASH:
		dash_ticks -= 1
		if dash_ticks <= 0:
			state = State.IDLE
	else:
		var horizontal := _horizontal_input()
		if horizontal != 0:
			facing = horizontal
		var desired := float(horizontal) * (_stats().ground_speed if is_on_floor() else _stats().air_speed)
		var acceleration := rules.ground_acceleration if is_on_floor() else rules.air_acceleration
		if horizontal == 0 and is_on_floor():
			acceleration = rules.ground_deceleration
		velocity.x = move_toward(velocity.x, desired, acceleration / float(rules.physics_ticks_per_second))
	move_and_slide()
	if is_on_floor():
		air_jumps_remaining = _stats().air_jump_count
		aerial_attacks_remaining = 2
		aerial_evades_remaining = tuning.aerial_evades_per_airtime
		up_special_available = true
		launcher_jump_available = false
		if state != State.DASH:
			state = State.RUN if _horizontal_input() != 0 else State.IDLE
	elif velocity.y < 0.0:
		state = State.JUMP
	else:
		state = State.FALL


func _apply_gravity(rules: CombatRules) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + _stats().gravity / float(rules.physics_ticks_per_second), rules.max_fall_speed)


func _respawn(rules: CombatRules) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	invulnerability_ticks = rules.respawn_invulnerability_ticks
	air_jumps_remaining = _stats().air_jump_count
	aerial_attacks_remaining = 2
	up_special_available = true
	launcher_jump_available = false
	guard_durability = _tuning(rules).guard_max_durability
	guard_regen_delay_ticks = 0
	guard_held = false
	action_held = false
	aerial_evades_remaining = _tuning(rules).aerial_evades_per_airtime
	evade_cooldown_ticks = 0
	special_cooldowns.clear()
	ultimate_gauge = 0.0
	ultimate_used = false
	ultimate_followup_pending = false
	state = State.IDLE


func _relative_direction(direction: CombatIntent.Direction) -> AttackData.InputDirection:
	match direction:
		CombatIntent.Direction.UP: return AttackData.InputDirection.UP
		CombatIntent.Direction.DOWN: return AttackData.InputDirection.DOWN
		CombatIntent.Direction.LEFT: return AttackData.InputDirection.FORWARD if facing < 0 else AttackData.InputDirection.BACK
		CombatIntent.Direction.RIGHT: return AttackData.InputDirection.FORWARD if facing > 0 else AttackData.InputDirection.BACK
		_: return AttackData.InputDirection.NEUTRAL


func _direction_matches(required: AttackData.InputDirection, actual: AttackData.InputDirection) -> bool:
	if required == AttackData.InputDirection.ANY_HORIZONTAL:
		return actual in [AttackData.InputDirection.NEUTRAL, AttackData.InputDirection.FORWARD, AttackData.InputDirection.BACK]
	if required == AttackData.InputDirection.OMNI:
		return true
	return required == actual


func _horizontal_input() -> int:
	if input_direction == CombatIntent.Direction.LEFT: return -1
	if input_direction == CombatIntent.Direction.RIGHT: return 1
	return 0


func _stats() -> CharacterStats:
	return runtime_profile.stats if runtime_profile != null else character_data.base_stats


func _active_tuning() -> CombatTuningData:
	if runtime_profile != null and runtime_profile.combat_tuning != null:
		return runtime_profile.combat_tuning
	return CombatTuningData.new()


func _tuning(rules: CombatRules) -> CombatTuningData:
	if runtime_profile != null and runtime_profile.combat_tuning != null:
		return runtime_profile.combat_tuning
	return rules.combat_tuning


func _cooldown_snapshot() -> Dictionary:
	var result := {}
	var keys: Array = special_cooldowns.keys()
	keys.sort()
	for key: StringName in keys:
		result[String(key)] = int(special_cooldowns[key])
	return result


func _ultimate_followup() -> AttackData:
	for attack: AttackData in attacks:
		if attack.is_ultimate() and attack.ultimate_followup:
			return attack
	return null


func _sync_debug_hitbox() -> void:
	var shape_node := get_node_or_null("Hitbox/CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	shape_node.disabled = state != State.ATTACK_ACTIVE or active_attack == null
	if not shape_node.disabled:
		var rect_shape := shape_node.shape as RectangleShape2D
		rect_shape.size = active_attack.hitbox_size
		shape_node.position = get_hitbox_rect().get_center() - global_position


func _finish_tick() -> void:
	_sync_debug_hitbox()
	queue_redraw()


func _draw() -> void:
	var color := body_color
	if invulnerability_ticks > 0 and invulnerability_ticks % 6 < 3: color = Color.WHITE
	if state in [State.HITSTUN, State.KNOCKBACK]: color = Color("ffdf5a")
	if state == State.GUARD: color = Color("4d8dff")
	if state == State.GUARD_BREAK: color = Color("ff6b6b")
	if state in [State.EVADE_GROUND, State.EVADE_AIR]: color = Color("b883ff")
	if active_attack != null and active_attack.is_ultimate(): color = Color("ffe45e")
	draw_rect(Rect2(-27, -82, 54, 96), color, true)
	draw_rect(Rect2(-27, -82, 54, 96), Color("122033"), false, 3.0)
	draw_line(Vector2.ZERO, Vector2(24.0 * facing, 0.0), Color.WHITE, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(-24, -88), State.keys()[state], HORIZONTAL_ALIGNMENT_CENTER, 48, 11, Color.WHITE)
	if state in [State.GUARD, State.GUARD_BREAK]:
		draw_string(ThemeDB.fallback_font, Vector2(-24, 28), "G %.0f" % guard_durability, HORIZONTAL_ALIGNMENT_CENTER, 48, 11, Color.WHITE)
	if state == State.ATTACK_ACTIVE:
		var rect := get_hitbox_rect()
		draw_rect(Rect2(to_local(rect.position), rect.size), Color(1, 0.25, 0.25, 0.25), true)
		draw_rect(Rect2(to_local(rect.position), rect.size), Color("ff5364"), false, 2.0)
