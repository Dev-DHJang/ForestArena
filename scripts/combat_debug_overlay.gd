extends Node2D
## Reads exact combat rectangles. It never writes fighter state or collision nodes.
const HIT_COLOR := Color("ff5364")
const HURT_COLOR := Color("48bfff")
var controller: MatchController


func _ready() -> void:
	z_index = 100
	set_enabled(false)


func set_enabled(enabled: bool) -> void:
	visible = enabled
	set_process(enabled)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func sample_geometry() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if controller == null: return result
	for fighter: FighterController in controller.call("_fighters"):
		var geometry: Dictionary = fighter.call("get_debug_geometry")
		if not geometry.get("hurtbox", {}).is_empty() or not geometry.get("hitboxes", []).is_empty():
			result.append({"fighter_id": String(fighter.fighter_id), "geometry": geometry})
	return result


func _draw() -> void:
	for item: Dictionary in sample_geometry():
		var geometry: Dictionary = item.geometry
		var hurtbox: Dictionary = geometry.get("hurtbox", {})
		if not hurtbox.is_empty(): _draw_box(hurtbox, HURT_COLOR)
		for box: Dictionary in geometry.get("hitboxes", []): _draw_box(box, HIT_COLOR)


func _draw_box(box: Dictionary, color: Color) -> void:
	var rectangle := Rect2(to_local(Vector2(float(box.x), float(box.y))), Vector2(float(box.w), float(box.h)))
	draw_rect(rectangle, Color(color, 0.20), true)
	draw_rect(rectangle, color, false, 2.0)
