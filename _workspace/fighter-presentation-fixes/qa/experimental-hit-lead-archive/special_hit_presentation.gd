extends SceneTree
## Actual special pulses, with local and 20 Hz snapshot-driven remote drawings.
const Presentation := preload("res://scripts/local_fighter_presentation.gd")
var failures: Array[String] = []
var checks := 0
var scene: Node
var controller: MatchController
var catalog: LoadoutCatalog
var incoming: Array[Dictionary] = []
var remote_visual: Node
var traces: Array[Dictionary] = []
var baseline := {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok and not failures.has(label): failures.append(label)
func observe(visual: Node, fighter: FighterController, delta: float) -> void:
 var before := fighter.snapshot()
 visual.sync_visual(delta)
 check(before == fighter.snapshot(), "drawing does not modify actual combat")
func profile(cid: StringName) -> RuntimeCombatProfile:
 var selection := LoadoutSelection.new(); selection.character_id=cid
 return LoadoutBuilder.build(selection,catalog).profile
func on_event(id: StringName, payload: Dictionary) -> void:
 if id != &"hit_resolved": return
 incoming.append(payload.duplicate(true))
 remote_visual.play_combat_event(id,payload)
func run() -> void:
 scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
 await physics_frame
 root.get_node("ForestArenaAudio").muted=true
 controller=scene.get_node("MatchController");controller.set_physics_process(false)
 controller.bot_source=null;controller.bot_sources.clear()
 controller.rules=load("res://assets/combat/two_fighter_combat_rules.tres").duplicate(true)
 catalog=LocalPlayCatalog.new().combat
 for cid: StringName in [&"ja-hyun",&"nabi"]:
  for activity: String in ["standing","walking","attacking"]:
   for lead: bool in [false,true]:
    pulse_case(cid,lead,activity)
 var output: String="user://special-hit-presentation-trace.json"
 var args:=OS.get_cmdline_user_args()
 var output_flag:=args.find("--trace-output")
 if output_flag>=0 and output_flag+1<args.size():output=args[output_flag+1]
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(traces,"\t"))
 lead_boundaries()
 remote_event_boundaries()
 scene.queue_free();await process_frame
 for failure: String in failures:push_error(failure)
 print("SPECIAL_HIT_PRESENTATION: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL",checks])
 quit(0 if failures.is_empty() else 1)
func pulse_case(cid: StringName, lead: bool, activity: String) -> void:
 var source:=controller.player
 var target:=controller.training_dummy
 source.configure_profile(profile(&"ja-hyun"));target.configure_profile(profile(cid))
 controller.reset_match()
 # A fresh fixture begins with no historic pull velocity/anchor. Match reset
 # deliberately retains irrelevant expired-pull metadata; do not compare it.
 for fighter: FighterController in [source,target]:
  fighter.pull_anchor=Vector2.ZERO;fighter.pull_speed=0.0;fighter.pull_stop_distance=64.0
 source.position=Vector2(600,572);target.position=Vector2(780,572)
 source.facing=1;target.facing=-1
 var local:=Presentation.new();target.add_child(local);local.set_process(false)
 var proxy:=FighterController.new()
 proxy.character_data=catalog.character_by_id(cid);proxy.fighter_id=target.fighter_id
 root.add_child(proxy);proxy.set_physics_process(false);proxy.configure_profile(profile(cid))
 proxy.collision_layer=0;proxy.collision_mask=0
 remote_visual=Presentation.new();proxy.add_child(remote_visual);remote_visual.set_process(false)
 remote_visual.sync_visual(0)
 if lead:
  remote_visual._motion_layouts[&"hitstun"]["hit_reaction_lead_frame_range"]=[0,6]
  remote_visual._motion_layouts[&"hitstun"]["hit_reaction_lead_ticks"]=6
 # Also supply it locally: actual remaining stun still wins over drawing lead.
 local.sync_visual(0)
 if lead:
  local._motion_layouts[&"hitstun"]["hit_reaction_lead_frame_range"]=[0,6]
  local._motion_layouts[&"hitstun"]["hit_reaction_lead_ticks"]=6
 controller.presentation_event.connect(on_event)
 incoming.clear()
 var hit_ticks: Array[int]=[]
 var window_maxima: Array[int]=[]
 var current_max: int=-1
 var local_frames: Array[int]=[]
 var snapshots: Array[Dictionary]=[]
 var hp_before:=target.current_hp
 for tick: int in 110:
  if tick==3:controller.submit_intent(CombatIntent.new(controller.tick+1,source.fighter_id,&"attack_special",CombatIntent.Direction.NEUTRAL,CombatIntent.Edge.PRESS,CombatIntent.Context.GROUND))
  if tick==10 and activity=="walking":controller.submit_intent(CombatIntent.new(controller.tick+1,target.fighter_id,&"move",CombatIntent.Direction.LEFT,CombatIntent.Edge.PRESS,CombatIntent.Context.GROUND))
  if tick==15 and activity=="attacking":controller.submit_intent(CombatIntent.new(controller.tick+1,target.fighter_id,&"attack_heavy",CombatIntent.Direction.NEUTRAL,CombatIntent.Edge.PRESS,CombatIntent.Context.GROUND))
  controller.step_fixed_tick(false)
  if not incoming.is_empty():
   if current_max>=0:window_maxima.append(current_max)
   current_max=0
   for event: Dictionary in incoming:
    check(event.result=="HIT", "real unobstructed special pulse is an effective HIT")
    check(target.state==FighterController.State.HITSTUN,"each actual special HIT enters combat HITSTUN")
    hit_ticks.append(controller.tick)
   incoming.clear()
  # Same public snapshot consumer and event-before-next-snapshot order as LAN.
  if controller.tick%3==0:
   var network:=controller.network_snapshot()
   proxy.apply_network_snapshot(network.fighters[1])
  observe(local,target,1.0/60.0);observe(remote_visual,proxy,1.0/60.0)
  snapshots.append(controller.snapshot().duplicate(true));local_frames.append(local.sprite.frame)
  if local.requested_motion==&"hitstun":
   check(target.hitstun_ticks>0 and local._reaction_duration_ticks>0,"local clock follows actual remaining combat stun")
  if current_max>=0 and remote_visual.requested_motion==&"hitstun":current_max=maxi(current_max,remote_visual.sprite.frame)
  traces.append({"character":cid,"lead":lead,"activity":activity,"tick":controller.tick,"state":FighterController.State.keys()[target.state],"local_motion":local.requested_motion,"local_frame":local.sprite.frame,"remote_motion":remote_visual.requested_motion,"remote_frame":remote_visual.sprite.frame,"stun":target.hitstun_ticks})
 if current_max>=0:window_maxima.append(current_max)
 check(hit_ticks.size()==10,"actual special hits exactly ten times")
 check(is_equal_approx(hp_before-target.current_hp,14.0),"nine pulls plus final hit keep fourteen total damage")
 for index: int in range(1,hit_ticks.size()):check(hit_ticks[index]-hit_ticks[index-1]==6,"special hit schedule remains six ticks")
 if lead:
  for index: int in range(mini(window_maxima.size(),9)):
   check(window_maxima[index]>=4,"%s remote pulse %d must reach a readable hit pose before the next six-tick hit" % [cid,index+1])
 else:
  check(window_maxima.slice(0,9).all(func(frame: int)->bool:return frame<=2),"authored 24 FPS repeats only the first three poses at six-tick cadence")
 var key: String="%s/%s/" % [cid,activity]
 if not lead:
  baseline[key+"snapshots"]=snapshots;baseline[key+"local_frames"]=local_frames
 else:
  if baseline[key+"snapshots"]!=snapshots:
   FileAccess.open("res://_workspace/fighter-presentation-fixes/qa/special-hit-snapshot-mismatch-"+String(cid)+".json",FileAccess.WRITE).store_string(JSON.stringify({"before":baseline[key+"snapshots"],"after":snapshots},"\t"))
  check(baseline[key+"snapshots"]==snapshots,"display lead leaves complete actual match snapshots identical")
  check(baseline[key+"local_frames"]==local_frames,"display lead leaves locally timed hit reactions unchanged")
 controller.presentation_event.disconnect(on_event)
 local.free();proxy.free()

func lead_boundaries() -> void:
 var valid := {"hit_reaction_lead_frame_range":[0,6],"hit_reaction_lead_ticks":6}
 check(Presentation.hit_reaction_lead_frame(0.0,24.0,16,valid)==0,"lead begins with the original first pose")
 check(Presentation.hit_reaction_lead_frame(5.0/60.0,24.0,16,valid)==5,"six-tick cadence reaches the authored impact pose")
 check(Presentation.hit_reaction_lead_frame(6.0/60.0,24.0,16,valid)==6,"lead joins the following authored frame without a jump")
 check(Presentation.hit_reaction_lead_frame(6.0/60.0+1.5/24.0,24.0,16,valid)==7,"remaining frames use their authored FPS")
 check(Presentation.hit_reaction_lead_frame(20.0,24.0,16,valid)==15,"completed remote reaction holds its last drawing until real state changes")
 var parsed: Dictionary=JSON.parse_string('{"hit_reaction_lead_frame_range":[0,6],"hit_reaction_lead_ticks":6}')
 check(Presentation.hit_reaction_lead_frame(0,24,16,parsed)==0,"finite integral JSON numbers are accepted")
 var invalid: Array=[{}, {"hit_reaction_lead_frame_range":[0,6]}, {"hit_reaction_lead_ticks":6}]
 for span: Variant in [[1,6],[0,17],[0,0],[-1,5],[0,6.5],[false,6],[0,true],[0,INF],[0,NAN],[0],"0,6"]:
  invalid.append({"hit_reaction_lead_frame_range":span,"hit_reaction_lead_ticks":6})
 for duration: Variant in [0,5,13,-1,true,6.5,INF,NAN,"6",null]:
  invalid.append({"hit_reaction_lead_frame_range":[0,6],"hit_reaction_lead_ticks":duration})
 for item: Dictionary in invalid:
  check(Presentation.hit_reaction_lead_frame(0,24,16,item)==-1,"invalid or incomplete lead pair uses the legacy playback path")
 var layout:=Presentation.display_layout({"sha256":"test-artwork","hit_reaction_lead_frame_range":[0,6],"hit_reaction_lead_ticks":6})
 check(layout.get("hit_reaction_lead_frame_range")==[0,6] and layout.get("hit_reaction_lead_ticks")==6,"hash-bound display data carries both lead values")

func remote_event_boundaries() -> void:
 var proxy:=FighterController.new();proxy.character_data=catalog.character_by_id(&"ja-hyun")
 proxy.fighter_id=&"remote-target";root.add_child(proxy);proxy.set_physics_process(false)
 proxy.configure_profile(profile(&"ja-hyun"))
 var visual:=Presentation.new();proxy.add_child(visual);visual.set_process(false)
 visual.sync_visual(0)
 visual._motion_layouts[&"hitstun"]["hit_reaction_lead_frame_range"]=[0,6]
 visual._motion_layouts[&"hitstun"]["hit_reaction_lead_ticks"]=6
 proxy.apply_network_snapshot({"state":"HITSTUN","stocks":3})
 for first_delta: float in [0.0,1.0/60.0,1.0/30.0]:
  var epoch: int=10+int(first_delta*1000)
  var hit: Dictionary={"defender_id":"remote-target","result":"HIT","tick":6,"event_seq":1,"epoch":epoch}
  visual.play_combat_event(&"hit_resolved",hit);observe(visual,proxy,first_delta)
  check(visual.sprite.frame==0,"first drawn pose remains frame zero even when a frame was delayed")
  observe(visual,proxy,5.0/60.0)
  check(visual.sprite.frame==5,"remote display reaches a visible impact pose without deriving combat stun")
  var same:=visual.sprite.frame
  var variants: Array[Dictionary]=[hit, {"defender_id":"remote-target","result":"HIT","tick":5,"event_seq":2,"epoch":epoch}, {"defender_id":"remote-target","result":"BLOCK","tick":7,"event_seq":3,"epoch":epoch}, {"defender_id":"remote-target","result":"IMMUNE","tick":8,"event_seq":4,"epoch":epoch}, {"defender_id":"remote-target","result":"ARMOR","tick":9,"event_seq":5,"epoch":epoch}]
  for payload: Dictionary in variants:
   visual.play_combat_event(&"hit_resolved",payload);observe(visual,proxy,0)
   check(visual.sprite.frame==same,"duplicate, old or non-HIT event does not restart authored lead")
  var fresh:=hit.duplicate();fresh.tick=12;fresh.event_seq=6
  visual.play_combat_event(&"hit_resolved",fresh);observe(visual,proxy,0)
  check(visual.sprite.frame==0,"next unique effective HIT restarts the authored lead")
 for state: String in ["IDLE","GUARD","DEAD","MATCH_ENDED"]:
  proxy.apply_network_snapshot({"state":state,"stocks":0 if state in ["DEAD","MATCH_ENDED"] else 3})
  observe(visual,proxy,0)
  visual.play_combat_event(&"hit_resolved",{"defender_id":"remote-target","result":"HIT","tick":100,"event_seq":100,"epoch":100})
  observe(visual,proxy,0)
  check(visual.requested_motion!=&"hitstun","late HIT cannot invent hitstun while the real state is "+state)
 proxy.free()
