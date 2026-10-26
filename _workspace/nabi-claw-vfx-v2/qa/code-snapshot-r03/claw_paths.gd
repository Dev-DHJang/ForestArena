extends RefCounted
## Draft geometry only: input points come from the actual authored claw.
static func point(value: Variant) -> bool:
	if not value is Array or value.size()!=2: return false
	for component: Variant in value:
		if not (component is int or component is float): return false
		if not is_finite(float(component)) or component<0 or component>128: return false
	return true

static func trails(anchors: Dictionary, previous: Dictionary, mirrored := false, scale := 1.0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not point(anchors.get("claw_hand")) or not point(anchors.get("claw_tip")): return result
	if not is_finite(scale) or scale<=0.0: return result
	var facing := -1.0 if mirrored else 1.0
	var hand := Vector2(float(anchors.claw_hand[0])-64,float(anchors.claw_hand[1])-64)*Vector2(facing,1)*scale
	var tip := Vector2(float(anchors.claw_tip[0])-64,float(anchors.claw_tip[1])-64)*Vector2(facing,1)*scale
	var direction := tip-hand
	if direction.length_squared()<1.0: return result
	var old_hand := hand
	if point(previous.get("claw_hand")):
		old_hand=Vector2(float(previous.claw_hand[0])-64,float(previous.claw_hand[1])-64)*Vector2(facing,1)*scale
	var normal := direction.normalized().orthogonal()*facing
	var bow := normal * clampf((tip-old_hand).length()*0.45,6.0*scale,24.0*scale)
	for finger: int in 3:
		var spread := float(finger-1)*3.0*scale
		result.append({"start":old_hand+normal*spread,"control":old_hand.lerp(hand,0.55)+normal*spread*1.5+bow,
			"control2":hand+normal*spread+bow*0.7,"tip":tip+normal*spread*0.35,"width":3.8*scale,
			"from":0.0,"to":1.0,"opacity":0.8,"central_tip":tip})
	return result
