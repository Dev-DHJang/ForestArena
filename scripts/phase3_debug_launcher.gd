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
@onready var bot_profile: OptionButton = %BotProfile
@onready var scenario: OptionButton = %Scenario
@onready var apply_button: Button = %ApplyConfiguration
@onready var close_button: Button = %CloseLauncher
@onready var status: Label = %LauncherStatus


func _ready() -> void:
	visible = OS.is_debug_build()
	if not visible:
		return
	_fill(player_character, CHARACTERS, 0)
	_fill(dummy_character, CHARACTERS, 1)
	_sync_job_options(player_character, player_job)
	_sync_job_options(dummy_character, dummy_job)
	_fill(bot_profile, BOT_PROFILES, 0)
	_fill(scenario, SCENARIOS, 0)
	player_character.item_selected.connect(func(_index: int) -> void: _sync_job_options(player_character, player_job))
	dummy_character.item_selected.connect(func(_index: int) -> void: _sync_job_options(dummy_character, dummy_job))
	apply_button.pressed.connect(_request_configuration)
	close_button.pressed.connect(func() -> void: dismissed.emit())


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
		"bot_profile_id": _selected_id(bot_profile),
		"scenario_id": _selected_id(scenario),
	}
	configuration_requested.emit(configuration)


func _selected_id(option: OptionButton) -> StringName:
	return StringName(option.get_item_metadata(option.selected))
