extends SceneTree

const CONTRACT_PATH := "res://docs/ui/combat-ui-v01.json"
const REQUIRED_IDS := [
	"CBT_01_Match_1v1", "CBT_02_Match_Solo8", "CBT_03_Match_Team4v4", "CBT_04_Practice",
	"CBT_05_ControlPressed", "CBT_06_RingOutRespawn", "CBT_07_SuddenDeath", "CBT_08_Pause",
	"CBT_09_ResumePrompt", "CBT_10_MatchEndTransition",
]


func _initialize() -> void:
	var failures: PackedStringArray = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
	if not (parsed is Dictionary):
		failures.append("combat UI contract is not a JSON object")
	else:
		_validate(parsed as Dictionary, failures)
	if failures.is_empty():
		print("combat_ui_design_contract: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _validate(contract: Dictionary, failures: PackedStringArray) -> void:
	if contract.get("schema_version") != 1 or contract.get("status") != "accepted-design-contract":
		failures.append("combat UI schema or status drift")
	var scope: Dictionary = contract.get("scope", {})
	if scope.get("current_phase") != 2 or scope.get("godot-runtime_implementation") != false or scope.get("combat_authority") != "read-only-presentation":
		failures.append("combat UI scope or authority drift")
	var resolution: Dictionary = contract.get("resolution", {})
	var penpot_size: Array = resolution.get("penpot_reference", [])
	var runtime_size: Array = resolution.get("runtime_logical", [])
	if penpot_size.size() != 2 or int(penpot_size[0]) != 1920 or int(penpot_size[1]) != 1080 \
			or runtime_size.size() != 2 or int(runtime_size[0]) != 1280 or int(runtime_size[1]) != 720:
		failures.append("combat UI resolution drift")
	var baseline: Dictionary = contract.get("current_input_baseline", {})
	if baseline.get("safe_edge_ratio") != 0.065 or baseline.get("input_bottom_start_ratio") != 0.58:
		failures.append("touch baseline drift")
	if baseline.get("right_actions") != ["dash", "jump", "attack_light", "attack_heavy", "attack_special"]:
		failures.append("touch action order drift")
	var rules: Dictionary = contract.get("presentation_rules", {})
	if rules.get("hud_calculates_combat") != false or rules.get("prohibited_current_controls") != ["guard", "evade", "grab_support", "ultimate"]:
		failures.append("combat presentation boundary drift")
	var seen: Dictionary = {}
	for screen_value: Variant in contract.get("screens", []):
		if not (screen_value is Dictionary):
			failures.append("combat screen is not an object")
			continue
		var screen: Dictionary = screen_value
		var screen_id := String(screen.get("id", ""))
		if screen_id.is_empty() or seen.has(screen_id):
			failures.append("missing or duplicate combat screen ID: %s" % screen_id)
		else:
			seen[screen_id] = true
	if seen.size() != REQUIRED_IDS.size():
		failures.append("expected 10 combat UI screens but found %d" % seen.size())
	for screen_id: String in REQUIRED_IDS:
		if not seen.has(screen_id):
			failures.append("required combat screen is missing: %s" % screen_id)
	var proposed: Array = contract.get("proposed_review_frames", [])
	if proposed.size() != 2 or String((proposed[0] as Dictionary).get("status", "")) != "proposed":
		failures.append("responsive proposal frames drift")
	var mapping: Dictionary = contract.get("asset_mapping", {})
	if mapping.get("logical_id_count") != 8 or mapping.get("placeholder_policy") != "exact-logical-id-visible-until-approved":
		failures.append("combat asset placeholder mapping drift")
