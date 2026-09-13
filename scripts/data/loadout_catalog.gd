class_name LoadoutCatalog
extends Resource

@export var schema_version: int = 3
@export var characters: Array[CharacterData] = []
@export var jobs: Array[JobData] = []
@export var accessories: Array[AccessoryData] = []
@export var passives: Array[PassiveData] = []


func is_valid_definition() -> bool:
	return schema_version == 3 and _unique(characters, "character_id") and _unique(jobs, "job_id") and _unique(accessories, "accessory_id") and _unique(passives, "passive_id")


func character_by_id(id: StringName) -> CharacterData:
	for item: CharacterData in characters:
		if item != null and item.character_id == id: return item
	return null


func job_by_id(id: StringName) -> JobData:
	for item: JobData in jobs:
		if item != null and item.job_id == id: return item
	return null


func accessory_by_id(id: StringName) -> AccessoryData:
	for item: AccessoryData in accessories:
		if item != null and item.accessory_id == id: return item
	return null


func passive_by_id(id: StringName) -> PassiveData:
	for item: PassiveData in passives:
		if item != null and item.passive_id == id: return item
	return null


func _unique(items: Array, property: StringName) -> bool:
	var seen: Dictionary = {}
	for item: Resource in items:
		if item == null or not item.is_valid_definition(): return false
		var id: StringName = item.get(property)
		if id.is_empty() or seen.has(id): return false
		seen[id] = true
	return true
