class_name LocalAiApp
extends Node

const MATCH_SCENE := preload("res://scenes/main.tscn")
const PRESENTATION = preload("res://scripts/local_fighter_presentation.gd")
const BOT = preload("res://scripts/local_ai_command_source.gd")
var catalog := LocalPlayCatalog.new()
var store: LocalPlayerStore
var save_path := "user://local_player.json"
var layer: CanvasLayer
var page: Control
var body: VBoxContainer
var match_scene: Node2D
var match_controller: MatchController
var screen := ""
var message := ""

func _ready() -> void:
	layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	store = LocalPlayerStore.new(catalog, save_path)
	if not store.load_profile():
		_show_storage_error()
	else:
		message = "이전 저장 백업을 복구했습니다." if store.recovered else ""
		_show_home() if store.data.first_granted else _show_first()

func _new_page(title: String, background := true) -> void:
	if page != null:
		layer.remove_child(page)
		page.queue_free()
	page = Control.new()
	layer.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if background:
		var image := TextureRect.new()
		image.texture = ForestArenaResources.load_texture("fa.background.bg.lobby.forest.town")
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(image)
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.12, 0.13, 0.88 if background else 0.75)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	page.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 84)
	for side: String in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 30)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)
	_label(title, 32)
	if not message.is_empty(): _label(message, 19)
	message = ""

func _label(text: String, font_size := 22) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	body.add_child(label)
	return label

func _button(text: String, callback: Callable, parent: Node = null, disabled := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(190, 58)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 21)
	button.disabled = disabled
	var style := StyleBoxTexture.new()
	style.texture = ForestArenaResources.load_texture("fa.ui.button.base.btn.secondary.m.default")
	for side: int in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_texture_margin(side, 16)
		style.set_content_margin(side, 10)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	var pressed := style.duplicate() as StyleBoxTexture
	pressed.texture = ForestArenaResources.load_texture("fa.ui.button.base.btn.secondary.m.pressed")
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color("243d36"))
	button.pressed.connect(callback)
	(parent if parent != null else body).add_child(button)
	if OS.is_debug_build(): _log_button.call_deferred(button)
	return button

func _log_button(button: Button) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(button) or not button.is_inside_tree() or button.disabled: return
	var center := button.get_global_rect().get_center() / button.get_viewport_rect().size
	if center.x < 0 or center.x > 1 or center.y < 0 or center.y > 1: return
	print("FOREST_ARENA_UI_BUTTON " + JSON.stringify({"screen": screen, "text": button.text, "x": center.x, "y": center.y}))

func _show_first() -> void:
	screen = "first"
	_new_page("Forest Arena · 첫 캐릭터 선택")
	_label("함께 시작할 캐릭터 한 명을 받으세요. 다른 캐릭터도 상점에서 0원으로 구매할 수 있습니다.")
	_character_cards(false, func(id: String) -> void:
		if store.grant_first(id): _show_home()
		else:
			message = store.error
			_show_first())

func _character_cards(owned_only: bool, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	for character: CharacterData in catalog.combat.characters:
		if owned_only and not store.owns(String(character.character_id)): continue
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)
		var image := TextureRect.new()
		image.texture = character.concept_image
		image.custom_minimum_size = Vector2(190, 120 if owned_only else 200)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(image)
		_button(character.display_name, callback.bind(String(character.character_id)), card)

func _show_home() -> void:
	screen = "home"
	_new_page("Forest Arena · 로컬 AI 대전")
	_label("네 캐릭터와 함께 숲의 경기장으로")
	_button("대전 준비", _show_prepare)
	_button("상점 · 모두 0원", _show_shop)
	_label("구매와 선택은 이 기기에 저장됩니다. 인터넷 연결 없이 플레이할 수 있습니다.", 18)

func _show_shop() -> void:
	screen = "shop"
	_new_page("상점 · 0원 무료 구매")
	for item: Dictionary in catalog.products:
		var row := HBoxContainer.new()
		body.add_child(row)
		var image := TextureRect.new()
		image.texture = catalog.combat.character_by_id(StringName(item.id)).concept_image if item.kind == "character" else ForestArenaResources.load_texture(item.asset_id)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(64, 64)
		row.add_child(image)
		var text := Label.new()
		text.text = "%s · %s" % [item.name, item.description]
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var owned := store.owns(item.id)
		_button("보유 중" if owned else "0원 · 무료 구매", func() -> void:
			if not store.purchase(item.id): message = store.error
			_show_shop(), row, owned)
	_button("로비", _show_home)

func _show_prepare() -> void:
	screen = "prepare"
	_new_page("대전 준비 · 1대1 보통 AI")
	_label("내 캐릭터: " + catalog.product(store.data.selected_character).name)
	_character_cards(true, func(id: String) -> void:
		if not store.select(id, store.data.selected_accessory, store.data.opponent_character): message = store.error
		_show_prepare())
	_choice("장신구", [""] + store.data.accessories, store.data.selected_accessory, func(id: String) -> void:
		if not store.select(store.data.selected_character, id, store.data.opponent_character): message = store.error
		_show_prepare())
	var opponents: Array = []
	for character: CharacterData in catalog.combat.characters: opponents.append(String(character.character_id))
	_choice("AI 캐릭터", opponents, store.data.opponent_character, func(id: String) -> void:
		if not store.select(store.data.selected_character, store.data.selected_accessory, id): message = store.error
		_show_prepare())
	_label("숲의 경기장 · 중앙 통과형 발판 · 양끝 낭떠러지 · 3 STOCK", 18)
	_button("대전 시작", start_match)
	_button("로비", _show_home)

func _choice(title: String, ids: Array, selected: String, callback: Callable) -> void:
	var row := HBoxContainer.new()
	body.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 180
	row.add_child(label)
	var options := OptionButton.new()
	options.custom_minimum_size = Vector2(320, 58)
	for id: String in ids:
		options.add_item("미장착" if id == "" else String(catalog.product(id).name))
	options.select(ids.find(selected))
	options.item_selected.connect(func(index: int) -> void: callback.call(ids[index]))
	row.add_child(options)

func start_match() -> void:
	var config := LocalMatchConfig.from_store(store)
	if config == null: return
	_close_match()
	match_scene = MATCH_SCENE.instantiate()
	match_scene.app_shell_mode = true
	match_scene.get_node("ArenaVisual").forest_stage = true
	match_controller = match_scene.get_node("MatchController")
	match_controller.loadout_catalog = catalog.combat
	var selections: Array[LoadoutSelection] = [config.player, config.opponent]
	match_controller.player_selection = selections[0]
	match_controller.training_dummy_selection = selections[1]
	for index: int in 2:
		var fighter := match_scene.get_node("World/Player" if index == 0 else "World/TrainingDummy") as FighterController
		fighter.character_data = catalog.combat.character_by_id(selections[index].character_id)
		fighter.fighter_id = &"player" if index == 0 else &"opponent"
		fighter.show_debug_body = false
		fighter.add_child(PRESENTATION.new())
	match_controller.bot_source = BOT.new(&"opponent", config.seed, {"reaction_interval_ticks": config.reaction_interval_ticks})
	match_controller.match_ended.connect(_on_match_ended)
	match_scene.get_node("Interface/TouchCommandSource").extended_actions = true
	add_child(match_scene)
	if OS.is_debug_build(): match_scene.add_child(load("res://scripts/local_performance_probe.gd").new())
	match_scene.get_node("Interface/Restart").hide()
	match_scene.get_node("Interface/DebugReadout").hide()
	match_scene.get_node("Interface/PhaseLabel").hide()
	match_scene.get_node("Interface/HudPanel").hide()
	var readout := match_scene.get_node("Interface/MatchReadout") as Label
	readout.position = Vector2(84, 24)
	readout.add_theme_font_size_override("font_size", 20)
	readout.add_theme_color_override("font_outline_color", Color("122d38"))
	readout.add_theme_constant_override("outline_size", 8)
	_show_match_controls()

func _show_match_controls() -> void:
	screen = "match"
	match_scene.get_node("Interface").visible = true
	if page != null:
		layer.remove_child(page)
		page.queue_free()
	page = Control.new()
	layer.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pause := _button("일시정지", pause_match, page)
	pause.position = Vector2(1020, 125)

func pause_match() -> void:
	if match_controller == null or screen == "result": return
	match_scene.get_node("Interface").visible = false
	match_controller.pause_match(true)
	match_scene.set_process_input(false)
	match_scene.get_node("Interface/TouchCommandSource").release_all_touches()
	match_scene._release_semantic_actions()
	screen = "pause"
	_new_page("일시정지", false)
	_button("계속하기", func() -> void:
		match_scene.set_process_input(true)
		match_controller.pause_match(false)
		_show_match_controls())
	_button("대전 종료 · 준비 화면", func() -> void:
		_close_match()
		_show_prepare())

func _on_match_ended(winner: StringName) -> void:
	call_deferred("_show_result", winner)

func _show_result(winner: StringName) -> void:
	if match_controller == null: return
	match_scene.get_node("Interface").visible = false
	screen = "result"
	match_controller.pause_match(true)
	match_scene.set_process_input(false)
	match_scene.get_node("Interface/TouchCommandSource").release_all_touches()
	match_scene._release_semantic_actions()
	_new_page("무승부" if match_controller.is_draw else ("승리!" if winner == &"player" else "패배"), false)
	_button("같은 조건으로 재대전", start_match)
	_button("대전 준비", func() -> void:
		_close_match()
		_show_prepare())
	_button("로비", func() -> void:
		_close_match()
		_show_home())

func _close_match() -> void:
	if is_instance_valid(match_scene):
		match_scene._release_semantic_actions()
		match_scene.get_node("Interface/TouchCommandSource").release_all_touches()
		remove_child(match_scene)
		match_scene.queue_free()
	match_scene = null
	match_controller = null

func _show_storage_error() -> void:
	screen = "storage_error"
	_new_page("저장 확인 필요")
	_label(store.error)
	_button("다시 읽기", func() -> void:
		if store.load_profile(): _show_home() if store.data.first_granted else _show_first()
		else: _show_storage_error())
	_button("저장 초기화 안내", func() -> void:
		_new_page("보유 정보 초기화")
		_label("이 기기의 캐릭터·장신구 보유와 선택을 초기화합니다. 모든 상품은 다시 무료로 구매할 수 있습니다.")
		_button("초기화", func() -> void:
			if store.reset_profile(): _show_first()
			else: _show_storage_error())
		_button("취소", _show_storage_error))

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and screen == "match":
		pause_match()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED] and screen == "pause":
		pause_match.call_deferred()
