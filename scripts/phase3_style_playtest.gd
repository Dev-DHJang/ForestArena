class_name Phase3StylePlaytest
extends Node2D

## A developer-only local scene for the Phase 3 hands-on comparison. It is not
## a product character-selection UI and never changes combat authority.

const CATALOG_PATH := "res://assets/loadouts/default_loadout_catalog.tres"
const RULES_PATH := "res://assets/combat/phase1_combat_rules.tres"
const STYLE_ENTRIES := [
	{"id": &"ja-hyun", "scene": "res://scenes/fighters/ja_hyun_fighter.tscn"},
	{"id": &"myo-ryung", "scene": "res://scenes/fighters/myo_ryung_fighter.tscn"},
	{"id": &"nabi", "scene": "res://scenes/fighters/nabi_fighter.tscn"},
	{"id": &"yu-ran", "scene": "res://scenes/fighters/yu_ran_fighter.tscn"},
]

var style_id: StringName
var match_controller: MatchController
var player_fighter: FighterController
var rival_fighter: FighterController
var _readout: Label


func _ready() -> void:
	style_id = _requested_style() if style_id.is_empty() else style_id
	var entry := _entry_for(style_id)
	if entry.is_empty():
		push_error("Unknown Phase 3 playtest style: %s" % style_id)
		return
	_build_arena()
	_build_match(entry)
	_build_readout()


func _process(_delta: float) -> void:
	if match_controller == null:
		return
	_update_readout(match_controller.snapshot())


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R and match_controller != null:
		match_controller.reset_match()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("142034"), true)
	draw_rect(Rect2(100, 586, 1080, 48), Color("365f4b"), true)
	draw_rect(Rect2(500, 418, 280, 24), Color("4e8062"), true)
	draw_dashed_line(Vector2(80, 660), Vector2(1200, 660), Color("e96969"), 4.0, 14.0)


func _build_arena() -> void:
	var world := Node2D.new()
	world.name = &"World"
	add_child(world)
	_add_platform(world, &"Ground", Vector2(640, 610), Vector2(1080, 48), false)
	_add_platform(world, &"Platform", Vector2(640, 430), Vector2(280, 24), true)


func _add_platform(parent: Node, node_name: StringName, position: Vector2, size: Vector2, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = 8 if one_way else 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	shape.one_way_collision = one_way
	body.add_child(shape)
	parent.add_child(body)


func _build_match(entry: Dictionary) -> void:
	var catalog := load(CATALOG_PATH) as LoadoutCatalog
	var rules := load(RULES_PATH) as CombatRules
	if catalog == null or rules == null:
		push_error("Phase 3 playtest resources could not load")
		return
	player_fighter = _fighter_from_entry(entry)
	rival_fighter = _fighter_from_entry(entry)
	if player_fighter == null or rival_fighter == null:
		push_error("Phase 3 playtest fighter scene could not load")
		return
	player_fighter.name = &"Player"
	player_fighter.position = Vector2(430, 520)
	player_fighter.controlled_by_input = true
	rival_fighter.name = &"Rival"
	rival_fighter.position = Vector2(850, 520)
	rival_fighter.controlled_by_input = false
	# A copied rival profile keeps the same authored style while retaining a
	# distinct match identity. This is a debug shell, not a loadout rule.
	rival_fighter.fighter_id = &"playtest-rival"
	get_node("World").add_child(player_fighter)
	get_node("World").add_child(rival_fighter)
	match_controller = MatchController.new()
	match_controller.name = &"MatchController"
	match_controller.rules = rules
	match_controller.player = player_fighter
	match_controller.training_dummy = rival_fighter
	match_controller.configure_profiles_on_ready = false
	add_child(match_controller)
	var profile_result := _build_profile(catalog, style_id)
	if not profile_result.succeeded():
		push_error("Phase 3 player profile failed: %s" % profile_result.error_codes)
		return
	var rival_result := _build_profile(catalog, style_id)
	if not rival_result.succeeded():
		push_error("Phase 3 rival profile failed: %s" % rival_result.error_codes)
		return
	var rival_profile := rival_result.profile
	rival_profile.character_id = rival_fighter.fighter_id
	if not player_fighter.configure_profile(profile_result.profile) or not rival_fighter.configure_profile(rival_profile):
		push_error("Phase 3 playtest profile injection failed")
		return
	match_controller.reset_match()


func _build_readout() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_readout = Label.new()
	_readout.position = Vector2(22, 18)
	_readout.size = Vector2(1230, 90)
	_readout.add_theme_font_size_override("font_size", 20)
	_readout.add_theme_color_override("font_color", Color("edf4ff"))
	layer.add_child(_readout)
	_update_readout(match_controller.snapshot() if match_controller != null else {})


func _update_readout(snapshot: Dictionary) -> void:
	if _readout == null:
		return
	var fighters: Array = snapshot.get("fighters", [])
	var player: Dictionary = fighters[0] if fighters.size() > 0 else {}
	var rival: Dictionary = fighters[1] if fighters.size() > 1 else {}
	_readout.text = "PHASE 3 STYLE PLAYTEST · %s\nWASD 이동 · Space 점프 · J/K/L 약/강/특 · H 회피 · U 궁극기 · R 재시작\n%s %d/%d HP %d stock  vs  rival %d/%d HP %d stock" % [style_id, style_id, roundi(float(player.get("current_hp", 0))), roundi(float(player.get("max_hp", 0))), int(player.get("stocks", 0)), roundi(float(rival.get("current_hp", 0))), roundi(float(rival.get("max_hp", 0))), int(rival.get("stocks", 0))]


func _requested_style() -> StringName:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--style="):
			return StringName(argument.trim_prefix("--style="))
	return &"ja-hyun"


func _entry_for(id: StringName) -> Dictionary:
	for entry: Dictionary in STYLE_ENTRIES:
		if entry.id == id:
			return entry
	return {}


func _fighter_from_entry(entry: Dictionary) -> FighterController:
	return load(String(entry.scene)).instantiate() as FighterController


func _build_profile(catalog: LoadoutCatalog, id: StringName) -> LoadoutBuildResult:
	var selection := LoadoutSelection.new()
	selection.character_id = id
	return LoadoutBuilder.build(selection, catalog)
