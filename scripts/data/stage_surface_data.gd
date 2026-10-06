class_name StageSurfaceData
extends Resource

@export var schema_version := 1
@export var surface_id: StringName
@export var rect: Rect2
@export var one_way := false


func is_valid_definition() -> bool:
	return schema_version == 1 and not surface_id.is_empty() and rect.size.x > 0.0 and rect.size.y > 0.0
