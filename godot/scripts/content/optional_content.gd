class_name OptionalContent
extends Node
## Optional progression has its own ledger. It never mutates AlphaMissions scores.
## World code verifies proximity, vehicle type and a stopped car before sending events.

signal updated
signal notice(text: String)
signal objective_changed(target_key: String)
signal rewarded(reward: Dictionary)

const DATA_PATH := "res://data/optional_content.json"
const STATUSES := ["idle", "active", "failed", "completed"]

var tasks: Array = []
var wallet: int = 0
var scores: Dictionary = {"evidence_score": 0, "community_trust": 0}
var rescued_bonus: int = 0
var achievements: Dictionary = {}
var best_times: Dictionary = {}
var collected_points: Array = []
var active_id: String = ""
var status: String = "idle"
var objective_index: int = 0
var elapsed: float = 0.0
var timer_started: bool = false
var paused: bool = false
var last_notice: String = ""
var run_sequence: int = 0
var active_run_id: int = 0
var _progress: Dictionary = {}
var _completed_tasks: Dictionary = {}

var parts_vouchers: int:
	get:
		return wallet


func _ready() -> void:
	_load_definition()


func _load_definition() -> void:
	if not tasks.is_empty():
		return
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Missing optional-content data: " + DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.get("schema", 0) == 1 and parsed.get("tasks", null) is Array:
		tasks = parsed["tasks"].duplicate(true)


func get_task(id: String) -> Dictionary:
	_load_definition()
	for task: Dictionary in tasks:
		if task["id"] == id:
			return task.duplicate(true)
	return {}


func start_task(id: String) -> bool:
	var task := get_task(id)
	if task.is_empty():
		return false
	if status == "active":
		_announce("先完成或取消手上的委託，再選下一個。")
		return false
	if not bool(task["repeatable"]) and _completed_tasks.has(id):
		_announce("這份委託已完成，零件券也領過了。")
		return false
	active_id = id
	status = "active"
	objective_index = 0
	elapsed = 0.0
	timer_started = false
	_progress.clear()
	run_sequence += 1
	active_run_id = run_sequence
	if id == "ACT-005" and not collected_points.is_empty():
		_progress["photos"] = collected_points.duplicate()
		if collected_points.size() == 8:
			objective_index = task["objectives"].size()
			_complete_task(task)
			_notify()
			return true
	_announce(str(task["dialogue"]))
	_notify()
	return true


func cancel_task() -> void:
	_clear_active()
	_announce("委託已先放下；完成成果與街景相簿都還在。")
	_notify()


func set_paused(value: bool) -> void:
	paused = value


func handle_event(event_name: String, target_id: String) -> bool:
	if status != "active" or paused or target_id.is_empty():
		return false
	var task := get_task(active_id)
	var objective := get_active_objective()
	if objective.is_empty() or event_name != objective["event"] or not objective["targets"].has(target_id):
		return false
	var done: Array = _progress.get(objective["key"], []).duplicate()
	if done.has(target_id):
		return false
	done.append(target_id)
	_progress[objective["key"]] = done
	if active_id == "ACT-005" and not collected_points.has(target_id):
		collected_points.append(target_id)
		var point_amount: int = int(task.get("point_reward", 0))
		wallet += point_amount
		rewarded.emit({"task_id": active_id, "point_id": target_id, "parts_vouchers": point_amount, "evidence_score": 0, "community_trust": 0, "rescued_bonus": 0, "first_completion": false})
		_announce("街景已收進相簿（%d／8），獲得 %d 零件券。" % [collected_points.size(), point_amount])
	if done.size() >= int(objective["required"]):
		var completed_index := objective_index
		objective_index += 1
		if float(task.get("time_limit", 0.0)) > 0.0 and completed_index == int(task.get("timer_after_objective", -1)):
			timer_started = true
			_announce("出發！限時 %d 秒。" % int(task["time_limit"]))
		if objective_index >= task["objectives"].size():
			_complete_task(task)
	_notify()
	return true


func advance_time(delta: float) -> void:
	if status != "active" or not timer_started or paused or not is_finite(delta) or delta <= 0.0:
		return
	var task := get_task(active_id)
	var limit: float = float(task.get("time_limit", 0.0))
	if limit <= 0.0:
		return
	var previous_second: int = ceili(elapsed)
	elapsed = minf(elapsed + delta, limit)
	if elapsed >= limit:
		status = "failed"
		_announce("時間到了。這次沒有領獎；在委託板選同一個活動就能再試。")
		_notify()
	elif ceili(elapsed) != previous_second:
		updated.emit()


func _complete_task(task: Dictionary) -> void:
	status = "completed"
	var first: bool = not _completed_tasks.has(active_id)
	if first:
		_completed_tasks[active_id] = true
		var reward: Dictionary = task["reward"].duplicate(true)
		wallet += int(reward["parts_vouchers"])
		scores["evidence_score"] += int(reward["evidence_score"])
		scores["community_trust"] += int(reward["community_trust"])
		rescued_bonus += int(reward["rescued_bonus"])
		achievements[str(reward["achievement"])] = true
		reward["task_id"] = active_id
		reward["first_completion"] = true
		rewarded.emit(reward)
	var is_record: bool = float(task.get("time_limit", 0.0)) > 0.0
	var new_best: bool = is_record and (not best_times.has(active_id) or elapsed < float(best_times[active_id]))
	if new_best:
		best_times[active_id] = elapsed
	var result := str(task["completion_dialogue"])
	if first and int(task["reward"]["parts_vouchers"]) > 0:
		result += "\n獲得 %d 零件券。" % int(task["reward"]["parts_vouchers"])
	if is_record:
		result += "\n本次 %.1f 秒，最佳 %.1f 秒。" % [elapsed, float(best_times[active_id])]
		if new_best:
			result += "新紀錄！"
		if not first:
			result += "本次重玩沒有重複領獎。"
	_announce(result)


func get_active_title() -> String:
	var task := get_task(active_id)
	return "%s　%s" % [active_id, task["title"]] if not task.is_empty() else "街坊委託"


func get_active_text() -> String:
	if status == "idle":
		return "到委託板選支線或活動。主線可以同時繼續。"
	if status == "failed":
		return "時間到了。到委託板選同一個活動重試；第一次完成才領獎。"
	if status == "completed":
		return last_notice
	var objective := get_active_objective()
	var text := str(objective.get("text", ""))
	if int(objective.get("required", 1)) > 1:
		text += "（%d／%d）" % [int(objective["completed"]), int(objective["required"])]
	if timer_started:
		text += "　剩餘 %.1f 秒" % get_remaining_time()
	return text


func get_active_objective() -> Dictionary:
	var task := get_task(active_id)
	if status != "active" or task.is_empty() or objective_index >= task["objectives"].size():
		return {}
	var objective: Dictionary = task["objectives"][objective_index].duplicate(true)
	var done: Array = _progress.get(objective["key"], [])
	var remaining: Array = []
	for target: String in objective["targets"]:
		if not done.has(target):
			remaining.append(target)
	objective["completed"] = done.size()
	objective["remaining_targets"] = remaining
	objective["target_key"] = str(remaining[0]) if not remaining.is_empty() else ""
	objective["events"] = [objective["event"]]
	return objective


func get_active_target_keys() -> Array[String]:
	var targets: Array[String] = []
	targets.assign(get_active_objective().get("remaining_targets", []))
	return targets


func get_target_keys() -> Array[String]:
	return get_active_target_keys()


func get_active_status() -> String:
	return status


func get_active_time() -> float:
	return get_remaining_time()


func get_remaining_time() -> float:
	return maxf(float(get_task(active_id).get("time_limit", 0.0)) - elapsed, 0.0)


func get_status() -> Dictionary:
	return {"active_id": active_id, "status": status, "objective_index": objective_index, "timer_started": timer_started, "elapsed": elapsed, "remaining_time": get_remaining_time(), "wallet": wallet, "parts_vouchers": wallet, "scores": scores.duplicate(true), "rescued_bonus": rescued_bonus, "collected_count": collected_points.size(), "achievements": achievements.duplicate(true), "best_times": best_times.duplicate(true), "completed_tasks": _completed_tasks.keys()}


func get_menu_entries() -> Array:
	_load_definition()
	var entries: Array = []
	for task: Dictionary in tasks:
		entries.append({"id": task["id"], "type": task["type"], "title": task["title"], "summary": task["summary"], "repeatable": task["repeatable"], "completed": _completed_tasks.has(task["id"]), "active": active_id == task["id"] and status == "active", "best_time": best_times.get(task["id"], -1.0), "collected_count": collected_points.size() if task["id"] == "ACT-005" else 0, "reward_vouchers": task["reward"]["parts_vouchers"], "time_limit": task.get("time_limit", 0.0)})
	return entries


func _announce(text: String) -> void:
	last_notice = text
	notice.emit(text)


func _notify() -> void:
	var targets := get_active_target_keys()
	objective_changed.emit(str(targets[0]) if not targets.is_empty() else "")
	updated.emit()


func _clear_active() -> void:
	active_id = ""
	status = "idle"
	objective_index = 0
	elapsed = 0.0
	timer_started = false
	active_run_id = 0
	_progress.clear()


func reset() -> void:
	_clear_active()
	wallet = 0
	scores = {"evidence_score": 0, "community_trust": 0}
	rescued_bonus = 0
	achievements.clear()
	best_times.clear()
	collected_points.clear()
	_completed_tasks.clear()
	run_sequence = 0
	paused = false
	last_notice = ""
	_notify()


func to_dict() -> Dictionary:
	return {"schema": 1, "active_id": active_id, "status": status, "objective_index": objective_index, "elapsed": elapsed, "timer_started": timer_started, "run_sequence": run_sequence, "active_run_id": active_run_id, "progress": _progress.duplicate(true), "completed_tasks": _completed_tasks.duplicate(true), "best_times": best_times.duplicate(true), "collected_points": collected_points.duplicate(), "wallet": wallet, "scores": scores.duplicate(true), "rescued_bonus": rescued_bonus, "achievements": achievements.duplicate(true)}


func from_dict(data: Dictionary) -> bool:
	_load_definition()
	if not _valid_state(data):
		return false
	active_id = data["active_id"]
	status = data["status"]
	objective_index = int(data["objective_index"])
	elapsed = float(data["elapsed"])
	timer_started = data["timer_started"]
	run_sequence = int(data["run_sequence"])
	active_run_id = int(data["active_run_id"])
	_progress = data["progress"].duplicate(true)
	_completed_tasks = data["completed_tasks"].duplicate(true)
	best_times = data["best_times"].duplicate(true)
	collected_points = data["collected_points"].duplicate()
	wallet = int(data["wallet"])
	scores = {"evidence_score": int(data["scores"]["evidence_score"]), "community_trust": int(data["scores"]["community_trust"])}
	rescued_bonus = int(data["rescued_bonus"])
	achievements = data["achievements"].duplicate(true)
	last_notice = "已讀取街坊委託進度。"
	if status == "completed":
		last_notice = str(get_task(active_id)["completion_dialogue"])
	elif status == "failed":
		last_notice = "活動時間到了；到委託板選同一個活動就能重試。"
	_notify()
	return true


func _valid_state(data: Dictionary) -> bool:
	if data.get("schema", 0) != 1 or tasks.size() != 10:
		return false
	if not data.get("active_id", null) is String or not data.get("status", null) is String or not STATUSES.has(data["status"]):
		return false
	for key: String in ["objective_index", "run_sequence", "active_run_id", "wallet", "rescued_bonus"]:
		if not _is_integer(data.get(key, null)) or int(data[key]) < 0:
			return false
	if not _is_number(data.get("elapsed", null)) or float(data["elapsed"]) < 0.0 or not data.get("timer_started", null) is bool:
		return false
	for key: String in ["progress", "completed_tasks", "best_times", "scores", "achievements"]:
		if not data.get(key, null) is Dictionary:
			return false
	if not data.get("collected_points", null) is Array:
		return false
	var photos: Array = get_task("ACT-005")["objectives"][0]["targets"]
	if not _valid_unique_targets(data["collected_points"], photos):
		return false
	var expected_wallet: int = data["collected_points"].size() * int(get_task("ACT-005")["point_reward"])
	var expected_scores := {"evidence_score": 0, "community_trust": 0}
	var expected_rescued: int = 0
	var expected_achievements: Dictionary = {}
	for id: Variant in data["completed_tasks"]:
		if not id is String or data["completed_tasks"][id] != true:
			return false
		var completed := get_task(id)
		if completed.is_empty() or (id == "ACT-005" and data["collected_points"].size() != 8):
			return false
		var reward: Dictionary = completed["reward"]
		expected_wallet += int(reward["parts_vouchers"])
		expected_scores["evidence_score"] += int(reward["evidence_score"])
		expected_scores["community_trust"] += int(reward["community_trust"])
		expected_rescued += int(reward["rescued_bonus"])
		expected_achievements[str(reward["achievement"])] = true
	if data["collected_points"].size() == 8 and not data["completed_tasks"].has("ACT-005"):
		return false
	if int(data["wallet"]) != expected_wallet or int(data["rescued_bonus"]) != expected_rescued or data["achievements"] != expected_achievements:
		return false
	if data["scores"].size() != 2:
		return false
	for score: String in expected_scores:
		if not _is_integer(data["scores"].get(score, null)) or int(data["scores"][score]) != int(expected_scores[score]):
			return false
	for id: Variant in data["best_times"]:
		if not id is String or not data["completed_tasks"].has(id) or not _is_number(data["best_times"][id]):
			return false
		var recorded := get_task(id)
		var limit: float = float(recorded.get("time_limit", 0.0))
		if limit <= 0.0 or float(data["best_times"][id]) < 0.0 or float(data["best_times"][id]) >= limit:
			return false
	for task: Dictionary in tasks:
		if data["completed_tasks"].has(task["id"]) and float(task.get("time_limit", 0.0)) > 0.0 and not data["best_times"].has(task["id"]):
			return false
	if int(data["run_sequence"]) < data["completed_tasks"].size() or int(data["active_run_id"]) > int(data["run_sequence"]):
		return false
	var loaded_task := get_task(data["active_id"])
	var loaded_status: String = data["status"]
	if loaded_status == "idle":
		return data["active_id"] == "" and int(data["objective_index"]) == 0 and float(data["elapsed"]) == 0.0 and data["timer_started"] == false and int(data["active_run_id"]) == 0 and data["progress"].is_empty()
	if loaded_task.is_empty() or int(data["active_run_id"]) != int(data["run_sequence"]) or int(data["active_run_id"]) <= 0:
		return false
	var count: int = loaded_task["objectives"].size()
	var index: int = int(data["objective_index"])
	if index > count or (loaded_status == "completed") != (index == count):
		return false
	if loaded_status == "completed" and not data["completed_tasks"].has(data["active_id"]):
		return false
	if loaded_status != "completed" and not bool(loaded_task["repeatable"]) and data["completed_tasks"].has(data["active_id"]):
		return false
	var limit: float = float(loaded_task.get("time_limit", 0.0))
	var expected_timer: bool = limit > 0.0 and index > int(loaded_task.get("timer_after_objective", -1))
	if data["timer_started"] != expected_timer or (not expected_timer and float(data["elapsed"]) != 0.0):
		return false
	if float(data["elapsed"]) > limit and expected_timer:
		return false
	if loaded_status == "failed" and (not expected_timer or float(data["elapsed"]) != limit):
		return false
	if expected_timer and loaded_status != "failed" and float(data["elapsed"]) >= limit:
		return false
	if loaded_status == "completed" and expected_timer and float(data["best_times"][data["active_id"]]) > float(data["elapsed"]):
		return false
	return _valid_progress(data["progress"], loaded_task, index, data["collected_points"])


func _valid_progress(progress: Dictionary, task: Dictionary, index: int, points: Array) -> bool:
	var allowed: Dictionary = {}
	for position: int in range(task["objectives"].size()):
		var objective: Dictionary = task["objectives"][position]
		allowed[objective["key"]] = objective["targets"]
		var done: Variant = progress.get(objective["key"], [])
		if not done is Array or not _valid_unique_targets(done, objective["targets"]):
			return false
		if position < index and done.size() != int(objective["required"]):
			return false
		if position == index and done.size() >= int(objective["required"]):
			return false
		if position > index and not done.is_empty():
			return false
		if task["id"] == "ACT-005":
			if done.size() != points.size():
				return false
			for point: String in points:
				if not done.has(point):
					return false
	for key: Variant in progress:
		if not key is String or not allowed.has(key):
			return false
	return true


func _valid_unique_targets(values: Array, allowed: Array) -> bool:
	var seen: Dictionary = {}
	for value: Variant in values:
		if not value is String or not allowed.has(value) or seen.has(value):
			return false
		seen[value] = true
	return true


func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _is_integer(value: Variant) -> bool:
	return _is_number(value) and float(value) == floor(float(value))
