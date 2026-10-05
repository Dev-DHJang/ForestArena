class_name OnlineTokenVerifier
extends RefCounted


static func verify_match_token(token: String, secret: String, now_unix: int) -> Dictionary:
	var parts := token.split(".")
	if parts.size() != 3: return {}
	var signing_input := "%s.%s" % [parts[0], parts[1]]
	var context := HMACContext.new()
	if context.start(HashingContext.HASH_SHA256, secret.to_utf8_buffer()) != OK: return {}
	if context.update(signing_input.to_utf8_buffer()) != OK: return {}
	var expected := context.finish()
	var supplied := _decode_base64url(parts[2])
	if supplied.size() != expected.size() or not _constant_time_equal(supplied, expected): return {}
	var parsed: Variant = JSON.parse_string(_decode_base64url(parts[1]).get_string_from_utf8())
	if not parsed is Dictionary: return {}
	var claims: Dictionary = parsed
	if claims.get("kind") != "match" or String(claims.get("sub", "")).is_empty(): return {}
	if int(claims.get("exp", 0)) <= now_unix or int(claims.get("iat", 0)) > now_unix + 30: return {}
	if int(claims.get("slot", 0)) not in [1, 2]: return {}
	if String(claims.get("character_id", "")) not in ["ja-hyun", "myo-ryung"]: return {}
	if String(claims.get("match_id", "")).is_empty() or String(claims.get("nonce", "")).is_empty(): return {}
	return claims


static func _decode_base64url(value: String) -> PackedByteArray:
	var normalized := value.replace("-", "+").replace("_", "/")
	while normalized.length() % 4 != 0: normalized += "="
	return Marshalls.base64_to_raw(normalized)


static func _constant_time_equal(left: PackedByteArray, right: PackedByteArray) -> bool:
	var difference := 0
	for index: int in left.size(): difference |= left[index] ^ right[index]
	return difference == 0
