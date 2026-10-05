extends Node

const MainScene = preload("res://scenes/main.tscn")


func _ready() -> void:
	var failures: Array[String] = []
	_test_token(failures)
	_test_authority_helpers(failures)
	if failures.is_empty():
		print("ONLINE_CONTRACT: PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures: push_error(failure)
		get_tree().quit(1)


func _test_token(failures: Array[String]) -> void:
	var secret := "0123456789abcdef0123456789abcdef"
	var now := int(Time.get_unix_time_from_system())
	var claims := {"kind": "match", "sub": "player-a", "match_id": "match-a", "slot": 1, "character_id": "ja-hyun", "nonce": "nonce-a", "iat": now, "exp": now + 60}
	var header := Marshalls.raw_to_base64(JSON.stringify({"alg": "HS256", "typ": "JWT"}).to_utf8_buffer()).replace("+", "-").replace("/", "_").trim_suffix("=")
	var payload := Marshalls.raw_to_base64(JSON.stringify(claims).to_utf8_buffer()).replace("+", "-").replace("/", "_").trim_suffix("=")
	var signing_input := "%s.%s" % [header, payload]
	var context := HMACContext.new()
	context.start(HashingContext.HASH_SHA256, secret.to_utf8_buffer())
	context.update(signing_input.to_utf8_buffer())
	var signature := Marshalls.raw_to_base64(context.finish()).replace("+", "-").replace("/", "_").trim_suffix("=")
	var verified := OnlineTokenVerifier.verify_match_token("%s.%s" % [signing_input, signature], secret, now)
	if verified.get("sub") != "player-a" or int(verified.get("slot", 0)) != 1: failures.append("valid match token was rejected")
	if not OnlineTokenVerifier.verify_match_token("%s.%sx" % [signing_input, signature], secret, now).is_empty(): failures.append("modified match token was accepted")
	if not OnlineTokenVerifier.verify_match_token("%s.%s" % [signing_input, signature], secret, now + 60).is_empty(): failures.append("expired match token was accepted")


func _test_authority_helpers(failures: Array[String]) -> void:
	var root := MainScene.instantiate()
	root.set("app_shell_mode", true)
	add_child(root)
	var controller := root.get_node("MatchController") as MatchController
	controller.set_physics_process(false)
	controller.step_fixed_tick(false)
	var snapshot := controller.network_snapshot()
	var first: Dictionary = snapshot.fighters[0]
	if not first.position is Dictionary or not first.velocity is Dictionary: failures.append("network snapshot contains non-JSON vectors")
	controller.player.input_direction = CombatIntent.Direction.RIGHT
	controller.release_fighter_input(&"ja-hyun")
	if controller.player.input_direction != CombatIntent.Direction.NEUTRAL: failures.append("disconnect input release failed")
	controller.finish_forfeit(&"myo-ryung")
	if controller.winner_id != &"ja-hyun": failures.append("disconnect forfeit did not produce the opponent winner")
	root.queue_free()
