extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,720)
	var catalog := LocalPlayCatalog.new()
	var original := load("res://assets/loadouts/default_loadout_catalog.tres") as LoadoutCatalog
	var original_moves := original.character_by_id(&"ja-hyun").base_move_set
	check(catalog.combat.characters.size() == 4 and catalog.products.size() == 10, "all historical IDs remain in full catalog")
	check(catalog.playable_characters().size() == 2 and catalog.playable_products().size() == 2, "only two active characters are offered")
	check(catalog.combat.character_by_id(&"ja-hyun").base_move_set != original_moves and original.character_by_id(&"ja-hyun").base_move_set == original_moves, "product move replacement cannot mutate source catalog")
	var store := LocalPlayerStore.new(catalog, "user://two-fighter-%d.json" % Time.get_ticks_usec())
	var old := LocalPlayerStore.fresh_data()
	old.first_granted = true
	old.characters = ["myo-ryung", "yu-ran"]
	old.accessories = ["fixture-boxing-gloves", "fixture-ultimate-charm"]
	old.selected_character = "yu-ran"
	old.selected_accessory = "fixture-boxing-gloves"
	old.opponent_character = "myo-ryung"
	var before := old.duplicate(true)
	var normalized := store.migrate_profile(old)
	check(old == before and normalized.characters == ["myo-ryung", "yu-ran", "ja-hyun"] and normalized.accessories == old.accessories, "old ownership retained while granting an available fighter")
	check(normalized.selected_character == "ja-hyun" and normalized.selected_accessory == "" and normalized.opponent_character == "ja-hyun", "old selection normalizes to playable no-accessory combat")
	check(store.migrate_profile(normalized) == normalized, "selection upgrade is idempotent")
	var writer := FileAccess.open(store.path, FileAccess.WRITE)
	writer.store_string(JSON.stringify(old))
	writer.close()
	var old_bytes := FileAccess.get_file_as_bytes(store.path)
	check(store.load_profile(), "v3 normalization loads and commits")
	check(store.data.selected_character == normalized.selected_character and store.data.selected_accessory == "" and store.data.opponent_character == "ja-hyun" and store.data.characters == normalized.characters and store.data.accessories == old.accessories, "v3 normalization publishes the normalized selection")
	check(FileAccess.get_file_as_bytes(store.path + ".bak") == old_bytes, "v3 normalization backs up old source bytes")
	var blocked := LocalPlayerStore.new(catalog, "user://missing-two-fighter-%d/profile.json" % Time.get_ticks_usec())
	var blocked_before := blocked.data.duplicate(true)
	check(not blocked.call("_load_candidate", old) and blocked.data == blocked_before, "failed normalization save cannot replace live memory")

	store.data = normalized
	check(not store.select("yu-ran", "", "nabi") and not store.select("ja-hyun", "fixture-boxing-gloves", "nabi"), "new inactive or accessory selection is rejected")
	check(not store.purchase("fixture-thorns") and not store.grant_first("myo-ryung"), "new inactive products cannot be granted or purchased")
	var touch: Control = load("res://scripts/touch_command_source.gd").new()
	touch.forestlight_controls = true
	touch.simplified_controls = true
	root.add_child(touch)
	await process_frame
	check(touch.ACTIONS.size() == 4 and not touch.ACTIONS.has(&"evade") and not touch.ACTIONS.has(&"ultimate"), "product has exactly four action buttons")
	var observation := {"fighters":[{"id":"player", "on_floor":false,"air_light_used":true,"air_heavy_used":false,"air_lock":0,"special_cooldown_ticks":0,"guard_durability":100}]}
	var copied := observation.duplicate(true)
	touch.update_snapshot(observation)
	check(touch._is_action_unready(&"attack_light") and not touch._is_action_unready(&"attack_heavy") and touch._is_action_unready(&"attack_special"), "air-use and ground-only cues read independent slots")
	check(touch._status_labels[&"attack_special"].text == "지상 전용" and observation == copied, "airborne special cue cannot mutate combat")
	var landed := {"fighters":[{"id":"player", "on_floor":true, "air_lock":0, "landing_down_ticks":18, "special_cooldown_ticks":0}]}
	var landed_copy := landed.duplicate(true)
	touch.update_snapshot(landed)
	for action: StringName in touch.ACTIONS: check(touch._is_action_unready(action), "landing down disables every action cue after air lock clears")
	for action: StringName in [&"attack_light", &"attack_heavy", &"attack_special"]: check(touch._status_labels[action].text == "행동 불가", "landing down cannot display a ready attack")
	check(landed == landed_copy, "landing down readiness preserves the combat snapshot")
	landed.fighters[0].landing_down_ticks = 0
	touch.update_snapshot(landed)
	for action: StringName in touch.ACTIONS: check(not touch._is_action_unready(action), "wake up restores readiness from the next snapshot")
	for action: StringName in touch.ACTIONS:
		var rect: Rect2 = touch.diagnostic_regions()[action]
		check(touch._action_for(rect.get_center()) == action, "button visual and hit region agree")
	for width: int in [1280,1600]:
		root.size = Vector2i(width,720)
		await process_frame
		for text_scale: float in [1.0,1.3]:
			touch.apply_accessibility({"text_scale":text_scale})
			for button_scale: float in [1.0,1.2]:
				touch.apply_menu_controls({"joystick_mode":"fixed","button_scale":button_scale,"button_transparency":0})
				var regions: Dictionary = touch.diagnostic_regions()
				for action: StringName in touch.ACTIONS:
					var rect: Rect2 = regions[action]
					check(rect.size.is_equal_approx(Vector2.ONE * (96 if action == &"attack_light" else 80) * button_scale), "four action diameters scale from approved base")
					for other: StringName in touch.ACTIONS:
						if other != action: check(not rect.intersects(regions[other]), "scaled product buttons never overlap")
	var bot := LocalAICommandSource.new(&"bot", 7, {"simplified_combat":true,"heavy_range":300})
	var actor := {"id":"bot","on_floor":true,"state":"IDLE","position":Vector2(500,572),"velocity":Vector2.ZERO,"air_jumps":1,"stocks":3,"special_cooldown_ticks":0}
	var target := {"id":"target","on_floor":true,"state":"IDLE","position":Vector2(560,572),"stocks":3}
	var view := {"fighters":[actor,target]}
	var seen := {}
	for tick: int in range(1,1801):
		for command: CombatIntent in bot.commands_for_tick(tick,view):
			check(command.action_id not in [&"dash",&"evade",&"ultimate"] and not (command.action_id == &"attack_heavy" and command.edge == CombatIntent.Edge.RELEASE), "AI never emits removed or charge-release commands")
			seen[command.action_id] = true
	check(seen.has(&"attack_heavy") and seen.has(&"attack_light"), "AI uses single heavy and light attacks")
	check(LanInvite.PROTOCOL_VERSION == 3 and LanMatchClient.PROTOCOL_VERSION == 3, "LAN uses protocol three")
	var server: Node = load("res://server/game/lan_game_server.gd").new()
	server.catalog = catalog.combat
	for selection: Dictionary in [{"schema_version":1,"character_id":"myo-ryung","job_id":"","accessory_id":""},{"schema_version":1,"character_id":"nabi","job_id":"","accessory_id":"fixture-thorns"}]:
		check(server.call("_selection_from", selection) == null, "server rejects inactive fighter and accessory bypasses")
	check(server.call("_selection_from", {"schema_version":1,"character_id":"nabi","job_id":"","accessory_id":""}) != null, "server accepts playable unmodified loadout")
	server.free()

	check(LanInvite.parse_host_code("FAH2|http://127.0.0.1:3001|ws://127.0.0.1:7778|2").get("error") == "unsupported_protocol", "previous LAN protocol is rejected explicitly")
	var app: Node = load("res://scenes/local_ai_app.tscn").instantiate()
	app.save_path = "user://two-fighter-app-%d.json" % Time.get_ticks_usec()
	root.add_child(app)
	await process_frame
	check(app.store.grant_first("nabi"), "first grant accepts active fighter")
	app.selected_mode = LocalMatchConfig.Mode.SOLO
	app.solo_participant_count = 8
	app.start_match()
	await physics_frame
	check(app.match_controller.rules.simplified_combat and app.match_controller.rules.special_cooldown_ticks == 300, "actual product uses a private simplified rule instance")
	for fighter: FighterController in app.match_controller.call("_fighters"):
		check(catalog.is_playable_character(fighter.runtime_profile.character_id) and fighter.runtime_profile.accessory_id == &"", "actual eight-player match uses only active fighters without accessories")
	check((load("res://assets/combat/phase1_combat_rules.tres") as CombatRules).simplified_combat == false, "legacy rule source remains untouched")
	touch.hide() # The independent input fixture must not cover the actual app capture.
	for count: int in [2,4,8]:
		app.solo_participant_count = count
		app.start_match()
		await physics_frame
		app.match_controller.set_physics_process(false)
		var live_touch: Control = app.match_scene.get_node("Interface/TouchCommandSource")
		var live_hud: Control = app.match_scene.forestlight_hud
		check(live_touch.simplified_controls and live_touch.ACTIONS.size() == 4 and live_hud.cards.size() == count, "real product combines four buttons with %d HUD cards" % count)
		for width: int in [1280,1600]:
			root.size = Vector2i(width,720)
			await process_frame
			for text_scale: float in [1.0,1.3]:
				app.match_scene.apply_accessibility({"text_scale":text_scale})
				app.match_scene._render_snapshot(app.match_controller.snapshot())
				await process_frame
				var map_bounds: Rect2 = app.match_scene.minimap.get_global_rect()
				var before_ui: String = app.match_controller.snapshot_hash()
				for card: Dictionary in live_hud.cards.values():
					var bounds: Rect2 = card.panel.get_global_rect()
					check(root.get_visible_rect().encloses(bounds) and not bounds.intersects(map_bounds), "real product HUD stays inside screen and outside minimap")
					for key: String in ["title","face","hp","health","stocks"]: check(bounds.encloses(card[key].get_global_rect()), "real product accessible card contains " + key)
					for action: StringName in live_touch.ACTIONS: check(not bounds.intersects(live_touch.diagnostic_regions()[action]), "real product HUD leaves four actions clear")
				for action: StringName in live_touch.ACTIONS:
					var rect: Rect2 = live_touch.diagnostic_regions()[action]
					check(live_touch._action_for(rect.get_center()) == action and root.get_visible_rect().encloses(rect), "real product visual and touch remain aligned at both aspect ratios")
				check(not live_touch._status_labels.has(&"ultimate") and before_ui == app.match_controller.snapshot_hash(), "real product has no ultimate indicator and UI cannot mutate combat")
				if "--capture" in OS.get_cmdline_user_args():
					var directory := "res://_workspace/two-fighter-combat-v2/qa/hud-captures"
					DirAccess.make_dir_recursive_absolute(directory)
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(directory.path_join("hud-%d-%d-%.1f.png" % [count,width,text_scale]))

	var app_path: String = app.save_path
	app.queue_free()
	touch.queue_free()
	await process_frame
	for path: String in [store.path,app_path]:
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	for failure: String in failures: push_error(failure)
	print("TWO_FIGHTER_PRODUCT: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
