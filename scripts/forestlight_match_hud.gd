class_name ForestlightMatchHud
extends Control
## Snapshot-only presentation. No combat commands or fighter mutations.
const SKIN := preload("res://scripts/forestlight_ui.gd")
var identities: Dictionary = {}
var cards: Dictionary = {}
var grid: GridContainer
var _last_count := 0
var _fighter_ids: Array[String] = []
var _text_scale := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = SKIN.theme()
	grid = GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	get_viewport().size_changed.connect(_layout)
	_layout()

func configure(participants: Dictionary, text_scale := 1.0) -> void:
	identities = participants.duplicate(true)
	_text_scale = text_scale
	_layout()

func update_snapshot(snapshot: Dictionary) -> void:
	if grid == null: return
	var fighters: Array = snapshot.get("fighters", [])
	var fighter_ids: Array[String] = []
	for fighter: Dictionary in fighters: fighter_ids.append(String(fighter.id))
	if fighter_ids != _fighter_ids:
		for card: Node in grid.get_children():
			grid.remove_child(card)
			card.queue_free()
		cards.clear()
		_fighter_ids = fighter_ids
		_last_count = fighters.size()
		for index: int in fighters.size(): _create_card(String(fighters[index].id), index)
		_layout()
	for index: int in fighters.size():
		var fighter: Dictionary = fighters[index]
		var id := String(fighter.id)
		if not cards.has(id): continue
		var card: Dictionary = cards[id]
		var identity: Dictionary = identities.get(StringName(id), identities.get(id, {}))
		var character_name := String(identity.get("character_name", identity.get("character_id", id)))
		var team := String(fighter.get("team_id", identity.get("team_id", "")))
		var team_name := "A팀" if team == "alpha" else ("B팀" if team == "beta" else team)
		card.title.text = "P%d · %s%s" % [index + 1, character_name, (" · " + team_name) if not team_name.is_empty() else ""]
		card.nickname.text = String(identity.get("nickname", id))
		card.hp.max_value = maxf(1.0, float(fighter.get("max_hp", 1)))
		card.hp.value = float(fighter.get("current_hp", 0))
		card.health.text = "HP %d/%d" % [roundi(card.hp.value), roundi(card.hp.max_value)]
		var stocks := int(fighter.get("stocks", 0))
		card.stocks.text = "기회 %d" % stocks if stocks > 0 else "탈락"
		card.gauge.text = "궁극 %d/%d · 가드 %d" % [roundi(float(fighter.get("ultimate_gauge", 0))), roundi(float(snapshot.get("ultimate_gauge_max", 100))), roundi(float(fighter.get("guard_durability", 0)))]

func _create_card(id: String, index: int) -> void:
	var panel := PanelContainer.new()
	panel.name = "StatusP%d" % (index + 1)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", SKIN.style("panel.default", 18.0))
	grid.add_child(panel)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 1)
	panel.add_child(rows)
	var title := _label(rows)
	title.name = "CharacterTeam"
	var nickname := _label(rows)
	nickname.name = "Nickname"
	var hp := ProgressBar.new()
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp.custom_minimum_size.y = 7
	hp.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("b8de78")
	var track := StyleBoxFlat.new()
	track.bg_color = Color("163d35")
	hp.add_theme_stylebox_override("fill", fill)
	hp.add_theme_stylebox_override("background", track)
	rows.add_child(hp)
	var values := HBoxContainer.new()
	values.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(values)
	var health := _label(values)
	health.name = "Health"
	health.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stocks := _label(values)
	stocks.name = "RemainingChances"
	stocks.custom_minimum_size.x = 70
	stocks.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var gauge := _label(rows)
	gauge.name = "UltimateGuard"
	gauge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gauge.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	cards[id] = {"panel": panel, "title": title, "nickname": nickname, "hp": hp, "health": health, "stocks": stocks, "gauge": gauge}

func _label(parent: Node) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_color", SKIN.LIGHT)
	parent.add_child(label)
	return label

func _layout() -> void:
	if grid == null or not is_inside_tree(): return
	position = Vector2(64, 16)
	# Four cards per row leave the existing minimap and pause controls clear.
	grid.columns = mini(4, maxi(1, _last_count))
	var available := get_viewport_rect().size.x - 64.0 - 288.0
	var card_width := minf(280.0, (available - float(grid.columns - 1) * 8.0) / float(grid.columns))
	var font_size := roundi((16.0 if _last_count > 4 else 18.0) * _text_scale)
	for id: String in cards:
		var card: Dictionary = cards[id]
		card.panel.custom_minimum_size = Vector2(card_width, 120)
		for key: String in ["title", "nickname", "health", "stocks", "gauge"]:
			card[key].add_theme_font_size_override("font_size", font_size - (2 if key in ["nickname", "gauge"] else 0))
	grid.size = Vector2.ZERO
	size = Vector2(available, 252)
