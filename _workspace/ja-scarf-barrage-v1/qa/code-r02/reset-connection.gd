extends SceneTree
const Presentation := preload("res://scripts/local_fighter_presentation.gd")
var checks := 0
var errors: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks += 1
 if not ok: errors.append(label)
func run() -> void:
 var catalog := LocalPlayCatalog.new().combat
 var fighter := FighterController.new()
 fighter.character_data=catalog.character_by_id(&"ja-hyun")
 fighter.fighter_id=&"connection-review"
 root.add_child(fighter)
 var selection := LoadoutSelection.new()
 selection.character_id=&"ja-hyun"
 fighter.configure_profile(LoadoutBuilder.build(selection,catalog).profile)
 fighter.set_physics_process(false)
 var visual := Presentation.new()
 fighter.add_child(visual)
 visual.set_process(false)
 check(fighter.presentation_reset.get_connections().size()==1,"one local playback reset listener")
 visual._spawn_elapsed=0.4
 var snapshot_before:=fighter.snapshot()
 fighter.presentation_reset.emit()
 check(fighter.snapshot()==snapshot_before,"reset callback leaves complete combat snapshot unchanged")
 check(visual._spawn_elapsed<0 and visual._last_motion==&"","local reset clears previous playback")
 visual._spawn_elapsed=0.4
 check(not fighter.configure_profile(null),"invalid profile is refused")
 check(visual._spawn_elapsed==0.4,"failed configuration never resets valid current playback")
 var weak: WeakRef = weakref(visual)
 visual.free()
 check(weak.get_ref()==null,"freed presentation is not retained by fighter signal")
 check(fighter.presentation_reset.get_connections().is_empty(),"freed presentation disconnects its callback")
 fighter.configure_profile(LoadoutBuilder.build(selection,catalog).profile)
 fighter.set_physics_process(false)
 var replacement := Presentation.new()
 fighter.add_child(replacement)
 replacement.set_process(false)
 check(fighter.presentation_reset.get_connections().size()==1,"replacement presentation creates a single fresh listener")
 fighter.free()
 print("PRESENTATION_RESET_CONNECTION: ",checks," checks; errors=",errors)
 quit(0 if errors.is_empty() else 1)
