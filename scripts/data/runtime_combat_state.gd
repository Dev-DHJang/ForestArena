class_name RuntimeCombatState
extends RefCounted

var current_hp: float = 0.0
var stocks: int = 0
var state_id: StringName = &"IDLE"
var active_attack_id: StringName
var velocity := Vector2.ZERO
var grounded := false
var guarding := false
var guard_durability := 0.0
var invulnerability_ticks := 0
var hitstun_ticks := 0
var knockdown_ticks := 0
var respawn_ticks := 0
## Zero means an ordinary full-HP return; effects may specify the next return HP.
var pending_respawn_hp := 0.0
var special_cooldown_ticks := 0
var ultimate_gauge := 0.0
var ultimate_used_this_stock := false
var evade_ticks := 0
var charge_ticks := 0
var platform_drop_ticks := 0
var revive_used := false


func reset(max_hp: float, initial_stocks: int, guard_max: float) -> void:
	current_hp = max_hp
	stocks = initial_stocks
	state_id = &"IDLE"
	active_attack_id = &""
	velocity = Vector2.ZERO
	grounded = false
	guarding = false
	guard_durability = guard_max
	invulnerability_ticks = 0
	hitstun_ticks = 0
	knockdown_ticks = 0
	respawn_ticks = 0
	pending_respawn_hp = 0.0
	special_cooldown_ticks = 0
	ultimate_gauge = 0.0
	ultimate_used_this_stock = false
	evade_ticks = 0
	charge_ticks = 0
	platform_drop_ticks = 0
	revive_used = false
