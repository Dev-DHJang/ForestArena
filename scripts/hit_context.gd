class_name HitContext
extends RefCounted

var tick := 0
var attacker: FighterController
var defender: FighterController
var attack: AttackData
var source_position := Vector2.ZERO
var target_position := Vector2.ZERO
var source_facing := 1
var source_direction: CombatIntent.Direction = CombatIntent.Direction.NEUTRAL


func _init(value_tick := 0, value_attacker: FighterController = null, value_defender: FighterController = null, value_attack: AttackData = null) -> void:
	tick = value_tick
	attacker = value_attacker
	defender = value_defender
	attack = value_attack
