class_name RuntimeCombatProfile
extends RefCounted

const SCHEMA_VERSION := 3

var schema_version := SCHEMA_VERSION
var character_id: StringName
var job_id: StringName
var accessory_id: StringName
var active_accessory_effect_ids: Array[StringName] = []
var stats: CharacterStats
var move_set: MoveSetData
var combat_tuning: CombatTuningData
var passive_ids: Array[StringName] = []
var tags: Array[StringName] = []


func is_valid_definition() -> bool:
	return schema_version == SCHEMA_VERSION and not character_id.is_empty() and stats != null and stats.is_valid_base_profile() and move_set != null and move_set.is_valid_definition() and combat_tuning != null and combat_tuning.is_valid_definition()
