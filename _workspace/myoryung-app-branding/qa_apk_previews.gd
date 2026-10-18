extends SceneTree

func _initialize() -> void:
	var task := "res://_workspace/myoryung-app-branding/"
	var original := Image.load_from_file("res://assets/branding/myo-ryung-v01/adaptive-foreground-432.png")
	var actual := Image.load_from_file(task + "previews/qa-apk-foreground.webp")
	var bg := Image.load_from_file(task + "previews/qa-apk-background.webp")
	# Source foreground, APK foreground, source forest composite, APK forest composite.
	for variant: int in range(4):
		var layer := (original if variant % 2 == 0 else actual).duplicate() as Image
		if variant >= 2:
			var composite := bg.duplicate() as Image
			composite.convert(Image.FORMAT_RGBA8)
			composite.blend_rect(layer, Rect2i(0, 0, 432, 432), Vector2i.ZERO)
			layer = composite.get_region(Rect2i(72, 72, 288, 288))
		for size: int in [48, 72, 128, 192]:
			var preview := layer.duplicate() as Image
			preview.resize(size, size, Image.INTERPOLATE_LANCZOS)
			preview.save_png(task + "previews/qa-apk-v%d-%d.png" % [variant, size])
	# Save an uncropped sheet with 224px rows.
	var tall := Image.create(896, 896, false, Image.FORMAT_RGBA8)
	tall.fill(Color("18242b"))
	for variant: int in range(4):
		var col := 0
		for size: int in [48, 72, 128, 192]:
			var preview := Image.load_from_file(task + "previews/qa-apk-v%d-%d.png" % [variant, size])
			tall.blend_rect(preview, Rect2i(0, 0, size, size), Vector2i(col * 224 + (224 - size) / 2, variant * 224 + (224 - size) / 2))
			col += 1
	tall.save_png(task + "previews/qa-apk-comparison.png")
	quit(0)
