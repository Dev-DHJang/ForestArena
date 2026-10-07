class_name LanInvite
extends RefCounted

const PROTOCOL_VERSION := 1
const HOST_PREFIX := "FAH1"
const INVITE_PREFIX := "FA1"
const ROOM_CODE_LENGTH := 8


static func host_code(websocket_url: String) -> String:
	return "%s|%s|%d" % [HOST_PREFIX, websocket_url, PROTOCOL_VERSION] if valid_private_websocket_url(websocket_url) else ""


static func invite_code(websocket_url: String, room_code: String) -> String:
	var normalized := room_code.strip_edges().to_upper()
	if not valid_private_websocket_url(websocket_url) or not valid_room_code(normalized): return ""
	return "%s|%s|%s|%d" % [INVITE_PREFIX, websocket_url, normalized, PROTOCOL_VERSION]


static func parse_host_code(value: String) -> Dictionary:
	var parts := value.strip_edges().split("|", false)
	if parts.size() != 3 or parts[0] != HOST_PREFIX or int(parts[2]) != PROTOCOL_VERSION:
		return {"error": "invalid_host_code"}
	var url := String(parts[1])
	if not valid_private_websocket_url(url): return {"error": "invalid_private_endpoint"}
	return {"websocket_url": url, "protocol_version": PROTOCOL_VERSION}


static func parse_invite_code(value: String) -> Dictionary:
	var parts := value.strip_edges().split("|", false)
	if parts.size() != 4 or parts[0] != INVITE_PREFIX or int(parts[3]) != PROTOCOL_VERSION:
		return {"error": "invalid_invite_code"}
	var url := String(parts[1])
	var room_code := String(parts[2]).to_upper()
	if not valid_private_websocket_url(url): return {"error": "invalid_private_endpoint"}
	if not valid_room_code(room_code): return {"error": "invalid_room_code"}
	return {"websocket_url": url, "room_code": room_code, "protocol_version": PROTOCOL_VERSION}


static func valid_room_code(value: String) -> bool:
	if value.length() != ROOM_CODE_LENGTH: return false
	for index: int in value.length():
		var code := value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 65 and code <= 90): return false
	return true


static func valid_private_websocket_url(value: String) -> bool:
	if not value.begins_with("ws://") or value.contains("/") and value.substr(5).contains("/"): return false
	var authority := value.trim_prefix("ws://")
	var separator := authority.rfind(":")
	if separator <= 0: return false
	var host := authority.substr(0, separator)
	var port_text := authority.substr(separator + 1)
	if not port_text.is_valid_int(): return false
	var port := int(port_text)
	if port < 1 or port > 65535: return false
	var octets := host.split(".")
	if octets.size() != 4: return false
	var values: Array[int] = []
	for octet: String in octets:
		if not octet.is_valid_int(): return false
		var number := int(octet)
		if number < 0 or number > 255 or str(number) != octet: return false
		values.append(number)
	return values[0] == 10 \
		or (values[0] == 172 and values[1] >= 16 and values[1] <= 31) \
		or (values[0] == 192 and values[1] == 168) \
		or (values[0] == 127)
