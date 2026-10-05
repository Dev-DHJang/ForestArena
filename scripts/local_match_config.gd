class_name LocalMatchConfig
extends RefCounted

const SCHEMA_VERSION := 2
const STAGE_ID := &"forest-ledge"
enum Mode { STORY, SOLO, TEAM, AI, PRACTICE }

var schema_version := SCHEMA_VERSION
var mode: Mode = Mode.AI
var participants: Array[LocalMatchParticipant] = []
var player := LoadoutSelection.new()
var opponent := LoadoutSelection.new()
var stage_id := STAGE_ID
var seed := 3001
var reaction_interval_ticks := 12


func is_valid_definition() -> bool:
	if schema_version != SCHEMA_VERSION or stage_id.is_empty() or participants.size() < 2 or participants.size() > 8 or reaction_interval_ticks < 1:
		return false
	var ids: Dictionary = {}
	var human_count := 0
	var team_sizes: Dictionary = {}
	for participant: LocalMatchParticipant in participants:
		if participant == null or not participant.is_valid_definition() or ids.has(participant.participant_id): return false
		ids[participant.participant_id] = true
		if participant.human_controlled: human_count += 1
		if mode == Mode.TEAM:
			if participant.team_id.is_empty(): return false
			team_sizes[participant.team_id] = int(team_sizes.get(participant.team_id, 0)) + 1
		elif not participant.team_id.is_empty():
			return false
	if human_count != 1: return false
	match mode:
		Mode.STORY, Mode.AI, Mode.PRACTICE:
			return participants.size() == 2
		Mode.SOLO:
			return true
		Mode.TEAM:
			if team_sizes.size() != 2: return false
			for size: int in team_sizes.values():
				if size < 1 or size > 4: return false
			return true
	return false

static func from_store(store: LocalPlayerStore) -> LocalMatchConfig:
	if not store.valid(store.data) or not store.data.first_granted: return null
	var config := LocalMatchConfig.new()
	config.player.character_id = StringName(store.data.selected_character)
	config.player.accessory_id = StringName(store.data.selected_accessory)
	config.opponent.character_id = StringName(store.data.opponent_character)
	config.participants = [
		_participant(&"player", config.player, true),
		_participant(&"opponent", config.opponent, false),
	]
	return config


static func _participant(id: StringName, selection: LoadoutSelection, human_controlled: bool) -> LocalMatchParticipant:
	var participant := LocalMatchParticipant.new()
	participant.participant_id = id
	participant.selection = selection.duplicate(true) as LoadoutSelection
	participant.human_controlled = human_controlled
	return participant
