extends SceneTree
const Presentation := preload("res://scripts/local_fighter_presentation.gd")
class ObservedEffects extends "res://scripts/fighter_attack_effects.gd":
 var paths: Array[Dictionary] = []
 func _cloth(start: Vector2, control: Vector2, tip: Vector2, opacity: float, width_scale: float, wave_strength := 0.0, flat_end := false) -> void:
  paths.append({"start":start,"tip":tip})
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var catalog := LocalPlayCatalog.new().combat
 var fighter := FighterController.new()
 fighter.character_data=catalog.character_by_id(&"ja-hyun")
 fighter.fighter_id=&"heading-review"
 root.add_child(fighter)
 var selection := LoadoutSelection.new()
 selection.character_id=&"ja-hyun"
 fighter.configure_profile(LoadoutBuilder.build(selection,catalog).profile)
 fighter.set_physics_process(false)
 var moves := load("res://assets/combat/movesets/two_fighter_ja_hyun_moveset.tres") as MoveSetData
 for attack: AttackData in moves.attacks():
  if attack.action_id==&"attack_special": fighter.active_attack=attack
 fighter.state=FighterController.State.ATTACK_RECOVERY
 fighter.attack_phase_tick=0
 var sprite := AnimatedSprite2D.new()
 fighter.add_child(sprite)
 var frames := SpriteFrames.new()
 frames.remove_animation(&"default")
 frames.add_animation(fighter.active_attack.visual_state_id)
 var texture := GradientTexture2D.new()
 for i: int in 32: frames.add_frame(fighter.active_attack.visual_state_id,texture)
 sprite.sprite_frames=frames
 sprite.animation=fighter.active_attack.visual_state_id
 sprite.frame=27
 var effect := ObservedEffects.new()
 effect.fighter=fighter
 effect.sprite=sprite
 effect.phase_frame_ranges=[[0,4],[4,27],[27,32]]
 for i: int in 32: effect.frame_anchors.append({"scarf_root":[64,80],"scarf_hand":[72,72],"scarf_tips":[[72,110],null]})
 effect.frame_anchors[26]={}
 fighter.add_child(effect)
 var before := fighter.snapshot()
 effect._draw()
 print("EMPTY_LAST_ACTIVE_DRAW: paths=",effect.paths.size()," snapshot_unchanged=",before==fighter.snapshot())
 if not effect.paths.is_empty(): print("new_downward_recovery=",effect.paths[0].tip.y>effect.paths[0].start.y)
 fighter.free()
 quit()
