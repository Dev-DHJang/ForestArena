extends SceneTree

## Explicit v2 -> v3 migration for CombatRules. Loading an older schema is not
## accepted by CombatRules.is_valid_definition; this one-shot migration writes
## the newly explicit gauge and platform-drop defaults into repository data.
const PATH := "res://assets/combat/phase1_combat_rules.tres"


func _init() -> void:
	var rules := load(PATH) as CombatRules
	if rules == null:
		push_error("CombatRules load failed: %s" % PATH)
		quit(1)
		return
	rules.schema_version = 3
	if not rules.is_valid_definition():
		push_error("CombatRules v3 is invalid: %s" % PATH)
		quit(1)
		return
	if ResourceSaver.save(rules, PATH) != OK:
		push_error("CombatRules v3 save failed: %s" % PATH)
		quit(1)
		return
	print("COMBAT_V3_RESAVE: PASS")
	quit(0)
