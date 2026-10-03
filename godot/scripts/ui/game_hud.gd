class_name GameHUD
extends CanvasLayer
## Container-driven Traditional Chinese HUD and modals. Root owns gameplay actions.

signal resume_requested
signal save_requested
signal load_requested
signal retry_requested
signal new_game_requested
signal quit_requested
signal branch_selected(branch: String)
signal optional_selected(id: String)
signal optional_cancelled

const DARK := Color("14242e")
const INK := Color("f1f3e9")
const ACCENT := Color("f0c368")
const MUTED := Color("acbfc6")

var _manager: Node
var _root: Control
var _hud: Control
var _overlay: Control
var _modal_box: VBoxContainer
var _modal_scroll: ScrollContainer
var _mission_label: Label
var _objective_label: Label
var _status_label: Label
var _scores_label: Label
var _prompt_label: Label
var _notice_label: Label
var _map: Control
var _map_player := Vector2.ZERO
var _map_target := Vector2.ZERO
var _has_map_target := false
var _mode: String = ""
var _cached_notice: String = ""
var _optional: Node
var _optional_label: Label
var _map_panel: Control
var _modal_panel: Control
var _controls_hint: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	_build_ui()
	_refresh_mission()


func bind_missions(manager: Node) -> void:
	if is_instance_valid(_manager) and _manager.updated.is_connected(_refresh_mission):
		_manager.updated.disconnect(_refresh_mission)
	_manager = manager
	if is_instance_valid(_manager):
		_manager.updated.connect(_refresh_mission)
	_refresh_mission()

func bind_optional(manager: Node) -> void:
	_optional = manager
	_optional.updated.connect(_refresh_optional)
	_refresh_optional()

func _refresh_optional() -> void:
	if not _optional or not _optional_label: return
	_optional_label.text = "街坊：" + _optional.get_active_text() if _optional.status == "active" or _optional.status == "failed" else "Tab 任務手機｜6份街坊委託、4種活動與街景相簿"
	if _scores_label: _scores_label.text = _score_text()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var theme := Theme.new()
	var font_path := "res://assets/fonts/SevenDistrictSansTC-Regular.otf"
	if not ResourceLoader.exists(font_path):
		font_path = "res://assets/fonts/NotoSansTC-Regular.ttf"
	if ResourceLoader.exists(font_path):
		theme.default_font = load(font_path)
	else:
		var system_font := SystemFont.new()
		system_font.font_names = PackedStringArray(["Microsoft JhengHei", "Noto Sans CJK TC", "sans-serif"])
		theme.default_font = system_font
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", ACCENT)
	theme.set_color("font_focus_color", "Button", ACCENT)
	theme.set_stylebox("normal", "Button", _style(Color("223b46"), Color("44606b"), 8))
	theme.set_stylebox("hover", "Button", _style(Color("304e59"), ACCENT, 8))
	theme.set_stylebox("pressed", "Button", _style(Color("3c5960"), ACCENT, 8))
	theme.set_stylebox("focus", "Button", _style(Color.TRANSPARENT, ACCENT, 8))
	_root.theme = theme
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hud)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	var mission_panel := _panel()
	mission_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(mission_panel)
	var mission_column := _padded_column(mission_panel, 12)
	_mission_label = _label("", 21, ACCENT)
	mission_column.add_child(_mission_label)
	_objective_label = _label("", 18)
	mission_column.add_child(_objective_label)
	_scores_label = _label("", 16, MUTED)
	mission_column.add_child(_scores_label)
	_optional_label = _label("", 15, Color(0.47, 0.90, 0.81))
	mission_column.add_child(_optional_label)
	var map_panel := _panel()
	_map_panel = map_panel
	map_panel.custom_minimum_size = Vector2(150, 136)
	top.add_child(map_panel)
	var map_column := _padded_column(map_panel, 8)
	map_column.add_child(_label("街區導航　↑ 北", 14, MUTED))
	_map = Control.new()
	_map.custom_minimum_size = Vector2(132, 94)
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.draw.connect(_draw_map)
	map_column.add_child(_map)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	_notice_label = _label("", 16, ACCENT)
	column.add_child(_notice_label)
	var prompt_panel := _panel()
	column.add_child(prompt_panel)
	var prompt_column := _padded_column(prompt_panel, 10)
	_prompt_label = _label("靠近標示物件，按 E 互動。", 19)
	prompt_column.add_child(_prompt_label)
	_status_label = _label("", 16, MUTED)
	prompt_column.add_child(_status_label)
	_controls_hint = _label("WASD 移動　左鍵攻擊　E 互動　F 上下車　Q 換工具　Tab 任務　Esc 暫停", 15, MUTED)
	if OS.has_feature("web"):
		_controls_hint.text = "WASD 移動　右鍵拖曳視角　左鍵攻擊　E 互動　F 上下車　Tab 任務"
	prompt_column.add_child(_controls_hint)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.045, 0.065, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		outer.add_theme_constant_override("margin_" + side, 24)
	_overlay.add_child(outer)
	var center := CenterContainer.new()
	outer.add_child(center)
	var modal_panel := _panel()
	_modal_panel = modal_panel
	modal_panel.custom_minimum_size = Vector2(700, 0)
	center.add_child(modal_panel)
	var modal_margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		modal_margin.add_theme_constant_override("margin_" + side, 20)
	modal_panel.add_child(modal_margin)
	_modal_scroll = ScrollContainer.new()
	_modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_modal_scroll.custom_minimum_size = Vector2(660, 400)
	modal_margin.add_child(_modal_scroll)
	_modal_box = VBoxContainer.new()
	_modal_box.add_theme_constant_override("separation", 12)
	_modal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_scroll.add_child(_modal_box)
	_overlay.hide()
	get_viewport().size_changed.connect(_resize_modal)
	_resize_modal()


func _resize_modal() -> void:
	if _modal_scroll == null:
		return
	var screen := get_viewport().get_visible_rect().size
	_modal_scroll.custom_minimum_size.y = clampf(screen.y - 150.0, 70.0, 460.0)
	_modal_scroll.custom_minimum_size.x = clampf(screen.x - 132.0, 180.0, 660.0)
	_modal_panel.custom_minimum_size.x = clampf(screen.x - 64.0, 230.0, 700.0)
	var compact: bool = screen.x < 750 or screen.y < 480
	_map_panel.visible = not compact
	_controls_hint.visible = not compact
	_scores_label.visible = not compact
	_mission_label.add_theme_font_size_override("font_size", 16 if compact else 21)
	_objective_label.add_theme_font_size_override("font_size", 14 if compact else 18)
	_optional_label.add_theme_font_size_override("font_size", 13 if compact else 15)


func _style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.07, 0.13, 0.17, 0.94), Color("36505b"), 9))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _padded_column(parent: Control, padding: int) -> VBoxContainer:
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, padding)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	return column


func _label(text: String, font_size: int = 18, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, callback: Callable, parent: Node = null) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	(parent if parent != null else _modal_box).add_child(button)
	return button


func _open(mode: String, heading: String, subtitle: String) -> void:
	if _overlay == null:
		return
	_mode = mode
	for child: Node in _modal_box.get_children():
		_modal_box.remove_child(child)
		child.queue_free()
	_modal_box.add_child(_label(heading, 30, ACCENT))
	_modal_box.add_child(_label(subtitle, 18))
	_overlay.show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_modal_scroll.scroll_vertical = 0


func hide_menus() -> void:
	_mode = ""
	if _overlay != null:
		_overlay.hide()
	get_tree().paused = false


func _resume() -> void:
	hide_menus()
	resume_requested.emit()


func is_menu_open() -> bool:
	return _overlay != null and _overlay.visible


func get_menu_mode() -> String:
	return _mode


func show_title() -> void:
	_open("title", "七期：斷鏈行動", "Alpha 0.2　｜　五個主線、六份委託、四種街頭活動。")
	_modal_box.add_child(_label("阿遠失去了存款。從美晴車店借一把扳手，沿著留下的地址，去找玻璃後面的人。", 19))
	_modal_box.add_child(_label("所有人物、公司與地點均為虛構。這個版本只提供第一章切片，沒有完整戰役結局。", 16, MUTED))
	_button("開始新遊戲", func() -> void: hide_menus(); new_game_requested.emit())
	_button("讀取存檔", func() -> void: load_requested.emit())
	_button("離開遊戲", func() -> void: quit_requested.emit())
	_focus_first_button()


func show_pause() -> void:
	_open("pause", "暫停", "任務停在這裡。存檔會保留任務步驟、物品、救援與街區狀態。")
	var rows := HBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	_modal_box.add_child(rows)
	_button("繼續遊戲", _resume, rows)
	_button("任務手機", show_phone, rows)
	_button("街坊委託與活動", show_optional_phone)
	_button("儲存進度", func() -> void: save_requested.emit())
	_button("讀取存檔", func() -> void: load_requested.emit())
	_button("重試目前任務", func() -> void: hide_menus(); retry_requested.emit())
	_button("回到開頭重新開始", func() -> void: hide_menus(); new_game_requested.emit())
	_button("離開遊戲", func() -> void: quit_requested.emit())
	_focus_first_button()


func show_phone() -> void:
	var title := str(_manager.get_current_title()) if is_instance_valid(_manager) else "任務手機"
	var objective := str(_manager.get_objective_text()) if is_instance_valid(_manager) else "先開始新遊戲。"
	_open("phone", title, objective)
	if is_instance_valid(_manager):
		var mission: Dictionary = _manager.get_current_mission()
		_modal_box.add_child(_label(str(mission.get("dialogue", "")), 18, MUTED))
		var optional: Dictionary = mission.get("optional", {})
		if not optional.is_empty():
			_modal_box.add_child(_label(str(optional.get("text", "")), 16, MUTED))
		if int(_manager.mission_index) == 4 and not bool(_manager.chapter_complete):
			_modal_box.add_child(_label("本次行動的解法", 21, ACCENT))
			for choice: String in ["smash", "evidence", "rescue"]:
				var captions := {"smash":"破壞：砸毀三個營運設備", "evidence":"蒐證：保存兩份紀錄，再停用裝置", "rescue":"救援：多帶兩人到安全點，再停用裝置"}
				_button(captions[choice], _select_branch.bind(choice))
		_modal_box.add_child(_label(_score_text(), 17, MUTED))
		if not str(_manager.notice).is_empty():
			_modal_box.add_child(_label(str(_manager.notice), 16, ACCENT))
	_button("街坊委託／活動／相簿", show_optional_phone)
	_button("收起手機，繼續行動", _resume)
	_focus_first_button()

func show_optional_phone(category: String = "side", page: int = 0) -> void:
	if not _optional:
		show_phone()
		return
	_open("optional", "街坊委託與街頭活動", _optional.get_active_text())
	var categories := HBoxContainer.new()
	categories.add_theme_constant_override("separation", 8)
	_modal_box.add_child(categories)
	_button("6份街坊委託", func() -> void: show_optional_phone("side", 0), categories)
	_button("4種活動／相簿", func() -> void: show_optional_phone("activity", 0), categories)
	var entries: Array = []
	for entry: Dictionary in _optional.get_menu_entries():
		if entry["type"] == category: entries.append(entry)
	var pages: int = maxi(1, ceili(float(entries.size()) / 2.0))
	page = clampi(page, 0, pages - 1)
	for index: int in range(page * 2, mini(page * 2 + 2, entries.size())):
		var item: Dictionary = entries[index]
		var title: String = String(item["title"]) + ("｜已完成" if item["completed"] else "")
		_button(title, _choose_optional.bind(String(item["id"])))
		_modal_box.add_child(_label(String(item["summary"]), 14, MUTED))
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 8)
	_modal_box.add_child(navigation)
	_button("←前頁", func() -> void: show_optional_phone(category, page - 1), navigation)
	_button("下一頁→", func() -> void: show_optional_phone(category, page + 1), navigation)
	if _optional.status == "active":
		_button("先放下目前委託", func() -> void: optional_cancelled.emit())
	_modal_box.add_child(_label("委託零件券 %d｜相簿 %d／8｜成就 %d" % [_optional.wallet, _optional.collected_points.size(), _optional.achievements.size()], 14, MUTED))
	_button("主線手機", show_phone)
	_button("收起手機，繼續行動", _resume)
	_focus_first_button()

func _choose_optional(id: String) -> void:
	optional_selected.emit(id)


func _select_branch(choice: String) -> void:
	branch_selected.emit(choice)
	# Root applies the choice synchronously. Accepted choices return to the street.
	if is_instance_valid(_manager) and str(_manager.branch) == choice:
		if is_menu_open():
			_resume()
	else:
		show_phone()


func show_chapter_complete(chosen_branch: String) -> void:
	var names := {"smash":"破壞", "evidence":"蒐證", "rescue":"救援"}
	var outcomes := {"smash":"前站的三個營運設備已失能。美晴等你回來，把借出的扳手收進工具架。", "evidence":"兩份紀錄已保存，前站營運已中止。予安接下文件，還有人名需要逐一釐清。", "rescue":"額外兩名受困者已到安全點，前站營運已中止。周成確認大家都上車，才鬆開一直握著的手。"}
	_open("complete", "第一章切片完成", "本次選法：" + str(names.get(chosen_branch, "未選擇")))
	_modal_box.add_child(_label(str(outcomes.get(chosen_branch, "你已回到美晴車店。")), 19))
	_modal_box.add_child(_label(_score_text(), 20, ACCENT))
	_modal_box.add_child(_label("這是五個主線任務的切片成果。後續章節與完整戰役結局尚未製作。", 16, MUTED))
	_button("儲存這次成果", func() -> void: save_requested.emit())
	_button("重新開始，試另一種解法", func() -> void: hide_menus(); new_game_requested.emit())
	_button("返回街區看看", _resume)
	_button("離開遊戲", func() -> void: quit_requested.emit())
	_focus_first_button()


func show_message(message: String) -> void:
	_cached_notice = message
	if _notice_label != null:
		_notice_label.text = message
	if is_menu_open():
		_modal_box.add_child(_label(message, 16, ACCENT))


func _focus_first_button() -> void:
	for child: Node in _modal_box.get_children():
		if child is Button:
			child.grab_focus()
			return


func _score_text() -> String:
	if not is_instance_valid(_manager):
		return ""
	var state: Dictionary = _manager.scores
	var optional_wallet: int = int(_optional.wallet) if _optional else 0
	return "證據 %d／100　街坊信任 %d／100　救出 %d 人　零件券 %d" % [int(state.get("evidence_score", 0)), int(state.get("community_trust", 50)), int(state.get("rescued_count", 0)), int(_manager.parts_vouchers) + optional_wallet]


func _refresh_mission() -> void:
	if _mission_label == null or not is_instance_valid(_manager):
		return
	_mission_label.text = _manager.get_current_title()
	_objective_label.text = _manager.get_objective_text()
	_scores_label.text = _score_text()
	_notice_label.text = str(_manager.notice) if not str(_manager.notice).is_empty() else _cached_notice


func update_status(hp: float, weapon: String, heat: int, vehicle: String, prompt: String) -> void:
	if _status_label == null:
		return
	var weapon_names := {"wrench":"扳手", "bat":"球棒", "pulse":"脈衝器具", "none":"空手", "":"空手"}
	var vehicle_names := {"bicycle":"自行車", "car":"小客車", "":"步行"}
	_status_label.text = "安全值 %d／100　工具：%s　警戒 %d／5　%s" % [clampi(int(hp), 0, 100), str(weapon_names.get(weapon, weapon)), clampi(heat, 0, 5), str(vehicle_names.get(vehicle, vehicle))]
	_prompt_label.text = prompt if not prompt.is_empty() else "沿導航前往任務目標。靠近標示物件，按 E 互動。"


func set_map_markers(player_xz: Vector2, target_xz: Vector2) -> void:
	_map_player = player_xz
	_map_target = target_xz
	_has_map_target = target_xz.is_finite()
	if _map != null:
		_map.queue_redraw()


func _draw_map() -> void:
	var rect := Rect2(Vector2.ZERO, _map.size)
	_map.draw_rect(rect, Color("10232c"))
	var center := _map.size * 0.5
	for offset: float in [-48.0, -24.0, 0.0, 24.0, 48.0]:
		_map.draw_line(Vector2(center.x + offset, 0), Vector2(center.x + offset, _map.size.y), Color("29434c"), 1)
		_map.draw_line(Vector2(0, center.y + offset), Vector2(_map.size.x, center.y + offset), Color("29434c"), 1)
	_map.draw_circle(center, 5, INK)
	if _has_map_target:
		var relative := (_map_target - _map_player) * 0.8
		var marker := center + relative
		marker.x = clampf(marker.x, 7, _map.size.x - 7)
		marker.y = clampf(marker.y, 7, _map.size.y - 7)
		_map.draw_line(center, marker, ACCENT.darkened(0.3), 2)
		_map.draw_rect(Rect2(marker - Vector2(4, 4), Vector2(8, 8)), ACCENT)
