class_name Menu09MatchView
extends RefCounted
## Native presentation for the approved lobby and match preparation. The app owns play and LAN.
const STYLE = preload("res://scripts/premium_menu/premium_menu_theme.gd")
const ART_PREFIX := "fa.ui.menu.v07.character."
const BG_ID := "fa.ui.menu.v07.background.character-room"
const SIZE := Vector2(1280, 720)
var app: Node
var canvas: Control
var overlay: Control

func _init(owner: Node, canonical_id: String, footer_top := 586.0) -> void:
	app = owner
	var page: Control = app.page
	page.get_node("ForestlightContent").hide()
	page.theme = STYLE.make(app._text_scale())
	page.set_meta("menu_screen_id", canonical_id)
	var background := TextureRect.new()
	background.texture = ForestArenaResources.load_texture(BG_ID)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var atmosphere := ColorRect.new()
	atmosphere.color = Color(STYLE.BG, 0.65)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(atmosphere)
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.name = "LobbyCanvas" if app.screen == "home" else "Menu09MatchCanvas"
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(canvas)
	canvas.size = SIZE
	canvas.pivot_offset = SIZE / 2.0
	page.resized.connect(_fit)
	_fit()
	_fit.call_deferred()
	fill(Rect2(0, 0, 1280, 108), Color(STYLE.BG, 0.94))
	fill(Rect2(0, footer_top, 1280, 720 - footer_top), Color(STYLE.BG, 0.94))

func _fit() -> void:
	if not is_instance_valid(canvas) or not canvas.is_inside_tree(): return
	var safe := CombatUiGeometry.safe_rect(canvas.get_viewport())
	var ratio := minf(1.0, minf(safe.size.x / SIZE.x, safe.size.y / SIZE.y))
	canvas.scale = Vector2.ONE * ratio
	canvas.position = safe.get_center() - SIZE / 2.0

func place(node: Control, area: Rect2) -> void:
	node.position = area.position
	node.size = area.size

func fill(area: Rect2, color: Color) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(rect)
	place(rect, area)

func label(text: String, area: Rect2, font_size := 20, color := STYLE.TEXT, align := HORIZONTAL_ALIGNMENT_LEFT, parent: Control = null) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.horizontal_alignment = align
	node.add_theme_font_size_override("font_size", roundi(font_size * app._text_scale()))
	node.add_theme_color_override("font_color", color)
	(parent if parent != null else canvas).add_child(node)
	place(node, area)
	return node

func panel(area: Rect2, parent: Control = null) -> Panel:
	var node := Panel.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", STYLE.surface())
	(parent if parent != null else canvas).add_child(node)
	place(node, area)
	return node

func art(id: String, area: Rect2, parent: Control = null) -> TextureRect:
	var node := TextureRect.new()
	node.texture = ForestArenaResources.load_texture(id)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else canvas).add_child(node)
	place(node, area)
	return node

func button(text: String, callback: Callable, area: Rect2, primary := false, disabled := false, font_size := 20, parent: Control = null) -> Button:
	var node: Button = app._button(text, callback, parent if parent != null else canvas, disabled)
	node.custom_minimum_size = Vector2(72, 72)
	node.clip_text = true
	node.add_theme_font_size_override("font_size", roundi(font_size * app._text_scale()))
	node.add_theme_stylebox_override("normal", STYLE.surface(primary, primary))
	node.add_theme_stylebox_override("hover", STYLE.surface(true, primary))
	node.add_theme_stylebox_override("pressed", STYLE.surface(true, true))
	node.add_theme_stylebox_override("disabled", STYLE.surface())
	node.add_theme_stylebox_override("focus", STYLE.surface(true))
	node.add_theme_color_override("font_color", STYLE.BG if primary else STYLE.TEXT)
	node.add_theme_color_override("font_hover_color", STYLE.BG if primary else STYLE.GOLD)
	node.add_theme_color_override("font_focus_color", STYLE.BG if primary else STYLE.GOLD)
	place(node, area)
	return node

func heading(title: String, subtitle: String, back: Callable) -> void:
	button("←", back, Rect2(64, 24, 72, 72), false, false, 26)
	label(title, Rect2(154, 25, 1050, 42), 30)
	label(subtitle, Rect2(156, 70, 1048, 32), 16, STYLE.MUTED)

func info(title: String, detail: String, confirm := Callable(), confirm_label := "확인") -> void:
	close_overlay()
	canvas.get_viewport().gui_release_focus()
	overlay = ColorRect.new()
	(overlay as ColorRect).color = Color(STYLE.BG, 0.88)
	overlay.name = "Menu09MatchOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(overlay)
	place(overlay, Rect2(Vector2.ZERO, SIZE))
	panel(Rect2(268, 210, 744, 292), overlay)
	label(title, Rect2(304, 235, 670, 52), 30, STYLE.GOLD, HORIZONTAL_ALIGNMENT_LEFT, overlay)
	label(detail, Rect2(304, 302, 670, 86), 21, STYLE.TEXT, HORIZONTAL_ALIGNMENT_LEFT, overlay)
	if confirm.is_valid():
		button("취소", close_overlay, Rect2(304, 402, 320, 72), false, false, 20, overlay)
		button(confirm_label, func() -> void:
			close_overlay()
			confirm.call(), Rect2(640, 402, 336, 72), true, false, 20, overlay)
	else:
		button("닫기", close_overlay, Rect2(304, 402, 672, 72), true, false, 20, overlay)

func close_overlay() -> bool:
	if not is_instance_valid(overlay): return false
	canvas.remove_child(overlay)
	overlay.queue_free()
	overlay = null
	return true

func lobby(notice: String) -> void:
	var selected_id := String(app.store.data.selected_character)
	var character: Dictionary = app.catalog.product(selected_id)
	var nickname := String(app.store.data.nickname)
	var portrait := art(ART_PREFIX + selected_id, Rect2(373, 108, 517, 448))
	portrait.name = "LobbyCharacter"
	button("프로필", app._show_premium_menu.bind("profile"), Rect2(64, 24, 84, 72), false, false, 17)
	label(nickname, Rect2(162, 28, 270, 38), 22)
	label("대표 캐릭터 · " + String(character.get("name", "")), Rect2(162, 65, 270, 30), 16, STYLE.MUTED)
	label("FOREST ARENA", Rect2(445, 43, 200, 34), 22, STYLE.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	label("조약돌 —    무지개돌 —", Rect2(659, 45, 294, 36), 18, STYLE.MUTED)
	button("공지", app._show_premium_menu.bind("notices"), Rect2(984, 24, 72, 72), false, false, 18)
	button("우편", app._show_premium_menu.bind("mail"), Rect2(1064, 24, 72, 72), false, false, 18)
	button("설정", app._show_premium_menu.bind("settings", {"category": "effects"}), Rect2(1144, 24, 72, 72), false, false, 18)
	label("FOREST ADVENTURE", Rect2(64, 134, 316, 26), 16, STYLE.MINT)
	label("숲에서 만나는\n새로운 한 판", Rect2(64, 167, 321, 94), 30)
	button("스토리 모드", app._open_local_prepare.bind(LocalMatchConfig.Mode.STORY), Rect2(64, 265, 265, 72))
	label("나의 편성", Rect2(64, 351, 260, 28), 18, STYLE.GOLD)
	label(String(character.get("name", "")), Rect2(64, 382, 260, 36), 23)
	var equipment: Dictionary = app.catalog.product(String(app.store.data.selected_accessory))
	label("신기 · " + String(equipment.get("name", "미장착")), Rect2(64, 424, 300, 32), 19, STYLE.MUTED)
	button("프리셋", app._show_premium_menu.bind("preset"), Rect2(64, 475, 116, 72), false, false, 17)
	button("접근성 설정", app._show_accessibility, Rect2(190, 475, 160, 72), false, false, 17)
	if not notice.is_empty():
		label(notice, Rect2(65, 550, 720, 37), 15, STYLE.MINT)
	elif not app.demo_mode:
		label("저장 · " + ("로컬 DB" if app.db_mode else "기기 저장"), Rect2(65, 550, 325, 30), 15, STYLE.MUTED)
	label("대전을 시작하세요", Rect2(912, 132, 304, 33), 19, STYLE.GOLD)
	button("일반대전", app._show_mode_select, Rect2(912, 173, 304, 112), true, false, 31)
	label("AI · 자동 매칭 · 로비", Rect2(924, 294, 292, 30), 18, STYLE.MUTED)
	button("랭킹대전", app._show_rank_lobby, Rect2(912, 332, 304, 76), false, false, 25)
	button("LAN 1:1 · 같은 Wi-Fi", app._open_lan_direct, Rect2(912, 420, 304, 72), false, false, 18)
	button("오프라인 대전", app._open_offline_direct, Rect2(912, 504, 304, 72), false, false, 20)
	if not app.demo_mode:
		button("저장 모드 · " + ("로컬 DB" if app.db_mode else "기기 저장"), app._show_db_connection, Rect2(415, 504, 282, 72), false, false, 18)
	var nav := Control.new()
	nav.name = "LobbyNavigation"
	canvas.add_child(nav)
	place(nav, Rect2(64, 613, 1152, 75))
	var items := [
		["상점", "shop", {}], ["캐릭터", "character_collection", {}],
		["신기", "accessory_collection", {}], ["미션", "mission", {}],
		["업적", "mission", {"category": "achievement"}], ["친구", "social", {}],
	]
	for index: int in items.size():
		var item: Array = items[index]
		button(item[0], app._show_premium_menu.bind(item[1], item[2]), Rect2(index * 193, 0, 182, 75), false, false, 16 if index == 0 else 18, nav)

func modes() -> void:
	heading("일반대전", "AI, 자동 매칭, 로비에서 대전 방식을 선택하세요", app._show_home)
	var cards := [
		["AI", "오프라인 AI 대전을 준비해요.", app._open_local_prepare.bind(LocalMatchConfig.Mode.AI, "mode_select")],
		["자동 매칭", "매칭 조건과 온라인 운영은 미정이에요.", func() -> void: info("자동 매칭", "자동 매칭과 시즌 운영은 준비 중입니다. 오프라인 AI 또는 같은 Wi-Fi 대전을 선택하세요.")],
		["로비", "방 목록과 전체 초대 코드를 확인해요.", app._open_rooms_from_mode],
	]
	for index: int in cards.size():
		var card: Array = cards[index]
		var x := 64.0 + index * 388.0
		button(card[0], card[2], Rect2(x, 169, 376, 288), index == 0, false, 31)
		label(card[1], Rect2(x + 12, 477, 352, 67), 19, STYLE.MUTED)
	label("개인전 · 팀전은 방 목록에서 준비할 수 있어요.", Rect2(64, 626, 1152, 44), 19, STYLE.MUTED)

func rooms(notice: String) -> void:
	heading("일반대전 · 방 목록", "현재 같은 Wi-Fi LAN은 1:1 · 오프라인은 개인전 최대 8명 / 팀당 최대 4명", app._back_from_rooms)
	var filters := ["전체", "개인전", "팀전"]
	for index: int in filters.size():
		var value: String = filters[index]
		var filter := button(value, app._select_menu09_room_filter.bind(value), Rect2(64 + index * 142, 129, 132, 72), false, false, 19)
		if value == app.menu09_room_filter:
			filter.text += " ✓"
			filter.add_theme_stylebox_override("normal", STYLE.surface(true))
	panel(Rect2(64, 216, 794, 278))
	label("제목 · 대전 방식", Rect2(86, 235, 433, 32), 18, STYLE.MUTED)
	label("인원        상태", Rect2(630, 235, 208, 32), 18, STYLE.MUTED)
	var selected_filter: String = app.menu09_room_filter
	var list_status := "공개 방 목록 준비 중" if selected_filter == "전체" else selected_filter + " 공개 방 목록 준비 중"
	label(list_status, Rect2(86, 294, 730, 42), 27)
	label("초대 코드를 받았다면 오른쪽에서 입장하세요.", Rect2(86, 350, 730, 52), 20, STYLE.MUTED)
	if not notice.is_empty(): label(notice, Rect2(86, 425, 740, 62), 17, STYLE.GOLD)
	button("개인전 준비", app._open_local_prepare.bind(LocalMatchConfig.Mode.SOLO, "lan_menu"), Rect2(64, 508, 390, 72), false, false, 21)
	button("팀전 준비", app._open_local_prepare.bind(LocalMatchConfig.Mode.TEAM, "lan_menu"), Rect2(468, 508, 390, 72), false, false, 21)
	panel(Rect2(880, 129, 336, 451))
	label("초대 코드로 입장", Rect2(900, 151, 295, 38), 23, STYLE.GOLD)
	button("초대 코드로 참가", app._show_lan_join, Rect2(900, 210, 296, 72), false, false, 20)
	label("방장이 전달한 FA5 전체 코드를 사용합니다.", Rect2(900, 301, 296, 84), 18, STYLE.MUTED)
	button("방 만들기", app._show_lan_host, Rect2(900, 488, 296, 72), true, false, 22)
	button("새로고침", app._refresh_menu09_rooms, Rect2(64, 612, 174, 72), false, false, 20)
	label("LAN 방 만들기에는 Mac 서버의 FAH5 연결 코드가 필요합니다.", Rect2(257, 636, 960, 42), 18, STYLE.MUTED)

func rank() -> void:
	heading("랭킹대전", "시즌 · 점수 · 승급 · 보상 · 매칭 운영은 미정", app._show_home)
	panel(Rect2(64, 135, 550, 445))
	art("fa.rank.rank.silver", Rect2(198, 154, 282, 262))
	label("실버 3 · 예시", Rect2(87, 430, 504, 58), 33, STYLE.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	label("실제 시즌 등급은 아직 제공하지 않습니다.", Rect2(87, 498, 504, 59), 19, STYLE.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	button("파티 찾기", func() -> void: info("파티 찾기", "랭킹 파티 운영은 준비 중입니다."), Rect2(672, 152, 544, 108), false, false, 27)
	button("친구 초대", func() -> void: info("친구 초대", "랭킹 파티 초대는 준비 중입니다. 같은 Wi-Fi 대전에서 기존 친구 초대를 이용할 수 있습니다."), Rect2(672, 279, 544, 108), false, false, 27)
	button("자동 매칭", func() -> void: info("자동 매칭", "랭킹대전 매칭은 준비 중입니다."), Rect2(672, 406, 544, 108), true, false, 27)
	label("시즌 랭크와 현재 LAN 승패 순위는 별개예요.", Rect2(64, 636, 760, 34), 18, STYLE.MUTED)
	button("LAN 순위 보기", app._show_premium_menu.bind("rank", {"entry_context": "rank_lobby"}), Rect2(907, 611, 309, 72))

func roster(config: LocalMatchConfig, lan := false) -> void:
	var total := 1 if lan else (config.participants.size() if config != null else 0)
	label("참가자 %d / %d" % [total, 2 if lan else 8], Rect2(64, 126, 380, 40), 22)
	var team_mode := config != null and config.mode == LocalMatchConfig.Mode.TEAM and not lan
	label("같은 Wi-Fi LAN 1:1" if lan else ("A팀 · 윗줄    B팀 · 아랫줄" if team_mode else "개인전 최대 8명 · 팀당 최대 4명"), Rect2(437, 131, 438, 32), 16, STYLE.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	var participants: Array = []
	if config != null: participants.assign(config.participants)
	var team_rows := {"alpha": [], "beta": []}
	if team_mode:
		for participant: LocalMatchParticipant in participants:
			team_rows[String(participant.team_id)].append(participant)
	for index: int in 8:
		var x := 64.0 + (index % 4) * 202.0
		var y := 173.0 + floorf(index / 4.0) * 169.0
		var area := Rect2(x, y, 190, 155)
		panel(area)
		var member: LocalMatchParticipant = null
		if team_mode:
			var row: Array = team_rows["alpha" if index < 4 else "beta"]
			if index % 4 < row.size(): member = row[index % 4]
		elif index < participants.size(): member = participants[index]
		if lan and index == 0:
			var nickname := String(app.demo_guest.nickname)
			member_card(area, String(app.store.data.selected_character), "방장 · 나", nickname)
		elif not lan and member != null:
			var role := "방장 · 나" if member.human_controlled else "AI"
			var member_name := String(app.store.data.nickname) if member.human_controlled else String(app.catalog.product(String(member.selection.character_id)).get("name", "AI"))
			member_card(area, String(member.selection.character_id), role, member_name)
		else:
			var note := "현재 LAN 범위 밖" if lan and index >= 2 else ("참가자 대기" if lan else "빈 자리")
			label("＋", Rect2(x, y + 44, 190, 45), 30, STYLE.LINE, HORIZONTAL_ALIGNMENT_CENTER)
			label(note, Rect2(x + 6, y + 102, 178, 42), 16, STYLE.MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func member_card(area: Rect2, id: String, role: String, player_name: String) -> void:
	label(role, Rect2(area.position + Vector2(12, 8), Vector2(166, 32)), 16, STYLE.GOLD)
	art(ART_PREFIX + id, Rect2(area.position + Vector2(59, 35), Vector2(72, 83)))
	label(player_name, Rect2(area.position + Vector2(8, 120), Vector2(174, 32)), 17, STYLE.TEXT, HORIZONTAL_ALIGNMENT_CENTER)

func room_settings() -> VBoxContainer:
	panel(Rect2(899, 124, 317, 389))
	label("경기 설정", Rect2(915, 138, 281, 42), 23, STYLE.GOLD)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_meta("qa_id", "prepare/room_settings_scroll")
	canvas.add_child(scroll)
	place(scroll, Rect2(913, 189, 289, 309))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.set_meta("menu09_room_options", true)
	scroll.add_child(column)
	return column

func form_column() -> VBoxContainer:
	panel(Rect2(64, 124, 1152, 448))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_meta("qa_id", app.screen + "/form_scroll")
	canvas.add_child(scroll)
	place(scroll, Rect2(86, 144, 1108, 407))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	return column
