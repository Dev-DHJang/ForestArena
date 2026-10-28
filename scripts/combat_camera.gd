extends Camera2D

@export var player: FighterController
@export_range(0.5, 2.0, 0.01) var fixed_zoom := 1.50


func _ready() -> void:
	if player == null: player = get_node("../World/Player") as FighterController
	zoom = Vector2.ONE * fixed_zoom


func _process(_delta: float) -> void:
	if player == null: return
	zoom = Vector2.ONE * fixed_zoom
	# Presentation follows the local player only. Ring-out and hit calculations never
	# read this camera, so camera smoothing cannot change a fixed-tick result.
	position = player.global_position
	var controller := get_node_or_null("../MatchController") as MatchController
	if controller != null and controller.rules.falling_ring_out and controller.stage_data != null:
		var floor_surface := controller.stage_data.main_floor()
		if floor_surface != null: position.y = minf(position.y, floor_surface.rect.position.y)
