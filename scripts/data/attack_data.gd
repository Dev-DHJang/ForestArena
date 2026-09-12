class_name AttackData
extends Resource

enum InputDirection { NEUTRAL, FORWARD, BACK, UP, DOWN, ANY_HORIZONTAL, OMNI }
enum ActivationContext { GROUND, AIR, BOTH }
enum LaunchMode { VECTOR, TOWARD_SOURCE }
enum AttackKind { NORMAL, ULTIMATE }

@export var schema_version: int = 3
@export var attack_id: StringName
@export var action_id: StringName
@export var input_direction: InputDirection = InputDirection.NEUTRAL
@export var activation_context: ActivationContext = ActivationContext.GROUND
@export_range(0, 4, 1) var combo_step: int = 0
@export var requires_dash: bool = false
@export var startup_ticks: int = 1
@export var active_ticks: int = 1
@export var recovery_ticks: int = 1
@export var damage: float = 0.0
@export var base_knockback: float = 0.0
@export var knockback_growth: float = 0.0
@export var launch_mode: LaunchMode = LaunchMode.VECTOR
@export var launch_vector: Vector2 = Vector2(1.0, -0.18)
@export var hitbox_size: Vector2 = Vector2(60.0, 50.0)
@export var hitbox_offset: Vector2 = Vector2(44.0, -28.0)
@export var max_hits_per_target: int = 1
@export var rehit_interval_ticks: int = 0
@export var is_finisher: bool = false
@export var is_launcher: bool = false
@export var self_impulse: Vector2 = Vector2.ZERO
@export var visual_state_id: StringName
@export var attack_kind: AttackKind = AttackKind.NORMAL
@export var guard_damage_multiplier: float = 1.0
@export var chargeable: bool = false
@export var charge_damage_max_multiplier: float = 1.0
@export var charge_knockback_max_multiplier: float = 1.0
@export var charge_recovery_max_bonus_ticks: int = 0
@export var cooldown_group: StringName
@export var cooldown_ticks: int = 0
@export var ultimate_cost: float = 0.0
@export var ultimate_followup: bool = false


func is_valid_definition() -> bool:
	return schema_version == 3 \
		and not attack_id.is_empty() \
		and not action_id.is_empty() \
		and combo_step >= 0 \
		and startup_ticks > 0 \
		and active_ticks > 0 \
		and recovery_ticks > 0 \
		and damage >= 0.0 \
		and base_knockback >= 0.0 \
		and knockback_growth >= 0.0 \
		and (launch_mode == LaunchMode.TOWARD_SOURCE or not launch_vector.is_zero_approx()) \
		and hitbox_size.x > 0.0 \
		and hitbox_size.y > 0.0 \
		and max_hits_per_target > 0 \
		and (max_hits_per_target == 1 or rehit_interval_ticks > 0) \
		and guard_damage_multiplier >= 0.0 \
		and charge_damage_max_multiplier >= 1.0 \
		and charge_knockback_max_multiplier >= 1.0 \
		and charge_recovery_max_bonus_ticks >= 0 \
		and (cooldown_group.is_empty() or cooldown_ticks > 0) \
		and (not cooldown_group.is_empty() or cooldown_ticks == 0) \
		and (attack_kind != AttackKind.ULTIMATE or ultimate_followup or ultimate_cost > 0.0) \
		and (attack_kind == AttackKind.ULTIMATE or not ultimate_followup) \
		and not visual_state_id.is_empty()


func is_ultimate() -> bool:
	return attack_kind == AttackKind.ULTIMATE
