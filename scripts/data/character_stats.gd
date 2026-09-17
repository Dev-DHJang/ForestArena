class_name CharacterStats
extends Resource

## Base values authored by a character. They are data only until a combat
## controller consumes a RuntimeCombatProfile in a later phase.
@export var schema_version := 2
@export_range(1.0, 999.0, 1.0) var max_hp: float = 100.0
@export_range(0.1, 10.0, 0.01) var weight: float = 1.0
@export_range(1.0, 2000.0, 1.0) var ground_speed: float = 300.0
@export_range(1.0, 2000.0, 1.0) var air_speed: float = 280.0
@export_range(1.0, 2000.0, 1.0) var jump_velocity: float = 520.0
@export_range(1.0, 4000.0, 1.0) var gravity: float = 1400.0
@export_range(1.0, 3000.0, 1.0) var dash_speed: float = 500.0
@export_range(0.01, 2.0, 0.01) var dash_duration_seconds: float = 0.15
@export_range(0, 5, 1) var air_jump_count: int = 1


func is_valid_base_profile() -> bool:
	return schema_version == 2 \
		and max_hp > 0.0 \
		and weight > 0.0 \
		and ground_speed > 0.0 \
		and air_speed > 0.0 \
		and jump_velocity > 0.0 \
		and gravity > 0.0 \
		and dash_speed > 0.0 \
		and dash_duration_seconds > 0.0 \
		and air_jump_count >= 0
