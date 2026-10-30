class_name AccessoryAbilityData
extends Resource

## Data-owned active equipment. Presentation never supplies collision or timing.
@export var ability_id: StringName
@export var texture_id: StringName
@export var cooldown_ticks := 600
@export var startup_ticks := 6
@export var extend_ticks := 18
@export var return_ticks := 18
@export var recovery_ticks := 6
@export var reach := 180.0
@export var hitbox_size := Vector2(28, 28)
@export var origin_offset := Vector2(24, -32)
@export var stun_ticks := 30
@export var tags: Array[StringName] = [&"PROJECTILE"]
@export var ground_motion_id: StringName
@export var air_motion_id: StringName


func is_valid_definition() -> bool:
	return not ability_id.is_empty() and not texture_id.is_empty() and cooldown_ticks > 0 and startup_ticks > 0 and extend_ticks > 0 and return_ticks > 0 and recovery_ticks > 0 and is_finite(reach) and reach > 0.0 and hitbox_size.is_finite() and hitbox_size.x > 0.0 and hitbox_size.y > 0.0 and origin_offset.is_finite() and stun_ticks > 0 and not ground_motion_id.is_empty() and not air_motion_id.is_empty() and not tags.is_empty() and tags.all(func(tag: StringName) -> bool: return AttackData.VALID_TAGS.has(tag))


func total_ticks() -> int:
	return startup_ticks + extend_ticks + return_ticks + recovery_ticks
