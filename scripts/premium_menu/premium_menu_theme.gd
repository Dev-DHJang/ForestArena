class_name PremiumMenuTheme
extends RefCounted

const BG := Color("10181c")
const PANEL := Color("1c282c")
const TEXT := Color("f2f3ed")
const MUTED := Color("bbc6c6")
const GOLD := Color("d9c58e")
const MINT := Color("8cbfb2")
const LINE := Color("455455")
const DANGER := Color("dd9b92")

static func surface(selected := false, filled := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = GOLD if filled else Color(PANEL, 0.94)
	box.border_color = GOLD if selected else LINE
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

static func make(text_scale := 1.0) -> Theme:
	var result := Theme.new()
	var path := ForestArenaResources.resource_path("fa.font.menu.v07.noto_sans_kr")
	if not path.is_empty():
		var font := FontVariation.new()
		font.base_font = load(path) as Font
		font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500}
		result.default_font = font
	result.default_font_size = roundi(20 * text_scale)
	for type: String in ["Label", "Button", "CheckButton", "OptionButton", "LineEdit", "RichTextLabel"]:
		result.set_color("font_color", type, TEXT)
	result.set_color("font_hover_color", "Button", GOLD)
	result.set_color("font_pressed_color", "Button", BG)
	result.set_color("font_disabled_color", "Button", MUTED.darkened(0.3))
	result.set_color("font_focus_color", "Button", GOLD)
	result.set_stylebox("normal", "Button", surface())
	result.set_stylebox("hover", "Button", surface(true))
	result.set_stylebox("pressed", "Button", surface(true, true))
	result.set_stylebox("focus", "Button", surface(true))
	result.set_stylebox("disabled", "Button", surface())
	result.set_stylebox("panel", "PanelContainer", surface())
	result.set_stylebox("normal", "LineEdit", surface())
	result.set_stylebox("focus", "LineEdit", surface(true))
	result.set_color("caret_color", "LineEdit", GOLD)
	result.set_color("font_color", "OptionButton", TEXT)
	result.set_stylebox("normal", "OptionButton", surface())
	result.set_stylebox("hover", "OptionButton", surface(true))
	result.set_stylebox("pressed", "OptionButton", surface(true))
	result.set_constant("separation", "VBoxContainer", 12)
	result.set_constant("separation", "HBoxContainer", 12)
	result.set_constant("h_separation", "GridContainer", 12)
	result.set_constant("v_separation", "GridContainer", 12)
	return result
