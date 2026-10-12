extends "res://server/game/lan_game_server.gd"
var sent: Array[Dictionary]=[]
var rejected: Array[Dictionary]=[]
func _send(id: int, message: Dictionary) -> void:
 sent.append({'peer_id':id,'type':message.get('type',''),'slot':message.get('slot',0),'resumed':message.get('resumed',false)})
func _broadcast(message: Dictionary) -> void:
 sent.append({'type':message.get('type',''),'slot':message.get('slot',0)})
func _reject(id: int, code: String) -> void:
 rejected.append({'peer_id':id,'code':code})
