extends RefCounted
## Case-file typography and red evidence stamps, specific to this story.
const INK := Color("16181d")
const RED := Color("c4271c")
const Art = preload("res://scripts/ui/art_theme.gd")
var hud: CanvasLayer
var case: RefCounted
var compact := false
var tablet := false
var _choice_row: HBoxContainer
const Inspector = preload("res://scripts/ui/evidence_inspector.gd")
var _paper_echo: TextureRect

class DossierBinding extends Control:
	func _draw() -> void:
		# Decoration lies entirely in the reserved left margin.
		draw_line(Vector2(-28,0),Vector2(-28,size.y),Color("9a7443"),1,true)
		for y: float in [size.y*0.22,size.y*0.76]:
			draw_circle(Vector2(-28,y),5,Color("8a7455"))
			draw_circle(Vector2(-28,y),3,Color("16181d"))
		# A closed tie at the first binding hole reads as string, not a clipped slash.
		draw_arc(Vector2(-28,size.y*0.22),9,0,TAU,24,Color("c4271c"),2,true)

func inspect(receipt: bool) -> void:
	var old: Node = hud._root.get_node_or_null("EvidenceInspector")
	if old: old.queue_free()
	var view := Inspector.new()
	view.receipt = receipt
	view.tree_exited.connect(hud._focus_first_button)
	hud._root.add_child(view)

func photos() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	hud._modal_box.add_child(row)
	for i: int in 2:
		var photo: Button = hud._button("甲・客服訊息" if i == 0 else "乙・轉帳收據",inspect.bind(i == 1),row)
		photo.name = "InspectMessage" if i == 0 else "InspectReceipt"
		photo.icon = Art.texture("icon-phone" if i == 0 else "icon-receipt")
		photo.focus_mode = Control.FOCUS_CLICK
		photo.set_meta("evidence_photo",true)
		photo.expand_icon = true
		photo.add_theme_constant_override("icon_max_width",56)
		photo.add_theme_font_size_override("font_size",13 if compact else 16)
		photo.custom_minimum_size.y = 44 if compact else 76
		Art.skin_button(photo)
		photo.tooltip_text = "點擊放大核對證物"

func setup(owner_hud: CanvasLayer, data: RefCounted) -> void:
	hud = owner_hud
	case = data

func line(text: String, accent: bool = false) -> void:
	var label: Label = hud._label(text,13 if compact else 22 if tablet else 17,INK)
	if accent:
		label.add_theme_color_override("font_color", RED if text.begins_with("已封存") or text.begins_with("七期留證簿") else Color("65502c"))
	if text.begins_with("✓"):
		label.add_theme_color_override("font_color",RED if case.stage == 4 else Color("6f6b62"))
	if text.begins_with("核對說詞"):
		var selected_style := StyleBoxFlat.new()
		selected_style.bg_color = Art.AMBER
		selected_style.set_content_margin_all(0)
		label.add_theme_stylebox_override("normal",selected_style)
	hud._modal_box.add_child(label)

func contradiction() -> void:
	var strip := PanelContainer.new()
	strip.name = "EvidenceContradiction"
	strip.add_theme_stylebox_override("panel",hud._style(Art.CHARCOAL,Art.KRAFT,1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	strip.add_child(row)
	for i: int in 3:
		if i == 1:
			var chain := Art.image("icon-chain",36)
			chain.custom_minimum_size.x = 36
			chain.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			row.add_child(chain)
		else:
			var label: Label = hud._label("選取證據\n公司專戶" if i == 0 else "矛盾結論\n個人戶名",13 if compact else 16,Art.AMBER if i == 0 else Art.RED)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(label)
	hud._modal_box.add_child(strip)
	strip.modulate.a = 0.45
	strip.create_tween().tween_property(strip,"modulate:a",1.0,0.24)

func button(text: String, action: Callable) -> Button:
	var b: Button = hud._button(text,action,_choice_row)
	if tablet:
		b.custom_minimum_size.y = 60
		b.add_theme_font_size_override("font_size",20)
	if compact:
		b.custom_minimum_size.y = 64 if _choice_row else 44
		b.add_theme_font_size_override("font_size",14)
	b.add_theme_color_override("font_color",INK)
	b.add_theme_color_override("font_hover_color",INK)
	b.add_theme_color_override("font_pressed_color",INK)
	b.add_theme_color_override("font_focus_color",INK)
	b.add_theme_stylebox_override("normal",Art.paper())
	for state: String in ["hover","pressed","focus"]:
		b.add_theme_stylebox_override(state,hud._style(Color("dfd4bd"),INK,2))
	return b

func choices_row() -> void:
	if hud.get_viewport().get_visible_rect().size.y >= 500: return
	_choice_row = HBoxContainer.new()
	_choice_row.add_theme_constant_override("separation",6)
	hud._modal_box.add_child(_choice_row)

func proof_list() -> void:
	# Document cells are labels; only the separate compare tab is a button.
	var very_short := hud.get_viewport().get_visible_rect().size.y < 350
	var list: BoxContainer = HBoxContainer.new() if very_short else VBoxContainer.new()
	list.name = "EvidenceFactList"
	list.add_theme_constant_override("separation",4)
	hud._modal_box.add_child(list)
	for i: int in case.PROOFS.size():
		var row: BoxContainer = VBoxContainer.new() if very_short else HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation",8)
		list.add_child(row)
		var parts: PackedStringArray = case.PROOFS[i].split("：",true,1)
		var caption: Label = hud._label(parts[0],13 if compact else 16,Color("65502c"))
		caption.custom_minimum_size.x = 0 if very_short else 54 if compact else 68
		row.add_child(caption)
		var value: Label = hud._label(parts[1],13 if compact else 18,RED if i == 0 else INK)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(value)
		var action: Button = hud._button(case.PROOFS[i],choose_proof.bind(i),row)
		action.name = "CompareProof%d" % i
		action.clip_text = true
		action.autowrap_mode = TextServer.AUTOWRAP_OFF
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		action.size_flags_horizontal = Control.SIZE_SHRINK_END
		action.custom_minimum_size = Vector2(48,44)
		Art.skin_button(action)
		for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
			action.add_theme_color_override(state,Color.TRANSPARENT)
		var tag: Label = hud._label("比對",13,Art.PAPER)
		tag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		action.add_child(tag)
		if i < case.PROOFS.size()-1: list.add_child(VSeparator.new() if very_short else HSeparator.new())

func show_page() -> void:
	if is_instance_valid(_paper_echo): _paper_echo.queue_free()
	hud._modal_box.rotation = 0.0
	hud._open("case","","")
	var screen: Vector2 = hud.get_viewport().get_visible_rect().size
	compact = screen.y < 500 or screen.x < 360
	tablet = hud.device_profile == "tablet" and screen.x >= 700 and screen.y >= 900
	_choice_row = null
	var resume: Button = hud._return_footer.get_child(1)
	resume.disabled = case.stage == 2 and case.selected_claim < 0
	resume.visible = case.stage != 4
	hud._return_footer.get_child(0).visible = case.stage != 4
	var gate: Label = hud._modal_content.get_node_or_null("CaseGateReason")
	if not gate:
		gate = hud._label("",13,INK)
		gate.name = "CaseGateReason"
		hud._modal_content.add_child(gate)
		hud._modal_content.move_child(gate,hud._return_footer.get_index())
	gate.visible = case.stage == 2 and case.selected_claim < 0
	gate.text = "尚缺：選說詞，再比對收據戶名。" if case.selected_claim < 0 else "已選說詞；請比對收據欄位。"
	hud._modal_box.add_theme_constant_override("separation",3 if compact else 10)
	hud._modal_panel.add_theme_stylebox_override("panel",Art.paper(true))
	var binding: Control = hud._modal_panel.get_node_or_null("DossierBinding")
	if not binding:
		binding = DossierBinding.new()
		binding.name = "DossierBinding"
		binding.mouse_filter = Control.MOUSE_FILTER_IGNORE
		binding.resized.connect(binding.queue_redraw)
		hud._modal_panel.add_child(binding)
	binding.show()
	line("七期留證簿｜案卷 01・出金保證金",true)
	if case.stage in [2,3]: photos()
	match case.stage:
		0:
			line("證物甲｜恆曜客服對話・上週五")
			line("「受款帳戶是恆曜公司專戶。先補繳四萬八千元解凍保證金，才能出金。」")
			line("阿遠：我已轉了三十八萬。先留下這則訊息，再去車店找美晴核對。")
			button("保存這則訊息",func() -> void: case.preserve_message(); show_page())
		1:
			line("甲已留存 → 乙待核對 → 連結矛盾 → 封存",true)
			line("美晴站在車店工作台旁。找到紅圍裙、拿扳手的人，靠近交談。")
			line("左下拖移走路；右側拖曳看向。美晴會陪你核對手機裡的轉帳收據。")
			button("收起案卷，去找美晴",hud._resume)
		2:
			if not compact:
				line("甲｜客服聲稱「公司專戶」")
				line("乙｜戶名記載「林○翔（個人）」")
			if case.selected_claim < 0:
				line("先選一句要核對的說詞",true)
				choices_row()
				for i: int in case.CLAIMS.size(): button(case.CLAIMS[i],choose_claim.bind(i))
			else:
				line("核對說詞：「%s」" % case.CLAIMS[case.selected_claim])
				if screen.y >= 750: contradiction()
				proof_list()
		3:
			if screen.y >= 600: contradiction()
			else: line("甲「公司專戶」←→ 乙「個人戶名」",true)
			line("✓ 戶名已核對・連結完成。選擇證物支持的判斷。")
			choices_row()
			for i: int in case.REASONS.size(): button(case.REASONS[i],choose_reason.bind(i))
		4:
			if screen.y >= 600:
				var seal := Art.image("archive-seal",144 if screen.y >= 750 else 120)
				hud._modal_box.add_child(seal)
				seal.name = "ArchiveSeal"
				seal.modulate.a = 0.0
				seal.self_modulate.a = 0.0
				seal.scale = Vector2.ONE * 1.5
				var tween := seal.create_tween().set_parallel(true)
				tween.tween_property(seal,"modulate:a",1.0,0.12)
				tween.tween_property(seal,"scale",Vector2.ONE,0.30).from(Vector2.ONE * 1.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tween.tween_property(seal,"self_modulate:a",1.0,0.01).set_delay(0.27)
				# The applicator is an absolute overlay inside a fixed impression slot.
				# It never changes container minima or paints a second paper over text.
				var applicator := TextureRect.new()
				applicator.name = "StampApplicator"
				# Moving impression and settled impression use the exact same asset.
				applicator.texture = seal.texture
				applicator.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				applicator.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				applicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
				applicator.size = Vector2(110,110)
				seal.add_child(applicator)
				# Evaluate the settled slot size each frame. Absolute positions set
				# before container layout used to send the stamp through the title.
				var place_stamp := func(offset: Vector2) -> void:
					applicator.size = Vector2.ONE*seal.size.y
					applicator.position = (seal.size-applicator.size)*0.5+offset
				place_stamp.call(Vector2(18,-8))
				var press := applicator.create_tween()
				press.tween_method(place_stamp,Vector2(18,-8),Vector2.ZERO,0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				press.tween_interval(0.09)
				press.tween_method(place_stamp,Vector2.ZERO,Vector2.ZERO,0.28)
				press.parallel().tween_property(applicator,"modulate:a",0.0,0.28)
				press.tween_callback(applicator.queue_free)
			if screen.y >= 750: line("✓ 公司專戶 ←→ 個人戶名",true)
			line(case.CONCLUSION)
			line("✓ 核對完成 4／4・證物甲乙可隨時重讀。",true)
			var next := button("回到街區，繼續斷鏈",hud._resume)
			# Preserve the established action while rendering it as secondary in
			# every state, including keyboard focus after a completed case.
			for state: String in ["normal","hover","pressed","focus"]:
				next.add_theme_stylebox_override(state,Art.button_style(false,false))
			for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
				next.add_theme_color_override(state,Art.PAPER)
	if not case.feedback.is_empty():
		if case.stage == 4: hud._modal_box.add_child(hud._label(case.feedback,13,Color("65502c")))
		else: hud._modal_box.add_child(hud._label(case.feedback,13,Color("65502c")))
	if not compact and case.stage != 4:
		var progress := PanelContainer.new()
		progress.name = "CaseEvidenceProgress"
		progress.add_theme_stylebox_override("panel",hud._style(Art.CHARCOAL,Art.KRAFT,1))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",8)
		progress.add_child(row)
		var icon := Art.image("icon-receipt",36)
		icon.custom_minimum_size.x = 36
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var progress_label: Label = hud._label("甲乙留證 2／2\n點按證物放大核對" if case.stage in [2,3] else "核對完成 4／4\n說詞・戶名・矛盾・封存" if case.stage == 4 else "留證 1／4・前往車店",14,Art.PAPER)
		progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(progress_label)
		hud._modal_box.add_child(progress)
		line("紙緣翻閱 ↓" if screen.y < 750 else "留證 → 核對 → 連結 → 封存",true)
	if not compact: hud._modal_box.add_child(hud._label("全部證物均為虛構；未連接銀行或通訊軟體。",13,Color("65502c")))
	hud._focus_first_button()
	hud._resize_modal.call_deferred()

func choose_claim(index: int) -> void:
	case.select_claim(index)
	show_page()

func choose_proof(index: int) -> void:
	case.link_proof(index)
	show_page()

func choose_reason(index: int) -> void:
	if case.conclude(index): hud.show_toast("✓ 完成第一份反詐案卷")
	show_page()
