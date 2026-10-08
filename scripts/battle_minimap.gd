class_name BattleMinimap
extends Control

const MAP_SIZE := Vector2(240, 150)
const ALLY_COLOR := Color("51b5ff")
const ENEMY_COLOR := Color("ff6675")
const SOLO_COLOR := Color.WHITE
const FACE_IDS := {
	"ja-hyun": "fa.character.minimap.ja-hyun.face",
	"myo-ryung": "fa.character.minimap.myo-ryung.face",
	"nabi": "fa.character.minimap.nabi.face",
	"yu-ran": "fa.character.minimap.yu-ran.face"
}

var embedded := false
var stage: StageData
var participants: Dictionary = {}
var local_id: StringName
var team_mode := false
var settings := {"transparency": 30, "marker_style": "face", "show_names": true}
var text_scale := 1.0
var markers: Array[Dictionary] = []
var _fighters: Array = []
var _faces: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	embedded = embedded or get_parent() is Container
	custom_minimum_size = MAP_SIZE
	size = MAP_SIZE
	modulate.a = 1.0 - float(settings.transparency) / 100.0
	_layout_in_safe_area()

func _process(_delta: float) -> void:
	_layout_in_safe_area()

func _layout_in_safe_area() -> void:
	if embedded: return
	var safe := Rect2(Vector2.ZERO, get_viewport_rect().size)
	if OS.has_feature("mobile"):
		var physical := Vector2(DisplayServer.window_get_size())
		var device_safe := Rect2(DisplayServer.get_display_safe_area())
		if physical.x > 0 and physical.y > 0 and device_safe.has_area():
			var ratio := safe.size / physical
			safe = Rect2(device_safe.position * ratio, device_safe.size * ratio)
	position = Vector2(safe.end.x - MAP_SIZE.x - 16, safe.position.y + 16)
	size = MAP_SIZE

func configure(p_stage: StageData, p_participants: Dictionary, p_local_id: StringName, p_team_mode: bool) -> void:
	stage = p_stage
	participants.clear()
	_faces.clear()
	for id: Variant in p_participants:
		var entry: Dictionary = p_participants[id].duplicate(true)
		participants[StringName(id)] = entry
		var character_id := String(entry.get("character_id", ""))
		if FACE_IDS.has(character_id):
			_faces[StringName(id)] = get_node("/root/ForestArenaResources").load_texture(FACE_IDS[character_id])
	local_id = p_local_id
	team_mode = p_team_mode
	_rebuild_markers()

func apply_settings(value: Dictionary, p_text_scale: float = 1.0) -> void:
	settings = {"transparency": clampi(int(value.get("transparency", 30)), 0, 90), "marker_style": "dot" if value.get("marker_style", "face") == "dot" else "face", "show_names": bool(value.get("show_names", true))}
	text_scale = clampf(p_text_scale, 1, 1.3)
	modulate.a = 1.0 - float(settings.transparency) / 100.0
	_rebuild_markers()

func update_snapshot(snapshot: Dictionary) -> void:
	_fighters = snapshot.get("fighters", []).duplicate(true)
	_rebuild_markers()

func map_rect() -> Rect2:
	var available := Rect2(12, 12, 216, 126)
	if stage == null or not stage.ring_bounds.has_area(): return available
	var scale_factor := minf(available.size.x / stage.ring_bounds.size.x, available.size.y / stage.ring_bounds.size.y)
	var extent := stage.ring_bounds.size * scale_factor
	return Rect2(available.get_center() - extent * 0.5, extent)

func world_to_map(world: Vector2) -> Vector2:
	if stage == null or not stage.ring_bounds.has_area(): return map_rect().get_center()
	return map_rect().position + (world - stage.ring_bounds.position) / stage.ring_bounds.size * map_rect().size

func participant_color(id: StringName) -> Color:
	if not team_mode: return SOLO_COLOR
	var local_team := String(participants.get(local_id, {}).get("team_id", ""))
	var team := String(participants.get(id, {}).get("team_id", ""))
	return ALLY_COLOR if not local_team.is_empty() and team == local_team else ENEMY_COLOR

func _rebuild_markers() -> void:
	markers.clear()
	if stage == null: queue_redraw(); return
	var area := map_rect()
	var padding := 13.0 if settings.marker_style == "face" else 6.0
	var bounds := area.grow(-padding)
	if not bounds.has_area(): bounds = area
	for fighter_value: Variant in _fighters:
		if not fighter_value is Dictionary: continue
		var fighter: Dictionary = fighter_value
		var id := StringName(fighter.get("id", ""))
		if not participants.has(id) or int(fighter.get("stocks", 0)) <= 0: continue
		var location: Variant = fighter.get("position", Vector2.ZERO)
		var world := Vector2.ZERO
		if location is Vector2: world = location
		elif location is Dictionary: world = Vector2(float(location.get("x", 0)), float(location.get("y", 0)))
		var projected := world_to_map(world)
		var point := Vector2(clampf(projected.x, bounds.position.x, bounds.end.x), clampf(projected.y, bounds.position.y, bounds.end.y))
		markers.append({"id": id, "point": point, "color": participant_color(id), "name": String(participants[id].get("nickname", String(id))), "name_rect": Rect2(), "self": id == local_id})
	if settings.show_names: _place_names()
	queue_redraw()

func _place_names() -> void:
	var font := ThemeDB.fallback_font
	var font_size := roundi(12 * text_scale)
	var occupied: Array[Rect2] = []
	for marker: Dictionary in markers:
		var half := 13.0 if settings.marker_style == "face" else 7.0
		occupied.append(Rect2(marker.point - Vector2.ONE * half, Vector2.ONE * half * 2))
		if marker.self:
			var triangle_y := -20.0 if settings.marker_style == "face" else -14.0
			occupied.append(Rect2(marker.point + Vector2(-5, triangle_y), Vector2(10, 6)))
	for marker: Dictionary in markers:
		var text: String = marker.name
		while font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > 80 and text.length() > 1:
			text = text.substr(0, text.length() - (2 if text.ends_with("…") else 1)) + "…"
		marker.name = text
		var extent := Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 6, font_size + 6)
		var candidates: Array[Vector2] = []
		var point: Vector2 = marker.point
		var radius := 15.0 if settings.marker_style == "face" else 8.0
		candidates.append(point + Vector2(-extent.x / 2, -radius - extent.y))
		candidates.append(point + Vector2(-extent.x / 2, radius))
		candidates.append(point + Vector2(radius, -extent.y / 2))
		candidates.append(point + Vector2(-radius - extent.x, -extent.y / 2))
		# Bounded nearby search avoids sorting a full grid on every combat tick.
		for distance: int in [24, 40, 56, 72, 88, 104, 120]:
			for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				candidates.append(point + direction.normalized() * distance - extent * 0.5)
		var placed := Rect2()
		for candidate: Vector2 in candidates:
			var rect := Rect2(candidate, extent)
			if not Rect2(3, 3, 234, 144).encloses(rect): continue
			var intersects := false
			for used: Rect2 in occupied:
				if used.grow(1).intersects(rect): intersects = true; break
			if not intersects:
				placed = rect
				break
		if not placed.has_area():
			var best_distance := INF
			for y: int in range(3, 145 - int(extent.y), 3):
				for x: int in range(3, 235 - int(extent.x), 3):
					var rect := Rect2(Vector2(x, y), extent)
					var distance := rect.get_center().distance_squared_to(point)
					if distance >= best_distance: continue
					var free := true
					for used: Rect2 in occupied:
						if used.grow(1).intersects(rect): free = false; break
					if free: placed = rect; best_distance = distance
		if not placed.has_area():
			# Even under extreme crowding retain every name, within the map.
			placed = Rect2(Vector2(clampf(point.x - extent.x / 2, 3, 237 - extent.x), clampf(point.y + radius, 3, 147 - extent.y)), extent)
		marker.name_rect = placed
		occupied.append(placed)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color("102b2d"))
	draw_rect(Rect2(Vector2.ONE, MAP_SIZE - Vector2.ONE * 2), Color("a2c1b6"), false, 1)
	if stage == null: return
	var area := map_rect()
	draw_rect(area, Color("193e3d"))
	for surface: StageSurfaceData in stage.surfaces:
		var terrain := Rect2(world_to_map(surface.rect.position), surface.rect.size / stage.ring_bounds.size * area.size).intersection(area)
		if terrain.has_area(): draw_rect(terrain, Color("70a58b") if not surface.one_way else Color("b4c9a2"))
	var font := ThemeDB.fallback_font
	var font_size := roundi(12 * text_scale)
	for marker: Dictionary in markers:
		var point: Vector2 = marker.point
		var color: Color = marker.color
		if settings.marker_style == "face" and _faces.get(marker.id) != null:
			var face_rect := Rect2(point - Vector2(11, 11), Vector2(22, 22))
			draw_rect(face_rect.grow(2), color)
			draw_texture_rect(_faces[marker.id], face_rect, false)
		else:
			draw_circle(point, 5, Color("0a191e"))
			draw_circle(point, 3.5, color)
		if settings.show_names:
			var rect: Rect2 = marker.name_rect
			if rect.has_area():
				if rect.get_center().distance_to(point) > 30: draw_line(point, rect.get_center(), Color(color, 0.4), 1)
				draw_rect(rect, Color("0b2026"))
				draw_string(font, rect.position + Vector2(3, font_size + 1), marker.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

	# Paint the local pointer last so other overlapping faces cannot cover it.
	for marker: Dictionary in markers:
		if marker.self:
			var top: Vector2 = marker.point + Vector2(0, -15 if settings.marker_style == "face" else -9)
			var triangle := PackedVector2Array([top, top + Vector2(-4, -5), top + Vector2(4, -5)])
			draw_colored_polygon(triangle, marker.color)
			draw_polyline(PackedVector2Array([triangle[0], triangle[1], triangle[2], triangle[0]]), Color("0b2026"), 1, true)
