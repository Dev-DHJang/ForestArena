extends Node
## Runs after both default-priority LanMatchClient nodes have polled snapshots.
var step: Callable
func _process(delta: float) -> void:
	if step.is_valid(): step.call(delta)
