class_name LocalMatchParticipant
extends RefCounted

const SCHEMA_VERSION := 1

var schema_version := SCHEMA_VERSION
var participant_id: StringName
var selection := LoadoutSelection.new()
var team_id: StringName
var human_controlled := false


func is_valid_definition() -> bool:
	return schema_version == SCHEMA_VERSION and not participant_id.is_empty() and selection != null and selection.is_valid_definition()
