class_name AndroidQaCommandSource
extends LocalAICommandSource
## Test policy can withhold ultimate input while the normal gauge is earned.
var allow_ultimate := true
func commands_for_tick(tick: int, match_snapshot: Dictionary) -> Array[CombatIntent]:
	var commands := super.commands_for_tick(tick, match_snapshot)
	if not allow_ultimate:
		commands = commands.filter(func(intent: CombatIntent) -> bool: return intent.action_id != &"ultimate")
	return commands
