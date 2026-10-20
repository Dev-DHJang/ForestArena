extends RefCounted
## Load ignored workspace sheets only inside an isolated review process.

static func load_frames(entry: Dictionary, errors: Array[String], textures: Array[Texture2D]) -> SpriteFrames:
	var path := "res://" + String(entry.path).trim_prefix("res://")
	var image := Image.load_from_file(path)
	if image == null or image.is_empty() or image.get_size() != Vector2i(2048, 128) or image.get_format() != Image.FORMAT_RGBA8:
		errors.append("invalid candidate PNG " + path)
		return null
	var texture: Texture2D
	if entry.get("reuse_approved_runtime", false):
		texture = load(path) as Texture2D
	else:
		texture = ImageTexture.create_from_image(image)
		texture.take_over_path(path)
	textures.append(texture)
	# Caching the raw PNG avoids editor import; the SpriteFrames itself is still
	# parsed by Godot, including every frame reference, region and duration.
	var frames := load(String(entry.sprite_frames_path)) as SpriteFrames
	var motion := StringName(entry.visual_state_id)
	if frames == null or frames.get_animation_names().size() != 1 or not frames.has_animation(motion) or frames.get_frame_count(motion) != 16:
		errors.append("candidate SpriteFrames must contain exactly its declared sixteen-frame motion: " + String(motion))
		return null
	if not is_equal_approx(frames.get_animation_speed(motion), float(entry.fps)) or frames.get_animation_loop(motion) != bool(entry.loop):
		errors.append("candidate SpriteFrames fps/loop differs from catalog: " + String(motion))
	for index: int in 16:
		var frame := frames.get_frame_texture(motion, index) as AtlasTexture
		if frame == null or frame.atlas != texture or frame.region != Rect2(index * 128, 0, 128, 128) or not is_equal_approx(frames.get_frame_duration(motion, index), 1.0):
			errors.append("candidate SpriteFrames PNG/order/region/duration differs: %s frame %d" % [motion, index])
	return frames
