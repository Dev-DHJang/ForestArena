class_name PremiumMenuRouter
extends RefCounted

const VIEW = preload("res://scripts/premium_menu/premium_menu_view.gd")
const IDS := ["character_collection", "character_detail", "accessory_collection", "accessory_detail", "preset", "shop", "collection", "mission", "social", "rank", "profile", "settings", "controls"]
var app: Node
var state: Dictionary = {}
var view: Control
var busy := false
var _remembered: Dictionary = {}
var _history: Array[Dictionary] = []
var _draft: Dictionary = {}
var _baseline: Dictionary = {}
var _preset_draft: Dictionary = {}
var _preset_index := 0
var _loaded_owner := ""

func _init(owner: Node) -> void:
	app = owner

func reset() -> void:
	state = {}
	_history.clear()
	_remembered.clear()
	_draft = {}
	_baseline = {}
	_preset_draft = {}
	_loaded_owner = ""
	view = null
	busy = false

func open(menu_id: String, params: Dictionary = {}) -> void:
	if busy or menu_id not in IDS: return
	if not is_instance_valid(view) or app.page != view:
		state = {}
		_history.clear()
	if not state.is_empty():
		_remembered[state.id] = state.duplicate(true)
		if state.id != menu_id and not params.get("replace", false): _history.append(state.duplicate(true))
	var next: Dictionary = _remembered.get(menu_id, {}).duplicate(true)
	var context: String = String(state.get("entry_context", "lobby"))
	next.merge({"id": menu_id, "filter": "전체", "tab": "기술", "category": "전체", "scroll": 0, "entry_context": context}, false)
	next.merge(params, true)
	next.id = menu_id
	next.erase("replace")
	if not params.has("preset_edit"): next.erase("preset_edit")
	state = next
	_load_local()
	if menu_id in ["settings", "controls"]: _begin_settings()
	_rebuild()

func _load_local() -> void:
	var owner: String = app._menu_owner_key()
	if owner != _loaded_owner:
		var errors: Array[String] = []
		if not app.menu_store.load_presets(owner, {"character": app.store.data.selected_character, "accessory": app.store.data.selected_accessory}): errors.append(app.menu_store.error)
		if not app.menu_store.load_controls(): errors.append(app.menu_store.error)
		state.local_load_error = not errors.is_empty()
		if errors.is_empty(): _loaded_owner = owner
		else: state.message = " / ".join(errors)
		_preset_index = app.menu_store.selected_slot if errors.is_empty() else 0
		_preset_draft = app.menu_store.slots[_preset_index].duplicate(true) if errors.is_empty() else {}
	else:
		if state.get("local_load_error", false): state.message = ""
		state.local_load_error = false

func _rebuild() -> void:
	if state.is_empty(): return
	view = VIEW.new()
	view.build(app, state, _draft, _preset_draft, _preset_index)
	view.action.connect(_on_action)
	app._display_premium_view(view, String(state.id))
	view.modulate.a = 0.0
	busy = true
	var transition := view.create_tween()
	transition.tween_property(view, "modulate:a", 1.0, 0.2)
	transition.finished.connect(func() -> void: busy = false)

func handle_back() -> bool:
	if state.is_empty(): return false
	if busy: return true
	if is_instance_valid(view) and view.close_modal(): return true
	if _dirty():
		view.confirm("변경한 설정을 버릴까요?", "적용하지 않은 변경은 저장되지 않습니다.", "버리고 돌아가기", func() -> void:
			_draft = _baseline.duplicate(true)
			_go_back())
		return true
	_go_back()
	return true

func _go_back() -> void:
	var context: String = String(state.get("entry_context", "lobby"))
	if not _history.is_empty():
		state = _history.pop_back()
		_load_local()
		if state.id in ["settings", "controls"]: _begin_settings()
		_rebuild()
		return
	state = {}
	view = null
	if context == "pause": app.pause_match()
	elif context == "prepare": app._show_prepare()
	else: app._show_home()

func _on_action(action_id: String, payload: Dictionary = {}) -> void:
	if busy or app.storage_busy: return
	if state.get("local_load_error", false) and (action_id.begins_with("preset_") or (action_id == "select" and state.get("preset_edit", false))):
		view.confirm("편성을 불러오지 못했습니다", "메뉴 저장을 다시 읽은 뒤 편성을 변경하거나 적용할 수 있습니다.", "다시 읽기", _retry_local)
		return
	match action_id:
		"back": handle_back()
		"open":
			if _dirty():
				view.confirm("변경한 설정을 버릴까요?", "적용하지 않은 변경은 저장되지 않습니다.", "메뉴 이동", func() -> void:
					_draft = _baseline.duplicate(true)
					open(payload.id, payload.get("params", {})))
			else: open(payload.id, payload.get("params", {}))
		"update":
			state.merge(payload, true)
			_rebuild()
		"select": await _select(String(payload.id))
		"purchase": await _purchase(String(payload.id))
		"nickname": await _nickname(String(payload.value))
		"retry_db": app._retry_db()
		"retry_local": _retry_local()
		"practice":
			if await _select(String(state.selected_id), false):
				state = {}
				_history.clear()
				app.selected_mode = LocalMatchConfig.Mode.PRACTICE
				app.start_match()
		"preset_slot":
			_preset_index = int(payload.index)
			_preset_draft = app.menu_store.slots[_preset_index].duplicate(true)
			_rebuild()
		"preset_edit": open(payload.id, {"preset_edit": true, "selected_id": _preset_draft.get("character" if payload.id == "character_collection" else "accessory", "")})
		"preset_clear_accessory":
			_preset_draft.accessory = ""
			_rebuild()
		"preset_save":
			if _valid_preset(_preset_draft):
				var ok: bool = app.menu_store.save_slot(_preset_index, _preset_draft.character, _preset_draft.get("accessory", ""))
				state.message = "프리셋을 저장했습니다." if ok else app.menu_store.error
			else: state.message = "보유한 캐릭터와 장신구를 먼저 선택하세요."
			_rebuild()
		"preset_apply": await _apply_preset()
		"category": _category(String(payload.value))
		"draft":
			_draft.merge(payload, true)
			if is_instance_valid(view): view.update_preview(_draft)
		"settings_apply": await _apply_settings()
		"settings_cancel":
			_draft = _baseline.duplicate(true)
			_rebuild()
		"settings_reset":
			view.confirm("기본값으로 복원할까요?", "적용을 누르면 현재 분류의 기본 설정을 저장합니다.", "기본값 복원", func() -> void:
				_reset_draft()
				_rebuild())

func _retry_local() -> void:
	_loaded_owner = ""
	state.message = ""
	_load_local()
	if state.id in ["settings", "controls"]: _begin_settings()
	_rebuild()

func _select(id: String, redraw := true) -> bool:
	var item: Dictionary = app.catalog.product(id)
	if item.is_empty() or not app.store.owns(id):
		if redraw: view.confirm("아직 보유하지 않았습니다", "상점에서 0원 무료 구매 후 선택할 수 있습니다.", "상점으로", func() -> void: open("shop", {"category": item.get("kind", "전체")}))
		return false
	if state.get("preset_edit", false):
		_preset_draft["character" if item.kind == "character" else "accessory"] = id
		while not _history.is_empty() and _history.back().id != "preset": _history.pop_back()
		if not _history.is_empty(): state = _history.pop_back()
		else: state = {"id": "preset", "entry_context": state.get("entry_context", "lobby")}
		_rebuild()
		return true
	var character: String = id if item.kind == "character" else String(app.store.data.selected_character)
	var accessory: String = id if item.kind == "accessory" else String(app.store.data.selected_accessory)
	busy = true
	var ok: bool = await app._change_profile("select", {"character": character, "accessory": accessory, "opponent": app.store.data.opponent_character})
	busy = false
	state.message = "편성에 적용했습니다." if ok else app.store.error
	if redraw: _rebuild()
	return ok

func _purchase(id: String) -> void:
	if app.store.owns(id): return
	busy = true
	var ok: bool = await app._change_profile("purchase", {"id": id})
	busy = false
	state.message = "무료 구매 완료 · 보유 목록에 추가했습니다." if ok else app.store.error
	_rebuild()

func _nickname(value: String) -> void:
	busy = true
	var ok: bool = await app._change_profile("identity", {"nickname": value.strip_edges()})
	busy = false
	state.message = "닉네임을 저장했습니다." if ok else (app.store.error if not app.store.error.is_empty() else "닉네임은 1~12자로 입력하세요.")
	_rebuild()

func _valid_preset(value: Dictionary) -> bool:
	var character: String = String(value.get("character", ""))
	var accessory: String = String(value.get("accessory", ""))
	return app.catalog.contains(character, "character") and app.store.owns(character) and (accessory.is_empty() or (app.catalog.contains(accessory, "accessory") and app.store.owns(accessory)))

func _apply_preset() -> void:
	if not _valid_preset(_preset_draft):
		view.confirm("선택이 필요합니다", "보유한 캐릭터와 장신구로 편성을 완성하세요.", "확인", func() -> void: pass)
		return
	busy = true
	var ok: bool = await app._change_profile("select", {"character": _preset_draft.character, "accessory": _preset_draft.get("accessory", ""), "opponent": app.store.data.opponent_character})
	busy = false
	if ok:
		if not app.menu_store.save_slot(_preset_index, _preset_draft.character, _preset_draft.get("accessory", "")) or not app.menu_store.set_active_slot(_preset_index):
			state.message = "편성은 적용했지만 프리셋을 저장하지 못했습니다. " + app.menu_store.error
		else:
			state = {}
			_history.clear()
			app._show_prepare()
			return
	else: state.message = app.store.error
	_rebuild()

func _settings_category() -> String:
	return "controls" if state.id == "controls" else String(state.get("category", "sound"))

func _begin_settings() -> void:
	if state.id == "settings" and state.get("category", "전체") == "전체": state.category = "sound"
	match _settings_category():
		"sound": _draft = {"music": ForestArenaAudio.music_level, "effects": ForestArenaAudio.effects_level, "muted": ForestArenaAudio.muted}
		"effects", "accessibility": _draft = app.store.data.accessibility.duplicate(true)
		"minimap": _draft = app.store.data.minimap.duplicate(true)
		"controls": _draft = app.menu_store.controls.duplicate(true)
	_baseline = _draft.duplicate(true)

func _dirty() -> bool:
	return state.get("id", "") in ["settings", "controls"] and _draft != _baseline

func _category(value: String) -> void:
	var switch := func() -> void:
		state.category = value
		_begin_settings()
		_rebuild()
	if _dirty(): view.confirm("변경한 설정을 버릴까요?", "분류를 바꾸면 적용하지 않은 변경은 사라집니다.", "분류 이동", switch)
	else: switch.call()

func _reset_draft() -> void:
	match _settings_category():
		"sound": _draft = {"music": 0.6, "effects": 0.8, "muted": false}
		"effects": _draft.reduce_visual_effects = false
		"accessibility":
			_draft.text_scale = 1.0
			_draft.haptics_enabled = true
		"minimap": _draft = LocalPlayerStore.default_minimap()
		"controls": _draft = {"joystick_mode": "fixed", "button_scale": 1.0, "button_transparency": 0}

func _apply_settings() -> void:
	busy = true
	var ok := false
	match _settings_category():
		"sound":
			ok = ForestArenaAudio.set_levels(float(_draft.music), float(_draft.effects), bool(_draft.muted)) == OK
			if not ok: ForestArenaAudio.set_levels(float(_baseline.music), float(_baseline.effects), bool(_baseline.muted), false)
		"effects", "accessibility": ok = await app._change_profile("accessibility", _draft)
		"minimap": ok = await app._change_profile("minimap", _draft)
		"controls":
			ok = app.menu_store.save_controls(_draft)
			if ok: app._apply_menu_control_settings()
	busy = false
	state.message = "설정을 적용했습니다." if ok else "설정을 저장하지 못했습니다. 다시 시도하세요."
	if ok: _baseline = _draft.duplicate(true)
	_rebuild()
