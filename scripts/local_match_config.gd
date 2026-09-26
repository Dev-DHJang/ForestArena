class_name LocalMatchConfig
extends RefCounted

const STAGE_ID := &"forest-ledge"
var player := LoadoutSelection.new()
var opponent := LoadoutSelection.new()
var stage_id := STAGE_ID
var seed := 3001
var reaction_interval_ticks := 12

static func from_store(store: LocalPlayerStore) -> LocalMatchConfig:
	if not store.valid(store.data) or not store.data.first_granted: return null
	var config := LocalMatchConfig.new()
	config.player.character_id = StringName(store.data.selected_character)
	config.player.accessory_id = StringName(store.data.selected_accessory)
	config.opponent.character_id = StringName(store.data.opponent_character)
	return config
