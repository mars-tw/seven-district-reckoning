class_name TouchControls
extends CanvasLayer

signal camera_step(amount: float)
signal phone_requested
signal pause_requested
signal map_requested

var enabled: bool = false
var controls: Control
var panels: Array[Control] = []
var held: Dictionary = {}
var minimum_until: Dictionary = {}
var small_view_hint: Label
var too_small: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 35
	controls = Control.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(controls)
	var left := GridContainer.new()
	left.columns = 3
	left.add_theme_constant_override("h_separation", 5)
	left.add_theme_constant_override("v_separation", 5)
	controls.add_child(left)
	panels.append(left)
	_action_button(left,"跑","sprint"); _action_button(left, "↑", "move_forward"); _spacer(left)
	_action_button(left, "←", "move_left"); _action_button(left, "↓", "move_back"); _action_button(left, "→", "move_right")
	var right := GridContainer.new()
	right.columns = 3
	right.add_theme_constant_override("h_separation", 5)
	right.add_theme_constant_override("v_separation", 5)
	controls.add_child(right)
	panels.append(right)
	_action_button(right, "攻擊", "attack"); _action_button(right, "互動", "interact"); _action_button(right, "上下車", "mount")
	_action_button(right, "跳／煞", "jump"); _action_button(right, "換工具", "cycle_weapon"); _action_button(right, "取回", "reset_vehicle")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	controls.add_child(top)
	panels.append(top)
	_command_button(top, "視角←", func() -> void: camera_step.emit(-0.25))
	_command_button(top, "視角→", func() -> void: camera_step.emit(0.25))
	_command_button(top, "委託", func() -> void: phone_requested.emit())
	_command_button(top, "地圖", func() -> void: map_requested.emit())
	_command_button(top, "暫停", func() -> void: pause_requested.emit())
	get_viewport().size_changed.connect(_layout)
	small_view_hint = Label.new()
	small_view_hint.text = "請用全螢幕或橫向，放大操作區"
	small_view_hint.add_theme_font_size_override("font_size", 14)
	if ResourceLoader.exists("res://assets/fonts/SevenDistrictSansTC-Regular.otf"):
		small_view_hint.add_theme_font_override("font", load("res://assets/fonts/SevenDistrictSansTC-Regular.otf"))
	controls.add_child(small_view_hint)
	_layout()
	set_enabled(DisplayServer.is_touchscreen_available())

func _spacer(parent: Node) -> void:
	var item := Control.new()
	item.custom_minimum_size = Vector2(50, 50)
	parent.add_child(item)

func _button(parent: Node, caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(54, 50)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	if ResourceLoader.exists("res://assets/fonts/SevenDistrictSansTC-Regular.otf"):
		button.add_theme_font_override("font", load("res://assets/fonts/SevenDistrictSansTC-Regular.otf"))
	parent.add_child(button)
	return button

func _action_button(parent: Node, caption: String, action: String) -> void:
	var button := _button(parent, caption)
	button.button_down.connect(func() -> void:
		held[action] = true
		minimum_until[action] = Time.get_ticks_msec() + 140
		Input.action_press(action)
		if action == "jump": Input.action_press("brake")
	)
	button.button_up.connect(func() -> void: held[action] = false)
	button.mouse_exited.connect(func() -> void: held[action] = false)

func _command_button(parent: Node, caption: String, callback: Callable) -> void:
	_button(parent, caption).pressed.connect(callback)

func _process(_delta: float) -> void:
	if not enabled or get_tree().paused:
		release_all()
		controls.visible = enabled and not get_tree().paused
		return
	controls.visible = true
	for action: String in held.keys():
		if not held[action] and Time.get_ticks_msec() >= int(minimum_until.get(action, 0)):
			Input.action_release(action)
			if action == "jump": Input.action_release("brake")
			held.erase(action)
			minimum_until.erase(action)

func set_enabled(value: bool) -> void:
	enabled = value
	if controls:
		controls.visible = value and not get_tree().paused
	if not value:
		release_all()

func release_all() -> void:
	for action: String in held:
		Input.action_release(action)
	if held.has("jump"):
		Input.action_release("brake")
	held.clear()
	minimum_until.clear()

func _layout() -> void:
	if panels.size() != 3:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	too_small = viewport_size.y < 300 or viewport_size.x < 350
	if too_small: release_all()
	for panel: Control in panels: panel.visible = not too_small
	small_view_hint.visible = too_small
	small_view_hint.position = Vector2(maxf(4, (viewport_size.x - 240) * 0.5), maxf(4, viewport_size.y - 50))
	panels[0].position = Vector2(10, maxf(140, viewport_size.y - 220))
	panels[1].position = Vector2(maxf(180, viewport_size.x - 185), maxf(140, viewport_size.y - 220))
	panels[2].position = Vector2(maxf(8, (viewport_size.x - panels[2].get_combined_minimum_size().x) * 0.5), 155)
