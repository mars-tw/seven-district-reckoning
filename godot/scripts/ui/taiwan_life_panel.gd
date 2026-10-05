extends RefCounted
## A shared content controller with distinct phone/tablet/desktop presentation.
var hud: CanvasLayer
var life: Node
var handlers: Dictionary
var profile_name: String = "desktop"
var category: String = "story"
var page: int = 0

func setup(host: CanvasLayer, manager: Node, callbacks: Dictionary) -> void:
	hud = host
	life = manager
	handlers = callbacks

func set_profile(value: String) -> void:
	profile_name = value

func _call(key: String, args: Array = []) -> void:
	if handlers.has(key): (handlers[key] as Callable).callv(args)

func _label(value: String, size_value: int = 16, color: Color = Color("e1ebe0"), parent: Node = null) -> Label:
	var result: Label = hud._label(value,size_value,color)
	(parent if parent else hud._modal_box).add_child(result)
	return result

func _button(value: String, callback: Callable, parent: Node = null) -> Button:
	var result: Button = hud._button(value,callback,parent)
	result.custom_minimum_size.y = 52 if profile_name=="phone" else 56 if profile_name=="tablet" else 44
	return result

func show_jobs(selected: String = "story", selected_page: int = 0) -> void:
	category = selected
	page = maxi(0,selected_page)
	hud._open("life","台灣街區生活","生活金 %d｜人物故事、外送美食、便利商店採買與店到店取件" % life.cash)
	var tabs := HFlowContainer.new()
	hud._modal_box.add_child(tabs)
	for key: String in ["story","food","convenience","parcel","culture"]:
		var names: Dictionary = {"story":"人物故事","food":"外送美食","convenience":"便利商店","parcel":"取貨送貨","culture":"生活相簿"}
		var tab: Button = _button(str(names[key])+ (" ✓" if category==key else ""),func() -> void: show_jobs(key),tabs)
		tab.custom_minimum_size.x = 130 if profile_name=="phone" else 145
	var content: VBoxContainer = hud._modal_box
	var side: VBoxContainer = hud._modal_box
	if profile_name=="tablet" and hud.get_viewport().get_visible_rect().size.x>=740:
		var columns := HBoxContainer.new()
		columns.add_theme_constant_override("separation",18)
		hud._modal_box.add_child(columns)
		content = VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.custom_minimum_size.x = 310
		columns.add_child(content)
		side = VBoxContainer.new()
		side.custom_minimum_size.x = 220
		columns.add_child(side)
	elif profile_name=="desktop" and hud.get_viewport().get_visible_rect().size.x>=1200:
		var columns := HBoxContainer.new()
		columns.add_theme_constant_override("separation",24)
		hud._modal_box.add_child(columns)
		content = VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(content)
		side = VBoxContainer.new()
		side.custom_minimum_size.x = 280
		columns.add_child(side)
	_show_active(side)
	if handlers.has("activities"):
		_button("文化活動：陀螺、木屐、手作與集章",func() -> void: _call("activities"),side)
	if category=="culture":
		_show_culture(content)
	elif category=="story":
		var characters: Array = life.get_character_rows()
		var per_page: int = 2 if profile_name=="phone" else 4
		page = clampi(page,0,maxi(0,ceili(float(characters.size())/per_page)-1))
		for row: Dictionary in characters.slice(page*per_page,page*per_page+per_page):
			_label("%s｜%s｜信任 %d／100" % [row["name"],row["role"],row["trust"]],17,Color("f0c368"),content)
			var dialogue: Array = row.get("arc_dialogue",[])
			if not dialogue.is_empty(): _label(str(dialogue[mini(int(row["completed_episodes"]),dialogue.size()-1)]),14,Color("acbfc6"),content)
			for id: String in row.get("mission_ids",[]):
				var task: Dictionary = life.tasks[id]
				var done: bool = life.records.has(id)
				var title: String = str(task["title"])+(" ✓" if done else "（先完成前章與信任條件）" if not life.is_unlocked(id) else "")
				var button: Button = _button(title,func() -> void: _call("start",[id]),content)
				button.disabled = done or not life.is_unlocked(id)
		_navigation(content)
	else:
		var rows: Array = life.get_entries(category)
		var per_page: int = 3 if profile_name=="phone" else 6
		page = clampi(page,0,maxi(0,ceili(float(rows.size())/per_page)-1))
		for row: Dictionary in rows.slice(page*per_page,page*per_page+per_page):
			var task: Dictionary = life.tasks[row["id"]]
			_button(str(row["title"]),func() -> void: _call("start",[str(row["id"])]),content)
			_label(str(task.get("dialogue","")),14,Color("acbfc6"),content)
		_navigation(content)
	if category=="parcel": _label("店到店流程參考蝦皮取件與寄件服務；工作單、四碼和包裹都是遊戲資料。",13,Color("acbfc6"))
	if not str(life.last_notice).is_empty(): _label(str(life.last_notice),14,Color("f0c368"))
	_button("收起生活手機",func() -> void: _call("resume"))
	hud._focus_first_button()

func _navigation(parent: Node) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	_button("← 前頁",func() -> void: show_jobs(category,page-1),row)
	_button("下一頁 →",func() -> void: show_jobs(category,page+1),row)

func _show_active(parent: Node) -> void:
	if life.active_id.is_empty():
		_label("先接一張工作單，再前往實際街坊櫃檯。",14,Color("acbfc6"),parent)
		return
	_label(life.get_active_title(),18,Color("84c7b3"),parent)
	_label(life.get_active_text(),15,Color("e1ebe0"),parent)
	if not life.cargo.is_empty():
		var titles: Array[String] = []
		for item: String in life.cargo: titles.append(_item_title(item))
		_label("生活背包："+"、".join(titles),14,Color("acbfc6"),parent)
	var step: Dictionary = life.get_current_step()
	var target: String = str(step.get("target",""))
	if not target.is_empty(): _button("在地圖標示目前工作點",func() -> void: _call("mark",[target]),parent)
	for choice: Dictionary in life.get_choices():
		_button(str(choice["label"]),func() -> void: _call("route",[str(choice["id"])]),parent)
		_label(str(choice.get("dialogue","")),14,Color("acbfc6"),parent)
	if life.status in ["active","choosing","failed"]:
		_button("停止接單／退回未送物品",func() -> void: _call("cancel"),parent)

func _show_culture(parent: Node) -> void:
	var rows: Array = life.get_discovery_rows()
	_label("生活相簿 %d／%d 站" % [rows.size(),life.stations.size()],18,Color("f0c368"),parent)
	_label("到實際市場、綠廊、夜市或取貨站互動，會把這一站收進相簿。",14,Color("acbfc6"),parent)
	for row: Dictionary in rows:
		_label(str(row["title"]),16,Color("84c7b3"),parent)
		if row.has("culture_note"): _label(str(row["culture_note"]),14,Color("acbfc6"),parent)

func show_station(id: String) -> void:
	if not life.stations.has(id): return
	var station: Dictionary = life.stations[id]
	hud._open("life_station",str(station["title"]),"核對工作單，再從櫃檯取餐、取件或交付。")
	var npc: String = str(station.get("npc_id",""))
	if life.characters.has(npc):
		var character: Dictionary = life.characters[npc]
		_label(str(character["name"])+"｜"+str(character["role"]),18,Color("f0c368"))
		var dialogues: Array = character.get("arc_dialogue",[])
		var completed: int = 0
		for row: Dictionary in life.get_character_rows():
			if str(row["id"])==npc: completed = int(row["completed_episodes"])
		if not dialogues.is_empty(): _label(str(dialogues[mini(completed,dialogues.size()-1)]),16)
	if station.has("culture_note"): _label(str(station["culture_note"]),14,Color("acbfc6"))
	var activity_stations: Dictionary = {"green_class":"TW-ACT-TOP","arcade_temple":"TW-ACT-CLOGS","creative_workshop":"TW-ACT-CRAFT","green_notice":"TW-ACT-WALK"}
	if activity_stations.has(id) and handlers.has("activity_station"):
		_button("參加這一站的文化活動",func() -> void: _call("activity_station",[str(activity_stations[id])]))
	if not str(life.last_notice).is_empty(): _label(str(life.last_notice),14,Color("f0c368"))
	var step: Dictionary = life.get_current_step()
	if str(step.get("target",""))==id:
		_label(life.get_active_title()+"\n"+life.get_active_text(),17,Color("84c7b3"))
		var action: String = str(step.get("action",""))
		if action=="verify_code":
			_label("遊戲工作單上的四碼："+str(step.get("code","")),16)
			var entry := LineEdit.new()
			entry.name = "FictionalPickupCode"
			entry.placeholder_text = "輸入這張遊戲工作單的四碼"
			entry.max_length = 4
			entry.custom_minimum_size.y = 50
			hud._modal_box.add_child(entry)
			_button("確認取件碼",func() -> void: _call("act",[id,"",entry.text]))
		elif action=="pickup":
			var correct: String = str(step.get("item_id",""))
			var choices: Array[String] = [correct]
			for row: Dictionary in life.definition.get("items",[]):
				var candidate: String = str(row.get("id",""))
				if not candidate.is_empty() and candidate!=correct:
					choices.append(candidate)
					if choices.size()>=3: break
			choices.sort()
			for item: String in choices:
				_button("領取："+_item_title(item),func() -> void: _call("act",[id,item,""]))
		else:
			_button("交談" if action=="talk" else "交付工作單物品" if action=="deliver" else "退回物品",func() -> void: _call("act",[id,"",""]))
	else:
		_label("目前工作點在其他站，可看生活手機或記錄這一站。",15,Color("acbfc6"))
	_button("人物故事與配送工作單",func() -> void: show_jobs())
	_button("記錄這一站的生活相簿",func() -> void: _call("discover",[id]); show_station(id))
	_button("返回街上",func() -> void: _call("resume"))
	hud._focus_first_button()

func _item_title(id: String) -> String:
	for row: Dictionary in life.definition.get("items",[]):
		if str(row.get("id",""))==id: return str(row.get("title",id))
	for row: Dictionary in life.definition.get("foods",[]):
		if str(row.get("id",""))==id: return str(row.get("title",id))
	return id
