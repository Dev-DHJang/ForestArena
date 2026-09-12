class_name BotCommandProfile
extends Resource

## Data-only tuning for a deterministic combat command source. The profile is
## intentionally character agnostic so the same archetype can drive any loadout.
const SCHEMA_VERSION := 1

@export var schema_version: int = SCHEMA_VERSION
@export var profile_id: StringName
@export_range(1, 120, 1) var decision_interval_ticks: int = 10
@export_range(0.0, 1280.0, 1.0) var preferred_distance_min: float = 120.0
@export_range(0.0, 1280.0, 1.0) var preferred_distance_max: float = 240.0
@export_range(0, 100, 1) var aggression_percent: int = 55
@export_range(0, 100, 1) var aerial_percent: int = 15
@export_range(0, 100, 1) var guard_percent: int = 30
@export_range(0, 100, 1) var evade_percent: int = 20
@export_range(0, 100, 1) var grab_percent: int = 10
@export_range(0, 100, 1) var heavy_percent: int = 20
@export_range(0, 100, 1) var special_percent: int = 25
@export_range(0, 100, 1) var ultimate_percent: int = 70


func is_valid_definition() -> bool:
	return schema_version == SCHEMA_VERSION \
		and not profile_id.is_empty() \
		and decision_interval_ticks > 0 \
		and preferred_distance_min >= 0.0 \
		and preferred_distance_max >= preferred_distance_min \
		and _is_percent(aggression_percent) \
		and _is_percent(aerial_percent) \
		and _is_percent(guard_percent) \
		and _is_percent(evade_percent) \
		and _is_percent(grab_percent) \
		and _is_percent(heavy_percent) \
		and _is_percent(special_percent) \
		and _is_percent(ultimate_percent)


func _is_percent(value: int) -> bool:
	return value >= 0 and value <= 100
