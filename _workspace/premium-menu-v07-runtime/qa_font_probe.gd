extends SceneTree
func _initialize() -> void:
	var file = load("res://forest_arena/assets/ui/premium-menu-v07/fonts/NotoSansKR[wght].ttf")
	print("supported:", file.get_supported_variation_list())
	var font := FontVariation.new()
	font.base_font = file
	font.variation_opentype = {"wght": 500}
	print("set:",font.variation_opentype, "supported:", font.get_supported_variation_list())
	print("tag:", TextServerManager.get_primary_interface().name_to_tag("wght"))
	quit()
