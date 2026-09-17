class_name CombatRules
extends Resource

@export var schema_version: int = 2
@export var physics_ticks_per_second: int = 60
@export var stocks_per_fighter: int = 3
@export var ground_acceleration: float = 3000.0
@export var ground_deceleration: float = 3600.0
@export var air_acceleration: float = 1800.0
@export var max_fall_speed: float = 1000.0
@export var hitstun_min_ticks: int = 6
@export var hitstun_max_ticks: int = 30
@export var di_max_degrees: float = 10.0
@export var respawn_delay_ticks: int = 45
@export var respawn_invulnerability_ticks: int = 60
@export var guard_max_durability: float = 100.0
@export var guard_regen_per_tick: float = 0.5
@export var guard_break_ticks: int = 30
@export var combo_link_window_ticks: int = 5
@export var ring_left: float = -160.0
@export var ring_right: float = 1440.0
@export var ring_top: float = -240.0
@export var ring_bottom: float = 820.0


func is_valid_definition() -> bool:
	return schema_version == 2 \
		and physics_ticks_per_second == 60 \
		and stocks_per_fighter > 0 \
		and ground_acceleration > 0.0 \
		and ground_deceleration > 0.0 \
		and air_acceleration > 0.0 \
		and max_fall_speed > 0.0 \
		and hitstun_min_ticks > 0 \
		and hitstun_max_ticks >= hitstun_min_ticks \
		and di_max_degrees >= 0.0 \
		and respawn_delay_ticks > 0 \
		and respawn_invulnerability_ticks > 0 \
		and guard_max_durability > 0.0 \
		and guard_regen_per_tick >= 0.0 \
		and guard_break_ticks >= 0
