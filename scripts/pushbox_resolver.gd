class_name PushboxResolver
extends RefCounted

const PASSES_PER_FIGHTER := 4


static func resolve(fighters: Array[FighterController]) -> void:
	var active: Array[FighterController] = []
	for fighter: FighterController in fighters:
		if fighter != null and fighter.state not in [FighterController.State.SPAWNING, FighterController.State.RING_OUT, FighterController.State.DEAD, FighterController.State.MATCH_ENDED]:
			active.append(fighter)
	active.sort_custom(func(a: FighterController, b: FighterController) -> bool: return a.fighter_id < b.fighter_id)
	for ignored_pass: int in maxi(4, active.size() * PASSES_PER_FIGHTER):
		var moved := false
		for left_index: int in active.size():
			for right_index: int in range(left_index + 1, active.size()):
				moved = _separate_pair(active[left_index], active[right_index]) or moved
		if not moved:
			break


static func _separate_pair(first: FighterController, second: FighterController) -> bool:
	var first_box := first.get_pushbox_rect()
	var second_box := second.get_pushbox_rect()
	if not first_box.intersects(second_box):
		return false
	var overlap := minf(first_box.end.x, second_box.end.x) - maxf(first_box.position.x, second_box.position.x)
	if overlap <= 0.0:
		return false
	var first_is_left := first_box.get_center().x < second_box.get_center().x
	if is_equal_approx(first_box.get_center().x, second_box.get_center().x):
		first_is_left = first.fighter_id < second.fighter_id
	# A small fixed clearance prevents multi-fighter half-overlap relaxation from
	# asymptotically leaving sub-pixel intersections.
	var half := overlap * 0.5 + 0.5
	first.global_position.x += -half if first_is_left else half
	second.global_position.x += half if first_is_left else -half
	return true
