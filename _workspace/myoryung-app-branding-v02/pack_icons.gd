extends SceneTree

const TASK := "res://_workspace/myoryung-app-branding-v02"
const OUTPUT := "res://assets/branding/myo-ryung-v02"

func _initialize() -> void:
	# Art is generated with image_gen; this step only packages Android sizes/layers.
	var head := Image.load_from_file(TASK + "/source/foreground-source.png")
	var forest := Image.load_from_file(TASK + "/source/forest-source.png")
	if head == null or forest == null:
		push_error("Generated icon layers are missing")
		quit(1)
		return
	head.convert(Image.FORMAT_RGBA8)
	forest.convert(Image.FORMAT_RGBA8)
	var foreground := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	foreground.fill(Color.TRANSPARENT)
	var bust := head.duplicate() as Image
	bust.resize(360, 360, Image.INTERPOLATE_LANCZOS)
	foreground.blend_rect(bust, Rect2i(0, 0, 360, 360), Vector2i(36, 10))
	var background := forest.duplicate() as Image
	background.resize(432, 432, Image.INTERPOLATE_LANCZOS)
	# The user-selected original bust remains the regular icon composition.
	var master := Image.load_from_file(TASK + "/source/concept-icon.png")
	master.convert(Image.FORMAT_RGBA8)
	master.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
	var main := master.duplicate() as Image
	main.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var outputs := {
		"app-icon-1024.png": master,
		"main-192.png": main,
		"adaptive-foreground-432.png": foreground,
		"adaptive-background-432.png": background,
	}
	for filename: String in outputs:
		var result := (outputs[filename] as Image).save_png(OUTPUT + "/" + filename)
		if result != OK:
			push_error("Cannot save icon: " + filename)
			quit(1)
			return
	write_previews(master, background, foreground)
	print("APP_ICON_PACK: PASS (1024 master, 192 main, 432 foreground/background)")
	quit(0)

func write_previews(master: Image, background: Image, foreground: Image) -> void:
	DirAccess.make_dir_recursive_absolute(TASK + "/previews")
	var adaptive := background.duplicate() as Image
	adaptive.blend_rect(foreground, Rect2i(0, 0, 432, 432), Vector2i.ZERO)
	# The 108dp adaptive layers expose a central 72dp launcher viewport.
	adaptive = adaptive.get_region(Rect2i(72, 72, 288, 288))
	var sheet := Image.create(720, 960, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("18242b"))
	var row := 0
	for family: String in ["main", "adaptive"]:
		for shape: String in ["circle", "rounded"]:
			var column := 0
			for size: int in [48, 72, 192]:
				var preview := (master if family == "main" else adaptive).duplicate() as Image
				preview.resize(size, size, Image.INTERPOLATE_LANCZOS)
				for y: int in range(size):
					for x: int in range(size):
						var p := Vector2(x + 0.5, y + 0.5) - Vector2.ONE * size * 0.5
						var outside := p.length() > size * 0.5
						if shape == "rounded":
							var q := p.abs() - Vector2.ONE * size * 0.28
							outside = q.max(Vector2.ZERO).length() > size * 0.22
						if outside:
							preview.set_pixel(x, y, Color.TRANSPARENT)
				preview.save_png(TASK + "/previews/%s-%s-%d.png" % [family, shape, size])
				sheet.blend_rect(preview, Rect2i(0, 0, size, size), Vector2i(column * 240 + (240 - size) / 2, row * 240 + (240 - size) / 2))
				column += 1
			row += 1
	sheet.save_png(TASK + "/previews/contact-sheet.png")
