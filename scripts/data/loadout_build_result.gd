class_name LoadoutBuildResult
extends RefCounted

const ERR_INVALID_SELECTION := &"invalid_selection"
const ERR_INVALID_CATALOG := &"invalid_catalog"
const ERR_MISSING_CHARACTER := &"missing_character"
const ERR_MISSING_JOB := &"missing_job"
const ERR_MISSING_ACCESSORY := &"missing_accessory"
const ERR_UNSUPPORTED_SCHEMA := &"unsupported_schema"
const ERR_UNALLOWED_JOB := &"unallowed_job"
const ERR_INVALID_PARENT := &"invalid_parent"
const ERR_JOB_CYCLE := &"job_cycle"
const ERR_CONFLICT := &"conflict"
const ERR_INVALID_PROFILE := &"invalid_profile"
const ERR_MISSING_PASSIVE := &"missing_passive"
const ERR_DEPRECATED_FIELD := &"deprecated_field"

var profile: RuntimeCombatProfile
var error_codes: Array[StringName] = []


func succeeded() -> bool:
	return profile != null and error_codes.is_empty()


static func success(value: RuntimeCombatProfile) -> LoadoutBuildResult:
	var result := LoadoutBuildResult.new()
	result.profile = value
	return result


static func failure(code: StringName) -> LoadoutBuildResult:
	var result := LoadoutBuildResult.new()
	result.error_codes.append(code)
	return result
