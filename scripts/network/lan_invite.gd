class_name LanInvite
extends RefCounted

const PROTOCOL_VERSION := 2
const HOST_PREFIX := "FAH2"
const INVITE_PREFIX := "FA2"
const ROOM_CODE_LENGTH := 8


static func host_code(websocket_url: String, api_url: String = "") -> String:
	if not valid_endpoint_pair(websocket_url, api_url): return ""
	return "%s|%s|%s|%d" % [HOST_PREFIX, api_url, websocket_url, PROTOCOL_VERSION]


static func invite_code(websocket_url: String, room_code: String, api_url: String = "") -> String:
	var normalized := room_code.strip_edges().to_upper()
	if not valid_endpoint_pair(websocket_url, api_url) or not valid_room_code(normalized): return ""
	return "%s|%s|%s|%s|%d" % [INVITE_PREFIX, api_url, websocket_url, normalized, PROTOCOL_VERSION]


static func parse_host_code(value: String) -> Dictionary:
	var parts := value.strip_edges().split("|", true)
	if parts[0] == "FAH1": return {"error": "unsupported_protocol"}
	if parts.size() != 4 or parts[0] != HOST_PREFIX or parts[3] != str(PROTOCOL_VERSION):
		return {"error": "invalid_host_code"}
	if not valid_endpoint_pair(parts[2], parts[1]): return {"error": "invalid_private_endpoint"}
	return {"websocket_url": parts[2], "api_url": parts[1], "protocol_version": PROTOCOL_VERSION}


static func parse_invite_code(value: String) -> Dictionary:
	var parts := value.strip_edges().split("|", true)
	if parts[0] == "FA1": return {"error": "unsupported_protocol"}
	if parts.size() != 5 or parts[0] != INVITE_PREFIX or parts[4] != str(PROTOCOL_VERSION):
		return {"error": "invalid_invite_code"}
	if not valid_endpoint_pair(parts[2], parts[1]): return {"error": "invalid_private_endpoint"}
	var room_code := String(parts[3]).to_upper()
	if not valid_room_code(room_code): return {"error": "invalid_room_code"}
	return {"websocket_url": parts[2], "api_url": parts[1], "room_code": room_code, "protocol_version": PROTOCOL_VERSION}


static func valid_endpoint_pair(websocket_url: String, api_url: String) -> bool:
	if not api_url.begins_with("http://"): return false
	var api_ws := api_url.replace("http://", "ws://")
	return valid_private_websocket_url(websocket_url) and valid_private_websocket_url(api_ws) and websocket_url.substr(5).get_slice(":", 0) == api_ws.substr(5).get_slice(":", 0)


static func ipv4_number(value: String) -> int:
	var parts := value.split(".")
	if parts.size() != 4: return -1
	var result := 0
	for part: String in parts:
		if not part.is_valid_int() or str(int(part)) != part or int(part) < 0 or int(part) > 255: return -1
		result = (result << 8) | int(part)
	return result


static func address_in_cidr(address: String, cidr: String) -> bool:
	var parts := cidr.split("/")
	if parts.size() != 2 or not parts[1].is_valid_int(): return false
	var bits := int(parts[1])
	var base := ipv4_number(parts[0])
	var candidate := ipv4_number(address.trim_prefix("::ffff:"))
	if bits < 1 or bits > 32 or base < 0 or candidate < 0: return false
	var mask := (0xffffffff << (32 - bits)) & 0xffffffff
	return (base & mask) == (candidate & mask)


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
