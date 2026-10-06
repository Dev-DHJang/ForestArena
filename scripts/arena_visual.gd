extends Node2D

@onready var background: TextureRect = $Background
@onready var terrain: TextureRect = $Terrain
@export var stage_data: StageData
var _missing_background_id := ""
var _event_flash_ticks := 0
var _last_event: StringName
var reduce_visual_effects := false


func _ready() -> void:
	ForestArenaResources.quality_changed.connect(_on_quality_changed)
	_apply_background()


func _on_quality_changed(_new_quality: String) -> void:
	_apply_background()


## Presentation only: this consumer never feeds position, hit timing or outcome
## back into fixed-tick combat authority.
func play_combat_event(event_id: StringName, _payload: Dictionary) -> void:
	_last_event = event_id
	_event_flash_ticks = 0 if reduce_visual_effects else (4 if event_id == &"hit_resolved" else 0)
	queue_redraw()


func apply_accessibility(settings: Dictionary) -> void:
	reduce_visual_effects = bool(settings.get("reduce_visual_effects", false))
	if reduce_visual_effects: _event_flash_ticks = 0


func _process(_delta: float) -> void:
	if _event_flash_ticks <= 0: return
	_event_flash_ticks -= 1
	queue_redraw()


func _apply_background() -> void:
	if stage_data == null or not stage_data.is_valid_definition():
		_missing_background_id = "invalid-stage-data"
		background.texture = _fallback_texture()
		terrain.visible = false
		queue_redraw()
		return
	var texture := ForestArenaResources.load_texture(stage_data.background_asset_id)
	if texture == null:
		_missing_background_id = stage_data.background_asset_id
		background.texture = _fallback_texture()
	else:
		_missing_background_id = ""
		background.texture = texture
	# The expanded collision layout intentionally uses exact temporary geometry.
	# Keep the approved two-piece image untouched until replacement art is approved.
	terrain.texture = null
	terrain.visible = false
	queue_redraw()


func _fallback_texture() -> Texture2D:
	var image := Image.create_empty(16, 9, false, Image.FORMAT_RGBA8)
	image.fill(Color("a22654"))
	return ImageTexture.create_from_image(image)


func _draw() -> void:
	# StageData owns both these temporary walk surfaces and their collision peers.
	if stage_data != null:
		for surface: StageSurfaceData in stage_data.surfaces:
			var fill := Color("4e8062") if surface.one_way else Color("365f4b")
			draw_rect(surface.rect, fill, true)
			draw_line(surface.rect.position, Vector2(surface.rect.end.x, surface.rect.position.y), Color("a9d86e"), 5.0)
	if not _missing_background_id.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(360, 230), "MISSING RESOURCE: %s" % _missing_background_id, HORIZONTAL_ALIGNMENT_CENTER, 560.0, 24, Color.WHITE)
	if _event_flash_ticks > 0:
		draw_rect(Rect2(0, 0, 1280, 720), Color(1.0, 1.0, 1.0, 0.08), true)
