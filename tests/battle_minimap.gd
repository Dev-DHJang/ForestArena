extends SceneTree
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var map := BattleMinimap.new()
	map.embedded = true
	root.add_child(map)
	var stage := load("res://assets/combat/stages/forest_ledge_stage.tres") as StageData
	var participants := {}
	var fighters: Array = []
	for index: int in 8:
		var id := StringName("p%d" % index)
		participants[id] = {"nickname": "참가자%d" % index, "character_id": ["ja-hyun", "myo-ryung", "nabi", "yu-ran"][index % 4], "team_id": "alpha" if index < 4 else "beta"}
		fighters.append({"id": id, "stocks": 3, "position": Vector2(640, 420)})
	map.configure(stage, participants, &"p0", true)
	map.update_snapshot({"fighters": fighters})
	check(map.markers.size() == 8, "all eight participants show")
	check(map.participant_color(&"p0") == BattleMinimap.ALLY_COLOR and map.participant_color(&"p3") == BattleMinimap.ALLY_COLOR, "local team blue")
	check(map.participant_color(&"p4") == BattleMinimap.ENEMY_COLOR, "enemy red")
	check(map.world_to_map(stage.ring_bounds.position).is_equal_approx(map.map_rect().position), "top-left transform")
	check(map.world_to_map(stage.ring_bounds.end).is_equal_approx(map.map_rect().end), "bottom-right transform")
	for character: String in BattleMinimap.FACE_IDS:
		var texture := root.get_node("ForestArenaResources").load_texture(BattleMinimap.FACE_IDS[character]) as AtlasTexture
		check(texture != null and texture.region.has_area(), "approved face loads " + character)
	check(map.markers[0].self and not map.markers[1].self, "self marker independent from color")
	var triangle_rect := Rect2(map.markers[0].point + Vector2(-5, -20), Vector2(10, 6))
	for marker: Dictionary in map.markers: check(not marker.name_rect.intersects(triangle_rect), "names do not cover self triangle")
	map.apply_settings({"transparency": 30, "marker_style": "face", "show_names": true}, 1.3)
	for index: int in map.markers.size():
		var rect: Rect2 = map.markers[index].name_rect
		check(Rect2(0, 0, 240, 150).encloses(rect), "large name stays inside map")
		for other: int in range(index + 1, map.markers.size()):
			check(not rect.intersects(map.markers[other].name_rect), "clustered names do not overlap")
	fighters[0].stocks = 0
	map.update_snapshot({"fighters": fighters})
	check(map.markers.size() == 7, "eliminated hidden")
	fighters[0].stocks = 1
	fighters[0].position = {"x": 99999, "y": -99999}
	map.update_snapshot({"fighters": fighters})
	check(map.markers.size() == 8 and map.map_rect().has_point(map.markers[0].point), "respawn and network position clamp")
	map.configure(stage, participants, &"p7", false)
	for marker: Dictionary in map.markers: check(marker.color == Color.WHITE, "free for all uniform white")
	map.apply_settings({"transparency": 90, "marker_style": "dot", "show_names": false})
	check(is_equal_approx(map.modulate.a, 0.1) and map.settings.marker_style == "dot", "whole map transparency and dot setting")
	for marker: Dictionary in map.markers: check(not marker.name_rect.has_area(), "name off removes label")
	map.apply_settings({"transparency": 0, "marker_style": "face", "show_names": true})
	check(is_equal_approx(map.modulate.a, 1), "opaque setting")
	map.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	print("BATTLE_MINIMAP: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
