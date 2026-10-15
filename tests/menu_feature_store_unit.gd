extends SceneTree
var failures: Array[String] = []
var checks := 0
var directory := "user://menu-feature-store-unit-%d" % Time.get_ticks_usec()
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func event(index: int, when: String, character := "ja-hyun", mode := "ai", outcome := "win") -> Dictionary:
	return {"event_id": "event-%d" % index, "owner": "device", "service_id": "", "canonical_player_id": "", "sent": false, "mode": mode, "outcome": outcome, "character_id": character, "ended_at": when}
func mission(data: Dictionary, id: String) -> Dictionary:
	for row: Dictionary in data.missions:
		if row.id == id: return row
	return {}
func run() -> void:
	var store := MenuFeatureStore.new(directory)
	check(store.load_all(), "fresh journals load without network")
	var before: Dictionary = store.progress.duplicate(true)
	check(not store.append_offline(event(0, "2026-10-14T15:00:00Z", "bad"), "bad"), "invalid character cannot enter outbox")
	check(store.progress == before, "failed event leaves memory unchanged")
	var when := "2026-10-14T15:00:00Z"
	for index: int in 4: check(store.append_offline(event(index, when, ["ja-hyun", "myo-ryung", "nabi", "yu-ran"][index], "ai" if index == 0 else "solo", "win" if index == 0 else "loss"), str(index)), "append actual event %d" % index)
	check(store.append_offline(event(0, when), "0") and store.progress.events.size() == 4, "same completed match is durable once")
	var now := int(Time.get_unix_time_from_datetime_string("2026-10-15T14:59:59"))
	var data := MenuFeatureStore.summarize(_events(store), now)
	check(mission(data, "daily-play").period == "2026-10-15" and mission(data, "daily-play").current == 4, "KST midnight belongs next local day")
	check(mission(data, "weekly-play").period == "2026-10-12", "week begins KST Monday")
	check(mission(data, "all-characters").current == 4 and mission(data, "all-characters").completed, "character achievement is distinct set")
	check(data.stats.offline == {"played": 4, "wins": 1, "losses": 3, "draws": 0} and data.stats.lan.played == 0, "local offline totals cannot become LAN totals")
	check(data.stats.modes.ai.played == 1 and data.stats.modes.solo.played == 3, "mode totals remain separate")
	var tomorrow := MenuFeatureStore.summarize(_events(store), int(Time.get_unix_time_from_datetime_string("2026-10-15T15:00:00")))
	check(mission(tomorrow, "daily-play").current == 0 and mission(tomorrow, "weekly-play").current == 4, "KST next day resets only daily")
	check(store.bind_events(["device"], "service-A", "player-A"), "unassigned events bind to verified owner")
	check(store.pending_events("service-B", "player-A").is_empty() and store.pending_events("service-A", "player-B").is_empty(), "service or account mismatch cannot expose outbox")
	check(store.pending_events("service-A", "player-A").size() == 4, "verified owner receives own pending events")
	check(store.accept_events(["event-0"], "service-B", "player-A") and store.pending_events("service-A", "player-A").size() == 4, "wrong service acknowledgement does not mark sent")
	check(store.accept_events(["event-0"], "service-A", "player-A") and store.pending_events("service-A", "player-A").size() == 3, "exact accepted IDs mark sent")
	var large: Dictionary = store.progress.duplicate(true)
	for index: int in range(10, 70):
		var added := event(index, when)
		added.service_id = "service-A"
		added.canonical_player_id = "player-A"
		large.events.append(added)
	check(store.save_progress(large) and store.pending_events("service-A", "player-A").size() == 50 and store.pending_events("service-A", "player-A", [], 0).size() == 63, "POST batch is capped but snapshot retains every pending result")
	var intent := {"request_id": "immutable-merge", "payload": {"nickname": "숲지기", "source_access_token": "fake-proof-for-test"}}
	check(store.begin_merge(intent), "immutable intent saved before network")
	var primary := JSON.parse_string(FileAccess.get_file_as_string(directory + "/menu_identity_v01.json")) as Dictionary
	var backup := JSON.parse_string(FileAccess.get_file_as_string(directory + "/menu_identity_v01.json.bak")) as Dictionary
	check(primary == backup and primary.intent == intent, "primary and backup both contain same pending intent")
	check(not store.begin_merge({"request_id": "replacement"}), "pending request cannot be replaced")
	var restored := MenuFeatureStore.new(directory)
	check(restored.load_all() and restored.identity.intent == intent and restored.progress.events.size() == 64, "restart preserves original intent and offline IDs")
	check(restored.save_receipt({"canonical_player_id": "player-A"}), "successful server receipt saved before app callback")
	check(restored.identity.intent.request_id == "immutable-merge", "receipt does not change original request")
	var operation := {"operation_id": "operation-1", "service_id": "service-A", "canonical_player_id": "player-A", "payload": {"action": "request"}}
	check(restored.add_operation(operation), "social operation durable before HTTP")
	check(restored.remove_operation("other") and restored.identity.operations.size() == 1, "unrelated operation cannot remove pending social")
	check(restored.remove_operation("operation-1") and restored.identity.operations.is_empty(), "exact social receipt clears pending")
	var blocked_path := directory + "/blocked"
	DirAccess.make_dir_recursive_absolute(blocked_path)
	var future := FileAccess.open(blocked_path + "/menu_identity_v01.json", FileAccess.WRITE)
	future.store_string('{"schema_version":99}')
	future.close()
	var invalid := MenuFeatureStore.new(blocked_path)
	check(not invalid.load_all() and invalid.blocked, "unknown schema blocks all journal mutation")
	check(not invalid.begin_merge(intent) and FileAccess.get_file_as_string(blocked_path + "/menu_identity_v01.json") == '{"schema_version":99}', "unknown primary cannot be overwritten by default state")
	_cleanup(directory)
	for failure: String in failures: push_error(failure)
	print("MENU_FEATURE_STORE_UNIT: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
func _events(store: MenuFeatureStore) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in store.progress.events: result.append(item)
	return result
func _cleanup(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	for child: String in dir.get_directories(): _cleanup(path.path_join(child))
	for file: String in dir.get_files(): DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
