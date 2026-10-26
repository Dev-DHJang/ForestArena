extends SceneTree
## Two real LanMatchClient sockets; combat happens only in the unchanged server.
const RenderRelay := preload("res://_workspace/motion-naturalness-v1/qa/lan-launch-release-visual-r03/render-relay.gd")
const CandidateFrames := preload("res://_workspace/motion-naturalness-v1/import-parity-candidate-frames.gd")
var DIR := ""
const CATALOG := "res://_workspace/motion-naturalness-v1/remaining-candidate-catalog-r10.json"
const CAPTURE_SIZE := Vector2i(640,480)
var view_case := "normal"
var target_character := "ja-hyun"
var server_room_loadouts: Array[Dictionary]=[{},{}]
var viewports: Array[SubViewport] = []
var cameras: Array[Camera2D] = []
var raw_files: Array[FileAccess] = []
var prelude: Array[Dictionary] = []
var capture_manifest: Array[Dictionary] = []
var capture_started := false
var capture_pending := false
var sync_serial := 0
var elapsed_since_sync := 0.0
var skipped_process_while_pending := 0
var pending_packet: Dictionary = {}
var draw_observations: Array[Dictionary] = [{},{}]
var arrival_serial := 0
var arrivals: Array[Dictionary] = []
var latest_snapshot_serial: Array[int] = [0,0]
var latest_snapshot_usec: Array[int] = [0,0]
var sync_snapshot_ids := {}
var draw_snapshot_ids := {}
var unpaired_syncs: Array[Dictionary] = []
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
var tick_barriers: Array[Dictionary] = []
var render_relay: Node

func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: errors.append(label)

func render_step(delta: float) -> void:
	if not observing: return
	render_tick += 1
	elapsed_since_sync += delta
	if capture_pending:
		# Do not advance a second pose before the first has actually drawn.
		# Accumulate real idle-process delta; never substitute fixed 1/60.
		# Never stretch release time to force four pictures.
		skipped_process_while_pending += 1
		return
	sync_serial += 1
	var delta_for_sync := elapsed_since_sync
	elapsed_since_sync = 0.0
	var samples: Array[Dictionary] = []
	for index: int in fighters.size():
		for id: StringName in fighters[index]:
			var fighter: FighterController = fighters[index][id]
			var visual: Node = fighter.get_node("Presentation")
			var before := fighter.snapshot()
			var stun_before := fighter.hitstun_ticks
			visual.sync_visual(delta_for_sync)
			check(before==fighter.snapshot() and stun_before==fighter.hitstun_ticks,"public sync leaves received state and stun unchanged")
			visual.effects.queue_redraw()
			if id != &"lan_guest": continue
			var sample := {"client_slot":index+1,"owned":index==1,"fighter_id":String(id),"target_character":target_character,"sync_stamp":sync_serial,"server_tick":last_tick[index],"render_tick":render_tick,"sync_usec":Time.get_ticks_usec(),"delta_for_sync":delta_for_sync,"state":FighterController.State.keys()[fighter.state],"attack_id":"" if fighter.active_attack==null else String(fighter.active_attack.attack_id),"air_jumps":fighter.air_jumps_remaining,"remaining_stun_local":fighter.hitstun_ticks,"display_duration":visual._reaction_duration_ticks,"motion":String(visual.requested_motion),"frame_zero_based":visual.sprite.frame,"release_active":visual.release_clock.active,"release_elapsed":visual.release_clock.elapsed,"release_started_count":visual.release_clock.started_count,"facing":fighter.facing,"flip_h":visual.sprite.flip_h,"sprite_position":[visual.sprite.position.x,visual.sprite.position.y],"sprite_scale":[visual.sprite.scale.x,visual.sprite.scale.y],"received_snapshot":before,"snapshot_unchanged":true,"snapshot_arrival_id":latest_snapshot_serial[index],"receipt_to_sync_usec":Time.get_ticks_usec()-latest_snapshot_usec[index]}
			samples.append(sample)
			sync_snapshot_ids[latest_snapshot_serial[index]]=true
			cameras[index].position=fighter.global_position+Vector2(0,-35)
			cameras[index].force_update_scroll()
			# Require the real native AnimatedSprite2D notification on every sample,
			# including held poses. The draw signal runs after that notification.
			visual.sprite.queue_redraw()
	pending_packet={"sync_stamp":sync_serial,"render_tick":render_tick,"samples":samples}
	draw_observations=[{},{}]
	capture_pending=true
	return

static func transform_numbers(value: Transform2D) -> Array:
	return [value.x.x,value.x.y,value.y.x,value.y.y,value.origin.x,value.origin.y]

static func marker_bytes(stamp: int, frame: int, index: int, motion: String, flipped: bool) -> Array[int]:
	var values: Array[int]=[165,90,stamp&255,(stamp>>8)&255,frame&255,index+1,(1 if motion=="launch" else (2 if motion=="jump" else 0)) | (128 if flipped else 0),0]
	for i: int in 7: values[7]=values[7]^values[i]
	return values

func on_sprite_draw(index: int, fighter: FighterController, visual: Node) -> void:
	if not observing or not capture_pending: return
	var sprite: AnimatedSprite2D=visual.sprite
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
	var bytes := marker_bytes(sync_serial,sprite.frame,index,String(sprite.animation),sprite.flip_h)
	# Native sprite commands and this pixel marker share the same CanvasItem
	# draw notification. The marker is verification-only, outside the figure.
	sprite.draw_set_transform_matrix(sprite.get_global_transform_with_canvas().affine_inverse())
	for byte_index: int in 8:
		for bit: int in 8:
			var white := (bytes[byte_index]&(1<<bit))!=0
			sprite.draw_rect(Rect2(4+(byte_index*8+bit)*2,4,2,4),Color.WHITE if white else Color.BLACK)
	var expected: Dictionary=pending_packet.samples[index]
	draw_snapshot_ids[latest_snapshot_serial[index]]=true
	draw_observations[index]={"sync_stamp":sync_serial,"draw_usec":Time.get_ticks_usec(),"engine_frames_drawn_at_command":Engine.get_frames_drawn(),"clock_release_active_at_draw":visual.release_clock.active,"clock_release_elapsed_at_draw":visual.release_clock.elapsed,"animation":String(sprite.animation),"frame_zero_based":sprite.frame,"texture_rid":str(texture.get_rid().get_id()),"texture_class":texture.get_class(),"texture_path":texture.resource_path,"atlas_region":str((texture as AtlasTexture).region) if texture is AtlasTexture else "","sprite_global_with_canvas":transform_numbers(sprite.get_global_transform_with_canvas()),"sprite_global":transform_numbers(sprite.global_transform),"fighter_global":transform_numbers(fighter.global_transform),"sprite_position":[sprite.position.x,sprite.position.y],"sprite_scale":[sprite.scale.x,sprite.scale.y],"flip_h":sprite.flip_h,"draw_received_snapshot":fighter.snapshot(),"draw_stun":fighter.hitstun_ticks,"latest_snapshot_arrival_id":latest_snapshot_serial[index],"latest_received_server_tick":last_tick[index],"receipt_to_draw_usec":Time.get_ticks_usec()-latest_snapshot_usec[index],"sync_pose_matches_native_draw":expected.frame_zero_based==sprite.frame and expected.motion==String(sprite.animation) and expected.flip_h==sprite.flip_h,"sync_snapshot_still_current":expected.snapshot_arrival_id==latest_snapshot_serial[index],"marker_bytes":bytes,"last_sync_packet":expected.duplicate(true)}

static func decoded_marker(image: Image) -> Array[int]:
	var values: Array[int]=[]
	for byte_index: int in 8:
		var value:=0
		for bit: int in 8:
			var pixel:=image.get_pixel(5+(byte_index*8+bit)*2,5)
			if pixel.r>0.5 and pixel.g>0.5 and pixel.b>0.5: value=value|(1<<bit)
		values.append(value)
	return values

func on_frame_post_draw() -> void:
	if not observing or not capture_pending: return
	var rendered: Array[PackedByteArray]=[]
	var samples: Array[Dictionary]=[]
	var paired:=true
	for index: int in 2:
		var observed: Dictionary=draw_observations[index]
		if observed.is_empty():
			check(false,"pending sync has no actual sprite draw notification")
			paired=false
			continue
		var fighter: FighterController=fighters[index][&"lan_guest"]
		var visual: Node=fighter.get_node("Presentation")
		var image:=viewports[index].get_texture().get_image()
		if image==null or image.is_empty():
			check(false,"post-draw backend RGBA unavailable")
			paired=false
			continue
		image.convert(Image.FORMAT_RGBA8)
		var valid: bool=image.get_size()==CAPTURE_SIZE and decoded_marker(image)==observed.marker_bytes
		valid=valid and observed.sync_pose_matches_native_draw and observed.sync_stamp==pending_packet.sync_stamp and observed.animation==String(visual.sprite.animation) and observed.frame_zero_based==visual.sprite.frame
		valid=valid and observed.sprite_global_with_canvas==transform_numbers(visual.sprite.get_global_transform_with_canvas()) and observed.draw_received_snapshot==fighter.snapshot() and observed.draw_stun==fighter.hitstun_ticks
		check(valid,"post-draw pixels/stamp/native-draw pose/transform/received state agree")
		paired=paired and valid
		var sample: Dictionary=observed.last_sync_packet.duplicate(true)
		# Attribute pixels to actual draw pose, not merely requested sync values.
		sample["state_at_sync"]=sample.state
		sample["state"]=observed.draw_received_snapshot.state
		sample["server_tick_at_sync"]=sample.server_tick
		sample["server_tick"]=observed.latest_received_server_tick
		sample["release_active_at_sync"]=sample.release_active
		sample["motion"]=observed.animation
		sample["frame_zero_based"]=observed.frame_zero_based
		sample["draw_observation"]=observed.duplicate(true)
		sample["post_draw_usec"]=Time.get_ticks_usec()
		sample["engine_frames_drawn_at_post_draw"]=Engine.get_frames_drawn()
		sample["pixel_marker_verified"]=valid
		sample["snapshot_unchanged"]=observed.draw_received_snapshot==fighter.snapshot()
		samples.append(sample)
		rendered.append(image.get_data())
	if paired and samples.size()==2:
		for index: int in 2:
			if samples[index].release_active: release_seen[index]=true
			if launch_seen[index]: trace.append(samples[index].duplicate(true))
		var item:={"render_tick":pending_packet.render_tick,"samples":samples,"rgba":rendered}
		if not capture_started:
			prelude.append(item)
			if prelude.size()>5: prelude.pop_front()
			if launch_seen[0] or launch_seen[1]:
				capture_started=true
				for buffered: Dictionary in prelude: persist_capture(buffered)
				prelude.clear()
		else: persist_capture(item)
	else: unpaired_syncs.append(pending_packet.duplicate(true))
	capture_pending=false

func rgba_hash(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func persist_capture(item: Dictionary) -> void:
	for index: int in 2:
		var bytes: PackedByteArray = item.rgba[index]
		var offset := raw_files[index].get_position()
		raw_files[index].store_buffer(bytes)
		check(raw_files[index].get_error()==OK,"write exact rendered RGBA sample")
		capture_manifest.append({"client_slot":index+1,"render_tick":item.render_tick,"raw_path":view_case+"-client-%d.rgba"%(index+1),"raw_offset":offset,"byte_length":bytes.size(),"rgba_sha256":rgba_hash(bytes),"size":[CAPTURE_SIZE.x,CAPTURE_SIZE.y],"trace":item.samples[index].duplicate(true)})

func prepare_viewports() -> void:
	root.size=Vector2i(1280,512)
	for index: int in 2:
		var viewport := SubViewport.new()
		viewport.name="Client%dWorld"%(index+1)
		viewport.size=CAPTURE_SIZE
		viewport.world_2d=World2D.new()
		viewport.disable_3d=true
		viewport.transparent_bg=false
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		viewports.append(viewport)
		# Keep only the real stage artwork; no local MatchController can step combat.
		var shell: Node = load("res://scenes/main.tscn").instantiate()
		var artwork: Node = shell.get_node("ArenaVisual")
		shell.remove_child(artwork)
		shell.free()
		viewport.add_child(artwork)
		artwork.set_process(false)
		var camera := Camera2D.new()
		camera.zoom=Vector2(1.5,1.5)
		camera.position_smoothing_enabled=false
		viewport.add_child(camera)
		camera.enabled=true
		cameras.append(camera)
		var display := TextureRect.new()
		display.position=Vector2(index*640,32)
		display.size=Vector2(640,480)
		display.texture=viewport.get_texture()
		display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		root.add_child(display)
		var label := Label.new()
		label.position=Vector2(index*640+8,4)
		label.text="Actual LAN %s / client %d / %s %s"%[view_case,index+1,target_character,"remote" if index==0 else "owned"]
		root.add_child(label)
		var raw := FileAccess.open(DIR+view_case+"-client-%d.rgba"%(index+1),FileAccess.WRITE)
		check(raw != null,"open fresh RGBA stream")
		if raw == null: return
		raw_files.append(raw)

func on_snapshot(value: Dictionary, index: int) -> void:
	arrival_serial+=1
	latest_snapshot_serial[index]=arrival_serial
	latest_snapshot_usec[index]=Time.get_ticks_usec()
	arrivals.append({"arrival_id":arrival_serial,"kind":"snapshot","client_slot":index+1,"server_tick":int(value.get("tick",0)),"received_usec":latest_snapshot_usec[index],"observing_at_receipt":observing,"draw_pending_at_receipt":capture_pending})
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
	arrival_serial+=1
	arrivals.append({"arrival_id":arrival_serial,"kind":"event","client_slot":index+1,"server_tick":int(payload.get("tick",0)),"event_id":String(id),"received_usec":Time.get_ticks_usec(),"observing_at_receipt":observing,"draw_pending_at_receipt":capture_pending})
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
		var cid: StringName = &"nabi" if slot==1 else StringName(target_character)
		var fighter := FighterController.new()
		fighter.fighter_id = &"lan_host" if slot==1 else &"lan_guest"
		fighter.character_data = LocalPlayCatalog.new().combat.character_by_id(cid)
		fighter.show_debug_body = false
		viewports[index].add_child(fighter)
		var selection := LoadoutSelection.new()
		selection.character_id = cid
		check(fighter.configure_profile(LoadoutBuilder.build(selection,LocalPlayCatalog.new().combat).profile),"client fighter actual profile")
		fighter.set_physics_process(false)
		var visual: Node = presentation_script.new()
		fighter.add_child(visual)
		visual.set_process(false)
		if slot==2: visual.sprite.draw.connect(on_sprite_draw.bind(index,fighter,visual))
		visual.sync_visual(0)
		for motion: StringName in frames.get(String(cid),{}):
			visual._motions[motion] = frames[String(cid)][motion]
			visual._motion_layouts[motion] = entries[String(cid)][motion]
		visual._last_motion = &""
		fighters[index][fighter.fighter_id] = fighter
	client.failed.connect(func(code: String) -> void:
		if observing: errors.append("client %d: %s" % [index+1,code]))
	client.room_ready.connect(func(loadouts: Dictionary, _slot: int) -> void:
		server_room_loadouts[index]=loadouts.duplicate(true)
		check(String(loadouts.get("1",{}).get("character_id",""))=="nabi" and String(loadouts.get("2",{}).get("character_id",""))==target_character,"real server loadouts match source Nabi and requested target"))
	client.snapshot_received.connect(on_snapshot.bind(index))
	client.presentation_event_received.connect(on_event.bind(index))
	client.match_started.connect(func(_slot: int) -> void: client.qa_autoplay = true)
	if index==0: client.room_created.connect(func(code: String) -> void: invite=code)

func observed_tick() -> int:
	return maxi(last_tick[0],last_tick[1])

func both_ticks_at_least(tick: int) -> bool:
	return last_tick[0]>=tick and last_tick[1]>=tick

func ready_on_floor() -> bool:
	for index: int in 2:
		for id: String in ["lan_host","lan_guest"]:
			var value:=row(index,id)
			if value.is_empty() or value.get("state","") not in ["IDLE","RUN"] or not bool(value.get("on_floor",false)): return false
	return true

func tick_barrier(after_tick: int, label: String) -> bool:
	var minimum:=after_tick+2
	var success:=await wait_for(func() -> bool: return both_ticks_at_least(minimum),2000,label)
	tick_barriers.append({"label":label,"last_observed_tick_at_input":after_tick,"required_tick":minimum,"received_ticks_after":last_tick.duplicate(),"success":success})
	return success

func natural_scenario() -> bool:
	# The server can report a running room while both fighters still SPAWN.
	# Do not send a one-shot press until both clients observe playable ground.
	if not await wait_for(ready_on_floor,8000,"both clients see spawning finished and both fighters grounded"): return false
	var move_tick:=observed_tick()
	send_input(0,&"move",CombatIntent.Direction.RIGHT,CombatIntent.Edge.PRESS)
	send_input(1,&"move",CombatIntent.Direction.LEFT,CombatIntent.Edge.PRESS)
	if not await wait_for(func() -> bool:
		var a:=row(0,"lan_host")
		var b:=row(0,"lan_guest")
		return both_ticks_at_least(move_tick+2) and not a.is_empty() and not b.is_empty() and absf(float(a.position.x)-float(b.position.x))<70 and bool(a.on_floor) and bool(b.on_floor),5000,"actual movement to uppercut range"): return false
	var release_tick:=observed_tick()
	send_input(0,&"move",CombatIntent.Direction.RIGHT,CombatIntent.Edge.RELEASE)
	send_input(1,&"move",CombatIntent.Direction.LEFT,CombatIntent.Edge.RELEASE)
	if not await tick_barrier(release_tick,"initial movement release precedes target facing press"): return false
	var desired:=1 if view_case=="normal" else -1
	var direction:=CombatIntent.Direction.RIGHT if desired==1 else CombatIntent.Direction.LEFT
	var facing_tick:=observed_tick()
	send_input(1,&"move",direction,CombatIntent.Edge.PRESS)
	if not await wait_for(func() -> bool: return both_ticks_at_least(facing_tick+2) and int(row(0,"lan_guest").get("facing",0))==desired and int(row(1,"lan_guest").get("facing",0))==desired,2000,"both clients acknowledge actual target facing"): return false
	var facing_release_tick:=observed_tick()
	send_input(1,&"move",direction,CombatIntent.Edge.RELEASE)
	if not await tick_barrier(facing_release_tick,"target facing release precedes host re-approach"): return false
	var approach_tick:=observed_tick()
	send_input(0,&"move",CombatIntent.Direction.RIGHT,CombatIntent.Edge.PRESS)
	if not await wait_for(func() -> bool:
		var a:=row(0,"lan_host")
		var b:=row(0,"lan_guest")
		return both_ticks_at_least(approach_tick+2) and not a.is_empty() and not b.is_empty() and absf(float(b.position.x)-float(a.position.x))<60 and bool(a.on_floor) and bool(b.on_floor),3000,"real host re-approach before release"): return false
	var approach_release_tick:=observed_tick()
	send_input(0,&"move",CombatIntent.Direction.RIGHT,CombatIntent.Edge.RELEASE)
	if not await tick_barrier(approach_release_tick,"host release precedes heavy attack"): return false
	send_input(0,&"attack_heavy",CombatIntent.Direction.NEUTRAL,CombatIntent.Edge.PRESS)
	if not await wait_for(func() -> bool: return launch_seen[0] and launch_seen[1],2000,"real Nabi heavy causes target LAUNCH on both clients"): return false
	if not await wait_for(func() -> bool: return release_seen[0] and release_seen[1],2000,"actual draw observes release on both clients"): return false
	await create_timer(0.2).timeout
	return true

func safe_output_directory(value: String, case_name: String) -> bool:
	# File APIs may follow links: reject noncanonical input and every linked
	# ancestor before any report/raw stream can be opened.
	if value.is_empty() or not value.is_absolute_path() or value!=value.simplify_path(): return false
	var workspace := ProjectSettings.globalize_path("res://_workspace").simplify_path().trim_suffix("/")
	if not value.begins_with(workspace+"/") or not DirAccess.dir_exists_absolute(value): return false
	var current := value
	while true:
		var parent := current.get_base_dir()
		if parent==current or parent.is_empty(): break
		var directory := DirAccess.open(parent)
		if directory==null or directory.is_link(current.get_file()): return false
		current=parent
	var output := DirAccess.open(value)
	if output==null: return false
	for leaf: String in [case_name+"-report.json",case_name+"-client-1.rgba",case_name+"-client-2.rgba"]:
		if output.is_link(leaf) or output.file_exists(leaf) or output.dir_exists(leaf): return false
	return true

func run() -> void:
	if OS.get_environment("LAN_RELEASE_VISUAL_AUTHORIZED")!="root-reviewed-render-and-sockets":
		push_error("Prepared only: root authorization is required before GUI/socket execution")
		quit(1); return
	DIR = OS.get_environment("LAN_RELEASE_OUTPUT_DIR")
	var requested_case := OS.get_environment("LAN_RELEASE_VISUAL_CASE")
	if requested_case not in ["normal","mirror"] or not safe_output_directory(DIR,requested_case):
		push_error("QA output must be an existing canonical absolute workspace directory with no linked ancestors or existing report/raw paths")
		quit(1); return
	DIR += "/"
	mode = OS.get_environment("LAN_RELEASE_MODE")
	if mode.is_empty(): mode="natural"
	check(mode in ["natural","attack","jump"],"known QA case")
	target_character=OS.get_environment("LAN_RELEASE_TARGET_CHARACTER")
	check(target_character in ["ja-hyun","nabi"],"known target profile")
	view_case=OS.get_environment("LAN_RELEASE_VISUAL_CASE")
	check(view_case in ["normal","mirror"],"known actual facing case")
	check(mode=="natural","visual fixture runs only natural release")
	if DisplayServer.get_name()=="headless":
		push_error("real rendering backend is required; headless capture is forbidden")
		quit(1); return
	if FileAccess.file_exists(DIR+view_case+"-report.json"):
		push_error("QA output already exists")
		quit(1); return
	var script_path := OS.get_environment("LAN_RELEASE_PRESENTATION")
	if script_path.is_empty(): script_path="res://scripts/local_fighter_presentation.gd"
	if script_path!="res://scripts/local_fighter_presentation.gd":
		push_error("Visual fixture requires the public presentation")
		quit(1); return
	presentation_script = load(script_path) as GDScript
	prepare_viewports()
	if not errors.is_empty():
		for raw: FileAccess in raw_files: raw.close()
		for message: String in errors: push_error(message)
		quit(1); return
	prepare_candidates()
	prepare_client(0)
	prepare_client(1)
	RenderingServer.frame_post_draw.connect(on_frame_post_draw)
	render_relay=RenderRelay.new()
	render_relay.process_priority=10000
	render_relay.step=Callable(self,"render_step")
	root.add_child(render_relay)
	observing = true
	var host_selection := LoadoutSelection.new()
	host_selection.character_id = &"nabi"
	var guest_selection := LoadoutSelection.new()
	guest_selection.character_id = StringName(target_character)
	var url := OS.get_environment("FOREST_ARENA_LAN_TEST_WS_URL")
	var hosting:=clients[0].begin_host(LanInvite.host_code(url,"http://127.0.0.1:18081"),host_selection,"","host")
	check(hosting,"public authenticated host API")
	var joined:=false
	if hosting and await wait_for(func() -> bool: return not invite.is_empty(),5000,"authenticated room create"):
		joined=clients[1].begin_join(invite,guest_selection,"","guest")
		check(joined,"public authenticated join API")
	var running:=false
	if joined: running=await wait_for(func() -> bool: return clients[0].running and clients[1].running and not row(0,"lan_guest").is_empty(),5000,"two actual sockets match start")
	if running:
		for loadouts: Dictionary in server_room_loadouts:
			check(not loadouts.is_empty() and String(loadouts.get("1",{}).get("character_id",""))=="nabi" and String(loadouts.get("2",{}).get("character_id",""))==target_character,"both real clients received matching authoritative room loadouts")
		check(clients[0].local_slot==1 and clients[1].local_slot==2,"owned fighter IDs mapped from real local slots")
		if errors.is_empty(): await natural_scenario()
	# Finish the pending native draw before closing the raw streams.
	if capture_pending: await RenderingServer.frame_post_draw
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
		var drawn_order: Array[int]=[]
		for frame: int in selected:
			if drawn_order.is_empty() or drawn_order[-1]!=frame: drawn_order.append(frame)
		if mode=="natural": check(drawn_order==[12,13,14,15],"each real socket actually draws all four release poses in order; ordinary held-pose repeats allowed")
		else: check(followup_rendered,"received followup result is displayed; delivery may follow natural release completion")
		followup_display_summary.append({"client_slot":index+1,"release_frames":selected,"followup_rendered":followup_rendered,"first_followup_render_tick":first_followup_tick,"release_incomplete_before_followup":followup_rendered and selected.size()<4,"note":"network delivery may occur after natural completion; headless public test separately proves immediate cancellation for already-applied input results"})
		check(release_seen[index],"release observed for owned and remote Ja")
	check(events.any(func(e: Dictionary) -> bool: return e.event_id=="hit_resolved" and e.payload.get("result")=="HIT" and e.payload.get("defender_id")=="lan_guest"),"actual server HIT event received")
	clients[1].leave()
	await create_timer(0.15).timeout
	clients[0].request_rematch(false)
	await create_timer(0.15).timeout
	for client: LanMatchClient in clients: client.stop()
	for raw: FileAccess in raw_files: raw.close()
	for capture: Dictionary in capture_manifest:
		if capture.trace.release_active: check(int(capture.trace.draw_observation.draw_received_snapshot.facing)==(1 if view_case=="normal" else -1),"release pixels use actual requested server facing")
	check(not capture_manifest.is_empty(),"actual rendered captures saved")
	var omitted_snapshots: Array[Dictionary]=[]
	for arrival: Dictionary in arrivals:
		if arrival.kind=="snapshot" and not sync_snapshot_ids.has(arrival.arrival_id) and not draw_snapshot_ids.has(arrival.arrival_id): omitted_snapshots.append(arrival)
	var report := {"status":"pass" if errors.is_empty() else "fix","checks":checks,"errors":errors,"mode":mode,"scope":"real-socket public-presentation fixture, not actual app HUD footage; native draw stamped backend RGBA with separate sync/draw receive states; immediate proxy packet apply; semantic QA/Android separate","visual_case":view_case,"target_character":target_character,"server_room_loadouts":server_room_loadouts,"rendering_method":RenderingServer.get_current_rendering_method(),"capture_manifest":capture_manifest,"arrival_log":arrivals,"input_tick_barriers":tick_barriers,"render_process_priority":10000,"snapshots_neither_synced_nor_observed_at_draw":omitted_snapshots,"skipped_process_while_draw_pending":skipped_process_while_pending,"unpaired_sync_packets":unpaired_syncs,"frame_pairing":"native AnimatedSprite2D.draw pose/texture/transform plus same-draw pixel stamp; readback at frame_post_draw; immediate network apply; sync and draw receipt state separated","presentation":script_path,"catalog_sha256":FileAccess.get_sha256(CATALOG),"owned_ids":{"1":"lan_host","2":"lan_guest"},"all_snapshots_omit_stun":all_snapshots_omit_stun,"latest_received_snapshots":latest,"inputs":inputs,"events":events,"trace":trace,"followup_display_summary":followup_display_summary}
	FileAccess.open(DIR+view_case+"-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	for error: String in errors: push_error(error)
	print("LAN_LAUNCH_RELEASE_VISUAL "+view_case+": "+("PASS" if errors.is_empty() else "FAIL")+" (%d checks)"%checks)
	for map: Dictionary in fighters:
		for fighter: FighterController in map.values(): fighter.free()
	for client: LanMatchClient in clients: client.free()
	if render_relay!=null: render_relay.free()
	for viewport: SubViewport in viewports: viewport.free()
	root.get_node("ForestArenaAudio").shutdown()
	quit(0 if errors.is_empty() else 1)
