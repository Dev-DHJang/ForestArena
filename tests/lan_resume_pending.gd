extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:
 call_deferred('run')
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label)
func run() -> void:
 var server: Node=load('res://tests/fixtures/lan_resume_server_probe.gd').new()
 var match_root: Node=load('res://scenes/main.tscn').instantiate()
 root.add_child(match_root)
 await process_frame
 server.controller=match_root.get_node('MatchController')
 server.controller.set_physics_process(false)
 var token='synthetic-fixture-not-a-real-secret'
 server.clients={1:{'player_id':'fixture-player','nickname':'fixture-name','connected':true,'deadline':0,'reconnect_token':token,'peer_id':11,'last_seq':123}}
 server._resume(22,token,'fixture-player')
 check(server.rejected.size()==1 and server.rejected[0].code=='resume_pending','valid authenticated reconnect waits for old connected socket')
 check(server.clients[1].peer_id==11 and not server.peer_to_slot.has(22),'pending reconnect never steals occupied slot')
 server.rejected.clear()
 server._resume(22,'wrong-fixture-token','fixture-player')
 check(server.rejected.size()==1 and server.rejected[0].code=='resume_rejected','invalid token remains terminal even while connected')
 server.rejected.clear()
 server.clients[1].connected=false
 server.clients[1].deadline=Time.get_ticks_msec()+60000
 server._resume(22,token,'fixture-player')
 check(server.rejected.is_empty() and server.peer_to_slot.get(22)==1 and server.clients[1].last_seq==-1,'same token resumes same slot after old socket is disconnected')
 check(server.sent.any(func(message: Dictionary) -> bool:return message.type=='joined' and message.resumed and message.slot==1),'resumed reply reaches the client after successful slot restoration')
 var client: Node=load('res://scripts/network/lan_match_client.gd').new()
 client.active=true;client.running=true;client._reconnecting=true
 var deadline=Time.get_ticks_msec()+60000
 client._reconnect_deadline_msec=deadline
 client._last_direction=CombatIntent.Direction.RIGHT
 Input.action_press(&'attack_light');Input.action_press(&'move_right')
 var errors: Array[String]=[]
 client.failed.connect(func(code: String) -> void:errors.append(code))
 client._handle_message(JSON.stringify({'protocol_version':2,'type':'error','code':'resume_pending'}))
 check(client.active and client.running and client._reconnecting and errors.is_empty(),'pending does not leave match or emit failed')
 check(client._reconnect_deadline_msec==deadline and client._reconnect_at_msec>Time.get_ticks_msec(),'retry has bounded backoff without extending grace')
 check(client._last_direction==CombatIntent.Direction.NEUTRAL and not Input.is_action_pressed(&'move_right') and not Input.is_action_pressed(&'attack_light'),'pending releases real input actions')
 client._handle_message(JSON.stringify({'protocol_version':2,'type':'joined','slot':1,'reconnect_token':'rotated-synthetic','names':{}}))
 check(client.local_slot==1 and not client._reconnecting and client._reconnect_deadline_msec==0,'normal joined resets original reconnect state')
 client._handle_message(JSON.stringify({'protocol_version':2,'type':'error','code':'resume_rejected'}))
 check(not client.active and errors==['resume_rejected'],'invalid resume still terminates safely')
 client.active=true;client.running=true;client._reconnecting=true;client._reconnect_deadline_msec=Time.get_ticks_msec()-1
 client._handle_message(JSON.stringify({'protocol_version':2,'type':'error','code':'resume_pending'}))
 check(not client.active,'expired pending never extends reconnect window')
 client.free();server.free();match_root.queue_free()
 await process_frame
 for failure: String in failures:push_error(failure)
 print('LAN_RESUME_PENDING: '+('PASS' if failures.is_empty() else 'FAIL')+' (isolated fixture; no physical-device claim)')
 quit(0 if failures.is_empty() else 1)
