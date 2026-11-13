class_name PremiumMenuView
extends Control

signal action(action_id: String, payload: Dictionary)
const STYLE = preload("res://scripts/premium_menu/premium_menu_theme.gd")
const LIFE = preload("res://scripts/premium_menu/menu09_life.gd")
const SCREENS := {
	"character_collection": ["SCR_04_CharacterCollection", "캐릭터", "동료의 방 / CHARACTER", "character-room"],
	"character_detail": ["SCR_05_CharacterDetail", "캐릭터 상세", "동료의 방 / CHARACTER", "character-room"],
	"accessory_collection": ["SCR_06_AccessoryCollection", "신기", "숲속 공방 / ACCESSORY", "accessory-workshop"],
	"accessory_detail": ["SCR_07_AccessoryDetail", "신기 상세", "숲속 공방 / ACCESSORY", "accessory-workshop"],
	"preset": ["SCR_08_Preset", "전투 편성", "나의 편성 / PRESET", "character-room"],
	"shop": ["SCR_19_Shop", "상점", "숲의 교역소 / SHOP", "shop-market"],
	"shop_detail": ["SCR_19_Shop", "상점 · 상세", "숲의 교역소 / SHOP", "shop-market"],
	"collection": ["SCR_20_Collection", "도감", "숲의 기록실 / COLLECTION", "archive"],
	"collection_detail": ["SCR_20_Collection", "도감 · 상세", "숲의 기록실 / COLLECTION", "archive"],
	"mission": ["SCR_21_Mission", "미션", "숲의 기록실 / MISSION", "archive"],
	"social": ["SCR_22_Social", "친구", "동료의 쉼터 / SOCIAL", "character-room"],
	"mail": ["EXT_MENU09_Mailbox", "우편함", "우편함 / MAIL", "character-room"],
	"notices": ["EXT_MENU09_Notices", "공지사항", "공지사항 / NOTICES", "character-room"],
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
var _media_player: VideoStreamPlayer
var _media_toggle: Button
var _media_status: Label

const MEDIA_TECHNIQUES := [
	["약공격", "light"], ["강공격", "heavy"], ["공중 약", "jump-light"],
	["공중 강", "jump-heavy"], ["특수", "special"],
]
const ARTIFACT_DISPLAY_NAMES := {
	"fixture-thorns": "균형 신기",
	"fixture-ultimate-charm": "집중 신기",
	"fixture-phoenix-revive": "활공 신기",
}

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
	LIFE.header_action(self)
	resized.connect(_resize_canvas)
	_resize_canvas.call_deferred()
	match String(state.id):
		"character_collection", "character_detail": _character()
		"accessory_collection", "accessory_detail": _accessories()
		"preset": _presets()
		"shop": _shop()
		"shop_detail", "collection_detail": _product_detail()
		"collection": _collection()
		"mission": LIFE.missions(self)
		"social": LIFE.friends(self)
		"mail": LIFE.mail(self)
		"notices": LIFE.notices(self)
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
	_label(LIFE.screen_title(state, String(SCREENS[state.id][1])), content, 34, STYLE.TEXT, Rect2(184, 65, 750, 47))
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
		"shop": return "상품 구성과 조건은 미정입니다" if state.get("category") in ["stone", "rainbow"] else "현재 판매 가능한 항목은 0원입니다"
		"collection": return "보유 기록과 기존 설명 · 읽기 전용"
		"settings", "controls": return "변경 후 적용을 누르세요"
		"mission": return "실제 완료 기록 · 보상 없음"
		"social": return "친구 · 요청 · 실제 LAN 초대"
		"mail": return "우편 운영은 준비 중입니다"
		"notices": return "공지와 이벤트를 확인합니다"
		"rank": return "정상 종료한 LAN 대전만 순위 반영"
		"profile": return "오프라인과 LAN 기록을 따로 표시합니다"
	return "캐릭터와 신기를 살펴보세요"

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
	return String(ARTIFACT_DISPLAY_NAMES.get(id, item.get("name", fallback)))

func _preview_media(owner: String, clip: String, title: String, parent: VBoxContainer) -> void:
	var key := owner + "." + clip
	var frame := Control.new()
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	frame.custom_minimum_size.y = 172
	parent.add_child(frame)
	var poster := TextureRect.new()
	poster.texture = ForestArenaResources.load_texture("fa.ui.menu09.poster." + key)
	poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	poster.mouse_filter = MOUSE_FILTER_IGNORE
	frame.add_child(poster)
	poster.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var play := _button("▶ 영상 재생", "media_play", {}, frame, false, true)
	play.set_anchors_and_offsets_preset(PRESET_CENTER)
	play.offset_left = -96
	play.offset_right = 96
	play.offset_top = -40
	play.offset_bottom = 40
	play.set_meta("qa_id", "menu/media/play/" + key)
	play.pressed.connect(_open_media.bind(key, title))

func _open_media(key: String, title: String) -> void:
	var stream := ForestArenaResources.load_video("fa.ui.menu09.video." + key)
	var column := _modal_shell(title, "기존 자료로 제작한 소개 영상")
	if stream == null:
		_label("영상 파일을 불러오지 못했습니다.", column, 20, STYLE.MUTED)
	else:
		var frame := AspectRatioContainer.new()
		frame.ratio = 16.0 / 9.0
		frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
		frame.custom_minimum_size.y = 334
		column.add_child(frame)
		_media_player = VideoStreamPlayer.new()
		_media_player.name = "Menu09Video"
		_media_player.set_meta("media_key", key)
		_media_player.expand = true
		_media_player.mouse_filter = MOUSE_FILTER_IGNORE
		_media_player.stream = stream
		frame.add_child(_media_player)
		_media_status = _label("재생 중", column, 18, STYLE.MINT)
	var controls := HBoxContainer.new()
	column.add_child(controls)
	if is_instance_valid(_media_player):
		_media_toggle = _button("일시정지", "media_toggle", {}, controls)
		_media_toggle.size_flags_horizontal = SIZE_EXPAND_FILL
		_media_toggle.set_meta("qa_id", "menu/media/toggle")
		_media_toggle.pressed.connect(_toggle_media)
		_media_player.finished.connect(func() -> void:
			_media_toggle.text = "다시 재생"
			_media_status.text = "재생 완료")
		_media_player.play()
		if not _media_player.is_playing():
			_media_status.text = "영상을 재생하지 못했습니다."
			_media_toggle.text = "다시 시도"
	var close := _button("닫기", "media_close", {}, controls)
	close.size_flags_horizontal = SIZE_EXPAND_FILL
	close.set_meta("qa_id", "menu/media/close")
	close.pressed.connect(close_modal)

func _toggle_media() -> void:
	if not is_instance_valid(_media_player): return
	if not _media_player.is_playing():
		_media_player.paused = false
		_media_player.play()
	else:
		_media_player.paused = not _media_player.paused
	_update_media_status()

func _update_media_status() -> void:
	if not _media_player.is_playing():
		_media_toggle.text = "다시 시도"
		_media_status.text = "영상을 재생하지 못했습니다."
		return
	_media_toggle.text = "이어서 재생" if _media_player.paused else "일시정지"
	_media_status.text = "일시정지" if _media_player.paused else "재생 중"

func _notification(what: int) -> void:
	if what not in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		return
	if is_instance_valid(_media_player) and _media_player.is_playing():
		_media_player.paused = true
		_update_media_status()

func _techniques(owner: String, parent: VBoxContainer) -> void:
	var selected := String(state.get("technique", "light"))
	var title := "약공격"
	for entry: Array in MEDIA_TECHNIQUES:
		if entry[1] == selected: title = entry[0]
	_preview_media(owner, selected, title, parent)
	_tabs(MEDIA_TECHNIQUES.slice(0, 3), "technique", parent, selected)
	_tabs(MEDIA_TECHNIQUES.slice(3), "technique", parent, selected)

func _character_matches(character: CharacterData) -> bool:
	if state.filter == "균형": return &"balanced" in character.tags
	if state.filter == "근접": return not (&"balanced" in character.tags)
	return true

func _character_id() -> String:
	var selected: String = String(state.get("selected_id", app.store.data.selected_character))
	if state.get("browse_only", false) and app.catalog.contains(selected, "character"):
		return selected
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
	var selectable: bool = app.catalog.is_playable_character(StringName(id))
	_label(character.display_name, main, 34, STYLE.TEXT, Rect2(0, 0, 442, 48))
	_label(character.combat_role, main, 20, STYLE.MINT, Rect2(0, 46, 442, 32))
	_texture("fa.ui.menu.v07.character." + id, main, Rect2(0, 76, 450, 278))
	var tabs := VBoxContainer.new()
	main.add_child(tabs)
	_place(tabs, Rect2(462, 0, 140, 288))
	var tab := String(state.get("tab", "기술")) if state.id == "character_detail" else "스탯"
	for entry: Array in [["스탯", "스탯"], ["기술", "기술"], ["스토리", "이야기"]]:
		var button: Button
		if state.id == "character_collection" and entry[1] != "스탯":
			var params := {"selected_id": id, "tab": entry[1], "browse_only": not selectable, "preset_edit": state.get("preset_edit", false)}
			button = _button(entry[0], "open", {"id": "character_detail", "params": params}, tabs)
			if entry[1] == "기술": button.set_meta("qa_id", "menu/character_collection/detail")
		else:
			button = _button(entry[0], "update", {"tab": entry[1], "detail_scroll": 0}, tabs, entry[1] == tab)
			button.set_meta("qa_id", "menu/%s/tab/%s" % [state.id, entry[1]])
	var right := _panel_column(main, Rect2(622, 0, 530, 358))
	if not selectable: _label("도감 소개 · 현재 경기 비활성", right, 18, STYLE.GOLD)
	match tab:
		"기술":
			_techniques(id, right)
			_label(_passive_text(character.passive_description), right, 18, STYLE.MUTED)
		"연계":
			_label("기본 연속 공격 %d타" % character.base_move_set.combo_count, right, 23, STYLE.GOLD)
			for link: ComboLinkData in character.base_move_set.combo_links:
				_label("%s → %s · %s" % [_attack_title(character, link.from_attack_id), _attack_title(character, link.next_attack_id), _action_name(String(link.input_action_id))], right, 18)
		"이야기": _character_story(character, right)
		_: _stats_summary(character, right, true)
	var roster := HBoxContainer.new()
	main.add_child(roster)
	_place(roster, Rect2(0, 372, 1152, 84))
	for item: Dictionary in app.catalog.products:
		if item.kind != "character": continue
		var active: bool = app.catalog.is_playable_character(StringName(item.id))
		if not active and state.get("preset_edit", false): continue
		var row := _button(String(item.name), "update", {"selected_id": item.id, "browse_only": not active, "detail_scroll": 0, "story_page": 0, "technique": "light"}, roster, item.id == id)
		row.size_flags_horizontal = SIZE_EXPAND_FILL
		row.icon = ForestArenaResources.load_texture("fa.ui.menu.v07.character." + String(item.id))
		row.expand_icon = true
		row.add_theme_constant_override("icon_max_width", 60)
		row.set_meta("qa_id", "menu/%s/%s/%s" % [state.id, "character" if active else "preview", item.id])
	if state.id == "character_detail":
		_footer_button("연습 준비", "practice", {}, false, not selectable or not app.store.owns(id) or state.get("preset_edit", false))
	_footer_button("초안에 넣기" if state.get("preset_edit", false) else "이 캐릭터 선택", "select", {"id": id}, true, not selectable)

func _stats_summary(character: CharacterData, parent: VBoxContainer, show_chart := false) -> void:
	_label("기본 능력치", parent, 28, STYLE.GOLD)
	var stats := character.base_stats
	var values_parent := parent
	if show_chart:
		var columns := HBoxContainer.new()
		parent.add_child(columns)
		_stats_chart(character, columns)
		values_parent = VBoxContainer.new()
		values_parent.size_flags_horizontal = SIZE_EXPAND_FILL
		columns.add_child(values_parent)
	for row: Array in [["체력", str(roundi(stats.max_hp))], ["지상 이동", str(roundi(stats.ground_speed))], ["공중 이동", str(roundi(stats.air_speed))], ["점프", str(roundi(stats.jump_velocity))], ["무게", "%.2f" % stats.weight]]:
		var line := HBoxContainer.new()
		values_parent.add_child(line)
		_label(row[0], line, 22, STYLE.MUTED).size_flags_horizontal = SIZE_EXPAND_FILL
		_label(row[1], line, 22, STYLE.TEXT)

func _stat_values(stats: CharacterStats) -> Array[float]:
	return [stats.max_hp, stats.ground_speed, stats.air_speed, stats.jump_velocity, stats.weight]

func _stats_chart(character: CharacterData, parent: HBoxContainer) -> void:
	var chart := Control.new()
	chart.mouse_filter = MOUSE_FILTER_IGNORE
	chart.custom_minimum_size = Vector2(224, 220)
	parent.add_child(chart)
	var values := _stat_values(character.base_stats)
	var maxima := values.duplicate()
	for other: CharacterData in app.catalog.combat.characters:
		var profile := _stat_values(other.base_stats)
		for i in values.size(): maxima[i] = maxf(maxima[i], profile[i])
	var center := Vector2(112, 102)
	var vertices := PackedVector2Array()
	for i in values.size():
		var direction := Vector2.UP.rotated(TAU * i / values.size())
		vertices.append(center + direction * 80.0)
	for scale_value: float in [0.25, 0.5, 0.75, 1.0]:
		var outline := Line2D.new()
		outline.width = 1.0
		outline.closed = true
		outline.default_color = Color(STYLE.MUTED, 0.46)
		for vertex: Vector2 in vertices:
			outline.add_point(center.lerp(vertex, scale_value))
		chart.add_child(outline)
	var fill := Polygon2D.new()
	fill.color = Color(STYLE.MINT, 0.34)
	var points := PackedVector2Array()
	for i in values.size(): points.append(center.lerp(vertices[i], values[i] / maxima[i]))
	fill.polygon = points
	chart.add_child(fill)
	var line := Line2D.new()
	line.points = points
	line.closed = true
	line.width = 2.0
	line.default_color = STYLE.GOLD
	chart.add_child(line)
	_label("도감 내 상대 비교", chart, 14, STYLE.MUTED, Rect2(4, 188, 214, 26))

func _character_story(character: CharacterData, parent: VBoxContainer) -> void:
	var page := clampi(int(state.get("story_page", 0)), 0, 1)
	var paragraphs := [character.background_setting, character.concept_summary]
	if character.character_id == &"myo-ryung":
		paragraphs = ["묘령은 백평원 출신으로 숲에서 일어난 일을 독립적으로 조사합니다. 기록인장을 따라 단서를 모으고, 직접 확인한 사실을 기록합니다.", "묘령은 조사 중 자현과 협력합니다. 각자의 목표와 방식은 다르지만, 함께 단서를 확인하며 사건의 실마리를 찾습니다."]
	_label("스토리 · %d / 2" % (page + 1), parent, 28, STYLE.GOLD)
	_label(paragraphs[page], parent, 22)
	var nav := HBoxContainer.new()
	parent.add_child(nav)
	_button("이전", "update", {"story_page": 0, "detail_scroll": 0}, nav, false, false, page == 0).size_flags_horizontal = SIZE_EXPAND_FILL
	_button("다음", "update", {"story_page": 1, "detail_scroll": 0}, nav, false, false, page == 1).size_flags_horizontal = SIZE_EXPAND_FILL

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
	if id == "pebble-yoyo": return "fa.accessory.pebble.yoyo"
	return "fa.ui.menu09.artifact." + id.trim_prefix("fixture-")

func _accessory_category(id: String) -> String:
	if id in ["pebble-yoyo", "fixture-boxing-gloves"]: return "attack"
	if id == "fixture-iron-armor": return "defense"
	return "special"

func _accessory_filters(parent: VBoxContainer) -> void:
	var filters := [["전체", "전체"], ["공격", "attack"]]
	if not state.get("preset_edit", false):
		filters.append_array([["방어", "defense"], ["특수", "special"]])
	_tabs(filters, "filter", parent, String(state.filter))

func _accessories() -> void:
	if state.get("preset_edit", false) and state.filter not in ["전체", "attack"]:
		state.filter = "전체"
	var id: String = String(state.get("selected_id", app.store.data.selected_accessory))
	if not state.get("browse_only", false) or not app.catalog.contains(id, "accessory"):
		if not app.catalog.is_playable_accessory(StringName(id)): id = "pebble-yoyo"
	if state.filter != "전체" and state.filter != _accessory_category(id):
		for candidate: Dictionary in app.catalog.products:
			if candidate.kind != "accessory" or _accessory_category(candidate.id) != state.filter: continue
			if state.get("preset_edit", false) and not app.catalog.is_playable_accessory(StringName(candidate.id)): continue
			id = candidate.id
			break
	state.selected_id = id
	var active: bool = app.catalog.is_playable_accessory(StringName(id))
	state.browse_only = not active
	var item: Dictionary = app.catalog.product(id)
	_label(_product_name(id), main, 34, STYLE.TEXT, Rect2(0, 0, 342, 48))
	_texture(_accessory_icon(id), main, Rect2(0, 52, 346, 280))
	var detail := _panel_column(main, Rect2(354, 0, 364, 358))
	_label("장착 효과", detail, 28, STYLE.GOLD)
	_label(item.description, detail, 21)
	_label(_owned_label(id) if active else "소개용 · 현재 경기 비활성", detail, 20, STYLE.MINT)
	if id == "pebble-yoyo":
		_label("피해 없이 가드로 막을 수 있습니다. 사용 중 이동과 다른 행동이 제한됩니다.", detail, 20, STYLE.MUTED)
	var right := _panel_column(main, Rect2(730, 0, 422, 358), "media_scroll")
	if id in ["pebble-yoyo", "fixture-iron-armor"]:
		_preview_media("accessory", id.trim_prefix("fixture-"), _product_name(id) + " 소개", right)
	else:
		_label("신기 소개", right, 26, STYLE.GOLD)
		_label("이 신기의 효과를 왼쪽에서 확인하세요.", right, 19, STYLE.MUTED)
	_accessory_filters(right)
	var strip := ScrollContainer.new()
	strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(strip)
	_place(strip, Rect2(0, 370, 1152, 86))
	var roster := HBoxContainer.new()
	strip.add_child(roster)
	for candidate: Dictionary in app.catalog.products:
		if candidate.kind != "accessory": continue
		var is_active: bool = app.catalog.is_playable_accessory(StringName(candidate.id))
		if state.get("preset_edit", false) and not is_active: continue
		if state.filter != "전체" and state.filter != _accessory_category(candidate.id): continue
		var row := _button(_product_name(candidate.id), "update", {"selected_id": candidate.id, "browse_only": not is_active, "detail_scroll": 0, "media_scroll": 0}, roster, candidate.id == id)
		row.custom_minimum_size.x = 158
		row.icon = ForestArenaResources.load_texture(_accessory_icon(candidate.id))
		row.expand_icon = true
		row.add_theme_constant_override("icon_max_width", 36)
		row.set_meta("qa_id", "menu/accessory_collection/%s/%s" % ["accessory" if is_active else "preview", candidate.id])
	if roster.get_child_count() == 0: _label("이 분류에 장착 가능한 신기가 없습니다.", roster, 20, STYLE.MUTED)
	if active and app.store.owns(id):
		_footer_button("신기 해제", "unequip", {})
		_footer_button("초안에 넣기" if state.get("preset_edit", false) else "이 신기 장착", "select", {"id": id}, true)
	elif active:
		_footer_button("상점에서 0원 획득", "open", {"id": "shop", "params": {"category": "accessory"}}, true)

func _card(item: Dictionary, parent: Node, selected := false, behavior := "shop") -> void:
	var target := "shop_detail" if behavior == "shop" else "collection_detail"
	var card := _button("", "open", {"id": target, "params": {"product_id": item.id, "technique": "light", "detail_scroll": 0}}, parent, selected)
	card.custom_minimum_size = Vector2(276, 312)
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.set_meta("qa_id", ("menu/shop/detail/" if behavior == "shop" else "menu/collection/read/") + String(item.id))
	var margin := MarginContainer.new()
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(margin)
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	var column := VBoxContainer.new()
	column.mouse_filter = MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var icon := TextureRect.new()
	icon.texture = ForestArenaResources.load_texture("fa.ui.menu.v07.character." + String(item.id) if item.kind == "character" else _accessory_icon(item.id))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size.y = 94
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_child(icon)
	_label(_product_name(item.id), column, 23)
	_label(_owned_label(item.id), column, 17, STYLE.GOLD)
	if not app.catalog.is_playable_product(item.id): _label("현재 경기 비활성", column, 17, STYLE.MUTED)
	_label("상세 보기" if behavior == "shop" else "기록 읽기", column, 18, STYLE.GOLD)
	card.custom_minimum_size.y = maxf(card.custom_minimum_size.y, margin.get_combined_minimum_size().y)

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
	_label("신기 · " + _product_name(String(preset.get("accessory", "")), "장착 없음"), right, 23)
	var acc_button := _button("신기 바꾸기", "preset_edit", {"id": "accessory_collection"}, right)
	acc_button.set_meta("qa_id", "menu/preset/edit/accessory")
	var remove := _button("신기 해제", "preset_clear_accessory", {}, right)
	remove.set_meta("qa_id", "menu/preset/clear/accessory")
	_footer_button("편성 저장", "preset_save", {})
	_footer_button("이 편성으로 준비", "preset_apply", {}, true)

func _shop() -> void:
	var top := VBoxContainer.new()
	main.add_child(top)
	_place(top, Rect2(0, 0, 1152, 72))
	_tabs([["캐릭터", "character"], ["신기", "accessory"], ["조약돌", "stone"], ["무지개돌", "rainbow"]], "category", top, String(state.category))
	var category := String(state.category)
	if category in ["stone", "rainbow"]:
		var rows := _panel_column(main, Rect2(0, 84, 1152, 372), "scroll")
		var currency := "조약돌" if category == "stone" else "무지개돌"
		_label(currency, rows, 34, STYLE.GOLD)
		_label("상품 구성과 교환·결제 조건은 미정입니다.", rows, 23)
		_label("판매 상품 없음", rows, 20, STYLE.MUTED)
		return
	if category == "accessory":
		var filters := VBoxContainer.new()
		main.add_child(filters)
		_place(filters, Rect2(0, 84, 536, 72))
		_accessory_filters(filters)
	var top_offset := 168 if category == "accessory" else 84
	var rows := _scroll(main, Rect2(0, top_offset, 1152, 456 - top_offset))
	var grid := GridContainer.new()
	grid.columns = 4
	rows.add_child(grid)
	for item: Dictionary in app.catalog.products:
		if category != "전체" and item.kind != category: continue
		if item.kind == "accessory" and state.filter != "전체" and state.filter != _accessory_category(item.id): continue
		_card(item, grid)

func _product_detail() -> void:
	var id := String(state.get("product_id", ""))
	var item: Dictionary = app.catalog.product(id)
	if item.is_empty():
		_label("선택한 항목을 찾을 수 없습니다.", main, 24, STYLE.MUTED, Rect2(0, 0, 550, 60))
		return
	var active: bool = app.catalog.is_playable_product(id)
	var is_character: bool = item.kind == "character"
	_label(_product_name(id), main, 34, STYLE.TEXT, Rect2(0, 0, 358, 48))
	_texture("fa.ui.menu.v07.character." + id if is_character else _accessory_icon(id), main, Rect2(0, 60, 358, 392))
	var details := _panel_column(main, Rect2(374, 0, 290, 456))
	_label(item.description, details, 20, STYLE.MUTED)
	_label(_owned_label(id) if active else "소개용 · 현재 경기 비활성", details, 19, STYLE.MINT)
	var right := _panel_column(main, Rect2(680, 0, 472, 456), "media_scroll")
	if is_character:
		var character: CharacterData = app.catalog.combat.character_by_id(StringName(id))
		_stats_summary(character, details)
		_techniques(id, right)
		if state.id == "collection_detail":
			_character_story(character, right)
		else:
			var roster := HBoxContainer.new()
			right.add_child(roster)
			for candidate: Dictionary in app.catalog.products:
				if candidate.kind != "character": continue
				var switch := _button(String(candidate.name), "update", {"product_id": candidate.id, "technique": "light", "media_scroll": 0}, roster, candidate.id == id)
				switch.size_flags_horizontal = SIZE_EXPAND_FILL
				switch.add_theme_font_size_override("font_size", roundi(16 * text_scale))
				switch.set_meta("qa_id", "menu/shop_detail/character/" + String(candidate.id))
	elif id in ["pebble-yoyo", "fixture-iron-armor"]:
		_preview_media("accessory", id.trim_prefix("fixture-"), _product_name(id) + " 소개", right)
	else:
		_label("신기 소개", right, 28, STYLE.GOLD)
		_label(item.description, right, 22)
	if state.id != "shop_detail":
		_label("도감은 읽기 전용입니다.", details, 18, STYLE.MUTED)
		return
	if not active:
		_footer_button("현재 판매하지 않음", "unavailable", {}, false, true)
	elif app.store.owns(id):
		_footer_button("보유 중", "owned", {}, false, true)
	else:
		var buy := _footer_button("0원 · 무료 구매", "shop_purchase", {}, true)
		buy.set_meta("qa_id", "purchase/" + id)
		buy.pressed.connect(_confirm_purchase.bind(item))

func _confirm_purchase(item: Dictionary) -> void:
	var id := String(item.id)
	if not app.catalog.is_playable_product(id) or app.store.owns(id): return
	confirm(_product_name(id), "기존 무료 구매로 보유 목록에 추가할까요?", "0원 · 구매 확인", func() -> void:
		action.emit("purchase", {"id": id}))
	var button := modal.find_child("ModalConfirm", true, false) as Button
	button.set_meta("qa_id", "menu/shop/purchase_confirm/" + id)

func _collection() -> void:
	var top := VBoxContainer.new()
	main.add_child(top)
	_place(top, Rect2(0, 0, 1152, 72))
	_tabs([["캐릭터", "character"], ["신기", "accessory"]], "category", top, String(state.category) if state.category != "전체" else "character")
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
	_label("신기 · " + _product_name(String(app.store.data.selected_accessory), "장착 없음"), right, 20)
	_label("보유 캐릭터 %d / %d · 신기 %d / %d" % [app.store.data.characters.size(), app.catalog.combat.characters.size(), app.store.data.accessories.size(), app.catalog.combat.accessories.size()], right, 20, STYLE.MUTED)
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
		confirm("프로필을 연결할까요?", "최종 닉네임: %s\n보유한 캐릭터·신기는 합치고 현재 편성·설정·기기 프리셋·조작은 유지합니다. 원본 계정과 기록은 보존합니다." % nickname, "연결", func() -> void: action.emit("service", {"action": "retry_identity" if service_snapshot.get("intent", false) else "unify", "payload": {"nickname": nickname, "api_url": url}})))
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
	var category: String = "controls" if state.id == "controls" else String(state.category)
	var body := LIFE.settings_panel(self, category)
	if body == null: return
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
		if id in ["shop_detail", "collection_detail"]: continue
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
	if is_instance_valid(_media_player): _media_player.stop()
	_media_player = null
	_media_toggle = null
	_media_status = null
	remove_child(modal)
	modal.queue_free()
	modal = null
	return true
