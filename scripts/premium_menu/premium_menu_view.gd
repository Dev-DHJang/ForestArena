class_name PremiumMenuView
extends Control

signal action(action_id: String, payload: Dictionary)
const STYLE = preload("res://scripts/premium_menu/premium_menu_theme.gd")
const SCREENS := {
	"character_collection": ["SCR_04_CharacterCollection", "캐릭터", "동료의 방 / CHARACTER", "character-room"],
	"character_detail": ["SCR_05_CharacterDetail", "캐릭터 상세", "동료의 방 / CHARACTER", "character-room"],
	"accessory_collection": ["SCR_06_AccessoryCollection", "장신구", "숲속 공방 / ACCESSORY", "accessory-workshop"],
	"accessory_detail": ["SCR_07_AccessoryDetail", "장신구 상세", "숲속 공방 / ACCESSORY", "accessory-workshop"],
	"preset": ["SCR_08_Preset", "전투 편성", "나의 편성 / PRESET", "character-room"],
	"shop": ["SCR_19_Shop", "상점", "숲의 교역소 / SHOP", "shop-market"],
	"collection": ["SCR_20_Collection", "도감", "숲의 기록실 / COLLECTION", "archive"],
	"mission": ["SCR_21_Mission", "미션", "숲의 기록실 / MISSION", "archive"],
	"social": ["SCR_22_Social", "친구", "동료의 쉼터 / SOCIAL", "social-lodge"],
	"rank": ["SCR_23_Rank", "랭크", "숲의 전망대 / RANK", "observatory"],
	"profile": ["SCR_24_Profile", "프로필", "나의 기록 / PROFILE", "observatory"],
	"settings": ["EXT_06_GeneralSettings", "일반 설정", "설정 / SETTINGS", "archive"],
	"controls": ["CBT_08_Settings", "조작 설정", "설정 / CONTROLS", "archive"],
}
const ACTION_NAMES := {"light": "약공격", "heavy": "강공격", "special": "특수 기술", "ultimate": "궁극기", "attack_light": "약공격", "attack_heavy": "강공격", "attack_special": "특수 기술", "attack_ultimate": "궁극기"}
var app: Node
var state: Dictionary
var draft: Dictionary
var preset: Dictionary
var preset_index := 0
var content: Control
var main: Control
var footer: HBoxContainer
var modal: Control
var text_scale := 1.0
var preview: Control
var _controls_preview: Control
var _draft_labels: Dictionary = {}
var _fit_scale := 1.0
var service_snapshot: Dictionary = {}
var _identity_url: LineEdit
var _social_search: LineEdit
var _nickname: LineEdit

func build(owner: Node, current: Dictionary, next_settings: Dictionary, next_preset: Dictionary, slot: int) -> void:
	app = owner
	state = current
	draft = next_settings
	preset = next_preset
	preset_index = slot
	text_scale = float(app._text_scale())
	var safe := CombatUiGeometry.safe_rect(app.get_viewport())
	_fit_scale = minf(1.0, minf(safe.size.x / 1280.0, safe.size.y / 720.0))
	name = "PremiumMenuView"
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = STYLE.make(text_scale)
	set_meta("menu_screen_id", SCREENS[state.id][0])
	set_meta("menu_id", state.id)
	set_meta("entry_context", state.get("entry_context", "lobby"))
	if app.get("menu_service") != null: service_snapshot = app.menu_service.snapshot(String(state.id))
	_layout_shell()
	resized.connect(_resize_canvas)
	_resize_canvas.call_deferred()
	match String(state.id):
		"character_collection", "character_detail": _character()
		"accessory_collection", "accessory_detail": _accessories()
		"preset": _presets()
		"shop": _shop()
		"collection": _collection()
		"mission": _missions()
		"social": _social()
		"rank": _rank()
		"profile": _profile()
		"settings", "controls": _settings()
	if app.db_mode and not app.db_client.pending.is_empty():
		var retry := _button("DB 재시도", "retry_db", {}, content)
		retry.add_theme_font_size_override("font_size", roundi(17 * text_scale))
		_place(retry, Rect2(676, 32, 158, 72))
	if state.get("local_load_error", false):
		var retry := _button("메뉴 재시도", "retry_local", {}, content)
		retry.add_theme_font_size_override("font_size", roundi(17 * text_scale))
		_place(retry, Rect2(846, 32, 178, 72))

func _layout_shell() -> void:
	var bg := TextureRect.new()
	bg.texture = ForestArenaResources.load_texture("fa.ui.menu.v07.background." + String(SCREENS[state.id][3]))
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color(STYLE.BG, 0.42)
	veil.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(veil)
	veil.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	content = Control.new()
	content.name = "Centered1280Content"
	add_child(content)
	content.set_anchors_and_offsets_preset(PRESET_CENTER)
	content.offset_left = -640
	content.offset_right = 640
	content.offset_top = -360
	content.offset_bottom = 360
	_rect(Color(STYLE.BG, 0.88), Rect2(0, 0, 1280, 128), content)
	_rect(Color(STYLE.BG, 0.91), Rect2(0, 608, 1280, 112), content)
	var back := _button("뒤로", "back", {}, content)
	_place(back, Rect2(64, 32, 100, 72))
	back.icon = ForestArenaResources.load_texture("fa.ui.menu.v07.icon.arrow")
	back.expand_icon = true
	back.add_theme_constant_override("icon_max_width", 22)
	_label(String(SCREENS[state.id][2]), content, 16, STYLE.GOLD, Rect2(184, 32, 750, 26))
	_label(String(SCREENS[state.id][1]), content, 34, STYLE.TEXT, Rect2(184, 65, 750, 47))
	var all := _button("전체 메뉴", "all_menu", {}, content)
	_place(all, Rect2(1036, 32, 180, 72))
	all.pressed.connect(_all_menu)
	main = Control.new()
	main.name = "MenuBody"
	content.add_child(main)
	_place(main, Rect2(64, 140, 1152, 456))
	footer = HBoxContainer.new()
	content.add_child(footer)
	_place(footer, Rect2(64, 616, 1152, 72))
	var notice := ScrollContainer.new()
	notice.name = "FooterNoticeScroll"
	notice.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	notice.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	notice.custom_minimum_size = Vector2(330, 72 / maxf(_fit_scale, 0.5))
	notice.size_flags_horizontal = SIZE_EXPAND_FILL
	notice.set_meta("qa_id", "menu/%s/notice_scroll" % state.id)
	footer.add_child(notice)
	var note := _label(String(state.get("message", "")), notice, 17, STYLE.MINT)
	note.size_flags_horizontal = SIZE_EXPAND_FILL
	if note.text.is_empty():
		note.text = "편성 초안 선택 · 실제 적용은 편성에서" if state.get("preset_edit", false) else _footer_hint()

func _resize_canvas() -> void:
	if not is_instance_valid(content) or not is_inside_tree(): return
	var safe := CombatUiGeometry.safe_rect(get_viewport())
	_fit_scale = minf(1.0, minf(safe.size.x / 1280.0, safe.size.y / 720.0))
	for target: Node in find_children("*", "BaseButton", true, false):
		var button := target as BaseButton
		button.custom_minimum_size.x = maxf(button.custom_minimum_size.x, 72 / maxf(_fit_scale, 0.5))
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 72 / maxf(_fit_scale, 0.5))
	for target: Node in find_children("*", "HSlider", true, false) + find_children("*", "LineEdit", true, false):
		var field := target as Control
		field.custom_minimum_size.y = maxf(field.custom_minimum_size.y, 72 / maxf(_fit_scale, 0.5))
	content.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
	content.size = Vector2(1280, 720)
	content.position = safe.get_center() - Vector2(640, 360)
	content.pivot_offset = Vector2(640, 360)
	content.scale = Vector2.ONE * _fit_scale

func _footer_hint() -> String:
	match String(state.id):
		"shop": return "모든 상품 0원 · 무료 구매"
		"collection": return "보유 기록과 기존 설명 · 읽기 전용"
		"settings", "controls": return "변경 후 적용을 누르세요"
		"mission": return "실제 완료 기록 · 보상 없음"
		"social": return "친구 · 요청 · 실제 LAN 초대"
		"rank": return "정상 종료한 LAN 대전만 순위 반영"
		"profile": return "오프라인과 LAN 기록을 따로 표시합니다"
	return "캐릭터와 장신구를 살펴보세요"

func _place(node: Control, area: Rect2) -> void:
	node.position = area.position
	node.size = area.size

func _rect(color: Color, area: Rect2, parent: Node) -> ColorRect:
	var node := ColorRect.new()
	node.color = color
	node.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(node)
	_place(node, area)
	return node

func _label(text: String, parent: Node, font_size := 20, color := STYLE.TEXT, area := Rect2()) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", roundi(font_size * text_scale))
	if font_size >= 28:
		var font := FontVariation.new()
		font.base_font = (theme.default_font as FontVariation).base_font if theme.default_font is FontVariation else theme.default_font
		font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
		node.add_theme_font_override("font", font)
	node.add_theme_color_override("font_color", color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(node)
	if area.size != Vector2.ZERO: _place(node, area)
	return node

func _button(text: String, id: String, payload: Dictionary, parent: Node, selected := false, primary := false, disabled := false) -> Button:
	var node := Button.new()
	node.text = text + (" ✓" if selected else "")
	node.custom_minimum_size = Vector2(72, 72) / maxf(_fit_scale, 0.5)
	node.disabled = disabled
	node.set_meta("qa_id", "menu/%s/%s" % [state.id, id])
	node.set_meta("menu_action", id)
	if selected or primary: node.add_theme_stylebox_override("normal", STYLE.surface(selected, primary))
	if primary: node.add_theme_color_override("font_color", STYLE.BG)
	node.pressed.connect(func() -> void:
		ForestArenaAudio.play_event(&"ui_back" if id == "back" else &"ui_select", {})
		action.emit(id, payload))
	parent.add_child(node)
	return node

func _footer_button(text: String, id: String, payload: Dictionary, primary := false, disabled := false) -> Button:
	var node := _button(text, id, payload, footer, false, primary, disabled)
	node.custom_minimum_size.x = 180
	return node

func _scroll(parent: Node, area: Rect2, key := "scroll") -> VBoxContainer:
	var scroll := ScrollContainer.new()
	parent.add_child(scroll)
	_place(scroll, area)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_meta("qa_id", "menu/%s/%s" % [state.id, key])
	scroll.scroll_vertical = int(state.get(key, 0))
	scroll.get_v_scroll_bar().value_changed.connect(func(value: float) -> void: state[key] = int(value))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(column)
	scroll.set_deferred("scroll_vertical", int(state.get(key, 0)))
	return column

func _panel_column(parent: Node, area: Rect2, key := "detail_scroll") -> VBoxContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	_place(panel, area)
	var margin := MarginContainer.new()
	panel.add_child(margin)
	for side: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	scroll.get_v_scroll_bar().value_changed.connect(func(value: float) -> void: state[key] = int(value))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(column)
	scroll.set_deferred("scroll_vertical", int(state.get(key, 0)))
	return column

func _tabs(labels: Array, key: String, parent: Node, selected: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	for entry: Variant in labels:
		var label: String = String(entry[0] if entry is Array else entry)
		var value: String = String(entry[1] if entry is Array else entry)
		var node := _button(label, "update", {key: value, "scroll": 0}, row, value == selected)
		node.set_meta("qa_id", "menu/%s/%s/%s" % [state.id, key, value])
		node.size_flags_horizontal = SIZE_EXPAND_FILL
	return row

func _texture(id: String, parent: Node, area: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = ForestArenaResources.load_texture(id)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(node)
	_place(node, area)
	return node

func _owned_label(id: String) -> String:
	if id == String(app.store.data.selected_character) or id == String(app.store.data.selected_accessory): return "✓ 장착 중"
	return "보유" if app.store.owns(id) else "미보유"

func _product_name(id: String, fallback := "선택 없음") -> String:
	var item: Dictionary = app.catalog.product(id)
	return String(item.get("name", fallback))

func _character_matches(character: CharacterData) -> bool:
	if state.filter == "균형": return &"balanced" in character.tags
	if state.filter == "근접": return not (&"balanced" in character.tags)
	return true

func _character_id() -> String:
	var selected: String = String(state.get("selected_id", app.store.data.selected_character))
	if not app.catalog.is_playable_character(StringName(selected)): selected = String(app.catalog.combat.characters[0].character_id)
	if not _character_matches(app.catalog.combat.character_by_id(StringName(selected))):
		for character: CharacterData in app.catalog.playable_characters():
			if _character_matches(character):
				selected = String(character.character_id)
				break
	state.selected_id = selected
	return selected

func _character() -> void:
	var id := _character_id()
	var character: CharacterData = app.catalog.combat.character_by_id(StringName(id))
	var left := VBoxContainer.new()
	main.add_child(left)
	_place(left, Rect2(0, 0, 286, 456))
	var filters := _tabs(["전체", "균형", "근접"], "filter", left, String(state.filter))
	for button: Node in filters.get_children():
		(button as Button).add_theme_font_size_override("font_size", roundi(18 * text_scale))
	var rows := _scroll(main, Rect2(0, 84, 286, 372))
	var visible := 0
	for item: Dictionary in app.catalog.products:
		if item.kind != "character" or not app.catalog.is_playable_character(StringName(item.id)): continue
		var data: CharacterData = app.catalog.combat.character_by_id(StringName(item.id))
		if not _character_matches(data): continue
		visible += 1
		var row := _button("%s\n%s" % [item.name, _owned_label(item.id)], "update", {"selected_id": item.id, "detail_scroll": 0}, rows, item.id == id)
		row.icon = ForestArenaResources.load_texture("fa.ui.menu.v07.character." + String(item.id))
		row.expand_icon = true
		row.add_theme_constant_override("icon_max_width", 62)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 86
		row.set_meta("qa_id", "menu/%s/character/%s" % [state.id, item.id])
	if visible == 0: _label("조건에 맞는 캐릭터가 없습니다.\n전체 필터로 돌아가세요.", rows, 20, STYLE.MUTED)
	_texture("fa.ui.menu.v07.character." + id, main, Rect2(298, -12, 424, 476))
	var right := _panel_column(main, Rect2(746, 0, 406, 456))
	_label(character.display_name, right, 32)
	_label(character.combat_role, right, 20, STYLE.GOLD)
	_label(_owned_label(id), right, 17, STYLE.MINT)
	if state.id == "character_detail":
		_tabs(["기술", "연계", "이야기"], "tab", right, String(state.tab))
		match String(state.tab):
			"기술":
				_label(_passive_text(character.passive_description), right, 19, STYLE.MUTED)
				for slot: MoveSlotData in character.base_move_set.slots:
					var attack: AttackData = slot.attack
					_label("%s\n피해 %s · 준비 %.2f초 / 공격 %.2f초 / 회복 %.2f초" % [_attack_title(character, attack.attack_id), str(attack.damage), attack.startup_ticks / 60.0, attack.active_ticks / 60.0, attack.recovery_ticks / 60.0], right, 18)
			"연계":
				_label("기본 연속 공격 %d타" % character.base_move_set.combo_count, right, 23, STYLE.GOLD)
				for link: ComboLinkData in character.base_move_set.combo_links:
					_label("%s → %s\n입력: %s · %s" % [_attack_title(character, link.from_attack_id), _attack_title(character, link.next_attack_id), _action_name(String(link.input_action_id)), "적중 후 연결" if link.requires_hit else "연결 가능"], right, 18)
				if character.base_move_set.combo_links.is_empty(): _label("현재 기술 데이터에 추가 연계가 없습니다.", right, 20, STYLE.MUTED)
			"이야기":
				_label(character.background_setting, right, 20)
		_footer_button("연습 준비", "practice", {}, false, not app.store.owns(id) or state.get("preset_edit", false))
	else:
		var combat_summary: String = character.passive_description.get_slice("실제", 0).strip_edges()
		_label(combat_summary, right, 20)
		_label("상시 효과 준비 중", right, 18, STYLE.MUTED)
		_label("큰 원화로 모습을 살펴보고\n기술과 전투 특징을 확인하세요.", right, 19, STYLE.MUTED)
		var detail := _button("기술 살펴보기", "open", {"id": "character_detail", "params": {"selected_id": id, "filter": state.filter, "tab": "기술", "preset_edit": state.get("preset_edit", false)}}, right)
		detail.set_meta("qa_id", "menu/character_collection/detail")
		_footer_button("상세 보기", "open", {"id": "character_detail", "params": {"selected_id": id, "filter": state.filter, "preset_edit": state.get("preset_edit", false)}}).set_meta("qa_id", "menu/character_collection/detail_footer")
	_footer_button("초안에 넣기" if state.get("preset_edit", false) else "이 캐릭터 선택", "select", {"id": id}, true)

func _passive_text(value: String) -> String:
	if "PassiveData" in value or "향후" in value or "정의" in value: return "상시 효과 준비 중"
	return value

func _attack_title(character: CharacterData, id: StringName) -> String:
	for slot: MoveSlotData in character.base_move_set.slots:
		if slot.attack.attack_id != id: continue
		var attack: AttackData = slot.attack
		var directions := ["", "앞 ", "뒤 ", "위 ", "아래 ", "좌우 ", ""]
		var where := "공중 " if attack.activation_context == AttackData.ActivationContext.AIR else ""
		return where + String(directions[attack.input_direction]) + _action_name(String(attack.action_id))
	return "연계 기술"

func _action_name(value: String) -> String:
	return String(ACTION_NAMES.get(value, value.replace("_", " ")))

func _accessory_icon(id: String) -> String:
	var item: Dictionary = app.catalog.product(id)
	if app.catalog.is_playable_accessory(StringName(id)): return String(item.get("asset_id", "fa.icon.icon.accessory"))
	id = id.trim_prefix("fixture-").replace("-", "_")
	var names := {"iron_armor": "armor", "boxing_gloves": "glove", "thorns": "balance", "explosive_gloves": "jump", "ultimate_charm": "focus", "phoenix_revive": "wing"}
	return "fa.ui.menu.v07.icon." + String(names.get(id, "gear"))

func _accessory_category(id: String) -> String:
	id = id.trim_prefix("fixture-").replace("-", "_")
	if id == "iron_armor": return "방어"
	if id in ["thorns", "explosive_gloves", "phoenix_revive"]: return "이동"
	return "기술"

func _accessories() -> void:
	var id: String = String(state.get("selected_id", app.store.data.selected_accessory))
	if not app.catalog.is_playable_accessory(StringName(id)): id = String(app.catalog.PLAYABLE_ACCESSORY_IDS[0])
	state.selected_id = id
	var rows := _scroll(main, Rect2(0, 0, 286, 456))
	for item: Dictionary in app.catalog.playable_products():
		if item.kind != "accessory": continue
		var row := _button("%s\n%s" % [item.name, _owned_label(item.id)], "update", {"selected_id": item.id}, rows, item.id == id)
		row.icon = ForestArenaResources.load_texture(_accessory_icon(item.id))
		row.expand_icon = true
		row.add_theme_constant_override("icon_max_width", 62)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 86
		row.set_meta("qa_id", "menu/accessory_collection/accessory/" + String(item.id))
	_texture(_accessory_icon(id), main, Rect2(310, 30, 390, 390))
	var item: Dictionary = app.catalog.product(id)
	var right := _panel_column(main, Rect2(746, 0, 406, 456))
	_label(item.name, right, 32)
	_label(_owned_label(id), right, 20, STYLE.MINT)
	_label("전방 발사 · 회수", right, 23, STYLE.GOLD)
	_label("팔에서 앞으로 나갔다 돌아옵니다.\n발사 중 요요에 맞으면 0.5초 경직.\n피해 없이 가드로 막을 수 있습니다.", right, 20)
	_label("쿨타임 10초 · 지상·공중 사용\n사용 중 이동과 다른 행동 제한", right, 19, STYLE.MUTED)
	_label("기존 장신구의 보유 기록은 보존됩니다.", right, 17, STYLE.MUTED)
	if app.store.owns(id):
		_footer_button("장신구 해제", "unequip", {})
		_footer_button("초안에 넣기" if state.get("preset_edit", false) else "이 장신구 장착", "select", {"id": id}, true)
	else:
		_footer_button("상점에서 0원 획득", "open", {"id": "shop", "params": {"category": "accessory"}}, true)

func _card(item: Dictionary, parent: Node, selected := false, behavior := "shop") -> void:
	var panel := PanelContainer.new()
	# Card decoration must let finger drags reach its ScrollContainer.
	panel.mouse_filter = MOUSE_FILTER_PASS
	panel.custom_minimum_size = Vector2(276, 282)
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", STYLE.surface(selected))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var image := TextureRect.new()
	image.texture = ForestArenaResources.load_texture("fa.ui.menu.v07.character." + String(item.id) if item.kind == "character" else _accessory_icon(item.id))
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size.y = 94
	image.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_child(image)
	_label(item.name, column, 23)
	_label(_owned_label(item.id), column, 17, STYLE.GOLD)
	_label(item.description, column, 17, STYLE.MUTED)
	if behavior == "shop":
		var button := _button("보유 중" if app.store.owns(item.id) else "0원 · 무료 구매", "shop_detail", {}, column, false, not app.store.owns(item.id))
		button.set_meta("qa_id", "purchase/" + String(item.id))
		button.set_meta("menu_qa_id", "menu/shop/detail/" + String(item.id))
		button.pressed.connect(func() -> void: _shop_detail(item))
	elif behavior == "accessory":
		var button := _button("✓ 선택" if selected else "살펴보기", "update", {"selected_id": item.id}, column, selected)
		button.set_meta("qa_id", "menu/accessory_collection/accessory/" + String(item.id))
	else:
		var button := _button("기록 읽기", "codex_detail", {}, column)
		button.set_meta("qa_id", "menu/collection/read/" + String(item.id))
		button.pressed.connect(func() -> void: _codex_detail(item))

func _presets() -> void:
	if state.get("local_load_error", false):
		var body := _panel_column(main, Rect2(192, 72, 768, 320))
		_label("편성을 불러오지 못했습니다", body, 30, STYLE.GOLD)
		_label("메뉴 저장을 다시 읽은 뒤 편성을 변경하거나 적용할 수 있습니다.", body, 22, STYLE.MUTED)
		_label("위 메뉴 재시도로 다시 확인하세요.", body, 20)
		return
	var top := HBoxContainer.new()
	main.add_child(top)
	_place(top, Rect2(0, 0, 1152, 72))
	for index: int in 4:
		var button := _button("프리셋 %d%s" % [index + 1, " ✓" if index == app.menu_store.selected_slot else ""], "preset_slot", {"index": index}, top, index == preset_index)
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.set_meta("qa_id", "menu/preset/slot/%d" % index)
	var character: String = String(preset.get("character", ""))
	if app.catalog.contains(character, "character"): _texture("fa.ui.menu.v07.character." + character, main, Rect2(25, 84, 430, 372))
	else: _label("빈 편성\n캐릭터를 골라 주세요", main, 28, STYLE.MUTED, Rect2(60, 200, 350, 130))
	var right := _panel_column(main, Rect2(494, 84, 658, 372))
	_label("%02d  숲으로 향하는 동료" % (preset_index + 1), right, 29, STYLE.GOLD)
	_label("캐릭터 · " + _product_name(character), right, 23)
	var char_button := _button("캐릭터 바꾸기", "preset_edit", {"id": "character_collection"}, right)
	char_button.set_meta("qa_id", "menu/preset/edit/character")
	_label("기본 전투 스타일 · 추가 직업 준비 중", right, 18, STYLE.MUTED)
	_label("장신구 · " + _product_name(String(preset.get("accessory", "")), "장착 없음"), right, 23)
	var acc_button := _button("장신구 바꾸기", "preset_edit", {"id": "accessory_collection"}, right)
	acc_button.set_meta("qa_id", "menu/preset/edit/accessory")
	var remove := _button("장신구 해제", "preset_clear_accessory", {}, right)
	remove.set_meta("qa_id", "menu/preset/clear/accessory")
	_footer_button("편성 저장", "preset_save", {})
	_footer_button("이 편성으로 준비", "preset_apply", {}, true)

func _shop() -> void:
	var left := _scroll(main, Rect2(0, 0, 202, 456), "category_scroll")
	for entry: Array in [["추천", "전체"], ["캐릭터", "character"], ["장신구", "accessory"]]:
		var button := _button(entry[0], "update", {"category": entry[1], "scroll": 0}, left, state.category == entry[1])
		button.set_meta("qa_id", "menu/shop/category/" + String(entry[1]))
	_label("먼저 연습하고\n내게 맞는 동료를\n선택하세요.", left, 20, STYLE.MUTED)
	var rows := _scroll(main, Rect2(226, 0, 926, 456))
	if state.category == "전체":
		_label("새로운 전투의 가능성", rows, 28, STYLE.GOLD)
		var hero := PanelContainer.new()
		hero.mouse_filter = MOUSE_FILTER_PASS
		rows.add_child(hero)
		var row := HBoxContainer.new()
		hero.add_child(row)
		var art := TextureRect.new()
		art.mouse_filter = MOUSE_FILTER_IGNORE
		art.texture = ForestArenaResources.load_texture("fa.ui.menu.v07.character.ja-hyun")
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(172, 180)
		row.add_child(art)
		var message := VBoxContainer.new()
		message.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(message)
		_label("함께할 동료, 새로운 방식", message, 25)
		_label("캐릭터와 장신구를 살펴보고 연습장에서 경험하세요.", message, 19, STYLE.MUTED)
		_button("캐릭터 살펴보기", "open", {"id": "character_collection"}, message).set_meta("qa_id", "menu/shop/character_collection")
	var grid := GridContainer.new()
	grid.columns = 3
	rows.add_child(grid)
	for item: Dictionary in app.catalog.playable_products():
		if state.category != "전체" and item.kind != state.category: continue
		_card(item, grid)

func _shop_detail(item: Dictionary) -> void:
	var owned: bool = app.store.owns(item.id)
	confirm(String(item.name), "%s\n\n%s" % [item.description, "이미 보유한 상품입니다." if owned else "가격 0원 · 기존 무료 구매입니다. 보유 목록에 추가할까요?"], "닫기" if owned else "0원 · 구매 확인", func() -> void:
		if not owned: action.emit("purchase", {"id": item.id}))
	var button: Button = modal.find_child("ModalConfirm", true, false) as Button
	button.set_meta("qa_id", "menu/shop/purchase_confirm/" + String(item.id))

func _collection() -> void:
	var top := VBoxContainer.new()
	main.add_child(top)
	_place(top, Rect2(0, 0, 1152, 72))
	_tabs([["캐릭터", "character"], ["장신구", "accessory"]], "category", top, String(state.category) if state.category != "전체" else "character")
	var owned_row := _tabs(["전체", "보유", "미보유"], "filter", top, String(state.filter))
	owned_row.custom_minimum_size.y = 72
	var rows := _scroll(main, Rect2(0, 168, 1152, 288))
	var grid := GridContainer.new()
	grid.columns = 4
	rows.add_child(grid)
	var kind: String = "character" if state.category == "전체" else String(state.category)
	var count := 0
	for item: Dictionary in app.catalog.products:
		if item.kind != kind: continue
		if state.filter == "보유" and not app.store.owns(item.id): continue
		if state.filter == "미보유" and app.store.owns(item.id): continue
		count += 1
		_card(item, grid, false, "collection")
	if count == 0: _label("조건에 맞는 기록이 없습니다.\n전체 필터에서 기록을 살펴보세요.", rows, 24, STYLE.MUTED)

func _codex_detail(item: Dictionary) -> void:
	var body: String = String(item.description)
	if item.kind == "character":
		var character: CharacterData = app.catalog.combat.character_by_id(StringName(item.id))
		body += "\n\n" + character.background_setting + "\n\n" + _passive_text(character.passive_description)
	confirm(String(item.name), body + "\n\n도감은 읽기 전용입니다.", "확인", func() -> void: pass)

func _service_button(text: String, action_id: String, payload: Dictionary, parent: Node, qa_action := "", next_state: Dictionary = {}, primary := false) -> Button:
	var envelope := {"action": action_id, "payload": payload}
	if not next_state.is_empty(): envelope.state = next_state
	var button := _button(text, "service", envelope, parent, false, primary)
	button.set_meta("qa_id", "menu/%s/%s" % [state.id, qa_action if not qa_action.is_empty() else action_id])
	return button

func _service_status(parent: Node, allow_connect := true) -> void:
	var status: String = String(service_snapshot.get("status", "unlinked"))
	var message: String = String(service_snapshot.get("error", ""))
	match status:
		"local": _label("기기에 저장한 기록 · 서버에 연결하면 함께 확인할 수 있습니다.", parent, 18, STYLE.MUTED)
		"loading": _label("서버 기록을 확인하고 있습니다…", parent, 20, STYLE.GOLD)
		"error": _label(message if not message.is_empty() else "서버 조회에 실패했습니다. 다시 시도하세요.", parent, 20, STYLE.DANGER)
		"idle": _label("서버 기록을 조회하려면 새로고침하세요.", parent, 20, STYLE.MUTED)
		"unlinked": _label("계정을 연결한 뒤 사용할 수 있습니다.
기기·DB·LAN 프로필과 현재 편성을 함께 유지합니다.", parent, 22, STYLE.MUTED)
	if not message.is_empty() and status != "error": _label(message, parent, 18, STYLE.DANGER)
	if status in ["local", "unlinked"] and allow_connect:
		_button("프로필에서 계정 연결", "open", {"id": "profile"}, parent).set_meta("qa_id", "menu/%s/connect_profile" % state.id)
	var data: Dictionary = service_snapshot.get("data", {})
	if data.has("fetched_at") and status != "ready": _label("마지막 조회 · " + _display_time(data.fetched_at), parent, 16, STYLE.MUTED)
	if data.get("stale_period", false): _label("기간이 바뀌었습니다. 현재 기간의 서버 기록은 다시 연결해 확인하세요.", parent, 18, STYLE.GOLD)
	if int(service_snapshot.get("pending", 0)) > 0: _label("기기 기록 %d개 전송 대기" % int(service_snapshot.pending), parent, 18, STYLE.GOLD)

func _refresh_button() -> void:
	_service_button("새로고침", "refresh", {"menu_id": state.id}, footer, "refresh")

func _missions() -> void:
	var category: String = String(state.get("category", "daily"))
	category = String({"전체": "daily", "일일": "daily", "주간": "weekly", "업적": "achievements"}.get(category, category))
	var tabs := VBoxContainer.new()
	main.add_child(tabs)
	_place(tabs, Rect2(0, 0, 1152, 72))
	_tabs([["일일", "daily"], ["주간", "weekly"], ["누적", "achievements"]], "category", tabs, category)
	var rows := _panel_column(main, Rect2(0, 84, 748, 372))
	_service_status(rows, false)
	var count := 0
	for mission: Dictionary in service_snapshot.get("data", {}).get("missions", []):
		if mission.get("category", "") != category: continue
		count += 1
		var card := PanelContainer.new()
		rows.add_child(card)
		card.add_theme_stylebox_override("panel", STYLE.surface(bool(mission.get("completed", false))))
		var column := VBoxContainer.new()
		card.add_child(column)
		_label(String(mission.title) + (" ✓ 완료" if mission.get("completed", false) else ""), column, 22, STYLE.GOLD if mission.get("completed", false) else STYLE.TEXT)
		_label("%d / %d · 보상 없음" % [int(mission.current), int(mission.target)], column, 20, STYLE.MUTED)
		var bar := ProgressBar.new()
		bar.max_value = maxi(1, int(mission.target))
		bar.value = int(mission.current)
		bar.show_percentage = false
		bar.custom_minimum_size.y = 14
		column.add_child(bar)
		var detail := _button("기록 보기", "mission_detail", {}, column)
		detail.set_meta("qa_id", "menu/mission/mission/" + String(mission.id))
		detail.pressed.connect(func() -> void: confirm(String(mission.title), "%d / %d\n%s\n연습·Story·포기는 제외합니다. 보상은 없습니다." % [int(mission.current), int(mission.target), "완료했습니다." if mission.get("completed", false) else "완료한 경기 기록으로 진행됩니다."], "확인", func() -> void: pass))
	if count == 0 and service_snapshot.get("status") not in ["loading", "error"]: _label("이 분류에 표시할 미션 기록이 없습니다.", rows, 22, STYLE.MUTED)
	var side := _panel_column(main, Rect2(772, 84, 380, 372))
	_label("나의 경기 기록", side, 26, STYLE.GOLD)
	_label("일일은 한국 시간 자정, 주간은 월요일에 새로 시작합니다.", side, 20)
	_label("오프라인 AI·Solo·Team 완료 기록과 정상 종료한 LAN 대전 기록으로 진행합니다.", side, 19, STYLE.MUTED)
	_label("연습·Story·포기는 포함하지 않습니다. 미션 보상은 없습니다.", side, 19, STYLE.MUTED)
	if service_snapshot.get("status") in ["local", "unlinked"]: _button("계정 연결", "open", {"id": "profile"}, side).set_meta("qa_id", "menu/mission/connect_profile")
	_refresh_button()

func _social() -> void:
	var category: String = String(state.get("category", "friends"))
	category = String({"전체": "friends", "친구": "friends", "최근 플레이어": "recent", "찾기": "search"}.get(category, category))
	var top := VBoxContainer.new()
	main.add_child(top)
	_place(top, Rect2(0, 0, 1152, 72))
	_tabs([["친구", "friends"], ["받은 요청", "incoming"], ["보낸 요청", "outgoing"], ["찾기", "search"], ["최근 플레이어", "recent"], ["초대", "invites"]], "category", top, category)
	var body := _panel_column(main, Rect2(0, 84, 1152, 372))
	_service_status(body)
	if category == "search":
		_label("정확한 닉네임으로 검색합니다.", body, 20)
		var row := HBoxContainer.new()
		body.add_child(row)
		_social_search = LineEdit.new()
		_social_search.placeholder_text = "닉네임"
		_social_search.text = String(state.get("search", ""))
		_social_search.max_length = 12
		_social_search.custom_minimum_size.y = 72 / maxf(_fit_scale, 0.5)
		_social_search.size_flags_horizontal = SIZE_EXPAND_FILL
		_social_search.set_meta("qa_id", "menu/social/search_input")
		row.add_child(_social_search)
		_social_search.text_changed.connect(func(value: String) -> void: state.search = value)
		var search := _button("검색", "social_search", {}, row)
		search.set_meta("qa_id", "menu/social/search_submit")
		search.pressed.connect(func() -> void: action.emit("service", {"action": "search", "payload": {"nickname": _social_search.text}, "state": {"search": _social_search.text}}))
	var data: Dictionary = service_snapshot.get("data", {})
	if data.has(category):
		var items: Array = data[category]
		if items.is_empty(): _label({"friends": "등록한 친구가 없습니다.", "incoming": "받은 친구 요청이 없습니다.", "outgoing": "보낸 친구 요청이 없습니다.", "recent": "아직 최근 LAN 상대가 없습니다.", "search": "검색 결과가 없습니다.", "invites": "받은 대전 초대가 없습니다."}.get(category, "표시할 항목이 없습니다."), body, 24, STYLE.MUTED)
		for item: Dictionary in items: _social_row(item, category, body)
	if app.get("menu_service") != null and not app.menu_service.identity.get("operations", []).is_empty(): _service_button("이전 요청 다시 확인", "retry_social", {}, footer, "retry_social")
	_refresh_button()

func _social_row(item: Dictionary, category: String, parent: Node) -> void:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	_label(String(item.get("nickname", "")), column, 25)
	if category == "friends": _label("● 접속 중" if item.get("online", false) else "오프라인 · " + _display_time(item.get("last_seen", "")), column, 18, STYLE.MINT if item.get("online", false) else STYLE.MUTED)
	if category == "recent": _label("최근 대전 · " + _display_time(item.get("ended_at", item.get("last_played", ""))), column, 18, STYLE.MUTED)
	if category == "invites": _label("초대 만료 · " + _display_time(item.get("expires_at", "")), column, 18, STYLE.GOLD)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	var id: String = String(item.get("player_id", ""))
	match category:
		"friends":
			var available: bool = not String(app.lan_current_invite).is_empty() and app.lan_client.active and not app.lan_client.running and app.lan_client.local_slot == 1
			var invite := _service_button("현재 LAN 방으로 초대", "invite", {"player_id": id, "invite_code": app.lan_current_invite}, actions, "invite/" + id)
			invite.disabled = not available
			if not available: invite.tooltip_text = "LAN 대기방을 만든 뒤 친구 초대로 들어오세요."
			var remove := _button("친구 삭제", "confirm_remove", {}, actions)
			remove.set_meta("qa_id", "menu/social/remove/" + id)
			remove.pressed.connect(func() -> void: confirm("친구를 삭제할까요?", String(item.get("nickname", "")), "삭제", func() -> void: action.emit("service", {"action": "remove", "payload": {"player_id": id}})))
		"incoming":
			_service_button("수락", "accept", {"request_id": item.request_id}, actions, "accept/" + String(item.request_id), {}, true)
			_service_button("거절", "reject", {"request_id": item.request_id}, actions, "reject/" + String(item.request_id))
		"outgoing": _service_button("요청 취소", "cancel", {"request_id": item.request_id}, actions, "cancel/" + String(item.request_id))
		"search", "recent": _service_button("친구 요청", "request", {"player_id": id}, actions, "request/" + id)
		"invites":
			var accept := _service_button("대전 참가", "accept_invite", {"invite_id": item.invite_id}, actions, "accept_invite/" + String(item.invite_id), {}, true)
			accept.disabled = app.lan_client.active or is_instance_valid(app.match_scene)
			if accept.disabled: accept.tooltip_text = "현재 대전을 끝내거나 LAN 방을 닫은 뒤 참가하세요."
			_service_button("거절", "reject_invite", {"invite_id": item.invite_id}, actions, "reject_invite/" + String(item.invite_id))

func _rank() -> void:
	var scope: String = String(state.get("scope", "all"))
	var top := HBoxContainer.new()
	main.add_child(top)
	_place(top, Rect2(0, 0, 1152, 72))
	for entry: Array in [["전체", "all"], ["이번 달", "month"], ["친구", "friends"]]:
		var button := _service_button(entry[0] + (" ✓" if scope == entry[1] else ""), "rank_scope", {"scope": entry[1], "page": 0}, top, "scope/" + entry[1], {"scope": entry[1], "rank_page": 0})
		button.size_flags_horizontal = SIZE_EXPAND_FILL
	var rows := _panel_column(main, Rect2(0, 84, 1152, 372))
	_service_status(rows)
	var data: Dictionary = service_snapshot.get("data", {})
	if data.has("entries"):
		if data.entries.is_empty(): _label("집계된 LAN 대전 기록이 없습니다.\n0경기는 순위에 표시하지 않습니다.", rows, 25, STYLE.MUTED)
		else:
			_label("순위 · 닉네임 · 승 / 패 / 무 · 승률", rows, 18, STYLE.MUTED)
			for entry: Dictionary in data.entries: _rank_row(entry, rows)
		_label("내 순위", rows, 24, STYLE.GOLD)
		if data.get("own") is Dictionary: _rank_row(data.own, rows)
		else: _label("아직 순위가 없습니다. 정상 종료한 LAN 경기를 완료하세요.", rows, 20, STYLE.MUTED)
		var page: int = int(data.get("page", 0))
		if page > 0: _service_button("이전", "rank_scope", {"scope": scope, "page": page - 1}, footer, "page_previous", {"scope": scope, "rank_page": page - 1})
		if data.get("has_more", false): _service_button("다음", "rank_scope", {"scope": scope, "page": page + 1}, footer, "page_next", {"scope": scope, "rank_page": page + 1})
	_refresh_button()

func _rank_row(entry: Dictionary, parent: Node) -> void:
	_label("%d위 · %s · %d승 %d패 %d무 · %.1f%%" % [int(entry.rank), String(entry.nickname), int(entry.wins), int(entry.losses), int(entry.draws), float(entry.win_rate) * 100.0], parent, 23)

func _display_time(value: Variant) -> String:
	if not value is String or value.is_empty(): return "기록 없음"
	return String(value).replace("T", " ").trim_suffix("Z") + " UTC"

func _profile() -> void:
	var selected: String = String(app.store.data.selected_character)
	if app.catalog.contains(selected, "character"): _texture("fa.ui.menu.v07.character." + selected, main, Rect2(32, 0, 400, 456))
	var right := _panel_column(main, Rect2(486, 0, 666, 456))
	_label(String(app.store.data.nickname), right, 32)
	_label("현재 캐릭터 · " + _product_name(selected), right, 23, STYLE.GOLD)
	_label("장신구 · " + _product_name(String(app.store.data.selected_accessory), "장착 없음"), right, 20)
	_label("보유 캐릭터 %d / %d · 장신구 %d / %d" % [app.store.data.characters.size(), app.catalog.combat.characters.size(), app.store.data.accessories.size(), app.catalog.combat.accessories.size()], right, 20, STYLE.MUTED)
	_label("닉네임 · 한글·영문·숫자·밑줄 2~12자" if not service_snapshot.get("binding", {}).is_empty() else "닉네임 · 공백 제외 1~12자", right, 20)
	_nickname = LineEdit.new()
	_nickname.name = "NicknameInput"
	_nickname.text = String(state.get("nickname_draft", app.store.data.nickname))
	_nickname.max_length = 12
	_nickname.custom_minimum_size.y = 72 / maxf(_fit_scale, 0.5)
	_nickname.set_meta("qa_id", "menu/profile/nickname_input")
	right.add_child(_nickname)
	_nickname.text_changed.connect(func(value: String) -> void: state.nickname_draft = value)
	_nickname.text_submitted.connect(func(value: String) -> void: action.emit("nickname", {"value": value}))
	var save := _button("닉네임 저장", "nickname_save", {}, right)
	save.set_meta("qa_id", "menu/profile/nickname_save")
	save.pressed.connect(func() -> void: action.emit("nickname", {"value": _nickname.text}))
	_label("연결한 닉네임은 프로필과 LAN에 함께 적용합니다." if not service_snapshot.get("binding", {}).is_empty() else "오프라인 표시용 닉네임입니다. 계정 연결 시 최종 닉네임을 정하세요.", right, 18, STYLE.MUTED)
	_identity_panel(right)
	_profile_records(right)

func _identity_panel(parent: Node) -> void:
	_label("기기·DB·LAN 계정 연결", parent, 25, STYLE.GOLD)
	var binding: Dictionary = service_snapshot.get("binding", {})
	if not binding.is_empty():
		_label("연결한 닉네임 · " + String(binding.get("nickname", "")), parent, 20, STYLE.MINT)
		_label("같은 서버의 프로필을 함께 사용합니다.", parent, 18, STYLE.MUTED)
	else: _label("DB 계정을 먼저 사용하고, 없으면 LAN 게스트를 연결합니다. 둘 다 없으면 새 게스트를 만듭니다. 보유는 합치고 현재 편성·설정은 유지합니다.", parent, 19, STYLE.MUTED)
	_identity_url = LineEdit.new()
	_identity_url.text = String(state.get("identity_url_draft", binding.get("api_url", app.db_address)))
	_identity_url.placeholder_text = "서버 주소"
	_identity_url.custom_minimum_size.y = 72 / maxf(_fit_scale, 0.5)
	_identity_url.set_meta("qa_id", "menu/profile/identity_url")
	parent.add_child(_identity_url)
	_identity_url.text_changed.connect(func(value: String) -> void: state.identity_url_draft = value)
	var unify := _button("프로필 통합 다시 확인" if service_snapshot.get("intent", false) else "이 닉네임으로 계정 연결", "identity_confirm", {}, parent)
	unify.set_meta("qa_id", "menu/profile/identity_connect")
	unify.pressed.connect(func() -> void:
		var nickname := _nickname.text.strip_edges()
		var url := _identity_url.text.strip_edges()
		confirm("프로필을 연결할까요?", "최종 닉네임: %s\n보유한 캐릭터·장신구는 합치고 현재 편성·설정·기기 프리셋·조작은 유지합니다. 원본 계정과 기록은 보존합니다." % nickname, "연결", func() -> void: action.emit("service", {"action": "retry_identity" if service_snapshot.get("intent", false) else "unify", "payload": {"nickname": nickname, "api_url": url}})))
	_service_status(parent, false)

func _profile_records(parent: Node) -> void:
	_label("모드별 대전 기록", parent, 26, STYLE.GOLD)
	var data: Dictionary = service_snapshot.get("data", {})
	var stats: Dictionary = data.get("stats", {})
	if stats.has("offline"): _stats_line("오프라인 전체", stats.offline, parent)
	for pair: Array in [["AI", "ai"], ["Solo", "solo"], ["Team", "team"]]:
		if stats.get("modes", {}).has(pair[1]): _stats_line(pair[0], stats.modes[pair[1]], parent)
	if service_snapshot.get("status") in ["ready", "loading", "error"] and not service_snapshot.get("local_only", false) and stats.has("lan"): _stats_line("LAN", stats.lan, parent)
	else: _label("LAN 전적은 계정 연결 후 서버에서 조회합니다.", parent, 18, STYLE.MUTED)
	_label("최근 완료 기록", parent, 24)
	for entry: Dictionary in data.get("history", []):
		var mode: String = String(entry.get("mode", ""))
		var outcome: String = String({"win": "승리", "loss": "패배", "draw": "무승부"}.get(String(entry.get("outcome", "")), entry.get("outcome", "")))
		_label("%s · %s · %s\n%s" % ["LAN" if entry.get("source") == "lan" else "오프라인 " + mode.to_upper(), outcome, _product_name(String(entry.get("character_id", ""))), _display_time(entry.get("ended_at", ""))], parent, 18, STYLE.MUTED)
	_refresh_button()

func _stats_line(title: String, stats: Dictionary, parent: Node) -> void:
	_label("%s · %d경기 / %d승 %d패 %d무" % [title, int(stats.get("played", 0)), int(stats.get("wins", 0)), int(stats.get("losses", 0)), int(stats.get("draws", 0))], parent, 20)

func _settings() -> void:
	var left := _scroll(main, Rect2(0, 0, 246, 456), "category_scroll")
	left.add_theme_constant_override("separation", 4)
	var category: String = "controls" if state.id == "controls" else String(state.category)
	for entry: Array in [["소리", "sound"], ["화면 효과", "effects"], ["접근성", "accessibility"], ["미니맵", "minimap"], ["조작", "controls"], ["디버깅", "debug"]]:
		var node: Button
		if entry[1] == "controls": node = _button(entry[0], "open", {"id": "controls"}, left, category == entry[1])
		elif state.id == "controls": node = _button(entry[0], "open", {"id": "settings", "params": {"category": entry[1]}}, left)
		else: node = _button(entry[0], "category", {"value": entry[1]}, left, category == entry[1])
		node.set_meta("qa_id", "menu/%s/category/%s" % [state.id, entry[1]])
	var body := _panel_column(main, Rect2(270, 0, 882, 456))
	match category:
		"sound":
			_label("소리 설정", body, 28)
			_slider("음악 음량", "music", float(draft.music), 0, 1, 0.05, body, 100, "%")
			_slider("효과음 음량", "effects", float(draft.effects), 0, 1, 0.05, body, 100, "%")
			_toggle("전체 음소거", "muted", bool(draft.muted), body)
			_label("소리 설정은 이 기기에 저장됩니다.", body, 18, STYLE.MUTED)
		"effects":
			_label("화면 효과", body, 28)
			_toggle("피격 번쩍임 줄이기", "reduce_visual_effects", bool(draft.reduce_visual_effects), body)
			_label("피격 상태와 위험 안내는 글자와 아이콘으로도 표시됩니다.", body, 22, STYLE.MUTED)
		"accessibility":
			_label("접근성", body, 28)
			_choices("텍스트 크기", "text_scale", [["기본", 1.0], ["크게", 1.15], ["매우 크게", 1.3]], draft.text_scale, body)
			_toggle("진동 피드백", "haptics_enabled", bool(draft.haptics_enabled), body)
			_label("소리와 진동 없이도 상태와 결과를 확인할 수 있습니다.\n큰 글자는 스크롤로 모두 읽을 수 있습니다.", body, 22, STYLE.MUTED)
		"minimap":
			_label("미니맵", body, 28)
			_minimap_preview(body)
			_slider("미니맵 투명도", "transparency", float(draft.transparency), 0, 90, 1, body, 1, "%")
			_choices("캐릭터 표시", "marker_style", [["얼굴", "face"], ["점", "dot"]], draft.marker_style, body)
			_toggle("미니맵 이름 표시", "show_names", bool(draft.show_names), body)
		"debug":
			_label("디버깅 · 임시 기능", body, 28)
			_toggle("타격·피격 범위 표시", "show_combat_ranges", bool(draft.show_combat_ranges), body)
			_label("빨강: 타격 범위 · 파랑: 피격 범위\n현재 실행 중에만 유지하며, 앱을 다시 실행하면 꺼집니다.", body, 22, STYLE.MUTED)
		"controls":
			_label("조작 설정", body, 28)
			_controls_sample(body)
			_choices("조이스틱", "joystick_mode", [["고정", "fixed"], ["플로팅", "floating"]], draft.joystick_mode, body)
			_slider("버튼 크기", "button_scale", float(draft.button_scale), 1.0, 1.2, 0.05, body, 100, "%")
			_slider("버튼 투명도", "button_transparency", float(draft.button_transparency), 0, 50, 5, body, 1, "%")
			_label("플로팅은 왼쪽 예약 영역의 첫 터치에서 시작합니다.\n조작 설정은 이 기기에 저장됩니다.", body, 18, STYLE.MUTED)
	_footer_button("기본값", "settings_reset", {})
	_footer_button("취소", "settings_cancel", {})
	_footer_button("적용", "settings_apply", {}, true)

func _slider(title: String, key: String, value: float, minimum: float, maximum: float, step: float, parent: Node, multiplier := 1.0, suffix := "") -> void:
	var label := _label("%s · %d%s" % [title, roundi(value * multiplier), suffix], parent, 22)
	_draft_labels[key] = [label, title, multiplier, suffix]
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.custom_minimum_size.y = 72 / maxf(_fit_scale, 0.5)
	slider.set_meta("qa_id", "menu/%s/draft/%s" % [state.id, key])
	parent.add_child(slider)
	slider.value_changed.connect(func(next: float) -> void: action.emit("draft", {key: int(next) if key in ["transparency", "button_transparency"] else next}))
	slider.drag_ended.connect(func(changed: bool) -> void:
		if changed: ForestArenaAudio.play_event(&"ui_select", {}))

func _toggle(title: String, key: String, value: bool, parent: Node) -> void:
	var button := CheckButton.new()
	button.text = title
	button.button_pressed = value
	button.custom_minimum_size.y = 72 / maxf(_fit_scale, 0.5)
	button.set_meta("qa_id", "menu/%s/draft/%s" % [state.id, key])
	parent.add_child(button)
	button.toggled.connect(func(next: bool) -> void:
		ForestArenaAudio.play_event(&"ui_select", {})
		action.emit("draft", {key: next}))

func _choices(title: String, key: String, options: Array, value: Variant, parent: Node) -> void:
	_label(title, parent, 22)
	var row := HBoxContainer.new()
	parent.add_child(row)
	for option: Array in options:
		var button := _button(String(option[0]), "draft", {key: option[1]}, row, value == option[1])
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.set_meta("qa_id", "menu/%s/draft/%s/%s" % [state.id, key, str(option[1])])
		button.pressed.connect(func() -> void:
			for child: Node in row.get_children():
				(child as Button).add_theme_stylebox_override("normal", STYLE.surface(child == button))
				(child as Button).text = (child as Button).text.trim_suffix(" ✓") + (" ✓" if child == button else ""))

func _minimap_preview(parent: Node) -> void:
	var map := BattleMinimap.new()
	map.name = "MinimapPreview"
	map.embedded = true
	map.custom_minimum_size = Vector2(360, 170)
	parent.add_child(map)
	map.set_process(false)
	preview = map
	_initialize_minimap.call_deferred(map)

func _initialize_minimap(map: BattleMinimap) -> void:
	if not is_instance_valid(map) or not map.is_inside_tree(): return
	map.configure(load("res://assets/combat/stages/forest_ledge_stage.tres") as StageData, {&"self": {"nickname": app.store.data.nickname, "character_id": app.store.data.selected_character if app.store.data.first_granted else "ja-hyun", "team_id": "alpha"}, &"other": {"nickname": "AI 1", "character_id": "nabi", "team_id": "beta"}}, &"self", true)
	map.apply_settings(draft, text_scale)
	map.update_snapshot({"fighters": [{"id": "self", "stocks": 3, "position": Vector2(100, 420)}, {"id": "other", "stocks": 3, "position": Vector2(1100, 520)}]})

func _controls_sample(parent: Node) -> void:
	var sample := Control.new()
	sample.name = "ControlsPreview"
	sample.custom_minimum_size = Vector2(780, 180)
	sample.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(sample)
	_controls_preview = sample
	_draw_controls(draft)

func _draw_controls(settings: Dictionary) -> void:
	if not is_instance_valid(_controls_preview): return
	for child: Node in _controls_preview.get_children():
		_controls_preview.remove_child(child)
		child.queue_free()
	var floating: bool = settings.joystick_mode == "floating"
	_label("플로팅 · 첫 터치 위치" if floating else "고정 · 왼쪽 조이스틱", _controls_preview, 17, STYLE.MUTED, Rect2(0, 0, 380, 30))
	var joystick := Panel.new()
	var circle := STYLE.surface(true)
	circle.set_corner_radius_all(60)
	joystick.add_theme_stylebox_override("panel", circle)
	_controls_preview.add_child(joystick)
	_place(joystick, Rect2(88 if floating else 30, 46, 110, 110))
	_label("＋", joystick, 38, STYLE.GOLD, Rect2(33, 20, 50, 62))
	for index: int in 4:
		var button := Panel.new()
		button.add_theme_stylebox_override("panel", STYLE.surface(true))
		button.modulate.a = 1.0 - float(settings.button_transparency) / 100.0
		_controls_preview.add_child(button)
		var side: float = 64 * float(settings.button_scale)
		_place(button, Rect2(330 + index * 104, 60 - index * 8, side, side))
		_label(["점프", "약", "강", "특수"][index], button, 20, STYLE.GOLD, Rect2(12, 17, side - 24, 44))

func update_preview(settings: Dictionary) -> void:
	draft = settings
	for key: String in _draft_labels:
		var row: Array = _draft_labels[key]
		(row[0] as Label).text = "%s · %d%s" % [row[1], roundi(float(settings.get(key, 0)) * float(row[2])), row[3]]
	if is_instance_valid(preview): preview.apply_settings(settings, text_scale)
	_draw_controls(settings)

func _all_menu() -> void:
	if is_instance_valid(modal) or app.menu_router.busy or app.storage_busy: return
	var column := _modal_shell("전체 메뉴", "원하는 메뉴를 선택하세요.")
	var grid := GridContainer.new()
	grid.columns = 3
	column.add_child(grid)
	for id: String in SCREENS:
		var button := _button(String(SCREENS[id][1]), "all_menu_entry", {}, grid, id == state.id)
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.set_meta("qa_id", "menu/%s/open/%s" % [state.id, id])
		button.pressed.connect(func() -> void:
			close_modal()
			action.emit("open", {"id": id}))
	var cancel := _button("닫기", "modal_cancel", {}, column)
	cancel.pressed.connect(close_modal)

func _modal_shell(title: String, body: String) -> VBoxContainer:
	close_modal()
	modal = Control.new()
	modal.name = "PremiumMenuModal"
	modal.set_meta("qa_id", "menu/%s/modal" % state.id)
	modal.mouse_filter = MOUSE_FILTER_STOP
	add_child(modal)
	modal.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(STYLE.BG, 0.88)
	modal.add_child(shade)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	modal.add_child(panel)
	panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	panel.offset_left = -440
	panel.offset_right = 440
	panel.offset_top = -290
	panel.offset_bottom = 290
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(column)
	_label(title, column, 30, STYLE.GOLD)
	_label(body, column, 21)
	return column

func confirm(title: String, body: String, confirm_text: String, callback: Callable) -> void:
	var column := _modal_shell(title, body)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	var cancel := _button("취소", "modal_cancel", {}, buttons)
	cancel.size_flags_horizontal = SIZE_EXPAND_FILL
	cancel.pressed.connect(close_modal)
	var accept := _button(confirm_text, "modal_confirm", {}, buttons, false, true)
	accept.name = "ModalConfirm"
	accept.size_flags_horizontal = SIZE_EXPAND_FILL
	var consumed := [false]
	accept.pressed.connect(func() -> void:
		if consumed[0]: return
		consumed[0] = true
		accept.disabled = true
		close_modal()
		callback.call())

func close_modal() -> bool:
	if not is_instance_valid(modal): return false
	remove_child(modal)
	modal.queue_free()
	modal = null
	return true
