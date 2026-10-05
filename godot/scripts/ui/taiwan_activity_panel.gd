extends RefCounted
## Actual buttons and keyboard events. Scores are calculated only by the manager.
var hud: CanvasLayer
var manager: Node
var callbacks: Dictionary = {}
var shown_id: String = ""
var info: Label
var feedback: Label
var gauge: Control
var rendered_status: String = ""
var rebuild_scheduled: bool = false
const NAMES: Dictionary = {"tap":"轉動","left":"左腳","right":"右腳","red":"紅色","blue":"藍色","white":"白色","flower":"花朵","stripes":"條紋","dots":"圓點"}

class RhythmGauge extends Control:
	var phase: float = 0
	var target: float = .5
	var tolerance: float = .15
	func _draw() -> void:
		var y: float = size.y*.5-12
		draw_style_box(_background(),Rect2(0,y,size.x,24))
		draw_rect(Rect2(maxf(0,target-tolerance)*size.x,y,2*tolerance*size.x,24),Color("c19d52"))
		draw_line(Vector2(phase*size.x,y-10),Vector2(phase*size.x,y+34),Color("dbeee7"),4)
	func _background() -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("203b44")
		return box

class ActivityKeys extends Control:
	var owner_panel: RefCounted
	func _input(event: InputEvent) -> void:
		if not owner_panel or not owner_panel.hud or owner_panel.hud._mode!="culture_activity": return
		if not event is InputEventKey or not event.pressed or event.echo: return
		var state: Dictionary = owner_panel.manager.get_session()
		if state.get("status")!="active": return
		var action: String = ""
		if event.keycode==KEY_SPACE and state.get("kind")=="rhythm": action = "tap"
		elif event.keycode==KEY_LEFT and state.get("kind")=="alternating": action = "left"
		elif event.keycode==KEY_RIGHT and state.get("kind")=="alternating": action = "right"
		if not action.is_empty():
			owner_panel._call("input",[action])
			get_viewport().set_input_as_handled()

func setup(host: CanvasLayer, activity_manager: Node, handlers: Dictionary) -> void:
	hud = host
	manager = activity_manager
	callbacks = handlers.duplicate()
	if not manager.updated.is_connected(refresh): manager.updated.connect(refresh)

func _call(key: String, args: Array = []) -> void:
	if callbacks.has(key): (callbacks[key] as Callable).callv(args)

func _label(text: String, font_size: int = 16) -> Label:
	var result: Label = hud._label(text,font_size,Color("ddebe0"))
	hud._modal_box.add_child(result)
	return result

func _button(text: String, callable: Callable, parent: Node = null) -> Button:
	var button: Button = hud._button(text,callable,parent)
	button.custom_minimum_size.y = 56
	return button

func show_directory() -> void:
	shown_id = ""
	hud._open("culture_directory","街坊文化活動","到指定站點現場開始；只有徽章和最佳成績，沒有現金獎勵。")
	for row: Dictionary in manager.get_rows():
		_label(str(row["title"])+"｜最佳 %d／100｜完成 %d 次" % [row["best"],row["completed"]],18)
		_label("地點："+str(manager.stations[row["station_id"]]["title"])+("｜徽章："+str(row["badge"]) if row["has_badge"] else ""),14)
		_button("查看「"+str(row["title"])+"」",func() -> void: show_activity(str(row["id"])))
		_button("在地圖標示此活動",func() -> void: _call("mark",[str(row["station_id"])]))
	_button("回到生活工作單",func() -> void: _call("close"))
	_button("回街上",func() -> void: _call("resume"))
	hud._focus_first_button()

func show_activity(id: String) -> void:
	if not manager.activities.has(id): return
	shown_id = id
	rendered_status = manager.status if manager.active_id==id else "preview"
	var task: Dictionary = manager.activities[id]
	var active: bool = manager.active_id==id and manager.status=="active"
	hud._open("culture_activity",str(task["title"]),"" if active else str(task["instruction"]))
	if active:
		# The gameplay controls precede all explanatory text, including on short phones.
		(hud._modal_box.get_child(0) as Label).add_theme_font_size_override("font_size",22)
		(hud._modal_box.get_child(1) as Label).hide()
	info = null
	feedback = null
	gauge = null
	if active:
		var keys := ActivityKeys.new()
		keys.owner_panel = self
		keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
		keys.process_mode = Node.PROCESS_MODE_ALWAYS
		keys.hide()
		hud._modal_box.add_child(keys)
		if task["kind"] in ["rhythm","alternating"]:
			var primary := HBoxContainer.new()
			primary.add_theme_constant_override("separation",12)
			hud._modal_box.add_child(primary)
			gauge = RhythmGauge.new()
			gauge.custom_minimum_size = Vector2(0,72)
			gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gauge.size_flags_vertical = Control.SIZE_FILL
			primary.add_child(gauge)
			var actions := VBoxContainer.new()
			actions.custom_minimum_size.x = 138
			actions.add_theme_constant_override("separation",6)
			primary.add_child(actions)
			for action: String in (["tap"] if task["kind"]=="rhythm" else ["left","right"]):
				_button(str(NAMES[action])+ ("（空白鍵）" if action=="tap" else "（方向鍵）"),func() -> void: _call("input",[action]),actions)
			info = _label("",16)
		elif task["kind"]=="craft":
			info = _label("",15)
			var actions := HFlowContainer.new()
			hud._modal_box.add_child(actions)
			for action: String in task["options"]:
				_button(str(NAMES[action]),func() -> void: _call("input",[action]),actions)
		else:
			info = _label("",16)
			_button("標示下一個集章站",func() -> void: _call("mark",[manager.get_target_key()]))
			_button("在現場蓋這一站",func() -> void: _call("visit",[manager.get_target_key()]))
			_button("回街上前往下一站",func() -> void: _call("resume"))
		feedback = _label(manager.last_notice,14)
		_button("停止這次活動",func() -> void: _call("cancel"))
		_label(str(task["instruction"]),14)
		_label("活動地點："+str(manager.stations[task["station_id"]]["title"])+"｜最佳 %d／100" % manager.best[id],14)
	else:
		_label("活動地點："+str(manager.stations[task["station_id"]]["title"])+"｜最佳 %d／100" % manager.best[id],15)
		info = _label("",18)
		feedback = _label(manager.last_notice,15)
		_button("在現場開始／重玩",func() -> void: _call("start",[id]))
		_button("在地圖標示活動地點",func() -> void: _call("mark",[str(task["station_id"])]))
	_button("活動目錄",func() -> void: show_directory())
	_button("回街上",func() -> void: _call("resume"))
	refresh()
	hud._focus_first_button()

func _translated(items: Array) -> PackedStringArray:
	var result := PackedStringArray()
	for item: String in items: result.append(str(NAMES.get(item,item)))
	return result

func refresh() -> void:
	if not hud or hud._mode!="culture_activity" or not is_instance_valid(info): return
	var state: Dictionary = manager.get_session()
	# A final result changes the controls once; frame ticks only update the gauge.
	if rendered_status=="active" and state["status"] in ["completed","failed","idle"] and not rebuild_scheduled:
		rebuild_scheduled = true
		call_deferred("_refresh_result_controls",shown_id)
	if manager.active_id==shown_id and state["status"]=="active":
		if state.get("kind")=="craft":
			var recipe: Dictionary = manager.activities[shown_id]["recipes"][int(state["craft_index"])/3]
			info.text = "作品 %d／3：%s｜成績 %d／100\n%s｜下一項：%s" % [mini(3,int(state["craft_index"])/3+1),recipe["title"],state["score"]," → ".join(_translated(recipe["steps"])),NAMES.get(state["expected"],"")]
		elif state.get("kind")=="walk": info.text = "集章 %d／4｜下一站：%s" % [state["round_index"],manager.stations[state["target_station"]]["title"]]
		else: info.text = "第 %d／8 拍｜下一拍：%s｜命中 %d" % [state["round_index"]+1,NAMES.get(state["expected"],""),state["hits"]]
	else: info.text = "最佳 %d／100｜完成 %d 次" % [manager.best[shown_id],manager.completion_counts[shown_id]]
	feedback.text = str(state["message"])
	if is_instance_valid(gauge):
		gauge.phase = float(state["phase"])
		gauge.target = float(state["target"])
		gauge.tolerance = float(state["tolerance"])
		gauge.queue_redraw()

func _refresh_result_controls(id: String) -> void:
	rebuild_scheduled = false
	if hud and hud._mode=="culture_activity" and shown_id==id and manager.status in ["completed","failed","idle"]:
		show_activity(id)
