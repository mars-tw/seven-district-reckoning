class_name TaiwanActivities
extends Node
## The host supplies elapsed time and real player position, never a client score.
signal updated
signal notice(text: String)
signal completed(activity_id: String, outcome: Dictionary)
const DATA_PATH: String = "res://data/taiwan_activities.json"
const STATION_PATH: String = "res://data/taiwan_life.json"
var activities: Dictionary = {}
var stations: Dictionary = {}
var active_id: String = ""
var status: String = "idle"
var paused: bool = false
var elapsed: float = 0.0
var round_elapsed: float = 0.0
var round_index: int = 0
var score: int = 0
var hits: int = 0
var mistakes: int = 0
var craft_index: int = 0
var round_resolved: bool = false
var last_notice: String = ""
var last_result: Dictionary = {}
var best: Dictionary = {}
var completion_counts: Dictionary = {}
var attempts: Dictionary = {}
var badges: Array[String] = []

func _ready() -> void:
	load_definition()

func load_definition() -> bool:
	if not activities.is_empty(): return true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	var places: Variant = JSON.parse_string(FileAccess.get_file_as_string(STATION_PATH))
	if not parsed is Dictionary or not places is Dictionary: return false
	for station: Dictionary in places.get("stations",[]): stations[str(station["id"])] = station.duplicate(true)
	for row: Dictionary in parsed.get("activities",[]):
		if not stations.has(str(row.get("station_id",""))): return false
		activities[str(row["id"])] = row.duplicate(true)
		best[str(row["id"])] = 0
		completion_counts[str(row["id"])] = 0
		attempts[str(row["id"])] = 0
	return activities.size()==4

func reset() -> void:
	load_definition()
	_clear_session()
	for id: String in activities:
		best[id] = 0
		completion_counts[id] = 0
		attempts[id] = 0
	badges.clear()
	last_notice = ""
	last_result.clear()
	updated.emit()

func _clear_session() -> void:
	active_id = ""
	status = "idle"
	paused = false
	elapsed = 0
	round_elapsed = 0
	round_index = 0
	score = 0
	hits = 0
	mistakes = 0
	craft_index = 0
	round_resolved = false

func _say(text: String, accepted: bool = false) -> bool:
	last_notice = text
	notice.emit(text)
	updated.emit()
	return accepted

func _near(station_id: String, position: Vector3) -> bool:
	if not stations.has(station_id) or not position.is_finite(): return false
	var p: Array = stations[station_id]["position"]
	return Vector2(position.x,position.z).distance_to(Vector2(float(p[0]),float(p[1])))<=4.5 and absf(position.y)<=3.5

func start(id: String, position: Vector3, vehicle: String = "any") -> bool:
	load_definition()
	if status=="active": return _say("先結束目前活動，再開始下一項")
	if paused or not activities.has(id): return false
	var task: Dictionary = activities[id]
	if not _near(str(task["station_id"]),position): return _say("請先到 %s 現場開始活動" % str(stations[task["station_id"]]["title"]))
	var allowed: Array = ["any","foot","bicycle"] if task["kind"]=="walk" else ["any","foot"]
	if not vehicle in allowed: return _say("這項活動請下車步行；集章也可騎自行車")
	_clear_session()
	active_id = id
	status = "active"
	attempts[id] = int(attempts[id])+1
	last_result.clear()
	return _say(str(task["instruction"]),true)

func cancel() -> void:
	_clear_session()
	last_result.clear()
	_say("活動已停止，已取得的徽章與最佳成績保留")

func set_paused(value: bool) -> void:
	paused = value

func is_timed() -> bool:
	return status=="active" and activities.has(active_id) and activities[active_id]["kind"] in ["rhythm","alternating"]

func advance_time(delta: float) -> void:
	if paused or status!="active" or not is_finite(delta) or delta<=0 or delta>60: return
	elapsed += delta
	if not is_timed(): return
	var task: Dictionary = activities[active_id]
	var period: float = float(task["period"])
	round_elapsed += delta
	while round_elapsed>=period and status=="active":
		if not round_resolved:
			mistakes += 1
			last_notice = "這一拍沒有踏中，下一拍再試"
		round_elapsed -= period
		round_index += 1
		round_resolved = false
		if round_index>=int(task["rounds"]): _finish(hits>=int(task["pass_hits"]))
	updated.emit()

func handle_input(action: String) -> bool:
	if paused or status!="active" or not activities.has(active_id): return false
	var task: Dictionary = activities[active_id]
	if task["kind"]=="walk": return false
	if task["kind"]=="craft":
		if not action in task["options"]: return false
		var recipe: Dictionary = task["recipes"][craft_index/3]
		var expected: String = str(recipe["steps"][craft_index%3])
		if action!=expected:
			mistakes = mini(100,mistakes+1)
			return _say("材料不符，依配色卡重選；作品仍可完成")
		craft_index += 1
		round_index = craft_index/3
		score = maxi(0,100-mistakes*10)
		if craft_index==9: _finish(true)
		else: _say("材料選對了，接著選下一項",true)
		return true
	var expected: String = "tap" if task["kind"]=="rhythm" else str(task["sequence"][round_index])
	if not action in ["tap","left","right"]: return false
	if round_resolved: return _say("這拍已結束，等游標回到下一拍；連按不會得分")
	round_resolved = true
	var target: float = float(task["targets"][round_index])
	var valid: bool = action==expected and absf(round_elapsed-target)<=float(task["tolerance"])
	if valid:
		hits += 1
		score = hits*100/int(task["rounds"])
		return _say("踏中了！等下一拍",true)
	mistakes += 1
	return _say("踩錯腳，下一拍再交替" if action!=expected else "太早或太晚了，等游標進金色區間")

func visit_station(station_id: String, position: Vector3, vehicle: String = "any") -> bool:
	if paused or status!="active" or not activities.has(active_id) or activities[active_id]["kind"]!="walk": return false
	var route: Array = activities[active_id]["route"]
	if station_id!=str(route[round_index]): return _say("先到工作卡標示的下一站，重複或跳站不蓋章")
	if not vehicle in ["any","foot","bicycle"]: return _say("集章請步行或騎自行車，開車不計入")
	if not _near(station_id,position): return _say("請走到這一站 4.5 公尺內再蓋章")
	round_index += 1
	score = round_index*100/route.size()
	if round_index==route.size(): _finish(true)
	else: _say("已蓋一站，下一站："+str(stations[route[round_index]]["title"]),true)
	return true

func _finish(success: bool) -> void:
	status = "completed" if success else "failed"
	best[active_id] = maxi(int(best[active_id]),score)
	if success:
		completion_counts[active_id] = int(completion_counts[active_id])+1
		if not badges.has(active_id): badges.append(active_id)
	last_result = {"id":active_id,"success":success,"score":score,"hits":hits,"mistakes":mistakes,"elapsed":elapsed,"best":best[active_id]}
	last_notice = ("活動完成！" if success else "這次沒過關，可再練一次。")+" 成績 %d／100；最佳 %d／100" % [score,best[active_id]]
	notice.emit(last_notice)
	completed.emit(active_id,last_result.duplicate(true))
	updated.emit()

func get_active_title() -> String:
	return str(activities[active_id]["title"]) if activities.has(active_id) else ""

func get_active_text() -> String:
	return last_notice if not active_id.is_empty() else ""

func get_target_key() -> String:
	if not activities.has(active_id): return ""
	var task: Dictionary = activities[active_id]
	if task["kind"]=="walk" and status=="active": return str(task["route"][round_index])
	return str(task["station_id"])

func get_rows() -> Array[Dictionary]:
	load_definition()
	var result: Array[Dictionary] = []
	for id: String in activities:
		var row: Dictionary = activities[id].duplicate(true)
		row["best"] = best[id]
		row["completed"] = completion_counts[id]
		row["has_badge"] = badges.has(id)
		result.append(row)
	return result

func get_session() -> Dictionary:
	var result: Dictionary = {"active_id":active_id,"status":status,"paused":paused,"score":score,"hits":hits,"mistakes":mistakes,"round_index":round_index,"craft_index":craft_index,"elapsed":elapsed,"message":last_notice,"phase":0.0,"target":0.0,"tolerance":0.0,"expected":"","target_station":get_target_key()}
	if not activities.has(active_id) or status!="active": return result
	var task: Dictionary = activities[active_id]
	result["kind"] = task["kind"]
	if is_timed():
		var period: float = float(task["period"])
		result["phase"] = round_elapsed/period
		result["target"] = float(task["targets"][round_index])/period
		result["tolerance"] = float(task["tolerance"])/period
		result["expected"] = "tap" if task["kind"]=="rhythm" else task["sequence"][round_index]
	elif task["kind"]=="craft": result["expected"] = task["recipes"][craft_index/3]["steps"][craft_index%3]
	return result

func to_dict() -> Dictionary:
	load_definition()
	return {"version":1,"best":best.duplicate(true),"completion_counts":completion_counts.duplicate(true),"attempts":attempts.duplicate(true),"badges":badges.duplicate()}

func _whole(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=low and float(value)<=high

func from_dict(data: Dictionary) -> bool:
	load_definition()
	if data.size()!=5 or not _whole(data.get("version"),1,1): return false
	for key: String in ["best","completion_counts","attempts"]:
		if not data.get(key) is Dictionary or data[key].size()!=activities.size(): return false
	if not data.get("badges") is Array: return false
	var expected_badges: Array[String] = []
	for id: String in activities:
		if not _whole(data["best"].get(id),0,100) or not _whole(data["completion_counts"].get(id),0,1000000) or not _whole(data["attempts"].get(id),0,1000000): return false
		var count: int = int(data["completion_counts"][id])
		var tries: int = int(data["attempts"][id])
		var maximum: int = int(data["best"][id])
		if count>tries or (tries==0 and maximum!=0): return false
		var kind: String = str(activities[id]["kind"])
		if kind in ["rhythm","alternating"]:
			if not maximum in [0,12,25,37,50,62,75,87,100]: return false
			if (count>0)!=(maximum>=75): return false
		elif kind=="walk":
			if not maximum in [0,100] or (count>0)!=(maximum==100): return false
		elif maximum%10!=0 or (count==0 and maximum!=0): return false
		if count>0: expected_badges.append(id)
	if data["badges"].size()!=expected_badges.size(): return false
	var seen: Array[String] = []
	for badge: Variant in data["badges"]:
		if not badge is String or not expected_badges.has(badge) or seen.has(badge): return false
		seen.append(badge)
	# Atomic validation precedes mutation. Interrupted sessions are deliberately discarded.
	_clear_session()
	for id: String in activities:
		best[id] = int(data["best"][id])
		completion_counts[id] = int(data["completion_counts"][id])
		attempts[id] = int(data["attempts"][id])
	badges = seen
	last_result.clear()
	last_notice = "已讀取活動收藏；未完成的場次可在現場重新開始"
	updated.emit()
	return true
