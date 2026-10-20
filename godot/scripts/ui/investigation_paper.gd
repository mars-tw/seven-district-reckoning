extends RefCounted
## Real typeset document surface; hit targets are the ink lines on the paper.
const Art = preload("res://scripts/ui/art_theme.gd")
const PHRASES = "第二次收費|自動保存|同案補充通知|同案|已退回原位|展開原件|已回看|費用疑問|三個工作天|車店收據|輪值資料|交接摘要|反查依據|工作天|原件影本|前後合看|玩家推論|甲先發|乙後補|林秀蘭|陳奕廷|吳安琪|預付費|代辦費|點此貼入|已拿起|右側|摘要|原件|首筆|末筆|犯罪"

static func wrap_ink(value) -> void:
	# Web's fallback text server may ignore CJK punctuation rules. Insert measured
	# breaks while retaining the exact source text for input and diagnostics.
	if not is_instance_valid(value) or not value is Control: return
	var ink: Control = value
	if ink.size.x < 44: return
	var source: String = ink.get_meta("original_text",ink.get("text"))
	var available := ink.size.x-4
	if ink is Button: available -= ink.get_theme_stylebox("normal").get_minimum_size().x
	var pattern := RegEx.new()
	pattern.compile(PHRASES+"|[0-9]+[：:][0-9]+|[A-Za-z0-9_]+|[^\\n]|\\n")
	var units: Array[String] = []
	for match_value: RegExMatch in pattern.search_all(source):
		var token := match_value.get_string()
		if token != "\n" and not units.is_empty() and units[-1] != "\n" and (token in ["。","，","：","；","？","！","」","』","）","、","｜"] or units[-1] in ["「","『","（"]): units[-1] += token
		else: units.append(token)
	var lines := PackedStringArray()
	var line := ""
	var font: Font = ink.get_theme_font("font")
	var font_size := ink.get_theme_font_size("font_size")
	for token: String in units:
		if token == "\n":
			lines.append(line); line = ""
		elif not line.is_empty() and font.get_string_size(line+token,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > available:
			lines.append(line); line = token
		else: line += token
	lines.append(line)
	var lone := RegEx.new(); lone.compile("^[\\p{Han}][。，：；？！、」』）]?$" )
	for i: int in range(1,lines.size()):
		if lone.search(lines[i]) and lines[i-1].length() > 3:
			var before := lines[i-1]
			var take := 0
			var prior_tokens := pattern.search_all(before)
			while not prior_tokens.is_empty() and (take < 2 or before[before.length()-take] in ["。","，","：","；","？","！","」","』","）","、","｜"]):
				take += prior_tokens.pop_back().get_string().length()
			lines[i] = before.right(take)+lines[i]
			lines[i-1] = before.left(before.length()-take)
	var wrapped := "\n".join(lines)
	if ink.get("text") != wrapped: ink.set("text",wrapped)

static func make(doc: Dictionary, fields: Array, selected: int, viewed: Array, compact: bool, pick: Callable) -> PanelContainer:
	var paper := PanelContainer.new()
	paper.name = "OriginalDocument"
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := Art.paper()
	style.content_margin_left = 6 if compact else 10
	style.content_margin_right = 6 if compact else 10
	style.content_margin_top = 4 if compact else 8
	style.content_margin_bottom = 4 if compact else 8
	paper.add_theme_stylebox_override("panel",style)
	var ink := VBoxContainer.new()
	ink.add_theme_constant_override("separation",2)
	paper.add_child(ink)
	var heading := Label.new()
	heading.text = doc.title+"｜原件"
	heading.set_meta("original_text",heading.text)
	heading.add_theme_font_size_override("font_size",15 if compact else 20)
	heading.add_theme_color_override("font_color",Art.CHARCOAL)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.resized.connect(wrap_ink.bind(heading))
	ink.add_child(heading)
	wrap_ink.call_deferred(heading)
	for i: int in fields.size():
		var b := Button.new()
		b.name = "CitedField"+str(i)
		b.text = fields[i]
		b.set_meta("original_text",b.text)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.y = 44
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size",14 if compact else 18)
		for state: String in ["normal","hover","pressed","focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Art.AMBER if i == selected else Color(0,0,0,.04) if i in viewed else Color.TRANSPARENT
			box.border_color = Art.CHARCOAL if state == "focus" else Color("a88a60")
			box.border_width_bottom = 1 if i in viewed else 0
			box.border_width_left = 2 if state == "focus" else 0
			box.content_margin_left = 4
			box.content_margin_right = 4
			box.content_margin_top = 3
			box.content_margin_bottom = 3
			b.add_theme_stylebox_override(state,box)
		for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
			b.add_theme_color_override(state,Art.CHARCOAL)
		b.pressed.connect(pick.bind(i))
		b.resized.connect(wrap_ink.bind(b))
		ink.add_child(b)
		wrap_ink.call_deferred(b)
	return paper
