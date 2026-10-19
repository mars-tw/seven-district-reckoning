extends RefCounted
## R4: original investigation art; layout and gameplay remain in their owners.
const PATH := "res://assets/art/r4/"
const CHARCOAL := Color("16181d")
const PAPER := Color("f1e8d5")
const RED := Color("c4271c")
const AMBER := Color("ffb800")
const KRAFT := Color("9a7443")

static func texture(id: String) -> Texture2D:
	if id == "meiqing-portrait": return load("res://assets/art/r9/meiqing-waist.png") as Texture2D
	if id == "ayuan-portrait": return load("res://assets/art/r9/ayuan-waist.png") as Texture2D
	if id in ["title-street","title-logo","app-icon"]: return load("res://assets/art/r7/"+id+".webp") as Texture2D
	if id in ["receipt-paper","case-paper"]: return load("res://assets/art/r8/clean-paper.webp") as Texture2D
	if id in ["ayuan-portrait","meiqing-portrait","icon-chain","icon-phone","icon-receipt","case-panel"]: return load("res://assets/art/r7/"+id+".png") as Texture2D
	if id == "archive-seal": return load("res://assets/art/r5/archive-seal.png") as Texture2D
	var path := PATH + id + (".png" if id in ["ayuan-portrait","meiqing-portrait","title-logo","app-icon","icon-chain","icon-phone","icon-receipt","icon-folder"] else ".webp")
	return load(path) as Texture2D

static func image(id: String, height: float) -> TextureRect:
	var view := TextureRect.new()
	view.name = "Art_" + id.replace("-", "_")
	view.texture = texture(id)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.custom_minimum_size.y = height
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view

static func paper(bound: bool = false) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture("case-paper")
	box.texture_margin_left = 28
	box.texture_margin_right = 18
	box.texture_margin_top = 18
	box.texture_margin_bottom = 18
	box.content_margin_left = 40 if bound else 12
	box.content_margin_right = 16 if bound else 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

static func button_style(active: bool = false, primary: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = AMBER if primary or active else CHARCOAL
	box.border_color = AMBER if active else KRAFT
	box.set_border_width_all(1)
	box.border_width_left = 3
	box.set_corner_radius_all(2)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box

static func skin_button(button: Button, primary: bool = false) -> void:
	for state: String in ["normal","hover","pressed","focus","disabled"]:
		var style := button_style(false, primary)
		if state in ["hover","pressed","focus"]:
			style.border_color = PAPER if not primary else CHARCOAL
			style.set_border_width_all(2)
			if not primary: style.bg_color = Color("34332f")
		if state == "disabled":
			style.bg_color = Color("44413b")
			style.border_color = Color("777166")
		button.add_theme_stylebox_override(state, style)
	for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(state, CHARCOAL if primary else PAPER)
	button.add_theme_color_override("font_disabled_color", Color("aca69b"))
	button.add_theme_constant_override("outline_size", 0)
