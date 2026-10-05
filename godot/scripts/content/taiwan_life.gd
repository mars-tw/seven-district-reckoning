class_name TaiwanLife
extends Node
## Local fictional work orders and character stories. There are no real accounts or payments.
signal updated
signal notice(text: String)
signal completed(task_id: String, outcome: Dictionary)
const DATA_PATH: String = "res://data/taiwan_life.json"
const ACTIONS: Array[String] = ["talk","pickup","verify_code","deliver","return"]
const STATUSES: Array[String] = ["idle","active","choosing","failed","returning","completed"]
var definition: Dictionary = {}
var tasks: Dictionary = {}
var stations: Dictionary = {}
var characters: Dictionary = {}
var active_id: String = ""
var route_id: String = ""
var step_index: int = 0
var status: String = "idle"
var elapsed: float = 0.0
var paused: bool = false
var cargo: Array[String] = []
var cargo_origins: Dictionary = {}
var clock: float = 0.0
var cooldowns: Dictionary = {}
var discovered_stations: Array[String] = []
var return_station: String = ""
var cash: int = 0
var trust: Dictionary = {}
var records: Dictionary = {}
var last_notice: String = ""
var last_result: Dictionary = {}

func _ready() -> void:
	load_definition()

func load_definition() -> bool:
	if not definition.is_empty(): return true
	if not FileAccess.file_exists(DATA_PATH): return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary or not _whole(parsed.get("schema_version"),1,1): return false
	definition = parsed
	for row: Dictionary in definition.get("stations",[]): stations[str(row["id"])] = row.duplicate(true)
	for row: Dictionary in definition.get("characters",[]): characters[str(row["id"])] = row.duplicate(true)
	for collection: String in ["missions","delivery_templates"]:
		for row: Dictionary in definition.get(collection,[]):
			var task: Dictionary = row.duplicate(true)
			task["repeatable"] = collection=="delivery_templates"
			tasks[str(task["id"])] = task
	return not tasks.is_empty() and not stations.is_empty()

func reset() -> void:
	load_definition()
	active_id = ""
	route_id = ""
	step_index = 0
	status = "idle"
	elapsed = 0
	cargo.clear()
	cargo_origins.clear()
	cooldowns.clear()
	discovered_stations.clear()
	clock = 0
	return_station = ""
	cash = 0
	trust.clear()
	records.clear()
	last_result.clear()
	last_notice = ""
	updated.emit()

func set_paused(value: bool) -> void:
	paused = value

func is_unlocked(id: String) -> bool:
	load_definition()
	if not tasks.has(id): return false
	for prerequisite: String in tasks[id].get("prerequisites",[]):
		if _task_count(prerequisite)==0: return false
	var required: Dictionary = tasks[id].get("required_trust",{})
	if not required.is_empty() and int(trust.get(str(required.get("npc_id","")),0))<int(required.get("min",0)): return false
	return true

func start_task(id: String) -> bool:
	load_definition()
	if not tasks.has(id) or not is_unlocked(id): return _reject("先完成這位街坊前一段的交代")
	if status in ["active","choosing","returning"] or not cargo.is_empty(): return _reject("先完成或退回目前攜帶的工作物品")
	if not bool(tasks[id]["repeatable"]) and _task_count(id)>0: return _reject("這段人物故事已完成，可接其他委託或重玩配送工作")
	if float(cooldowns.get(id,0))>clock: return _reject("這張配送單還在整理，%d 秒後可再接；可先做其他工作" % ceili(float(cooldowns[id])-clock))
	active_id = id
	route_id = ""
	step_index = 0
	elapsed = 0
	return_station = ""
	status = "active"
	last_result.clear()
	last_notice = str(tasks[id].get("dialogue",""))
	notice.emit(last_notice)
	updated.emit()
	return true

func get_choices() -> Array:
	if not tasks.has(active_id) or status!="choosing": return []
	return tasks[active_id].get("choices",[]).duplicate(true)

func choose_route(id: String) -> bool:
	if status!="choosing": return false
	for option: Dictionary in tasks[active_id].get("choices",[]):
		if str(option["id"])==id:
			route_id = id
			status = "active"
			_announce(str(option.get("dialogue","已選擇這次工作路線")))
			updated.emit()
			return true
	return _reject("請選擇工作單上的路線")

func _route(task: Dictionary, selected: String) -> Dictionary:
	if selected.is_empty(): return {}
	for row: Dictionary in task.get("choices",[]):
		if str(row["id"])==selected: return row
	return {}

func _steps(task: Dictionary, selected: String) -> Array:
	var result: Array = task.get("steps",[]).duplicate(true)
	if not selected.is_empty(): result.append_array(_route(task,selected).get("steps",[]))
	return result

func get_current_step() -> Dictionary:
	if status=="returning": return {"action":"return","target":return_station,"caption":"將未交付物品退回原取貨站","required_vehicle":"any"}
	if not tasks.has(active_id) or status not in ["active","choosing"]: return {}
	if status=="choosing": return {"action":"choice","caption":"先在生活手機選擇工作路線","target":""}
	var sequence: Array = _steps(tasks[active_id],route_id)
	return sequence[step_index].duplicate(true) if step_index<sequence.size() else {}

func get_active_title() -> String:
	return str(tasks.get(active_id,{}).get("title","台灣街區生活"))

func get_active_text() -> String:
	var step: Dictionary = get_current_step()
	if step.is_empty(): return last_notice if status=="failed" else "接街坊故事，或做美食、便利商店與店到店配送"
	var text_value: String = str(step.get("caption",""))
	var limit: float = float(tasks.get(active_id,{}).get("limit_seconds",0))
	if status=="active" and limit>0: text_value += "｜剩餘 %d 秒" % ceili(maxf(0,limit-elapsed))
	return text_value

func get_target_key() -> String:
	return str(get_current_step().get("target",""))

func get_entries(category: String = "all") -> Array:
	load_definition()
	var result: Array = []
	for id: String in tasks:
		var task: Dictionary = tasks[id]
		var kind: String = str(task.get("category","story"))
		if category!="all" and category!=kind: continue
		result.append({"id":id,"title":task["title"],"category":kind,"npc_id":task.get("npc_id",""),"unlocked":is_unlocked(id),"completed":_task_count(id)>0,"repeatable":task["repeatable"],"reward":task.get("reward",{}),"active":active_id==id and status in ["active","choosing","returning"]})
	return result

func get_character_rows() -> Array:
	load_definition()
	var rows: Array = []
	for id: String in characters:
		var row: Dictionary = characters[id].duplicate(true)
		row["trust"] = int(trust.get(id,0))
		row["completed_episodes"] = 0
		for task_id: String in row.get("mission_ids",[]):
			if _task_count(task_id)>0: row["completed_episodes"] += 1
		rows.append(row)
	return rows

func can_interact(target: String, position_value: Vector3) -> bool:
	if not stations.has(target) or not position_value.is_finite(): return false
	var p: Array = stations[target]["position"]
	return Vector2(position_value.x,position_value.z).distance_to(Vector2(float(p[0]),float(p[1])))<=4.5

func discover_station(target: String, position_value: Vector3) -> bool:
	if not can_interact(target,position_value) or discovered_stations.has(target): return false
	discovered_stations.append(target)
	_announce("生活相簿已記錄："+str(stations[target]["title"]))
	updated.emit()
	return true

func get_discovery_rows() -> Array:
	var rows: Array = []
	for id: String in discovered_stations:
		rows.append(stations[id].duplicate(true))
	return rows

func handle_action(action: String, target: String, vehicle: String, position_value: Vector3, item: String = "", code: String = "") -> bool:
	if paused or status not in ["active","returning"]: return false
	var step: Dictionary = get_current_step()
	if action!=str(step.get("action","")) or target!=str(step.get("target","")): return _reject("這裡不是目前工作單的交付點")
	if not can_interact(target,position_value): return _reject("請靠近實際櫃檯或收件人再操作")
	var required: String = str(step.get("required_vehicle","any"))
	if required!="any" and vehicle!=required: return _reject("這張工作單需要"+("自行車" if required=="bicycle" else "汽車"))
	if status=="returning":
		for pending: String in cargo.duplicate():
			if str(cargo_origins.get(pending,""))==target:
				cargo.erase(pending)
				cargo_origins.erase(pending)
		return_station = str(cargo_origins.get(cargo[0],"")) if not cargo.is_empty() else ""
		if cargo.is_empty():
			status = "idle"
			active_id = ""
			route_id = ""
			step_index = 0
			elapsed = 0
			_announce("未交付物品已退回，可以接新工作")
		else:
			_announce("這站的物品已退回；其他物品還需退到各自取貨站")
		updated.emit()
		return true
	var item_id: String = str(step.get("item_id",""))
	if action=="verify_code" and code!=str(step.get("code","")): return _reject("取件碼不符；請核對遊戲工作單上的四碼，未取出任何包裹")
	if action=="pickup":
		if item!=item_id: return _reject("物品不符；請選工作單指定的餐點或包裹")
		if cargo.has(item_id): return _reject("這件物品已放進生活背包")
		cargo.append(item_id)
		cargo_origins[item_id] = target
		return_station = str(cargo_origins[cargo[0]])
	elif action in ["deliver","return"]:
		if not item.is_empty() and item!=item_id: return _reject("選擇的物品不符合收件工作單")
		if not cargo.has(item_id): return _reject("生活背包裡沒有這次要交付的物品")
		cargo.erase(item_id)
		cargo_origins.erase(item_id)
		return_station = str(cargo_origins.get(cargo[0],"")) if not cargo.is_empty() else ""
	step_index += 1
	var task: Dictionary = tasks[active_id]
	if route_id.is_empty() and task.has("choices") and not task["choices"].is_empty() and step_index>=task.get("steps",[]).size():
		status = "choosing"
		_announce("街坊想知道你的做法，請從生活手機選擇路線")
	elif step_index>=_steps(task,route_id).size():
		_finish()
	else:
		_announce(get_active_text())
	updated.emit()
	return true

func cancel_task() -> void:
	if status not in ["active","choosing","failed"]: return
	if not cargo.is_empty():
		status = "returning"
		_announce("已停止接單，請先將背包物品退回原取貨站")
	else:
		active_id = ""
		route_id = ""
		step_index = 0
		elapsed = 0
		return_station = ""
		status = "idle"
		_announce("已放下這張工作單")
	updated.emit()

func advance_time(delta: float) -> void:
	if paused or not _number(delta,0,1): return
	clock += delta
	for id: String in cooldowns.keys():
		if float(cooldowns[id])<=clock: cooldowns.erase(id)
	if status not in ["active","choosing"]: return
	elapsed += delta
	var limit: float = float(tasks[active_id].get("limit_seconds",0))
	if limit>0 and elapsed>limit:
		status = "failed"
		_announce(str(tasks[active_id].get("failure_dialogue","超過工作時限，未完成的物品仍需退回")))
		updated.emit()

func _reward(task: Dictionary, selected: String) -> Dictionary:
	var option: Dictionary = _route(task,selected)
	return option.get("reward",task.get("reward",{"cash":0,"trust":0})).duplicate(true)

func _finish() -> void:
	var task: Dictionary = tasks[active_id]
	if not cargo.is_empty():
		status = "returning"
		_announce("還有物品未交付，先退回再結清")
		return
	var selected: String = route_id if not route_id.is_empty() else "default"
	var task_records: Dictionary = records.get(active_id,{})
	if not task["repeatable"] and _task_count(active_id)>0:
		status = "completed"
		return
	task_records[selected] = int(task_records.get(selected,0)) + 1
	records[active_id] = task_records
	var reward: Dictionary = _reward(task,route_id)
	cash += int(reward.get("cash",0))
	var npc: String = str(task.get("npc_id",""))
	if not npc.is_empty(): trust[npc] = mini(100,int(trust.get(npc,0))+int(reward.get("trust",0)))
	status = "completed"
	if task["repeatable"]: cooldowns[active_id] = clock+float(task.get("cooldown_seconds",0))
	last_result = {"task_id":active_id,"route_id":selected,"cash":int(reward.get("cash",0)),"trust":int(reward.get("trust",0)),"elapsed":elapsed,"repeatable":task["repeatable"]}
	_announce(str(task.get("completion_dialogue","工作單已交付"))+"｜獲得 %d 生活金" % int(reward.get("cash",0)))
	completed.emit(active_id,last_result.duplicate(true))

func _task_count(id: String) -> int:
	var count: int = 0
	for value: Variant in records.get(id,{}).values(): count += int(value)
	return count

func _announce(value: String) -> void:
	last_notice = value
	notice.emit(value)

func _reject(value: String) -> bool:
	_announce(value)
	return false

func to_dict() -> Dictionary:
	return {"version":1,"active_id":active_id,"route_id":route_id,"step_index":step_index,"status":status,"elapsed":elapsed,"clock":clock,"cooldowns":cooldowns.duplicate(true),"cargo":cargo.duplicate(),"cargo_origins":cargo_origins.duplicate(true),"return_station":return_station,"cash":cash,"trust":trust.duplicate(true),"records":records.duplicate(true),"discovered_stations":discovered_stations.duplicate()}

func from_dict(data: Dictionary) -> bool:
	if not load_definition() or not _valid_state(data): return false
	active_id = data["active_id"]
	route_id = data["route_id"]
	step_index = int(data["step_index"])
	status = data["status"]
	elapsed = float(data["elapsed"])
	cargo.clear()
	for item: String in data["cargo"]: cargo.append(item)
	cargo_origins = data["cargo_origins"].duplicate(true)
	clock = float(data["clock"])
	cooldowns = data["cooldowns"].duplicate(true)
	discovered_stations.clear()
	for station: String in data["discovered_stations"]: discovered_stations.append(station)
	return_station = data["return_station"]
	cash = int(data["cash"])
	trust.clear()
	for npc: String in data["trust"]: trust[npc] = int(data["trust"][npc])
	records.clear()
	for id: String in data["records"]:
		var normalized: Dictionary = {}
		for selected: String in data["records"][id]: normalized[selected] = int(data["records"][id][selected])
		records[id] = normalized
	last_notice = ""
	last_result.clear()
	updated.emit()
	return true

func _valid_state(data: Dictionary) -> bool:
	if not _whole(data.get("version"),1,1): return false
	for key: String in ["active_id","route_id","status","return_station"]:
		if not data.get(key) is String: return false
	if data["status"] not in STATUSES or not _number(data.get("elapsed"),0,10000000) or not _whole(data.get("step_index"),0,100): return false
	if not data.get("records") is Dictionary or not data.get("trust") is Dictionary or not data.get("cargo") is Array or not _whole(data.get("cash"),0,100000000): return false
	if not data.get("cargo_origins") is Dictionary or not data.get("cooldowns") is Dictionary or not _number(data.get("clock"),0,10000000): return false
	if not data.get("discovered_stations") is Array: return false
	var seen_stations: Dictionary = {}
	for station: Variant in data["discovered_stations"]:
		if not station is String or not stations.has(station) or seen_stations.has(station): return false
		seen_stations[station] = true
	var computed_cash: int = 0
	var computed_trust: Dictionary = {}
	var raw_trust: Dictionary = {}
	for id: Variant in data["records"]:
		if not id is String or not tasks.has(id) or not data["records"][id] is Dictionary: return false
		var counts: Dictionary = data["records"][id]
		var task: Dictionary = tasks[id]
		var total: int = 0
		for selected: Variant in counts:
			if not selected is String or not _whole(counts[selected],1,10000): return false
			if selected!="default" and _route(task,selected).is_empty(): return false
			if selected=="default" and not task.get("choices",[]).is_empty(): return false
			var reward: Dictionary = _reward(task,"" if selected=="default" else selected)
			total += int(counts[selected])
			computed_cash += int(counts[selected])*int(reward.get("cash",0))
			var npc: String = str(task.get("npc_id",""))
			if not npc.is_empty():
				raw_trust[npc] = int(raw_trust.get(npc,0))+int(counts[selected])*int(reward.get("trust",0))
				computed_trust[npc] = mini(100,int(raw_trust[npc]))
		if total<1 or (not task["repeatable"] and total>1): return false
		for prerequisite: String in task.get("prerequisites",[]):
			if not data["records"].has(prerequisite): return false
	if int(data["cash"])!=computed_cash or data["trust"].size()!=computed_trust.size(): return false
	for npc: Variant in data["trust"]:
		if not npc is String or not computed_trust.has(npc) or not _whole(data["trust"][npc],0,100) or int(data["trust"][npc])!=int(computed_trust[npc]): return false
	for completed_id: String in data["records"]:
		var rule: Dictionary = tasks[completed_id].get("required_trust",{})
		if rule.is_empty(): continue
		var npc: String = str(rule.get("npc_id",""))
		var own_trust: int = 0
		if str(tasks[completed_id].get("npc_id",""))==npc:
			for route_key: String in data["records"][completed_id]:
				own_trust += int(data["records"][completed_id][route_key])*int(_reward(tasks[completed_id],"" if route_key=="default" else route_key).get("trust",0))
		if mini(100,int(raw_trust.get(npc,0))-own_trust)<int(rule.get("min",0)): return false
	for id: Variant in data["cooldowns"]:
		if not id is String or not tasks.has(id) or not tasks[id]["repeatable"] or not data["records"].has(id) or not _number(data["cooldowns"][id],0,float(data["clock"])+float(tasks[id].get("cooldown_seconds",0))): return false
	var id: String = data["active_id"]
	var selected: String = data["route_id"]
	var state_status: String = data["status"]
	if id.is_empty(): return state_status=="idle" and selected.is_empty() and int(data["step_index"])==0 and data["cargo"].is_empty() and data["cargo_origins"].is_empty() and data["return_station"].is_empty()
	if not tasks.has(id) or state_status=="idle": return false
	var task: Dictionary = tasks[id]
	for prerequisite: String in task.get("prerequisites",[]):
		if not data["records"].has(prerequisite): return false
	var trust_rule: Dictionary = task.get("required_trust",{})
	if state_status!="completed" and not trust_rule.is_empty() and int(computed_trust.get(str(trust_rule.get("npc_id","")),0))<int(trust_rule.get("min",0)): return false
	if not selected.is_empty() and _route(task,selected).is_empty(): return false
	var sequence: Array = _steps(task,selected)
	var index: int = int(data["step_index"])
	if index>sequence.size(): return false
	if not selected.is_empty() and index<task.get("steps",[]).size(): return false
	var pending: Array[String] = []
	var pending_origins: Dictionary = {}
	var origin: String = ""
	for step: Dictionary in sequence.slice(0,index):
		var item: String = str(step.get("item_id",""))
		if str(step["action"])=="pickup":
			if pending.has(item): return false
			pending.append(item)
			pending_origins[item] = str(step["target"])
			origin = str(pending_origins[pending[0]])
		elif str(step["action"]) in ["deliver","return"]:
			if not pending.has(item): return false
			pending.erase(item)
			pending_origins.erase(item)
			origin = str(pending_origins[pending[0]]) if not pending.is_empty() else ""
	for item: Variant in data["cargo"]:
		if not item is String: return false
	if state_status=="returning":
		var origins_in_order: Array[String] = []
		for pending_item: String in pending:
			var pickup_origin: String = str(pending_origins[pending_item])
			if not origins_in_order.has(pickup_origin): origins_in_order.append(pickup_origin)
		var found_remaining: bool = false
		for pickup_origin: String in origins_in_order:
			var group_count: int = 0
			var remaining_count: int = 0
			for pending_item: String in pending:
				if str(pending_origins[pending_item])==pickup_origin:
					group_count += 1
					if data["cargo"].has(pending_item): remaining_count += 1
			if remaining_count!=0 and remaining_count!=group_count: return false
			if remaining_count==0 and found_remaining: return false
			if remaining_count>0: found_remaining = true
		for returned: String in pending.duplicate():
			if not data["cargo"].has(returned):
				pending.erase(returned)
				pending_origins.erase(returned)
		origin = str(pending_origins[pending[0]]) if not pending.is_empty() else ""
	if data["cargo"]!=pending or data["cargo_origins"]!=pending_origins: return false
	if data["return_station"]!=origin: return false
	if state_status=="choosing": return selected.is_empty() and not task.get("choices",[]).is_empty() and index==task.get("steps",[]).size()
	if state_status=="returning": return not pending.is_empty() and stations.has(origin)
	if state_status=="completed": return index==sequence.size() and pending.is_empty() and data["records"].has(id) and data["records"][id].has(selected if not selected.is_empty() else "default")
	if state_status=="active" and index>=sequence.size(): return false
	if state_status=="failed":
		var limit: float = float(task.get("limit_seconds",0))
		if limit<=0 or float(data["elapsed"])<=limit: return false
	if state_status in ["active","choosing"] and not task["repeatable"] and data["records"].has(id): return false
	return true

func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high

func _whole(value: Variant, low: int, high: int) -> bool:
	return _number(value,low,high) and float(value)==floorf(float(value))
