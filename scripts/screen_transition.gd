class_name ScreenTransition
extends CanvasLayer
## A transparent input blocker starts immediately; the bar appears only after 150 ms.
signal failed
signal settled
const PREPARER = preload("res://scripts/ui_resource_preparer.gd")
const DELAY_MSEC := 150
var preparer: UiResourcePreparer
var busy := false
var committing := false
var generation := 0
var overlay: Control
var panel: VBoxContainer
var bar: ProgressBar
var caption: Label
var actions: HBoxContainer
var started_msec := 0
var prepare_override: Callable
var _retry: Callable
var _back: Callable

func _ready() -> void:
	layer = 100
	preparer = PREPARER.new()
	add_child(preparer)
	overlay = ColorRect.new()
	overlay.name = "ScreenLoadingOverlay"
	(overlay as ColorRect).color = Color(0.025, 0.07, 0.055, 0.78)
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = VBoxContainer.new()
	overlay.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -240
	panel.offset_right = 240
	panel.offset_top = -42
	panel.offset_bottom = 90
	caption = Label.new()
	caption.text = "화면 준비 중…"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 24)
	panel.add_child(caption)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(480, 18)
	bar.show_percentage = false
	bar.max_value = 1.0
	panel.add_child(bar)
	actions = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(actions)
	for label: String in ["다시 시도", "이전 화면"]:
		var button := Button.new()
		button.text = label
		button.custom_minimum_size = Vector2(180, 58)
		actions.add_child(button)
		button.pressed.connect(func() -> void:
			var callback := _retry if label == "다시 시도" else _back
			cancel()
			if callback.is_valid(): callback.call())
	preparer.progress_changed.connect(func(value: float) -> void:
		bar.indeterminate = false
		bar.value = value)
	overlay.hide()
	set_process(false)

func _process(_delta: float) -> void:
	if busy and Time.get_ticks_msec() - started_msec >= DELAY_MSEC:
		overlay.modulate.a = 1.0
		panel.show()

func navigate(build: Callable, paths: Array[String] = [], back: Callable = Callable()) -> bool:
	if busy: return false
	busy = true
	get_viewport().gui_release_focus()
	generation += 1
	var ticket := generation
	started_msec = Time.get_ticks_msec()
	caption.text = "화면 준비 중…"
	bar.value = 0.0
	bar.indeterminate = true
	bar.show()
	actions.hide()
	panel.hide()
	overlay.modulate.a = 0.0
	overlay.show()
	set_process(true)
	_retry = func() -> void: navigate(build, paths, back)
	_back = back
	var ok: bool = await prepare_override.call(paths) if prepare_override.is_valid() else await preparer.prepare(paths)
	if ticket != generation or not is_inside_tree(): return false
	if not ok:
		caption.text = preparer.error if not preparer.error.is_empty() else "화면 준비에 실패했습니다. 다시 시도하세요."
		bar.hide()
		actions.show()
		(actions.get_child(1) as Button).disabled = not back.is_valid()
		panel.show()
		overlay.modulate.a = 1.0
		set_process(false)
		failed.emit()
		return false
	if Time.get_ticks_msec() - started_msec >= DELAY_MSEC:
		_process(0.0)
		await get_tree().process_frame
		if ticket != generation: return false
	committing = true
	await build.call()
	committing = false
	# Keep input blocked until the new controls have completed layout.
	await get_tree().process_frame
	if ticket != generation: return false
	busy = false
	overlay.hide()
	set_process(false)
	settled.emit()
	return true

func cancel() -> void:
	generation += 1
	preparer.cancel()
	busy = false
	committing = false
	overlay.hide()
	set_process(false)


func _input(_event: InputEvent) -> void:
	if busy and not actions.visible: get_viewport().set_input_as_handled()
