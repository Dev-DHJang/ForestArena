extends SceneTree

const GEOMETRY := preload("res://scripts/combat_ui_geometry.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message): failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var transformed := GEOMETRY.logical_safe_rect(Rect2(0, 0, 1280, 720), Rect2(180, 40, 2400, 1300), Transform2D(Vector2(2, 0), Vector2(0, 2), Vector2(100, 20)))
	check(transformed == Rect2(40, 10, 1200, 650), "safe area converts scaled and translated screen pixels")
	check(GEOMETRY.logical_safe_rect(Rect2(0, 0, 1280, 720), Rect2(), Transform2D.IDENTITY) == Rect2(0, 0, 1280, 720), "missing device safe area keeps logical viewport")
	var hud: Control = load("res://scripts/forestlight_match_hud.gd").new()
	var touch: Control = load("res://scripts/touch_command_source.gd").new()
	touch.extended_actions = true
	touch.forestlight_controls = true
	root.add_child(hud)
	root.add_child(touch)
	await process_frame
	for width: int in [1280, 1600]:
		root.size = Vector2i(width, 720)
		await process_frame
		var safe := Rect2(30, 18, width - 70, 668)
		hud.safe_area_override = safe
		touch.safe_area_override = safe
		touch._layout_visuals()
		for scale_value: float in [1.0, 1.3]:
			touch.apply_accessibility({"text_scale": scale_value})
			for count: int in [2, 4, 8]:
				var participants := {}
				var fighters: Array = []
				for index: int in count:
					var id := "lan_host" if index == 0 else ("lan_guest" if index == 1 else "ai_%d" % index)
					participants[StringName(id)] = {"character_id": ["ja-hyun", "myo-ryung", "nabi", "yu-ran"][index % 4], "character_name": ["자현", "묘령", "나비", "유란"][index % 4], "nickname": "참가자 %d" % index, "team_id": "alpha" if index % 2 == 0 else "beta"}
					fighters.append({"id": id, "team_id": participants[StringName(id)].team_id, "current_hp": 87 + index, "max_hp": 100, "stocks": 3, "guard_durability": 20 + index * 20, "special_cooldown_ticks": 60 if index == 0 else 0, "ultimate_gauge": 0 if index == 0 else 100, "ultimate_used_this_stock": false})
				var snapshot := {"fighters": fighters, "guard_max": 100, "ultimate_gauge_max": 100}
				var before := JSON.stringify(snapshot)
				for team_value: bool in [false, true]:
					hud.configure(participants, scale_value, &"lan_guest", team_value)
					hud.update_snapshot(snapshot)
					await process_frame
					check(hud.cards.size() == count, "every participant gets a compact card")
					var map_rect := Rect2(safe.end.x - 256, safe.position.y + 16, 240, 150)
					for card: Dictionary in hud.cards.values():
						var bounds: Rect2 = card.panel.get_global_rect()
						check(safe.encloses(bounds), "HUD cards fit safe area")
						for key: String in ["title", "face", "hp", "health", "stocks"]:
							check(bounds.encloses(card[key].get_global_rect()), "actual accessible HUD child fits its card " + key)
						check(bounds.end.y <= safe.position.y + 172, "HUD uses at most two short rows")
						check(not bounds.intersects(map_rect), "compact HUD preserves minimap reservation")
						check(card.face.size == Vector2(32, 32) and card.face.texture is AtlasTexture, "approved logical face atlas displays at 32 pixels")
						check(card.title.get_theme_font_size("font_size") == roundi(16 * scale_value), "HUD uses accessible 16-pixel base text")
						check(card.stocks.size.x >= 70, "remaining chances keep readable space")
					if not team_value and count == 2:
						check(hud.cards.lan_guest.panel.position.x < hud.cards.lan_host.panel.position.x, "LAN guest receives local card on the left")
						check(hud.cards.lan_guest.title.text.begins_with("P2"), "local card preserves participant number")
					if team_value:
						check(hud._fighter_ids[0] == "lan_host" and hud._fighter_ids[1] == ("ai_2" if count >= 4 else "lan_guest"), "team sorting preserves original participant numbers")
				touch.local_fighter_id = &"lan_guest"
				touch.update_snapshot(snapshot)
				check(touch._guard_bar.value == 40 and touch._status_labels[&"attack_special"].text == "준비" and touch._status_labels[&"ultimate"].text == "준비", "readiness uses actual LAN guest rather than first fighter")
				touch.local_fighter_id = &"lan_host"
				touch.update_snapshot(snapshot)
				check(touch._status_labels[&"attack_special"].text == "1.0초" and touch._status_labels[&"ultimate"].text == "0%", "cooldown and ultimate values stay beside relevant controls")
				check(JSON.stringify(snapshot) == before, "HUD and readiness never mutate supplied snapshot")
			for action: StringName in touch.ACTIONS:
				var rect: Rect2 = touch.diagnostic_regions()[action]
				check(safe.encloses(rect), "action geometry fits simulated notch and bottom inset " + String(action))
				check(touch._action_for(rect.get_center()) == action, "visual center and hit region agree " + String(action))
				check(rect.size == Vector2.ONE * (96 if action == &"attack_light" else (64 if action == &"ultimate" else 80)), "action diameters match approved layout " + String(action))
				for other: StringName in touch.ACTIONS:
					if other != action: check(not rect.intersects(touch.diagnostic_regions()[other]), "action regions do not overlap")
			var regions: Dictionary = touch.diagnostic_regions()
			var light_center: Vector2 = regions[&"attack_light"].get_center()
			var heavy_center: Vector2 = regions[&"attack_heavy"].get_center()
			check(heavy_center.x > light_center.x and heavy_center.y < light_center.y, "heavy sits above and right of central light")
			check(regions[&"jump"].get_center().y > light_center.y and regions[&"evade"].get_center().y > light_center.y, "jump and evade sit below light")
			check(regions[&"attack_special"].get_center().y < light_center.y and regions[&"ultimate"].get_center().y < heavy_center.y, "special and ultimate sit on upper outer arc")
			for label: Label in touch._status_labels.values():
				for action: StringName in touch.ACTIONS:
					check(not label.get_rect().intersects(regions[action]), "readiness text never overlaps action hit region")
			check(touch._action_for(Vector2(safe.end.x - 12, safe.end.y - 12)).is_empty(), "empty corner never activates an action")
			check(touch._action_for(Vector2(safe.end.x + 1, safe.end.y - 100)).is_empty(), "unsafe screen inset never activates an action")
			var pad: Rect2 = touch._joystick_touch_rect
			check(safe.encloses(pad), "joystick fits device safe area")
			await process_frame
			check(touch._guard_bar.get_global_rect().size.y <= 8 and touch._guard_bar.get_combined_minimum_size().y <= 8, "guard bar stays thin after actual frame layout")
			touch._assign(1, pad.get_center() + Vector2(pad.size.x * 0.35, 0))
			touch._assign(2, touch.diagnostic_regions()[&"attack_heavy"].get_center())
			check(Input.is_action_pressed(&"move_right") and Input.is_action_pressed(&"attack_heavy"), "move and held heavy coexist")
			touch.notification(Control.NOTIFICATION_RESIZED)
			check(touch._touch_actions.is_empty() and not Input.is_action_pressed(&"attack_heavy") and not Input.is_action_pressed(&"move_right"), "resize releases contacts before relocating hit regions")
			check(touch._action_for(touch.diagnostic_regions()[&"attack_light"].get_center()) == &"attack_light", "resize retains aligned hit region")
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	scene.app_shell_mode = true
	# This presentation check never advances combat or stale touch edges.
	scene.get_node("MatchController").set_physics_process(false)
	root.add_child(scene)
	scene.get_node("MatchController").set_physics_process(false)
	await process_frame
	var controller: MatchController = scene.get_node("MatchController")
	controller.set_physics_process(false)
	var before_hash := controller.snapshot_hash()
	var camera: Camera2D = scene.get_node("Camera2D")
	camera._process(0.016)
	scene._render_snapshot(controller.snapshot())
	check(is_equal_approx(camera.zoom.x, 1.5) and camera.position == controller.player.global_position, "closer fixed camera still follows local fighter")
	check(before_hash == controller.snapshot_hash(), "camera and common HUD preserve live combat snapshot")
	var many_participants := {}
	var many_fighters: Array = []
	for index: int in 8:
		var id := String(controller.player.fighter_id) if index == 0 else (String(controller.training_dummy.fighter_id) if index == 1 else "extra_%d" % index)
		many_participants[StringName(id)] = {"character_id": "ja-hyun", "character_name": "자현", "team_id": ""}
		many_fighters.append({"id": id, "current_hp": 100, "max_hp": 100, "stocks": 3})
	scene.forestlight_hud.configure(many_participants, 1.3, controller.player.fighter_id)
	scene.forestlight_hud.update_snapshot({"fighters": many_fighters})
	controller.player.global_position = Vector2(640, 520)
	controller.training_dummy.global_position = Vector2(640, -2000)
	camera._process(0.016)
	await process_frame
	var indicator: OffscreenOpponentIndicator = scene.get_node("Interface/OffscreenOpponentIndicator")
	var before_arrow := controller.snapshot_hash()
	indicator.update_indicator()
	check(indicator.visible and indicator.arrow_direction.y < 0, "fully hidden upper enemy shows an upward arrow")
	check(indicator.arrow_position.y - 20 >= scene.forestlight_hud.get_global_rect().end.y + 8, "large eight-player HUD stays above the complete arrow tip")
	for card: Dictionary in scene.forestlight_hud.cards.values():
		check(not card.panel.get_global_rect().intersects(Rect2(indicator.arrow_position - Vector2(20, 20), Vector2(40, 40))), "upper arrow leaves every status card clear")
	check(before_arrow == controller.snapshot_hash(), "dynamic arrow region never mutates combat")
	var map_bounds: Rect2 = scene.minimap.get_global_rect()
	var pause_bounds := Rect2(map_bounds.position + Vector2(0, map_bounds.size.y + 12), Vector2(map_bounds.size.x, 58))
	for direction: Vector2 in [Vector2(1, -0.1), Vector2(1, -1), Vector2(-1, -1), Vector2.UP]:
		controller.training_dummy.global_position = controller.player.global_position + direction * 4000
		await process_frame
		indicator.update_indicator()
		var arrow_bounds := Rect2(indicator.arrow_position - Vector2(20, 20), Vector2(40, 40))
		check(indicator.visible and not arrow_bounds.intersects(map_bounds) and not arrow_bounds.intersects(pause_bounds), "diagonal arrow leaves minimap and pause reservation clear")

	controller.training_dummy.global_position = controller.player.global_position + Vector2(camera.get_viewport_rect().size.x / camera.zoom.x / 2 - 7, 0)
	await process_frame
	indicator.update_indicator()
	check(not indicator.visible, "partly exposed enemy still hides its arrow with large HUD")
	controller.training_dummy.state = FighterController.State.MATCH_ENDED
	controller.training_dummy.global_position = Vector2(640, -2000)
	indicator.update_indicator()
	check(not indicator.visible, "ended opponent keeps the dynamic arrow hidden")

	scene.queue_free()
	hud.queue_free()
	touch.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	print("MATCH_PLAYTEST_UI: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
