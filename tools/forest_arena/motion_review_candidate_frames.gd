extends RefCounted
## Load ignored workspace sheets only inside an isolated review process.

static func load_frames(entry: Dictionary, errors: Array[String], textures: Array[Texture2D]) -> SpriteFrames:
	var count := int(entry.get("frame_count", 16))
	var columns := int(entry.get("atlas_columns", 16))
	var cell := int(entry.get("cell_size", 128))
	if entry.get("frame_count", 16) is bool or entry.get("atlas_columns", 16) is bool or not is_equal_approx(float(entry.get("frame_count", 16)), float(count)) or not is_equal_approx(float(entry.get("atlas_columns", 16)), float(columns)) or count not in [16, 24, 32] or columns < 1 or columns > mini(16, count) or ceili(float(count) / columns) > 2 or cell != 128:
		errors.append("invalid candidate frame_count/atlas_columns/cell_size")
		return null
	var durations: Array = entry.get("frame_durations", [])
	if entry.has("frame_durations") and durations.size() != count:
		errors.append("candidate durations must match declared frame count")
		return null
	for duration: Variant in durations:
		if not (duration is int or duration is float) or not is_finite(float(duration)) or float(duration) <= 0.0:
			errors.append("candidate durations must be finite positive numbers")
			return null
	var path := "res://" + String(entry.path).trim_prefix("res://")
	var image := Image.load_from_file(path)
	var expected_size := Vector2i(columns * cell, ceili(float(count) / columns) * cell)
	if image == null or image.is_empty() or image.get_size() != expected_size or image.get_format() != Image.FORMAT_RGBA8:
		errors.append("invalid candidate PNG " + path)
		return null
	# Last unused cells may never contain undisclosed drawings.
	for unused: int in range(count, columns * ceili(float(count) / columns)):
		var unused_image := image.get_region(Rect2i((unused % columns) * cell, (unused / columns) * cell, cell, cell))
		if not unused_image.is_invisible():
			errors.append("candidate unused atlas cell must be transparent: " + path)
			return null
	var texture: Texture2D
	if entry.get("reuse_approved_runtime", false):
		texture = load(path) as Texture2D
	else:
		texture = ImageTexture.create_from_image(image)
		texture.take_over_path(path)
	textures.append(texture)
	# Caching the raw PNG avoids editor import; Godot still parses SpriteFrames.
	var frames := load(String(entry.sprite_frames_path)) as SpriteFrames
	var motion := StringName(entry.visual_state_id)
	if frames == null or frames.get_animation_names().size() != 1 or not frames.has_animation(motion) or frames.get_frame_count(motion) != count:
		errors.append("candidate SpriteFrames must contain exactly its declared motion/count: " + String(motion))
		return null
	if not is_equal_approx(frames.get_animation_speed(motion), float(entry.fps)) or frames.get_animation_loop(motion) != bool(entry.loop):
		errors.append("candidate SpriteFrames fps/loop differs from catalog: " + String(motion))
	for index: int in count:
		var frame := frames.get_frame_texture(motion, index) as AtlasTexture
		var expected_region := Rect2((index % columns) * cell, (index / columns) * cell, cell, cell)
		var duration := 1.0 if durations.is_empty() else float(durations[index])
		if frame == null or frame.atlas != texture or frame.region != expected_region or not is_equal_approx(frames.get_frame_duration(motion, index), duration):
			errors.append("candidate SpriteFrames PNG/order/region/duration differs: %s frame %d" % [motion, index])
	return frames
