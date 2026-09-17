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
		if move_set == null or not move_set.is_valid_definition():
			push_error("invalid v2 moveset: %s" % path)
			quit(1)
			return
		if ResourceSaver.save(move_set, path) != OK:
			push_error("save failed: %s" % path)
			quit(1)
			return
	print("COMBAT_V2_RESAVE: PASS")
	quit(0)
