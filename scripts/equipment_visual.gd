extends Node2D
## Read-only equipment drawing. Geometry and hit resolution belong to combat.
var fighter: FighterController
var hand_local := Vector2.ZERO
var has_hand_anchor := false
var _texture: Texture2D
var _texture_id: StringName

func _process(_delta: float) -> void:
	queue_redraw()

func string_root() -> Vector2:
	return hand_local if has_hand_anchor else to_local(fighter.equipment_origin())

func display_tip() -> Vector2:
	var root_point := string_root()
	if fighter.equipment_phase in ["startup", "recovery"]: return root_point
	var tip := to_local(fighter.equipment_position)
	if fighter.equipment_phase == "return":
		# Return has no hitbox. Ease its drawing into the animated palm so the
		# catch never jumps from the fixed combat origin to the hand next frame.
		var ability := fighter.equipment_ability()
		var progress := clampf(float(fighter.equipment_phase_tick + 1) / float(ability.return_ticks),0.0,1.0)
		tip += (root_point - to_local(fighter.equipment_origin())) * progress
	return tip

func _draw() -> void:
	if fighter == null or fighter.equipment_phase == "idle" or fighter.ring_out_hidden: return
	var ability := fighter.equipment_ability()
	if ability == null: return
	if _texture_id != ability.texture_id:
		_texture_id = ability.texture_id
		var manager := get_node_or_null("/root/ForestArenaResources")
		if manager != null: _texture = manager.load_texture(String(_texture_id))
	var root_point := string_root()
	var tip := display_tip()
	if root_point.distance_to(tip) > 2.0:
		draw_line(root_point, tip, Color("fff0ca"), 1.8, true)
	if _texture != null:
		# Rotation changes only the drawing, never the authoritative square hitbox.
		draw_set_transform(tip, float(fighter.equipment_tick) * 0.5 * fighter.equipment_facing)
		draw_texture_rect(_texture, Rect2(Vector2(-14,-14),Vector2(28,28)), false)
		draw_set_transform(Vector2.ZERO)
