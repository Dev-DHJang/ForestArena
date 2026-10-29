extends "res://tools/forest_arena/motion_review_timeline.gd"
## Audit-only extension: observe the real presentation transform and effect inputs.
func _sample(presentation: Node2D, fighter: FighterController, delta: float, phase: String) -> Dictionary:
	var result := super._sample(presentation, fighter, delta, phase)
	var sprite: AnimatedSprite2D = presentation.sprite
	result["sprite_scale"] = [sprite.scale.x, sprite.scale.y]
	result["sprite_position"] = [sprite.position.x, sprite.position.y]
	result["sprite_offset"] = [sprite.offset.x, sprite.offset.y]
	result["state"] = fighter.state
	result["phase_tick"] = fighter.attack_phase_tick
	result["attack_strike_ready"] = fighter.attack_strike_ready
	if fighter.active_attack != null:
		var attack := fighter.active_attack
		result["effect_attack"] = {"schema_version":attack.schema_version,"attack_id":String(attack.attack_id),"visual_state_id":String(attack.visual_state_id),"action_id":String(attack.action_id),"activation_context":attack.activation_context,"startup_ticks":attack.startup_ticks,"active_ticks":attack.active_ticks,"recovery_ticks":attack.recovery_ticks,"hitbox_offset":[attack.hitbox_offset.x,attack.hitbox_offset.y],"hitbox_size":[attack.hitbox_size.x,attack.hitbox_size.y]}
	return result
