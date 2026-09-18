class_name AttackData
extends Resource

enum InputDirection { NEUTRAL, FORWARD, BACK, UP, DOWN, ANY_HORIZONTAL, OMNI }
enum ActivationContext { GROUND, AIR, BOTH }
enum LaunchMode { VECTOR, TOWARD_SOURCE }
enum HitReaction { NORMAL_HIT, LIGHT_STAGGER, HEAVY_STAGGER, KNOCKBACK, KNOCK_DOWN, LAUNCH, GROUND_BOUNCE, WALL_BOUNCE, SLAM, CRUMPLE }
const VALID_TAGS: Array[StringName] = [&"MELEE", &"PROJECTILE", &"MAGIC", &"FIRE", &"SPECIAL", &"ULTIMATE", &"UNBLOCKABLE"]

@export var schema_version: int = 3
@export var attack_id: StringName
@export var action_id: StringName
@export var input_direction: InputDirection = InputDirection.NEUTRAL
@export var activation_context: ActivationContext = ActivationContext.GROUND
@export var requires_dash: bool = false
@export var startup_ticks: int = 1
@export var active_ticks: int = 1
@export var recovery_ticks: int = 1
@export var damage: float = 0.0
@export var knockback: float = 0.0
@export var fixed_hitstun_ticks: int = 6
@export var guard_damage: float = 0.0
@export var guard_hitstun_ticks: int = 0
@export var guard_knockback: float = 0.0
@export var hit_reaction: HitReaction = HitReaction.NORMAL_HIT
@export var tags: Array[StringName] = [&"MELEE"]
@export var resource_cost: float = 0.0
@export var resource_gain: float = 0.0
@export var charge_min_ticks: int = 0
@export var charge_max_ticks: int = 0
@export var charge_damage_multiplier: float = 1.0
@export var charge_knockback_multiplier: float = 1.0
@export var charge_recovery_ticks_per_step: int = 0
@export var ignore_armor_and_immunity: bool = false
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


func is_valid_definition() -> bool:
	return schema_version == 3 \
		and not attack_id.is_empty() \
		and not action_id.is_empty() \
		and startup_ticks > 0 \
		and active_ticks > 0 \
		and recovery_ticks > 0 \
		and damage >= 0.0 \
		and knockback >= 0.0 \
		and fixed_hitstun_ticks >= 0 \
		and guard_damage >= 0.0 \
		and guard_hitstun_ticks >= 0 \
		and guard_knockback >= 0.0 \
		and charge_min_ticks >= 0 \
		and charge_max_ticks >= charge_min_ticks \
		and charge_damage_multiplier >= 1.0 \
		and charge_knockback_multiplier >= 1.0 \
		and charge_recovery_ticks_per_step >= 0 \
		and not tags.is_empty() \
		and tags.all(func(tag: StringName) -> bool: return VALID_TAGS.has(tag)) \
		and (launch_mode == LaunchMode.TOWARD_SOURCE or not launch_vector.is_zero_approx()) \
		and hitbox_size.x > 0.0 \
		and hitbox_size.y > 0.0 \
		and max_hits_per_target > 0 \
		and (max_hits_per_target == 1 or rehit_interval_ticks > 0) \
		and not visual_state_id.is_empty()
