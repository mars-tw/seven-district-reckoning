class_name AlphaMissions
extends Node
## Deterministic first-chapter progression. World interactions supply exact event/target pairs.

signal updated
signal mission_completed(id: String)
signal chapter_completed(branch: String)

const DATA_PATH := "res://data/alpha_missions.json"
const SCORE_DEFAULTS := {"evidence_score": 0, "community_trust": 50, "rescued_count": 0, "heat_level": 0}
const BRANCHES := ["smash", "evidence", "rescue"]

var mission_index: int = 0
var current_objective: int = 0
var branch: String = ""
var scores: Dictionary = SCORE_DEFAULTS.duplicate(true)
var parts_vouchers: int = 0
var chapter_complete: bool = false
var started: bool = false
var notice: String = ""
var flags: Dictionary = {}
var missions: Array = []
var _rescue_identity: Dictionary = {}
var _progress: Dictionary = {}
var _accepted_events: Dictionary = {}
var _rewarded_missions: Dictionary = {}
var _rescued_npc_ids: Dictionary = {}
var _optional_saved: Dictionary = {}
var _destroyed_records: Dictionary = {}
var _mission_start: Dictionary = {}


func _ready() -> void:
	_load_definition()


func _load_definition() -> void:
	if not missions.is_empty():
		return
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Missing first-chapter mission data: " + DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.get("schema", 0) == 1 and parsed.get("missions", []) is Array:
		missions = parsed["missions"]
		_rescue_identity = parsed.get("rescue_identity", {}).duplicate(true)


func start_campaign() -> void:
	_load_definition()
	mission_index = 0
	current_objective = 0
	branch = ""
	scores = SCORE_DEFAULTS.duplicate(true)
	parts_vouchers = 0
	chapter_complete = false
	started = true
	notice = ""
	flags.clear()
	_progress.clear()
	_accepted_events.clear()
	_rewarded_missions.clear()
	_rescued_npc_ids.clear()
	_optional_saved.clear()
	_destroyed_records.clear()
	_capture_checkpoint()
	updated.emit()


func get_current_mission() -> Dictionary:
	_load_definition()
	if mission_index < 0 or mission_index >= missions.size():
		return {}
	return missions[mission_index].duplicate(true)


func get_current_title() -> String:
	if chapter_complete:
		return "第一章切片完成"
	var mission := get_current_mission()
	return str(mission.get("id", "")) + "　" + str(mission.get("title", "準備開始"))


func _active_objectives() -> Array:
	var mission := get_current_mission()
	var objectives: Array = mission.get("objectives", []).duplicate(true)
	if mission_index == 4 and BRANCHES.has(branch):
		objectives.append_array(mission["branches"][branch]["objectives"].duplicate(true))
		objectives.append(mission["return_objective"].duplicate(true))
	return objectives


func get_current_objective() -> Dictionary:
	if chapter_complete:
		return {}
	var objectives := _active_objectives()
	if current_objective < 0 or current_objective >= objectives.size():
		return {}
	var objective: Dictionary = objectives[current_objective].duplicate(true)
	var done: Array = _progress.get(objective["key"], [])
	var remaining: Array = []
	for target: String in objective["targets"]:
		if not done.has(target):
			remaining.append(target)
	objective["completed"] = mini(done.size(), int(objective["required"]))
	objective["remaining_targets"] = remaining
	objective["target_key"] = str(objective.get("navigation_target", remaining[0] if not remaining.is_empty() else ""))
	return objective


func get_objective_text() -> String:
	if chapter_complete:
		return "美晴車店已收到前站的消息。這是第一章切片成果，後續戰役尚未製作。"
	var objective := get_current_objective()
	var text := str(objective.get("text", ""))
	if int(objective.get("required", 1)) > 1:
		text += "（%d／%d）" % [int(objective.get("completed", 0)), int(objective["required"])]
	return text


func get_target_key() -> String:
	return str(get_current_objective().get("target_key", ""))


func handle_event(event_name: String, target_id: String) -> bool:
	if not started or chapter_complete or target_id.is_empty():
		return false
	var mission := get_current_mission()
	if mission.is_empty():
		return false
	var event_key := "%s|%s|%s" % [mission["id"], event_name, target_id]
	if _accepted_events.has(event_key) and event_name != "select_branch":
		return false
	# Penalties are unique by world identity and are rolled back with a failed attempt.
	if event_name == "street_damage" or event_name == "civilian_hit" or event_name == "enemy_sighting":
		var global_key := event_name + "|" + target_id
		if flags.has(global_key):
			return false
		flags[global_key] = true
		if event_name == "street_damage":
			scores["community_trust"] -= 2
		elif event_name == "civilian_hit":
			scores["community_trust"] -= 10
			scores["heat_level"] += 2
		else:
			scores["heat_level"] += 1
		_clamp_scores()
		updated.emit()
		return true
	if event_name == "evidence_destroyed":
		return _handle_lost_record(target_id, event_key)
	var optional: Dictionary = mission.get("optional", {})
	if event_name == optional.get("event", "") and target_id == optional.get("target", ""):
		if _destroyed_records.has(target_id):
			return false
		_optional_saved[str(mission["id"])] = true
		_accepted_events[event_key] = true
		notice = "紀錄已保存。任務完成時一併交付。"
		updated.emit()
		return true
	if event_name == "select_branch":
		return _choose_branch(target_id, event_key)
	var objective := get_current_objective()
	if objective.is_empty() or not objective["events"].has(event_name) or not objective["targets"].has(target_id):
		return false
	var event_targets: Dictionary = objective.get("event_targets", {})
	if event_targets.has(event_name) and not event_targets[event_name].has(target_id):
		return false
	if event_name == "collect_evidence" and _destroyed_records.has(target_id):
		return false
	var done: Array = _progress.get(objective["key"], []).duplicate()
	if done.has(target_id):
		return false
	done.append(target_id)
	_progress[objective["key"]] = done
	_accepted_events[event_key] = true
	if event_name == "escort_safe":
		var npc_id := str(_rescue_identity.get(target_id, target_id))
		if not _rescued_npc_ids.has(npc_id):
			_rescued_npc_ids[npc_id] = true
			scores["rescued_count"] = _rescued_npc_ids.size()
	if event_name == "destroy_target":
		scores["heat_level"] += 1
		_clamp_scores()
	notice = ""
	if event_name == objective.get("alternative_event", "") or done.size() >= int(objective["required"]):
		current_objective += 1
		if current_objective >= _active_objectives().size():
			_complete_mission()
	updated.emit()
	return true


func _choose_branch(choice: String, event_key: String) -> bool:
	if mission_index != 4 or not BRANCHES.has(choice):
		return false
	# Once actions begin, restart the checkpoint to choose another route consistently.
	if current_objective != 0:
		if current_objective != 1 or not _progress.get(get_current_objective().get("key", ""), []).is_empty():
			notice = "已開始這個解法。要換法，請在暫停選單重試目前任務。"
			updated.emit()
			return false
	if choice == "evidence" and (_destroyed_records.has("record_1") or _destroyed_records.has("record_2")):
		notice = "紀錄已損毀。選破壞或救援仍能完成任務；重試可恢復紀錄。"
		updated.emit()
		return false
	if branch == choice:
		return false
	branch = choice
	_progress["choose_branch"] = [choice]
	_accepted_events[event_key] = true
	current_objective = 1
	notice = "已選擇%s。開始行動後若要換法，請重試本任務。" % get_current_mission()["branches"][choice]["title"]
	updated.emit()
	return true


func _handle_lost_record(target_id: String, event_key: String) -> bool:
	var optional: Dictionary = get_current_mission().get("optional", {})
	var is_optional: bool = target_id == optional.get("target", "")
	var is_branch_record: bool = mission_index == 4 and ["record_1", "record_2"].has(target_id)
	if not is_optional and not is_branch_record:
		return false
	if is_optional and _optional_saved.has(get_current_mission()["id"]):
		return false
	if is_branch_record and _progress.get("save_records", []).has(target_id):
		return false
	_destroyed_records[target_id] = true
	_accepted_events[event_key] = true
	notice = "證據已損毀。通行物與其他解法仍可使用，不影響主線繼續。"
	if is_branch_record and branch == "evidence":
		branch = "smash"
		_progress["choose_branch"] = ["smash"]
		current_objective = 1
		notice = "紀錄已損毀，已改走破壞解法。也可在開始砸設備前改選救援。"
	updated.emit()
	return true


func _complete_mission() -> void:
	var mission := get_current_mission()
	var mission_id := str(mission["id"])
	if not _rewarded_missions.has(mission_id):
		var reward: Dictionary = mission["reward"].duplicate(true)
		if _optional_saved.has(mission_id):
			reward["evidence_score"] += int(mission["optional"]["evidence_score"])
		if mission_index == 4:
			var branch_reward: Dictionary = mission["branches"][branch]["reward"]
			reward["evidence_score"] += int(branch_reward["evidence_score"])
			reward["community_trust"] += int(branch_reward["community_trust"])
		for score_key: String in reward:
			scores[score_key] += int(reward[score_key])
		parts_vouchers += int(mission["parts_vouchers"])
		_rewarded_missions[mission_id] = true
	_clamp_scores()
	if mission_index == 1:
		flags["front_desk_disabled"] = true
	elif mission_index == 2:
		flags["car_unlocked"] = true
	elif mission_index == 4:
		flags["front_site_disabled"] = true
		flags["front_site_records_saved"] = branch == "evidence"
	mission_index += 1
	current_objective = 0
	_progress.clear()
	notice = "%s完成，獲得 %d 零件券。" % [mission["title"], mission["parts_vouchers"]]
	chapter_complete = mission_index >= missions.size()
	if chapter_complete:
		scores["heat_level"] = 0
	_capture_checkpoint()
	mission_completed.emit(mission_id)
	if chapter_complete:
		chapter_completed.emit(branch)


func _clamp_scores() -> void:
	scores["evidence_score"] = clampi(int(scores.get("evidence_score", 0)), 0, 100)
	scores["community_trust"] = clampi(int(scores.get("community_trust", 50)), 0, 100)
	scores["rescued_count"] = maxi(int(scores.get("rescued_count", 0)), 0)
	scores["heat_level"] = clampi(int(scores.get("heat_level", 0)), 0, 5)


func _capture_checkpoint() -> void:
	_mission_start = {"scores": scores.duplicate(true), "rescued_npc_ids": _rescued_npc_ids.duplicate(true), "flags": flags.duplicate(true), "optional_saved": _optional_saved.duplicate(true), "destroyed_records": _destroyed_records.duplicate(true)}


func restart_current() -> void:
	if chapter_complete or not started:
		return
	var road_checkpoint := current_objective if mission_index == 2 and current_objective >= 2 else 0
	scores = _mission_start.get("scores", SCORE_DEFAULTS).duplicate(true)
	_rescued_npc_ids = _mission_start.get("rescued_npc_ids", {}).duplicate(true)
	flags = _mission_start.get("flags", {}).duplicate(true)
	_optional_saved = _mission_start.get("optional_saved", {}).duplicate(true)
	_destroyed_records = _mission_start.get("destroyed_records", {}).duplicate(true)
	var prefix := str(get_current_mission()["id"]) + "|"
	if road_checkpoint == 0:
		_progress.clear()
		for key: String in _accepted_events.keys():
			if key.begins_with(prefix):
				_accepted_events.erase(key)
	else:
		var objective_key := str(get_current_objective().get("key", ""))
		_progress.erase(objective_key)
		var current_targets: Array = get_current_objective().get("targets", [])
		for key: String in _accepted_events.keys():
			for target: String in current_targets:
				if key.begins_with(prefix) and key.ends_with("|" + target):
					_accepted_events.erase(key)
	current_objective = road_checkpoint
	if mission_index == 4:
		branch = ""
	notice = "已回到任務檢查點。必要工具、任務物與受困者可重新使用。"
	updated.emit()


func to_dict() -> Dictionary:
	return {"schema": 1, "mission_index": mission_index, "current_objective": current_objective, "branch": branch, "scores": scores.duplicate(true), "parts_vouchers": parts_vouchers, "chapter_complete": chapter_complete, "started": started, "flags": flags.duplicate(true), "progress": _progress.duplicate(true), "accepted_events": _accepted_events.duplicate(true), "rewarded_missions": _rewarded_missions.duplicate(true), "rescued_npc_ids": _rescued_npc_ids.duplicate(true), "optional_saved": _optional_saved.duplicate(true), "destroyed_records": _destroyed_records.duplicate(true), "mission_start": _mission_start.duplicate(true)}


func from_dict(data: Dictionary) -> bool:
	_load_definition()
	if data.get("schema", 0) != 1 or missions.size() != 5:
		return false
	if not _is_integer(data.get("mission_index", null)) or not _is_integer(data.get("current_objective", null)) or not data.get("branch", null) is String:
		return false
	var loaded_index := int(data.get("mission_index", -1))
	var loaded_objective := int(data.get("current_objective", -1))
	var loaded_branch := str(data.get("branch", ""))
	if loaded_index < 0 or loaded_index > missions.size() or loaded_objective < 0:
		return false
	if loaded_branch != "" and not BRANCHES.has(loaded_branch):
		return false
	if loaded_index < 4 and loaded_branch != "":
		return false
	for key: String in ["scores", "flags", "progress", "accepted_events", "rewarded_missions", "rescued_npc_ids", "optional_saved", "destroyed_records", "mission_start"]:
		if not data.get(key, null) is Dictionary:
			return false
	if not _valid_scores(data["scores"]):
		return false
	if not _is_integer(data.get("parts_vouchers", null)) or int(data["parts_vouchers"]) < 0 or not data.get("started", null) is bool:
		return false
	var objective_count: int = missions[loaded_index]["objectives"].size() if loaded_index < 5 else 1
	if loaded_index == 4 and loaded_branch != "":
		objective_count += missions[4]["branches"][loaded_branch]["objectives"].size() + 1
	if loaded_objective >= objective_count or (loaded_index == 5 and (loaded_branch == "" or loaded_objective != 0)):
		return false
	var allowed_progress: Dictionary = {}
	if loaded_index < 5:
		var known_objectives: Array = missions[loaded_index]["objectives"].duplicate(true)
		if loaded_index == 4:
			for choice: String in BRANCHES:
				known_objectives.append_array(missions[4]["branches"][choice]["objectives"])
			known_objectives.append(missions[4]["return_objective"])
		for objective: Dictionary in known_objectives:
			allowed_progress[objective["key"]] = objective["targets"]
	for progress_key: Variant in data["progress"]:
		if not progress_key is String or not allowed_progress.has(progress_key):
			return false
		var value: Variant = data["progress"][progress_key]
		if not value is Array:
			return false
		var seen: Dictionary = {}
		for target: Variant in value:
			if not target is String or not allowed_progress[progress_key].has(target) or seen.has(target):
				return false
			seen[target] = true
	for npc_id: Variant in data["rescued_npc_ids"]:
		if not _rescue_identity.values().has(npc_id) or data["rescued_npc_ids"][npc_id] != true:
			return false
	if int(data["scores"]["rescued_count"]) != data["rescued_npc_ids"].size():
		return false
	for index: int in range(5):
		var mission_id := str(missions[index]["id"])
		if data["rewarded_missions"].has(mission_id) != (index < loaded_index):
			return false
	if data["rewarded_missions"].size() != loaded_index:
		return false
	for reward_value: Variant in data["rewarded_missions"].values():
		if reward_value != true:
			return false
	var checkpoint: Dictionary = data["mission_start"]
	if bool(data["started"]):
		for key: String in ["scores", "rescued_npc_ids", "flags", "optional_saved", "destroyed_records"]:
			if not checkpoint.get(key, null) is Dictionary:
				return false
		if not _valid_scores(checkpoint["scores"]):
			return false
		if int(checkpoint["scores"]["rescued_count"]) != checkpoint["rescued_npc_ids"].size():
			return false
		for npc_id: Variant in checkpoint["rescued_npc_ids"]:
			if not _rescue_identity.values().has(npc_id) or checkpoint["rescued_npc_ids"][npc_id] != true:
				return false
	# Mutate only after all structural checks pass; failed loads leave the live campaign intact.
	mission_index = loaded_index
	current_objective = loaded_objective
	branch = loaded_branch
	scores = data["scores"].duplicate(true)
	parts_vouchers = maxi(int(data.get("parts_vouchers", 0)), 0)
	chapter_complete = loaded_index == 5
	started = bool(data.get("started", true))
	flags = data["flags"].duplicate(true)
	_progress = data["progress"].duplicate(true)
	_accepted_events = data["accepted_events"].duplicate(true)
	_rewarded_missions = data["rewarded_missions"].duplicate(true)
	_rescued_npc_ids = data["rescued_npc_ids"].duplicate(true)
	_optional_saved = data["optional_saved"].duplicate(true)
	_destroyed_records = data["destroyed_records"].duplicate(true)
	_mission_start = data["mission_start"].duplicate(true)
	scores["rescued_count"] = _rescued_npc_ids.size()
	_clamp_scores()
	notice = "已讀取存檔。"
	updated.emit()
	return true


func _is_integer(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_finite(value) and value == floor(value)


func _valid_scores(state: Dictionary) -> bool:
	for key: String in SCORE_DEFAULTS:
		if not _is_integer(state.get(key, null)):
			return false
	return int(state["evidence_score"]) >= 0 and int(state["evidence_score"]) <= 100 and int(state["community_trust"]) >= 0 and int(state["community_trust"]) <= 100 and int(state["heat_level"]) >= 0 and int(state["heat_level"]) <= 5 and int(state["rescued_count"]) >= 0 and int(state["rescued_count"]) <= 4
