extends SceneTree

const PATHS := [
	"res://assets/combat/movesets/ja_hyun_moveset.tres",
	"res://assets/combat/movesets/myo_ryung_moveset.tres",
	"res://assets/combat/movesets/nabi_moveset.tres",
	"res://assets/combat/movesets/yu_ran_moveset.tres",
]


func _init() -> void:
	for path: String in PATHS:
		var move_set := load(path) as MoveSetData
		if move_set == null:
			push_error("Move removal load failed: %s" % path)
			quit(1)
			return
		for index: int in range(move_set.slots.size() - 1, -1, -1):
			var slot: MoveSlotData = move_set.slots[index]
			if slot.attack != null and slot.attack.action_id == &"grab":
				move_set.slots.remove_at(index)
		if not move_set.is_valid_definition() or ResourceSaver.save(move_set, path) != OK:
			push_error("Move removal save failed: %s" % path)
			quit(1)
			return
	print("REMOVE_GRAB_MOVES: PASS")
	quit(0)
