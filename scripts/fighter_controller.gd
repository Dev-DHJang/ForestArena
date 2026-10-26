class_name FighterController
extends CharacterBody2D

const TRAVEL_STRIKE_TICKS := 4

const ComboControllerScript = preload("res://scripts/combo_controller.gd")
const EffectControllerScript = preload("res://scripts/effect_controller.gd")
const EffectData = preload("res://scripts/data/combat_effect_data.gd")

## Fixed-tick Phase 1 fighter. Geometry and visual state mirror the authority
## state for debugging, but physics overlap and animation never decide hits.
signal presentation_event(event_id: StringName, payload: Dictionary)
## Local observation only; resets drawing clocks without adding combat state.
signal presentation_reset
## Local drawing notification after an effective hit sets its reaction.
signal hit_reaction_started

enum State { SPAWNING, IDLE, RUN, JUMP, FALL, DASH, EVADE, CHARGE, ATTACK_STARTUP, ATTACK_ACTIVE, ATTACK_RECOVERY, GUARD, HITSTUN, LAUNCH, KNOCK_DOWN, WAKE_UP, RING_OUT, DEAD, MATCH_ENDED }

@export var fighter_id: StringName
@export var character_data: CharacterData
var attacks: Array[AttackData] = []
var combo_count: int = 2
@export var controlled_by_input: bool = false
@export var body_color: Color = Color("43c782")
@export var show_debug_body := true

var state: State = State.SPAWNING
var runtime_state := RuntimeCombatState.new()
var current_hp: float:
	get: return runtime_state.current_hp
	set(value): runtime_state.current_hp = value
var stocks: int:
	get: return runtime_state.stocks
	set(value): runtime_state.stocks = value
var facing := 1
var input_direction: CombatIntent.Direction = CombatIntent.Direction.NEUTRAL
var spawn_position: Vector2
var air_jumps_remaining := 0
var aerial_attacks_remaining := 2
var up_special_available := true
var launcher_jump_available := false
var invulnerability_ticks: int:
	get: return runtime_state.invulnerability_ticks
	set(value): runtime_state.invulnerability_ticks = value
var respawn_ticks: int:
	get: return runtime_state.respawn_ticks
	set(value): runtime_state.respawn_ticks = value
var hitstun_ticks: int:
	get: return runtime_state.hitstun_ticks
	set(value): runtime_state.hitstun_ticks = value
var dash_ticks := 0
var active_attack: AttackData
var attack_phase_tick := 0
var attack_landed := false
var combo_index := 0
var buffered_intent: CombatIntent
var activation_serial := 0
## Defensive attack cancels allow movement immediately, but keep the original recovery before another attack.
var attack_restart_lock_ticks := 0
var diagnostic := ""
var locked_facing := 1
var locked_direction: CombatIntent.Direction = CombatIntent.Direction.NEUTRAL
var runtime_profile: RuntimeCombatProfile
var charge_attack: AttackData
var charge_direction: CombatIntent.Direction = CombatIntent.Direction.NEUTRAL
var air_light_used := false
var air_heavy_used := false
var air_lock := 0
var air_lock_ticks := 0
var air_lock_expired := false
var landing_knockdown_pending := false
var landing_down_ticks := 0
var wakeup_protection_ticks := 0
var pull_ticks_remaining := 0
var pull_anchor := Vector2.ZERO
var pull_speed := 0.0
var pull_stop_distance := 64.0
var attack_travel_active := false
var attack_target_id: StringName = &""
var attack_travel_end := Vector2.ZERO
var attack_strike_ready := false
var attack_travel_failed := false
var _attack_movement_started := false
var _simplified_combat := false


func _ready() -> void:
	spawn_position = global_position
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
	if profile == null or fighter_id.is_empty() or not profile.is_valid_definition():
		diagnostic = "invalid_runtime_profile"
		return false
	runtime_profile = profile
	attacks = profile.move_set.attacks()
	combo_count = profile.move_set.combo_count
	air_jumps_remaining = _stats().air_jump_count
	runtime_state.reset(_stats().max_hp, 3, 100.0)
	attack_restart_lock_ticks = 0
	_reset_air_status()
	_clear_attack_travel()
	state = State.IDLE
	set_physics_process(true)
	presentation_reset.emit()
	return true


func reset_for_match(rules: CombatRules) -> void:
	_simplified_combat = rules.simplified_combat
	_reset_air_status()
	_clear_attack_travel()
	set_collision_mask_value(4, true)
	if runtime_profile == null:
		return
	runtime_state.reset(_stats().max_hp, rules.stocks_per_fighter, rules.guard_max_durability)
	attack_restart_lock_ticks = 0
	global_position = spawn_position
	velocity = Vector2.ZERO
	active_attack = null
	buffered_intent = null
	combo_index = 0
	input_direction = CombatIntent.Direction.NEUTRAL
	air_jumps_remaining = _stats().air_jump_count
	aerial_attacks_remaining = 2
	up_special_available = true
	launcher_jump_available = false
	charge_attack = null
	charge_direction = CombatIntent.Direction.NEUTRAL
	invulnerability_ticks = 0
	respawn_ticks = 0
	hitstun_ticks = 0
	dash_ticks = 0
	attack_phase_tick = 0
	attack_landed = false
	state = State.IDLE
	_sync_debug_hitbox()
	presentation_reset.emit()


func consume_intent(intent: CombatIntent, rules: CombatRules) -> void:
	_simplified_combat = rules.simplified_combat
	if _simplified_combat:
		if intent.action_id in [&"dash", &"evade", &"ultimate"]: return
		if (air_lock == 2 or landing_down_ticks > 0) and intent.action_id != &"move": return
		if air_lock == 1 and intent.action_id in [&"jump", &"attack_light", &"attack_heavy", &"attack_special"]: return
	if state in [State.SPAWNING, State.RING_OUT, State.DEAD, State.MATCH_ENDED]: return
	if intent.action_id == &"move":
		input_direction = CombatIntent.Direction.NEUTRAL if intent.edge == CombatIntent.Edge.RELEASE else intent.direction
		if intent.edge == CombatIntent.Edge.RELEASE and state == State.GUARD:
			runtime_state.guarding = false
			state = State.IDLE if is_on_floor() else State.FALL
		return
	# Direction releases can still clear a held input, but no action (including
	# ultimate or platform drop) may bypass an effective hit's action lock.
	if state in [State.HITSTUN, State.LAUNCH, State.KNOCK_DOWN]: return
	if active_attack != null and intent.edge == CombatIntent.Edge.PRESS and _try_cancel(intent, rules):
		return
	if attack_restart_lock_ticks > 0 and intent.action_id in [&"attack_light", &"attack_heavy", &"attack_special", &"ultimate"]:
		return
	if intent.action_id == &"guard":
		if is_on_floor() and state in [State.IDLE, State.RUN]:
			runtime_state.guarding = true
			state = State.GUARD
		return
	if intent.action_id == &"drop_platform":
		_try_drop_platform(rules)
		return
	if intent.action_id == &"evade":
		_try_evade(rules)
		return
	if intent.action_id == &"ultimate":
		_try_ultimate(intent, rules)
		return
	if state == State.CHARGE:
		if intent.action_id == &"attack_heavy" and intent.edge == CombatIntent.Edge.RELEASE:
			_release_charge(rules)
		return
	if intent.edge != CombatIntent.Edge.PRESS or state in [State.SPAWNING, State.RING_OUT, State.DEAD, State.MATCH_ENDED, State.HITSTUN, State.LAUNCH, State.KNOCK_DOWN]:
		return
	if intent.action_id == &"jump":
		_try_jump(rules)
		return
	if intent.action_id == &"dash":
		_try_dash()
		return
	if not _simplified_combat and intent.action_id == &"attack_heavy" and active_attack == null and is_on_floor():
		_start_charge(intent)
		return
	if intent.action_id not in [&"attack_light", &"attack_heavy", &"attack_special"]:
		return
	if active_attack != null:
		var linked := ComboControllerScript.linked_attack(runtime_profile.move_set, active_attack, intent, _combo_link_tick(), attack_landed)
		if state in [State.ATTACK_ACTIVE, State.ATTACK_RECOVERY] and linked != null and buffered_intent == null:
			buffered_intent = intent
		return
	var next := _select_attack(intent)
	if next == null: return
	if next.action_id == &"attack_special" and runtime_state.special_cooldown_ticks > 0: return
	_start_attack(next, intent.direction, rules)


func step_tick(rules: CombatRules) -> void:
	_simplified_combat = rules.simplified_combat
	if runtime_profile == null:
		return
	if state in [State.DEAD, State.MATCH_ENDED]:
		velocity = Vector2.ZERO
		input_direction = CombatIntent.Direction.NEUTRAL
		_finish_tick()
		return
	diagnostic = ""
	if wakeup_protection_ticks > 0: wakeup_protection_ticks -= 1
	if air_lock_ticks > 0:
		air_lock_ticks -= 1
		if air_lock_ticks == 0:
			air_lock = 0
			landing_knockdown_pending = false
			air_lock_expired = true
	if pull_ticks_remaining > 0: _step_pull()
	if attack_restart_lock_ticks > 0: attack_restart_lock_ticks -= 1
	if invulnerability_ticks > 0:
		invulnerability_ticks -= 1
	if runtime_state.special_cooldown_ticks > 0: runtime_state.special_cooldown_ticks -= 1
	if runtime_state.platform_drop_ticks > 0:
		runtime_state.platform_drop_ticks -= 1
		if runtime_state.platform_drop_ticks <= 0: set_collision_mask_value(4, true)
	if state == State.EVADE:
		runtime_state.evade_ticks -= 1
		move_and_slide()
		if runtime_state.evade_ticks <= 0: state = State.IDLE if is_on_floor() else State.FALL
		_finish_tick()
		return
	if state == State.GUARD:
		# Guard is sustained by a down hold. It does not become an ordinary run tick.
		move_and_slide()
		_finish_tick()
		return
	if state == State.CHARGE:
		var previous_charge := runtime_state.charge_ticks
		runtime_state.charge_ticks = mini(runtime_state.charge_ticks + 1, charge_attack.charge_max_ticks if charge_attack != null else 0)
		if charge_attack != null and previous_charge < charge_attack.charge_max_ticks and runtime_state.charge_ticks == charge_attack.charge_max_ticks:
			presentation_event.emit(&"charge_ready", {})
		velocity.x = move_toward(velocity.x, 0.0, rules.ground_deceleration / float(rules.physics_ticks_per_second))
		move_and_slide()
		_finish_tick()
		return
	if state != State.GUARD:
		runtime_state.guarding = false
		runtime_state.guard_durability = minf(rules.guard_max_durability, runtime_state.guard_durability + rules.guard_regen_per_tick)
	if state == State.RING_OUT:
		respawn_ticks -= 1
		if respawn_ticks <= 0:
			_respawn(rules)
		_finish_tick()
		return
	if state in [State.HITSTUN, State.LAUNCH, State.KNOCK_DOWN]:
		hitstun_ticks -= 1
		if landing_down_ticks > 0: landing_down_ticks = maxi(1, hitstun_ticks)
		# Ordinary grounded stagger slows with the same fixed-tick ground drag.
		# Launch/knock-down motion remains distinct and keeps its authored momentum.
		if state == State.HITSTUN and is_on_floor() and pull_ticks_remaining <= 0:
			velocity.x = move_toward(velocity.x, 0.0, rules.ground_deceleration / float(rules.physics_ticks_per_second))
		_apply_gravity(rules)
		move_and_slide()
		if hitstun_ticks <= 0:
			if state == State.KNOCK_DOWN:
				if landing_down_ticks > 0: wakeup_protection_ticks = 12
				landing_down_ticks = 0
				state = State.WAKE_UP
				EffectControllerScript.dispatch(EffectData.Trigger.ON_WAKE_UP, self, null, rules)
			else:
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


func _legacy_hitbox_rect() -> Rect2:
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


func get_pushbox_rect() -> Rect2:
	# Lower-body separation stays distinct from damage reception and attack reach.
	return Rect2(global_position + Vector2(-27.0, -58.0), Vector2(54.0, 72.0))


func ground_contact_offset_y() -> float:
	var body := get_node_or_null("Body") as CollisionShape2D
	if body == null or not body.shape is RectangleShape2D:
		return 14.0
	return body.position.y + (body.shape as RectangleShape2D).size.y * 0.5


func register_landed_hit(attack: AttackData) -> void:
	attack_landed = true
	if attack.is_launcher:
		launcher_jump_available = true


func apply_hit(attack: AttackData, knockback_velocity: Vector2, stun_ticks: int, rules: CombatRules, reaction_override := -1) -> bool:
	current_hp = maxf(0.0, current_hp - attack.damage)
	if current_hp <= 0.0:
		return lose_stock(rules)
	velocity = knockback_velocity
	pull_ticks_remaining = 0
	_clear_attack_travel()
	landing_down_ticks = 0
	_apply_air_status(attack, rules)
	hitstun_ticks = stun_ticks
	active_attack = null
	buffered_intent = null
	charge_attack = null
	runtime_state.charge_ticks = 0
	runtime_state.guarding = false
	runtime_state.evade_ticks = 0
	dash_ticks = 0
	if not (rules.simplified_combat and attack.preserve_air_actions): air_jumps_remaining = 0
	launcher_jump_available = false
	var reaction: int = attack.hit_reaction if reaction_override < 0 else reaction_override
	match reaction:
		AttackData.HitReaction.KNOCK_DOWN, AttackData.HitReaction.SLAM, AttackData.HitReaction.CRUMPLE:
			state = State.KNOCK_DOWN
		AttackData.HitReaction.LAUNCH, AttackData.HitReaction.GROUND_BOUNCE, AttackData.HitReaction.WALL_BOUNCE:
			state = State.LAUNCH
		_:
			state = State.HITSTUN
	hit_reaction_started.emit()
	return false


func ring_out(rules: CombatRules) -> bool:
	return lose_stock(rules)


func lose_stock(rules: CombatRules) -> bool:
	if state in [State.RING_OUT, State.DEAD, State.MATCH_ENDED] or stocks <= 0: return false
	stocks -= 1
	_reset_air_status()
	_clear_attack_travel()
	attack_restart_lock_ticks = 0
	current_hp = 0.0
	runtime_state.pending_respawn_hp = 0.0
	velocity = Vector2.ZERO
	active_attack = null
	buffered_intent = null
	combo_index = 0
	input_direction = CombatIntent.Direction.NEUTRAL
	launcher_jump_available = false
	charge_attack = null
	runtime_state.charge_ticks = 0
	runtime_state.guarding = false
	runtime_state.evade_ticks = 0
	dash_ticks = 0
	hitstun_ticks = 0
	if stocks <= 0:
		state = State.DEAD
	else:
		respawn_ticks = rules.respawn_delay_ticks
		state = State.RING_OUT
	return true


func revive(rules: CombatRules, revive_hp: float) -> bool:
	if stocks > 0 or runtime_state.revive_used or revive_hp <= 0.0: return false
	runtime_state.revive_used = true
	stocks = 1
	current_hp = minf(revive_hp, _stats().max_hp)
	runtime_state.pending_respawn_hp = current_hp
	respawn_ticks = rules.respawn_delay_ticks
	state = State.RING_OUT
	return true


func snapshot() -> Dictionary:
	return {
		"id": String(fighter_id), "state": State.keys()[state], "current_hp": snappedf(current_hp, 0.001), "max_hp": _stats().max_hp,
		"air_light_used": air_light_used, "air_heavy_used": air_heavy_used,
		"air_lock": air_lock, "air_lock_ticks": air_lock_ticks, "air_lock_expired": air_lock_expired,
		"landing_knockdown_pending": landing_knockdown_pending, "landing_down_ticks": landing_down_ticks, "wakeup_protection_ticks": wakeup_protection_ticks,
		"pull_ticks_remaining": pull_ticks_remaining, "pull_anchor": {"x": pull_anchor.x, "y": pull_anchor.y}, "pull_speed": pull_speed, "pull_stop_distance": pull_stop_distance,
		"attack_travel_active": attack_travel_active, "attack_target_id": String(attack_target_id), "attack_travel_end": {"x": attack_travel_end.x, "y": attack_travel_end.y},
		"attack_strike_ready": attack_strike_ready, "attack_travel_failed": attack_travel_failed, "attack_movement_started": _attack_movement_started,
		"on_floor": is_on_floor(),
		"stocks": stocks, "position": Vector2(snappedf(global_position.x, 0.001), snappedf(global_position.y, 0.001)),
		"velocity": Vector2(snappedf(velocity.x, 0.001), snappedf(velocity.y, 0.001)), "facing": facing,
		"attack_id": &"" if active_attack == null else active_attack.attack_id, "attack_phase_tick": attack_phase_tick,
		"attack_restart_lock_ticks": attack_restart_lock_ticks,
		"invulnerability_ticks": invulnerability_ticks, "respawn_ticks": respawn_ticks,
		"pending_respawn_hp": snappedf(runtime_state.pending_respawn_hp, 0.001), "revive_used": runtime_state.revive_used,
		"air_jumps": air_jumps_remaining, "air_attacks": aerial_attacks_remaining, "up_special": up_special_available,
		"guard_durability": snappedf(runtime_state.guard_durability, 0.001),
		"guard_max": runtime_state.guard_durability if runtime_profile == null else 100.0,
		"special_cooldown_ticks": runtime_state.special_cooldown_ticks,
		"ultimate_gauge": snappedf(runtime_state.ultimate_gauge, 0.001),
		"ultimate_used_this_stock": runtime_state.ultimate_used_this_stock,
	}


func apply_network_snapshot(value: Dictionary) -> void:
	for key: String in ["air_light_used", "air_heavy_used", "air_lock_expired", "landing_knockdown_pending", "attack_travel_active", "attack_strike_ready", "attack_travel_failed"]:
		set(key, bool(value.get(key, false)))
	for key: String in ["air_lock", "air_lock_ticks", "landing_down_ticks", "wakeup_protection_ticks", "pull_ticks_remaining"]:
		set(key, maxi(0, int(value.get(key, 0))))
	for key: String in ["pull_speed", "pull_stop_distance"]: set(key, float(value.get(key, 0.0)))
	for key: String in ["pull_anchor", "attack_travel_end"]:
		var point: Dictionary = value.get(key, {})
		set(key, Vector2(float(point.get("x", 0.0)), float(point.get("y", 0.0))))
	attack_target_id = StringName(value.get("attack_target_id", ""))
	_attack_movement_started = bool(value.get("attack_movement_started", false))
	var position_value: Dictionary = value.get("position", {})
	var velocity_value: Dictionary = value.get("velocity", {})
	global_position = Vector2(float(position_value.get("x", global_position.x)), float(position_value.get("y", global_position.y)))
	velocity = Vector2(float(velocity_value.get("x", velocity.x)), float(velocity_value.get("y", velocity.y)))
	current_hp = float(value.get("current_hp", current_hp))
	stocks = int(value.get("stocks", stocks))
	facing = int(value.get("facing", facing))
	invulnerability_ticks = int(value.get("invulnerability_ticks", invulnerability_ticks))
	respawn_ticks = int(value.get("respawn_ticks", respawn_ticks))
	runtime_state.pending_respawn_hp = float(value.get("pending_respawn_hp", runtime_state.pending_respawn_hp))
	runtime_state.revive_used = bool(value.get("revive_used", runtime_state.revive_used))
	air_jumps_remaining = int(value.get("air_jumps", air_jumps_remaining))
	aerial_attacks_remaining = int(value.get("air_attacks", aerial_attacks_remaining))
	up_special_available = bool(value.get("up_special", up_special_available))
	runtime_state.guard_durability = float(value.get("guard_durability", runtime_state.guard_durability))
	runtime_state.special_cooldown_ticks = int(value.get("special_cooldown_ticks", runtime_state.special_cooldown_ticks))
	runtime_state.ultimate_gauge = float(value.get("ultimate_gauge", runtime_state.ultimate_gauge))
	runtime_state.ultimate_used_this_stock = bool(value.get("ultimate_used_this_stock", runtime_state.ultimate_used_this_stock))
	attack_phase_tick = int(value.get("attack_phase_tick", attack_phase_tick))
	attack_restart_lock_ticks = maxi(0, int(value.get("attack_restart_lock_ticks", 0)))
	var network_attack_id := StringName(value.get("attack_id", ""))
	var previous_attack_id := &"" if active_attack == null else active_attack.attack_id
	if network_attack_id.is_empty():
		active_attack = null
	elif runtime_profile != null and (active_attack == null or active_attack.attack_id != network_attack_id):
		active_attack = null
		for candidate: AttackData in runtime_profile.move_set.attacks():
			if candidate.attack_id == network_attack_id:
				active_attack = candidate
				break
	if not network_attack_id.is_empty() and network_attack_id != previous_attack_id: activation_serial += 1
	var state_name := String(value.get("state", ""))
	var state_index := State.keys().find(state_name)
	if state_index >= 0: state = state_index as State
	queue_redraw()


func _try_jump(rules: CombatRules) -> void:
	if active_attack != null:
		if not (state == State.ATTACK_RECOVERY and attack_landed and active_attack.is_launcher and launcher_jump_available):
			return
		active_attack = null
		launcher_jump_available = false
	if state == State.DASH:
		return
	if is_on_floor():
		velocity.y = -_stats().jump_velocity
		state = State.JUMP
		presentation_event.emit(&"jump", {})
		EffectControllerScript.dispatch(EffectData.Trigger.ON_JUMP, self, null, rules)
	elif air_jumps_remaining > 0 or launcher_jump_available:
		if launcher_jump_available:
			launcher_jump_available = false
		else:
			air_jumps_remaining -= 1
		velocity.y = -_stats().jump_velocity
		state = State.JUMP
		presentation_event.emit(&"jump", {})
		EffectControllerScript.dispatch(EffectData.Trigger.ON_JUMP, self, null, rules)


func _try_dash() -> void:
	if active_attack != null or not is_on_floor():
		return
	var horizontal := _horizontal_input()
	var direction := horizontal if horizontal != 0 else facing
	facing = direction
	velocity.x = _stats().dash_speed * direction
	dash_ticks = maxi(1, roundi(_stats().dash_duration_seconds * 60.0))
	state = State.DASH
	presentation_event.emit(&"dash", {})


func _start_charge(intent: CombatIntent) -> void:
	var next := _select_attack(intent)
	if next == null:
		return
	_face_ground_attack(intent.direction)
	charge_attack = next
	charge_direction = intent.direction
	locked_facing = facing
	locked_direction = intent.direction
	velocity.x = 0.0
	dash_ticks = 0
	runtime_state.charge_ticks = 0
	state = State.CHARGE
	presentation_event.emit(&"charge_start", {})


func _release_charge(rules: CombatRules) -> void:
	if charge_attack == null:
		state = State.IDLE if is_on_floor() else State.FALL
		return
	var attack := charge_attack.duplicate(true) as AttackData
	var held := runtime_state.charge_ticks
	if held >= attack.charge_min_ticks and attack.charge_max_ticks > 0:
		var steps := maxi(1, held / maxi(1, attack.charge_min_ticks))
		attack.damage *= attack.charge_damage_multiplier
		attack.knockback *= attack.charge_knockback_multiplier
		attack.recovery_ticks += attack.charge_recovery_ticks_per_step * steps
		attack.visual_state_id = &"attack_heavy_charge"
	charge_attack = null
	runtime_state.charge_ticks = 0
	_start_attack(attack, charge_direction, rules)


func _select_attack(intent: CombatIntent) -> AttackData:
	if _simplified_combat:
		if not is_on_floor() and intent.action_id == &"attack_special": return null
		if not is_on_floor() and ((intent.action_id == &"attack_light" and air_light_used) or (intent.action_id == &"attack_heavy" and air_heavy_used)): return null
		var normalized := CombatIntent.new(intent.tick, intent.fighter_id, intent.action_id, CombatIntent.Direction.NEUTRAL, intent.edge, intent.context)
		var selected := ComboControllerScript.opening_attack(runtime_profile.move_set, normalized, AttackData.ActivationContext.GROUND if is_on_floor() else AttackData.ActivationContext.AIR, facing, false)
		if selected != null and selected.ground_only and not is_on_floor(): return null
		return selected
	var context := AttackData.ActivationContext.GROUND if is_on_floor() else AttackData.ActivationContext.AIR
	if context == AttackData.ActivationContext.AIR and intent.action_id != &"attack_special" and aerial_attacks_remaining <= 0:
		return null
	var relative := _relative_direction(intent.direction)
	if intent.action_id == &"attack_special" and relative == AttackData.InputDirection.UP and not up_special_available:
		return null
	# Dash light has a dedicated slot. Dash heavy ends the dash and enters the
	# ordinary directional charge, rather than requesting a nonexistent dash slot.
	return ComboControllerScript.opening_attack(runtime_profile.move_set, intent, context, facing, state == State.DASH and intent.action_id == &"attack_light")


func _start_attack(next: AttackData, direction: CombatIntent.Direction, rules: CombatRules = null, preserve_facing := false) -> void:
	_clear_attack_travel()
	wakeup_protection_ticks = 0
	if is_on_floor() and not next.requires_dash:
		if not preserve_facing: _face_ground_attack(direction)
		velocity.x = 0.0
		dash_ticks = 0
	active_attack = next
	activation_serial += 1
	attack_phase_tick = 0
	attack_landed = false
	locked_facing = facing
	locked_direction = direction
	combo_index = 0
	if next.activation_context == AttackData.ActivationContext.AIR and next.action_id in [&"attack_light", &"attack_heavy"]:
		if _simplified_combat:
			if next.action_id == &"attack_light": air_light_used = true
			else: air_heavy_used = true
		else: aerial_attacks_remaining -= 1
	if next.action_id == &"attack_special" and next.input_direction == AttackData.InputDirection.UP:
		up_special_available = false
		velocity += next.self_impulse
	# The optional argument preserves existing test and tool callers. Match authority
	# always supplies its rules; the fallback is only the contract default.
	if next.action_id == &"attack_special": runtime_state.special_cooldown_ticks = rules.special_cooldown_ticks if rules != null else 45
	state = State.ATTACK_STARTUP
	var direction_name := "neutral"
	if next.input_direction == AttackData.InputDirection.UP: direction_name = "up"
	elif next.input_direction == AttackData.InputDirection.DOWN: direction_name = "down"
	elif next.input_direction in [AttackData.InputDirection.FORWARD, AttackData.InputDirection.BACK, AttackData.InputDirection.ANY_HORIZONTAL]: direction_name = "side"
	presentation_event.emit(&"attack_started", {"attack_id": next.attack_id, "action_id": next.action_id, "activation_serial": activation_serial, "direction": direction_name})
	EffectControllerScript.dispatch(EffectData.Trigger.ON_ATTACK_START, self, null, rules if rules != null else CombatRules.new(), &"", 0, next.tags)


func _advance_attack(rules: CombatRules) -> void:
	attack_phase_tick += 1
	if state == State.ATTACK_STARTUP and attack_phase_tick >= active_attack.startup_ticks:
		state = State.ATTACK_ACTIVE
		attack_phase_tick = 0
	elif state == State.ATTACK_ACTIVE and attack_phase_tick >= active_attack.active_ticks:
		state = State.ATTACK_RECOVERY
		attack_phase_tick = 0
	elif state == State.ATTACK_RECOVERY and attack_phase_tick >= active_attack.recovery_ticks:
		var finished := active_attack
		var queued := buffered_intent
		active_attack = null
		buffered_intent = null
		EffectControllerScript.dispatch(EffectData.Trigger.ON_ATTACK_END, self, null, rules, &"", 0, finished.tags)
		if queued != null:
			var next := ComboControllerScript.linked_attack(runtime_profile.move_set, finished, queued, 0, attack_landed)
			if next != null:
				_start_attack(next, queued.direction, rules, true)
				return
		combo_index = 0
		state = State.IDLE if is_on_floor() else State.FALL


func _step_movement(rules: CombatRules) -> void:
	_apply_gravity(rules)
	if state == State.DASH:
		dash_ticks -= 1
		if dash_ticks <= 0:
			state = State.IDLE
	else:
		var horizontal := 0 if air_lock == 2 else _horizontal_input()
		if horizontal != 0:
			facing = horizontal
		var desired := float(horizontal) * (_stats().ground_speed if is_on_floor() else _stats().air_speed)
		var acceleration := rules.ground_acceleration if is_on_floor() else rules.air_acceleration
		if horizontal == 0 and is_on_floor():
			acceleration = rules.ground_deceleration
		velocity.x = move_toward(velocity.x, desired, acceleration / float(rules.physics_ticks_per_second))
	move_and_slide()
	if is_on_floor():
		var just_landed := not runtime_state.grounded
		air_jumps_remaining = _stats().air_jump_count
		aerial_attacks_remaining = 2
		up_special_available = true
		launcher_jump_available = false
		if state != State.DASH:
			state = State.RUN if _horizontal_input() != 0 else State.IDLE
		if just_landed: EffectControllerScript.dispatch(EffectData.Trigger.ON_LAND, self, null, rules)
	elif velocity.y < 0.0:
		state = State.JUMP
	else:
		state = State.FALL


func _apply_gravity(rules: CombatRules) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + _stats().gravity / float(rules.physics_ticks_per_second), rules.max_fall_speed)


func _respawn(rules: CombatRules) -> void:
	_reset_air_status()
	_clear_attack_travel()
	attack_restart_lock_ticks = 0
	global_position = spawn_position
	velocity = Vector2.ZERO
	current_hp = runtime_state.pending_respawn_hp if runtime_state.pending_respawn_hp > 0.0 else _stats().max_hp
	runtime_state.pending_respawn_hp = 0.0
	invulnerability_ticks = rules.respawn_invulnerability_ticks
	air_jumps_remaining = _stats().air_jump_count
	aerial_attacks_remaining = 2
	up_special_available = true
	launcher_jump_available = false
	charge_attack = null
	runtime_state.charge_ticks = 0
	state = State.IDLE
	presentation_event.emit(&"respawn", {})


func _try_evade(rules: CombatRules) -> void:
	if active_attack != null or state not in [State.IDLE, State.RUN, State.GUARD, State.DASH] or not is_on_floor(): return
	var horizontal := _horizontal_input()
	if horizontal == 0: return
	runtime_state.guarding = false
	runtime_state.evade_ticks = rules.evade_ticks
	invulnerability_ticks = max(invulnerability_ticks, rules.evade_invulnerability_ticks)
	facing = horizontal
	velocity.x = horizontal * _stats().dash_speed
	state = State.EVADE
	presentation_event.emit(&"evade", {})


func _try_cancel(intent: CombatIntent, rules: CombatRules) -> bool:
	# Cancel windows count from recovery start; startup/active cannot skip the attack.
	if state != State.ATTACK_RECOVERY: return false
	var kind: CancelRuleData.Kind
	match intent.action_id:
		&"jump": kind = CancelRuleData.Kind.JUMP
		&"guard": kind = CancelRuleData.Kind.GUARD
		&"evade": kind = CancelRuleData.Kind.EVADE
		&"attack_special": kind = CancelRuleData.Kind.SPECIAL
		&"ultimate": kind = CancelRuleData.Kind.ULTIMATE
		_: return false
	if not ComboControllerScript.can_cancel(runtime_profile.move_set, active_attack, kind, attack_phase_tick, attack_landed):
		return false
	var next: AttackData
	# Reject impossible actions before ending the current move or clearing its buffer.
	match kind:
		CancelRuleData.Kind.JUMP:
			if not is_on_floor() and air_jumps_remaining <= 0 and not launcher_jump_available: return false
		CancelRuleData.Kind.GUARD:
			if not is_on_floor(): return false
		CancelRuleData.Kind.EVADE:
			if not is_on_floor() or _horizontal_input() == 0: return false
		CancelRuleData.Kind.SPECIAL:
			next = _select_attack(intent)
			if next == null or runtime_state.special_cooldown_ticks > 0: return false
		CancelRuleData.Kind.ULTIMATE:
			if runtime_state.ultimate_gauge < rules.ultimate_gauge_max or runtime_state.ultimate_used_this_stock: return false
			var context := AttackData.ActivationContext.GROUND if is_on_floor() else AttackData.ActivationContext.AIR
			next = ComboControllerScript.opening_attack(runtime_profile.move_set, intent, context, facing, false)
			if next == null: return false
	if kind in [CancelRuleData.Kind.JUMP, CancelRuleData.Kind.GUARD, CancelRuleData.Kind.EVADE]:
		attack_restart_lock_ticks = maxi(attack_restart_lock_ticks, active_attack.recovery_ticks - attack_phase_tick)
	active_attack = null
	buffered_intent = null
	state = State.IDLE if is_on_floor() else State.FALL
	if kind == CancelRuleData.Kind.JUMP:
		_try_jump(rules)
	elif kind == CancelRuleData.Kind.GUARD:
		runtime_state.guarding = true
		state = State.GUARD
	elif kind == CancelRuleData.Kind.EVADE:
		_try_evade(rules)
	elif kind == CancelRuleData.Kind.SPECIAL:
		_start_attack(next, intent.direction, rules)
	elif kind == CancelRuleData.Kind.ULTIMATE:
		_try_ultimate(intent, rules)
	return true


func _try_ultimate(intent: CombatIntent, rules: CombatRules) -> void:
	if intent.edge != CombatIntent.Edge.PRESS or active_attack != null:
		return
	if runtime_state.ultimate_gauge < rules.ultimate_gauge_max or runtime_state.ultimate_used_this_stock:
		return
	var next := ComboControllerScript.opening_attack(runtime_profile.move_set, intent, AttackData.ActivationContext.GROUND if is_on_floor() else AttackData.ActivationContext.AIR, facing, false)
	if next == null:
		diagnostic = "ultimate_missing_authored_move"
		return
	runtime_state.ultimate_gauge = 0.0
	runtime_state.ultimate_used_this_stock = true
	_start_attack(next, intent.direction, rules)


func _try_drop_platform(rules: CombatRules) -> void:
	if rules.simplified_combat and active_attack != null: return
	# The platform owns layer 4; the ground remains layer 1 and never gets disabled.
	if not is_on_floor(): return
	runtime_state.guarding = false
	if state == State.GUARD: state = State.FALL
	runtime_state.platform_drop_ticks = rules.platform_drop_ticks
	set_collision_mask_value(4, false)


func _relative_direction(direction: CombatIntent.Direction) -> AttackData.InputDirection:
	match direction:
		CombatIntent.Direction.UP: return AttackData.InputDirection.UP
		CombatIntent.Direction.DOWN: return AttackData.InputDirection.DOWN
		CombatIntent.Direction.LEFT: return AttackData.InputDirection.FORWARD if facing < 0 else AttackData.InputDirection.BACK
		CombatIntent.Direction.RIGHT: return AttackData.InputDirection.FORWARD if facing > 0 else AttackData.InputDirection.BACK
		_: return AttackData.InputDirection.NEUTRAL


func _face_ground_attack(direction: CombatIntent.Direction) -> void:
	if direction == CombatIntent.Direction.LEFT: facing = -1
	elif direction == CombatIntent.Direction.RIGHT: facing = 1


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


func _combo_link_tick() -> int:
	if active_attack == null:
		return -1000000
	if state == State.ATTACK_ACTIVE:
		return attack_phase_tick - active_attack.active_ticks
	if state == State.ATTACK_RECOVERY:
		return attack_phase_tick
	return -1000000


func _stats() -> CharacterStats:
	return runtime_profile.stats if runtime_profile != null else character_data.base_stats


func _sync_debug_hitbox() -> void:
	var shape_node := get_node_or_null("Hitbox/CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	shape_node.disabled = state != State.ATTACK_ACTIVE or active_attack == null or not get_hitbox_rect().has_area()
	if not shape_node.disabled:
		var rect_shape := shape_node.shape as RectangleShape2D
		rect_shape.size = get_hitbox_rect().size
		shape_node.position = get_hitbox_rect().get_center() - global_position


func _finish_tick() -> void:
	if _simplified_combat: _check_air_landing()
	if is_on_floor() and not runtime_state.grounded and state not in [State.SPAWNING, State.DEAD, State.RING_OUT, State.MATCH_ENDED]:
		presentation_event.emit(&"land", {})
	runtime_state.state_id = State.keys()[state]
	runtime_state.active_attack_id = &"" if active_attack == null else active_attack.attack_id
	runtime_state.velocity = velocity
	runtime_state.grounded = is_on_floor()
	_sync_debug_hitbox()
	queue_redraw()


func _draw() -> void:
	if not show_debug_body: return
	var color := body_color
	if invulnerability_ticks > 0 and invulnerability_ticks % 6 < 3: color = Color.WHITE
	if state in [State.HITSTUN, State.LAUNCH, State.KNOCK_DOWN]: color = Color("ffdf5a")
	draw_rect(Rect2(-27, -82, 54, 96), color, true)
	draw_rect(Rect2(-27, -82, 54, 96), Color("122033"), false, 3.0)
	draw_line(Vector2.ZERO, Vector2(24.0 * facing, 0.0), Color.WHITE, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(-24, -88), State.keys()[state], HORIZONTAL_ALIGNMENT_CENTER, 48, 11, Color.WHITE)
	if state == State.ATTACK_ACTIVE:
		var rect := get_hitbox_rect()
		draw_rect(Rect2(to_local(rect.position), rect.size), Color(1, 0.25, 0.25, 0.25), true)
		draw_rect(Rect2(to_local(rect.position), rect.size), Color("ff5364"), false, 2.0)


func get_hitbox_rect() -> Rect2:
	var windows := attack_hit_windows()
	if windows.is_empty(): return Rect2()
	return windows[0].boxes[0]


func attack_hit_windows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state != State.ATTACK_ACTIVE or active_attack == null: return result
	if active_attack.attack_movement == 1 and not attack_strike_ready: return result
	if active_attack.hit_windows.is_empty():
		result.append({"index": -1, "boxes": [_legacy_hitbox_rect()], "attack": active_attack})
		return result
	for index: int in active_attack.hit_windows.size():
		var window: Dictionary = active_attack.hit_windows[index]
		if int(window.tick) != attack_phase_tick + 1: continue
		var boxes: Array[Rect2] = []
		for box: Rect2 in window.boxes:
			var local := box
			if locked_facing < 0: local.position.x = -box.end.x
			boxes.append(Rect2(global_position + local.position, local.size))
		var response := active_attack.duplicate(true) as AttackData
		for key: String in ["damage", "knockback", "launch_mode", "launch_vector", "hit_reaction", "pull_ticks", "pull_stop_distance"]:
			if window.has(key): response.set(key, window[key])
		result.append({"index": index, "boxes": boxes, "attack": response})
	return result


func _reset_air_status() -> void:
	air_light_used = false
	air_heavy_used = false
	air_lock = 0
	air_lock_ticks = 0
	air_lock_expired = false
	landing_knockdown_pending = false
	landing_down_ticks = 0
	wakeup_protection_ticks = 0
	pull_ticks_remaining = 0


func _apply_air_status(attack: AttackData, rules: CombatRules) -> void:
	if not rules.simplified_combat or air_lock_expired: return
	if attack.air_lock == 0 and not attack.landing_knockdown: return
	if air_lock_ticks == 0: air_lock_ticks = 120
	air_lock = maxi(air_lock, attack.air_lock)
	landing_knockdown_pending = landing_knockdown_pending or attack.landing_knockdown


func _check_air_landing() -> void:
	if not is_on_floor() or state in [State.SPAWNING, State.RING_OUT, State.DEAD, State.MATCH_ENDED]: return
	var landed := not runtime_state.grounded
	var impact := landing_knockdown_pending and velocity.y >= 0.0
	if not landed and not impact: return
	var down := landing_knockdown_pending
	air_lock = 0
	air_lock_ticks = 0
	air_lock_expired = false
	landing_knockdown_pending = false
	air_light_used = false
	air_heavy_used = false
	air_jumps_remaining = _stats().air_jump_count
	aerial_attacks_remaining = 2
	if down:
		active_attack = null
		buffered_intent = null
		velocity = Vector2.ZERO
		hitstun_ticks = 18
		landing_down_ticks = 18
		state = State.KNOCK_DOWN


func begin_pull(anchor: Vector2, speed: float, ticks: int, stop_distance: float) -> void:
	pull_anchor = anchor
	pull_speed = speed
	pull_ticks_remaining = ticks
	pull_stop_distance = stop_distance


func _step_pull() -> void:
	var offset := pull_anchor - global_position
	if offset.length() <= pull_stop_distance:
		pull_ticks_remaining = 0
		velocity = Vector2.ZERO
		return
	# A fixed destination and the ordinary collision move prevent a pull from
	# teleporting through terrain. The final pulse replaces this motion normally.
	var speed := minf(pull_speed, (offset.length() - pull_stop_distance) * 60.0)
	velocity = offset.normalized() * speed
	pull_ticks_remaining -= 1


func _clear_attack_travel() -> void:
	attack_travel_active = false
	attack_target_id = &""
	attack_travel_end = Vector2.ZERO
	attack_strike_ready = false
	attack_travel_failed = false
	_attack_movement_started = false


func advance_attack_travel(targets: Array[FighterController], rules: CombatRules, occupants: Array[FighterController] = []) -> void:
	if active_attack == null or state != State.ATTACK_ACTIVE or active_attack.attack_movement != 1: return
	if not _attack_movement_started:
		_attack_movement_started = true
		attack_travel_active = true
		attack_travel_end = global_position + Vector2(locked_facing * active_attack.travel_distance, 0.0)
		var first: FighterController
		var nearest := INF
		var path := Rect2(Vector2(minf(global_position.x, attack_travel_end.x), global_position.y - 82.0), Vector2(active_attack.travel_distance, 96.0))
		for target: FighterController in targets:
			if target == self or target.state in [State.SPAWNING, State.RING_OUT, State.DEAD, State.MATCH_ENDED]: continue
			var box := target.get_hurtbox_rect()
			var center_distance := (target.global_position.x - global_position.x) * locked_facing
			if center_distance < 0.0 or center_distance > active_attack.travel_distance or not path.intersects(box): continue
			var distance := (box.position.x - global_position.x) if locked_facing > 0 else (global_position.x - box.end.x)
			distance = maxf(0.0, distance)
			if distance < nearest or (is_equal_approx(distance, nearest) and (first == null or target.fighter_id < first.fighter_id)):
				first = target
				nearest = distance
		if first != null:
			attack_target_id = first.fighter_id
			attack_travel_end.x = first.global_position.x + locked_facing * active_attack.behind_distance
	if not attack_travel_active: return
	var end_box := Rect2(attack_travel_end + Vector2(-27, -58), Vector2(54, 72))
	for occupant: FighterController in occupants:
		if occupant != self and occupant.state not in [State.SPAWNING, State.RING_OUT, State.DEAD, State.MATCH_ENDED] and end_box.intersects(occupant.get_pushbox_rect()):
			_finish_attack_travel(false)
			return
	# Reject terrain before crossing a body: restoring pushboxes while inside an
	# enemy beside a wall could otherwise separate the attacker into that wall.
	if test_move(global_transform, Vector2(attack_travel_end.x - global_position.x, 0.0)):
		_finish_attack_travel(false)
		return
	var remaining := attack_travel_end.x - global_position.x
	var distance := minf(absf(remaining), active_attack.travel_speed / float(rules.physics_ticks_per_second))
	var collision := move_and_collide(Vector2(signf(remaining) * distance, 0.0))
	velocity.x = 0.0
	if collision != null:
		_finish_attack_travel(false)
	elif absf(attack_travel_end.x - global_position.x) < 0.01:
		attack_travel_active = false
		attack_strike_ready = not attack_target_id.is_empty()
		for target: FighterController in targets:
			if target != self and target.state not in [State.DEAD, State.RING_OUT, State.MATCH_ENDED] and get_pushbox_rect().intersects(target.get_pushbox_rect()):
				attack_travel_failed = true
				attack_strike_ready = false
		if attack_strike_ready:
			locked_facing *= -1
			facing = locked_facing
		_finish_attack_travel(not attack_travel_failed, attack_strike_ready)
	_finish_tick()


func _finish_attack_travel(succeeded: bool, strike := false) -> void:
	attack_travel_active = false
	attack_travel_failed = not succeeded
	attack_strike_ready = succeeded and strike
	if attack_strike_ready:
		# Reserve at most four active ticks for the single back strike. A nearby
		# target must not add unused travel time to its twenty-tick recovery.
		attack_phase_tick = active_attack.active_ticks - TRAVEL_STRIKE_TICKS
	else:
		state = State.ATTACK_RECOVERY
		attack_phase_tick = 0
	_finish_tick()
