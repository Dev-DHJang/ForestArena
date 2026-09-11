class_name Phase3DebugMatchConfig
extends Resource

## Editor/debug-only fighter pairing. It intentionally does not represent a
## player selection, saved loadout, or release UI state.
@export var player_fighter_scene: PackedScene
@export var training_dummy_fighter_scene: PackedScene


func is_valid_definition() -> bool:
	return player_fighter_scene != null and training_dummy_fighter_scene != null
