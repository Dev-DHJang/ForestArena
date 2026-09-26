class_name LocalPlayCatalog
extends RefCounted

const ACCESSORIES := [
	["iron_armor", "철갑옷", "무게 증가 · 슈퍼아머"],
	["boxing_gloves", "복싱 글러브", "이동 속도 증가 · 기술 목록 교체"],
	["thorns", "가시 갑옷", "피해를 받으면 반사 피해"],
	["explosive_gloves", "폭발 장갑", "적중 시 추가 피해"],
	["ultimate_charm", "필살 장신구", "적중 시 궁극기 게이지 추가"],
	["phoenix_revive", "1회 부활 장신구", "마지막 기회 소진 시 한 번, HP 35로 부활"],
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
