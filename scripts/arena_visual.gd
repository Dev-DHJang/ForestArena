extends Node2D

const BACKGROUND_ID := "fa.background.combat.training.arena"

@onready var background: TextureRect = $Background
var _missing_background_id := ""
var _event_flash_ticks := 0
var _last_event: StringName


func _ready() -> void:
	ForestArenaResources.quality_changed.connect(_on_quality_changed)
	_apply_background()


func _on_quality_changed(_new_quality: String) -> void:
	_apply_background()


## Presentation only: this consumer never feeds position, hit timing or outcome
## back into fixed-tick combat authority.
func play_combat_event(event_id: StringName, _payload: Dictionary) -> void:
	_last_event = event_id
	_event_flash_ticks = 4 if event_id == &"hit_resolved" else 0
	queue_redraw()


func _process(_delta: float) -> void:
	if _event_flash_ticks <= 0: return
	_event_flash_ticks -= 1
	queue_redraw()


func _apply_background() -> void:
	var texture := ForestArenaResources.load_texture(BACKGROUND_ID)
	if texture == null:
		_missing_background_id = BACKGROUND_ID
		background.texture = _fallback_texture()
	else:
		_missing_background_id = ""
		background.texture = texture
	queue_redraw()


func _fallback_texture() -> Texture2D:
	var image := Image.create_empty(16, 9, false, Image.FORMAT_RGBA8)
	image.fill(Color("a22654"))
	return ImageTexture.create_from_image(image)


func _draw() -> void:
	# Authoritative collision geometry remains represented independently of the backdrop.
	draw_rect(Rect2(100, 586, 1080, 48), Color("365f4b"))
	draw_rect(Rect2(500, 418, 280, 24), Color("4e8062"))
	draw_dashed_line(Vector2(80, 660), Vector2(1200, 660), Color("e96969"), 4.0, 14.0)
	draw_string(ThemeDB.fallback_font, Vector2(92, 694), "RING-OUT BOUNDARY (PHASE 1)", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color("f39b9b"))
	if not _missing_background_id.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(360, 230), "MISSING RESOURCE: %s" % _missing_background_id, HORIZONTAL_ALIGNMENT_CENTER, 560.0, 24, Color.WHITE)
	if _event_flash_ticks > 0:
		draw_rect(Rect2(0, 0, 1280, 720), Color(1.0, 1.0, 1.0, 0.08), true)
