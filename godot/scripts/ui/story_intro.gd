class_name StoryIntro
extends CanvasLayer
## R1 cold open: four short chat-style cards that tell how A-Yuan lost his
## savings to the fictional "恆曜投資教育" group, then hand him to Mei.
## Tap, click, Space, Enter or E advances; "跳過" ends at once.

signal finished(skipped: bool)
const Art = preload("res://scripts/ui/art_theme.gd")

const CARDS := [
	{"kicker": "三個月前｜台中七期，外送等單中", "lines": [
		["恆曜投資教育｜助教", "至遠哥，本週學員平均獲利 12%，名額只剩最後三位！", "them"],
		["阿遠", "我只是想把機車貸款早點還完……", "me"]]},
	{"kicker": "上週｜申請出金", "lines": [
		["恆曜投資教育｜客服", "受款帳戶是恆曜公司專戶。先補繳四萬八千元「解凍保證金」，才能出金。", "them"],
		["阿遠", "我已經把存款全部轉進去了。", "me"],
		["系統", "您已被移出群組。", "system"]]},
	{"kicker": "今天｜存款歸零", "lines": [
		["", "三十八萬。十年外送攢下的錢，一夜之間沒了。", "narration"],
		["", "群組消失，客服變成空號。只剩一個地址：七期，一面玻璃帷幕後面。", "narration"]]},
	{"kicker": "美晴車店", "lines": [
		["美晴", "把客服訊息留下來。先來車店，我陪你比對收據上的戶名。", "them"],
		["", "現實中遇到投資詐騙，請撥 165 反詐騙專線。本作人物、公司皆為虛構。", "notice"]]},
]

const INK := Color("f1e8d5")
const ACCENT := Color("ffb800")
const MUTED := Color("c6bdad")

var index: int = -1
var _root: Control
var _kicker: Label
var _bubbles: VBoxContainer
var _dots: HBoxContainer
var _hint: Label
var _font: Font
var _closing: bool = false
var _portrait: TextureRect
var _portrait_frame: Control
var _column: VBoxContainer

func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists("res://assets/fonts/SevenDistrictSansTC-Regular.otf"):
		_font = load("res://assets/fonts/SevenDistrictSansTC-Regular.otf") as Font
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_gui_input)
	add_child(_root)
	var art := Art.image("title-street", 0)
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(art)
	var shade := ColorRect.new()
	shade.color = Color(0.086, 0.094, 0.114, 0.60)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 20)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(margin)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)
	var column := VBoxContainer.new()
	_column = column
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)
	_portrait = Art.image("ayuan-portrait", 160)
	_portrait_frame = Control.new()
	_portrait_frame.name = "WaistPortraitCrop"
	_portrait_frame.clip_contents = true
	column.add_child(_portrait_frame)
	_portrait.custom_minimum_size.y = 0
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_frame.add_child(_portrait)
	_kicker = _label("", 17, ACCENT)
	var header_box := _box(Art.CHARCOAL,Art.KRAFT,2)
	header_box.expand_margin_top = 12
	_kicker.add_theme_stylebox_override("normal",header_box)
	column.add_child(_kicker)
	_bubbles = VBoxContainer.new()
	_bubbles.add_theme_constant_override("separation", 10)
	_bubbles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_bubbles)
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 8)
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_dots)
	for i: int in CARDS.size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(22, 4)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dots.add_child(dot)
	_hint = _label("點一下繼續", 14, MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hint)
	var skip := Button.new()
	skip.name = "SkipIntro"
	skip.text = "跳過 ›"
	skip.custom_minimum_size = Vector2(96, 48)
	skip.focus_mode = Control.FOCUS_NONE
	if _font: skip.add_theme_font_override("font", _font)
	skip.add_theme_font_size_override("font_size", 16)
	skip.add_theme_stylebox_override("normal", _box(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.18), 24))
	skip.add_theme_stylebox_override("hover", _box(Color(1, 1, 1, 0.12), ACCENT, 24))
	skip.add_theme_stylebox_override("pressed", _box(Color(1, 1, 1, 0.16), ACCENT, 24))
	Art.skin_button(skip)
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -112
	skip.offset_right = -16
	skip.offset_top = 16
	skip.offset_bottom = 64
	skip.pressed.connect(func() -> void: finish(true))
	_root.add_child(skip)
	get_viewport().size_changed.connect(_fit)
	advance()

func _fit() -> void:
	var screen := get_viewport().get_visible_rect().size
	var tablet := screen.x >= 700 and screen.y >= 600
	var width: float = screen.x * 0.84 if tablet else clampf(screen.x - 48.0, 260.0, 560.0)
	var short_view := screen.y < 500
	_portrait_frame.visible = not short_view
	_portrait_frame.custom_minimum_size = Vector2(width,clampf(screen.y * .40,160,440 if tablet else 330) if not short_view else 0)
	if screen.y < 650 and not short_view: _portrait_frame.custom_minimum_size.y = screen.y*0.2
	# The waist extends behind an opaque dialogue header. No alpha fade.
	_portrait.offset_bottom = 16
	_column.add_theme_constant_override("separation", 6 if short_view else 12)
	_bubbles.add_theme_constant_override("separation", 4 if short_view else 10)
	for label: Node in _bubbles.find_children("*", "Label", true, false):
		if not label.has_meta("art_font_size"): label.set_meta("art_font_size",label.get_theme_font_size("font_size"))
		var base_size := int(label.get_meta("art_font_size"))
		label.add_theme_font_size_override("font_size",13 if short_view else base_size + 5 if tablet else base_size)
	_kicker.add_theme_font_size_override("font_size",22 if tablet else 17)
	_hint.add_theme_font_size_override("font_size",18 if tablet else 14)
	for node: Node in _bubbles.get_children():
		(node as Control).custom_minimum_size.x = width
	_kicker.custom_minimum_size.x = width

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font: label.add_theme_font_override("font", _font)
	return label

func _box(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(mini(radius, 2))
	box.border_width_left = 3
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box

func _bubble(speaker: String, text: String, kind: String) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := Color("24252a")
	var border := Color("9a7443")
	match kind:
		"me": fill = Color("383127"); border = ACCENT
		"system": fill = Color("39211e"); border = Color("c4271c")
		"narration": fill = Color(0, 0, 0, 0); border = Color(0, 0, 0, 0)
		"notice": fill = Color(0, 0, 0, 0); border = Color(1, 1, 1, 0.12)
	panel.add_theme_stylebox_override("panel", _box(fill, border, 14))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	if not speaker.is_empty():
		column.add_child(_label(speaker, 13, ACCENT if kind in ["them","me"] else Art.PAPER))
	var body := _label(text, 21 if kind == "narration" else (13 if kind == "notice" else 18), MUTED if kind == "notice" else INK)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(body)
	return panel

func advance() -> void:
	if _closing: return
	index += 1
	if index >= CARDS.size():
		finish(false)
		return
	var card: Dictionary = CARDS[index]
	_portrait.texture = Art.texture("meiqing-portrait" if index == 3 else "ayuan-portrait")
	_kicker.text = "今天｜車店門口" if index == 3 else str(card["kicker"])
	for child: Node in _bubbles.get_children():
		_bubbles.remove_child(child)
		child.queue_free()
	var delay: float = 0.0
	for line: Array in card["lines"]:
		var bubble := _bubble(str(line[0]), str(line[1]), str(line[2]))
		bubble.modulate.a = 0.0
		_bubbles.add_child(bubble)
		var tween := bubble.create_tween()
		tween.tween_interval(delay)
		tween.tween_property(bubble, "modulate:a", 1.0, 0.28)
		delay += 0.35
	for i: int in _dots.get_child_count():
		(_dots.get_child(i) as ColorRect).color = ACCENT if i <= index else Color(1, 1, 1, 0.2)
	_hint.text = "保存訊息，開始行動" if index == CARDS.size() - 1 else "點一下繼續"
	_fit()

func finish(skipped: bool) -> void:
	if _closing: return
	_closing = true
	finished.emit(skipped)
	queue_free()

func _on_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		advance()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E]:
		advance()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		finish(true)
		get_viewport().set_input_as_handled()
