class_name OffscreenOpponentIndicator
extends Control

@export var player_path: NodePath = NodePath("../../World/Player")
@export var opponent_path: NodePath = NodePath("../../World/TrainingDummy")
@export var camera_path: NodePath = NodePath("../../Camera2D")
@export var horizontal_margin_ratio := 0.085
@export var safe_top_ratio := 0.21
@export var safe_bottom_ratio := 0.50

var player: FighterController
var opponent: FighterController
var camera: Camera2D
var arrow_position := Vector2.ZERO
var arrow_direction := Vector2.RIGHT


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	player = get_node(player_path) as FighterController
	opponent = get_node(opponent_path) as FighterController
	camera = get_node(camera_path) as Camera2D
	visible = false


func _process(_delta: float) -> void:
	update_indicator()


func update_indicator() -> void:
	if player == null or opponent == null or camera == null or opponent.state == FighterController.State.MATCH_ENDED:
		visible = false
		return
	var viewport_size := get_viewport_rect().size
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	var bounds := _opponent_screen_bounds()
	if bounds.has_area() and viewport_rect.intersects(bounds):
		visible = false
		return
	var player_screen := player.get_global_transform_with_canvas().origin
	var opponent_screen := opponent.get_global_transform_with_canvas().origin
	arrow_direction = (opponent_screen - player_screen).normalized()
	if arrow_direction.is_zero_approx():
		visible = false
		return
	var safe := safe_rect(viewport_size, horizontal_margin_ratio, safe_top_ratio, safe_bottom_ratio)
	# Use the safe region's center so the whole arrow stays between the top HUD
	# and bottom touch controls even on wide Android screens.
	arrow_position = edge_position(safe.get_center(), arrow_direction, safe)
	visible = true
	queue_redraw()


func _opponent_screen_bounds() -> Rect2:
	var presentation := opponent.get_node_or_null("Presentation")
	if presentation != null and presentation.has_method("screen_bounds"):
		return presentation.screen_bounds()
	var center := opponent.get_global_transform_with_canvas().origin
	return Rect2(center - Vector2(24, 48), Vector2(48, 96))


static func safe_rect(viewport_size: Vector2, x_margin: float, top_ratio: float, bottom_ratio: float) -> Rect2:
	var left := viewport_size.x * x_margin
	var top := viewport_size.y * top_ratio
	return Rect2(left, top, viewport_size.x - left * 2.0, viewport_size.y * (bottom_ratio - top_ratio))


static func edge_position(origin: Vector2, direction: Vector2, bounds: Rect2) -> Vector2:
	var unit := direction.normalized()
	var distances: Array[float] = []
	if unit.x > 0.0001: distances.append((bounds.end.x - origin.x) / unit.x)
	elif unit.x < -0.0001: distances.append((bounds.position.x - origin.x) / unit.x)
	if unit.y > 0.0001: distances.append((bounds.end.y - origin.y) / unit.y)
	elif unit.y < -0.0001: distances.append((bounds.position.y - origin.y) / unit.y)
	var travel := INF
	for distance: float in distances:
		if distance >= 0.0: travel = minf(travel, distance)
	if is_inf(travel): return bounds.get_center()
	var point := origin + unit * travel
	return Vector2(clampf(point.x, bounds.position.x, bounds.end.x), clampf(point.y, bounds.position.y, bounds.end.y))


func _draw() -> void:
	if not visible: return
	var angle := arrow_direction.angle()
	var forward := Vector2.RIGHT.rotated(angle)
	var side := forward.orthogonal()
	var tip := arrow_position + forward * 20.0
	var back := arrow_position - forward * 16.0
	var points := PackedVector2Array([tip, back + side * 14.0, back - side * 14.0])
	draw_colored_polygon(points, Color("ffd66b"))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color("18333b"), 5.0, true)
