extends Node
signal quality_changed(new_quality: String)
const VALID_QUALITIES := ["high", "medium", "low"]
const REGISTRY_PATH := "res://forest_arena/data/resource_registry.json"
const PROFILE_PATH := "res://forest_arena/data/quality_profiles.json"
const SETTINGS_PATH := "user://forest_arena_graphics.cfg"
var quality: String = "high"
var _by_id: Dictionary = {}
var profiles: Dictionary = {}
func _ready() -> void:
    _load_registry()
    _load_profiles()
    _load_saved_quality()
func _json(path: String) -> Dictionary:
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null: return {}
    var v = JSON.parse_string(f.get_as_text())
    return v if typeof(v) == TYPE_DICTIONARY else {}
func _load_registry() -> void:
    var r := _json(REGISTRY_PATH)
    for a in r.get("assets", []): _by_id[a.get("id", "")] = a
func _load_profiles() -> void: profiles = _json(PROFILE_PATH)
func _load_saved_quality() -> void:
    var c := ConfigFile.new()
    if c.load(SETTINGS_PATH) == OK: quality = str(c.get_value("graphics", "quality", "high"))
    if quality not in VALID_QUALITIES: quality = "high"
func set_quality(value: String) -> void:
    if value not in VALID_QUALITIES: return
    if value == quality: return
    quality = value
    var c := ConfigFile.new(); c.set_value("graphics", "quality", quality); c.save(SETTINGS_PATH)
    quality_changed.emit(quality)
func resource_path(id: String) -> String:
    var a: Dictionary = _by_id.get(id, {})
    if a.is_empty():
        push_warning("FOREST_ARENA_RESOURCE_MISSING id=%s reason=unknown-id" % id)
        return ""
    if a.get("quality_dependent", false): return str(a.get("variants", {}).get(quality, a.get("variants", {}).get("high", "")))
    return str(a.get("path", ""))
func load_texture(id: String) -> Texture2D:
    var p := resource_path(id)
    if p.is_empty(): return null
    var texture := load(p) as Texture2D
    if texture == null: push_warning("FOREST_ARENA_RESOURCE_MISSING id=%s path=%s reason=texture-load" % [id, p])
    return texture
func profile() -> Dictionary: return profiles.get(quality, {})
