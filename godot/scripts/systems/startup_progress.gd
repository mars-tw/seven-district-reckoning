extends RefCounted
# Loading is a real startup state, never a substitute for the original title/game.
const PHASES = {"first_frame": "正在準備街區", "base_world": "正在準備道路與建築", "actors": "正在準備人物與車輛", "district_life": "正在準備街坊", "content_world": "正在準備委託", "urban_detail": "正在準備街景", "contacts": "正在準備聯絡人", "expansion": "正在準備周邊街區", "taiwan_world": "正在準備生活場所", "bindings": "正在準備操作介面", "world_ready": "街區已準備好"}
const MAX_UNITS = 128
const BUDGET_US = 4000
var active := true
var complete := false
var first_frame_drawn := false
var _owner: WeakRef
var _tree: SceneTree
var _previous_pause := false
var _layer: CanvasLayer
var _label: Label
var _phase := "first_frame"
var _started_us := 0
var _batch_started_us := 0
var _batch_units := 0
var _total_units := 0
var _temporary_roots: Array[WeakRef] = []
func setup(owner: Node) -> void:
	_owner = weakref(owner)
	_tree = owner.get_tree()
	_previous_pause = _tree.paused
	_tree.paused = true
	_started_us = Time.get_ticks_usec()
	_batch_started_us = _started_us
	_layer = CanvasLayer.new()
	_layer.layer = 1000
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	owner.add_child(_layer)
	var panel := ColorRect.new()
	panel.color = Color("182b33")
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(panel)
	_label = Label.new()
	mark("font_load_begin")
	_label.add_theme_font_override("font", load("res://assets/fonts/NotoSansTC-Regular.otf") as Font)
	mark("font_load_end")
	_label.text = PHASES[_phase]
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.add_theme_font_size_override("font_size", 28)
	panel.add_child(_label)
	mark("begin")
func running() -> bool:
	var owner: Node = _owner.get_ref() if _owner != null else null
	return active and is_instance_valid(owner) and owner.is_inside_tree()
func mark(event: String) -> void:
	# Only static phases, monotonic elapsed time, counts and readiness.
	print("SEVEN_STARTUP "+JSON.stringify({"event":event,"phase":_phase,"elapsed_ms":(Time.get_ticks_usec()-_started_us)/1000,"items":_total_units,"ready":complete}))
func phase(value: String) -> void:
	if not running() or not PHASES.has(value): return
	_phase = value
	_label.text = str(PHASES[value])
	mark("phase")
func first_frame() -> bool:
	if not running(): return false
	mark("first_frame_wait")
	if DisplayServer.get_name() == "headless":
		await _tree.process_frame
		await _tree.process_frame
		mark("first_frame_headless_not_rendered")
	else:
		await RenderingServer.frame_post_draw
		if not running(): return false
		first_frame_drawn = true
		mark("first_frame_drawn")
	return running()
func checkpoint(units: int = 1, force: bool = false) -> bool:
	if not running(): return false
	if complete: return true
	_batch_units += units
	_total_units += units
	if _phase == "base_world": mark("phase")
	if force or _batch_units >= MAX_UNITS or Time.get_ticks_usec()-_batch_started_us >= BUDGET_US:
		_label.text = str(PHASES[_phase])
		await _tree.process_frame
		if not running(): return false
		_batch_units = 0
		_batch_started_us = Time.get_ticks_usec()
	return true
func finish() -> bool:
	if not running() or complete: return false
	complete = true
	_phase = "world_ready"
	mark("complete")
	_layer.queue_free()
	return true
func track_temporary_root(node: Node) -> void:
	_temporary_roots.append(weakref(node))
func cancel() -> void:
	if not active: return
	active = false
	# Parenting also frees these when an owner exits while a coroutine is dropped.
	for reference: WeakRef in _temporary_roots:
		var node: Node = reference.get_ref()
		if is_instance_valid(node): node.free()
	_temporary_roots.clear()
	if is_instance_valid(_layer): _layer.queue_free()
	if not complete and is_instance_valid(_tree): _tree.paused = _previous_pause
