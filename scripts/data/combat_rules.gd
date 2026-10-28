class_name CombatRules
extends Resource

# Missing version means legacy/unknown data and must be rejected explicitly.
@export var schema_version: int = 0
@export var simplified_combat := false
@export var physics_ticks_per_second: int = 60
@export var stocks_per_fighter: int = 3
@export var ground_acceleration: float = 3000.0
@export var ground_deceleration: float = 3600.0
@export var air_acceleration: float = 1800.0
@export var max_fall_speed: float = 1000.0
@export var hitstun_min_ticks: int = 10
@export var hitstun_max_ticks: int = 36
## Applied after the legacy weight/clamp calculation; old rule sets retain 1x.
@export var hitstun_multiplier: int = 1
@export var landing_down_ticks: int = 18
@export var falling_ring_out := false
@export var ring_out_hide_margin: float = 256.0
@export var ring_out_confirm_ticks: int = 60
@export var di_max_degrees: float = 10.0
@export var respawn_delay_ticks: int = 45
@export var respawn_invulnerability_ticks: int = 60
@export var guard_max_durability: float = 100.0
@export var guard_regen_per_tick: float = 0.5
@export var guard_break_ticks: int = 30
@export var evade_ticks: int = 12
@export var evade_invulnerability_ticks: int = 8
@export var special_cooldown_ticks: int = 45
@export var ultimate_gauge_max: float = 100.0
@export var ultimate_gauge_per_damage_dealt: float = 1.0
@export var ultimate_gauge_per_damage_taken: float = 0.5
@export var platform_drop_ticks: int = 12
@export var combo_link_window_ticks: int = 13


func is_valid_definition() -> bool:
	return schema_version in [4, 5] \
		and physics_ticks_per_second == 60 \
		and stocks_per_fighter > 0 \
		and ground_acceleration > 0.0 \
		and ground_deceleration > 0.0 \
		and air_acceleration > 0.0 \
		and max_fall_speed > 0.0 \
		and hitstun_min_ticks > 0 \
		and hitstun_max_ticks >= hitstun_min_ticks \
		and hitstun_multiplier > 0 and landing_down_ticks > 0 \
		and ring_out_hide_margin >= 0.0 and ring_out_confirm_ticks > 0 \
		and di_max_degrees >= 0.0 \
		and respawn_delay_ticks > 0 \
		and respawn_invulnerability_ticks > 0 \
		and guard_max_durability > 0.0 \
		and guard_regen_per_tick >= 0.0 \
		and guard_break_ticks >= 0 \
		and evade_ticks > 0 and evade_invulnerability_ticks >= 0 and special_cooldown_ticks >= 0 and ultimate_gauge_max > 0.0 \
		and ultimate_gauge_per_damage_dealt >= 0.0 and ultimate_gauge_per_damage_taken >= 0.0 and platform_drop_ticks > 0
