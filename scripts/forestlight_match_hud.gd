class_name ForestlightMatchHud
extends Control
## Snapshot-only presentation. Identity and local ID come from the match shell.
const SKIN := preload("res://scripts/forestlight_ui.gd")
const GEOMETRY := preload("res://scripts/combat_ui_geometry.gd")
const FACE_IDS := BattleMinimap.FACE_IDS
var identities: Dictionary = {}
var cards: Dictionary = {}
var grid: Control
var local_id: StringName = &"player"
var team_mode := false
var safe_area_override := Rect2()
var _last_count := 0
var _fighter_ids: Array[String] = []
var _participant_numbers: Dictionary = {}
var _text_scale := 1.0
var _last_snapshot: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = SKIN.theme()
	grid = Control.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grid)
	get_viewport().size_changed.connect(_layout)
	_layout()

func configure(participants: Dictionary, text_scale := 1.0, p_local_id: StringName = &"player", p_team_mode := false) -> void:
	identities = participants.duplicate(true)
	_text_scale = text_scale
	local_id = p_local_id
	team_mode = p_team_mode
	_layout()
	if not _last_snapshot.is_empty(): update_snapshot(_last_snapshot)

func update_snapshot(snapshot: Dictionary) -> void:
	if grid == null: return
	_last_snapshot = snapshot.duplicate(true)
	var fighters: Array = snapshot.get("fighters", [])
	var fighter_ids: Array[String] = []
	_participant_numbers.clear()
	for index: int in fighters.size():
		var id := String(fighters[index].id)
		fighter_ids.append(id)
		_participant_numbers[id] = index + 1
	if team_mode:
		fighter_ids.sort_custom(func(a: String, b: String) -> bool:
			var first := String(identities.get(StringName(a), identities.get(a, {})).get("team_id", ""))
			var second := String(identities.get(StringName(b), identities.get(b, {})).get("team_id", ""))
			return first < second if first != second else _participant_numbers[a] < _participant_numbers[b])
	elif fighters.size() == 2 and fighter_ids.has(String(local_id)):
		fighter_ids.erase(String(local_id))
		fighter_ids.push_front(String(local_id))
	if fighter_ids != _fighter_ids:
		for card: Node in grid.get_children():
			grid.remove_child(card)
			card.queue_free()
		cards.clear()
		_fighter_ids = fighter_ids
		_last_count = fighters.size()
		for id: String in fighter_ids: _create_card(id, int(_participant_numbers[id]))
		_layout()
	for fighter: Dictionary in fighters:
		var id := String(fighter.id)
		if not cards.has(id): continue
		var card: Dictionary = cards[id]
		var identity: Dictionary = identities.get(StringName(id), identities.get(id, {}))
		var character_name := String(identity.get("character_name", identity.get("character_id", id)))
		var team := String(fighter.get("team_id", identity.get("team_id", "")))
		var team_name := "A" if team == "alpha" else ("B" if team == "beta" else team)
		card.title.text = "P%d %s%s" % [_participant_numbers[id], character_name, (" · " + team_name) if not team_name.is_empty() else ""]
		var character_id := String(identity.get("character_id", ""))
		if character_id != card.character_id:
			card.character_id = character_id
			card.face.texture = ForestArenaResources.load_texture(FACE_IDS[character_id]) if FACE_IDS.has(character_id) else null
		card.hp.max_value = maxf(1.0, float(fighter.get("max_hp", 1)))
		card.hp.value = float(fighter.get("current_hp", 0))
		card.health.text = "HP %d/%d" % [roundi(card.hp.value), roundi(card.hp.max_value)]
		var stocks := int(fighter.get("stocks", 0))
		card.stocks.text = "기회 %d" % stocks if stocks > 0 else "탈락"
		card.panel.modulate.a = 1.0 if stocks > 0 else 0.65

func _create_card(id: String, number: int) -> void:
	var panel := Panel.new()
	panel.name = "StatusP%d" % number
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", SKIN.style("panel.default", 8.0))
	grid.add_child(panel)
	var face := TextureRect.new()
	face.name = "Face"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(face)
	var title := _label(panel)
	title.name = "CharacterTeam"
	var hp := ProgressBar.new()
	hp.name = "HealthBar"
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("b8de78")
	var track := StyleBoxFlat.new()
	track.bg_color = Color("163d35")
	hp.add_theme_stylebox_override("fill", fill)
	hp.add_theme_stylebox_override("background", track)
	panel.add_child(hp)
	var health := _label(panel)
	health.name = "Health"
	var stocks := _label(panel)
	stocks.name = "RemainingChances"
	stocks.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cards[id] = {"panel": panel, "title": title, "face": face, "character_id": "", "hp": hp, "health": health, "stocks": stocks}

func _label(parent: Node) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_color", SKIN.LIGHT)
	label.add_theme_color_override("font_outline_color", Color("122d38"))
	label.add_theme_constant_override("outline_size", 2)
	parent.add_child(label)
	return label

func _layout() -> void:
	if grid == null or not is_inside_tree(): return
	var safe := safe_area_override if safe_area_override.has_area() else GEOMETRY.safe_rect(get_viewport())
	position = safe.position + Vector2(16, 12)
	# Keep the 240x150 minimap and its pause/leave control reservation untouched.
	var available := safe.size.x - 288.0
	var columns := mini(4, maxi(1, _last_count))
	var width := minf(280.0, (available - float(columns - 1) * 8.0) / float(columns))
	var height := 64.0 + 40.0 * (_text_scale - 1.0)
	var font_size := roundi(16 * _text_scale)
	for index: int in _fighter_ids.size():
		var card: Dictionary = cards[_fighter_ids[index]]
		var x := (available - width) if _last_count == 2 and index == 1 else float(index % columns) * (width + 8)
		card.panel.position = Vector2(x, float(index / columns) * (height + 6))
		card.panel.size = Vector2(width, height)
		card.face.position = Vector2(8, 6)
		card.face.size = Vector2(32, 32)
		card.title.position = Vector2(48, 3)
		card.title.size = Vector2(width - 56, 29)
		card.hp.position = Vector2(48, 33)
		card.hp.size = Vector2(width - 56, 5)
		for key: String in ["title", "health", "stocks"]:
			card[key].add_theme_font_size_override("font_size", font_size)
		var row_height := maxf(26, maxf(card.health.get_combined_minimum_size().y, card.stocks.get_combined_minimum_size().y))
		card.health.position = Vector2(8, height - row_height - 2)
		card.health.size = Vector2(width - 112, row_height)
		card.stocks.position = Vector2(width - 104, height - row_height - 2)
		card.stocks.size = Vector2(96, row_height)
	grid.size = Vector2(available, height * ceilf(float(_last_count) / columns) + 6)
	size = grid.size

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]: _layout()
