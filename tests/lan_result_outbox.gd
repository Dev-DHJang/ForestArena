extends SceneTree
const OUTBOX = preload("res://server/game/lan_result_outbox.gd")
var failures: Array[String] = []
var checks := 0
var directory := "user://qa/lan_outbox_%d" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, name: String) -> void:
	checks += 1
	if not value: failures.append(name)

func write(path: String, source: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("queue.json")
	var queue := OUTBOX.new()
	root.add_child(queue)
	queue.set_process(false)
	check(queue.configure("http://127.0.0.1:18081", "secret-for-test", path), "fresh queue config")
	var match_id := DbProfileClient._uuid()
	var route := "/internal/v1/lan/matches/" + match_id
	check(queue.enqueue(route + "/register", {"participants": []}, match_id), "registration is durable before network")
	check(queue.enqueue(route + "/result", {"reason": "draw"}, match_id), "result is durable before network")
	check(queue.state_for(match_id) == "pending" and queue.jobs.size() == 2, "pending status")
	check(not FileAccess.get_file_as_string(path).contains("secret-for-test"), "service credential never saved")
	var restart := OUTBOX.new()
	root.add_child(restart)
	restart.set_process(false)
	check(restart.configure(queue.api_url, "rotated-token", path), "process restart restores queue with new service token")
	check(restart.jobs == queue.jobs, "restart retains immutable job IDs and payloads")
	check(restart._blocked(restart.jobs[1]) and not restart._blocked(restart.jobs[0]), "result cannot overtake registration")
	restart._active_id = restart.jobs[0].id
	restart._completed(HTTPRequest.RESULT_CANT_CONNECT, 0, [], PackedByteArray())
	check(restart.jobs.size() == 2 and restart.state_for(match_id) == "pending", "empty network failure preserves jobs without parser error")
	restart._active_id = restart.jobs[0].id
	restart._completed(HTTPRequest.RESULT_SUCCESS, 503, [], '{"error":"unavailable"}'.to_utf8_buffer())
	check(restart.jobs.size() == 2 and not restart.jobs[0].failed and restart._next_attempt_msec > Time.get_ticks_msec(), "temporary failure keeps queue with backoff")
	restart._active_id = restart.jobs[0].id
	restart._completed(HTTPRequest.RESULT_SUCCESS, 400, [], '{"error":"invalid"}'.to_utf8_buffer())
	check(restart.jobs.size() == 2 and restart.jobs[0].failed and restart._blocked(restart.jobs[1]), "permanent failure is visible and preserves dependent result")
	check(restart.retry_failed() and not restart.jobs[0].failed, "explicit retry retains jobs")
	restart._active_id = restart.jobs[0].id
	restart._completed(HTTPRequest.RESULT_SUCCESS, 200, [], '{"status":"duplicate"}'.to_utf8_buffer())
	check(restart.jobs.size() == 1 and not restart._blocked(restart.jobs[0]), "idempotent acknowledgement releases next job")
	restart._active_id = restart.jobs[0].id
	restart._completed(HTTPRequest.RESULT_SUCCESS, 200, [], '{"status":"stored"}'.to_utf8_buffer())
	check(restart.jobs.is_empty() and restart.state_for(match_id) == "stored", "acknowledged result is removed durably")
	var backup_before := FileAccess.get_file_as_string(path + ".bak")
	write(path, "{broken")
	var recovery := OUTBOX.new()
	root.add_child(recovery)
	recovery.set_process(false)
	check(recovery.configure(queue.api_url, "token", path) and recovery.jobs.size() == 1, "corrupt primary replays valid backup")
	check(recovery.enqueue("/internal/v1/lan/rooms", {"state":"closed"}), "recovered queue can save")
	check(FileAccess.get_file_as_string(path + ".bak") == backup_before, "corrupt primary never replaces good backup")
	var foreign := OUTBOX.new()
	root.add_child(foreign)
	foreign.set_process(false)
	check(not foreign.configure("http://127.0.0.1:19090", "token", path), "queue cannot cross backend endpoint")
	write(path, '{"schema_version":99,"jobs":[]}')
	var future := OUTBOX.new()
	root.add_child(future)
	future.set_process(false)
	check(not future.configure(queue.api_url, "token", path) and FileAccess.get_file_as_string(path).contains("99"), "future version rejected without downgrade")
	var blocked_path := directory.path_join("blocked.json")
	DirAccess.make_dir_recursive_absolute(blocked_path + ".tmp")
	var blocked := OUTBOX.new()
	root.add_child(blocked)
	blocked.set_process(false)
	check(blocked.configure(queue.api_url, "token", blocked_path), "blocked storage initializes without loss")
	check(not blocked.enqueue(route + "/register", {}, match_id) and blocked.jobs.size() == 1 and blocked.state_for(match_id) == "save_failed", "disk failure remains explicit and never claims stored")
	for node: Node in [queue, restart, recovery, foreign, future, blocked]: node.queue_free()
	await process_frame
	if failures.is_empty(): print("lan_result_outbox: PASS (%d checks)" % checks)
	else:
		for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
