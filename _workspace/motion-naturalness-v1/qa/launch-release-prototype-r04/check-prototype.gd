extends SceneTree
const Prototype := preload("res://_workspace/motion-naturalness-v1/qa/launch-release-prototype-r04/presentation-prototype.gd")
const Baseline := preload("res://scripts/local_fighter_presentation.gd")
const Clock := preload("res://_workspace/motion-naturalness-v1/qa/launch-release-prototype-r04/release-clock.gd")
const DIR := "res://_workspace/motion-naturalness-v1/qa/launch-release-prototype-r04/"
var failures: Array[String] = []
var checks := 0
var traces: Array = []
var player: FighterController
var visual: Node
var baseline: Node
var controller: MatchController
var seq := 2000
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func protected_state() -> Dictionary:
	var buffered := {}
	if player.buffered_intent != null:
		for key: String in ["tick","fighter_id","action_id","direction","edge","context"]: buffered[key] = player.buffered_intent.get(key)
	return {"snapshot":player.snapshot(),"hitstun_ticks":player.hitstun_ticks,"input_direction":player.input_direction,"buffered_intent":buffered,"activation_serial":player.activation_serial,"launcher_jump_available":player.launcher_jump_available}
func observe(delta: float) -> void:
	var before := protected_state()
	visual.sync_visual(delta)
	check(before == protected_state(),"clone never mutates combat/internal stun/buffered inputs")
	baseline.sync_visual(delta)
	check(before == protected_state(),"baseline is read only")
func setup(optional: bool = true, facing: int = 1) -> void:
	player.reset_for_match(controller.rules)
	player.position = Vector2(600,250)
	player.velocity = Vector2(0,120)
	player.facing = facing
	player.hitstun_ticks = 0
	observe(0)
	var entry: Dictionary = visual._motion_layouts[&"launch"]
	entry.erase("launch_release_frame_range");entry.erase("launch_release_ticks")
	if optional:
		entry.launch_release_frame_range = [12,16]
		entry.launch_release_ticks = 4
	player.buffered_intent = CombatIntent.new(12,player.fighter_id,&"light",CombatIntent.Direction.RIGHT)
func remote(state_name: String, vy: float = 120.0) -> void:
	player.apply_network_snapshot({"state":state_name,"current_hp":100,"stocks":3,"velocity":{"x":0,"y":vy}})
func start_bridge(facing: int = 1) -> void:
	setup(true,facing)
	remote("LAUNCH",-100)
	observe(.35)
	check(visual.sprite.frame == 4,"LAN duration-free 12FPS reaches F5")
	check(player.hitstun_ticks == 0 and visual._reaction_duration_ticks == 0,"no absent LAN hitstun inferred")
	remote("FALL")
	observe(0)
	check(visual.requested_motion == &"launch" and visual.sprite.frame == 12,"actual FALL displays optional F13 bridge")
func inject_candidate(target: Node) -> void:
	var path := "res://_workspace/motion-naturalness-v1/remaining/ja-hyun/launch-neutral-r09/launch_neutral-r09.json"
	var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(FileAccess.get_sha256("res://"+String(entry.path))==entry.sha256,"candidate metadata binds the exact frozen artwork hash")
	var image := Image.load_from_file("res://"+String(entry.path))
	check(image != null and image.get_size()==Vector2i(2048,128),"frozen r09 image loads directly without rewriting/importing")
	var texture := ImageTexture.create_from_image(image)
	var frames := SpriteFrames.new();frames.remove_animation(&"default");frames.add_animation(&"launch");frames.set_animation_loop(&"launch",false);frames.set_animation_speed(&"launch",12)
	for index: int in 16:
		var tile := AtlasTexture.new();tile.atlas=texture;tile.region=Rect2(index*128,0,128,128);frames.add_frame(&"launch",tile)
	target._motions[&"launch"] = frames
	target._motion_layouts[&"launch"] = entry.duplicate(true)
func unit_metadata() -> void:
	var valid := {"sha256":"hash","launch_release_frame_range":[12,16],"launch_release_ticks":4}
	check(not Clock.validated(valid,16).is_empty(),"optional field pair accepts declared default")
	var bad: Array = [{},{"sha256":"hash","launch_release_frame_range":[12,16]},{"sha256":"hash","launch_release_ticks":4},{"sha256":"hash","launch_release_frame_range":[12],"launch_release_ticks":4},{"sha256":"hash","launch_release_frame_range":[-1,16],"launch_release_ticks":4},{"sha256":"hash","launch_release_frame_range":[12,17],"launch_release_ticks":5},{"sha256":"hash","launch_release_frame_range":[16,12],"launch_release_ticks":4},{"sha256":"hash","launch_release_frame_range":[12,12],"launch_release_ticks":4}]
	for ticks: Variant in [0,-1,13,3,4.5,"4",true,NAN,INF,1.0e100]:
		var x := valid.duplicate(true);x.launch_release_ticks=ticks;bad.append(x)
	for span: Variant in [[12.5,16],"12,16",[NAN,16],[12,INF],[true,16],[12,1.0e100],{},null]:
		var x := valid.duplicate(true);x.launch_release_frame_range=span;bad.append(x)
	for accepted: Dictionary in [{"sha256":"hash","launch_release_frame_range":[12.0,16.0],"launch_release_ticks":4.0},{"sha256":"hash","launch_release_frame_range":[12,16.0],"launch_release_ticks":4.0},JSON.parse_string(JSON.stringify(valid))]:
		var normalized := Clock.validated(accepted,16)
		check(not normalized.is_empty(),"finite integral int/float metadata accepted including JSON roundtrip")
		check(normalized.get("begin") is int and normalized.get("end") is int and normalized.get("ticks") is int,"accepted numeric values normalize to bounded ints")
	var no_hash := valid.duplicate(true);no_hash.sha256="";bad.append(no_hash)
	for value: Dictionary in bad: check(Clock.validated(value,16).is_empty(),"malformed/incomplete/out-of-range optional metadata rejected")
	for first: int in range(16):
		var clock := Clock.new()
		var launch := {"state":FighterController.State.LAUNCH,"attack":false,"activation":0,"air_jumps":1,"launcher_jump":false,"velocity_y":0}
		clock.select(launch,valid,16,0);clock.remember_actual_launch(first)
		var falling := launch.duplicate();falling.state=FighterController.State.FALL
		var selected := clock.select(falling,valid,16,0)
		check(selected == (maxi(12,first+1) if first<15 else -1),"start only not-yet-seen tail; final pose never repeats")
func run() -> void:
	unit_metadata()
	var scene: Node = load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	root.get_node("ForestArenaAudio").muted=true
	await physics_frame
	controller=scene.get_node("MatchController");controller.set_physics_process(false);player=controller.player;player.set_physics_process(false)
	var selection := LoadoutSelection.new();selection.character_id=&"ja-hyun"
	check(player.configure_profile(LoadoutBuilder.build(selection,LocalPlayCatalog.new().combat).profile),"real Ja-Hyun profile")
	visual=Prototype.new();baseline=Baseline.new();player.add_child(visual);player.add_child(baseline);visual.set_process(false);baseline.set_process(false)
	inject_candidate(visual);inject_candidate(baseline)
	# The actual candidate entry is saved and re-read, rather than injecting only ints.
	for facing: int in [1,-1]:
		setup(true,facing)
		var candidate_row: Dictionary = visual._motion_layouts[&"launch"].duplicate(true)
		var serialized_path := DIR+"roundtrip-entry-r04.json"
		var saved := FileAccess.open(serialized_path,FileAccess.WRITE);saved.store_string(JSON.stringify(candidate_row,"\t"));saved.close()
		var reloaded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(serialized_path))
		check(reloaded.launch_release_ticks is float and reloaded.launch_release_frame_range[0] is float,"real JSON file reload yields float metadata")
		check(reloaded.sha256==candidate_row.sha256 and FileAccess.get_sha256("res://"+String(reloaded.path))==reloaded.sha256,"roundtripped actual candidate row retains exact art hash")
		visual._motion_layouts[&"launch"] = reloaded
		remote("LAUNCH",-100);observe(.35);remote("FALL");observe(0)
		check(visual.release_clock.active and visual.sprite.frame==12,"actual JSON-reloaded optional row enables F13 release")
		for step: int in 4: observe(1.0/60.0)
		check(not visual.release_clock.active and visual.requested_motion==&"jump","actual JSON-reloaded release finishes at four ticks")
	for facing: int in [1,-1]:
		for fps: int in [30,60,120]:
			start_bridge(facing)
			var samples: Array = [{"elapsed":0,"frame":visual.sprite.frame,"motion":String(visual.requested_motion)}]
			var dt := 1.0/float(fps)
			for sample: int in range(1,ceilf(float(fps)*4.0/60.0)+2):
				observe(dt)
				var t := float(sample)/float(fps)
				samples.append({"elapsed":t,"frame":visual.sprite.frame,"motion":String(visual.requested_motion)})
				if t+0.000001 < 4.0/60.0:
					check(visual.requested_motion==&"launch" and visual.sprite.frame==mini(15,12+int(floor(t*60.0+0.000001))),"frame-rate independent release pose selection")
				else: check(visual.requested_motion==&"jump","release ends at four display ticks without prolonging FALL")
				check(visual.sprite.flip_h==(facing<0),"single facing transform preserved")
			traces.append({"facing":facing,"fps":fps,"samples":samples})
		# Actual state JUMP can also be the server's airborne continuation.
		setup(true,facing);remote("LAUNCH",-100);observe(.35);remote("JUMP",-40);observe(0)
		check(visual.release_clock.active,"LAUNCH to JUMP allowed without evidence of new jump")
	for optional: bool in [false,true]:
		setup(optional)
		remote("LAUNCH");observe(1.3)
		check(visual.sprite.frame==15,"authored final launch drawing reached")
		remote("FALL");observe(0)
		check(not visual.release_clock.active and visual.requested_motion==&"jump","already saw F16: no bridge or repeated final pose")
	# Legacy metadata absent: every observed motion/frame/transform equals product.
	setup(false);remote("LAUNCH",-100)
	for dt: float in [0.0,.1,.2,.05]:
		observe(dt);check(visual.sprite.frame==baseline.sprite.frame and visual.requested_motion==baseline.requested_motion and visual.sprite.position==baseline.sprite.position,"legacy launch unchanged")
	remote("FALL")
	for dt: float in [0.0,1.0/60.0,.1]:
		observe(dt);check(visual.sprite.frame==baseline.sprite.frame and visual.requested_motion==baseline.requested_motion and visual.sprite.position==baseline.sprite.position,"legacy FALL unchanged")
	for next_state: String in ["IDLE","GUARD","EVADE","KNOCK_DOWN","DEAD","RING_OUT","MATCH_ENDED"]:
		start_bridge();remote(next_state);observe(0)
		check(not visual.release_clock.active and visual.requested_motion!=&"launch","landing/defense/KO/match result cancels immediately: "+next_state)
	# New attack result, not an input delay.
	start_bridge();var attack := player.runtime_profile.move_set.attacks()[0]
	player.active_attack=attack;player.state=FighterController.State.ATTACK_STARTUP;player.activation_serial+=1;observe(0)
	check(not visual.release_clock.active and visual.requested_motion==attack.visual_state_id,"new attack immediately replaces release")
	# New jump result: consumed allowance, launcher allowance or upward impulse.
	for kind: String in ["air_allowance","launcher","upward_impulse","fall_to_jump"]:
		start_bridge()
		if kind=="air_allowance": player.air_jumps_remaining-=1
		elif kind=="launcher":
			player.launcher_jump_available=true;observe(0);player.launcher_jump_available=false
		elif kind=="upward_impulse":player.velocity.y=-300
		else:player.state=FighterController.State.JUMP
		observe(0);check(not visual.release_clock.active and visual.requested_motion==&"jump","fresh jump result cancels: "+kind)
	# Real public inputs still act while the presentation is releasing.
	start_bridge();player.air_jumps_remaining=1;observe(0)
	player.consume_intent(CombatIntent.new(100,player.fighter_id,&"jump"),controller.rules)
	check(player.state==FighterController.State.JUMP and player.velocity.y<0,"real jump input acts before the display bridge finishes")
	observe(0);check(not visual.release_clock.active and visual.requested_motion==&"jump","real consumed jump cancels visual bridge immediately")
	start_bridge()
	player.consume_intent(CombatIntent.new(101,player.fighter_id,&"attack_light",CombatIntent.Direction.NEUTRAL,CombatIntent.Edge.PRESS,CombatIntent.Context.AIR),controller.rules)
	check(player.active_attack!=null,"real attack input acts before bridge finishes")
	observe(0);check(not visual.release_clock.active and visual.requested_motion==player.active_attack.visual_state_id,"real attack result replaces bridge without waiting")
	start_bridge();player.consume_intent(CombatIntent.new(102,player.fighter_id,&"move",CombatIntent.Direction.RIGHT),controller.rules);observe(0)
	check(player.input_direction==CombatIntent.Direction.RIGHT and visual.release_clock.active,"movement input remains applied during harmless display bridge")
	# Bad optional pairs fail closed in the full clone, not merely the helper.
	for pair: Array in [[[12,16],3],[[12,16],13],[[12.5,16],4],[[12,17],5],[[16,12],4],[null,4]]:
		setup(true);visual._motion_layouts[&"launch"].launch_release_frame_range=pair[0];visual._motion_layouts[&"launch"].launch_release_ticks=pair[1]
		remote("LAUNCH",-100);observe(.35);remote("FALL");observe(0)
		check(not visual.release_clock.active and visual.requested_motion==&"jump","bad optional pair keeps old FALL display")
	start_bridge();visual._motion_layouts[&"launch"].launch_release_ticks=0;observe(0)
	check(not visual.release_clock.active,"invalid metadata cancels an active bridge")
	start_bridge();var saved_hash: String=visual._motion_layouts[&"launch"].sha256;visual._motion_layouts[&"launch"].sha256="different-artwork";observe(0)
	check(not visual.release_clock.active,"different artwork hash cancels active bridge")
	visual._motion_layouts[&"launch"].sha256=saved_hash
	start_bridge();player.activation_serial+=1;observe(0);check(not visual.release_clock.active,"new activation serial cancels active bridge")
	# Current-state repeated hits and unique LAN HIT restart. Duplicate is ignored.
	start_bridge();remote("LAUNCH",-100);seq+=1
	var hit := {"epoch":1,"event_seq":seq,"tick":200,"defender_id":String(player.fighter_id),"result":"HIT"}
	visual.play_combat_event(&"hit_resolved",hit);observe(0)
	check(not visual.release_clock.active and visual.sprite.frame==0,"unique LAN re-hit immediately cancels/restarts launch")
	observe(.2);var before_frame: int=visual.sprite.frame
	visual.play_combat_event(&"hit_resolved",hit);observe(0)
	check(visual.sprite.frame==before_frame,"duplicate LAN HIT does not restart again")
	start_bridge()
	var local_attack := attack.duplicate() as AttackData;local_attack.damage=0
	player.apply_hit(local_attack,Vector2(0,-100),10,controller.rules,AttackData.HitReaction.LAUNCH);observe(0)
	check(not visual.release_clock.active and visual.sprite.frame==0,"new local hit clears release and starts exact first pose")
	start_bridge();player.apply_hit(local_attack,Vector2.ZERO,10,controller.rules,AttackData.HitReaction.NORMAL_HIT);observe(0)
	check(not visual.release_clock.active and visual.requested_motion==&"hitstun" and visual.sprite.frame==0,"new local ordinary hit replaces release with first HITSTUN pose")
	for kind: String in ["match","profile"]:
		start_bridge()
		if kind=="match": player.reset_for_match(controller.rules)
		else:check(player.configure_profile(LoadoutBuilder.build(selection,LocalPlayCatalog.new().combat).profile),"profile reset configures")
		observe(0);check(not visual.release_clock.active,"reset/profile cancels release: "+kind)
	# Profile change is tested against a real second profile; no candidate persists.
	start_bridge();selection.character_id=&"nabi";player.configure_profile(LoadoutBuilder.build(selection,LocalPlayCatalog.new().combat).profile);observe(0)
	check(not visual.release_clock.active and visual.character_id==&"nabi","character/profile change clears optional release")
	var report := {"checks":checks,"failures":failures,"traces":traces,"scope":"headless state/pose selection prototype, not pixel gameplay capture","metadata":"r04 finite integral JSON float fix; process-local pair and saved/reloaded actual candidate row; frozen r09/catalog/product untouched"}
	var file:=FileAccess.open(DIR+"report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	visual.free();baseline.free();scene.queue_free();await process_frame;root.get_node("ForestArenaAudio").shutdown()
	for failure: String in failures:push_error(failure)
	print("LAUNCH_RELEASE_PROTOTYPE: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL",checks]);quit(0 if failures.is_empty() else 1)
