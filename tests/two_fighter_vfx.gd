extends SceneTree
## Presentation-only guarantees at real attack phase boundaries and interruption.
const Presentation := preload("res://scripts/local_fighter_presentation.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if not value: failures.append(label)
func run() -> void:
	var material_path: String = root.get_node("ForestArenaResources").resource_path(Presentation.AttackEffects.SCARF_TEXTURE_ID)
	check(FileAccess.get_sha256(material_path)=="a4dcff0f9fdeb592ee86a209603c5dc97ca059f2a461b7f61576b1acf3ce3311","scarf UVs stay bound to the actual approved worn scarf artwork")
	for cid: StringName in [&"ja-hyun",&"nabi"]:
		var fighter := FighterController.new()
		fighter.fighter_id = StringName("vfx-"+String(cid))
		fighter.character_data = load("res://assets/character/%s/character.tres" % cid)
		root.add_child(fighter)
		fighter.set_physics_process(false)
		var selection := LoadoutSelection.new()
		selection.character_id = cid
		check(fighter.configure_profile(LoadoutBuilder.build(selection,LocalPlayCatalog.new().combat).profile),"profile")
		var visual := Presentation.new()
		fighter.add_child(visual)
		visual.set_process(false)
		var effect := visual.get_node("AttackReachEffects")
		check(effect.sprite == visual.sprite,"cloth attachment uses the actual displayed sprite/pivot")
		for attack: AttackData in fighter.runtime_profile.move_set.attacks():
			fighter.active_attack=attack
			for facing: int in [-1,1]:
				fighter.facing=facing
				for state: int in [FighterController.State.ATTACK_STARTUP,FighterController.State.ATTACK_ACTIVE,FighterController.State.ATTACK_RECOVERY]:
					fighter.state=state
					for tick: int in [0,1,3,6,7,20]:
						fighter.attack_phase_tick=tick
						var before := fighter.snapshot()
						visual.sync_visual(0)
						var envelope: Vector2 = effect.effect_envelope()
						check(envelope.y>=0 and envelope.y<=1,"effect opacity stays bounded")
						if state == FighterController.State.ATTACK_RECOVERY and tick>=7: check(envelope.y==0,"recovery trail expires within seven ticks")
						check(before==fighter.snapshot(),"drawing never changes simulation or resources")
			fighter.state=FighterController.State.HITSTUN
			check(effect.effect_envelope()==Vector2.ZERO,"hit interruption clears the attack effect immediately")
			fighter.active_attack=null
			check(effect.effect_envelope()==Vector2.ZERO,"ended attack cannot leave a stale trail")
		fighter.free()
	for failure: String in failures: push_error(failure)
	print("TWO_FIGHTER_VFX: "+("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
