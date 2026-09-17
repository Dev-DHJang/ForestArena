class_name FighterController
extends CharacterBody2D

const ComboControllerScript = preload("res://scripts/combo_controller.gd")

## Fixed-tick Phase 1 fighter. Geometry and visual state mirror the authority
## state for debugging, but physics overlap and animation never decide hits.
enum State { SPAWNING, IDLE, RUN, JUMP, FALL, DASH, EVADE, CHARGE, ATTACK_STARTUP, ATTACK_ACTIVE, ATTACK_RECOVERY, GUARD, HITSTUN, LAUNCH, KNOCK_DOWN, WAKE_UP, RING_OUT, DEAD, MATCH_ENDED }

@export var fighter_id: StringName
@export var character_data: CharacterData
var attacks: Array[AttackData] = []
var combo_count: int = 2
@export var controlled_by_input: bool = false
@export var body_color: Color = Color("43c782")

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
var diagnostic := ""
var locked_facing := 1
var locked_direction: CombatIntent.Direction = CombatIntent.Direction.NEUTRAL
var runtime_profile: RuntimeCombatProfile


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
	if profile == null or profile.character_id != fighter_id or not profile.is_valid_definition():
		diagnostic = "invalid_runtime_profile"
		return false
	runtime_profile = profile
	attacks = profile.move_set.attacks()
	combo_count = profile.move_set.combo_count
	air_jumps_remaining = _stats().air_jump_count
	runtime_state.reset(_stats().max_hp, 3, 100.0)
	state = State.IDLE
	set_physics_process(true)
	return true


func reset_for_match(rules: CombatRules) -> void:
	if runtime_profile == null:
		return
	runtime_state.reset(_stats().max_hp, rules.stocks_per_fighter, rules.guard_max_durability)
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
	invulnerability_ticks = 0
	respawn_ticks = 0
	hitstun_ticks = 0
	state = State.IDLE
	_sync_debug_hitbox()


func consume_intent(intent: CombatIntent, rules: CombatRules) -> void:
	if intent.action_id == &"move":
		input_direction = CombatIntent.Direction.NEUTRAL if intent.edge == CombatIntent.Edge.RELEASE else intent.direction
		if intent.edge == CombatIntent.Edge.RELEASE and state == State.GUARD:
			runtime_state.guarding = false
			state = State.IDLE if is_on_floor() else State.FALL
		return
	if active_attack != null and intent.edge == CombatIntent.Edge.PRESS and _try_cancel(intent, rules):
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
		if runtime_state.ultimate_gauge >= rules.ultimate_gauge_max and not runtime_state.ultimate_used_this_stock:
			runtime_state.ultimate_gauge = 0.0
			runtime_state.ultimate_used_this_stock = true
			diagnostic = "ultimate_requested_no_authored_move"
		return
	if intent.edge != CombatIntent.Edge.PRESS or state in [State.SPAWNING, State.RING_OUT, State.DEAD, State.MATCH_ENDED, State.HITSTUN, State.LAUNCH, State.KNOCK_DOWN]:
		return
	if intent.action_id == &"jump":
		_try_jump()
		return
	if intent.action_id == &"dash":
		_try_dash()
		return
	if intent.action_id not in [&"attack_light", &"attack_heavy", &"attack_special"]:
		return
	if active_attack != null:
		var linked := ComboControllerScript.linked_attack(runtime_profile.move_set, active_attack, intent, attack_phase_tick, attack_landed)
		if state == State.ATTACK_RECOVERY and linked != null and buffered_intent == null:
			buffered_intent = intent
		return
	var next := _select_attack(intent)
	if next == null: return
	if next.action_id == &"attack_special" and runtime_state.special_cooldown_ticks > 0: return
	_start_attack(next, intent.direction, rules)


func step_tick(rules: CombatRules) -> void:
	if runtime_profile == null:
		return
	diagnostic = ""
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


func apply_hit(attack: AttackData, knockback_velocity: Vector2, stun_ticks: int, rules: CombatRules) -> bool:
	current_hp = maxf(0.0, current_hp - attack.damage)
	if current_hp <= 0.0:
		return lose_stock(rules)
	velocity = knockback_velocity
	hitstun_ticks = stun_ticks
	active_attack = null
	buffered_intent = null
	air_jumps_remaining = 0
	launcher_jump_available = false
	match attack.hit_reaction:
		AttackData.HitReaction.KNOCK_DOWN, AttackData.HitReaction.SLAM, AttackData.HitReaction.CRUMPLE:
			state = State.KNOCK_DOWN
		AttackData.HitReaction.LAUNCH, AttackData.HitReaction.GROUND_BOUNCE, AttackData.HitReaction.WALL_BOUNCE:
			state = State.LAUNCH
		_:
			state = State.HITSTUN
	return false


func ring_out(rules: CombatRules) -> bool:
	return lose_stock(rules)


func lose_stock(rules: CombatRules) -> bool:
	if state in [State.RING_OUT, State.DEAD]: return false
	stocks -= 1
	current_hp = 0.0
	velocity = Vector2.ZERO
	active_attack = null
	buffered_intent = null
	combo_index = 0
	input_direction = CombatIntent.Direction.NEUTRAL
	launcher_jump_available = false
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
	respawn_ticks = rules.respawn_delay_ticks
	state = State.RING_OUT
	return true


func snapshot() -> Dictionary:
	return {
		"id": String(fighter_id), "state": State.keys()[state], "current_hp": snappedf(current_hp, 0.001), "max_hp": _stats().max_hp,
		"stocks": stocks, "position": Vector2(snappedf(global_position.x, 0.001), snappedf(global_position.y, 0.001)),
		"velocity": Vector2(snappedf(velocity.x, 0.001), snappedf(velocity.y, 0.001)), "facing": facing,
		"attack_id": &"" if active_attack == null else active_attack.attack_id, "attack_phase_tick": attack_phase_tick,
		"invulnerability_ticks": invulnerability_ticks, "respawn_ticks": respawn_ticks,
		"air_jumps": air_jumps_remaining, "air_attacks": aerial_attacks_remaining, "up_special": up_special_available,
		"guard_durability": snappedf(runtime_state.guard_durability, 0.001),
		"guard_max": runtime_state.guard_durability if runtime_profile == null else 100.0,
		"special_cooldown_ticks": runtime_state.special_cooldown_ticks,
		"ultimate_gauge": snappedf(runtime_state.ultimate_gauge, 0.001),
		"ultimate_used_this_stock": runtime_state.ultimate_used_this_stock,
	}


func _try_jump() -> void:
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


func _select_attack(intent: CombatIntent) -> AttackData:
	var context := AttackData.ActivationContext.GROUND if is_on_floor() else AttackData.ActivationContext.AIR
	if context == AttackData.ActivationContext.AIR and intent.action_id != &"attack_special" and aerial_attacks_remaining <= 0:
		return null
	if intent.action_id == &"attack_special" and intent.direction in [CombatIntent.Direction.LEFT, CombatIntent.Direction.RIGHT, CombatIntent.Direction.DOWN]:
		diagnostic = "Phase 1 no-op special direction; deferred to Phase 3"
		return null
	var relative := _relative_direction(intent.direction)
	if intent.action_id == &"attack_special" and relative == AttackData.InputDirection.UP and not up_special_available:
		return null
	return ComboControllerScript.opening_attack(runtime_profile.move_set, intent, context, facing, state == State.DASH)


func _start_attack(next: AttackData, direction: CombatIntent.Direction, rules: CombatRules = null) -> void:
	active_attack = next
	activation_serial += 1
	attack_phase_tick = 0
	attack_landed = false
	locked_facing = facing
	locked_direction = direction
	combo_index = 0
	if next.activation_context == AttackData.ActivationContext.AIR and next.action_id in [&"attack_light", &"attack_heavy"]:
		aerial_attacks_remaining -= 1
	if next.action_id == &"attack_special" and next.input_direction == AttackData.InputDirection.UP:
		up_special_available = false
		velocity += next.self_impulse
	# The optional argument preserves existing test and tool callers. Match authority
	# always supplies its rules; the fallback is only the contract default.
	if next.action_id == &"attack_special": runtime_state.special_cooldown_ticks = rules.special_cooldown_ticks if rules != null else 45
	state = State.ATTACK_STARTUP


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
		if queued != null:
			var next := ComboControllerScript.linked_attack(runtime_profile.move_set, finished, queued, 0, attack_landed)
			if next != null:
				_start_attack(next, queued.direction, rules)
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
	current_hp = _stats().max_hp
	invulnerability_ticks = rules.respawn_invulnerability_ticks
	air_jumps_remaining = _stats().air_jump_count
	aerial_attacks_remaining = 2
	up_special_available = true
	launcher_jump_available = false
	state = State.IDLE


func _try_evade(rules: CombatRules) -> void:
	if active_attack != null or state not in [State.IDLE, State.RUN, State.GUARD, State.DASH] or not is_on_floor(): return
	runtime_state.guarding = false
	runtime_state.evade_ticks = rules.evade_ticks
	invulnerability_ticks = max(invulnerability_ticks, rules.evade_invulnerability_ticks)
	velocity.x = facing * _stats().dash_speed
	state = State.EVADE


func _try_cancel(intent: CombatIntent, rules: CombatRules) -> bool:
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
	active_attack = null
	buffered_intent = null
	if kind == CancelRuleData.Kind.JUMP:
		_try_jump()
	elif kind == CancelRuleData.Kind.GUARD:
		if is_on_floor():
			runtime_state.guarding = true
			state = State.GUARD
	elif kind == CancelRuleData.Kind.EVADE:
		_try_evade(rules)
	elif kind == CancelRuleData.Kind.SPECIAL:
		var next := _select_attack(intent)
		if next != null and runtime_state.special_cooldown_ticks <= 0: _start_attack(next, intent.direction, rules)
	elif kind == CancelRuleData.Kind.ULTIMATE:
		if runtime_state.ultimate_gauge >= rules.ultimate_gauge_max and not runtime_state.ultimate_used_this_stock:
			runtime_state.ultimate_gauge = 0.0
			runtime_state.ultimate_used_this_stock = true
	return true


func _try_drop_platform(rules: CombatRules) -> void:
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
	runtime_state.state_id = State.keys()[state]
	runtime_state.active_attack_id = &"" if active_attack == null else active_attack.attack_id
	runtime_state.velocity = velocity
	runtime_state.grounded = is_on_floor()
	_sync_debug_hitbox()
	queue_redraw()


func _draw() -> void:
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
