extends RefCounted
# Loading is a real startup state, never a substitute for the original title/game.
const PHASES = {"first_frame": "正在準備街區", "base_world": "正在準備道路與建築", "actors": "正在準備人物與車輛", "district_life": "正在準備街坊", "content_world": "正在準備委託", "urban_detail": "正在準備街景", "contacts": "正在準備聯絡人", "expansion_terrain": "正在準備周邊地面", "bindings": "正在準備操作介面", "core_ready": "核心街區已準備好", "expansion": "正在準備周邊街區", "taiwan_world": "正在準備生活場所", "world_ready": "街區已準備好"}
const MAX_UNITS = 128
const BUDGET_US = 4000
const ACTIVE_MAX_UNITS = 32
const ACTIVE_BUDGET_US = 2000
var active := true
var complete := false
var core_released := false
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
var _last_batch_mark_us := 0
var _temporary_roots: Array[WeakRef] = []
var _owner_visibility_captured := false
var _owner_previous_visible := false
func setup(owner: Node) -> void:
	_owner = weakref(owner)
	if owner is Node3D:
		_owner_previous_visible = (owner as Node3D).visible
		_owner_visibility_captured = true
		(owner as Node3D).visible = false # CanvasLayer loading UI remains independent.
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
	var sample := {"event":event,"phase":_phase,"elapsed_ms":(Time.get_ticks_usec()-_started_us)/1000,"items":_total_units,"ready":complete}
	if DisplayServer.get_name() != "headless":
		var owner: Node = _owner.get_ref() if _owner != null else null
		var frames_drawn := Engine.get_frames_drawn()
		sample["render_frames_drawn"] = frames_drawn
		sample["draw_counter_available"] = frames_drawn >= 2
		sample["render_3d_draw_calls"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME) if frames_drawn >= 2 else null
		sample["owner_3d_visibility_suspended"] = _owner_visibility_captured
		sample["loading_layer_visible"] = is_instance_valid(_layer) and _layer.visible
		if is_instance_valid(owner) and owner is Node3D:
			sample["owner_local_visible"] = (owner as Node3D).visible
			sample["owner_visible_in_tree"] = (owner as Node3D).is_visible_in_tree()
	print("SEVEN_STARTUP "+JSON.stringify(sample))
func phase(value: String) -> void:
	if not running() or not PHASES.has(value): return
	_phase = value
	if is_instance_valid(_label): _label.text = str(PHASES[value])
	mark("phase")
func release_to_play() -> bool:
	if not running() or core_released: return false
	_restore_owner_visibility()
	core_released = true
	_phase = "core_ready"
	_tree.paused = _previous_pause
	# Hide now; queue_free can wait until the end of a slow native frame.
	if is_instance_valid(_layer): _layer.visible = false
	mark("core_ready")
	if is_instance_valid(_layer): _layer.queue_free()
	return true
func playable_frame() -> bool:
	if not running() or not core_released: return false
	if DisplayServer.get_name() == "headless":
		await _tree.process_frame
		await _tree.process_frame
	else:
		await RenderingServer.frame_post_draw
	return running()
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
	if force or Time.get_ticks_usec()-_last_batch_mark_us >= 500000:
		_last_batch_mark_us = Time.get_ticks_usec()
		mark("batch") # Native logs expose real work after phase entry, including expansion.
	var max_units := ACTIVE_MAX_UNITS if core_released else MAX_UNITS
	var budget_us := ACTIVE_BUDGET_US if core_released else BUDGET_US
	if force or _batch_units >= max_units or Time.get_ticks_usec()-_batch_started_us >= budget_us:
		if is_instance_valid(_label): _label.text = str(PHASES[_phase])
		await _tree.process_frame
		if not running(): return false
		_batch_units = 0
		_batch_started_us = Time.get_ticks_usec()
	return true
func finish() -> bool:
	if not running() or complete: return false
	_restore_owner_visibility()
	complete = true
	_phase = "world_ready"
	mark("complete")
	if is_instance_valid(_layer): _layer.queue_free()
	return true
func _restore_owner_visibility() -> void:
	if not _owner_visibility_captured: return
	_owner_visibility_captured = false # Restore once, including cancellation after a finish.
	var owner: Node = _owner.get_ref() if _owner != null else null
	if is_instance_valid(owner) and owner is Node3D:
		(owner as Node3D).visible = _owner_previous_visible
func track_temporary_root(node: Node) -> void:
	_temporary_roots.append(weakref(node))
func cancel() -> void:
	if not active: return
	active = false
	_restore_owner_visibility()
	# Parenting also frees these when an owner exits while a coroutine is dropped.
	for reference: WeakRef in _temporary_roots:
		var node: Node = reference.get_ref()
		if is_instance_valid(node): node.free()
	_temporary_roots.clear()
	if is_instance_valid(_layer): _layer.queue_free()
	if not complete and is_instance_valid(_tree): _tree.paused = _previous_pause
