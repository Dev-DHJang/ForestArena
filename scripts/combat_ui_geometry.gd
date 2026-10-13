class_name CombatUiGeometry
extends RefCounted
## Convert operating-system screen pixels into the viewport's logical coordinates.

static func logical_safe_rect(viewport_rect: Rect2, screen_safe: Rect2, screen_transform: Transform2D) -> Rect2:
	if not screen_safe.has_area(): return viewport_rect
	var inverse := screen_transform.affine_inverse()
	var mapped := Rect2(inverse * screen_safe.position, Vector2.ZERO)
	mapped = mapped.expand(inverse * Vector2(screen_safe.end.x, screen_safe.position.y))
	mapped = mapped.expand(inverse * screen_safe.end)
	mapped = mapped.expand(inverse * Vector2(screen_safe.position.x, screen_safe.end.y))
	var clipped := viewport_rect.intersection(mapped)
	return clipped if clipped.has_area() else viewport_rect

static func safe_rect(viewport: Viewport) -> Rect2:
	var full := viewport.get_visible_rect()
	if not OS.has_feature("mobile"): return full
	return logical_safe_rect(full, Rect2(DisplayServer.get_display_safe_area()), viewport.get_screen_transform())
