extends SceneTree
const Presentation := preload("res://scripts/local_fighter_presentation.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var catalog := LocalPlayCatalog.new().combat
 var rules := load("res://assets/combat/two_fighter_combat_rules.tres") as CombatRules
 var fighter := FighterController.new()
 fighter.character_data = catalog.character_by_id(&"ja-hyun")
 fighter.fighter_id = &"review-fighter"
 root.add_child(fighter)
 var selection := LoadoutSelection.new()
 selection.character_id = &"ja-hyun"
 fighter.configure_profile(LoadoutBuilder.build(selection,catalog).profile)
 fighter.set_physics_process(false)
 fighter.reset_for_match(rules)
 var visual := Presentation.new()
 fighter.add_child(visual)
 visual.set_process(false)
 fighter.stocks = 2
 fighter.ring_out(rules)
 visual.sync_visual(0.0)
 for tick: int in rules.respawn_delay_ticks:
  fighter.step_tick(rules)
  visual.sync_visual(1.0/60.0)
 visual.sync_visual(0.4)
 print("before reset: ", visual.requested_motion, " elapsed=",visual._spawn_elapsed," frame=",visual.sprite.frame)
 fighter.reset_for_match(rules)
 visual.sync_visual(0.0)
 print("after public reset_for_match: ", visual.requested_motion," elapsed=",visual._spawn_elapsed," frame=",visual.sprite.frame," state=",FighterController.State.keys()[fighter.state])
 fighter.configure_profile(LoadoutBuilder.build(selection,catalog).profile)
 fighter.set_physics_process(false)
 visual.sync_visual(0.0)
 print("after same-character profile reconfiguration: ",visual.requested_motion," elapsed=",visual._spawn_elapsed," frame=",visual.sprite.frame)
 fighter.free()
 quit()
