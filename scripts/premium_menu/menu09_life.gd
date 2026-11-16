extends RefCounted
## MENU09 생활 화면. 계정·경기 기록·설정은 기존 앱의 저장과 서비스에서 읽는다.

const STYLE = preload("res://scripts/premium_menu/premium_menu_theme.gd")
const SIDEBAR := Rect2(0, 0, 190, 456)
const BODY := Rect2(218, 0, 934, 456)
const GRAPHICS := ["effects", "accessibility", "minimap", "controls", "debug"]
const GRAPHICS_TABS := [
	["화면 효과", "effects"], ["접근성", "accessibility"], ["미니맵", "minimap"],
	["조작", "controls"], ["임시 디버깅", "debug"],
]
const MISSION_TABS := [["일일", "daily"], ["주간", "weekly"], ["출석", "attendance"]]
const ACHIEVEMENT_TABS := [["대전", "combat"], ["수집", "collection"], ["기술", "skills"]]
const FRIEND_TABS := [
	["친구", "friends"], ["받은 신청", "incoming"], ["보낸 신청", "outgoing"],
	["최근 상대", "recent"], ["받은 초대", "invites"],
]


static func screen_title(state: Dictionary, fallback: String) -> String:
	if state.get("id") == "settings":
		return "설정"
	if state.get("id") != "mission":
		return fallback
	match _mission_category(state):
		"daily": return "일일 미션"
		"weekly": return "주간 미션"
		"attendance": return "출석"
		"achievement", "achievements": return "업적"
	return fallback


static func header_action(view: Control) -> void:
	if view.state.id != "mission":
		return
	var category := _mission_category(view.state)
	var is_achievement := category in ["achievement", "achievements"]
	var update := {"category": view.state.get("mission_return", "daily"), "detail_scroll": 0} if is_achievement else {
		"category": "achievement", "mission_return": category, "achievement_group": "", "detail_scroll": 0,
	}
	var needs_footer := bool(view.state.get("local_load_error", false))
	var parent: Node = view.footer if needs_footer else view.content
	var button: Button = view._button("미션" if is_achievement else "업적", "update", update, parent)
	button.set_meta("qa_id", "menu/mission/return_to_mission" if is_achievement else "menu/mission/open_achievement")
	if not needs_footer:
		view._place(button, Rect2(836, 32, 180, 72))


static func _mission_category(state: Dictionary) -> String:
	var category := String(state.get("category", "daily"))
	return String({"전체": "daily", "일일": "daily", "주간": "weekly", "업적": "achievement"}.get(category, category))


static func _sidebar(view: Control, entries: Array, current: String, state_key := "category") -> VBoxContainer:
	var column: VBoxContainer = view._scroll(view.main, SIDEBAR, "category_scroll")
	column.add_theme_constant_override("separation", 12)
	for entry: Array in entries:
		var value := String(entry[1])
		var button: Button = view._button(String(entry[0]), "update", {state_key: value, "detail_scroll": 0}, column, current == value)
		button.set_meta("qa_id", "menu/%s/%s/%s" % [view.state.id, state_key, value])
	return column


static func _info(view: Control, title: String, body: String, unavailable_action := "") -> void:
	var column: VBoxContainer = view._modal_shell(title, body)
	if not unavailable_action.is_empty():
		view._button(unavailable_action, "unavailable", {}, column, false, false, true)
	var close: Button = view._button("닫기", "modal_cancel", {}, column)
	close.pressed.connect(view.close_modal)


static func _info_button(view: Control, parent: Node, text: String, id: String, title: String, body: String, unavailable_action := "") -> Button:
	var button: Button = view._button(text, id, {}, parent)
	button.pressed.connect(_info.bind(view, title, body, unavailable_action))
	return button


static func missions(view: Control) -> void:
	var category := _mission_category(view.state)
	if category in ["achievement", "achievements"]:
		_achievements(view, category)
		return
	_sidebar(view, MISSION_TABS, category)
	if category == "attendance":
		_attendance(view)
		return
	var column: VBoxContainer = view._panel_column(view.main, BODY)
	view._label("한국 시간 매일 00:00 갱신" if category == "daily" else "한국 시간 월요일 00:00 갱신", column, 22, STYLE.GOLD)
	_mission_records(view, column, category)
	_info_button(view, view.footer, "집계 안내", "mission_rules", "미션 집계 안내", "정상 종료한 AI·개인·팀·LAN 대전이 집계됩니다. 연습·Story·포기 경기는 제외합니다. 미션 보상은 없습니다.")
	view._refresh_button()


static func _mission_records(view: Control, rows: VBoxContainer, category: String) -> void:
	view._service_status(rows, false)
	var count := 0
	for mission: Dictionary in view.service_snapshot.get("data", {}).get("missions", []):
		if mission.get("category", "") != category:
			continue
		count += 1
		_mission_card(view, rows, mission)
	if count == 0 and view.service_snapshot.get("status") not in ["loading", "error"]:
		view._label("이 분류에 표시할 경기 기록이 없습니다.", rows, 22, STYLE.MUTED)
	if view.service_snapshot.get("status") in ["local", "unlinked"]:
		var connect_button: Button = view._button("계정 연결", "open", {"id": "profile"}, rows)
		connect_button.set_meta("qa_id", "menu/mission/connect_profile")


static func _mission_card(view: Control, rows: VBoxContainer, mission: Dictionary) -> void:
	var completed := bool(mission.get("completed", false))
	var current := int(mission.get("current", 0))
	var target := int(mission.get("target", 0))
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", STYLE.surface(completed))
	rows.add_child(panel)
	var row := HBoxContainer.new()
	panel.add_child(row)
	row.add_theme_constant_override("separation", 16)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(details)
	var title := String(mission.get("title", "경기 기록"))
	view._label(title, details, 23, STYLE.GOLD if completed else STYLE.TEXT)
	view._label("%d / %d · 보상 없음" % [current, target], details, 18, STYLE.MUTED)
	if mission.get("id") == "all-characters":
		view._label("이전 기록 포함 · 현재 경기 선택은 자현·나비", details, 16, STYLE.MUTED)
	var bar := ProgressBar.new()
	bar.max_value = maxi(1, target)
	bar.value = current
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size.y = 8
	details.add_child(bar)
	var button: Button = view._button("달성" if completed else "진행 중", "mission_detail", {}, row, completed)
	button.custom_minimum_size.x = 186
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.set_meta("qa_id", "menu/mission/mission/" + String(mission.get("id", "")))
	button.pressed.connect(func() -> void:
		var body := "%d / %d\n%s\n연습·Story·포기는 제외합니다. 보상은 없습니다." % [
			current, target, "완료했습니다." if completed else "완료한 경기 기록으로 진행됩니다.",
		]
		view.confirm(title, body, "확인", func() -> void: pass))


static func _attendance(view: Control) -> void:
	var column: VBoxContainer = view._panel_column(view.main, BODY)
	view._label("28칸 배치 예시 · 운영 기간과 시작일 미정", column, 22, STYLE.GOLD)
	view._label("출석 집계와 보상 수령이 열리면 기록을 확인할 수 있어요.", column, 19, STYLE.MUTED)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)
	for day: int in range(1, 29):
		var cell := PanelContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.custom_minimum_size = Vector2(0, 63)
		cell.add_theme_stylebox_override("panel", STYLE.surface())
		cell.set_meta("menu09_attendance_day", day)
		grid.add_child(cell)
		var label: Label = view._label(str(day), cell, 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	view._footer_button("오늘 출석 확인 · 준비 중", "attendance_check", {}, true, true)
	_info_button(view, view.footer, "운영 안내", "attendance_info", "출석 운영 안내", "출석 기간, 초기화 기준, 연속·누적 집계와 보상은 아직 정해지지 않았어요. 화면의 숫자는 달력 배치 예시입니다.")


static func _achievements(view: Control, category: String) -> void:
	var selected := String(view.state.get("achievement_group", "combat" if category == "achievements" else ""))
	if selected.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		view.main.add_child(row)
		view._place(row, Rect2(0, 68, 1152, 335))
		for entry: Array in ACHIEVEMENT_TABS:
			var column := VBoxContainer.new()
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(column)
			var group := String(entry[1])
			var button: Button = view._button(String(entry[0]), "update", {"achievement_group": group, "detail_scroll": 0}, column)
			button.set_meta("qa_id", "menu/mission/achievement_group/" + group)
			button.size_flags_vertical = Control.SIZE_EXPAND_FILL
			button.add_theme_font_size_override("font_size", roundi(31 * view.text_scale))
			var description: Label = view._label("누적 경기 기록" if group == "combat" else "조건·집계·보상 미정", column, 19, STYLE.MINT if group == "combat" else STYLE.MUTED)
			description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return
	_sidebar(view, ACHIEVEMENT_TABS, selected, "achievement_group")
	var column: VBoxContainer = view._panel_column(view.main, BODY)
	match selected:
		"combat":
			view._label("대전 업적 · 누적 경기 기록", column, 23, STYLE.GOLD)
			_mission_records(view, column, "achievements")
			view._refresh_button()
		"collection", "skills":
			view._label("수집 업적" if selected == "collection" else "기술 업적", column, 26, STYLE.GOLD)
			view._label("업적 조건과 집계 기준을 준비하고 있어요.", column, 21, STYLE.MUTED)
			_info_button(view, column, "미정 항목 보기", "achievement_info", "업적 운영 안내", "조건, 집계 기간과 보상 기준을 정한 뒤 제공할 예정이에요.", "보상 수령 · 미정")
			view._footer_button("보상 수령 · 미정", "achievement_reward", {}, false, true)
	view._footer_button("업적 분류", "update", {"achievement_group": ""})


static func friends(view: Control) -> void:
	var category := String(view.state.get("category", "friends"))
	category = String({"전체": "friends", "친구": "friends", "최근 플레이어": "recent", "찾기": "search"}.get(category, category))
	_sidebar(view, FRIEND_TABS, category)
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 12)
	view.main.add_child(search_row)
	view._place(search_row, Rect2(218, 0, 934, 72))
	var field := LineEdit.new()
	field.placeholder_text = "정확한 닉네임 (1~12자)"
	field.text = String(view.state.get("search", ""))
	field.max_length = 12
	field.custom_minimum_size.y = 72 / maxf(view._fit_scale, 0.5)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.set_meta("qa_id", "menu/social/search_input")
	search_row.add_child(field)
	field.text_changed.connect(func(value: String) -> void: view.state.search = value)
	var search: Button = view._button("검색", "social_search", {}, search_row, category == "search", true)
	search.custom_minimum_size.x = 160
	search.set_meta("qa_id", "menu/social/search_submit")
	var submit := func() -> void:
		var nickname := field.text.strip_edges()
		view.action.emit("service", {
			"action": "search",
			"payload": {"nickname": nickname},
			"state": {"search": nickname, "category": "search", "detail_scroll": 0},
		})
	search.pressed.connect(submit)
	field.text_submitted.connect(func(_value: String) -> void: submit.call())
	var rows: VBoxContainer = view._panel_column(view.main, Rect2(218, 88, 934, 368))
	view._service_status(rows)
	var data: Dictionary = view.service_snapshot.get("data", {})
	if data.has(category):
		var items: Array = data[category]
		if items.is_empty() and view.service_snapshot.get("status") not in ["loading", "error"]:
			var empty_messages := {
				"friends": "등록한 친구가 없습니다.", "incoming": "받은 친구 신청이 없습니다.",
				"outgoing": "보낸 친구 신청이 없습니다.", "recent": "아직 최근 LAN 상대가 없습니다.",
				"invites": "받은 대전 초대가 없습니다.", "search": "검색 결과가 없습니다.",
			}
			view._label(String(empty_messages.get(category, "표시할 항목이 없습니다.")), rows, 24, STYLE.MUTED)
		for item: Dictionary in items:
			_friend_card(view, item, category, rows)
	if view.app.get("menu_service") != null and not view.app.menu_service.identity.get("operations", []).is_empty():
		view._service_button("이전 요청 다시 확인", "retry_social", {}, view.footer, "retry_social")
	view._refresh_button()


static func _friend_card(view: Control, item: Dictionary, category: String, rows: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	rows.add_child(row)
	row.add_theme_constant_override("separation", 12)
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(72, 72)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override("panel", STYLE.surface())
	row.add_child(badge)
	var nickname := String(item.get("nickname", "")).strip_edges()
	var initial: Label = view._label(nickname.left(1) if not nickname.is_empty() else "·", badge, 25, STYLE.MINT)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(details)
	view._social_row(item, category, details)


static func mail(view: Control) -> void:
	view._label("선택", view.main, 18, STYLE.GOLD, Rect2(0, 6, 92, 30))
	view._label("우편 내용", view.main, 18, STYLE.GOLD, Rect2(108, 6, 520, 30))
	view._label("남은 시간", view.main, 18, STYLE.GOLD, Rect2(1000, 6, 152, 30))
	var column: VBoxContainer = view._panel_column(view.main, Rect2(0, 52, 1152, 404))
	view._label("표시할 우편이 없습니다.", column, 28, STYLE.TEXT)
	view._label("우편 발송과 수령은 준비 중입니다.", column, 20, STYLE.MUTED)
	view._footer_button("모두 받기", "mail_claim_all", {}, true, true)
	view._footer_button("지우기", "mail_delete", {}, false, true)
	view._footer_button("모두 지우기", "mail_delete_all", {}, false, true)


static func notices(view: Control) -> void:
	var category := String(view.state.get("category", "notice"))
	if category not in ["notice", "active", "past"]:
		category = "notice"
	_sidebar(view, [["공지사항", "notice"], ["진행 이벤트", "active"], ["지난 이벤트", "past"]], category)
	var column: VBoxContainer = view._panel_column(view.main, BODY)
	match category:
		"active":
			view._label("진행 이벤트", column, 27, STYLE.GOLD)
			view._label("현재 표시할 진행 이벤트가 없습니다.", column, 21, STYLE.MUTED)
		"past":
			view._label("지난 이벤트", column, 27, STYLE.GOLD)
			view._label("현재 표시할 지난 이벤트가 없습니다.", column, 21, STYLE.MUTED)
		_:
			view._label("공지사항", column, 27, STYLE.GOLD)
			view._label("표시할 공지사항이 없습니다. 공지 운영은 준비 중입니다.", column, 21, STYLE.MUTED)
	view._footer_button("닫기", "back", {})


static func settings_panel(view: Control, category: String) -> VBoxContainer:
	if view.state.id == "controls":
		_control_settings_navigation(view, category)
		return view._panel_column(view.main, Rect2(270, 0, 882, 456))
	var graphics := category in GRAPHICS
	var left: VBoxContainer = view._scroll(view.main, SIDEBAR, "category_scroll")
	left.add_theme_constant_override("separation", 12)
	for entry: Array in [
		["그래픽", "effects"], ["사운드", "sound"], ["알림", "notifications"], ["계정", "account"], ["정보", "info"],
	]:
		var value := String(entry[1])
		var button: Button = view._button(String(entry[0]), "category", {"value": value}, left, graphics if value == "effects" else category == value)
		# The first graphics entry opens effects, including from Sound.
		var key := "graphics" if graphics and value == "effects" else value
		button.set_meta("qa_id", "menu/settings/category/" + key)
	if graphics:
		_graphics_navigation(view, category)
		return view._panel_column(view.main, Rect2(218, 88, 934, 368))
	var column: VBoxContainer = view._panel_column(view.main, BODY)
	match category:
		"notifications":
			view._label("알림", column, 28, STYLE.GOLD)
			view._label("게임 알림을 준비하고 있어요.", column, 21, STYLE.MUTED)
			view._button("알림 설정 · 준비 중", "notifications_unavailable", {}, column, false, false, true)
			return null
		"account":
			view._label("계정", column, 28, STYLE.GOLD)
			view._label("프로필과 연결 상태를 확인합니다.", column, 20, STYLE.MUTED)
			view._button("프로필 관리", "open", {"id": "profile"}, column, false, true).set_meta("qa_id", "menu/settings/profile")
			var logout: Button = view._button("로그아웃 안내", "logout_info", {}, column)
			logout.pressed.connect(_info.bind(view, "로그아웃", "계정 로그아웃은 준비 중입니다.", "로그아웃 · 준비 중"))
			return null
		"info":
			view._label("FOREST ARENA", column, 28, STYLE.GOLD)
			var version := String(ProjectSettings.get_setting("application/config/version", ""))
			if not version.is_empty():
				view._label("앱 버전 " + version, column, 20, STYLE.MUTED)
			view._button("공지사항", "open", {"id": "notices"}, column).set_meta("qa_id", "menu/settings/notices")
			var exit: Button = view._button("게임 종료 안내", "exit_info", {}, column)
			exit.pressed.connect(_info.bind(view, "게임 종료", "이 화면의 종료 기능은 준비 중입니다.", "종료 · 준비 중"))
			return null
	return column


static func _graphics_navigation(view: Control, category: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	view.main.add_child(scroll)
	view._place(scroll, Rect2(218, 0, 934, 80))
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	scroll.add_child(row)
	for entry: Array in GRAPHICS_TABS:
		var value := String(entry[1])
		var button: Button
		if value == "controls":
			button = view._button(String(entry[0]), "open", {"id": "controls"}, row, category == value)
		else:
			button = view._button(String(entry[0]), "category", {"value": value}, row, category == value)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("qa_id", "menu/settings/category/" + value)


static func _control_settings_navigation(view: Control, category: String) -> void:
	var left: VBoxContainer = view._scroll(view.main, Rect2(0, 0, 246, 456), "category_scroll")
	left.add_theme_constant_override("separation", 4)
	for entry: Array in [
		["사운드", "sound"], ["화면 효과", "effects"], ["접근성", "accessibility"],
		["미니맵", "minimap"], ["조작", "controls"], ["임시 디버깅", "debug"],
	]:
		var value := String(entry[1])
		var params := {} if value == "controls" else {"category": value}
		var button: Button = view._button(String(entry[0]), "open", {"id": "controls" if value == "controls" else "settings", "params": params}, left, category == value)
		button.set_meta("qa_id", "menu/controls/category/" + value)
