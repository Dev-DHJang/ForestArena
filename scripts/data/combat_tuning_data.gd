class_name CombatTuningData
extends Resource

const SCHEMA_VERSION := 2

@export var schema_version: int = SCHEMA_VERSION
@export var guard_max_durability: float = 100.0
@export var guard_hold_delay_ticks: int = 6
@export var guard_hold_drain_per_second: float = 6.0
@export var guard_hit_minimum_cost: float = 8.0
@export var guard_hit_damage_multiplier: float = 2.0
@export var guard_regen_delay_ticks: int = 60
@export var guard_regen_per_second: float = 18.0
@export var guard_break_ticks: int = 60
@export var evade_total_ticks: int = 18
@export var evade_invulnerability_start_tick: int = 4
@export var evade_invulnerability_end_tick: int = 10
@export var evade_cooldown_ticks: int = 30
@export var evade_speed: float = 480.0
@export var aerial_evades_per_airtime: int = 1
@export var charge_start_ticks: int = 8
@export var charge_max_ticks: int = 60
@export var special_cooldown_ticks: int = 180
@export var aerial_up_specials_per_airtime: int = 1
@export var aerial_special_impulse_multiplier: float = 1.0
@export var ultimate_max_gauge: float = 100.0
@export var ultimate_dealt_damage_gain_multiplier: float = 1.0
@export var ultimate_received_damage_gain_multiplier: float = 0.5


func is_valid_definition() -> bool:
	return schema_version == SCHEMA_VERSION \
		and guard_max_durability > 0.0 \
		and guard_hold_delay_ticks >= 0 \
		and guard_hold_drain_per_second > 0.0 \
		and guard_hit_minimum_cost >= 0.0 \
		and guard_hit_damage_multiplier > 0.0 \
		and guard_regen_delay_ticks >= 0 \
		and guard_regen_per_second > 0.0 \
		and guard_break_ticks > 0 \
		and evade_total_ticks > 0 \
		and evade_invulnerability_start_tick >= 0 \
		and evade_invulnerability_end_tick >= evade_invulnerability_start_tick \
		and evade_invulnerability_end_tick < evade_total_ticks \
		and evade_cooldown_ticks >= evade_total_ticks \
		and evade_speed > 0.0 \
		and aerial_evades_per_airtime >= 0 \
		and charge_start_ticks > 0 \
		and charge_max_ticks >= charge_start_ticks \
		and special_cooldown_ticks > 0 \
		and aerial_up_specials_per_airtime == 1 \
		and aerial_special_impulse_multiplier > 0.0 \
		and ultimate_max_gauge > 0.0 \
		and ultimate_dealt_damage_gain_multiplier >= 0.0 \
		and ultimate_received_damage_gain_multiplier >= 0.0


func guard_hold_drain_per_tick(physics_ticks_per_second: int) -> float:
	return guard_hold_drain_per_second / float(physics_ticks_per_second)


func guard_regen_per_tick(physics_ticks_per_second: int) -> float:
	return guard_regen_per_second / float(physics_ticks_per_second)


func is_evade_invulnerable(elapsed_ticks: int) -> bool:
	return elapsed_ticks >= evade_invulnerability_start_tick and elapsed_ticks <= evade_invulnerability_end_tick
