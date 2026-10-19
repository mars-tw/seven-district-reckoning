extends "res://scripts/ui/touch_controls.gd"
const Art = preload("res://scripts/ui/art_theme.gd")
## Mobile additions live separately from the existing native-export work.
var _canceled_fingers: Dictionary = {}
var _coach: Label
var _has_moved := false
var _has_interacted := false
var _normal_styles: Dictionary = {}
var _context_attack := false
var _context_mounted := false

class CaseJoystick extends TouchControls.JoystickVisual:
	func _draw() -> void:
		var radius := size.x * 0.5
		draw_circle(size * 0.5,radius-2,Color(0.086,0.094,0.114,0.65))
		draw_arc(size*0.5,radius-3,0,TAU,48,Color("c6bdad"),2)
		draw_arc(size*0.5,radius-8,0,TAU,48,Color("9a7443"),1)
		for angle: float in [-0.6,0.6,2.54,3.74]:
			var p := size*0.5+Vector2(cos(angle),sin(angle))*(radius-5)
			draw_circle(p,4,Color("16181d"))
			draw_arc(p,4,0,TAU,16,Color("c6bdad"),1)
		draw_line(Vector2(radius-12,8),Vector2(radius+12,14),Color("c4271c"),2,true)
		draw_circle(size*0.5+vector*radius*0.58,radius*0.24,Color("f1e8d5"))

class EvidenceTag extends Control:
	func _draw() -> void:
		var s := size
		var owner_button := get_parent() as Button
		var pressed := bool(owner_button.get_meta("touch_pressed",false)) or owner_button.button_pressed
		draw_colored_polygon(PackedVector2Array([Vector2(1,8),Vector2(9,1),Vector2(s.x-1,1),Vector2(s.x-1,s.y-1),Vector2(1,s.y-1)]),Color("cf9400") if pressed else Color("ffb800"))
		if owner_button.has_focus(): draw_line(Vector2(5,s.y-5),Vector2(s.x-5,s.y-5),Color("16181d"),2)
		draw_circle(Vector2(8,9),2,Color("16181d"))
		draw_line(Vector2(2,3),Vector2(11,12),Color("c4271c"),1.5,true)

func _ready() -> void:
	super._ready()
	var old_joystick := joystick
	joystick = CaseJoystick.new()
	joystick.name = "CaseJoystick"
	joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.add_child(joystick)
	old_joystick.queue_free()
	for button: Node in controls.find_children("*","Button",true,false):
		Art.skin_button(button as Button, _action_buttons.get(button, "") == "interact")
		# Touch pads have a fixed physical grid; paper-button padding must not grow it.
		for state: String in ["normal","hover","pressed","focus","disabled"]:
			var style: StyleBox = (button as Button).get_theme_stylebox(state)
			style.content_margin_left = 2
			style.content_margin_right = 2
			style.content_margin_top = 2
			style.content_margin_bottom = 2
		_normal_styles[button] = button.get_theme_stylebox("normal")
		if _action_buttons.get(button,"") == "interact":
			for state: String in ["normal","hover","pressed","focus","disabled"]:
				var tag_style := button.get_theme_stylebox(state) as StyleBoxFlat
				tag_style.bg_color = Color.TRANSPARENT
				tag_style.set_border_width_all(0)
			var tag := EvidenceTag.new()
			tag.name = "EvidenceTag"
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tag.resized.connect(tag.queue_redraw)
			button.button_down.connect(tag.queue_redraw)
			button.button_up.connect(tag.queue_redraw)
			button.focus_entered.connect(tag.queue_redraw)
			button.focus_exited.connect(tag.queue_redraw)
			button.add_child(tag)
			button.move_child(tag,0)
			# Keep the label above the tactile tag while preserving real hit bounds.
			var caption := Label.new()
			caption.name = "EvidenceTagCaption"
			caption.text = button.text
			caption.add_theme_font_size_override("font_size",14)
			caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
			caption.add_theme_color_override("font_color",Art.CHARCOAL)
			caption.add_theme_constant_override("outline_size",0)
			_use_font(caption)
			button.add_child(caption)
			for color_name: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: button.add_theme_color_override(color_name,Color.TRANSPARENT)
	_install_toolbar_art()
	_coach = Label.new()
	_coach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coach.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coach.add_theme_font_size_override("font_size",14)
	_coach.add_theme_color_override("font_outline_color",Color.BLACK)
	_coach.add_theme_constant_override("outline_size",4)
	_use_font(_coach)
	controls.add_child(_coach)
	_layout()

func _install_toolbar_art() -> void:
	# Retain button text, callbacks and physical hit regions; children ignore input.
	var index := 0
	for child: Node in panels[2].get_children():
		if not child is Button: continue
		var button := child as Button
		button.visible = index in [2,3,5]
		button.tooltip_text = button.text
		for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
			button.add_theme_color_override(state,Color.TRANSPARENT)
		button.add_theme_constant_override("outline_size",0)
		var icon := TextureRect.new()
		icon.name = "ToolbarArt"
		icon.texture = load("res://assets/art/r5/toolbar-%d.png" % index) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.anchor_left = 0.5
		icon.anchor_right = 0.5
		icon.offset_left = -14
		icon.offset_right = 14
		icon.offset_top = 2
		icon.offset_bottom = 30
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		var caption := Label.new()
		caption.text = button.text
		caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		caption.offset_top = -17
		caption.offset_bottom = -1
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size",13)
		caption.add_theme_color_override("font_color",Art.PAPER)
		caption.add_theme_constant_override("outline_size",0)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_use_font(caption)
		button.add_child(caption)
		index += 1

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed: _canceled_fingers.erase(event.index)
	if event is InputEventScreenTouch and not event.pressed:
		if _canceled_fingers.has(event.index):
			_canceled_fingers.erase(event.index)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventScreenDrag:
		if _canceled_fingers.has(event.index):
			get_viewport().set_input_as_handled()
			return
		var was_owned := _touch_owners.has(event.index)
		super._input(event)
		if was_owned and not _touch_owners.has(event.index): _canceled_fingers[event.index] = true
	else:
		super._input(event)
	_sync_pressed_feedback()

func _sync_pressed_feedback() -> void:
	for button: Button in _normal_styles:
		if not is_instance_valid(button): continue
		button.add_theme_stylebox_override("normal",_normal_styles[button])
		button.set_meta("touch_pressed",false)
	for owner: Dictionary in _touch_owners.values():
		var button: Button = owner.get("button")
		if is_instance_valid(button):
			button.add_theme_stylebox_override("normal",button.get_theme_stylebox("pressed"))
			button.set_meta("touch_pressed",true)
	for button: Button in _normal_styles:
		if is_instance_valid(button):
			var tag := button.get_node_or_null("EvidenceTag")
			if tag: tag.queue_redraw()

func set_interaction_context(caption: String) -> void:
	for button: Button in _action_buttons:
		if _action_buttons[button] != "interact": continue
		button.text = caption if not caption.is_empty() else "互動"
		var tag_caption := button.get_node_or_null("EvidenceTagCaption") as Label
		if tag_caption: tag_caption.text = button.text
		button.modulate = Color.WHITE if not caption.is_empty() else Color(.78,.84,.84,.9)

func confirm_interaction() -> void:
	_has_interacted = true

func set_action_context(attack_available: bool, mounted: bool) -> void:
	if _context_attack == attack_available and _context_mounted == mounted: return
	_context_attack = attack_available
	_context_mounted = mounted
	_layout()

func _process(delta: float) -> void:
	super._process(delta)
	if joystick_vector.length() > .2: _has_moved = true
	if _coach:
		_coach.visible = profile != "desktop" and not (_has_moved and _has_interacted)
		_coach.text = "左下拖移・右側看向・黃鍵互動" if not _has_moved else "靠近人物，再點右下黃鍵互動"

func release_all() -> void:
	# Retain canceled ownership until lift: a paused/rotated finger cannot become a camera drag.
	for index: int in _touch_owners: _canceled_fingers[index] = true
	if joystick_index >= 0: _canceled_fingers[joystick_index] = true
	super.release_all()
	_sync_pressed_feedback()

func _notification(what: int) -> void:
	# Keep this round's background release independent of the uncommitted native patch.
	if what == NOTIFICATION_APPLICATION_PAUSED: release_all()
	super._notification(what)

func _layout() -> void:
	super._layout()
	if panels.size() == 3 and profile != "desktop":
		var screen := get_viewport().get_visible_rect().size
		var margin := maxf(10,safe_insets.z)
		var bsize := maxf(44,float(settings.get("touch_button_size",54)))
		(panels[2] as GridContainer).columns = 3
		panels[2].position = Vector2(screen.x-margin-bsize*3-12,maxf(10,safe_insets.y))
		for command: Node in panels[2].get_children():
			if command is Button:
				command.visible = command.tooltip_text in ["委託","地圖","暫停"]
				command.custom_minimum_size = Vector2(bsize,bsize)
		for button: Button in _action_buttons:
			var action: String = _action_buttons[button]
			if action in ["move_forward","move_back","move_left","move_right","sprint"]: continue
			button.visible = action in ["interact","mount"] or (action in ["attack","cycle_weapon"] and _context_attack) or (action in ["jump","reset_vehicle"] and _context_mounted)
		(panels[1] as GridContainer).columns = 2
		panels[1].position = Vector2(screen.x-margin-bsize*2-6,screen.y-maxf(42,safe_insets.w+26)-bsize*(2 if _context_attack or _context_mounted else 1)-6)
		panels[1].size = Vector2.ZERO
	if _coach:
		var screen := get_viewport().get_visible_rect().size
		_coach.position = Vector2(10,screen.y-26)
		_coach.size = Vector2(screen.x-20,22)
