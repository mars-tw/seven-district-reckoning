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
const Paper = preload("res://scripts/ui/investigation_paper.gd")
const Rail = preload("res://scripts/ui/investigation_rail.gd")
const Links = preload("res://scripts/ui/investigation_links.gd")

func _process(delta: float) -> void:
	if reveal_count < 0 or reveal_count >= 3 or not is_instance_valid(surface): return
	reveal_clock += delta
	if reveal_clock >= .8:
		reveal_clock = 0
		reveal_count += 1
		show_page()

class DraggedPaper extends Label:
	func _draw() -> void:
		var ink := Color("16181d")
		draw_arc(Vector2(18,size.y-18),4,PI,TAU,16,ink,1.5,true)
		draw_rect(Rect2(13,size.y-18,10,9),ink,false,1.5)
		draw_line(Vector2(18,size.y-15),Vector2(18,size.y-12),ink,1.5,true)

func _input(event: InputEvent) -> void:
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
			drag_ghost = DraggedPaper.new()
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
	manager.start(id)
	page = "pinning" if manager.entry().get("judging",false) and not manager.entry().complete else "evidence"
	document = 0
	statement = 0
	selected_document = -1
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
	b.text = "你選的｜"+b.text
	b.set_meta("original_text",b.text)
	var style := StyleBoxFlat.new()
	style.bg_color = Art.PAPER
	style.border_color = Art.RED
	style.set_border_width_all(3)
	style.content_margin_top = 2; style.content_margin_bottom = 2
	for key: String in ["normal","hover","pressed","focus"]: b.add_theme_stylebox_override(key,style)
	for key: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: b.add_theme_color_override(key,Art.RED)

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
	label("｜".join(sources),12 if get_viewport().get_visible_rect().size.x < 360 else 14,Color("65502c")).name = "SourceSummary"

func record_strip(sealed: bool = false, pinning: bool = false) -> void:
	var strip := Rail.new()
	strip.name = "RecordRibbon"
	strip.record_mode = true
	strip.sealed = sealed
	strip.pinned = manager.entry().pins
	strip.highlights = ([0] if selected_document == 0 else [2] if selected_document == 1 else [0,1,2]) if selected_document >= 0 else [[2],[0],[0,1,2]][statement]
	strip.custom_minimum_size.y = (184 if compact else 214) if sealed or pinning else 150
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
		for text: String in [["首筆原文","玩家推論","末筆原文"][i],["林秀蘭記","首筆＋末筆","陳奕廷記"][i]]:
			var caption := Label.new()
			caption.text = text
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.add_theme_font_size_override("font_size",12)
			caption.add_theme_color_override("font_color",Color("766c5c"))
			cell.add_child(caption)
		if sealed or i in manager.entry().pins:
			var result := Label.new()
			var choice: int = int(manager.entry().pin_choices.get(str(i),[1,2,0][i]))
			result.text = ("↓錯釘\n" if not manager.pin_error(i).is_empty() else "↓已核對\n")+["反駁林秀蘭\n『全在前』","反駁陳奕廷\n『全在後』","支持吳安琪\n『前後都有』"][choice]
			result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			result.add_theme_font_size_override("font_size",12)
			result.add_theme_color_override("font_color",Art.RED if not manager.pin_error(i).is_empty() else Art.CHARCOAL)
			cell.add_child(result)
	if sealed and not compact:
		label("兩筆原始紀錄 → 玩家推論",18)
		label("17：50 在前，18：10 在後。\n合看支持吳安琪『前後都有』；\n18：00 只作分界，沒有第三筆原件。",16)

func spread() -> void:
	label(manager.definition().reference,13)
	var pages := row()
	for i: int in 2:
		var paper := Paper.make(manager.definition().documents[i],[manager.definition().documents[i].fields[2]],0,[],true,func(_field: int) -> void: pass)
		pages.add_child(paper)
		for b: Button in paper.find_children("*","Button",true,false):
			b.disabled = true
			b.add_theme_color_override("font_disabled_color",Art.CHARCOAL)
			b.add_theme_stylebox_override("disabled",b.get_theme_stylebox("normal"))

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
		label("最終順序：甲 收據 → 乙 摘要 → 丙 輪值",16)
		var documents_row: HBoxContainer
		if get_viewport().get_visible_rect().size.y < 400: documents_row = row()
		for i: int in 3:
			var doc: Dictionary = c.documents[i]
			var fields: Array = [["17：42｜收據供摘要引用。"],["17：55｜摘要附件為甲收據。"],["18：00｜晚班開始；依據為已簽收摘要。"]][i]
			var paper := Paper.make(doc,fields,0,[],true,func(_field: int) -> void: pass)
			(documents_row if documents_row else body).add_child(paper)
			for b: Button in paper.find_children("*","Button",true,false):
				b.disabled = true
				b.add_theme_color_override("font_disabled_color",Art.CHARCOAL)
				b.add_theme_stylebox_override("disabled",b.get_theme_stylebox("normal"))
		label("收據早於晚班，晚班開立的猜測已被推翻。",18)
		label(c.boundary,14,Color("65502c"))
	else:
		spread()
		label(c.seal_comparison,18)
		label("安全行動："+c.action_choices[int(c.action_answer)]+"。",18)
		if get_viewport().get_visible_rect().size.y >= 400: label("同機構、同案號；乙件備註：未撤回原承諾。",14)
		label(c.boundary,14,Color("65502c"))

func show_page() -> void:
	drag_card = -1
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
	var center: Container = MarginContainer.new() if manager.entry().get("complete",false) or timeline_page else CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.add_child(center)
	var sheet := PanelContainer.new()
	sheet.name = "CaseSheet"
	sheet.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL if manager.entry().get("complete",false) or timeline_page else Control.SIZE_SHRINK_BEGIN
	sheet.custom_minimum_size.x = minf(screen.x-16,760)
	var paper := Art.paper(true)
	if manager.active == "second_help" and page in ["inspect","solve"] and not manager.entry().complete and screen.y >= 700:
		sheet.custom_minimum_size.y = 680
	paper.content_margin_left = 12 if compact else 20
	paper.content_margin_right = 12
	if timeline_portrait and compact:
		paper.content_margin_left = 6; paper.content_margin_right = 6
	if compact:
		paper.content_margin_top = 0 if screen.y < 400 else 3
		paper.content_margin_bottom = 0 if screen.y < 400 else 3
	sheet.add_theme_stylebox_override("panel",paper)
	center.add_child(sheet)
	var margin := MarginContainer.new()
	sheet.add_child(margin)
	for side: String in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,2 if screen.y < 400 and side in ["top","bottom"] else 4 if screen.y < 400 or compact and side in ["top","bottom"] else 8 if compact else 14)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation",0 if screen.y < 400 else 2 if compact else 8)
	margin.add_child(body)
	if page == "hub" or timeline_portrait or (screen.y >= 400 and not (compact and (page in ["solve","inspect","relations"] or manager.entry().get("complete",false)))): label("街坊查證簿" if page == "hub" else manager.definition().title,24)
	if page == "hub":
		banner()
		label("走訪取證，再回案卷比對。進度會自動保存。",16)
		for c: Dictionary in manager.definitions:
			button(("已封存・"+c.result+"｜" if manager.records[c.id].complete else "待查證｜")+c.title,open_case.bind(c.id))
		label("人物、機構與案件均為虛構。只核對證據，不猜誰有罪。",14)
	else:
		var tabs := row()
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
				current_tab(pick,page == destination)
			sealed_results()
		elif page in ["evidence","fieldnote"]: _evidence()
		elif page == "inspect": _inspect()
		elif page == "pinning": _pinning()
		elif page == "judgement": _judgement()
		elif page == "relations": _relations()
		else: _solve()
	if manager.entry().get("complete",false) and screen.y >= 700:
		var fill := Control.new(); fill.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_child(fill)
		label("案卷物件｜原件已留存，街區可回看處置。",14)
		if manager.active == "second_help":
			var replay := row()
			for choice: int in 3:
				button(["實際處置","付款回放","單件回放"][choice],func() -> void: manager.street_choice = choice; close(),replay)
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
			if side:
				label("甲乙原件均已留存",13)
				body = side
			label(c.action_question,17)
			var last_action: Dictionary = {}
			for event: Dictionary in manager.entry().history:
				if event.kind == "action": last_action = event
			for i: int in c.action_choices.size():
				var choice := button(c.action_choices[i],func() -> void: manager.choose_action(i); show_page())
				wrong_choice(choice,last_action.get("choice",-1) == i and i != int(c.action_answer))
			feedback_line(14,last_action.get("feedback",""))
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
			label("原文提供者與被核對的說法，可能來自不同人。",14)
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
		selected(button(choices[i],func() -> void: manager.choose_relation(relation_index,i); show_page(),directions),manager.entry().relations.get(str(relation_index),-1) == i)
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
	if error_index >= 0: feedback_line(13 if compact else 14,manager.relation_error(error_index))
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
		button(("拔釘 " if i in manager.entry().pins else "判定 ")+["17：50","前後合看","18：10"][i],func() -> void:
			pin_index = i
			if i in manager.entry().pins: manager.unpin_record(i)
			page = "judgement"; show_page()
		,picks)
	var ready: bool = manager.pins_correct()
	label("三筆判定相符，可以封存。" if ready else "已釘 %d／3；可拔釘重選。" % manager.entry().pins.size(),14)
	for i: int in 3:
		var error: String = manager.pin_error(i)
		if not error.is_empty(): label(error,14,Art.RED)
	var seal := button("封存三筆判定",func() -> void: manager.seal_records(); show_page(),null,true)
	seal.disabled = not ready
	label(manager.definition().boundary,14,Color("65502c"))
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
	label(["首筆原文｜林秀蘭記\n17：50。首筆不能代表整本簿。","索引原文｜吳安琪提供，只供定位。\n原件：17：50、18：10\n分界：18：00（非原件）","末筆原文｜陳奕廷記\n18：10。末筆不能代表整本簿。"][pin_index],13 if short_page and pin_index == 1 else 16)
	if pin_index != 1: label("18：00 分界：整點既非以前，也非以後。",14)
	if pin_index == 1:
		if manager.entry().support_refs.size() < 2 and get_viewport().get_visible_rect().size.y >= 400: label(manager.support_missing(),14,Art.RED)
		var refs := row()
		for i: int in [0,2]:
			selected(button(("已引用 " if i in manager.entry().support_refs else "引用 ")+["17：50","","18：10"][i],func() -> void:
				if i in manager.entry().support_refs: manager.uncite_support(i)
				else: manager.reference_support(i)
				manager.feedback = ""; show_page()
			,refs),i in manager.entry().support_refs)
	if side: body = side
	var choices := row()
	for i: int in 3:
		var decision := button(["反駁林秀蘭：\n全在前","反駁陳奕廷：\n全在後","支持吳安琪：\n前後都有"][i],func() -> void: manager.choose_pin(pin_index,i); show_page(),choices)
		selected(decision,manager.entry().pin_choices.get(str(pin_index),-1) == i)
		decision.disabled = pin_index == 1 and manager.entry().support_refs.size() < 2
	var selected: int = manager.entry().pin_choices.get(str(pin_index),-1)
	label("尚未選擇判定。" if selected < 0 else ["17：50（分界前）","首筆＋末筆（玩家合看）","18：10（分界後）"][pin_index]+" → "+["反駁林秀蘭『全在前』","反駁陳奕廷『全在後』","支持吳安琪『前後都有』"][selected],16)
	feedback_line()
	var pin := button("釘上 "+["17：50","前後合看","18：10"][pin_index],func() -> void: manager.pin_record(pin_index); page = "pinning"; show_page(),null,true)
	pin.disabled = selected < 0
	button("回紀錄帶",func() -> void: page = "pinning"; show_page())
	body = original_body

func _attachment() -> void:
	label("步驟 3／3｜揭時印證，再貼回收據",18)
	if get_viewport().get_visible_rect().size.y >= 400:
		var diagram := Links.new()
		diagram.name = "RevealedDocumentLinks"
		diagram.choices = manager.entry().relations.duplicate()
		diagram.revealed = reveal_count-1 if reveal_count >= 0 else 2
		diagram.custom_minimum_size.y = 90
		body.add_child(diagram)
	if reveal_count >= 0 and reveal_count < 3:
		label("正在揭開第 %d／3 張時間遮罩。" % (reveal_count+1),16)
		return
	label("17：42 收據 → 17：55 摘要 → 18：00 輪值",16)
	if get_viewport().get_visible_rect().size.y >= 400: label("收據早於晚班；貼在輪值單旁，留下反查依據。",16)
	var desk := row()
	var receipt := Paper.make({"title":"甲｜車店收據"},["17：42\n"+("已拿起・點右側貼入" if selected_document == 0 else "點選拿起收據")],0 if selected_document == 0 else -1,[],compact,func(_field: int) -> void: selected_document = 0; show_page())
	desk.add_child(receipt)
	var target := Paper.make({"title":"丙｜輪值資料"},["18：00\n貼入收據 →"],-1,[],compact,func(_field: int) -> void:
		if selected_document == 0: manager.seal_time(0); show_page()
	)
	desk.add_child(target)
	for paper: PanelContainer in [receipt,target]:
		for b: Button in paper.find_children("*","Button",true,false): b.custom_minimum_size.y = 76
	label("已拿起收據，再點右邊的貼件位置。" if selected_document == 0 else "先拿起左邊收據，再貼到右邊。",14)
	label(manager.definition().boundary,14,Color("65502c"))

func _inspect() -> void:
	var c: Dictionary = manager.definition()
	var short_page := get_viewport().get_visible_rect().size.y < 400
	if c.mode == "contradiction" and not short_page and get_viewport().get_visible_rect().size.y >= 800: label("步驟 1／2｜標出兩份收費原句",14)
	var picks := row()
	for i: int in c.documents.size():
		current_tab(button((["首筆","末筆","索引"][i] if c.mode == "testimony" else ["甲","乙","丙"][i])+" 原件",func() -> void: document = i; marked_field = -1; show_page(),picks),i == document)
	var fields: Array = c.documents[document].fields.duplicate()
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
			columns.add_child(paper)
			var field_button: Button = paper.find_child("CitedField0",true,false)
			field_button.name = "CitedField"+str(i)
			field_button.add_theme_font_size_override("font_size",12)
	else:
		var original := Paper.make(c.documents[document],fields,chosen,viewed,compact,func(i: int) -> void: _cite(i))
		body.add_child(original)
		if page == "inspect":
			for ink: Button in original.find_children("*","Button",true,false): ink.add_theme_font_size_override("font_size",16 if compact else 22)
	if c.mode == "contradiction":
		var missing := "點紙上的收費句。"
		if chosen >= 0: missing = "已選："+fields[chosen].get_slice("：",0)
		if not manager.feedback.is_empty() and marked_field >= 0 and marked_field != 2: missing = manager.feedback
		var both: bool = manager.entry().citations.get("0",-1) == 2 and manager.entry().citations.get("1",-1) == 2
		if not short_page: label(missing+"｜"+("甲乙已選" if both else "還缺"+("甲乙" if manager.entry().citations.is_empty() else "甲" if not manager.entry().citations.has("0") else "乙")),14,Color("8e1b12") if chosen >= 0 and chosen != 2 else Art.CHARCOAL)
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
	if is_instance_valid(surface):
		var sheet := surface.find_child("CaseSheet",true,false) as Control
		if sheet:
			var r := sheet.get_global_rect(); paper_rect = [r.position.x,r.position.y,r.size.x,r.size.y]
	return {"paper_rect":paper_rect,"revealed_cards":reveal_count,"ghost_text":drag_ghost.text if is_instance_valid(drag_ghost) else "","slot_order":slot_buttons.map(func(b: Button) -> int: return int(b.get_meta("card_index",-1)) if is_instance_valid(b) else -1),"ghost_rect":ghost,"pin_choices":manager.entry().get("pin_choices",{}).duplicate(),"visible":is_instance_valid(surface),"page":page,"document":document,"statement":statement,"buttons":buttons,"labels":labels,"art":art_path,"art_rect":art_rect,"drop_zone":drop,"dragging":drag_moved and drag_card >= 0,"marked_field":marked_field,"preview_slot":rail.preview if is_instance_valid(rail) and not rail.record_mode else -1}
