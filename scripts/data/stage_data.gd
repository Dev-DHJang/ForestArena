class_name StageData
extends Resource

@export var schema_version := 2
@export var stage_id: StringName
@export var background_asset_id: StringName
@export var terrain_asset_id: StringName
@export var surfaces: Array[StageSurfaceData] = []
@export var spawn_points: Array[Vector2] = []
@export var ring_bounds := Rect2()


func is_valid_definition() -> bool:
	if schema_version != 2 or stage_id.is_empty() or background_asset_id.is_empty() or terrain_asset_id.is_empty() or surfaces.is_empty() or spawn_points.size() < 2 or not ring_bounds.has_area():
		return false
	var ids: Dictionary = {}
	for surface: StageSurfaceData in surfaces:
		if surface == null or not surface.is_valid_definition() or ids.has(surface.surface_id):
			return false
		ids[surface.surface_id] = true
	for point: Vector2 in spawn_points:
		if not ring_bounds.has_point(point):
			return false
	return true


func main_floor() -> StageSurfaceData:
	for surface: StageSurfaceData in surfaces:
		if not surface.one_way:
			return surface
	return null
