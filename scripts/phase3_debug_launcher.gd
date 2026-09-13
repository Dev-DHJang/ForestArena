class_name Phase3DebugLauncher
extends PanelContainer

signal configuration_requested(configuration: Dictionary)
signal dismissed

const CHARACTERS := [
	{"label": "자현", "id": "ja-hyun"},
	{"label": "묘령", "id": "myo-ryung"},
	{"label": "나비", "id": "nabi"},
]
const JOB_BY_CHARACTER := {
	"ja-hyun": [{"label": "stage 1 · 방어", "id": "ja-hyun-guard-prototype"}, {"label": "stage 2 · 보루", "id": "ja-hyun-bulwark-prototype"}, {"label": "stage 2 · 리본 카운터", "id": "ja-hyun-ribbon-counter-prototype"}],
	"myo-ryung": [{"label": "stage 1 · 공중", "id": "myo-ryung-aerial-prototype"}, {"label": "stage 2 · 스카이 댄서", "id": "myo-ryung-sky-dancer-prototype"}, {"label": "stage 2 · 게일 다이버", "id": "myo-ryung-gale-diver-prototype"}],
	"nabi": [{"label": "stage 1 · 근접압박", "id": "nabi-close-pressure-prototype"}, {"label": "stage 2 · 러시클로", "id": "nabi-rushclaw-prototype"}, {"label": "stage 2 · 아이언 파운스", "id": "nabi-iron-pounce-prototype"}],
}
const BOT_PROFILES := [
	{"label": "간격형", "id": "spacing"},
	{"label": "공중형", "id": "aerial"},
	{"label": "근접형", "id": "close"},
]
const ACCESSORIES := [
	{"label": "없음", "id": ""},
	{"label": "나무껍질 수호 부적", "id": "bark-guard-charm"},
	{"label": "하늘 해류 부적", "id": "sky-current-charm"},
	{"label": "도약 가시 부적", "id": "pouncing-thorn-charm"},
]
const JOB_SUMMARIES := {
	"": "기본형 · 부모 없음 · stage 0 · 직업 modifier/passive/cancel 없음",
	"ja-hyun-guard-prototype": "root · stage 1 · 가드 용량/회복 강화",
	"ja-hyun-bulwark-prototype": "부모 방어 · stage 2 · 가드 +15/+3 · 보루 강공격 패시브 · 강→특수 취소",
	"ja-hyun-ribbon-counter-prototype": "부모 방어 · stage 2 · 지상 속도 +12 · 회피 반격 패시브 · 약→강 취소",
	"myo-ryung-aerial-prototype": "root · stage 1 · 공중 이동/회피 강화",
	"myo-ryung-sky-dancer-prototype": "부모 공중 · stage 2 · 공중 +25/점프 +20 · 공중 반격 패시브 · 공중 약→점프 취소",
	"myo-ryung-gale-diver-prototype": "부모 공중 · stage 2 · 아래 특수 강화 · cooldown 패시브 · 공중 강→특수 취소",
	"nabi-close-pressure-prototype": "root · stage 1 · 지상/대시 압박 강화",
	"nabi-rushclaw-prototype": "부모 근접압박 · stage 2 · 대시 +30/+0.02s · 약공격 패시브 · 대시 약→약 취소",
	"nabi-iron-pounce-prototype": "부모 근접압박 · stage 2 · 지상 +12/강 가드 ×1.25 · 회피 cooldown 패시브 · 강→대시 취소",
}
const SCENARIOS := [
	{"label": "표준 3-stock", "id": "standard-3-stock"},
	{"label": "방어 압박", "id": "guard-pressure"},
	{"label": "회피 대응", "id": "evade-response"},
	{"label": "궁극기 포착", "id": "ultimate-capture"},
]

@onready var player_character: OptionButton = %PlayerCharacter
@onready var player_job: OptionButton = %PlayerJob
@onready var dummy_character: OptionButton = %DummyCharacter
@onready var dummy_job: OptionButton = %DummyJob
@onready var player_accessory: OptionButton = %PlayerAccessory
@onready var dummy_accessory: OptionButton = %DummyAccessory
@onready var bot_profile: OptionButton = %BotProfile
@onready var scenario: OptionButton = %Scenario
@onready var apply_button: Button = %ApplyConfiguration
@onready var close_button: Button = %CloseLauncher
@onready var status: Label = %LauncherStatus
@onready var summary: Label = %JobSummary


func _ready() -> void:
	visible = OS.is_debug_build()
	if not visible:
		return
	_fill(player_character, CHARACTERS, 0)
	_fill(dummy_character, CHARACTERS, 1)
	_sync_job_options(player_character, player_job)
	_sync_job_options(dummy_character, dummy_job)
	_fill(player_accessory, ACCESSORIES, 0)
	_fill(dummy_accessory, ACCESSORIES, 0)
	_fill(bot_profile, BOT_PROFILES, 0)
	_fill(scenario, SCENARIOS, 0)
	player_character.item_selected.connect(func(_index: int) -> void: _sync_job_options(player_character, player_job); _update_summary())
	dummy_character.item_selected.connect(func(_index: int) -> void: _sync_job_options(dummy_character, dummy_job); _update_summary())
	player_job.item_selected.connect(func(_index: int) -> void: _update_summary())
	dummy_job.item_selected.connect(func(_index: int) -> void: _update_summary())
	apply_button.pressed.connect(_request_configuration)
	close_button.pressed.connect(func() -> void: dismissed.emit())
	_update_summary()


func set_status(message: String, succeeded: bool) -> void:
	status.text = message
	status.add_theme_color_override("font_color", Color("9ee493") if succeeded else Color("ffb3c1"))


func _fill(option: OptionButton, entries: Array, selected_index: int) -> void:
	option.clear()
	for entry: Dictionary in entries:
		option.add_item(String(entry.label))
		option.set_item_metadata(option.item_count - 1, String(entry.id))
	option.select(selected_index)


func _sync_job_options(character: OptionButton, job: OptionButton) -> void:
	var character_id := String(character.get_item_metadata(character.selected))
	var entries: Array = [{"label": "기본", "id": ""}]
	if JOB_BY_CHARACTER.has(character_id):
		entries.append_array(JOB_BY_CHARACTER[character_id])
	_fill(job, entries, 0)


func _request_configuration() -> void:
	var configuration := {
		"player_character_id": _selected_id(player_character),
		"player_job_id": _selected_id(player_job),
		"dummy_character_id": _selected_id(dummy_character),
		"dummy_job_id": _selected_id(dummy_job),
		"player_accessory_id": _selected_id(player_accessory),
		"dummy_accessory_id": _selected_id(dummy_accessory),
		"bot_profile_id": _selected_id(bot_profile),
		"scenario_id": _selected_id(scenario),
	}
	configuration_requested.emit(configuration)


func _update_summary() -> void:
	if summary == null:
		return
	summary.text = "P1 %s\nP2 %s" % [JOB_SUMMARIES.get(String(_selected_id(player_job)), "unknown"), JOB_SUMMARIES.get(String(_selected_id(dummy_job)), "unknown")]


func _selected_id(option: OptionButton) -> StringName:
	return StringName(option.get_item_metadata(option.selected))
