extends Control
## Fictional evidence is typeset, so annotations follow the actual words.
const Art = preload("res://scripts/ui/art_theme.gd")
const FONT = preload("res://assets/fonts/SevenDistrictSansTC-Regular.otf")
var receipt := true
var _paper: PanelContainer
var _column: VBoxContainer
var _close: Button
var _fields: GridContainer
var _fit_pending := false
var _notes: PanelContainer
var _note_rows: Array[BoxContainer] = []

class MarkedField extends PanelContainer:
	var circled := false
	func _draw() -> void:
		if circled:
			draw_set_transform(size*0.5,0,Vector2(1.0,size.y/maxf(1.0,size.x)))
			draw_arc(Vector2.ZERO,size.x*0.49,0,TAU,64,Color("c4271c"),2.0,true)
			draw_set_transform(Vector2.ZERO)

func _ready() -> void:
	name = "EvidenceInspector"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Art.CHARCOAL
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_paper = PanelContainer.new()
	var surface := StyleBoxTexture.new()
	surface.texture = Art.texture("receipt-paper")
	surface.set_content_margin_all(22)
	_paper.add_theme_stylebox_override("panel",surface)
	add_child(_paper)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation",14)
	_column.minimum_size_changed.connect(queue_fit)
	_paper.add_child(_column)
	add_text(_column,"證物乙・轉帳收據" if receipt else "證物甲・客服訊息",24,Art.CHARCOAL)
	add_text(_column,"離線留存｜虛構證物・上週五",13,Color("65502c")).set_meta("compact_optional",true)
	var body := PanelContainer.new()
	body.name = "TransferReceipt" if receipt else "CustomerConversation"
	var document := StyleBoxFlat.new()
	document.bg_color = Color("fffcf2") if receipt else Color("e3dccb")
	document.border_color = Color("9a8a70")
	document.set_border_width_all(2 if receipt else 0)
	document.set_content_margin_all(16)
	body.add_theme_stylebox_override("panel",document)
	_column.add_child(body)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation",12)
	body.add_child(contents)
	add_text(contents,"轉帳交易明細" if receipt else "恆曜客服｜線上對話留存",19,Art.CHARCOAL)
	add_text(contents,"留存編號 SD-01-B｜轉帳紀錄" if receipt else "上週五・客服傳送",13,Color("65502c"))
	contents.add_child(HSeparator.new())
	_fields = GridContainer.new()
	_fields.add_theme_constant_override("h_separation",18)
	_fields.add_theme_constant_override("v_separation",16)
	contents.add_child(_fields)
	if receipt:
		field("受款戶名","林○翔（個人）",true)
		field("轉帳時間","上週五 14：32",false)
		field("轉帳金額","三十八萬元",false)
		add_text(_column,"紅圈：收據記載個人戶名。\n黃線：時間與金額僅作留證。",16,Art.CHARCOAL)
	else:
		field("客服說詞","恆曜公司專戶",false)
		var bubble := PanelContainer.new()
		bubble.name = "CustomerMessageBubble"
		var bubble_style := StyleBoxFlat.new()
		bubble_style.bg_color = Color("fffcf2")
		bubble_style.border_color = Color("b3a58c")
		bubble_style.border_width_left = 3
		bubble_style.set_content_margin_all(14)
		bubble.add_theme_stylebox_override("panel",bubble_style)
		contents.add_child(bubble)
		# Keep both quotation marks with the quoted term at every supported width.
		var quoted := "\u2060".join(PackedStringArray(["「","解","凍","保","證","金","」"]))
		var quote_label := add_text(bubble,"先補繳四萬八千元\n%s，才能出\u2060金\u2060。" % quoted,18,Art.CHARCOAL)
		quote_label.name = "ProtectedQuote"
		quote_label.set_meta("source_text",quote_label.text)
		add_text(contents,"客服訊息・已留存",13,Color("65502c")).set_meta("compact_optional",true)
		var advice := add_text(_column,"保存說詞，再與轉帳收據核對。\n不要繼續付款。",16,Color("65502c"))
		advice.set_meta("source_text",advice.text)
	_notes = PanelContainer.new()
	_notes.name = "EvidenceCrossNotes"
	_notes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var note_style := StyleBoxFlat.new()
	note_style.bg_color = Color("e6dcc6")
	note_style.border_color = Art.RED
	note_style.border_width_left = 3
	note_style.set_content_margin_all(14)
	_notes.add_theme_stylebox_override("panel",note_style)
	_column.add_child(_notes)
	var notes := VBoxContainer.new()
	notes.add_theme_constant_override("separation",10)
	_notes.add_child(notes)
	add_text(notes,"甲乙核對筆記",18,Art.RED)
	var source := add_text(notes,"來源｜乙・阿遠留存的轉帳收據" if receipt else "來源｜甲・阿遠留存的客服對話",14,Color("65502c"))
	source.set_meta("compact_optional",true)
	for entry: Array in [["甲・客服聲稱","恆曜公司專戶"],["乙・收據記載","林○翔（個人）"],["核對結果","帳戶性質不一致"],["保全資料","保存原始對話與收據"],["後續行動","停止轉帳，再尋求協助"]]:
		var row := BoxContainer.new()
		row.add_theme_constant_override("separation",8)
		row.set_meta("large_tablet_only",_note_rows.size() >= 3)
		_note_rows.append(row)
		notes.add_child(row)
		add_text(row,entry[0],13,Color("65502c")).custom_minimum_size.x = 94
		var result := add_text(row,entry[1],16,Art.CHARCOAL)
		result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var limit := add_text(notes,"此矛盾足以質疑說詞，不能證明收款人就是幕後主嫌。",14,Color("65502c"))
	limit.set_meta("compact_optional",true)
	limit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	limit.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_close = Button.new()
	_close.text = "返回案卷"
	_close.custom_minimum_size = Vector2(180,52)
	_close.add_theme_font_override("font",FONT)
	_close.add_theme_font_size_override("font_size",18)
	Art.skin_button(_close,true)
	_close.pressed.connect(queue_free)
	add_child(_close)
	get_viewport().size_changed.connect(fit)
	fit()
	_close.grab_focus()

func add_text(parent: Node,text: String,size_value: int,color_value: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font",FONT)
	label.add_theme_font_size_override("font_size",size_value)
	label.set_meta("base_size",size_value)
	label.add_theme_color_override("font_color",color_value)
	parent.add_child(label)
	return label

func field(caption: String,value: String,circled: bool) -> void:
	var group := VBoxContainer.new()
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fields.add_child(group)
	add_text(group,caption,14,Color("65502c"))
	var marker := MarkedField.new()
	marker.name = "AccountAnnotation" if circled else "EvidenceHighlight"
	marker.circled = circled
	marker.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var box := StyleBoxFlat.new()
	box.bg_color = Color("f9d579")
	box.content_margin_left = 9
	box.content_margin_right = 9
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	marker.add_theme_stylebox_override("panel",box)
	group.add_child(marker)
	var label := add_text(marker,value,24,Art.RED if circled else Art.CHARCOAL)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF

func queue_fit() -> void:
	if _fit_pending: return
	_fit_pending = true
	fit.call_deferred()

func fit() -> void:
	_fit_pending = false
	var screen := get_viewport().get_visible_rect().size
	var short_view := screen.y < 500
	var small_view := screen.y < 650
	var narrow := screen.x < 360
	var dense_reading := screen.y < 1000
	var large_tablet := screen.x >= 700 and screen.y >= 1200
	for row: BoxContainer in _note_rows:
		row.vertical = large_tablet
		row.visible = large_tablet or not bool(row.get_meta("large_tablet_only"))
		(row.get_child(0) as Label).custom_minimum_size.x = 0 if large_tablet else 94
	_notes.visible = not small_view
	var width := minf(screen.x-32,820)
	_paper.custom_minimum_size.x = width
	_paper.size.x = width
	var surface := _paper.get_theme_stylebox("panel") as StyleBoxTexture
	surface.set_content_margin_all(8 if short_view else 12 if small_view else 16 if dense_reading else 22)
	for box: Node in _column.find_children("*","VBoxContainer",true,false):
		box.add_theme_constant_override("separation",3 if short_view else 6 if dense_reading else 12)
	for panel: Node in _column.find_children("*","PanelContainer",true,false):
		if panel is MarkedField:
			var marker_style := panel.get_theme_stylebox("panel") as StyleBoxFlat
			marker_style.content_margin_top = 3 if short_view else 7
			marker_style.content_margin_bottom = 3 if short_view else 7
			continue
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		style.set_content_margin_all(8 if short_view else 12 if dense_reading else 16)
	_column.add_theme_constant_override("separation",3 if short_view else 6 if small_view else 8 if dense_reading else 12)
	# Wide landscape paper has room for the three original receipt fields on
	# one row; retain the lower notes and a completely separate return footer.
	_fields.columns = 3 if receipt and screen.x >= 500 and (short_view or (screen.x >= 700 and screen.y < 900)) else 1
	_fields.add_theme_constant_override("v_separation",5 if short_view else 10 if dense_reading else 16)
	for label: Node in _column.find_children("*","Label",true,false):
		var base: int = int(label.get_meta("base_size",16))
		if label.has_meta("source_text"):
			label.text = String(label.get_meta("source_text")).replace("\n"," ") if short_view else String(label.get_meta("source_text"))
		label.visible = not (short_view and label.has_meta("compact_optional"))
		label.add_theme_font_size_override("font_size",mini(14,base) if short_view else mini(19,base) if small_view else mini(21,base) if narrow else roundi(base*1.25) if large_tablet else base)
	# Keep the return in a continuous paper footer without overlapping the
	# document rectangle (the existing accessibility contract).
	var height := screen.y-88
	_paper.size.y = maxf(_paper.get_combined_minimum_size().y,height)
	_paper.position = Vector2((screen.x-width)*0.5,12)
	var footer := get_node_or_null("PaperFooter") as Panel
	if not footer:
		footer = Panel.new()
		footer.name = "PaperFooter"
		footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var footer_style := StyleBoxTexture.new()
		footer_style.texture = Art.texture("receipt-paper")
		footer.add_theme_stylebox_override("panel",footer_style)
		add_child(footer)
		move_child(footer,_close.get_index())
	footer.position = Vector2(_paper.position.x,_paper.position.y+_paper.size.y-1)
	footer.size = Vector2(width,screen.y-12-footer.position.y)
	_close.position = Vector2((screen.x-180)*0.5,screen.y-68)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		queue_free()
		get_viewport().set_input_as_handled()
