extends CanvasLayer
## Separate, paginated dossier. No scroll and no keyboard-only controls.
const Art = preload("res://scripts/ui/art_theme.gd")
var manager: RefCounted
var hud: CanvasLayer
var surface: Control
var page := "hub"
var document := 0
var statement := 0
var selected_document := -1
var compact := false
var body: VBoxContainer
var navigation_tabs: HBoxContainer
var notice := ""
var marked_field := -1
var cited_fields: Dictionary = {}
var drag_card := -1
var drag_origin := Vector2.ZERO
var drag_moved := false
var drag_ghost: Label
var timeline_cards: Array[Button] = []
var drop_zone: Control
var rail: Control
var display_cards: Array = []
var drag_lane: Control
var origin_outline: Control
var slot_labels: Array[Label] = []
var pin_index := 0
var relation_index := 0
var live_order: Label
var slot_cells: Array[VBoxContainer] = []
var slot_buttons: Array[Button] = []
var history_index := 0
var reveal_count := -1
var reveal_clock := 0.0
var attachment_receipt: Control
var attachment_target: Control
var attachment_start := Vector2.ZERO
var attachment_held := false
var attachment_moved := false
var attachment_lane: Control
var reviewed_originals: Array = []
const Paper = preload("res://scripts/ui/investigation_paper.gd")
const Rail = preload("res://scripts/ui/investigation_rail.gd")
const Links = preload("res://scripts/ui/investigation_links.gd")
const TimeMask = preload("res://scripts/ui/investigation_time_mask.gd")

func _process(_delta: float) -> void:
	pass # Time covers move only while the player holds or drags them.

var original_return := ""
var action_offset := randi_range(0,2)
var action_serial := -1

func first_hint(kind: String, detail: String) -> String:
	var errors: Array = manager.entry().history.filter(func(e: Dictionary) -> bool: return e.kind == kind and not e.feedback.is_empty())
	if kind == "pin": return detail
	if errors.size() > 1: return detail
	return {"action":"甲乙的收費條件仍有衝突。回看兩處黃標與乙的備註。","relation":"你把引用方向讀反了，先回看『附件：』或『接班依據：』那一句。","pin":"這筆時間與你選的『全部』說法對不上。回看分界兩側的原件。"}.get(kind,detail)

func open_original(index: int) -> void:
	original_return = page
	if manager.definition().mode == "contradiction" and manager.entry().compared and not index in reviewed_originals: reviewed_originals.append(index)
	document = index
	page = "original"
	show_page()

func original_page() -> void:
	var doc: Dictionary = manager.definition().documents[document]
	label("完整原件｜"+doc.title,18)
	var original_body := body
	var side: VBoxContainer
	if get_viewport().get_visible_rect().size.y < 400:
		var split := row()
		var source := VBoxContainer.new(); source.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(source)
		side = VBoxContainer.new(); side.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(side)
		body = source
	label(manager.document_text(document),16)
	if side: body = side
	if manager.definition().mode == "contradiction":
		var paper := Paper.make(doc,[doc.fields[2]],0 if manager.entry().citations.get(str(document),-1) == 2 else -1,[],true,func(_i: int) -> void: pass)
		body.add_child(paper)
	button("收起原件，返回判定",func() -> void: page = original_return; show_page(),null,true)
	body = original_body

func _attachment_input(event: InputEvent) -> void:
	if not is_instance_valid(attachment_receipt): return
	var pos := Vector2.ZERO
	var down := false
	var up := false
	var motion := false
	if event is InputEventScreenTouch:
		pos = event.position; down = event.pressed; up = not down
	elif event is InputEventScreenDrag:
		pos = event.position; motion = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position; down = event.pressed; up = not down
	elif event is InputEventMouseMotion:
		pos = event.position; motion = true
	else: return
	if down and attachment_receipt.get_global_rect().has_point(pos):
		attachment_held = true; attachment_moved = false; attachment_start = pos
	if not attachment_held: return
	if motion and pos.distance_to(attachment_start) > 8:
		attachment_moved = true
		if not is_instance_valid(drag_ghost):
			drag_ghost = Label.new()
			drag_ghost.text = "甲 17：42\n拖曳中"
			drag_ghost.size = Vector2(96,48)
			drag_ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			drag_ghost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			var ghost_paper := Art.paper()
			ghost_paper.content_margin_left = 6; ghost_paper.content_margin_right = 6
			ghost_paper.content_margin_top = 2; ghost_paper.content_margin_bottom = 2
			ghost_paper.texture_margin_top = 4; ghost_paper.texture_margin_bottom = 4
			ghost_paper.texture_margin_left = 6; ghost_paper.texture_margin_right = 6
			drag_ghost.add_theme_stylebox_override("normal",ghost_paper)
			drag_ghost.add_theme_color_override("font_color",Art.CHARCOAL)
			drag_ghost.add_theme_font_size_override("font_size",13)
			drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			drag_ghost.z_index = 100
			surface.add_child(drag_ghost)
		attachment_receipt.modulate.a = .35
		drag_ghost.size = Vector2(96,48)
		drag_ghost.position = Vector2(clampf(pos.x-48,attachment_lane.global_position.x,attachment_lane.get_global_rect().end.x-96),attachment_lane.global_position.y+4)
		get_viewport().set_input_as_handled()
	if up:
		attachment_held = false
		if attachment_moved:
			get_viewport().set_input_as_handled()
			if attachment_target.get_global_rect().has_point(pos):
				manager.seal_time(0); notice = ""
			else:
				selected_document = -1
				notice = "位置不對，收據已退回原位。"
			show_page()

func _input(event: InputEvent) -> void:
	if is_instance_valid(surface) and page == "solve" and manager.definition().get("mode") == "timeline" and manager.entry().time_checked:
		_attachment_input(event)
		return
	if not is_instance_valid(surface) or page != "solve" or manager.definition().get("mode") != "timeline": return
	var pos := Vector2.ZERO
	var down := false
	var up := false
	var motion := false
	if event is InputEventScreenTouch:
		pos = event.position; down = event.pressed; up = not down
	elif event is InputEventScreenDrag:
		pos = event.position; motion = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position; down = event.pressed; up = not down
	elif event is InputEventMouseMotion:
		pos = event.position; motion = true
	else: return
	if down:
		for card: Button in timeline_cards:
			if card.get_global_rect().has_point(pos):
				drag_card = int(card.get_meta("card_index")); drag_origin = pos; drag_moved = false
				break
	if drag_card < 0: return
	if motion and (drag_moved or pos.distance_to(drag_origin) > 8):
		drag_moved = true
		if not is_instance_valid(drag_ghost):
			drag_ghost = Label.new()
			drag_ghost.name = "DraggedOriginal"
			drag_ghost.text = ["甲 車店收據","乙 交接摘要","丙 輪值資料"][drag_card]+"\n"+manager.definition().documents[drag_card].event+"\n時間被遮蔽"
			drag_ghost.custom_minimum_size = Vector2(224,66)
			for card: Button in timeline_cards:
				if int(card.get_meta("card_index")) == drag_card:
					card.modulate.a = 0
					if drag_card not in manager.entry().order:
						origin_outline = Rail.new()
						origin_outline.origin_mode = true
						surface.add_child(origin_outline)
						origin_outline.position = card.get_global_rect().position
						origin_outline.size = card.size
						origin_outline.z_index = 90
			var ghost_style := StyleBoxFlat.new()
			ghost_style.bg_color = Color(Art.PAPER,.72)
			ghost_style.border_color = Art.KRAFT
			ghost_style.set_border_width_all(1)
			ghost_style.shadow_color = Color(0,0,0,.55)
			ghost_style.shadow_size = 6
			ghost_style.shadow_offset = Vector2(4,6)
			drag_ghost.add_theme_stylebox_override("normal",ghost_style)
			drag_ghost.scale = Vector2.ONE
			drag_ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			drag_ghost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			drag_ghost.add_theme_color_override("font_color",Art.CHARCOAL)
			drag_ghost.add_theme_font_size_override("font_size",12)
			drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			surface.add_child(drag_ghost)
			drag_ghost.z_index = 100
		var safe := drag_lane.get_global_rect()
		var ghost_width := minf(224,safe.size.x-16)
		drag_ghost.size = Vector2(ghost_width,66)
		drag_ghost.position = Vector2(clampf(pos.x-ghost_width*.5,safe.position.x+8,safe.end.x-ghost_width-8),safe.position.y+4)
		if is_instance_valid(drop_zone):
			var r: Rect2 = drop_zone.get_global_rect()
			rail.preview = clampi(int((pos.x-r.position.x)/(r.size.x/3)),0,2) if r.has_point(pos) else -1
			for i: int in slot_labels.size():
				slot_labels[i].text = ("放下後" if surface.size.y < 400 else "放下後\n第%d格" % (i+1)) if rail.preview == i else "第 %d 格" % (i+1)
			var predicted: Array = manager.entry().order.duplicate()
			predicted.erase(drag_card)
			if rail.preview >= 0: predicted.insert(mini(rail.preview,predicted.size()),drag_card)
			_update_slots(predicted if rail.preview >= 0 else manager.entry().order)
			if is_instance_valid(live_order):
				var preview_text := ("放下後：" if rail.preview >= 0 else "目前：")+_order_text(predicted if rail.preview >= 0 else manager.entry().order)
				live_order.set_meta("original_text",preview_text)
				live_order.text = preview_text
				_wrap_label(live_order)
			rail.queue_redraw()
		get_viewport().set_input_as_handled()
	if up:
		var index := drag_card
		drag_card = -1
		if drag_moved:
			get_viewport().set_input_as_handled()
			if is_instance_valid(drop_zone) and drop_zone.get_global_rect().has_point(pos):
				var r: Rect2 = drop_zone.get_global_rect()
				manager.place_time(index,clampi(int((pos.x-r.position.x)/(r.size.x/3)),0,2))
			show_page()

func setup(owner_hud: CanvasLayer, data: RefCounted) -> void:
	hud = owner_hud
	manager = data
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_redraw)
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(surface) and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()

func dismiss() -> void:
	if is_instance_valid(surface):
		remove_child(surface)
		surface.queue_free()
		surface = null

func close() -> void:
	dismiss()
	hud._resume()
	hud._refresh_mission()

func open_hub() -> void:
	hud.hide_menus()
	page = "hub"
	notice = ""
	show_page()

func open_case(id: String) -> void:
	if action_serial != manager.game_serial:
		action_offset = (action_offset+1)%3
		action_serial = manager.game_serial
	manager.start(id)
	page = "pinning" if manager.entry().get("judging",false) and not manager.entry().complete else "evidence"
	document = 0
	statement = 0
	selected_document = -1
	reviewed_originals.clear()
	notice = ""
	cited_fields.clear()
	display_cards.clear()
	history_index = 0
	reveal_count = -1
	show_page()

func collected(index: int) -> void:
	hud.hide_menus()
	page = "fieldnote" if manager.definition().mode == "testimony" else "evidence"
	document = index
	show_page()

func _redraw() -> void:
	if is_instance_valid(surface): show_page()

func label(text: String, size_value: int = 18, color: Color = Art.CHARCOAL) -> Label:
	var l := Label.new()
	l.set_meta("original_text",text)
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size",mini(size_value,14) if compact else size_value)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.resized.connect(_wrap_label.bind(l))
	body.add_child(l)
	_wrap_label.call_deferred(l)
	return l

func _wrap_label(l) -> void:
	Paper.wrap_ink(l)

func row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation",6)
	body.add_child(r)
	return r

func button(text: String, callback: Callable, parent: Node = null, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.set_meta("original_text",text)
	b.set_meta("primary_action",primary)
	b.custom_minimum_size = Vector2(0,44 if compact else 48)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size",13 if compact else 17)
	Art.skin_button(b,primary)
	b.pressed.connect(callback)
	(parent if parent else body).add_child(b)
	b.resized.connect(Paper.wrap_ink.bind(b))
	Paper.wrap_ink.call_deferred(b)
	return b

func selected(b: Button, value: bool) -> void:
	b.set_meta("selected",value)
	b.set_meta("choice_state","selected" if value else "idle")
	if not value: return
	var style := StyleBoxFlat.new()
	style.bg_color = Art.PAPER
	style.border_color = Art.CHARCOAL
	style.set_border_width_all(3)
	style.content_margin_top = 2; style.content_margin_bottom = 2
	for key: String in ["normal","hover","pressed","focus"]: b.add_theme_stylebox_override(key,style)
	for key: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: b.add_theme_color_override(key,Art.CHARCOAL)

func current_tab(b: Button, value: bool) -> void:
	b.set_meta("current_tab",value)
	if not value: return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Art.PAPER,.2)
	style.border_color = Art.CHARCOAL
	style.border_width_bottom = 3
	for key: String in ["normal","hover","pressed","focus"]: b.add_theme_stylebox_override(key,style)
	for key: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: b.add_theme_color_override(key,Art.CHARCOAL)

func wrong_choice(b: Button, value: bool) -> void:
	b.set_meta("wrong_choice",value)
	if not value: return
	b.set_meta("choice_state","wrong")
	b.text = "你選的｜"+b.text
	b.set_meta("original_text",b.text)
	var style := StyleBoxFlat.new()
	style.bg_color = Art.PAPER
	style.border_color = Art.RED
	style.set_border_width_all(3)
	style.content_margin_top = 2; style.content_margin_bottom = 2
	for key: String in ["normal","hover","pressed","focus"]: b.add_theme_stylebox_override(key,style)
	for key: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: b.add_theme_color_override(key,Art.RED)

func checked_choice(b: Button, value: bool) -> void:
	if not value: return
	b.set_meta("choice_state","correct")
	var style: StyleBoxFlat = b.get_theme_stylebox("normal").duplicate()
	style.border_width_left = 6
	for key: String in ["normal","hover","pressed","focus"]: b.add_theme_stylebox_override(key,style)

func feedback_line(size_value: int = 14, explicit_error: String = "") -> void:
	if explicit_error.is_empty() and manager.feedback.begins_with("已封存") and not manager.entry().complete: return
	if not manager.feedback.is_empty() or not explicit_error.is_empty():
		var error: bool = not explicit_error.is_empty() or manager.feedback_is_error()
		var text: String = explicit_error if not explicit_error.is_empty() else manager.feedback
		if error and not text.begins_with("錯因："): text = "錯因："+text
		var ink := label(text,size_value,Art.RED if error else Art.CHARCOAL)
		if error:
			var marker := StyleBoxFlat.new(); marker.bg_color = Color.TRANSPARENT; marker.border_color = Art.RED; marker.border_width_left = 3; marker.content_margin_left = 6
			ink.add_theme_stylebox_override("normal",marker)

func banner(case_id: String = "") -> void:
	if compact: return
	var art := TextureRect.new()
	art.name = "CaseEvidenceArt"
	art.texture = load("res://assets/art/content-r2/"+case_id+".webp") if not case_id.is_empty() else load("res://assets/art/content-r1/investigation-desk.webp")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.clip_contents = true
	art.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y*(.15 if case_id == "before_night" else .20),90,210)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not case_id.is_empty() and not manager.entry().complete and manager.ready_to_solve() and manager.definition().mode in ["contradiction","timeline"]:
		art.mouse_filter = Control.MOUSE_FILTER_STOP
		art.gui_input.connect(func(event: InputEvent) -> void:
			if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
				page = "inspect"; marked_field = -1
				show_page.call_deferred()
		)
	body.add_child(art)

func source_summary() -> void:
	var c: Dictionary = manager.definition()
	var sources := PackedStringArray()
	for i: int in c.documents.size():
		var d: Dictionary = c.documents[i]
		sources.append(("已留存" if i in manager.entry().collected else "待訪")+["甲 ","乙 ","丙 "][i]+d.title.get_slice("｜",1))
	label("｜".join(sources),13 if get_viewport().get_visible_rect().size.y < 400 else 12 if get_viewport().get_visible_rect().size.x < 360 else 14,Color("65502c")).name = "SourceSummary"

func record_strip(sealed: bool = false, pinning: bool = false) -> void:
	var strip := Rail.new()
	strip.name = "RecordRibbon"
	strip.record_mode = true
	strip.sealed = sealed
	strip.pinned = manager.entry().pins
	for i: int in 3:
		if not manager.pin_error(i).is_empty(): strip.errors.append(i)
	strip.highlights = ([0] if selected_document == 0 else [2] if selected_document == 1 else [0,1,2]) if selected_document >= 0 else [[2],[0],[0,1,2]][statement]
	strip.custom_minimum_size.y = (210 if compact and get_viewport().get_visible_rect().size.y >= 400 else 184 if compact else 232) if sealed or pinning else 150
	body.add_child(strip)
	var columns := HBoxContainer.new()
	strip.add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.offset_top = 48
	columns.add_theme_constant_override("separation",2)
	for i: int in 3:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation",0)
		columns.add_child(cell)
		var time := Label.new()
		time.text = ["17：50","前後合看","18：10"][i]
		time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time.add_theme_font_size_override("font_size",18 if not compact else 16)
		time.add_theme_color_override("font_color",Art.CHARCOAL)
		cell.add_child(time)
		for text: String in [["首筆原文","玩家推論","末筆原文"][i],["林秀蘭記收件\n未記發言","首筆＋末筆\n不新增原件","陳奕廷記收件\n未記發言"][i]]:
			var caption := Label.new()
			caption.text = text
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.add_theme_font_size_override("font_size",12)
			caption.add_theme_color_override("font_color",Color("766c5c"))
			cell.add_child(caption)
		if sealed or i in manager.entry().pins:
			var result := Label.new()
			var choice: int = int(manager.entry().pin_choices.get(str(i),[1,2,0][i]))
			var wrong: bool = not manager.pin_error(i).is_empty()
			result.text = "你選的｜\n"+["反駁林秀蘭\n『全在前』","反駁陳奕廷\n『全在後』","支持吳安琪\n『前後都有』"][choice] if wrong else ["已核對\n17：50 在前\n反駁陳奕廷\n『全在後』","已核對\n支持吳安琪\n『前後都有』","已核對\n18：10 在後\n反駁林秀蘭\n『全在前』"][i]
			if get_viewport().get_visible_rect().size.y < 400 and not wrong:
				result.text = ["已核對\n反駁陳奕廷\n『全在後』","已核對\n支持吳安琪\n『前後都有』","已核對\n反駁林秀蘭\n『全在前』"][i]
			result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			result.add_theme_font_size_override("font_size",12)
			result.add_theme_color_override("font_color",Art.RED if not manager.pin_error(i).is_empty() else Art.CHARCOAL)
			if wrong:
				var frame := StyleBoxFlat.new(); frame.bg_color = Art.PAPER; frame.border_color = Art.RED; frame.set_border_width_all(3)
				result.add_theme_stylebox_override("normal",frame)
			cell.add_child(result)
	if sealed and not compact:
		label("兩筆原始紀錄 → 玩家推論",18)
		label("17：50 在前，18：10 在後。\n合看支持吳安琪『前後都有』；\n18：00 只作分界，沒有第三筆原件。",16)

func spread() -> void:
	if not compact: label(manager.definition().reference,13)
	var pages := row()
	for i: int in 2:
		var doc: Dictionary = manager.definition().documents[i].duplicate()
		doc.title = ["甲｜承諾","乙｜要求"][i]
		var paper := Paper.make(doc,[manager.definition().documents[i].fields[2]],0,[],true,func(_field: int) -> void: open_original(i))
		pages.add_child(paper)
		for b: Button in paper.find_children("*","Button",true,false):
			b.disabled = manager.entry().complete
			if b.disabled:
				b.add_theme_color_override("font_disabled_color",Art.CHARCOAL)
				b.add_theme_stylebox_override("disabled",b.get_theme_stylebox("normal"))
			else: b.tooltip_text = "展開完整原件"

class AttachedReceipt extends Control:
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO,0,Vector2(1,size.y/92.0))
		var paper := Rect2(size.x*.42,8,size.x*.55,72)
		draw_style_box(Art.paper(),paper); draw_rect(paper,Art.KRAFT,false,1)
		draw_string(get_theme_default_font(),paper.position+Vector2(12,24),"丙｜輪值資料",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Art.CHARCOAL)
		draw_string(get_theme_default_font(),paper.position+Vector2(12,51),"18：00",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Art.CHARCOAL)
		var receipt := Rect2(10,24,size.x*.43,60)
		draw_style_box(Art.paper(),receipt); draw_rect(receipt,Art.KRAFT,false,1)
		draw_string(get_theme_default_font(),receipt.position+Vector2(8,23),"甲 收據 17：42",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Art.CHARCOAL)
		draw_rect(Rect2(receipt.position+Vector2(receipt.size.x-30,-6),Vector2(43,14)),Color("c8b084"))
		draw_line(Vector2(24,60),Vector2(size.x*.35,60),Art.RED,2,true)

func sealed_results() -> void:
	var c: Dictionary = manager.definition()
	label("封存回顧｜"+c.result,22,Art.CHARCOAL)
	label("最後封存選擇｜"+((["甲乙留存，付款暫停","收據 → 摘要 → 輪值","三筆判定已核對"] if get_viewport().get_visible_rect().size.y < 400 else ["留存甲乙，暫停付款","甲 → 乙 → 丙；兩段引用已選","首筆反駁陳奕廷；末筆反駁林秀蘭；合看支持吳安琪"])[["contradiction","timeline","testimony"].find(c.mode)]),14)
	if page == "history":
		_review_history()
		return
	if page == "chain":
		_review_chain()
		return
	if c.mode == "testimony":
		var original_body := body
		if get_viewport().get_visible_rect().size.y < 400:
			var split := row()
			var band := VBoxContainer.new()
			band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			split.add_child(band)
			body = band
			record_strip(true)
			var results := VBoxContainer.new()
			results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			split.add_child(results)
			body = results
		else: record_strip(true)
		label("18：00 是分界，整點不算以前或以後。",16)
		label(c.boundary,14,Color("65502c"))
		body = original_body
	elif c.mode == "timeline":
		var original_body := body
		var result_column: VBoxContainer
		if get_viewport().get_visible_rect().size.y < 400:
			var split := row()
			var originals := VBoxContainer.new(); originals.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(originals)
			result_column = VBoxContainer.new(); result_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(result_column)
			body = originals
		else: label("最終順序：甲 收據 → 乙 摘要 → 丙 輪值",16)
		var documents_row: HBoxContainer
		documents_row = row()
		for i: int in 3:
			var doc: Dictionary = c.documents[i].duplicate()
			if result_column: doc.title = ["甲","乙","丙"][i]
			var fields: Array = [["17：42\n收據"],["17：55\n附件：甲"],["18：00\n輪值起點"]][i]
			var paper := Paper.make(doc,fields,0,[],true,func(_field: int) -> void: pass)
			(documents_row if documents_row else body).add_child(paper)
			for b: Button in paper.find_children("*","Button",true,false):
				b.disabled = true
				b.add_theme_color_override("font_disabled_color",Art.CHARCOAL)
				b.add_theme_stylebox_override("disabled",b.get_theme_stylebox("normal"))
		var attached := AttachedReceipt.new(); attached.name = "TapedReceipt"; attached.custom_minimum_size.y = 64 if get_viewport().get_visible_rect().size.y < 400 else 92; body.add_child(attached)
		if result_column: body = result_column
		label("收據早於晚班，晚班開立的猜測已被推翻。",18)
		label(c.boundary,14,Color("65502c"))
		body = original_body
	else:
		spread()
		label(c.seal_comparison,18)
		label("安全行動："+c.action_choices[int(c.action_answer)]+"。",18)
		var mistakes: Array = manager.entry().history.filter(func(e: Dictionary) -> bool: return e.kind == "action" and not e.feedback.is_empty())
		if not mistakes.is_empty() and get_viewport().get_visible_rect().size.y >= 400: label("錯選留存："+c.action_choices[int(mistakes[0].choice)],14)
		if get_viewport().get_visible_rect().size.y >= 400: label("同機構、同案號；乙件備註：未撤回原承諾。",14)
		label(c.boundary,14,Color("65502c"))

func illustration_caption() -> String:
	if manager.active == "before_night":
		var times := PackedStringArray()
		for i: int in 3: times.append(["17：42","17：55","18：00"][i] if manager.entry().complete or manager.entry().reveal_steps[i] == 3 else "待揭")
		return " → ".join(times)
	if manager.entry().complete: return "封存｜原件已歸位"
	if manager.active == "second_help": return "黃標 %d／2" % [int(manager.entry().citations.get("0",-1) == 2)+int(manager.entry().citations.get("1",-1) == 2)]
	return "已釘 %d／3" % manager.entry().pins.size()

func show_page() -> void:
	drag_card = -1
	attachment_receipt = null; attachment_target = null
	attachment_held = false; attachment_moved = false
	drag_ghost = null
	timeline_cards.clear()
	slot_labels.clear()
	slot_cells.clear()
	slot_buttons.clear()
	drop_zone = null
	if is_instance_valid(surface):
		remove_child(surface)
		surface.queue_free()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var screen := get_viewport().get_visible_rect().size
	compact = screen.y < 700 or screen.x < 360
	var timeline_page: bool = manager.definition().get("mode") == "timeline" and page in ["solve","relations"]
	var timeline_portrait: bool = timeline_page and screen.y >= 400 and not manager.entry().get("complete",false)
	surface = Control.new()
	surface.name = "InvestigationDossier"
	surface.theme = Theme.new()
	surface.theme.default_font = load("res://assets/fonts/SevenDistrictSansTC-Regular.otf")
	surface.theme.default_font_size = 18
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.name = "OpaqueDossierBackdrop"
	back.color = Art.CHARCOAL
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.add_child(back)
	var center: Container = MarginContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("margin_top",8 if screen.y >= 400 else 0)
	center.add_theme_constant_override("margin_bottom",8 if screen.y >= 400 else 0)
	surface.add_child(center)
	var sheet := PanelContainer.new()
	sheet.name = "CaseSheet"
	sheet.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet.custom_minimum_size.x = minf(screen.x-16,760)
	var paper := Art.paper(true)
	paper.content_margin_left = 6 if compact else 20
	paper.content_margin_right = 6 if compact else 12
	if timeline_portrait and compact:
		paper.content_margin_left = 6; paper.content_margin_right = 6
	if compact:
		paper.content_margin_top = 0
		paper.content_margin_bottom = 0
	sheet.add_theme_stylebox_override("panel",paper)
	center.add_child(sheet)
	var margin := MarginContainer.new()
	sheet.add_child(margin)
	for side: String in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,0 if compact and side in ["top","bottom"] else 4 if screen.y < 400 else 8 if compact else 14)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation",0 if compact else 4)
	margin.add_child(body)
	if page == "hub" or screen.y >= 400: label("街坊查證簿" if page == "hub" else manager.definition().title,24)
	if page == "hub":
		banner()
		label("走訪取證，再回案卷比對。進度會自動保存。",16)
		for c: Dictionary in manager.definitions:
			button(("已封存・"+c.result+"｜" if manager.records[c.id].complete else "待查證｜")+c.title,open_case.bind(c.id))
		label("人物、機構與案件均為虛構。只核對證據，不猜誰有罪。",14)
	else:
		var tabs := row()
		navigation_tabs = tabs
		var paper_landscape: bool = screen.y < 400 and manager.ready_to_solve() and manager.definition().mode == "contradiction" and page in ["solve","inspect"]
		var timeline_landscape: bool = compact and manager.definition().mode == "timeline" and page == "solve"
		if (timeline_portrait or page not in ["fieldnote","relations"] and not paper_landscape and not timeline_landscape) and not manager.entry().complete:
			for tab: String in ["證物","推論","放大"]:
				var destination: String = {"證物":"evidence","推論":"solve","放大":"inspect"}[tab]
				var active_tab: bool = page == destination or tab == "推論" and page in ["relations","pinning","judgement"]
				var pick := button(tab,func() -> void: page = destination; marked_field = -1; show_page(),tabs)
				current_tab(pick,active_tab)
		if page == "solve" and manager.definition().mode == "testimony" and not manager.entry().complete:
			button("換一句 %d／3" % (statement+1),func() -> void: statement = (statement+1)%3; selected_document = -1; show_page(),tabs)
		if manager.entry().complete:
			for tab: String in ["封存結論","證據鏈","曾選錯"]:
				var destination: String = {"封存結論":"evidence","證據鏈":"chain","曾選錯":"history"}[tab]
				var pick := button(tab,func() -> void: page = destination; history_index = 0; show_page(),tabs)
				current_tab(pick,page == destination or tab == "封存結論" and page not in ["chain","history"])
			sealed_results()
		elif page in ["evidence","fieldnote"]: _evidence()
		elif page == "original": original_page()
		elif page == "inspect": _inspect()
		elif page == "pinning": _pinning()
		elif page == "judgement": _judgement()
		elif page == "relations": _relations()
		else: _solve()
	if manager.entry().get("complete",false) and screen.y >= 700:
		label("案卷物件｜原件已留存，街區可回看處置。",14)
		if manager.active == "second_help":
			var replay := row()
			for choice: int in 3:
				button(["實際處置","付款回放","單件回放"][choice],func() -> void: manager.street_choice = choice; close(),replay)
	var breathing := TextureRect.new()
	breathing.name = "SourceContextFill"
	breathing.texture = load("res://assets/art/content-r2/"+manager.active+".webp") if not manager.active.is_empty() else load("res://assets/art/content-r1/investigation-desk.webp")
	breathing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	breathing.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	breathing.clip_contents = true
	breathing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breathing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(breathing)
	if manager.ready_to_solve():
		var status := Label.new(); status.name = "IllustrationState"
		status.text = illustration_caption()
		status.add_theme_color_override("font_color",Art.CHARCOAL)
		status.add_theme_font_size_override("font_size",16)
		var tag := StyleBoxFlat.new(); tag.bg_color = Art.AMBER if manager.active == "second_help" and not manager.entry().complete else Art.PAPER
		tag.content_margin_left = 8; tag.content_margin_right = 8; tag.content_margin_top = 4; tag.content_margin_bottom = 4
		status.add_theme_stylebox_override("normal",tag); status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		breathing.add_child(status)
		status.visible = breathing.size.y >= 30 and screen.y >= 400
		breathing.resized.connect(func() -> void: status.visible = breathing.size.y >= 30 and screen.y >= 400)
	var footer := row()
	if page != "hub":
		button("案件清單",open_hub,footer)
	else:
		button("取消街區導引",func() -> void: manager.suspend(); close(),footer)
	button("返回街區",close,footer,not manager.entry().get("complete",false))
	hud._refresh_mission()

func _evidence() -> void:
	var c: Dictionary = manager.definition()
	var short_page := get_viewport().get_visible_rect().size.y < 400
	var fieldnote := page == "fieldnote"
	if not compact and not fieldnote:
		label("待訪來源 → 到現場 → 取得證物 → 推論",14,Color("65502c"))
	if not fieldnote:
		var picks := row()
		for i: int in c.documents.size():
			current_tab(button((["首筆","末筆","索引"][i] if c.mode == "testimony" else ["甲","乙","丙"][i])+(" 已留存" if i in manager.entry().collected else " 待走訪"),func() -> void: document = i; show_page(),picks),i == document)
	var doc: Dictionary = c.documents[document]
	if not short_page: label(doc.title,21)
	if document in manager.entry().collected:
		if get_viewport().get_visible_rect().size.y >= 700 and not fieldnote: banner(manager.active)
		label(manager.document_text(document),18)
		if not short_page: label("來源："+doc.place+"｜同案原文已留存",14)
	else:
		if not short_page: label(c.brief,17)
		label("待走訪："+doc.place+"。靠近後點互動，才能留下這份證物。",18)
		if not compact: banner(manager.active)
	if manager.pending() >= 0:
		if not fieldnote:
			label("下一站："+c.documents[manager.pending()].place,16)
			button("收起案卷，跟隨街區導引",close,null,true)
	elif not short_page:
		button("證物已齊，開始推論",func() -> void: page = "solve"; show_page(),null,true)

func _solve() -> void:
	if not manager.ready_to_solve():
		label("證物還沒收齊。先讀來源，回街區找人或核對原件。",18)
		button("查看待訪證物",func() -> void: page = "evidence"; document = manager.pending(); show_page())
		return
	var c: Dictionary = manager.definition()
	if c.mode == "contradiction":
		if manager.entry().compared:
			var original_body := body
			var side: VBoxContainer
			if get_viewport().get_visible_rect().size.y < 400:
				var split := row()
				var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(left)
				side = VBoxContainer.new(); side.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(side)
				left.size_flags_stretch_ratio = .7
				side.size_flags_stretch_ratio = 1.3
				body = left
			if get_viewport().get_visible_rect().size.y >= 400: label("步驟 2／2｜比對原件，決定處置",17)
			spread()
			var review_actions := row()
			for source: int in 2:
				button(("已回看 " if source in reviewed_originals else "展開原件 ")+["甲","乙"][source],func() -> void: open_original(source),review_actions)
			if side:
				body = side
			label(c.action_question,17)
			var last_action: Dictionary = {}
			for event: Dictionary in manager.entry().history:
				if event.kind == "action": last_action = event
			for position: int in c.action_choices.size():
				var i: int = (position+action_offset)%c.action_choices.size()
				var choice := button(c.action_choices[i],func() -> void: manager.choose_action(i); show_page())
				choice.disabled = not (0 in reviewed_originals and 1 in reviewed_originals)
				wrong_choice(choice,last_action.get("choice",-1) == i and i != int(c.action_answer))
			feedback_line(14,first_hint("action",last_action.get("feedback","")) if not last_action.is_empty() else "")
			body = original_body
		else:
			if not compact: label(c.reference+"\n"+c.short_question,14,Color("65502c"))
			elif get_viewport().get_visible_rect().size.y < 400: label(c.compact_comparison,13)
			_inspect()
	elif c.mode == "timeline":
		_timeline(c)
	elif c.mode == "testimony":
		var original_body := body
		var short_page := get_viewport().get_visible_rect().size.y < 400
		var side: VBoxContainer
		if short_page:
			var split := row()
			var left := VBoxContainer.new()
			left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			split.add_child(left)
			side = VBoxContainer.new()
			side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			split.add_child(side)
			body = left
		label("步驟 1／3｜"+c.statements[statement]+(" ✓" if manager.entry().pairs.has(str(statement)) else ""),19)
		var picks := row()
		for i: int in 3:
			var evidence_button := button(["首筆 林秀蘭\n17：50","末筆 陳奕廷\n18：10","索引 吳安琪"][i],func() -> void: selected_document = i; show_page(),picks)
			selected(evidence_button,i == selected_document)
			evidence_button.add_theme_font_size_override("font_size",13 if compact else 15)
		if not short_page:
			label("原件記收件時間，沒有記錄發言；用時間核對各人的『全部』說法。",14)
			record_strip()
		var verdicts := row()
		for i: int in 2:
			var b := button(["支持這句","推翻這句"][i],func() -> void:
				if statement == 2 and selected_document == 2 and i == 0:
					manager.begin_pin_review()
					page = "pinning"
				else: manager.pair(statement,selected_document,i)
				show_page()
			,verdicts)
			b.disabled = selected_document < 0
		if short_page:
			body = side
			record_strip()
		label("已核對 %d／3｜可直接重配，不扣分。" % manager.entry().pairs.size(),14)
		body = original_body
	if c.mode == "contradiction" and (get_viewport().get_visible_rect().size.y >= 400 or not manager.entry().compared) and not (compact and manager.entry().compared): source_summary()
	if c.mode != "contradiction" and not manager.feedback.is_empty() and get_viewport().get_visible_rect().size.y >= 400 and (c.mode != "timeline" or manager.entry().time_revealed and not manager.entry().time_checked and manager.feedback_is_error()):
		var feedback_label := label(manager.feedback,15,Art.RED if manager.feedback_is_error() else Art.CHARCOAL)
		feedback_label.name = "CaseFeedback"
		var gap := Control.new()
		gap.custom_minimum_size.y = 8
		body.add_child(gap)

func _card(parent: Node, index: int, revealed: bool) -> Button:
	var caption: String = (["甲 17：42","乙 17：55","丙 18：00"] if revealed else ["甲 車店收據","乙 交接摘要","丙 輪值資料"])[index]
	var b := button(caption,func() -> void: manager.add_time(index); show_page(),parent)
	b.set_meta("card_index",index)
	for state: String in ["normal","hover","pressed","focus"]:
		var paper_style := Art.paper()
		paper_style.content_margin_left = 3; paper_style.content_margin_right = 3
		paper_style.content_margin_top = 2; paper_style.content_margin_bottom = 2
		b.add_theme_stylebox_override(state,paper_style)
	for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: b.add_theme_color_override(state,Art.CHARCOAL)
	timeline_cards.append(b)
	var clue := Label.new()
	clue.text = manager.definition().documents[index].event
	clue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clue.add_theme_font_size_override("font_size",12 if get_viewport().get_visible_rect().size.y < 400 else 13 if compact else 15)
	clue.add_theme_color_override("font_color",Art.CHARCOAL)
	clue.set_meta("original_text",clue.text)
	clue.resized.connect(Paper.wrap_ink.bind(clue))
	parent.add_child(clue)
	Paper.wrap_ink.call_deferred(clue)
	return b

func _timeline(_c: Dictionary) -> void:
	var short_page := get_viewport().get_visible_rect().size.y < 400
	var revealed: bool = manager.entry().time_revealed
	if manager.entry().time_checked: _attachment(); return
	var original_body := body
	var destination: VBoxContainer
	if short_page:
		var split := row()
		var sources := VBoxContainer.new(); sources.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(sources)
		destination = VBoxContainer.new(); destination.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(destination)
		body = sources
	label("步驟 1／3｜排原件；再核對箭頭，最後揭時。",14)
	if not compact: label("先後由引用關係決定，時間暫不揭露。",14)
	if not compact: label("原件已全放入，可拖曳改排" if manager.entry().order.size() == 3 else "待放原件｜拖入下方；也可點選",14)
	var picks := row()
	for i: int in (display_cards if display_cards.size() == 3 else manager.time_cards()):
		if i in manager.entry().order: continue
		var cell := VBoxContainer.new(); cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL; picks.add_child(cell)
		_card(cell,i,revealed)
	if short_page: body = destination
	drag_lane = Control.new(); drag_lane.custom_minimum_size.y = 74; body.add_child(drag_lane)
	rail = Rail.new()
	rail.custom_minimum_size.y = 116 if short_page else 146 if compact else 180
	drop_zone = rail; rail.name = "TimelineDropZone"; body.add_child(rail)
	var slots := HBoxContainer.new(); rail.add_child(slots); slots.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slots.offset_left = 5; slots.offset_right = -5; slots.offset_top = 4; slots.offset_bottom = -4
	slots.add_theme_constant_override("separation",8)
	for i: int in 3:
		var cell := VBoxContainer.new(); cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL; slots.add_child(cell)
		var slot := Label.new(); slot.text = "第 %d 格" % (i+1)
		slot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.custom_minimum_size.y = 24 if short_page else 36 if compact else 44
		slot.add_theme_font_size_override("font_size",12 if compact else 14)
		slot.add_theme_color_override("font_color",Art.CHARCOAL); cell.add_child(slot); slot_labels.append(slot)
		slot_cells.append(cell)
		var card: Button
		if i < manager.entry().order.size(): card = _card(cell,int(manager.entry().order[i]),revealed)
		else:
			cell.add_child(Control.new())
			cell.add_child(Label.new())
		slot_buttons.append(card)
	var order_text := PackedStringArray()
	for i: int in manager.entry().order: order_text.append(["甲","乙","丙"][i])
	live_order = label("目前："+_order_text(manager.entry().order),16); live_order.name = "LiveOrder"
	var actions := row()
	button("撤回末張",func() -> void: manager.undo_time(); show_page(),actions)
	button("打亂牌位",func() -> void:
		display_cards = [[2,1,0],[1,0,2],[1,2,0],[0,2,1],[2,0,1]].pick_random(); show_page()
	,actions)
	button("核對關係",func() -> void: relation_index = 0; page = "relations"; show_page(),actions,true)
	body = original_body

func _update_slots(order: Array) -> void:
	# Hit targets and quotations preview the same insertion as the model.
	for i: int in slot_buttons.size():
		var b: Button = slot_buttons[i]
		var clue: Label = slot_cells[i].get_child(2)
		if i >= order.size():
			if is_instance_valid(b):
				timeline_cards.erase(b)
				slot_cells[i].remove_child(b); b.queue_free()
				slot_cells[i].add_child(Control.new()); slot_cells[i].move_child(slot_cells[i].get_child(2),1)
				slot_buttons[i] = null
			clue.text = ""
			continue
		var index: int = order[i]
		if not is_instance_valid(b):
			for child: Node in slot_cells[i].get_children().slice(1):
				slot_cells[i].remove_child(child); child.queue_free()
			b = _card(slot_cells[i],index,false)
			slot_buttons[i] = b
			clue = slot_cells[i].get_child(2)
		b.visible = true; b.modulate.a = 1
		b.text = ["甲 車店收據","乙 交接摘要","丙 輪值資料"][index]
		b.set_meta("original_text",b.text)
		Paper.wrap_ink.call_deferred(b)
		b.set_meta("card_index",index)
		clue.text = manager.definition().documents[index].event
		clue.set_meta("original_text",clue.text)
		Paper.wrap_ink.call_deferred(clue)

func _order_text(order: Array) -> String:
	var names := PackedStringArray()
	for i: int in order: names.append(["甲","乙","丙"][i])
	return " → ".join(names) if not names.is_empty() else "尚未放入"

func _relations() -> void:
	var original_body := body
	var source_body := body
	var side: VBoxContainer
	if get_viewport().get_visible_rect().size.y < 400:
		var split := row()
		source_body = VBoxContainer.new(); source_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(source_body)
		side = VBoxContainer.new(); side.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(side)
		source_body.add_theme_constant_override("separation",0)
		side.add_theme_constant_override("separation",0)
		body = source_body
	label("步驟 2／3｜選擇引用方向",18)
	var diagram := Links.new()
	diagram.name = "DocumentLinks"
	diagram.choices = manager.entry().relations.duplicate()
	diagram.custom_minimum_size.y = 78
	body.add_child(diagram)
	var picks := row()
	for i: int in 2:
		current_tab(button(["甲與乙","乙與丙"][i],func() -> void: relation_index = i; manager.feedback = ""; show_page(),picks),relation_index == i)
	label(["甲原文：本張先完成，才交給摘要引用。\n乙原文：『附件：車店收據。』","乙原文：已收到前張收據，晚班尚未開始。\n丙原文：『接班依據：已簽收的交接摘要。』"][relation_index],14)
	if side: body = side
	if not compact: label("箭頭從先完成的原件，指向引用它的文件。",14)
	var choices: Array = [["車店收據 → 交接摘要","交接摘要 → 車店收據"],["輪值資料 → 交接摘要","交接摘要 → 輪值資料"]][relation_index]
	var directions := row()
	for i: int in 2:
		var direction := button(choices[i],func() -> void: manager.choose_relation(relation_index,i); show_page(),directions)
		var chosen: bool = manager.entry().relations.get(str(relation_index),-1) == i
		selected(direction,chosen)
		wrong_choice(direction,chosen and i != [0,1][relation_index])
		checked_choice(direction,chosen and i == [0,1][relation_index])
	var correct: bool = manager.relations_correct(manager.entry().relations)
	if not compact or correct or manager.entry().relations.size() < 2: label("方向已核對，可以揭時。" if correct else "待修正：紅虛線方向。" if manager.entry().relations.size() == 2 else "待補：兩段引用方向都要核對。",14)
	var actions := row()
	var reveal := button("揭時核對",func() -> void:
		if manager.verify_time():
			reveal_count = 0; reveal_clock = 0; page = "solve"
		elif manager.entry().relations.get("0",-1) != 0: relation_index = 0
		elif manager.entry().relations.get("1",-1) != 1: relation_index = 1
		show_page()
	,actions,true)
	reveal.disabled = not correct
	button("回排序改排",func() -> void: page = "solve"; show_page(),actions)
	var error_index := -1
	for i: int in 2:
		if manager.entry().relations.has(str(i)) and manager.entry().relations[str(i)] != [0,1][i]:
			error_index = i
			if i == relation_index: break
	if error_index >= 0: feedback_line(13 if compact else 14,first_hint("relation",manager.relation_error(error_index)))
	if side: body = source_body
	body = original_body

func _pinning() -> void:
	var original_body := body
	var short_page := get_viewport().get_visible_rect().size.y < 400
	var controls: VBoxContainer
	if short_page:
		var split := row()
		var band := VBoxContainer.new()
		band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		split.add_child(band)
		controls = VBoxContainer.new()
		controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		split.add_child(controls)
		body = band
	else: label("步驟 3／3｜釘入紀錄帶",19)
	record_strip(false,true)
	if short_page: body = controls
	var picks := row()
	for i: int in 3:
		var repair := button(("拔釘 " if i in manager.entry().pins else "判定 ")+["17：50","前後合看","18：10"][i],func() -> void:
			pin_index = i
			if i in manager.entry().pins: manager.unpin_record(i)
			page = "judgement"; show_page()
		,picks)
		if not manager.pin_error(i).is_empty(): repair.add_theme_color_override("font_color",Art.RED)
	var ready: bool = manager.pins_correct()
	label("三筆判定相符，可以封存。" if ready else "已釘 %d／3；可拔釘重選。" % manager.entry().pins.size(),14)
	for i: int in 3:
		var error: String = manager.pin_error(i)
		if not error.is_empty():
			var ink := label(first_hint("pin",error),14,Art.RED)
			var marker := StyleBoxFlat.new(); marker.bg_color = Color.TRANSPARENT; marker.border_color = Art.RED; marker.border_width_left = 3; marker.content_margin_left = 6
			ink.add_theme_stylebox_override("normal",marker)
	var seal := button("封存三筆判定",func() -> void: manager.seal_records(); show_page(),null,true)
	seal.disabled = not ready
	if not compact: label(manager.definition().boundary,14,Color("65502c"))
	body = original_body

func _judgement() -> void:
	var original_body := body
	var short_page := get_viewport().get_visible_rect().size.y < 400
	var side: VBoxContainer
	if get_viewport().get_visible_rect().size.y < 400:
		var split := row()
		var source := VBoxContainer.new(); source.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(source)
		side = VBoxContainer.new(); side.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(side)
		source.size_flags_stretch_ratio = .7
		side.size_flags_stretch_ratio = 1.3
		body = source
	label("步驟 2／3｜"+(["首筆","合看","末筆"] if get_viewport().get_visible_rect().size.y < 400 else ["首筆反證","前後兩筆一起核對","末筆反證"])[pin_index],18)
	label(["原件記載｜17：50 收件\n記錄人：林秀蘭；未記發言。","索引原文｜吳安琪提供，只供定位。"+("\n分界：18：00（非原件）" if short_page else ""),"原件記載｜18：10 收件\n記錄人：陳奕廷；未記發言。"][pin_index],13 if short_page else 14)
	if not short_page:
		var axis := Rail.new(); axis.name = "JudgementTimeAxis"; axis.record_mode = true
		axis.custom_minimum_size.y = 48
		body.add_child(axis)
		var ticks := HBoxContainer.new(); axis.add_child(ticks)
		ticks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for time: String in ["17：50 原件","18：00 分界","18：10 原件"]:
			var tick := Label.new(); tick.text = time; tick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tick.vertical_alignment = VERTICAL_ALIGNMENT_TOP; tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; tick.add_theme_font_size_override("font_size",14)
			tick.add_theme_color_override("font_color",Art.CHARCOAL); ticks.add_child(tick)
	if pin_index == 1:
		if manager.entry().support_refs.size() < 2 and get_viewport().get_visible_rect().size.y >= 400: label(manager.support_missing(),14,Art.CHARCOAL)
		var refs := row()
		for i: int in [0,2]:
			var reference := button(("已引用 " if i in manager.entry().support_refs else "引用 ")+["17：50","","18：10"][i],func() -> void:
				if i in manager.entry().support_refs: manager.uncite_support(i)
				else: manager.reference_support(i)
				manager.feedback = ""; show_page()
			,refs)
			selected(reference,i in manager.entry().support_refs)
			checked_choice(reference,i in manager.entry().support_refs)
	if side: body = side
	if not short_page:
		var boundary := label("18：00  ┄ 分界，不是原件 ┄",14,Color("766c5c"))
		boundary.name = "BoundaryNotOriginal"
	var choices: Node = row() if short_page else body
	for i: int in 3:
		var decision := button(["林秀蘭：\n兩筆全在前","陳奕廷：\n兩筆全在後","吳安琪：\n前後都有"][i],func() -> void: manager.choose_pin(pin_index,i); show_page(),choices)
		if not short_page:
			decision.text = ["林秀蘭｜七號簿上那兩筆，全在傍晚六點以前。","陳奕廷｜我記得七號簿那兩筆都在六點以後。","吳安琪｜同一本簿，有六點以前，也有六點以後。"][i]
			decision.set_meta("original_text",decision.text)
			decision.add_theme_font_size_override("font_size",13 if compact else 16)
		selected(decision,manager.entry().pin_choices.get(str(pin_index),-1) == i)
		# Candidate claims remain selectable; evidence gates the pin action.
		if not decision.get_meta("selected",false):
			var paper_style := StyleBoxFlat.new(); paper_style.bg_color = Art.PAPER; paper_style.border_color = Art.KRAFT; paper_style.set_border_width_all(1)
			paper_style.content_margin_left = 10; paper_style.content_margin_right = 10
			paper_style.content_margin_top = 6; paper_style.content_margin_bottom = 6
			for state: String in ["normal","hover","pressed","focus"]: decision.add_theme_stylebox_override(state,paper_style)
			for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: decision.add_theme_color_override(state,Art.CHARCOAL)
	var selected: int = manager.entry().pin_choices.get(str(pin_index),-1)
	# Source sufficiency is already stated above; verdict reasons belong to the
	# pinned record. Do not repeat stale pairing feedback between these controls.
	var judgement_actions := row()
	var pin := button("釘上 "+["17：50","前後合看","18：10"][pin_index],func() -> void: manager.pin_record(pin_index); page = "pinning"; show_page(),judgement_actions,true)
	pin.disabled = selected < 0 or pin_index == 1 and manager.entry().support_refs.size() < 2
	button("回紀錄帶",func() -> void: page = "pinning"; show_page(),judgement_actions)
	body = original_body

func _attachment() -> void:
	label("步驟 3／3｜揭時印證，再貼回收據",18)
	if get_viewport().get_visible_rect().size.y >= 400:
		var diagram := Links.new()
		diagram.name = "RevealedDocumentLinks"
		diagram.choices = manager.entry().relations.duplicate()
		diagram.revealed = manager.entry().reveal_steps.count(3)-1
		diagram.reveal_steps = manager.entry().reveal_steps.duplicate()
		diagram.time_confirmed = manager.entry().reveal_steps == [3,3,3]
		diagram.custom_minimum_size.y = 90
		body.add_child(diagram)
	var steps: Array = manager.entry().get("reveal_steps",[0,0,0])
	reveal_count = steps.count(3)
	if reveal_count < 3:
		label("親手揭時｜拖動紙封條；長按可逐格揭開",16)
		var mask := TimeMask.new()
		mask.name = "VisibleTimeMask"
		mask.panel = self
		mask.custom_minimum_size.y = 132 if compact else 180
		body.add_child(mask)
		label("鬆手停住，往回拖可遮回。三張全揭後才開放貼件。",14)
		var locked := button("貼回收據｜揭時後開放",func() -> void: pass)
		locked.disabled = true
		return
	label("17：42 收據 → 17：55 摘要 → 18：00 輪值",16)
	if get_viewport().get_visible_rect().size.y >= 400: label("以收據核對輪值起點，拖入原件旁的附件框。",16)
	var desk := row()
	var receipt := Paper.make({"title":"甲｜車店收據"},["17：42\n"+("已退回原位" if notice.begins_with("位置不對") else "已備妥・按住拖曳" if selected_document == 0 else "點選拿起收據")],-1,[],compact,func(_field: int) -> void: selected_document = 0; notice = ""; show_page())
	desk.add_child(receipt)
	var target := Paper.make({"title":"丙｜輪值資料"},["18：00\n拖到此處"],-1,[],compact,func(_field: int) -> void:
		notice = "請把甲收據拖進丙件框內。"; show_page()
	)
	desk.add_child(target)
	attachment_receipt = receipt; attachment_target = target
	if selected_document == 0:
		var frame := Panel.new(); frame.name = "AttachmentTarget"; frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := StyleBoxFlat.new(); box.bg_color = Color.TRANSPARENT; box.border_color = Art.AMBER; box.set_border_width_all(2)
		frame.add_theme_stylebox_override("panel",box)
		# Keep the frame outside PanelContainer's child layout: a managed child
		# would be stretched onto the text content rather than the paper edge.
		surface.add_child(frame)
		var fit := func() -> void:
			if is_instance_valid(frame) and is_instance_valid(target):
				frame.position = target.get_global_rect().position+Vector2(4,4)
				frame.size = target.size-Vector2(8,8)
		target.item_rect_changed.connect(fit)
		fit.call_deferred()
	for paper: PanelContainer in [receipt,target]:
		var inset: StyleBoxTexture = paper.get_theme_stylebox("panel").duplicate()
		inset.content_margin_left = 12; inset.content_margin_right = 12
		paper.add_theme_stylebox_override("panel",inset)
		var heading: Label = paper.get_child(0).get_child(0)
		heading.text = ("甲｜車店收據" if paper == receipt else "丙｜輪值資料")+"\n原件"
		heading.set_meta("original_text",heading.text)
		heading.add_theme_font_size_override("font_size",14 if compact else 16)
		for b: Button in paper.find_children("*","Button",true,false): b.custom_minimum_size.y = 76
	attachment_lane = Control.new(); attachment_lane.name = "ReceiptDragLane"; attachment_lane.custom_minimum_size.y = 52; body.add_child(attachment_lane)
	label(notice if not notice.is_empty() else "按住收據拖入附件框，放錯退回。" if selected_document == 0 else "先拿起左邊收據，再拖到右邊。",14)
	label(manager.definition().boundary,14,Color("65502c"))

func _inspect() -> void:
	var c: Dictionary = manager.definition()
	var short_page := get_viewport().get_visible_rect().size.y < 400
	if c.mode == "contradiction" and not short_page and get_viewport().get_visible_rect().size.y >= 800: label("步驟 1／2｜標出兩份收費原句",14)
	# Small portrait magnification keeps the same font and complete paper;
	# source switches share the existing tab row instead of consuming a row.
	var picks := navigation_tabs if compact and not short_page and page == "inspect" and c.mode == "contradiction" else row()
	for i: int in c.documents.size():
		current_tab(button((["首筆","末筆","索引"][i] if c.mode == "testimony" else ["甲","乙","丙"][i])+" 原件",func() -> void: document = i; marked_field = -1; show_page(),picks),i == document)
	var fields: Array = c.documents[document].fields.duplicate()
	if short_page:
		# Keep long provenance/edition clauses across the paper width rather
		# than squeezing them into one of the narrow horizontal ink columns.
		var context := PackedStringArray()
		for i: int in fields.size():
			var clauses: PackedStringArray = fields[i].split("\n")
			fields[i] = clauses[0]
			for j: int in range(1,clauses.size()): context.append(clauses[j])
		if not context.is_empty(): label("\n".join(context),13)
	if c.mode == "timeline" and not manager.entry().time_revealed:
		for i: int in fields.size():
			for time: String in ["17：42","17：55","18：00"]: fields[i] = fields[i].replace(time,"〔確認後揭時〕")
	var chosen: int = int(manager.entry().citations.get(str(document),-1)) if c.mode == "contradiction" else marked_field
	if c.mode == "contradiction" and chosen != 2: chosen = -1
	var viewed: Array = manager.entry().viewed_fields.get(str(document),[]) if c.mode == "contradiction" else []
	if short_page:
		var columns := row()
		for i: int in fields.size():
			var paper := Paper.make({"title":(["首筆","末筆","索引"] if c.mode == "testimony" else ["甲","乙","丙"])[document]},[fields[i]],0 if chosen == i else -1,[],true,func(_field: int) -> void: _cite(i))
			var short_inset: StyleBoxTexture = paper.get_theme_stylebox("panel").duplicate()
			short_inset.content_margin_top = 3; short_inset.content_margin_bottom = 3
			paper.add_theme_stylebox_override("panel",short_inset)
			columns.add_child(paper)
			var field_button: Button = paper.find_child("CitedField0",true,false)
			field_button.name = "CitedField"+str(i)
			field_button.add_theme_font_size_override("font_size",12)
	else:
		var original := Paper.make(c.documents[document],fields,chosen,viewed,compact,func(i: int) -> void: _cite(i))
		body.add_child(original)
		if page == "inspect":
			for ink: Button in original.find_children("*","Button",true,false): ink.add_theme_font_size_override("font_size",16 if compact else 20 if get_viewport().get_visible_rect().size.x < 400 else 22)
	if c.mode == "contradiction":
		var missing := "點紙上的收費句。"
		if chosen >= 0: missing = "已選："+fields[chosen].get_slice("：",0)
		if not manager.feedback.is_empty() and marked_field >= 0 and marked_field != 2: missing = manager.feedback
		var both: bool = manager.entry().citations.get("0",-1) == 2 and manager.entry().citations.get("1",-1) == 2
		if not short_page: label("已標 %d／2｜" % [int(manager.entry().citations.get("0",-1) == 2)+int(manager.entry().citations.get("1",-1) == 2)]+missing+"｜"+("甲乙已選" if both else "還缺"+("甲乙" if manager.entry().citations.is_empty() else "甲" if not manager.entry().citations.has("0") else "乙")),14,Color("8e1b12") if chosen >= 0 and chosen != 2 else Art.CHARCOAL)
		var compare := button("核對兩處黃標",func() -> void:
			manager.compare_choice(int(c.answer) if manager.entry().citations.get("0",-1) == 2 and manager.entry().citations.get("1",-1) == 2 else (int(c.answer)+1)%c.choices.size())
			page = "solve"; show_page()
		,null,true)
		compare.disabled = not both
	else:
		button("回到核對",func() -> void: page = "solve"; show_page(),null,true)

func _review_chain() -> void:
	var c: Dictionary = manager.definition()
	var original_body := body
	if c.mode == "contradiction":
		spread()
		label("已引用：甲的承諾、乙的要求。",16)
	elif c.mode == "timeline":
		label("你排的順序："+_order_text(manager.entry().order),16)
		for i: int in 2:
			var choice: int = manager.entry().relations.get(str(i),-1)
			label(["甲乙關係：","乙丙關係："][i]+("舊版未留選句" if choice < 0 else [["摘要引用收據，收據在前","收據引用摘要，摘要在前"],["摘要引用輪值，輪值在前","輪值沿用摘要，摘要在前"]][i][choice]),16)
	else:
		if get_viewport().get_visible_rect().size.y < 400:
			var split := row()
			var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(left)
			var right := VBoxContainer.new(); right.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(right)
			body = left; record_strip(true)
			body = right
		else: record_strip(true)
		label("你引用了首筆 17：50 與末筆 18：10。",14)
	label(c.boundary,14)
	body = original_body

func _review_history() -> void:
	var events: Array = manager.entry().get("history",[]).filter(func(e: Dictionary) -> bool: return not e.feedback.is_empty())
	if events.is_empty():
		label("沒有留存錯選紀錄。",16)
	else:
		history_index = clampi(history_index,0,events.size()-1)
		var event: Dictionary = events[history_index]
		label("曾選錯 %d／%d" % [history_index+1,events.size()],16)
		var decision: String = manager.definition().action_choices[int(event.choice)] if event.kind == "action" else ["17：50","前後合看","18：10"][int(event.index)]+" → "+["反駁林秀蘭『全在前』","反駁陳奕廷『全在後』","支持吳安琪『前後都有』"][int(event.choice)] if event.kind == "pin" else "文件關係選擇"
		label("這次錯選｜你當時的選擇："+decision,16)
		label(event.feedback,14,Art.RED)
		var navigation := row()
		button("上一筆",func() -> void: history_index = maxi(0,history_index-1); show_page(),navigation).disabled = history_index == 0
		button("下一筆",func() -> void: history_index = mini(events.size()-1,history_index+1); show_page(),navigation).disabled = history_index == events.size()-1
	label(manager.definition().boundary,14)

func _cite(index: int) -> void:
	marked_field = index
	cited_fields[document] = index
	if manager.definition().mode == "contradiction": manager.cite(document,index)
	show_page()

func diagnostics() -> Dictionary:
	var buttons: Array = []
	var labels: Array = []
	var art_path := ""
	var art_rect: Array = []
	if is_instance_valid(surface):
		for b: Node in surface.find_children("*","Button",true,false):
			if not b.is_visible_in_tree(): continue
			var r: Rect2 = b.get_global_rect()
			buttons.append({"text":b.get_meta("original_text",b.text),"rendered_text":b.text,"rect":[r.position.x,r.position.y,r.size.x,r.size.y],"disabled":b.disabled,"selected":b.get_meta("selected",false),"current_tab":b.get_meta("current_tab",false),"primary":b.get_meta("primary_action",false),"font_size":b.get_theme_font_size("font_size"),"color":b.get_theme_color("font_color").to_html(),"background":b.get_theme_stylebox("normal").bg_color.to_html() if b.get_theme_stylebox("normal") is StyleBoxFlat else "paper_texture"})
		for l: Node in surface.find_children("*","Label",true,false):
			if l == drag_ghost or not l.is_visible_in_tree(): continue
			var r: Rect2 = l.get_global_rect()
			labels.append({"text":l.get_meta("original_text",l.text).replace("\u2060",""),"rendered_text":l.text,"rect":[r.position.x,r.position.y,r.size.x,r.size.y],"color":l.get_theme_color("font_color").to_html()})
		var picture := surface.find_child("CaseEvidenceArt",true,false) as TextureRect
		if picture and picture.texture:
			art_path = picture.texture.resource_path
			var r := picture.get_global_rect()
			art_rect = [r.position.x,r.position.y,r.size.x,r.size.y]
	var drop: Array = []
	if is_instance_valid(drop_zone):
		var r := drop_zone.get_global_rect()
		drop = [r.position.x,r.position.y,r.size.x,r.size.y]
	var ghost: Array = []
	if is_instance_valid(drag_ghost):
		var r := drag_ghost.get_global_rect(); ghost = [r.position.x,r.position.y,r.size.x,r.size.y]
	var paper_rect: Array = []
	var mask_rect: Array = []
	if is_instance_valid(surface):
		var mask := surface.find_child("VisibleTimeMask",true,false) as Control
		if mask:
			var bounds := mask.get_global_rect()
			mask_rect = [bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]
	if is_instance_valid(surface):
		var sheet := surface.find_child("CaseSheet",true,false) as Control
		if sheet:
			var r := sheet.get_global_rect(); paper_rect = [r.position.x,r.position.y,r.size.x,r.size.y]
	return {"attachment_source":_bounds(attachment_receipt),"attachment_target":_bounds(attachment_target),"attachment_dragging":attachment_moved and attachment_held,"attachment_notice":notice,"time_mask_rect":mask_rect,"reveal_steps":manager.entry().get("reveal_steps",[]),"paper_rect":paper_rect,"revealed_cards":reveal_count,"ghost_text":drag_ghost.text if is_instance_valid(drag_ghost) else "","slot_order":slot_buttons.map(func(b: Button) -> int: return int(b.get_meta("card_index",-1)) if is_instance_valid(b) else -1),"ghost_rect":ghost,"pin_choices":manager.entry().get("pin_choices",{}).duplicate(),"visible":is_instance_valid(surface),"page":page,"document":document,"statement":statement,"buttons":buttons,"labels":labels,"art":art_path,"art_rect":art_rect,"drop_zone":drop,"dragging":drag_moved and drag_card >= 0,"marked_field":marked_field,"preview_slot":rail.preview if is_instance_valid(rail) and not rail.record_mode else -1}

func _bounds(control: Control) -> Array:
	if not is_instance_valid(control): return []
	var r := control.get_global_rect()
	return [r.position.x,r.position.y,r.size.x,r.size.y]
