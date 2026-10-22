class_name StageController
extends Node2D

@export var stage_data: StageData


func _ready() -> void:
	build_stage()


func build_stage() -> void:
	for child: Node in get_children():
		child.queue_free()
	if stage_data == null or not stage_data.is_valid_definition():
		push_error("StageController requires valid StageData")
		return
	for surface: StageSurfaceData in stage_data.surfaces:
		var body := StaticBody2D.new()
		body.name = String(surface.surface_id)
		body.position = surface.rect.get_center()
		# Every surface is terrain. One-way behavior belongs to the collision
		# shape; putting platforms on the hitbox layer makes fighters fall through.
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape := RectangleShape2D.new()
		shape.size = surface.rect.size
		collision.shape = shape
		collision.one_way_collision = surface.one_way
		body.add_child(collision)
		add_child(body)
