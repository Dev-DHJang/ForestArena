extends SceneTree
## Two real LanMatchClient sockets; combat happens only in the unchanged server.
const CandidateFrames := preload("res://_workspace/motion-naturalness-v1/import-parity-candidate-frames.gd")
var DIR := ""
const CATALOG := "res://_workspace/motion-naturalness-v1/remaining-candidate-catalog-r10.json"
var presentation_script: GDScript
var clients: Array[LanMatchClient] = []
var fighters: Array[Dictionary] = []
var latest: Array[Dictionary] = [{},{}]
var last_tick: Array[int] = [0,0]
var launch_seen: Array[bool] = [false,false]
var release_seen: Array[bool] = [false,false]
var followup_seen: Array[bool] = [false,false]
var entries := {}
var frames := {}
var textures: Array[Texture2D] = []
var errors: Array[String] = []
var checks := 0
var mode := "natural"
var invite := ""
var trace: Array[Dictionary] = []
var events: Array[Dictionary] = []
var inputs: Array[Dictionary] = []
var render_tick := 0
var followup_sent := false
var observing := false
var all_snapshots_omit_stun := true
var before_hashes := {}
var followup_display_summary: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: errors.append(label)

func _physics_process(_delta: float) -> bool:
	if not observing: return false
	render_tick += 1
	for index: int in fighters.size():
		for id: StringName in fighters[index]:
			var fighter: FighterController = fighters[index][id]
			var visual: Node = fighter.get_node("Presentation")
			var before := fighter.snapshot()
			var stun_before := fighter.hitstun_ticks
			visual.sync_visual(1.0/60)
			check(before == fighter.snapshot() and stun_before == fighter.hitstun_ticks,"display leaves received combat state and remaining stun unchanged")
			if id != &"lan_guest": continue
			if visual.release_clock.active: release_seen[index] = true
			if launch_seen[index]:
				trace.append({"client_slot":index+1,"owned":index==1,"fighter_id":String(id),"server_tick":last_tick[index],"render_tick":render_tick,"state":FighterController.State.keys()[fighter.state],"attack_id":"" if fighter.active_attack == null else String(fighter.active_attack.attack_id),"air_jumps":fighter.air_jumps_remaining,"remaining_stun_local":fighter.hitstun_ticks,"display_duration":visual._reaction_duration_ticks,"motion":String(visual.requested_motion),"frame_zero_based":visual.sprite.frame,"release_active":visual.release_clock.active,"release_elapsed":visual.release_clock.elapsed,"release_started_count":visual.release_clock.started_count})
	return false

func on_snapshot(value: Dictionary, index: int) -> void:
	latest[index] = value.duplicate(true)
	last_tick[index] = int(value.get("tick",0))
	for raw: Dictionary in value.get("fighters",[]):
		all_snapshots_omit_stun = all_snapshots_omit_stun and not raw.has("hitstun_ticks")
		var id := StringName(raw.get("id",""))
		if fighters[index].has(id):
			var fighter: FighterController = fighters[index][id]
			fighter.apply_network_snapshot(raw)
		if id != &"lan_guest": continue
		if raw.get("state") == "LAUNCH": launch_seen[index] = true
		if launch_seen[index] and not followup_sent and index == 1 and raw.get("state") == "FALL" and mode != "natural":
			followup_sent = true
			send_input(1,&"attack_light" if mode == "attack" else &"jump",CombatIntent.Direction.NEUTRAL,CombatIntent.Edge.PRESS)
		if followup_sent and ((mode=="attack" and raw.get("attack_id")=="ja-hyun-air-light") or (mode=="jump" and raw.get("state")=="JUMP")):
			followup_seen[index] = true

func on_event(id: StringName, payload: Dictionary, index: int) -> void:
	events.append({"client_slot":index+1,"event_id":String(id),"payload":payload.duplicate(true)})
	for fighter: FighterController in fighters[index].values():
		fighter.get_node("Presentation").play_combat_event(id,payload)

func send_input(index: int, action: StringName, direction: CombatIntent.Direction, edge: CombatIntent.Edge) -> void:
	var owned_id: StringName = &"lan_host" if index==0 else &"lan_guest"
	clients[index].submit_qa_intent(CombatIntent.new(last_tick[index]+1,owned_id,action,direction,edge,CombatIntent.Context.GROUND))
	inputs.append({"slot":index+1,"owned_fighter_id":String(owned_id),"observed_tick":last_tick[index],"action":String(action),"direction":int(direction),"edge":int(edge)})

func wait_for(predicate: Callable, timeout_ms: int, label: String) -> bool:
	var deadline := Time.get_ticks_msec()+timeout_ms
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		await process_frame
	check(false,"timeout: "+label)
	return false

func row(index: int, id: String) -> Dictionary:
	for raw: Dictionary in latest[index].get("fighters",[]):
		if raw.get("id")==id: return raw
	return {}

func prepare_candidates() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	for raw: Dictionary in catalog.assets:
		var entry := raw.duplicate(true)
		var cid := String(entry.character_id)
		var motion := StringName(entry.visual_state_id)
		if motion==&"launch":
			entry.launch_release_frame_range = [12,16]
			entry.launch_release_ticks = 4
		var path := "res://"+String(entry.path).trim_prefix("res://")
		check(FileAccess.get_sha256(path)==String(entry.sha256),"candidate hash "+path)
		var loaded := CandidateFrames.load_frames(entry,errors,textures)
		if loaded==null: continue
		if not entries.has(cid):
			entries[cid] = {}
			frames[cid] = {}
		entries[cid][motion] = entry
		frames[cid][motion] = loaded

func prepare_client(index: int) -> void:
	var client := LanMatchClient.new()
	client.set_meta("qa_active",true)
	client.qa_autoplay = true
	root.add_child(client)
	clients.append(client)
	fighters.append({})
	for slot: int in [1,2]:
		var cid: StringName = &"nabi" if slot==1 else &"ja-hyun"
		var fighter := FighterController.new()
		fighter.fighter_id = &"lan_host" if slot==1 else &"lan_guest"
		fighter.character_data = LocalPlayCatalog.new().combat.character_by_id(cid)
		fighter.show_debug_body = false
		root.add_child(fighter)
		var selection := LoadoutSelection.new()
		selection.character_id = cid
		check(fighter.configure_profile(LoadoutBuilder.build(selection,LocalPlayCatalog.new().combat).profile),"client fighter actual profile")
		fighter.set_physics_process(false)
		var visual: Node = presentation_script.new()
		fighter.add_child(visual)
		visual.set_process(false)
		visual.sync_visual(0)
		for motion: StringName in frames.get(String(cid),{}):
			visual._motions[motion] = frames[String(cid)][motion]
			visual._motion_layouts[motion] = entries[String(cid)][motion]
		visual._last_motion = &""
		fighters[index][fighter.fighter_id] = fighter
	client.failed.connect(func(code: String) -> void:
		if observing: errors.append("client %d: %s" % [index+1,code]))
	client.snapshot_received.connect(on_snapshot.bind(index))
	client.presentation_event_received.connect(on_event.bind(index))
	client.match_started.connect(func(_slot: int) -> void: client.qa_autoplay = true)
	if index==0: client.room_created.connect(func(code: String) -> void: invite=code)

func run() -> void:
	DIR = OS.get_environment("LAN_RELEASE_OUTPUT_DIR")
	var workspace := ProjectSettings.globalize_path("res://_workspace/")
	if DIR.is_empty() or not DIR.begins_with(workspace):
		push_error("QA output requires a fresh _workspace directory")
		quit(1); return
	DIR = DIR.trim_suffix("/")+"/"
	mode = OS.get_environment("LAN_RELEASE_MODE")
	if mode.is_empty(): mode="natural"
	check(mode in ["natural","attack","jump"],"known QA case")
	if FileAccess.file_exists(DIR+mode+"-report.json"):
		push_error("QA output already exists")
		quit(1); return
	var script_path := OS.get_environment("LAN_RELEASE_PRESENTATION")
	if script_path.is_empty(): script_path="res://scripts/local_fighter_presentation.gd"
	presentation_script = load(script_path) as GDScript
	prepare_candidates()
	prepare_client(0)
	prepare_client(1)
	observing = true
	var host_selection := LoadoutSelection.new()
	host_selection.character_id = &"nabi"
	var guest_selection := LoadoutSelection.new()
	guest_selection.character_id = &"ja-hyun"
	var url := OS.get_environment("FOREST_ARENA_LAN_TEST_WS_URL")
	check(clients[0].begin_host(LanInvite.host_code(url,"http://127.0.0.1:18081"),host_selection,"","host"),"public authenticated host API")
	if await wait_for(func() -> bool: return not invite.is_empty(),5000,"authenticated room create"):
		check(clients[1].begin_join(invite,guest_selection,"","guest"),"public authenticated join API")
	var running := await wait_for(func() -> bool: return clients[0].running and clients[1].running and not row(0,"lan_guest").is_empty(),5000,"two actual sockets match start")
	if running:
		check(clients[0].local_slot==1 and clients[1].local_slot==2,"owned fighter IDs mapped from real local slots")
		send_input(0,&"move",CombatIntent.Direction.RIGHT,CombatIntent.Edge.PRESS)
		send_input(1,&"move",CombatIntent.Direction.LEFT,CombatIntent.Edge.PRESS)
		var close := await wait_for(func() -> bool:
			var a := row(0,"lan_host")
			var b := row(0,"lan_guest")
			return not a.is_empty() and not b.is_empty() and absf(float(a.position.x)-float(b.position.x))<70 and bool(a.on_floor) and bool(b.on_floor),5000,"actual movement to uppercut range")
		send_input(0,&"move",CombatIntent.Direction.RIGHT,CombatIntent.Edge.RELEASE)
		send_input(1,&"move",CombatIntent.Direction.LEFT,CombatIntent.Edge.RELEASE)
		if close:
			send_input(0,&"attack_heavy",CombatIntent.Direction.NEUTRAL,CombatIntent.Edge.PRESS)
			await wait_for(func() -> bool: return launch_seen[0] and launch_seen[1],2000,"Nabi real ground heavy causes Ja LAUNCH on both clients")
			await wait_for(func() -> bool: return release_seen[0] and release_seen[1],2000,"snapshot FALL starts optional display release")
			if mode!="natural": await wait_for(func() -> bool: return followup_seen[0] and followup_seen[1],2000,"real followup input executes on authority and reaches both clients")
			await create_timer(0.2).timeout
	observing = false
	check(all_snapshots_omit_stun,"actual received LAN snapshots omit remaining hitstun")
	for index: int in 2:
		var selected: Array[int] = []
		var followup_rendered := false
		var first_followup_tick := -1
		for sample: Dictionary in trace:
			if int(sample.client_slot)!=index+1: continue
			check(int(sample.remaining_stun_local)==0 and int(sample.display_duration)==0,"no invented LAN stun duration")
			if sample.release_active: selected.append(int(sample.frame_zero_based))
			if mode=="attack" and not String(sample.attack_id).is_empty() and sample.motion!="launch": followup_rendered=true;first_followup_tick=int(sample.render_tick) if first_followup_tick<0 else first_followup_tick
			if mode=="jump" and sample.state=="JUMP" and sample.motion=="jump": followup_rendered=true;first_followup_tick=int(sample.render_tick) if first_followup_tick<0 else first_followup_tick
		if mode=="natural": check(selected==[12,13,14,15],"each real-socket client shows exactly four60Hz release samples")
		else: check(followup_rendered,"received followup result is displayed; delivery may follow natural release completion")
		followup_display_summary.append({"client_slot":index+1,"release_frames":selected,"followup_rendered":followup_rendered,"first_followup_render_tick":first_followup_tick,"release_incomplete_before_followup":followup_rendered and selected.size()<4,"note":"network delivery may occur after natural completion; headless public test separately proves immediate cancellation for already-applied input results"})
		check(release_seen[index],"release observed for owned and remote Ja")
	check(events.any(func(e: Dictionary) -> bool: return e.event_id=="hit_resolved" and e.payload.get("result")=="HIT" and e.payload.get("defender_id")=="lan_guest"),"actual server HIT event received")
	clients[1].leave()
	await create_timer(0.15).timeout
	clients[0].request_rematch(false)
	await create_timer(0.15).timeout
	for client: LanMatchClient in clients: client.stop()
	var report := {"status":"pass" if errors.is_empty() else "fix","checks":checks,"errors":errors,"mode":mode,"scope":"real authenticated localhost WebSocket server and two LanMatchClient nodes; received snapshots only; selected presentation with process-local r10 candidates/release; code-only, no Android/pixel claim","presentation":script_path,"catalog_sha256":FileAccess.get_sha256(CATALOG),"owned_ids":{"1":"lan_host","2":"lan_guest"},"all_snapshots_omit_stun":all_snapshots_omit_stun,"latest_received_snapshots":latest,"inputs":inputs,"events":events,"trace":trace,"followup_display_summary":followup_display_summary}
	FileAccess.open(DIR+mode+"-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	for error: String in errors: push_error(error)
	print("LAN_LAUNCH_RELEASE "+mode+": "+("PASS" if errors.is_empty() else "FAIL")+" (%d checks)"%checks)
	for map: Dictionary in fighters:
		for fighter: FighterController in map.values(): fighter.free()
	for client: LanMatchClient in clients: client.free()
	root.get_node("ForestArenaAudio").shutdown()
	quit(0 if errors.is_empty() else 1)
