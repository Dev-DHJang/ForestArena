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
var db_client: DbProfileClient
var db_mode := false
var db_session_path := "user://db_profile_session.json"
var storage_busy := false
var db_address := "http://127.0.0.1:3000"
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
var haptic_request_count := 0
var lan_client: LanMatchClient
var lan_host_code := ""
var lan_invite_code := ""
var lan_current_invite := ""
var lan_local_slot := 0
var lan_loadouts: Dictionary = {}
var lan_status_label: Label
var demo_guest: DemoGuestClient
var demo_guest_session_path := "user://demo_guest_session.json"
var demo_mode := OS.has_feature("demo") or "--demo" in OS.get_cmdline_user_args()
var demo_intent := ""
var demo_api_url := ""
var demo_generation := 0

func _ready() -> void:
	get_tree().quit_on_go_back = false
	layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	lan_client = LanMatchClient.new()
	lan_client.access_token_provider = Callable(self, "_refresh_demo_lan_token")
	add_child(lan_client)
	lan_client.status_changed.connect(_on_lan_status)
	lan_client.room_created.connect(_on_lan_room_created)
	lan_client.room_ready.connect(_on_lan_room_ready)
	lan_client.snapshot_received.connect(_on_lan_snapshot)
	lan_client.presentation_event_received.connect(_on_lan_presentation_event)
	lan_client.peer_status_changed.connect(_on_lan_peer_status)
	lan_client.match_finished.connect(_on_lan_match_finished)
	lan_client.rematch_changed.connect(_on_lan_rematch_changed)
	lan_client.failed.connect(_on_lan_failed)
	demo_guest = DemoGuestClient.new()
	demo_guest.session_path = demo_guest_session_path
	add_child(demo_guest)
	store = LocalPlayerStore.new(catalog, save_path)
	db_client = DbProfileClient.new()
	db_client.session_path = db_session_path
	add_child(db_client)
	var configured := OS.get_environment("FOREST_ARENA_API_URL")
	if not configured.is_empty(): db_address = configured
	var saved := db_client.saved_connection()
	var auto_db := not demo_mode and (bool(saved.get("use_db", false)) or "--db-profile" in OS.get_cmdline_user_args())
	if auto_db and configured.is_empty(): db_address = String(saved.get("api_url", db_address))
	if auto_db:
		_show_db_connection()
	elif not store.load_profile():
		_show_storage_error()
	else:
		message = "이전 저장 백업을 복구했습니다." if store.recovered else ""
		_show_home() if store.data.first_granted else _show_first()
	if auto_db:
		_connect_db.call_deferred(false)

func _new_page(title: String, background := true) -> void:
	ForestArenaAudio.set_context(screen)
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
	if db_mode and not db_client.pending.is_empty():
		_label("이전 저장 요청의 결과를 확인해야 합니다.", 18)
		_button("DB 저장 재시도", _retry_db)

func _label(text: String, font_size := 22) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", roundi(font_size * _text_scale()))
	body.add_child(label)
	return label

func _button(text: String, callback: Callable, parent: Node = null, disabled := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(190, 58)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", roundi(21 * _text_scale()))
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
	button.pressed.connect(func() -> void:
		ForestArenaAudio.play_event(&"ui_back" if text in ["로비", "취소", "계속하기", "대전 준비", "LAN 메뉴"] else &"ui_click", {})
		callback.call())
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
		if await _change_profile("grant_first", {"id": id}): _show_home()
		else:
			message = store.error
			_show_home() if store.data.first_granted else _show_first())
	if not demo_mode: _button("저장 모드 · " + ("로컬 DB" if db_mode else "기기 저장"), _show_db_connection)

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
	_new_page("Forest Arena · 대전 로비")
	_label("네 캐릭터와 함께 숲의 경기장으로")
	_button("오프라인 대전", _show_prepare)
	_button("LAN 1:1 · 같은 Wi-Fi", _show_lan_menu)
	_button("상점 · 모두 0원", _show_shop)
	_button("접근성 설정", _show_accessibility)
	if not demo_mode: _button("저장 모드 · " + ("로컬 DB" if db_mode else "기기 저장"), _show_db_connection)
	_label("로컬 DB에 저장합니다 · 변경 번호 %d" % db_client.revision if db_mode else "구매와 선택은 이 기기에 저장됩니다.", 18)


func _show_lan_menu() -> void:
	screen = "lan_menu"
	_new_page("LAN 1:1 · 같은 Wi-Fi")
	_label("Mac에서 ./scripts/demo-server.sh start를 실행한 뒤 표시되는 한 줄 연결 코드를 사용합니다.", 18)
	_label("무료 APK 데모 · 같은 네트워크 1대1 · 게스트와 닉네임은 로컬 서버에 저장됩니다.", 18)
	if not demo_guest.nickname.is_empty(): _label("온라인 닉네임: " + demo_guest.nickname, 18)
	_button("방 만들기", _show_lan_host)
	_button("초대 코드로 참가", _show_lan_join)
	_button("로비", _show_home)


func _show_lan_host() -> void:
	screen = "lan_host"
	_new_page("LAN 방 만들기")
	_label("Mac 호스트 연결 코드", 18)
	_line_input("FAH2|http://192.168.x.x:3001|ws://192.168.x.x:7778|2", lan_host_code, func(value: String) -> void: lan_host_code = value)
	_button("연결 코드 붙여넣기", _paste_lan_host_code)
	_lan_loadout_controls(_show_lan_host)
	_button("방 생성", _begin_lan_host)
	_button("LAN 메뉴", _show_lan_menu)


func _show_lan_join() -> void:
	screen = "lan_join"
	_new_page("LAN 방 참가")
	_label("방장이 전달한 한 줄 초대 코드", 18)
	_line_input("FA2|http://192.168.x.x:3001|ws://192.168.x.x:7778|ABCDEFGH|2", lan_invite_code, func(value: String) -> void: lan_invite_code = value)
	_button("초대 코드 붙여넣기", _paste_lan_invite_code)
	_lan_loadout_controls(_show_lan_join)
	_button("방 참가", _begin_lan_join)
	_button("LAN 메뉴", _show_lan_menu)


func _line_input(placeholder: String, value: String, callback: Callable) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.text = value
	input.custom_minimum_size = Vector2(760, 58)
	input.add_theme_font_size_override("font_size", roundi(19 * _text_scale()))
	input.text_changed.connect(callback)
	body.add_child(input)
	return input


func _paste_lan_host_code() -> void:
	lan_host_code = DisplayServer.clipboard_get().strip_edges()
	if lan_host_code.is_empty(): message = "클립보드에 연결 코드가 없습니다."
	_show_lan_host()


func _paste_lan_invite_code() -> void:
	lan_invite_code = DisplayServer.clipboard_get().strip_edges()
	if lan_invite_code.is_empty(): message = "클립보드에 초대 코드가 없습니다."
	_show_lan_join()


func _lan_loadout_controls(refresh: Callable) -> void:
	_label("내 캐릭터: " + String(catalog.product(store.data.selected_character).get("name", store.data.selected_character)))
	_character_cards(true, func(id: String) -> void:
		if not await _change_profile("select", {"character": id, "accessory": store.data.selected_accessory, "opponent": store.data.opponent_character}): message = store.error
		refresh.call())
	_choice("장신구", [""] + store.data.accessories, store.data.selected_accessory, func(id: String) -> void:
		if not await _change_profile("select", {"character": store.data.selected_character, "accessory": id, "opponent": store.data.opponent_character}): message = store.error
		refresh.call())


func _selected_lan_loadout() -> LoadoutSelection:
	var selection := LoadoutSelection.new()
	selection.character_id = StringName(store.data.selected_character)
	selection.accessory_id = StringName(store.data.selected_accessory)
	return selection


func _begin_lan_host() -> void:
	await _demo_login("host")


func _begin_lan_join() -> void:
	await _demo_login("join")


func _demo_login(intent: String, new_guest := false) -> void:
	if demo_guest.busy: return
	var parsed := LanInvite.parse_host_code(lan_host_code) if intent == "host" else LanInvite.parse_invite_code(lan_invite_code)
	if parsed.has("error"):
		_on_lan_failed(String(parsed.error))
		return
	demo_intent = intent
	demo_api_url = String(parsed.api_url)
	demo_generation += 1
	var generation := demo_generation
	screen = "demo_login"
	_new_page("게스트 접속 중")
	_label("처음 연결할 때 게스트를 만들고, 이후에는 같은 게스트로 접속합니다.", 18)
	_button("취소", _cancel_demo_login)
	var ok := await demo_guest.login(demo_api_url, new_guest)
	if generation != demo_generation or not is_inside_tree(): return
	if not ok:
		screen = "demo_guest_error"
		_new_page("게스트 연결 확인")
		_label(_demo_error(demo_guest.error), 18)
		_button("다시 시도", func() -> void: await _demo_login(intent))
		if demo_guest.session_invalid or demo_guest.error == "session_endpoint_mismatch":
			_button("새 게스트 시작 안내", _confirm_new_demo_guest)
		_button("취소", _cancel_demo_login)
		return
	_show_demo_nickname()


func _show_demo_nickname() -> void:
	screen = "demo_nickname"
	_new_page("온라인 닉네임")
	_label("한글·영문·숫자·밑줄 2~12자. 다른 게스트와 같은 이름은 사용할 수 없습니다.", 18)
	var input := _line_input("닉네임", demo_guest.nickname, func(_value: String) -> void: pass)
	input.name = "DemoNicknameInput"
	input.max_length = 12
	_button("닉네임 저장", func() -> void:
		if demo_guest.busy: return
		var generation := demo_generation
		var ok := await demo_guest.set_nickname(input.text)
		if generation != demo_generation or screen != "demo_nickname": return
		message = "닉네임을 저장했습니다." if ok else _demo_error(demo_guest.error)
		_show_demo_nickname())
	_button("이 닉네임으로 계속", _continue_demo_lan, null, demo_guest.nickname.is_empty())
	_button("취소", _cancel_demo_login)


func _confirm_new_demo_guest() -> void:
	screen = "demo_guest_reset"
	_new_page("새 게스트로 시작할까요?")
	_label("기존 서버 게스트는 삭제하지 않습니다. 이 기기의 무료 보유·선택·설정도 유지합니다. 기존 닉네임은 새 게스트에서 사용할 수 없습니다.", 18)
	_button("새 게스트 시작", func() -> void: await _demo_login(demo_intent, true))
	_button("취소", _cancel_demo_login)


func _cancel_demo_login() -> void:
	demo_generation += 1
	demo_guest.cancel()
	lan_client.leave()
	_show_lan_menu()


func _refresh_demo_lan_token() -> String:
	var ok := await demo_guest.login(demo_api_url)
	return demo_guest.access_token if ok else ""


func _continue_demo_lan() -> void:
	if demo_guest.busy or demo_guest.nickname.is_empty(): return
	var ok := lan_client.begin_host(lan_host_code, _selected_lan_loadout(), demo_guest.nickname, demo_guest.access_token) if demo_intent == "host" else lan_client.begin_join(lan_invite_code, _selected_lan_loadout(), demo_guest.nickname, demo_guest.access_token)
	if not ok: return
	screen = "lan_connecting"
	_new_page("LAN 서버 연결 중", false)
	lan_status_label = _label("인증한 게스트로 방을 연결하고 있습니다.")
	_button("취소", _leave_lan_to_menu)


func _demo_error(code: String) -> String:
	return {
		"nickname_taken": "이미 사용 중인 닉네임입니다. 다른 이름을 선택하세요.",
		"invalid_nickname": "한글·영문·숫자·밑줄로 2~12자를 입력하세요.",
		"session_invalid": "이전 게스트를 복구하지 못했습니다. 새 게스트 시작을 선택할 수 있습니다.",
		"invalid_refresh_token": "이전 게스트가 만료되었습니다. 새 게스트 시작을 선택할 수 있습니다.",
		"session_endpoint_mismatch": "다른 서버의 게스트가 저장돼 있습니다. 이전 서버로 연결하거나 새 게스트를 선택하세요.",
		"session_save_failed": "게스트 기록을 저장하지 못했습니다. 기기 저장 공간을 확인하세요.",
		"cancelled": "연결을 취소했습니다.",
	}.get(code, "게스트 서버 연결 실패. 같은 네트워크와 서버 실행 상태를 확인하세요. (%s)" % code)


func _on_lan_room_created(invite_code: String) -> void:
	lan_current_invite = invite_code
	screen = "lan_waiting"
	_new_page("LAN 방 · 참가자 대기", false)
	_label("내 닉네임: " + demo_guest.nickname, 18)
	_label("아래 한 줄 초대 코드를 같은 Wi-Fi의 참가자에게 전달하세요.", 18)
	var code := _line_input("", invite_code, func(_value: String) -> void: pass)
	code.editable = false
	lan_status_label = _label("참가자를 기다리는 중", 18)
	_button("초대 코드 복사", _copy_lan_invite)
	_button("방 닫기", _leave_lan_to_menu)


func _copy_lan_invite() -> void:
	if lan_current_invite.is_empty(): return
	DisplayServer.clipboard_set(lan_current_invite)
	if lan_status_label != null and is_instance_valid(lan_status_label):
		lan_status_label.text = "초대 코드를 복사했습니다. 참가자에게 전달하세요."


func _on_lan_room_ready(loadouts: Dictionary, local_slot_value: int) -> void:
	lan_loadouts = loadouts.duplicate(true)
	lan_local_slot = local_slot_value
	_start_lan_match()


func _start_lan_match() -> void:
	if lan_loadouts.size() != 2 or lan_local_slot not in [1, 2]:
		_on_lan_failed("invalid_match_configuration")
		return
	_close_match()
	match_scene = MATCH_SCENE.instantiate()
	match_scene.app_shell_mode = true
	match_scene.get_node("Interface/TouchCommandSource").extended_actions = true
	add_child(match_scene)
	match_controller = match_scene.get_node("MatchController") as MatchController
	match_controller.set_physics_process(false)
	match_controller.pause_match(true)
	match_controller.bot_source = null
	match_controller.bot_sources.clear()
	match_controller.presentation_event.connect(_on_presentation_event)
	var fighters: Array[FighterController] = [match_controller.player, match_controller.training_dummy]
	for index: int in 2:
		var slot := index + 1
		var selection := _lan_selection_from(lan_loadouts.get(str(slot), {}))
		if selection == null:
			_on_lan_failed("loadout_build_failed")
			return
		var result := LoadoutBuilder.build(selection, catalog.combat)
		if not result.succeeded():
			_on_lan_failed("loadout_build_failed")
			return
		var fighter := fighters[index]
		fighter.fighter_id = &"lan_host" if slot == 1 else &"lan_guest"
		fighter.character_data = catalog.combat.character_by_id(selection.character_id)
		fighter.show_debug_body = false
		if not fighter.configure_profile(result.profile):
			_on_lan_failed("profile_configuration_failed")
			return
		var presentation := PRESENTATION.new()
		presentation.name = "Presentation"
		fighter.add_child(presentation)
	var local_fighter := fighters[lan_local_slot - 1]
	var opponent := fighters[1 if lan_local_slot == 1 else 0]
	var camera := match_scene.get_node("Camera2D") as Camera2D
	camera.player = local_fighter
	var indicator := match_scene.get_node("Interface/OffscreenOpponentIndicator") as OffscreenOpponentIndicator
	indicator.player = local_fighter
	indicator.opponent = opponent
	match_scene.apply_accessibility(store.data.accessibility)
	match_scene.get_node("Interface/Restart").hide()
	match_scene.get_node("Interface/DebugReadout").hide()
	match_scene.get_node("Interface/PhaseLabel").hide()
	match_scene.get_node("Interface/HudPanel").hide()
	var readout := match_scene.get_node("Interface/MatchReadout") as Label
	readout.position = Vector2(84, 24)
	readout.add_theme_font_size_override("font_size", roundi(20 * _text_scale()))
	readout.add_theme_color_override("font_outline_color", Color("122d38"))
	readout.add_theme_constant_override("outline_size", 8)
	var markers := {}
	for index: int in 2:
		var slot := index + 1
		var fighter := fighters[index]
		markers[fighter.fighter_id] = {"nickname": lan_client.participant_names.get(str(slot), "참가자 %d" % slot), "character_id": fighter.character_data.character_id, "team_id": ""}
	match_scene.configure_minimap(markers, local_fighter.fighter_id, false, store.data.minimap)
	ForestArenaAudio.begin_match()
	_show_lan_match_controls()


func _lan_selection_from(value: Variant) -> LoadoutSelection:
	if not value is Dictionary: return null
	var selection := LoadoutSelection.new()
	selection.schema_version = int(value.get("schema_version", 0))
	selection.character_id = StringName(value.get("character_id", ""))
	selection.job_id = StringName(value.get("job_id", ""))
	selection.accessory_id = StringName(value.get("accessory_id", ""))
	return selection if selection.is_valid_definition() else null


func _show_lan_match_controls() -> void:
	ForestArenaAudio.set_context("lan_match")
	screen = "lan_match"
	match_scene.get_node("Interface").visible = true
	if page != null:
		layer.remove_child(page)
		page.queue_free()
	page = Control.new()
	layer.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var leave := _button("대전 나가기", _show_lan_leave_confirm, page)
	_place_match_button(leave)


func _show_lan_leave_confirm() -> void:
	if not is_instance_valid(match_scene): return
	screen = "lan_leave_confirm"
	match_scene.get_node("Interface/TouchCommandSource").release_all_touches()
	match_scene._release_semantic_actions()
	match_scene.get_node("Interface").visible = false
	_new_page("LAN 대전에서 나갈까요?", false)
	_label("확인하는 동안에도 서버의 경기는 계속됩니다.", 18)
	_button("계속 플레이", _show_lan_match_controls)
	_button("대전 나가기", _leave_lan_to_menu)


func _on_lan_snapshot(snapshot: Dictionary) -> void:
	if match_controller == null or not is_instance_valid(match_scene): return
	for fighter_value: Variant in snapshot.get("fighters", []):
		if not fighter_value is Dictionary: continue
		var fighter := match_controller.call("_fighter_by_id", StringName(fighter_value.get("id", ""))) as FighterController
		if fighter != null: fighter.apply_network_snapshot(fighter_value)
	match_controller.snapshot_changed.emit(snapshot)


func _on_lan_presentation_event(event_id: StringName, payload: Dictionary) -> void:
	if match_controller != null: match_controller.presentation_event.emit(event_id, payload)


func _on_lan_match_finished(result: Dictionary) -> void:
	if match_scene != null:
		match_scene.get_node("Interface").visible = false
		match_scene.get_node("Interface/TouchCommandSource").release_all_touches()
	screen = "lan_result"
	var winner_slot := int(result.get("winner_slot", 0))
	if result.get("reason") != "room_closed":
		ForestArenaAudio.finish_match("draw" if winner_slot == 0 and result.get("reason") == "draw" else ("victory" if winner_slot == lan_local_slot else "defeat"))
	var title := "무승부" if winner_slot == 0 and result.get("reason") == "draw" else ("승리!" if winner_slot == lan_local_slot else "패배")
	if result.get("reason") == "room_closed": title = "방이 종료되었습니다"
	_new_page(title, false)
	_label("참가자: " + String(lan_client.participant_names.get("1", "참가자 1")) + " · " + String(lan_client.participant_names.get("2", "참가자 2")), 18)
	_label("종료 사유: " + _lan_reason_text(String(result.get("reason", "combat"))), 18)
	_button("같은 조건으로 재대전 요청", _request_lan_rematch)
	_button("LAN 메뉴", _leave_lan_to_menu)
	_button("로비", _leave_lan_to_home)


func _request_lan_rematch() -> void:
	lan_client.request_rematch(true)
	screen = "lan_rematch_wait"
	_new_page("재대전 대기", false)
	lan_status_label = _label("상대의 재대전 요청을 기다리는 중")
	_button("재대전 취소", _leave_lan_to_menu)


func _on_lan_rematch_changed(ready_slots: Array, closed: bool) -> void:
	if closed:
		_close_match()
		lan_client.stop()
		message = "LAN 방이 종료되었습니다."
		_show_lan_menu()
	elif lan_status_label != null and is_instance_valid(lan_status_label):
		lan_status_label.text = "재대전 준비 %d/2" % ready_slots.size()


func _on_lan_peer_status(_slot: int, connected: bool) -> void:
	if screen == "lan_match" and not connected:
		message = "상대 연결이 끊겼습니다. 60초 동안 복귀를 기다립니다."


func _on_lan_status(text: String) -> void:
	if lan_status_label != null and is_instance_valid(lan_status_label): lan_status_label.text = text


func _on_lan_failed(code: String) -> void:
	ForestArenaAudio.play_event(&"ui_error", {})
	_close_match()
	message = "LAN 연결 실패: " + _lan_reason_text(code)
	_show_lan_menu()


func _lan_reason_text(code: String) -> String:
	return {
		"combat": "전투 종료", "draw": "동시 최종 탈락", "disconnect": "연결 이탈",
		"room_closed": "방 종료", "room_not_found": "방 코드를 찾을 수 없음", "room_full": "방이 가득 참",
		"server_busy": "호스트에서 다른 방이 진행 중", "invalid_loadout": "캐릭터 또는 장신구 선택 오류",
		"invalid_host_code": "호스트 연결 코드 형식 오류", "invalid_invite_code": "초대 코드 형식 오류",
		"invalid_private_endpoint": "사설 Wi-Fi 주소가 아님", "unsupported_protocol": "앱과 호스트 버전이 다릅니다. 데모 APK를 업데이트하세요.",
		"nickname_required": "게스트 닉네임을 먼저 설정하세요", "duplicate_guest": "같은 게스트는 두 번 참가할 수 없습니다",
		"unauthorized": "게스트 인증이 만료되었거나 유효하지 않습니다", "request_timeout": "8초 안에 서버 응답을 받지 못했습니다",
		"network_not_allowed": "허용된 같은 네트워크에서만 연결할 수 있습니다",
		"authentication_required": "먼저 게스트로 접속하세요", "authentication_failed": "게스트 인증을 확인하지 못했습니다. 다시 접속하세요",
		"authentication_timeout": "게스트 확인 시간이 지났습니다. 서버를 확인하고 다시 시도하세요", "authentication_unavailable": "게스트 API를 사용할 수 없습니다",
		"authentication_refresh_failed": "게스트를 복원하지 못했습니다. LAN 메뉴에서 다시 접속하세요", "reconnect_timeout": "60초 안에 경기로 돌아오지 못했습니다",
		"connection_lost": "호스트 연결 끊김", "connect_start_failed": "네트워크 연결을 시작하지 못함",
	}.get(code, code)


func _leave_lan_to_menu() -> void:
	demo_generation += 1
	demo_guest.cancel()
	lan_client.leave()
	_close_match()
	_show_lan_menu()


func _leave_lan_to_home() -> void:
	lan_client.leave()
	_close_match()
	_show_home()

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
			if not await _change_profile("purchase", {"id": item.id}): message = store.error
			_show_shop(), row, owned)
	_button("로비", _show_home)


func _show_accessibility() -> void:
	screen = "accessibility"
	_new_page("접근성 설정")
	_label("설정은 로컬 DB에 저장됩니다." if db_mode else "설정은 이 기기에 저장됩니다.", 18)
	var settings: Dictionary = store.data.accessibility
	var scales := [1.0, 1.15, 1.3]
	_choice_labels("텍스트 크기", ["기본", "크게", "매우 크게"], scales.find(float(settings.text_scale)), func(index: int) -> void:
		await _change_profile("accessibility", {"text_scale": scales[index], "reduce_visual_effects": bool(settings.reduce_visual_effects), "haptics_enabled": bool(settings.haptics_enabled)})
		_show_accessibility())
	_toggle("피격 번쩍임 줄이기", bool(settings.reduce_visual_effects), func(value: bool) -> void:
		await _change_profile("accessibility", {"text_scale": float(settings.text_scale), "reduce_visual_effects": value, "haptics_enabled": bool(settings.haptics_enabled)})
		_show_accessibility())
	_toggle("진동 피드백", bool(settings.haptics_enabled), func(value: bool) -> void:
		await _change_profile("accessibility", {"text_scale": float(settings.text_scale), "reduce_visual_effects": bool(settings.reduce_visual_effects), "haptics_enabled": value})
		_show_accessibility())
	_add_minimap_settings()
	_label("소리 설정은 이 기기에 저장됩니다.", 18)
	_toggle("전체 음소거", ForestArenaAudio.muted, func(value: bool) -> void:
		_save_audio_levels(ForestArenaAudio.music_level, ForestArenaAudio.effects_level, value))
	_audio_slider("음악 음량", ForestArenaAudio.music_level, true)
	_audio_slider("효과음 음량", ForestArenaAudio.effects_level, false)
	_label("소리·진동이 없어도 HP, stock, 가드와 상태 표시는 텍스트로 확인할 수 있습니다.", 18)
	_button("로비", _show_home)

func _add_minimap_settings() -> void:
	_label("닉네임과 미니맵", 26)
	_label("아래 닉네임은 오프라인 표시용입니다. 온라인 닉네임은 LAN 게스트 접속 후 서버에서 정합니다.", 18)
	var nickname_input := _line_input("닉네임 · 1~12자", String(store.data.nickname), func(_value: String) -> void: pass)
	nickname_input.name = "NicknameInput"
	nickname_input.max_length = 12
	_button("닉네임 저장", func() -> void:
		var ok := await _change_profile("identity", {"nickname": nickname_input.text.strip_edges()})
		message = "닉네임을 저장했습니다." if ok else (store.error if not store.error.is_empty() else "닉네임은 1~12자로 입력하세요. 줄바꿈과 제어 문자는 사용할 수 없습니다.")
		_show_accessibility())
	var settings: Dictionary = store.data.minimap
	var preview := BattleMinimap.new()
	preview.name = "MinimapPreview"
	preview.embedded = true
	preview.custom_minimum_size = Vector2(240, 150)
	var preview_row := HBoxContainer.new()
	preview_row.custom_minimum_size.y = 150
	body.add_child(preview_row)
	preview_row.add_child(preview)
	preview.set_process(false)
	preview.configure(load("res://assets/combat/stages/forest_ledge_stage.tres") as StageData, {
		&"self": {"nickname": store.data.nickname, "character_id": store.data.selected_character if store.data.first_granted else "ja-hyun", "team_id": "alpha"},
		&"other": {"nickname": "AI 1", "character_id": "myo-ryung", "team_id": "beta"}
	}, &"self", true)
	preview.apply_settings(settings, _text_scale())
	preview.update_snapshot({"fighters": [{"id": "self", "stocks": 3, "position": Vector2(100, 420)}, {"id": "other", "stocks": 3, "position": Vector2(1100, 520)}]})
	var caption := _label("미니맵 투명도 · %d%%" % settings.transparency, 20)
	var slider := HSlider.new()
	slider.name = "MinimapTransparency"
	slider.min_value = 0
	slider.max_value = 90
	slider.step = 1
	slider.value = settings.transparency
	slider.custom_minimum_size = Vector2(320, 58)
	body.add_child(slider)
	slider.value_changed.connect(func(value: float) -> void:
		caption.text = "미니맵 투명도 · %d%%" % int(value)
		var draft := settings.duplicate(true)
		draft.transparency = int(value)
		preview.apply_settings(draft, _text_scale()))
	_button("투명도 저장", func() -> void:
		var next := settings.duplicate(true)
		next.transparency = int(slider.value)
		await _save_minimap_settings(next))
	_choice_labels("캐릭터 표시", ["얼굴", "점"], 0 if settings.marker_style == "face" else 1, func(index: int) -> void:
		var next := settings.duplicate(true)
		next.marker_style = "face" if index == 0 else "dot"
		await _save_minimap_settings(next))
	_toggle("미니맵 이름 표시", settings.show_names, func(enabled: bool) -> void:
		var next := settings.duplicate(true)
		next.show_names = enabled
		await _save_minimap_settings(next))


func _save_minimap_settings(settings: Dictionary) -> void:
	var ok := await _change_profile("minimap", settings)
	message = "미니맵 설정을 저장했습니다." if ok else (store.error if not store.error.is_empty() else "미니맵 설정을 저장하지 못했습니다.")
	_show_accessibility()


func _show_prepare() -> void:
	screen = "prepare"
	_new_page("대전 준비 · " + _mode_name(selected_mode))
	_choice_labels("모드", ["스토리 프롤로그 · 첫 기록인장", "Solo · 각자전", "Team · 팀전", "AI · 1대1", "연습"], int(selected_mode), func(index: int) -> void:
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
		if not await _change_profile("select", {"character": id, "accessory": store.data.selected_accessory, "opponent": store.data.opponent_character}): message = store.error
		_show_prepare())
	_choice("장신구", [""] + store.data.accessories, store.data.selected_accessory, func(id: String) -> void:
		if not await _change_profile("select", {"character": store.data.selected_character, "accessory": id, "opponent": store.data.opponent_character}): message = store.error
		_show_prepare())
	var opponents: Array = []
	for character: CharacterData in catalog.combat.characters: opponents.append(String(character.character_id))
	_choice("AI 캐릭터", opponents, store.data.opponent_character, func(id: String) -> void:
		if not await _change_profile("select", {"character": store.data.selected_character, "accessory": store.data.selected_accessory, "opponent": id}): message = store.error
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
	options.item_selected.connect(func(index: int) -> void:
		ForestArenaAudio.play_event(&"ui_select", {})
		callback.call(ids[index]))
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
	options.item_selected.connect(func(index: int) -> void:
		ForestArenaAudio.play_event(&"ui_select", {})
		callback.call(index))
	row.add_child(options)


func _toggle(title: String, enabled: bool, callback: Callable) -> void:
	var row := HBoxContainer.new()
	body.add_child(row)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", roundi(20 * _text_scale()))
	row.add_child(label)
	var toggle := CheckButton.new()
	toggle.text = "켜짐" if enabled else "꺼짐"
	toggle.button_pressed = enabled
	toggle.add_theme_font_size_override("font_size", roundi(20 * _text_scale()))
	toggle.toggled.connect(func(value: bool) -> void:
		ForestArenaAudio.play_event(&"ui_select", {})
		callback.call(value))
	row.add_child(toggle)

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
	match_controller.presentation_event.connect(_on_presentation_event)
	match_scene.get_node("Interface/TouchCommandSource").extended_actions = true
	add_child(match_scene)
	match_scene.apply_accessibility(store.data.accessibility)
	if OS.is_debug_build(): match_scene.add_child(load("res://scripts/local_performance_probe.gd").new())
	match_scene.get_node("Interface/Restart").hide()
	match_scene.get_node("Interface/DebugReadout").hide()
	match_scene.get_node("Interface/PhaseLabel").hide()
	match_scene.get_node("Interface/HudPanel").hide()
	var readout := match_scene.get_node("Interface/MatchReadout") as Label
	readout.position = Vector2(84, 24)
	readout.add_theme_font_size_override("font_size", roundi(20 * _text_scale()))
	readout.add_theme_color_override("font_outline_color", Color("122d38"))
	readout.add_theme_constant_override("outline_size", 8)
	for index: int in range(2, config.participants.size()):
		_add_match_fighter(config.participants[index], index)
	_configure_bots(config)
	var markers := {}
	for index: int in config.participants.size():
		var participant: LocalMatchParticipant = config.participants[index]
		markers[participant.participant_id] = {"nickname": store.data.nickname if participant.human_controlled else "AI %d" % index, "character_id": participant.selection.character_id, "team_id": participant.team_id}
	match_scene.configure_minimap(markers, &"player", config.mode == LocalMatchConfig.Mode.TEAM, store.data.minimap)
	match_controller.reset_match()
	ForestArenaAudio.begin_match()
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
	if match_controller != null and match_controller.stage_data != null and index < match_controller.stage_data.spawn_points.size():
		return match_controller.stage_data.spawn_points[index]
	return Vector2.ZERO


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
		var bot := BOT.new(participant.participant_id, config.seed + index * 97, {"reaction_interval_ticks": config.reaction_interval_ticks, "team_id": participant.team_id, "stage_data": match_controller.stage_data})
		# Preserve the legacy 1v1 hook while all local modes share the same AI path.
		if index == 1: match_controller.bot_source = bot
		else: match_controller.bot_sources.append(bot)


func _mode_name(mode: LocalMatchConfig.Mode) -> String:
	return ["스토리 프롤로그 · 첫 기록인장", "Solo · 각자전", "Team · 팀전", "AI · 1대1", "연습"][int(mode)]

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
	_place_match_button(pause)

func _place_match_button(button: Button) -> void:
	var map := match_scene.get_node("Interface/BattleMinimap") as BattleMinimap
	var place := func() -> void:
		if not is_instance_valid(button): return
		button.position = map.position + Vector2(0, map.size.y + 12)
		button.size = Vector2(map.size.x, 58)
	map.item_rect_changed.connect(place)
	place.call()


func pause_match() -> void:
	if match_controller == null or screen == "result": return
	match_scene.get_node("Interface").visible = false
	match_controller.pause_match(true)
	ForestArenaAudio.set_match_paused(true)
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
	ForestArenaAudio.set_match_paused(false)
	_show_match_controls()

func handle_back_request(request_msec: int = -1) -> void:
	if storage_busy: return
	var now_msec: int = Time.get_ticks_msec() if request_msec < 0 else request_msec
	if OS.is_debug_build():
		print("FOREST_ARENA_BACK_REQUEST " + JSON.stringify({"screen": screen, "msec": now_msec, "previous_msec": last_back_request_msec}))
	if now_msec >= last_back_request_msec and now_msec - last_back_request_msec < BACK_REQUEST_DEBOUNCE_MSEC:
		return
	last_back_request_msec = now_msec
	match screen:
		"shop", "prepare", "accessibility":
			_show_home()
		"lan_menu":
			_show_home()
		"demo_login", "demo_nickname", "demo_guest_error", "demo_guest_reset":
			_cancel_demo_login()
		"lan_host", "lan_join":
			_show_lan_menu()
		"lan_connecting", "lan_waiting", "lan_result", "lan_rematch_wait":
			_leave_lan_to_menu()
		"lan_match":
			_show_lan_leave_confirm()
		"lan_leave_confirm":
			_show_lan_match_controls()
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
	ForestArenaAudio.finish_match("draw" if match_controller.is_draw else ("victory" if player_won else "defeat"))
	_new_page("무승부" if match_controller.is_draw else ("승리!" if player_won else "패배"), false)
	_button("같은 조건으로 재대전", start_match)
	_button("대전 준비", func() -> void:
		_close_match()
		_show_prepare())
	_button("로비", func() -> void:
		_close_match()
		_show_home())


func _on_presentation_event(event_id: StringName, _payload: Dictionary) -> void:
	if event_id not in [&"hit_resolved", &"ring_out", &"match_end", &"match_draw"] or not bool(store.data.accessibility.haptics_enabled): return
	haptic_request_count += 1
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(18 if event_id == &"hit_resolved" else 45, 0.35)


func _text_scale() -> float:
	return float(store.data.get("accessibility", LocalPlayerStore.default_accessibility()).get("text_scale", 1.0)) if store != null else 1.0

func _close_match() -> void:
	ForestArenaAudio.stop_effects("Combat")
	ForestArenaAudio.set_match_paused(false)
	if is_instance_valid(match_scene):
		match_scene._release_semantic_actions()
		match_scene.get_node("Interface/TouchCommandSource").release_all_touches()
		remove_child(match_scene)
		match_scene.queue_free()
	match_scene = null
	match_controller = null

func _show_db_connection() -> void:
	screen = "db_connection"
	_new_page("저장 모드")
	_label("기기 저장 또는 개발용 로컬 DB를 선택하세요. DB가 비어 있으면 기기 저장을 한 번 이전합니다.", 18)
	_line_input("http://127.0.0.1:3000", db_address, func(value: String) -> void: db_address = value)
	_button("로컬 DB 연결", func() -> void: await _connect_db(false))
	if db_client.session_invalid:
		_label("이전 게스트 세션을 복구할 수 없습니다. 새 게스트는 이전 DB 기록과 별도로 시작합니다.", 18)
		_button("새 게스트 시작 안내", func() -> void:
			_new_page("새 DB 게스트")
			_label("새 게스트에 현재 기기 저장을 이전합니다. 이전 DB 기록은 삭제하지 않습니다.")
			_button("새 게스트로 연결", func() -> void: await _connect_db(true))
			_button("취소", _show_db_connection))
	_button("기기 저장 사용", func() -> void:
		if not db_client.choose_device_mode():
			message = _db_error("session_save_failed")
			_show_db_connection()
			return
		db_mode = false
		store = LocalPlayerStore.new(catalog, save_path)
		if store.load_profile(): _show_home() if store.data.first_granted else _show_first()
		else: _show_storage_error())
	if db_mode and db_client.connected: _button("로비", _show_home if store.data.first_granted else _show_first)

func _busy_overlay() -> Control:
	storage_busy = true
	get_viewport().gui_release_focus()
	var overlay := ColorRect.new()
	overlay.color = Color(0.03, 0.1, 0.08, 0.9)
	layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.text = "로컬 DB 확인 중…"
	label.position = Vector2(400, 300)
	overlay.add_child(label)
	return overlay

func _connect_db(new_guest: bool) -> void:
	if storage_busy: return
	var overlay := _busy_overlay()
	var local := LocalPlayerStore.new(catalog, save_path)
	if not local.load_profile_read_only(): local.data = {}
	var ok := await db_client.connect_profile(db_address, local, new_guest)
	overlay.queue_free()
	storage_busy = false
	if ok:
		db_mode = true
		store.data = local.data.duplicate(true)
		message = "로컬 DB 연결 완료 · 게스트 " + db_client.player_id.left(8)
		_show_home() if store.data.first_granted else _show_first()
	else:
		message = _db_error(db_client.error)
		_show_db_connection()

func _change_profile(action: String, payload: Dictionary) -> bool:
	if storage_busy: return false
	if not db_mode:
		var local_ok := false
		match action:
			"grant_first": local_ok = store.grant_first(payload.id)
			"purchase": local_ok = store.purchase(payload.id)
			"select": local_ok = store.select(payload.character, payload.accessory, payload.opponent)
			"accessibility": local_ok = store.update_accessibility(payload.text_scale, payload.reduce_visual_effects, payload.haptics_enabled)
			"identity": local_ok = store.update_identity(payload.nickname)
			"minimap": local_ok = store.update_minimap(payload)
		ForestArenaAudio.play_event(&"ui_confirm" if local_ok else &"ui_error", {})
		return local_ok
	var overlay := _busy_overlay()
	var ok := await db_client.change(action, payload, store)
	overlay.queue_free()
	storage_busy = false
	store.error = "" if ok else _db_error(db_client.error)
	if not ok: message = store.error
	ForestArenaAudio.play_event(&"ui_confirm" if ok else &"ui_error", {})
	return ok


func _retry_db() -> void:
	if storage_busy: return
	var previous_screen := screen
	var overlay := _busy_overlay()
	var ok := await db_client.retry(store)
	overlay.queue_free()
	storage_busy = false
	message = "DB 저장 확인 완료" if ok else _db_error(db_client.error)
	match previous_screen:
		"shop": _show_shop()
		"prepare": _show_prepare()
		"accessibility": _show_accessibility()
		"lan_host": _show_lan_host()
		"lan_join": _show_lan_join()
		_: _show_home() if store.data.first_granted else _show_first()

func _db_error(code: String) -> String:
	match code:
		"revision_conflict": return "다른 실행에서 변경된 최신 DB 정보를 읽었습니다. 원하는 변경을 다시 선택하세요."
		"session_invalid", "invalid_refresh_token": return "게스트 세션을 복구할 수 없습니다. 저장 모드 화면에서 확인하세요."
		"session_endpoint_mismatch": return "이 게스트는 다른 API 주소에 저장됐습니다. 기존 주소로 연결하세요."
		"invalid_local_profile": return "기기 저장을 읽을 수 없어 이전하지 못했습니다. 기기 저장을 복구한 뒤 다시 연결하세요."
		"session_save_failed": return "게스트 세션을 기기에 저장하지 못했습니다. 저장 공간을 확인하세요."
		"pending_retry_required": return "이전 DB 저장 요청을 먼저 재시도하세요."
		_: return "DB 연결 또는 저장에 실패했습니다. 서버와 주소를 확인하고 다시 시도하세요. (%s)" % code

func _show_storage_error() -> void:
	if db_mode:
		_show_db_connection()
		return
	screen = "storage_error"
	_new_page("저장 확인 필요")
	_label(store.error)
	if not demo_mode: _button("로컬 DB 연결", _show_db_connection)
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


func _save_audio_levels(music: float, effects: float, muted: bool) -> void:
	if ForestArenaAudio.set_levels(music, effects, muted) != OK:
		message = "소리 설정을 저장하지 못했습니다. 현재 실행 중에는 적용됩니다."
		ForestArenaAudio.play_event(&"ui_error", {})


func _audio_slider(title: String, value: float, is_music: bool) -> void:
	var row := HBoxContainer.new()
	body.add_child(row)
	var label := Label.new()
	label.text = title + " " + str(roundi(value * 100.0)) + "%"
	label.custom_minimum_size.x = 230
	row.add_child(label)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(320, 58)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	slider.value_changed.connect(func(level: float) -> void:
		label.text = title + " " + str(roundi(level * 100.0)) + "%"
		_save_audio_levels(level if is_music else ForestArenaAudio.music_level, ForestArenaAudio.effects_level if is_music else level, ForestArenaAudio.muted))
	slider.drag_ended.connect(func(changed: bool) -> void:
		if changed and not is_music: ForestArenaAudio.play_event(&"ui_select", {}))


func _exit_tree() -> void:
	if demo_guest != null: demo_guest.cancel()
	ForestArenaAudio.shutdown()
