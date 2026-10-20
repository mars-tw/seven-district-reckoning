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
signal supplies_requested
signal purchase_requested(id: String)
signal setting_changed(key: String, value: String)
signal waypoint_selected(point: Vector2)
signal waypoint_cleared
signal life_requested
signal device_selected(profile_name: String)
## R1: title CTA asks root to play the cold-open story before MAIN-001.
signal story_start_requested
signal menu_opened
signal camera_requested(amount: float)

## R1 signature HUD element: five chain links, one per main mission. Each
## completed mission snaps a link, echoing the title 斷鏈行動.
class ChainLinks extends Control:
	var pending_art: Texture2D = preload("res://assets/art/r4/icon-folder.png")
	var sealed_art: Texture2D = preload("res://assets/art/r5/archive-seal.png")
	var stamp_font: Font = preload("res://assets/fonts/SevenDistrictSansTC-Regular.otf")
	var total: int = 5
	var broken: int = 0
	var flash: float = 0.0
	func _init() -> void:
		custom_minimum_size = Vector2(150, 32)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func set_broken(value: int) -> void:
		value = clampi(value, 0, total)
		if value > broken: flash = 1.0
		broken = value
		queue_redraw()
	func _process(delta: float) -> void:
		if flash > 0.0:
			flash = maxf(0.0, flash - delta * 1.5)
			queue_redraw()
	func _draw() -> void:
		var step: float = minf(size.x / float(total),22.0)
		for i: int in total:
			var center := Vector2(step * (i + 0.5), size.y * 0.5)
			var is_broken: bool = i < broken
			var color := Color("c4271c") if is_broken else Color("c6bdad")
			if is_broken and i == broken - 1 and flash > 0.0: color = color.lerp(Color.WHITE, flash)
			draw_circle(center,3.5,color,is_broken,1.5,true)

const MapScript = preload("res://scripts/ui/district_map.gd")
const LifePanelScript = preload("res://scripts/ui/taiwan_life_panel.gd")
const Art = preload("res://scripts/ui/art_theme.gd")

const DARK := Color("16181d")
const INK := Color("f1e8d5")
const ACCENT := Color("ffb800")
const MUTED := Color("c6bdad")

var _title_art: TextureRect
var _title_logo: TextureRect
var _title_logo_plate: PanelContainer
var _banner_portrait: TextureRect

var _manager: Node
var _root: Control
var _hud: Control
var _overlay: Control
var _modal_box: VBoxContainer
var _modal_scroll: ScrollContainer
var _modal_content: VBoxContainer
var _title_footer: HBoxContainer
var _title_start_button: Button
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
var _notice_until := 0
var _optional: Node
var _life: Node
var _activities: Node
var _optional_label: Label
var _map_panel: Control
var _modal_panel: Control
var _modal_outer: MarginContainer
var _modal_margin: MarginContainer
var _hud_margin: MarginContainer
var _prompt_panel: PanelContainer
var _controls_hint: Label
var _systems: Node
var _street: RefCounted
var _world_regions: Array[Dictionary] = []
var _world_blocks: Array[AABB] = []
var _world_points: Dictionary = {}
var _large_map: Control
var _stamina_bar: ProgressBar
var _stamina_caption: Label
var _survival_label: Label
var _last_survival: String = ""
var _near_shop: bool = false
var _settings_return_title: bool = false
var life_panel: RefCounted
var device_profile: String = "desktop"
var _world_radius: float = 150.0
var _navigation_roads: Array[Dictionary] = []
var _mission_panel: PanelContainer
var _health_bar: ProgressBar
var _chain: ChainLinks
var _distance_label: Label
var _banner: VBoxContainer
var _banner_kicker: Label
var _banner_title: Label
var _banner_line: Label
var _toast: Label
var _combo_label: Label
var _title_hid_hud: bool = false
var _dim: ColorRect
var _banner_tween: Tween
var _compact_landscape_touch: bool = false
var _toast_tween: Tween
var banner_text: String = ""
var dialogue_text: String = ""
var toast_text: String = ""
var _return_footer: HBoxContainer
var _revisits: Node
var _start_revisit: Callable
var _revisit_page := 0
var fraud_panel: RefCounted
var investigation_panel: CanvasLayer
var investigations: RefCounted

func show_investigations() -> void:
	if investigation_panel: investigation_panel.open_hub()
var modal_resize_count := 0
var modal_sort_count := 0
var modal_sort_peak := 0
var _modal_sort_frame := -1
var _modal_sorts_in_frame := 0
var _banner_card: PanelContainer

func _trace_modal_sort() -> void:
	modal_sort_count += 1
	if _mode != "case": return
	var frame := Engine.get_process_frames()
	if frame != _modal_sort_frame:
		_modal_sort_frame = frame
		_modal_sorts_in_frame = 0
	_modal_sorts_in_frame += 1
	modal_sort_peak = maxi(modal_sort_peak, _modal_sorts_in_frame)

func layout_diagnostics() -> Dictionary:
	var panel := _modal_panel.get_global_rect()
	return {"resize_calls":modal_resize_count,"container_sorts":modal_sort_count,"peak_sorts_per_frame":modal_sort_peak,
		"panel":[panel.position.x,panel.position.y,panel.size.x,panel.size.y],
		"case_gutter_reserved":_modal_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_ALWAYS}

func bind_fraud_case(data: RefCounted) -> void:
	fraud_panel = preload("res://scripts/ui/fraud_case_panel.gd").new()
	fraud_panel.setup(self,data)

func show_fraud_case() -> void:
	if fraud_panel: fraud_panel.show_page()


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
	if _activities and _activities.status=="active":
		_optional_label.text = "%s｜%s" % [_activities.get_active_title(),_activities.get_active_text()]
	elif _life and _life.status in ["active","choosing","returning","failed"]:
		_optional_label.text = "%s｜%s\n生活金 %d　攜帶 %d 件" % [_life.get_active_title(),_life.get_active_text(),_life.cash,_life.cargo.size()]
	elif _optional.status in ["active","failed"]:
		_optional_label.text = "街坊："+_optional.get_active_text()
	else:
		_optional_label.text = "%s｜街坊故事、配送與活動　生活金 %d" % ["配送按鈕" if device_profile in ["phone","tablet"] else "J 街坊生活",_life.cash if _life else 0]
	if _scores_label: _scores_label.text = _score_text()

func bind_systems(manager: Node, street: RefCounted) -> void:
	_systems = manager
	_street = street

func setup_district_map(regions: Array[Dictionary], blocks: Array[AABB], points: Dictionary) -> void:
	_world_regions = regions.duplicate(true)
	_world_blocks = blocks.duplicate()
	_world_points = points.duplicate(true)

func bind_life(manager: Node, callbacks: Dictionary) -> void:
	_life = manager
	_life.updated.connect(_refresh_optional)
	life_panel = LifePanelScript.new()
	life_panel.setup(self,manager,callbacks)
	life_panel.set_profile(device_profile)
	_refresh_optional()

func bind_activities(manager: Node) -> void:
	_activities = manager
	_activities.updated.connect(_refresh_optional)
	_refresh_optional()

func set_device_profile(settings: Dictionary) -> void:
	device_profile = str(settings.get("profile","desktop"))
	if life_panel: life_panel.set_profile(device_profile)
	_resize_modal()
	_refresh_optional()
	_refresh_mission()

func objective_text() -> String:
	if investigation_panel and is_instance_valid(investigation_panel.surface) and investigation_panel.page == "fieldnote" and investigation_panel.document < investigations.definition().get("documents",[]).size():
		return "正在訪談｜"+investigations.definition().documents[investigation_panel.document].place+"\n讀原話，保留這位街坊提供的文件。"
	if investigations and investigations.pending() >= 0:
		var source: Dictionary = investigations.definition().documents[investigations.pending()]
		return "查證 %d／%d｜" % [investigations.entry().collected.size()+1,investigations.definition().documents.size()]+source.place+"\n"+source.title+"・靠近後互動留證"
	if investigations and not investigations.active.is_empty() and not investigations.entry().complete and investigations.ready_to_solve():
		var next_step := "原件已齊，開查證簿核對。"
		if investigations.active == "second_help":
			var count := int(investigations.entry().citations.get("0",-1) == 2)+int(investigations.entry().citations.get("1",-1) == 2)
			next_step = "已標兩句，去決定處置。" if count == 2 else "已標 %d／2，去原件找收費句。" % count
		elif investigations.active == "before_night": next_step = "揭時 %d／3，去核對收據。" % investigations.entry().reveal_steps.count(3)
		else: next_step = "已釘 %d／3，去核對三人的原話。" % investigations.entry().pins.size()
		return investigations.definition().title+"\n"+next_step+"\n暫停 → 查證 → 街坊查證簿"
	if investigations and not investigations.street_result().is_empty():
		var result: Dictionary = investigations.street_result()
		if not investigations.street_at_source: return "返回來源｜"+result.place+"\n跟隨街區導引，查看處置與留存原件。"
		return result.heading+"｜"+result.place+"\n"+result.payment+"；留存 %d 份原件。" % result.count+"\n"+result.line
	if not is_instance_valid(_manager): return ""
	var text: String = _manager.get_objective_text()
	if device_profile in ["phone","tablet"]:
		text = text.replace("按 E 交談","點互動交談").replace("（Tab）","（點委託）")
	return text

func set_expanded_map(radius: float, roads: Array[Dictionary]) -> void:
	_world_radius = radius
	_navigation_roads = roads.duplicate(true)

func show_life_phone(category: String = "story", page: int = 0) -> void:
	if life_panel: life_panel.show_jobs(category,page)

func show_life_station(id: String) -> void:
	if life_panel: life_panel.show_station(id)

func update_world_vehicles(car_position: Vector2, bike_position: Vector2) -> void:
	_world_points["car"] = car_position
	_world_points["bicycle"] = bike_position

func update_survival(stamina_value: float, maximum: float, time_value: String, touch_enabled: bool) -> void:
	if not _systems: return
	var status: Dictionary = _systems.get_status()
	var caption: String = "體力 %d／%d　補給金 %d　等級 %d　%s" % [ceili(stamina_value),int(maximum),status["credits"],status["rank"],time_value]
	if caption != _last_survival:
		_last_survival = caption
		_survival_label.text = caption
	_stamina_bar.max_value = maximum
	_stamina_bar.value = stamina_value
	if _stamina_caption:
		_stamina_caption.text = "體力 %d／%d" % [ceili(stamina_value),int(maximum)]
		var screen := get_viewport().get_visible_rect().size
		_stamina_caption.visible = screen.y > screen.x
		_stamina_bar.visible = _stamina_caption.visible
	var compact: bool = get_viewport().get_visible_rect().size.x < 750 or get_viewport().get_visible_rect().size.y < 480
	_prompt_label.add_theme_font_size_override("font_size", 14 if compact and touch_enabled else 19)
	_prompt_label.max_lines_visible = 2 if compact and touch_enabled else -1
	_status_label.add_theme_font_size_override("font_size", 11 if compact and touch_enabled else 16)


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
	theme.set_stylebox("normal", "Button", Art.button_style())
	theme.set_stylebox("hover", "Button", Art.button_style(true))
	theme.set_stylebox("pressed", "Button", Art.button_style(true))
	theme.set_stylebox("focus", "Button", Art.button_style(true))
	theme.set_color("font_hover_color", "Button", DARK)
	theme.set_color("font_pressed_color", "Button", DARK)
	theme.set_color("font_focus_color", "Button", DARK)
	_root.theme = theme
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hud)
	var margin := MarginContainer.new()
	_hud_margin = margin
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
	_mission_panel = mission_panel
	# R1: a narrow card instead of a full-width banner keeps the street visible.
	mission_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mission_panel.custom_minimum_size.x = 430
	var mission_surface := StyleBoxTexture.new()
	mission_surface.texture = Art.texture("case-panel")
	mission_surface.texture_margin_left = 30
	mission_surface.texture_margin_right = 18
	mission_surface.texture_margin_top = 18
	mission_surface.texture_margin_bottom = 18
	mission_surface.set_content_margin_all(6)
	mission_panel.add_theme_stylebox_override("panel",mission_surface)
	top.add_child(mission_panel)
	var mission_column := _padded_column(mission_panel, 6)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 8)
	mission_column.add_child(header)
	_mission_label = _label("", 21, ACCENT)
	_mission_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_mission_label)
	_chain = ChainLinks.new()
	_chain.tooltip_text = "斷鏈進度"
	header.add_child(_chain)
	_objective_label = _label("", 18)
	mission_column.add_child(_objective_label)
	_distance_label = _label("", 14, ACCENT)
	mission_column.add_child(_distance_label)
	_scores_label = _label("", 16, MUTED)
	_scores_label.visible = false
	mission_column.add_child(_scores_label)
	_optional_label = _label("", 15, Color("e4c58f"))
	mission_column.add_child(_optional_label)
	_survival_label = _label("", 12, MUTED)
	mission_column.add_child(_survival_label)
	_stamina_bar = ProgressBar.new()
	_stamina_bar.custom_minimum_size.y = 6
	_stamina_bar.show_percentage = false
	_stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_bar.add_theme_stylebox_override("background",_style(Color("3e392e"),Color.TRANSPARENT,1))
	_stamina_bar.add_theme_stylebox_override("fill",_style(Color("c6bdad"),Color.TRANSPARENT,1))
	for style_name: String in ["background","fill"]:
		var bar_style: StyleBoxFlat = _stamina_bar.get_theme_stylebox(style_name) as StyleBoxFlat
		bar_style.content_margin_top = 0
		bar_style.content_margin_bottom = 0
	_health_bar = ProgressBar.new()
	_health_bar.name = "HealthBar"
	_health_bar.custom_minimum_size.y = 6
	_health_bar.show_percentage = false
	_health_bar.max_value = 100
	_health_bar.value = 100
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar.add_theme_stylebox_override("background",_style(Color("2a2024"),Color.TRANSPARENT,3))
	_health_bar.add_theme_stylebox_override("fill",_style(Color("e0705a"),Color.TRANSPARENT,3))
	for style_name: String in ["background","fill"]:
		var health_style: StyleBoxFlat = _health_bar.get_theme_stylebox(style_name) as StyleBoxFlat
		health_style.content_margin_top = 0
		health_style.content_margin_bottom = 0
	mission_column.add_child(_health_bar)
	_stamina_caption = _label("體力 100／100",12,INK)
	_hud.add_child(_stamina_caption)
	_stamina_caption.position = Vector2(16,16)
	_stamina_caption.size = Vector2(112,20)
	_hud.add_child(_stamina_bar)
	_stamina_bar.position = Vector2(16,40)
	_stamina_bar.size = Vector2(112,6)
	_stamina_caption.visible = false
	_health_bar.visible = false
	_stamina_bar.visible = true
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(top_spacer)
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
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.05, 0.9))
	_notice_label.add_theme_constant_override("outline_size", 6)
	column.add_child(_notice_label)
	var prompt_panel := _panel()
	_prompt_panel = prompt_panel
	prompt_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	prompt_panel.custom_minimum_size.x = 560
	prompt_panel.add_theme_stylebox_override("panel", _style(Color(0.086, 0.094, 0.114, 0.90), Art.KRAFT, 2))
	column.add_child(prompt_panel)
	var prompt_column := _padded_column(prompt_panel, 4)
	_prompt_label = _label("靠近標示物件，按 E 互動。", 19)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_column.add_child(_prompt_label)
	_status_label = _label("", 16, MUTED)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_column.add_child(_status_label)
	_controls_hint = _label("WASD 移動　左鍵攻擊　E 互動　F 上下車　Q 換工具　Tab 任務　Esc 暫停", 15, MUTED)
	if OS.has_feature("web"):
		_controls_hint.text = "WASD 移動　右鍵拖曳視角　左鍵攻擊　E 互動　F 上下車　Tab 任務"
	_controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_column.add_child(_controls_hint)
	_build_feedback_layer()
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_overlay)
	_title_art = Art.image("title-street", 0)
	_title_art.name = "TitleIllustration"
	_title_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_title_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(_title_art)
	var dim := ColorRect.new()
	_dim = dim
	dim.color = Color(0.025, 0.045, 0.065, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var outer := MarginContainer.new()
	_modal_outer = outer
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
	_modal_margin = modal_margin
	for side: String in ["left", "right", "top", "bottom"]:
		modal_margin.add_theme_constant_override("margin_" + side, 20)
	modal_panel.add_child(modal_margin)
	_modal_content = VBoxContainer.new()
	_modal_content.add_theme_constant_override("separation", 8)
	_modal_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_margin.add_child(_modal_content)
	_modal_scroll = ScrollContainer.new()
	_modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_modal_scroll.follow_focus = true
	_modal_scroll.custom_minimum_size = Vector2(660, 400)
	_modal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_content.add_child(_modal_scroll)
	_modal_box = VBoxContainer.new()
	_modal_box.add_theme_constant_override("separation", 12)
	_modal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_scroll.add_child(_modal_box)
	_modal_box.sort_children.connect(_trace_modal_sort)
	_title_footer = HBoxContainer.new()
	_title_footer.visible = false
	_title_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_content.add_child(_title_footer)
	_title_start_button = _button("開始行動",_on_title_start,_title_footer)
	_title_start_button.name = "TitleStart"
	_title_start_button.custom_minimum_size.y = 60
	_title_start_button.add_theme_font_size_override("font_size", 22)
	_title_start_button.add_theme_color_override("font_color", Color("1b1408"))
	_title_start_button.add_theme_color_override("font_hover_color", Color("1b1408"))
	_title_start_button.add_theme_color_override("font_focus_color", Color("1b1408"))
	_title_start_button.add_theme_color_override("font_pressed_color", Color("1b1408"))
	_title_start_button.add_theme_stylebox_override("normal", _style(ACCENT, Color("ffe2a3"), 12))
	_title_start_button.add_theme_stylebox_override("hover", _style(Color("ffd585"), Color.WHITE, 12))
	_title_start_button.add_theme_stylebox_override("pressed", _style(Color("d9a84c"), Color.WHITE, 12))
	_title_start_button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, Color.WHITE, 12))
	Art.skin_button(_title_start_button, true)
	_return_footer = HBoxContainer.new()
	_return_footer.add_theme_constant_override("separation",8)
	_modal_content.add_child(_return_footer)
	_button("返回",_menu_back,_return_footer).name = "AlwaysBack"
	_button("繼續行動",_resume,_return_footer).name = "AlwaysResume"
	_overlay.hide()
	get_viewport().size_changed.connect(_resize_modal)
	_resize_modal()


func _card_style() -> StyleBoxFlat:
	var style := _style(Color(0.086, 0.094, 0.114, 0.92), Art.KRAFT, 2)
	style.border_width_left = 4
	style.border_color = ACCENT
	return style


func _build_feedback_layer() -> void:
	# A solid caption card sits above the lower controls, clear of world labels.
	_banner_card = _panel()
	_banner_card.name = "MissionCaption"
	_banner_card.add_theme_stylebox_override("panel",_style(Art.CHARCOAL,Art.KRAFT,2))
	_hud.add_child(_banner_card)
	_banner = VBoxContainer.new()
	_banner.name = "MissionBanner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.add_theme_constant_override("separation", 4)
	_banner_card.modulate.a = 0.0
	_banner_card.add_child(_banner)
	_banner_kicker = _label("", 16, ACCENT)
	_banner_title = _label("", 40, INK)
	_banner_line = _label("", 19, Color("d8e4e6"))
	for label: Label in [_banner_kicker, _banner_title]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.05, 0.92))
		label.add_theme_constant_override("outline_size", 0)
		_banner.add_child(label)
	var dialogue := HBoxContainer.new()
	dialogue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue.add_theme_constant_override("separation", 12)
	_banner.add_child(dialogue)
	_banner_portrait = Art.image("meiqing-portrait", 52)
	_banner_portrait.custom_minimum_size.x = 52
	_banner_portrait.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	dialogue.add_child(_banner_portrait)
	_banner_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_banner_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_line.add_theme_color_override("font_outline_color", DARK)
	_banner_line.add_theme_constant_override("outline_size", 0)
	dialogue.add_child(_banner_line)
	_toast = _label("", 24, Color("9fe0b0"))
	_toast.name = "ObjectiveToast"
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.03, 0.92))
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.anchor_left = 0.0
	_toast.anchor_right = 1.0
	_toast.anchor_top = 0.40
	_toast.anchor_bottom = 0.40
	_toast.modulate.a = 0.0
	_hud.add_child(_toast)
	_combo_label = _label("", 30, Color("ffb35c"))
	_combo_label.name = "ComboCounter"
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_label.add_theme_color_override("font_outline_color", Color(0.1, 0.04, 0.0, 0.92))
	_combo_label.add_theme_constant_override("outline_size", 8)
	_combo_label.anchor_left = 0.55
	_combo_label.anchor_right = 1.0
	_combo_label.anchor_top = 0.48
	_combo_label.anchor_bottom = 0.48
	_combo_label.offset_right = -28
	_combo_label.modulate.a = 0.0
	_hud.add_child(_combo_label)


## R1: mission-start banner with the mission's own speaker line.
func show_banner(kicker: String, title: String, line: String = "", seconds: float = 2.8) -> void:
	if _banner == null: return
	banner_text = title
	dialogue_text = line
	_banner_kicker.text = kicker
	_banner_title.text = title
	_banner_line.text = line
	_banner_line.visible = not line.is_empty()
	_banner_portrait.visible = not line.is_empty() and line.begins_with("美晴") and get_viewport().get_visible_rect().size.y >= 500
	var compact: bool = get_viewport().get_visible_rect().size.x < 750
	_banner_title.add_theme_font_size_override("font_size", 18 if compact else 24)
	_banner_kicker.add_theme_font_size_override("font_size", 13 if compact else 16)
	_banner_line.add_theme_font_size_override("font_size", 14 if compact else 18)
	_fit_banner()
	if _banner_tween and _banner_tween.is_valid(): _banner_tween.kill()
	var tween := _banner_card.create_tween()
	_banner_tween = tween
	_banner.scale = Vector2.ONE
	_banner_card.modulate.a = 0.0
	tween.tween_property(_banner_card, "modulate:a", 1.0, 0.2)
	tween.tween_interval(maxf(0.5, seconds))
	tween.tween_property(_banner_card, "modulate:a", 0.0, 0.3)


## R1: objective-complete pop.
func show_toast(text: String, color: Color = Color("9fe0b0")) -> void:
	if _toast == null: return
	toast_text = text
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.pivot_offset = _toast.size * 0.5
	_toast.scale = Vector2.ONE * 0.7
	_toast.modulate.a = 1.0
	if _toast_tween and _toast_tween.is_valid(): _toast_tween.kill()
	var tween := _toast.create_tween()
	_toast_tween = tween
	tween.tween_property(_toast, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.4)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func set_combo(count: int) -> void:
	if _combo_label == null: return
	if count < 2:
		if _combo_label.modulate.a > 0.0: _combo_label.create_tween().tween_property(_combo_label, "modulate:a", 0.0, 0.3)
		return
	_combo_label.text = "連擊 ×%d" % count
	_combo_label.modulate.a = 1.0
	_combo_label.pivot_offset = Vector2(_combo_label.size.x, _combo_label.size.y * 0.5)
	_combo_label.scale = Vector2.ONE * 1.35
	_combo_label.create_tween().tween_property(_combo_label, "scale", Vector2.ONE, 0.16).set_ease(Tween.EASE_OUT)


func set_chain_progress(broken: int) -> void:
	if _chain: _chain.set_broken(broken)


func get_chain_progress() -> int:
	return _chain.broken if _chain else 0


func set_target_distance(meters: float) -> void:
	if _distance_label == null: return
	var text: String = "" if not is_finite(meters) or meters < 0.0 else ("▶ 目標就在附近" if meters < 4.0 else "▶ 目標 %d 公尺" % int(round(meters)))
	if _distance_label.text != text: _distance_label.text = text
	# Short landscape phones rely on the 3D beacon; the card stays clear of 連跑.
	_distance_label.visible = not text.is_empty() and not _compact_landscape_touch
	if device_profile in ["phone","tablet"]:
		var at_result: bool = investigations and investigations.street_at_source and not investigations.street_result().is_empty()
		_distance_label.visible = not at_result and not _compact_landscape_touch and not text.is_empty()
		_objective_label.text = objective_text()


func set_controls_hint_visible(value: bool) -> void:
	if _controls_hint and _controls_hint.visible != value and not (get_viewport().get_visible_rect().size.x < 750 or get_viewport().get_visible_rect().size.y < 480):
		_controls_hint.visible = value


## Approximate HUD coverage of the play view (0..1) for evidence reports.
func hud_coverage() -> float:
	var screen := get_viewport().get_visible_rect()
	var area: float = 0.0
	for panel: Control in [_mission_panel, _map_panel, _prompt_panel]:
		if panel and panel.is_visible_in_tree(): area += panel.get_global_rect().intersection(screen).get_area()
	return area / maxf(1.0, screen.get_area())


func _resize_modal() -> void:
	modal_resize_count += 1
	if _modal_scroll == null:
		return
	var screen := get_viewport().get_visible_rect().size
	var phone_layout: bool = device_profile=="phone" or screen.x<600 or screen.y<480
	for side: String in ["left","right","top","bottom"]:
		_modal_outer.add_theme_constant_override("margin_"+side,8 if phone_layout else 24)
		_modal_margin.add_theme_constant_override("margin_"+side,12 if phone_layout else 20)
	var map_layout: bool = _mode=="map" and screen.y>=350
	var title_layout: bool = _mode=="title"
	# R1: the title footer CTA needs ~160px; give the rest to the key-art text so
	# short browser canvases do not clip the secondary buttons.
	_modal_scroll.custom_minimum_size.y = clampf(screen.y - (170.0 if title_layout else 130.0 if map_layout else 150.0),80.0,420.0 if title_layout else 650.0 if map_layout else 460.0)
	if not title_layout:
		# Leave a fixed 48px return row outside the scrollable content.
		var compact_play: bool = _mode in ["map","culture_activity"]
		_modal_scroll.custom_minimum_size.y = minf(_modal_scroll.custom_minimum_size.y,maxf(60,screen.y-(130 if compact_play and phone_layout else 176 if compact_play else 210)))
	if _mode in ["pause","revisits","revisit_question","case"]:
		_modal_scroll.custom_minimum_size.y = minf(310 if _mode == "revisit_question" else 360 if _mode == "revisits" else 228,maxf(80,screen.y-138))
	if _mode == "pause": _modal_scroll.custom_minimum_size.y = minf(280,maxf(80,screen.y-138))
	if _mode == "case": _modal_scroll.custom_minimum_size.y = minf(650,maxf(80,screen.y-116))
	if _mode == "case" and screen.y >= 600:
		_modal_scroll.custom_minimum_size.y = minf(650,maxf(80,screen.y-170))
	if _mode == "title" and is_instance_valid(_title_logo):
		_title_logo.visible = screen.y >= 480
		_title_logo_plate.visible = _title_logo.visible
		_title_logo.custom_minimum_size.y = 116 if screen.y >= 600 else 54 if screen.y >= 480 else 0
	_modal_box.add_theme_constant_override("separation",6 if screen.y < 500 else 10)
	_modal_scroll.custom_minimum_size.x = clampf(screen.x - 132.0, 180.0, 660.0)
	_modal_panel.custom_minimum_size.x = clampf(screen.x - 64.0, 230.0, 700.0)
	if device_profile in ["tablet","desktop"] and _mode in ["life","life_station"]:
		var width: float = clampf(screen.x-90.0,250.0,980.0 if device_profile=="tablet" else 1100.0)
		_modal_panel.custom_minimum_size.x = width
		_modal_scroll.custom_minimum_size.x = maxf(180,width-50)
	elif device_profile=="phone":
		_modal_panel.custom_minimum_size.x = clampf(screen.x-16,180,650)
		_modal_scroll.custom_minimum_size.x = clampf(screen.x-64,132,602)
	if device_profile == "tablet" and _mode == "case" and screen.x >= 700 and screen.y >= 600:
		var width := minf(screen.x * 0.88, 1180.0)
		_modal_panel.custom_minimum_size.x = width
		_modal_scroll.custom_minimum_size.x = width - 80.0
		_modal_scroll.custom_minimum_size.y = minf(screen.y - 180.0, 620.0)
	if _mode == "case":
		# Binding owns its margin; words and controls never overlap it.
		_modal_scroll.custom_minimum_size.x = maxf(120,_modal_panel.custom_minimum_size.x-104)
		var reason: Node = _modal_content.get_node_or_null("CaseGateReason")
		if reason and reason.visible:
			_modal_scroll.custom_minimum_size.y = maxf(60,_modal_scroll.custom_minimum_size.y-28)
	var compact: bool = screen.x < 750 or screen.y < 480
	var touch_layout: bool = device_profile in ["phone","tablet"]
	_chain.custom_minimum_size = Vector2(110,16)
	_prompt_panel.visible = not (touch_layout and screen.y<480)
	_status_label.visible = not (touch_layout and compact)
	_map_panel.visible = not compact
	_controls_hint.visible = not compact and not touch_layout
	_mission_label.visible = not touch_layout
	if touch_layout: _map_panel.visible = false
	_scores_label.visible = false
	# Short landscape phones: keep the card to title/objective/bars so it clears
	# the left-edge sprint toggle; the jobs line stays reachable via 配送.
	_optional_label.visible = not touch_layout or (_optional and _optional.status in ["active","failed"]) or (_life and _life.status in ["active","choosing","returning","failed"])
	_survival_label.visible = not touch_layout
	_compact_landscape_touch = touch_layout and compact and screen.y <= screen.x
	if _compact_landscape_touch and _distance_label: _distance_label.visible = false
	if _mission_panel:
		_mission_panel.custom_minimum_size.x = clampf(screen.x * 0.34, 260.0, 470.0) if not (touch_layout and screen.y > screen.x) else clampf(screen.x - 32.0, 240.0, 470.0)
		if touch_layout and screen.y <= screen.x: _mission_panel.custom_minimum_size.x = clampf(screen.x * 0.5, 260.0, 440.0)
		if touch_layout and screen.y <= screen.x: _optional_label.visible = false
	if _prompt_panel:
		_prompt_panel.custom_minimum_size.x = clampf(screen.x * 0.46, 280.0, 620.0) if not (touch_layout and screen.y > screen.x) else clampf(screen.x - 32.0, 240.0, 620.0)
	# Touch layouts keep the command buttons outside the HUD cards.
	var phone_pads: bool = device_profile == "phone"
	_hud_margin.add_theme_constant_override("margin_top", (78 if phone_pads else 100) if touch_layout and screen.y > screen.x else 16)
	_hud_margin.add_theme_constant_override("margin_bottom", (236 if phone_pads else 300) if touch_layout and screen.y > screen.x else 16)
	_hud_margin.add_theme_constant_override("margin_right", (200 if phone_pads else 252) if touch_layout and screen.y <= screen.x else 16)
	_mission_label.add_theme_font_size_override("font_size", 16 if compact else 20)
	_objective_label.add_theme_font_size_override("font_size", 14 if compact else 18)
	_optional_label.add_theme_font_size_override("font_size", 14 if compact else 15)
	_fit_banner()


func _fit_banner() -> void:
	if not _banner_card: return
	var screen := get_viewport().get_visible_rect().size
	var touch := device_profile in ["phone","tablet"]
	var portrait := screen.y > screen.x
	var clearance := (300.0 if device_profile == "phone" else 370.0) if touch and portrait else 100.0
	var width := minf(screen.x - (232.0 if touch and not portrait else 32.0), 840.0)
	_banner_card.position = Vector2(16 if touch and not portrait else (screen.x - width) * 0.5, screen.y - clearance - 142.0)
	_banner_card.size = Vector2(width, 142)


func _style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(mini(radius, 2))
	style.border_width_left = 3
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.086, 0.094, 0.114, 0.97), Art.KRAFT, 2))
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
	button.clip_text = true
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.tooltip_text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	(parent if parent != null else _modal_box).add_child(button)
	return button


func _on_title_start() -> void:
	hide_menus()
	# Root shows the cold-open story when it listens; standalone HUDs start directly.
	if story_start_requested.get_connections().is_empty(): new_game_requested.emit()
	else: story_start_requested.emit()


func _open(mode: String, heading: String, subtitle: String) -> void:
	if _overlay == null:
		return
	_mode = mode
	# Auto scrollbars change the wrapping width. Near a page-height threshold,
	# Godot 4.7 can alternate between both widths in the same message-queue flush.
	# Reserve a constant gutter before adding any case text or artwork.
	_modal_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS if mode == "case" else ScrollContainer.SCROLL_MODE_AUTO
	# Keep the stable gutter required by R4.1 while suppressing system chrome.
	_modal_scroll.get_v_scroll_bar().self_modulate = Color.TRANSPARENT if mode == "case" else Color.WHITE
	_title_footer.visible = mode=="title"
	_title_art.visible = mode=="title"
	_return_footer.visible = mode!="title"
	_return_footer.get_child(0).visible = true
	var gate: Node = _modal_content.get_node_or_null("CaseGateReason")
	if gate: gate.visible = false
	_return_footer.get_child(1).visible = not _settings_return_title or mode != "settings"
	# R1: the title is a key-art screen. The gameplay HUD stays hidden behind it
	# and the street remains visible through a lighter veil.
	if mode == "title":
		if _hud.visible: _title_hid_hud = true
		_hud.visible = false
	elif _title_hid_hud:
		_title_hid_hud = false
		_hud.visible = true
	if _dim: _dim.color = Color(0.086, 0.094, 0.114, 0.10) if mode == "title" else Color("16181d") if mode == "case" else Color(0.086, 0.094, 0.114, 0.84)
	if mode == "case": _hud.visible = false
	var binding: Node = _modal_panel.get_node_or_null("DossierBinding")
	if binding: binding.visible = mode == "case"
	if _modal_panel: _modal_panel.add_theme_stylebox_override("panel", _style(Color(0.086, 0.094, 0.114, 0.82), Art.KRAFT, 2) if mode == "title" else _style(Color(0.086, 0.094, 0.114, 0.97), Art.KRAFT, 2))
	_resize_modal()
	for child: Node in _modal_box.get_children():
		_modal_box.remove_child(child)
		child.queue_free()
	if not heading.is_empty(): _modal_box.add_child(_label(heading, 22 if get_viewport().get_visible_rect().size.y < 500 else 28, ACCENT))
	# Existing life/activity panels address the subtitle at child 1, even when empty.
	if not subtitle.is_empty() or mode not in ["pause","revisits","case"]: _modal_box.add_child(_label(subtitle, 16))
	_overlay.show()
	get_tree().paused = true
	menu_opened.emit()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_modal_scroll.scroll_vertical = 0


func hide_menus() -> void:
	_mode = ""
	_hud.visible = true
	if _title_hid_hud and _hud:
		_title_hid_hud = false
		_hud.visible = true
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
	_open("title", "", "")
	for child: Node in _modal_box.get_children():
		_modal_box.remove_child(child)
		child.queue_free()
	var screen := get_viewport().get_visible_rect().size
	_title_logo = Art.image("title-logo", 116 if screen.y >= 600 else 54 if screen.y >= 480 else 0)
	_title_logo.visible = screen.y >= 480
	_title_logo_plate = PanelContainer.new()
	_title_logo_plate.name = "LogoPaperBacking"
	_title_logo_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_logo_plate.add_theme_stylebox_override("panel",Art.paper())
	_title_logo_plate.visible = _title_logo.visible
	_title_logo_plate.add_child(_title_logo)
	_modal_box.add_child(_title_logo_plate)
	var compact: bool = get_viewport().get_visible_rect().size.x < 600 or get_viewport().get_visible_rect().size.y < 600
	var heading := _label("七期：斷鏈行動", 19 if compact else 28, INK)
	_modal_box.add_child(heading)
	_modal_box.add_child(_label("案卷 01／第一章｜出金保證金", 13, ACCENT))
	_modal_box.add_child(_label("留住說詞，找出矛盾。", 19, INK))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_modal_box.add_child(row)
	_button("讀取存檔", func() -> void: load_requested.emit(), row)
	_button("設定",show_settings, row)
	_button("離開", func() -> void: quit_requested.emit(), row)
	_modal_box.add_child(_label("三十八萬存款，消失在假投資群組。\n保存訊息 → 車店核對 → 連結證物", 13 if screen.y < 480 else 16, INK))
	if get_viewport().get_visible_rect().size.y >= 600:
		_modal_box.add_child(_label("人物、公司與地點均為虛構。本版為第一章切片。", 13, MUTED))
	_title_start_button.grab_focus()
	_resize_modal.call_deferred()


func show_pause(page: int = 0) -> void:
	if investigation_panel: investigation_panel.dismiss()
	_open("pause", "暫停", "")
	var tabs := HBoxContainer.new()
	_modal_box.add_child(tabs)
	for index: int in 4:
		_button(["行動","進度","其他","查證"][index],show_pause.bind(index),tabs)
	var grid := GridContainer.new()
	grid.columns = 3 if page == 2 else 2
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",6)
	_modal_box.add_child(grid)
	if page == 0:
		_button("反詐案卷",show_fraud_case,grid)
		_button("章節回訪",show_revisits,grid)
		_button("街區地圖",show_district_map,grid)
		_button("配送與生活",func() -> void: life_requested.emit(),grid)
	elif page == 1:
		_button("儲存進度",func() -> void: save_requested.emit(),grid)
		_button("讀取存檔",func() -> void: load_requested.emit(),grid)
		_button("重試目前任務",func() -> void: hide_menus(); retry_requested.emit(),grid)
		_button("街坊委託與活動",show_optional_phone,grid)
	elif page == 3:
		if investigation_panel: _button("街坊查證簿・三宗新案",show_investigations,grid)
	else:
		_button("畫面與操作設定",show_settings,grid)
		_button("補給與挑戰",func() -> void: supplies_requested.emit(),grid)
		_button("重新開始",func() -> void: hide_menus(); new_game_requested.emit(),grid)
		_button("離開遊戲",func() -> void: quit_requested.emit(),grid)
		_button("視角向左",func() -> void: camera_requested.emit(-0.25),grid)
		_button("視角向右",func() -> void: camera_requested.emit(0.25),grid)
	_focus_first_button()

func _menu_back() -> void:
	if _mode == "case" and fraud_panel and fraud_panel.case.stage == 2 and fraud_panel.case.selected_claim >= 0:
		fraud_panel.case.selected_claim = -1
		show_fraud_case()
	elif _mode == "settings" and _settings_return_title: show_title()
	elif _mode == "pause": _resume()
	else: show_pause()

func bind_revisits(manager: Node, start_callback: Callable) -> void:
	_revisits = manager
	_start_revisit = start_callback
	_revisits.updated.connect(_refresh_mission)

func show_revisits(page: int = -1) -> void:
	if not _revisits: return
	_revisit_page = _revisits.recommended() if page < 0 else clampi(page,0,2)
	var route: Dictionary = _revisits.ROUTES[_revisit_page]
	_open("revisits","回訪 %d／3｜後記 %d／3" % [_revisit_page+1,_revisits.records.size()],"")
	_modal_box.add_child(_label(route["title"],20,ACCENT))
	_modal_box.add_child(_label(route["brief"],15))
	var entry: Dictionary = _revisits.records.get(route["id"],{})
	var summary := "三站走訪・可隨時暫停"
	if not entry.is_empty(): summary = "%d 次完成・最佳 %d 秒" % [entry["runs"],ceili(entry["best_seconds"])]
	if _revisit_page == _revisits.recommended(): summary += "・今日推薦"
	_modal_box.add_child(_label(summary,14,MUTED))
	if _revisits.active >= 0:
		_button("放下回訪，恢復主線導引",func() -> void: _revisits.cancel(); _refresh_mission(); _resume())
	elif _revisits.unlocked(_revisit_page):
		_button("再走一趟" if not entry.is_empty() else "接下回訪",func() -> void: _start_revisit.call(_revisit_page))
	else:
		_modal_box.add_child(_label("完成前一份回訪後解鎖",16,ACCENT))
	var row := HBoxContainer.new()
	_modal_box.add_child(row)
	_button("← 上一份",show_revisits.bind(posmod(_revisit_page-1,3)),row)
	_button("下一份 →",show_revisits.bind((_revisit_page+1)%3),row)
	if not entry.is_empty(): _button("閱讀後記",show_revisit_note.bind(_revisit_page),row)
	if _revisit_page == 1 and investigation_panel:
		_button("新查證｜晚班之前的收據",func() -> void: hide_menus(); investigation_panel.open_case("before_night"))

func show_revisit_note(page: int) -> void:
	if not _revisits or page < 0 or page > 2 or not _revisits.records.has(_revisits.ROUTES[page]["id"]): return
	_open("revisit_note",_revisits.ROUTES[page]["title"],_revisits.ROUTES[page]["note"])
	_button("回訪清單",show_revisits.bind(page))

func show_revisit_question() -> void:
	if not _revisits or not _revisits.awaiting_answer: return
	var route: Dictionary = _revisits.ROUTES[_revisits.active]
	_open("revisit_question",route["question"],route["clue"])
	for index: int in 2:
		_button(route["choices"][index],_answer_revisit.bind(index))

func _answer_revisit(choice: int) -> void:
	if _revisits.answer(choice):
		show_toast("核對完成｜回集合點交回紀錄")
		_resume()
	else:
		show_toast("再讀一次線索，可以重選")


func show_phone() -> void:
	var title := _player_mission_title() if is_instance_valid(_manager) else "任務手機"
	var objective := objective_text() if is_instance_valid(_manager) else "先開始新遊戲。"
	_open("phone", title, objective)
	if fraud_panel: _button("反詐案卷",show_fraud_case)
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
	_button("台灣生活／外送／取貨",func() -> void: life_requested.emit())
	_button("街區地圖",show_district_map)
	_button("補給與街區挑戰",func() -> void: supplies_requested.emit())
	_button("收起手機，繼續行動", _resume)
	_focus_first_button()

func show_optional_phone(category: String = "side", page: int = 0) -> void:
	if not _optional:
		show_phone()
		return
	_open("optional", "街坊委託與街頭活動", _optional.get_active_text())
	if _revisits: _button("章節回訪／人物後記",show_revisits)
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

func show_systems(near_shop: bool = false) -> void:
	if not _systems: return
	_near_shop = near_shop
	var status: Dictionary = _systems.get_status()
	_open("systems","街區補給與成長","%s｜等級 %d　經驗 %d　補給金 %d" % [status["rank_name"],status["rank"],status["xp"],status["credits"]])
	_modal_box.add_child(_label("到美晴車店的補給台購買；補給金由街區挑戰取得，與任務零件券分開。" if not near_shop else "已在補給台附近。急救補給會恢復生命，整備可改善體力、工具與自行車。",15,MUTED))
	if not str(_systems.last_notice).is_empty():
		_modal_box.add_child(_label(str(_systems.last_notice),15,ACCENT))
	for offer: Dictionary in _systems.get_offers():
		var caption: String = "%s｜%d 補給金" % [offer["title"],offer["cost"]]
		if offer["sold_out"]: caption += "（已領取）"
		elif not offer["unlocked"]: caption += "（等級 %d 解鎖）" % offer["unlock_rank"]
		var item: Button = _button(caption,func() -> void: purchase_requested.emit(str(offer["id"])))
		item.disabled = not near_shop or not offer["available"]
		_modal_box.add_child(_label(str(offer["description"]),14,MUTED))
	_modal_box.add_child(_label("街區挑戰",21,ACCENT))
	for challenge: Dictionary in _systems.get_challenges():
		_modal_box.add_child(_label("%s　%d／%d %s%s" % [challenge["title"],floori(float(challenge["progress"])),int(challenge["goal"]),challenge["unit"]," ✓" if challenge["completed"] else ""],16))
		_modal_box.add_child(_label("%s　獎勵 %d 補給金／%d XP" % [challenge["description"],challenge["reward_credits"],challenge["reward_xp"]],14,MUTED))
	var journal: Array = _systems.get_journal()
	if not journal.is_empty():
		_modal_box.add_child(_label("最近紀錄",18,ACCENT))
		for index: int in range(maxi(0,journal.size()-4),journal.size()):
			_modal_box.add_child(_label(str(journal[index].get("text",journal[index].get("message",""))),13,MUTED))
	if not near_shop:
		_button("在地圖標示補給台",func() -> void: waypoint_selected.emit(Vector2(-58,57)); show_district_map())
	_button("繼續行動",_resume)
	_focus_first_button()

func show_district_map() -> void:
	_open("map","七期街區地圖","白點是你，黃點是任務。點地圖放置自訂目的地；街區範圍為 %d × %d 公尺。" % [int(_world_radius*2),int(_world_radius*2)])
	if get_viewport().get_visible_rect().size.y<480:
		(_modal_box.get_child(0) as Label).add_theme_font_size_override("font_size",22)
		(_modal_box.get_child(1) as Label).add_theme_font_size_override("font_size",13)
	_large_map = MapScript.new()
	_large_map.world_radius = _world_radius
	_large_map.navigation_roads = _navigation_roads.duplicate(true)
	_large_map.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y-320.0,180.0,350.0)
	_large_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_box.add_child(_large_map)
	_large_map.setup(_world_regions,_world_blocks,_world_points)
	_large_map.player_position = _map_player
	_large_map.target_position = _map_target
	_large_map.has_target = _has_map_target
	_large_map.has_waypoint = _street.has_waypoint if _street else false
	_large_map.waypoint_position = _street.waypoint if _street else Vector2.ZERO
	_large_map.waypoint_selected.connect(func(value: Vector2) -> void:
		waypoint_selected.emit(value)
		_large_map.waypoint_position = _street.waypoint
		_large_map.has_waypoint = _street.has_waypoint
		_large_map.queue_redraw()
	)
	_modal_box.add_child(_label("藍點汽車／綠點自行車／淡黃點車店與安全點。方向線不會自動避開建築。",13,MUTED))
	var destinations := HBoxContainer.new()
	_modal_box.add_child(destinations)
	_button("美晴車店",func() -> void: waypoint_selected.emit(Vector2(-58,57)); show_district_map(),destinations)
	_button("撤離安全點",func() -> void: waypoint_selected.emit(Vector2(-46,42)); show_district_map(),destinations)
	_button("清除自訂標記",func() -> void: waypoint_cleared.emit(); show_district_map())
	_button("收起地圖，繼續行動",_resume)
	_focus_first_button()

func show_settings() -> void:
	if not _street: return
	_settings_return_title = _mode=="title" or (_mode=="settings" and _settings_return_title)
	_open("settings","畫面與操作","可調整畫質、視角、音效與戰鬥難度；設定會隨進度儲存。")
	var device_row := HFlowContainer.new()
	_modal_box.add_child(device_row)
	for profile: String in ["auto","phone","tablet","desktop"]:
		var names: Dictionary = {"auto":"自動裝置","phone":"手機","tablet":"平板","desktop":"電腦"}
		_button(str(names[profile])+(" ✓" if device_profile==profile else ""),func() -> void: device_selected.emit(profile); show_settings(),device_row)
	_modal_box.add_child(_label("裝置設定各自保存：手機搖桿、平板工作雙欄、電腦鍵鼠與遠景預算。",14,MUTED))
	_modal_box.add_child(_label("畫質｜省電保留基本街景；均衡增加材質層次；細緻開啟太陽陰影。",15,MUTED))
	var quality_row := HBoxContainer.new()
	_modal_box.add_child(quality_row)
	for key: String in ["performance","balanced","quality"]:
		var captions: Dictionary = {"performance":"省電","balanced":"均衡","quality":"細緻"}
		_button(str(captions[key])+ (" ✓" if _street.quality==key else ""),func() -> void: setting_changed.emit("quality",key); show_settings(),quality_row)
	var difficulty_row := HBoxContainer.new()
	_modal_box.add_child(difficulty_row)
	_button("標準"+(" ✓" if _street.difficulty=="standard" else ""),func() -> void: setting_changed.emit("difficulty","standard"); show_settings(),difficulty_row)
	_button("輕鬆"+(" ✓" if _street.difficulty=="relaxed" else ""),func() -> void: setting_changed.emit("difficulty","relaxed"); show_settings(),difficulty_row)
	_modal_box.add_child(_label("輕鬆模式降低受到的傷害與警衛追擊速度，任務獎勵維持相同。",14,MUTED))
	var sensitivity_row := HBoxContainer.new()
	_modal_box.add_child(sensitivity_row)
	for key: String in ["0.7","1.0","1.4"]:
		_button("視角 "+key+ (" ✓" if is_equal_approx(_street.sensitivity,float(key)) else ""),func() -> void: setting_changed.emit("sensitivity",key); show_settings(),sensitivity_row)
	_button("音效："+("關閉" if _street.muted else "開啟"),func() -> void: setting_changed.emit("muted","off" if _street.muted else "on"); show_settings())
	_button("日夜循環："+("開啟" if _street.cycle_enabled else "暫停"),func() -> void: setting_changed.emit("cycle","off" if _street.cycle_enabled else "on"); show_settings())
	var time_row := HBoxContainer.new()
	_modal_box.add_child(time_row)
	for key: String in ["10.0","17.5","21.0"]:
		var captions: Dictionary = {"10.0":"日間","17.5":"黃昏","21.0":"夜間"}
		_button(captions[key],func() -> void: setting_changed.emit("hour",key); show_settings(),time_row)
	_button("返回開頭" if _settings_return_title else "繼續行動",show_title if _settings_return_title else _resume)
	_focus_first_button()


func _select_branch(choice: String) -> void:
	branch_selected.emit(choice)
	# Root applies the choice synchronously. Accepted choices return to the street.
	if is_instance_valid(_manager) and str(_manager.branch) == choice:
		if is_menu_open():
			_resume()
	else:
		show_phone()


func show_chapter_complete(chosen_branch: String, run: Dictionary = {}) -> void:
	var names := {"smash":"破壞", "evidence":"蒐證", "rescue":"救援"}
	var outcomes := {"smash":"前站的三個營運設備已失能。美晴等你回來，把借出的扳手收進工具架。", "evidence":"兩份紀錄已保存，前站營運已中止。予安接下文件，還有人名需要逐一釐清。", "rescue":"額外兩名受困者已到安全點，前站營運已中止。周成確認大家都上車，才鬆開一直握著的手。"}
	_open("complete", "第一章切片完成", "本次選法：" + str(names.get(chosen_branch, "未選擇")))
	if run.has("grade"):
		# R1 replay hook: a visible grade, the best per branch and a next target.
		var grade_colors := {"S":Color("ffd36b"), "A":Color("9fe0b0"), "B":Color("9cc8ff"), "C":Color("c9c9c9")}
		var grade_row := HBoxContainer.new()
		grade_row.add_theme_constant_override("separation", 16)
		_modal_box.add_child(grade_row)
		var grade_label := _label(str(run["grade"]), 64, grade_colors.get(str(run["grade"]), INK))
		grade_label.name = "RunGrade"
		grade_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		grade_row.add_child(grade_label)
		var detail := _label("本局評價｜%d 分　用時 %s%s" % [int(run.get("score", 0)), str(run.get("time_text", "")), "
新紀錄！" if bool(run.get("new_best", false)) else ""], 18, INK)
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grade_row.add_child(detail)
		_modal_box.add_child(_label(str(run.get("progress", "")), 17, ACCENT))
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
	_notice_until = Time.get_ticks_msec()+1500
	_notice_label.modulate.a = 1
	var expiration := _notice_until
	get_tree().create_timer(1.5,true).timeout.connect(func() -> void:
		if _notice_until == expiration:
			_notice_until = 0
			_notice_label.text = ""
	)
	if _notice_label != null:
		_notice_label.text = message
	if is_menu_open():
		_modal_box.add_child(_label(message, 16, ACCENT))


func _focus_first_button() -> void:
	for child: Node in _modal_box.get_children():
		if child is Button:
			child.grab_focus()
			return
	# Short landscape choices are a row; inspection thumbnails must not steal
	# the primary decision focus when entering or returning to the case.
	for child: Node in _modal_box.find_children("*","Button",true,false):
		if not child.has_meta("evidence_photo"):
			(child as Button).grab_focus()
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
	_mission_label.text = _player_mission_title()
	_objective_label.text = objective_text()
	if _revisits and _revisits.active >= 0:
		_mission_label.text = _revisits.ROUTES[_revisits.active]["title"]
		_objective_label.text = _revisits.active_text()
	_scores_label.text = _score_text()
	_notice_label.text = _cached_notice if Time.get_ticks_msec() < _notice_until else ""

func _player_mission_title() -> String:
	if _manager.chapter_complete: return "第一章完成"
	return "第 %d 環｜%s" % [int(_manager.mission_index)+1,str(_manager.get_current_mission().get("title","準備開始"))]


func update_status(hp: float, weapon: String, heat: int, vehicle: String, prompt: String) -> void:
	if _status_label == null:
		return
	var weapon_names := {"wrench":"扳手", "bat":"球棒", "pulse":"脈衝器具", "none":"空手", "":"空手"}
	var vehicle_names := {"bicycle":"自行車", "car":"小客車", "":"步行"}
	if _health_bar: _health_bar.value = clampf(hp, 0.0, 100.0)
	_status_label.text = "安全值 %d／100　工具：%s　警戒 %d／5　%s" % [clampi(int(hp), 0, 100), str(weapon_names.get(weapon, weapon)), clampi(heat, 0, 5), str(vehicle_names.get(vehicle, vehicle))]
	_prompt_label.text = prompt if not prompt.is_empty() else "沿光柱前往目標，靠近後點右下黃鍵互動。" if device_profile in ["phone","tablet"] else "沿導航前往任務目標。靠近標示物件，按 E 互動。"
	if investigations and investigations.street_at_source and not investigations.street_result().is_empty():
		_prompt_label.text = ("點互動｜" if device_profile in ["phone","tablet"] else "E｜")+investigations.street_result().place+"｜互動"
	if device_profile in ["phone","tablet"]: _prompt_panel.visible = not prompt.is_empty() and get_viewport().get_visible_rect().size.y >= 480


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
