class_name TouchControls
extends CanvasLayer

signal camera_step(amount: float)
signal phone_requested
signal pause_requested
signal map_requested
signal jobs_requested

class JoystickVisual extends Control:
	var vector := Vector2.ZERO
	func _draw() -> void:
		var radius := size.x * .5
		draw_circle(size * .5, radius - 2, Color(0.08,.18,.20,.55))
		draw_arc(size * .5, radius - 2, 0, TAU, 48, Color(.80,.90,.86,.65), 2)
		draw_circle(size * .5 + vector * radius * .58, radius * .32, Color(.94,.51,.30,.80))

var enabled := false
var controls: Control
var panels: Array[Control] = []
var held: Dictionary = {}
var minimum_until: Dictionary = {}
var small_view_hint: Label
var too_small := false
var profile := "desktop"
var settings: Dictionary = {}
var safe_insets := Vector4.ZERO # left, top, right, bottom, in UI coordinates.
var joystick: JoystickVisual
var joystick_zone := Rect2()
var joystick_index := -1
var joystick_origin := Vector2.ZERO
var joystick_vector := Vector2.ZERO
var sprint_toggle := false
var _action_buttons: Dictionary = {}
var _command_buttons: Dictionary = {}
var _touch_owners: Dictionary = {}
var _action_owners: Dictionary = {}
var _floating_sprint: Button
var _last_size := Vector2.ZERO
var _original_mouse_emulation := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 35
	_original_mouse_emulation = Input.emulate_mouse_from_touch
	controls = Control.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(controls)
	var left := GridContainer.new()
	left.columns = 3
	controls.add_child(left)
	panels.append(left)
	_action_button(left,"跑","sprint"); _action_button(left,"↑","move_forward"); _spacer(left)
	_action_button(left,"←","move_left"); _action_button(left,"↓","move_back"); _action_button(left,"→","move_right")
	var right := GridContainer.new()
	right.columns = 3
	controls.add_child(right)
	panels.append(right)
	_action_button(right,"攻擊","attack"); _action_button(right,"互動","interact"); _action_button(right,"上下車","mount")
	_action_button(right,"跳／煞","jump"); _action_button(right,"換工具","cycle_weapon"); _action_button(right,"取回","reset_vehicle")
	var top := GridContainer.new()
	top.columns = 6
	controls.add_child(top)
	panels.append(top)
	_command_button(top,"視角←",func() -> void: camera_step.emit(-.25))
	_command_button(top,"視角→",func() -> void: camera_step.emit(.25))
	_command_button(top,"委託",func() -> void: phone_requested.emit())
	_command_button(top,"地圖",func() -> void: map_requested.emit())
	_command_button(top,"配送",func() -> void: jobs_requested.emit())
	_command_button(top,"暫停",func() -> void: pause_requested.emit())
	joystick = JoystickVisual.new()
	joystick.name = "FloatingJoystick"
	joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.add_child(joystick)
	_floating_sprint = _button(controls,"連跑")
	_floating_sprint.name = "SprintToggle"
	_command_buttons[_floating_sprint] = _toggle_sprint
	_floating_sprint.pressed.connect(_toggle_sprint)
	_floating_sprint.button_down.connect(func() -> void:
		if not bool(settings.get("sprint_toggle",true)): _press_action("sprint","floating_mouse",1.0,140)
	)
	_floating_sprint.button_up.connect(func() -> void: _release_owner("floating_mouse"))
	_floating_sprint.mouse_exited.connect(func() -> void: _release_owner("floating_mouse"))
	small_view_hint = Label.new()
	small_view_hint.text = "請用全螢幕或橫向，放大操作區"
	small_view_hint.add_theme_font_size_override("font_size",14)
	_use_font(small_view_hint)
	controls.add_child(small_view_hint)
	get_viewport().size_changed.connect(_layout)
	_layout()
	set_enabled(DisplayServer.is_touchscreen_available())

func _use_font(control: Control) -> void:
	if ResourceLoader.exists("res://assets/fonts/SevenDistrictSansTC-Regular.otf"):
		control.add_theme_font_override("font",load("res://assets/fonts/SevenDistrictSansTC-Regular.otf"))

func _spacer(parent: Node) -> void:
	var item := Control.new()
	item.custom_minimum_size = Vector2(54,54)
	parent.add_child(item)

func _button(parent: Node, caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(54,54)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size",13)
	_use_font(button)
	parent.add_child(button)
	return button

func _action_button(parent: Node, caption: String, action: String) -> void:
	var button := _button(parent,caption)
	_action_buttons[button] = action
	button.button_down.connect(func() -> void: _press_action(action,"mouse:" + str(button.get_instance_id()),1.0,140))
	button.button_up.connect(func() -> void: _release_owner("mouse:" + str(button.get_instance_id())))
	button.mouse_exited.connect(func() -> void: _release_owner("mouse:" + str(button.get_instance_id())))

func _command_button(parent: Node, caption: String, callback: Callable) -> void:
	var button := _button(parent,caption)
	_command_buttons[button] = callback
	button.pressed.connect(callback)

func _press_action(action: String, owner: String, strength: float = 1.0, minimum_ms: int = 0) -> void:
	if not InputMap.has_action(action): return
	if not _action_owners.has(action): _action_owners[action] = {}
	_action_owners[action][owner] = strength
	held[action] = true
	minimum_until[action] = maxi(int(minimum_until.get(action,0)),Time.get_ticks_msec() + minimum_ms)
	Input.action_press(action,strength)
	if action == "jump" and InputMap.has_action("brake"): Input.action_press("brake",strength)

func _release_owner(owner: String) -> void:
	for action: String in _action_owners.keys():
		_action_owners[action].erase(owner)
		held[action] = not _action_owners[action].is_empty()
		if held[action]:
			var maximum := 0.0
			for value: float in _action_owners[action].values(): maximum = maxf(maximum,value)
			Input.action_press(action,maximum)
	_release_expired()

func _release_expired() -> void:
	for action: String in held.keys():
		if not held[action] and Time.get_ticks_msec() >= int(minimum_until.get(action,0)):
			Input.action_release(action)
			if action == "jump" and InputMap.has_action("brake"): Input.action_release("brake")
			held.erase(action)
			minimum_until.erase(action)
			_action_owners.erase(action)

func _input(event: InputEvent) -> void:
	if not enabled or too_small or get_tree().paused: return
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.canceled:
			_release_touch(touch.index)
			get_viewport().set_input_as_handled()
		elif touch.pressed:
			for button: Button in _action_buttons:
				if button.is_visible_in_tree() and button.get_global_rect().has_point(touch.position):
					_touch_owners[touch.index] = {"action":_action_buttons[button],"button":button}
					_press_action(_action_buttons[button],"touch:" + str(touch.index),1.0,140)
					get_viewport().set_input_as_handled()
					return
			for button: Button in _command_buttons:
				if button.is_visible_in_tree() and button.get_global_rect().has_point(touch.position):
					_touch_owners[touch.index] = {"command":_command_buttons[button],"button":button}
					get_viewport().set_input_as_handled()
					return
			if profile != "desktop" and joystick_index == -1 and joystick_zone.has_point(touch.position):
				joystick_index = touch.index
				var radius := float(settings.get("joystick_radius",56))
				joystick_origin = Vector2(clampf(touch.position.x,joystick_zone.position.x+radius,joystick_zone.end.x-radius),clampf(touch.position.y,joystick_zone.position.y+radius,joystick_zone.end.y-radius))
				joystick.position = joystick_origin - Vector2.ONE * radius
				_update_joystick(touch.position)
				get_viewport().set_input_as_handled()
		elif touch.index == joystick_index or _touch_owners.has(touch.index):
			var owned: Dictionary = _touch_owners.get(touch.index,{})
			var command: Callable = owned.get("command",Callable())
			var button: Button = owned.get("button")
			_release_touch(touch.index)
			get_viewport().set_input_as_handled()
			if command.is_valid() and is_instance_valid(button) and button.get_global_rect().has_point(touch.position):
				command.call()
				_sync_emulation()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == joystick_index:
			_update_joystick(drag.position)
			# Consume the owning drag even when it crosses into the camera half.
			get_viewport().set_input_as_handled()
		elif _touch_owners.has(drag.index):
			var button: Button = _touch_owners[drag.index].get("button")
			if is_instance_valid(button) and not button.get_global_rect().grow(10).has_point(drag.position): _release_touch(drag.index)
			get_viewport().set_input_as_handled()

func _release_touch(index: int) -> void:
	_release_owner("touch:" + str(index))
	_touch_owners.erase(index)
	if index == joystick_index:
		joystick_index = -1
		joystick_vector = Vector2.ZERO
		_release_owner("joystick")
		if joystick:
			joystick.vector = Vector2.ZERO
			joystick.queue_redraw()

func _update_joystick(position_value: Vector2) -> void:
	var radius := float(settings.get("joystick_radius",56))
	var vector := (position_value - joystick_origin) / radius
	if vector.length() > 1: vector = vector.normalized()
	if vector.length() < .16: vector = Vector2.ZERO
	else: vector = vector.normalized() * ((vector.length()-.16)/.84)
	joystick_vector = vector
	joystick.vector = vector
	joystick.queue_redraw()
	_release_owner("joystick")
	for pair: Array in [["move_left",-vector.x],["move_right",vector.x],["move_forward",-vector.y],["move_back",vector.y]]:
		if float(pair[1]) > .01: _press_action(str(pair[0]),"joystick",float(pair[1]))

func _toggle_sprint() -> void:
	if not bool(settings.get("sprint_toggle",true)): return
	sprint_toggle = not sprint_toggle
	_floating_sprint.text = "停跑" if sprint_toggle else "連跑"
	if sprint_toggle: _press_action("sprint","toggle")
	else: _release_owner("toggle")

func _process(_delta: float) -> void:
	_sync_emulation()
	if not enabled or get_tree().paused:
		release_all()
		controls.visible = enabled and not get_tree().paused
		return
	controls.visible = true
	_release_expired()

func set_enabled(value: bool) -> void:
	enabled = value
	if controls: controls.visible = value and not get_tree().paused
	if not value: release_all()
	_sync_emulation()

func _sync_emulation() -> void:
	# Touch events have their own indexed ownership. Translating finger 0 to
	# a left mouse click would also trigger the desktop attack InputMap entry.
	Input.emulate_mouse_from_touch = false if enabled and is_inside_tree() and not get_tree().paused else _original_mouse_emulation

func set_profile(value: Variant) -> void:
	release_all()
	if value is Dictionary:
		settings = value.duplicate(true)
		profile = str(settings.get("profile","desktop"))
	elif value is String:
		profile = value if value in ["phone","tablet","desktop"] else "desktop"
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/device_profiles.json"))
		settings = data.get(profile,{}).duplicate(true) if data is Dictionary else {}
	if _floating_sprint:
		if bool(settings.get("sprint_toggle",true)):
			_action_buttons.erase(_floating_sprint)
			_command_buttons[_floating_sprint] = _toggle_sprint
			_floating_sprint.text = "連跑"
		else:
			_command_buttons.erase(_floating_sprint)
			_action_buttons[_floating_sprint] = "sprint"
			_floating_sprint.text = "跑"
	_layout()

func set_safe_insets(value: Vector4) -> void:
	safe_insets = Vector4(maxf(0,value.x),maxf(0,value.y),maxf(0,value.z),maxf(0,value.w))
	_layout()

func release_all() -> void:
	for action: String in held: Input.action_release(action)
	if held.has("jump") and InputMap.has_action("brake"): Input.action_release("brake")
	held.clear()
	minimum_until.clear()
	_action_owners.clear()
	_touch_owners.clear()
	joystick_index = -1
	joystick_vector = Vector2.ZERO
	sprint_toggle = false
	if _floating_sprint: _floating_sprint.text = "連跑" if bool(settings.get("sprint_toggle",true)) else "跑"
	if joystick:
		joystick.vector = Vector2.ZERO
		joystick.queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_WINDOW_FOCUS_OUT]: release_all()
	if what == NOTIFICATION_EXIT_TREE: Input.emulate_mouse_from_touch = _original_mouse_emulation

func _layout() -> void:
	if panels.size() != 3 or not joystick: return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size != _last_size: release_all()
	_last_size = viewport_size
	var margin := float(settings.get("safe_margin",10))
	var safe := Rect2(Vector2(maxf(margin,safe_insets.x),maxf(margin,safe_insets.y)),viewport_size-Vector2(maxf(margin,safe_insets.x)+maxf(margin,safe_insets.z),maxf(margin,safe_insets.y)+maxf(margin,safe_insets.w)))
	too_small = safe.size.y < 280 or safe.size.x < 326
	if too_small: release_all()
	var button_size := float(settings.get("touch_button_size",54))
	var gap := int(settings.get("touch_spacing",6))
	# A manually selected tablet layout still fits narrow windows after rotation.
	button_size = minf(button_size,(safe.size.x*.52-float(gap)*2)/3)
	button_size = maxf(44,button_size)
	for panel: Control in panels:
		panel.visible = not too_small
		panel.add_theme_constant_override("h_separation",gap)
		panel.add_theme_constant_override("v_separation",gap)
	for button: Node in find_children("*","Button",true,false): (button as Button).custom_minimum_size = Vector2(button_size,button_size)
	panels[0].visible = not too_small and profile == "desktop"
	var actions_size := Vector2(button_size*3+gap*2,button_size*2+gap)
	panels[0].position = Vector2(safe.position.x,safe.end.y-actions_size.y-32)
	panels[1].position = Vector2(safe.end.x-actions_size.x,safe.end.y-actions_size.y-32)
	var portrait := viewport_size.y > viewport_size.x
	(panels[2] as GridContainer).columns = 3 if portrait else 6
	var command_width := button_size*(3 if portrait else 6)+gap*(2 if portrait else 5)
	panels[2].position = Vector2(safe.position.x+(safe.size.x-command_width)*.5,maxf(safe.position.y,150 if not portrait else 156))
	var radius := float(settings.get("joystick_radius",56))
	joystick.size = Vector2.ONE * radius*2
	joystick_origin = Vector2(safe.position.x+radius,safe.end.y-radius-24)
	joystick.position = joystick_origin-Vector2.ONE*radius
	joystick.visible = not too_small and profile != "desktop"
	joystick_zone = Rect2(Vector2(safe.position.x,maxf(280 if portrait else 215,safe.end.y-radius*3)),Vector2(safe.size.x*.45,safe.end.y-maxf(280 if portrait else 215,safe.end.y-radius*3)))
	_floating_sprint.visible = joystick.visible
	_floating_sprint.position = Vector2(safe.position.x,safe.end.y-radius*2-button_size-36)
	small_view_hint.visible = too_small
	small_view_hint.position = Vector2(maxf(4,(viewport_size.x-240)*.5),maxf(4,viewport_size.y-50))
