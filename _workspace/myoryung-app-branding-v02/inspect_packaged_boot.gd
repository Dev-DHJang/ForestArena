extends MainLoop

func _initialize() -> void:
	var settings := {
		"show_image": ProjectSettings.get_setting("application/boot_splash/show_image", true),
		"minimum_display_time": ProjectSettings.get_setting("application/boot_splash/minimum_display_time", -1),
		"icon": ProjectSettings.get_setting("application/config/icon", ""),
		"main_scene": str(ProjectSettings.get_setting("application/run/main_scene", "")),
	}
	print("PACKAGED_BOOT " + JSON.stringify(settings))

func _process(_delta: float) -> bool:
	return true
