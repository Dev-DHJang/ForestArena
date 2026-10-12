class_name ForestlightUi
extends RefCounted

const INK := Color("183d35")
const LIGHT := Color("f4f9ee")

static func texture(name: String) -> Texture2D:
	return ForestArenaResources.load_texture("fa.ui.forestlight." + name)

static func style(name: String, margin := 18.0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture(name)
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, margin)
		box.set_content_margin(side, 12.0)
	return box

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 20
	for kind: String in ["Label", "Button", "OptionButton", "CheckButton", "LineEdit"]:
		result.set_color("font_color", kind, INK)
		result.set_color("font_hover_color", kind, INK)
		result.set_color("font_pressed_color", kind, INK)
		result.set_color("font_disabled_color", kind, Color("718173"))
	for kind: String in ["Button", "OptionButton"]:
		for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			result.set_color(color_name, kind, LIGHT)
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var visual := "pressed" if state == "pressed" else ("disabled" if state == "disabled" else ("selected" if state == "focus" else "default"))
			result.set_stylebox(state, kind, style("secondary." + visual))
	result.set_stylebox("normal", "LineEdit", style("card.default"))
	result.set_stylebox("focus", "LineEdit", style("card.selected"))
	result.set_color("font_color", "PopupMenu", INK)
	var popup := StyleBoxFlat.new()
	popup.bg_color = LIGHT
	popup.content_margin_left = 14
	popup.content_margin_right = 14
	result.set_stylebox("panel", "PopupMenu", popup)
	result.set_constant("v_separation", "PopupMenu", 14)
	return result

static func skin_button(button: Button, family := "secondary") -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var visual := "pressed" if state == "pressed" else ("disabled" if state == "disabled" else ("selected" if state == "focus" else "default"))
		button.add_theme_stylebox_override(state, style(family + "." + visual))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK if family in ["primary", "card", "tab"] else LIGHT)

static func image(parent: Node, name: String, asset: String) -> TextureRect:
	var image := TextureRect.new()
	image.name = name
	image.texture = texture(asset)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image
