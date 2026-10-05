class_name LocalAiApp
extends Node

const MATCH_SCENE := preload("res://scenes/main.tscn")
const PRESENTATION = preload("res://scripts/local_fighter_presentation.gd")
const BOT = preload("res://scripts/local_ai_command_source.gd")
const EXTRA_FIGHTER_SCENE := preload("res://scenes/fighters/ja_hyun_fighter.tscn")
const BACK_REQUEST_DEBOUNCE_MSEC := 200
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
var last_back_request_msec := -BACK_REQUEST_DEBOUNCE_MSEC
var selected_mode: LocalMatchConfig.Mode = LocalMatchConfig.Mode.AI
var solo_participant_count := 4
var team_size := 2
var active_config: LocalMatchConfig

func _ready() -> void:
	get_tree().quit_on_go_back = false
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
	_button("오프라인 대전", _show_prepare)
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
	_new_page("대전 준비 · " + _mode_name(selected_mode))
	_choice_labels("모드", ["스토리 · 첫 기록인장", "Solo · 각자전", "Team · 팀전", "AI · 1대1", "연습"], int(selected_mode), func(index: int) -> void:
		selected_mode = index as LocalMatchConfig.Mode
		_show_prepare())
	if selected_mode == LocalMatchConfig.Mode.SOLO:
		_choice_labels("참가 인원", ["2명", "4명", "6명", "8명"], [2, 4, 6, 8].find(solo_participant_count), func(index: int) -> void:
			solo_participant_count = [2, 4, 6, 8][index]
			_show_prepare())
	elif selected_mode == LocalMatchConfig.Mode.TEAM:
		_choice_labels("팀 인원", ["1 대 1", "2 대 2", "3 대 3", "4 대 4"], team_size - 1, func(index: int) -> void:
			team_size = index + 1
			_show_prepare())
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
	_label("숲의 경기장 · 중앙 통과형 발판 · 양끝 낭떠러지 · 3 STOCK · 온라인 없음", 18)
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


func _choice_labels(title: String, labels: Array[String], selected_index: int, callback: Callable) -> void:
	var row := HBoxContainer.new()
	body.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 180
	row.add_child(label)
	var options := OptionButton.new()
	options.custom_minimum_size = Vector2(320, 58)
	for item: String in labels: options.add_item(item)
	options.select(maxi(0, selected_index))
	options.item_selected.connect(func(index: int) -> void: callback.call(index))
	row.add_child(options)

func start_match() -> void:
	var config := _build_match_config()
	if config == null or not config.is_valid_definition():
		message = "대전 설정을 만들지 못했습니다. 보유 캐릭터와 선택을 확인해 주세요."
		_show_prepare()
		return
	active_config = config
	_close_match()
	match_scene = MATCH_SCENE.instantiate()
	match_scene.app_shell_mode = true
	match_controller = match_scene.get_node("MatchController")
	match_controller.loadout_catalog = catalog.combat
	var selections: Array[LoadoutSelection] = [config.participants[0].selection, config.participants[1].selection]
	match_controller.player_selection = selections[0]
	match_controller.training_dummy_selection = selections[1]
	for index: int in 2:
		var fighter := match_scene.get_node("World/Player" if index == 0 else "World/TrainingDummy") as FighterController
		fighter.character_data = catalog.combat.character_by_id(selections[index].character_id)
		fighter.fighter_id = config.participants[index].participant_id
		fighter.show_debug_body = false
		var presentation := PRESENTATION.new()
		presentation.name = "Presentation"
		fighter.add_child(presentation)
	match_controller.local_match_mode = config.mode
	match_controller.team_by_fighter_id = _team_map(config)
	match_controller.match_ended.connect(_on_match_ended.bind(match_controller))
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
	for index: int in range(2, config.participants.size()):
		_add_match_fighter(config.participants[index], index)
	_configure_bots(config)
	match_controller.reset_match()
	_show_match_controls()


func _build_match_config() -> LocalMatchConfig:
	if not store.valid(store.data) or not store.data.first_granted: return null
	var config := LocalMatchConfig.new()
	config.mode = selected_mode
	config.seed = 3001
	var total := 2
	if selected_mode == LocalMatchConfig.Mode.SOLO: total = solo_participant_count
	elif selected_mode == LocalMatchConfig.Mode.TEAM: total = team_size * 2
	var character_ids: Array[StringName] = []
	for character: CharacterData in catalog.combat.characters: character_ids.append(character.character_id)
	for index: int in total:
		var selection := LoadoutSelection.new()
		selection.character_id = StringName(store.data.selected_character) if index == 0 else character_ids[(character_ids.find(StringName(store.data.opponent_character)) + index - 1) % character_ids.size()]
		selection.accessory_id = StringName(store.data.selected_accessory) if index == 0 else &""
		var participant := LocalMatchParticipant.new()
		participant.participant_id = &"player" if index == 0 else StringName("ai_%d" % index)
		participant.selection = selection
		participant.human_controlled = index == 0
		if selected_mode == LocalMatchConfig.Mode.TEAM:
			participant.team_id = &"alpha" if index == 0 or index < team_size else &"beta"
		config.participants.append(participant)
	config.player = config.participants[0].selection.duplicate(true) as LoadoutSelection
	config.opponent = config.participants[1].selection.duplicate(true) as LoadoutSelection
	return config


func _team_map(config: LocalMatchConfig) -> Dictionary:
	var result := {}
	for participant: LocalMatchParticipant in config.participants:
		result[participant.participant_id] = participant.team_id
	return result


func _spawn_position(index: int) -> Vector2:
	var positions := [Vector2(360, 520), Vector2(900, 520), Vector2(540, 520), Vector2(720, 520), Vector2(240, 520), Vector2(1040, 520), Vector2(505, 340), Vector2(775, 340)]
	return positions[index]


func _add_match_fighter(participant: LocalMatchParticipant, index: int) -> void:
	var fighter := EXTRA_FIGHTER_SCENE.instantiate() as FighterController
	fighter.name = "Participant_%s" % participant.participant_id
	fighter.fighter_id = participant.participant_id
	fighter.character_data = catalog.combat.character_by_id(participant.selection.character_id)
	fighter.global_position = _spawn_position(index)
	fighter.spawn_position = fighter.global_position
	fighter.show_debug_body = false
	match_scene.get_node("World").add_child(fighter)
	var profile := LoadoutBuilder.build(participant.selection, catalog.combat)
	if not profile.succeeded() or not fighter.configure_profile(profile.profile):
		push_error("Local match participant profile failed: %s" % participant.participant_id)
	var presentation := PRESENTATION.new()
	presentation.name = "Presentation"
	fighter.add_child(presentation)
	match_controller.additional_fighters.append(fighter)


func _configure_bots(config: LocalMatchConfig) -> void:
	match_controller.bot_source = null
	match_controller.bot_sources.clear()
	if config.mode == LocalMatchConfig.Mode.PRACTICE: return
	for index: int in range(1, config.participants.size()):
		var participant := config.participants[index]
		var bot := BOT.new(participant.participant_id, config.seed + index * 97, {"reaction_interval_ticks": config.reaction_interval_ticks, "team_id": participant.team_id})
		# Preserve the legacy 1v1 hook while all local modes share the same AI path.
		if index == 1: match_controller.bot_source = bot
		else: match_controller.bot_sources.append(bot)


func _mode_name(mode: LocalMatchConfig.Mode) -> String:
	return ["스토리 · 첫 기록인장", "Solo · 각자전", "Team · 팀전", "AI · 1대1", "연습"][int(mode)]

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
	_button("계속하기", resume_match)
	_button("대전 종료 · 준비 화면", func() -> void:
		_close_match()
		_show_prepare())

func resume_match() -> void:
	if screen != "pause" or not is_instance_valid(match_scene) or match_controller == null: return
	match_scene.set_process_input(true)
	match_controller.pause_match(false)
	_show_match_controls()

func handle_back_request(request_msec: int = -1) -> void:
	var now_msec: int = Time.get_ticks_msec() if request_msec < 0 else request_msec
	if OS.is_debug_build():
		print("FOREST_ARENA_BACK_REQUEST " + JSON.stringify({"screen": screen, "msec": now_msec, "previous_msec": last_back_request_msec}))
	if now_msec >= last_back_request_msec and now_msec - last_back_request_msec < BACK_REQUEST_DEBOUNCE_MSEC:
		return
	last_back_request_msec = now_msec
	match screen:
		"shop", "prepare":
			_show_home()
		"match":
			pause_match()
		"pause":
			resume_match()
		"result":
			_close_match()
			_show_prepare()
		"storage_reset":
			_show_storage_error()
		"home", "first", "storage_error":
			get_tree().quit()

func _on_match_ended(winner: StringName, source: MatchController) -> void:
	call_deferred("_show_result_for_match", winner, source)

func _show_result_for_match(winner: StringName, source: MatchController) -> void:
	if not is_instance_valid(source) or source != match_controller: return
	_show_result(winner)

func _show_result(winner: StringName) -> void:
	if match_controller == null: return
	match_scene.get_node("Interface").visible = false
	screen = "result"
	match_controller.pause_match(true)
	match_scene.set_process_input(false)
	match_scene.get_node("Interface/TouchCommandSource").release_all_touches()
	match_scene._release_semantic_actions()
	var player_team := StringName(match_controller.team_by_fighter_id.get(&"player", &""))
	var player_won := winner == &"player" or (not player_team.is_empty() and match_controller.winner_team_id == player_team)
	_new_page("무승부" if match_controller.is_draw else ("승리!" if player_won else "패배"), false)
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
		screen = "storage_reset"
		_new_page("보유 정보 초기화")
		_label("이 기기의 캐릭터·장신구 보유와 선택을 초기화합니다. 모든 상품은 다시 무료로 구매할 수 있습니다.")
		_button("초기화", func() -> void:
			if store.reset_profile(): _show_first()
			else: _show_storage_error())
		_button("취소", _show_storage_error))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back_request()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and screen == "match":
		pause_match()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED] and screen == "pause":
		pause_match.call_deferred()
