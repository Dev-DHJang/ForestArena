extends SceneTree

var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func _initialize() -> void:
	var catalog := LocalPlayCatalog.new()
	var path := "user://test-local-%d.json" % Time.get_ticks_usec()
	var store := LocalPlayerStore.new(catalog, path)
	check(catalog.combat.is_valid_definition(), "real catalog valid")
	check(store.load_profile() and not store.data.first_granted, "fresh install")
	check(store.grant_first("nabi"), "first character grant")
	check(not store.grant_first("ja-hyun"), "one grant only")
	check(not store.select("ja-hyun", "", "nabi"), "unowned rejected")
	for item: Dictionary in catalog.products:
		if not store.owns(item.id): check(store.purchase(item.id), "purchase " + item.id)
		check(not store.purchase(item.id), "duplicate " + item.id)
	check(not store.purchase("unknown"), "unknown product")
	check(store.select("yu-ran", String(catalog.combat.accessories[0].accessory_id), "yu-ran"), "mirror selection")
	var reload := LocalPlayerStore.new(catalog, path)
	check(reload.load_profile(), "restart loads")
	for key: String in ["characters", "accessories", "selected_character", "selected_accessory", "opponent_character", "first_granted"]:
		check(reload.data[key] == store.data[key], "restart preserves " + key)
	for character: CharacterData in catalog.combat.characters:
		for accessory: AccessoryData in catalog.combat.accessories:
			var selection := LoadoutSelection.new()
			selection.character_id = character.character_id
			selection.accessory_id = accessory.accessory_id
			check(LoadoutBuilder.build(selection, catalog.combat).succeeded(), "all character accessory combinations")
	var old_data := store.data.duplicate(true)
	store.path = "user://missing-directory-%d/profile.json" % Time.get_ticks_usec()
	check(not store.select("nabi", "", "ja-hyun") and store.data == old_data, "save failure rolls back memory")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("invalid json")
	file.close()
	check(reload.load_profile() and reload.recovered, "corrupt main recovers backup")
	var invalid := LocalPlayerStore.fresh_data()
	invalid.schema_version = 0
	check(not store.valid(invalid), "unsupported schema rejected")
	invalid = LocalPlayerStore.fresh_data()
	invalid.characters = ["nabi"]
	check(not store.valid(invalid), "grant invariant enforced")
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	for failure: String in failures: push_error(failure)
	print("LOCAL_PLAYER_STORE: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
