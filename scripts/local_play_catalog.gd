class_name LocalPlayCatalog
extends RefCounted

const ACCESSORIES := [
	["iron_armor", "철갑옷", "무게 +5% · 지상 속도 -5%"],
	["boxing_gloves", "복싱 글러브", "유란 기술 목록으로 교체 · 속도 보너스 없음"],
	["thorns", "균형 장신구", "공중 속도 +5% · 지상 속도 -5%"],
	["explosive_gloves", "도약 장갑", "점프 속도 +5% · 무게 -5%로 더 잘 밀려남"],
	["ultimate_charm", "집중 장신구", "유효 적중 시 궁극기 게이지 +4 · 지상 속도 -5%"],
	["phoenix_revive", "활공 장신구", "중력 -5% · 공중 속도 -5%"],
]
var combat: LoadoutCatalog
var products: Array[Dictionary] = []

func _init() -> void:
	combat = (load("res://assets/loadouts/default_loadout_catalog.tres") as LoadoutCatalog).duplicate(true)
	combat.accessories.clear()
	for character: CharacterData in combat.characters:
		products.append({"kind": "character", "id": String(character.character_id), "name": character.display_name, "description": character.combat_role, "price": 0, "asset_id": String(character.concept_asset_id)})
	for entry: Array in ACCESSORIES:
		var accessory := load("res://assets/loadouts/fixtures/%s_accessory.tres" % entry[0]) as AccessoryData
		combat.accessories.append(accessory)
		products.append({"kind": "accessory", "id": String(accessory.accessory_id), "name": entry[1], "description": entry[2], "price": 0, "asset_id": "fa.icon.icon.accessory"})

func product(id: String) -> Dictionary:
	for item: Dictionary in products:
		if item.id == id: return item
	return {}

func contains(id: String, kind: String) -> bool:
	var item := product(id)
	return not item.is_empty() and item.kind == kind
