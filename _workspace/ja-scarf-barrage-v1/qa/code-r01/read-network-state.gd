extends SceneTree
const Presentation := preload("res://scripts/local_fighter_presentation.gd")
var errors: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks += 1
 if not ok: errors.append(label)
func observe(v: Node, f: FighterController) -> void:
 var before := f.snapshot()
 v.sync_visual(0.0)
 check(before==f.snapshot(),"snapshot read only")
func run() -> void:
 var catalog := LocalPlayCatalog.new().combat
 var fighter := FighterController.new()
 fighter.character_data=catalog.character_by_id(&"ja-hyun")
 fighter.fighter_id=&"review"
 root.add_child(fighter)
 var selection := LoadoutSelection.new()
 selection.character_id=&"ja-hyun"
 fighter.configure_profile(LoadoutBuilder.build(selection,catalog).profile)
 fighter.set_physics_process(false)
 var v := Presentation.new()
 fighter.add_child(v)
 v.set_process(false)
 fighter.apply_network_snapshot({"state":"RING_OUT","stocks":2,"respawn_ticks":30})
 observe(v,fighter)
 fighter.apply_network_snapshot({"state":"IDLE","stocks":2,"respawn_ticks":0,"invulnerability_ticks":120})
 observe(v,fighter)
 check(v.requested_motion==&"spawn","LAN RING_OUT to IDLE shows spawn")
 var attack: AttackData=fighter.runtime_profile.move_set.attacks()[0]
 fighter.apply_network_snapshot({"state":"ATTACK_STARTUP","stocks":2,"attack_id":String(attack.attack_id),"attack_phase_tick":0})
 observe(v,fighter)
 check(v.requested_motion==attack.visual_state_id and v._spawn_elapsed<0,"network attack overrides spawn immediately")
 fighter.apply_network_snapshot({"state":"RING_OUT","stocks":1,"attack_id":""})
 observe(v,fighter)
 fighter.apply_network_snapshot({"state":"IDLE","stocks":1})
 observe(v,fighter)
 fighter.apply_network_snapshot({"state":"RUN","stocks":1})
 observe(v,fighter)
 check(v.requested_motion==&"run" and v._spawn_elapsed<0,"network movement overrides spawn immediately")
 for stocks: int in [0,1]:
  fighter.apply_network_snapshot({"state":"MATCH_ENDED","stocks":stocks,"attack_id":String(attack.attack_id),"attack_phase_tick":3,"invulnerability_ticks":120})
  observe(v,fighter)
  check(v.requested_motion==(&"death" if stocks==0 else &"idle"),"ended state ignores retained attack")
  check(v.sprite.modulate==Color.WHITE,"ended state clears shield alpha")
  check(v.effects.effect_envelope()==Vector2.ZERO,"ended state produces no attack VFX")
 fighter.apply_network_snapshot({"state":"RING_OUT","stocks":1,"attack_id":""})
 observe(v,fighter)
 fighter.apply_network_snapshot({"state":"IDLE","stocks":1})
 observe(v,fighter)
 selection.character_id=&"nabi"
 fighter.character_data=catalog.character_by_id(&"nabi")
 fighter.configure_profile(LoadoutBuilder.build(selection,catalog).profile)
 fighter.set_physics_process(false)
 observe(v,fighter)
 check(v.character_id==&"nabi" and v.requested_motion==&"idle" and v._spawn_elapsed<0,"different character profile discards the old spawn timer")
 print("LAN_VISUAL_BOUNDARIES: ",checks," checks; errors=",errors)
 fighter.free()
 quit(0 if errors.is_empty() else 1)
