class_name DistrictSystems
extends Node
## Local, grant-once progression. Main and optional mission ledgers are independent.
## Only verified world callbacks may record commission completion or destruction.

signal updated
signal notice(text: String)
signal rewarded(reward: Dictionary)

const DATA_PATH := "res://data/district_systems.json"
const MAX_JOURNAL := 30
const MAX_WALK_SPEED := 10.0
const MAX_SAMPLE_DELTA := 0.25

var credits: int = 120
var xp: int = 0
var rank: int = 1
var paused: bool = false
var walking_distance: float = 0.0
var last_notice: String = ""
var _definition: Dictionary = {}
var _purchases: Dictionary = {}
var _commissions: Dictionary = {}
var _destroyed: Dictionary = {}
var _rewarded: Array = []
var _journal: Array = []
var _journal_sequence: int = 0
var _walk_sample: Vector3 = Vector3.ZERO
var _has_walk_sample: bool = false


func _ready() -> void:
	_load_definition()


func _load_definition() -> void:
	if not _definition.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary and parsed.get("schema", 0) == 1:
		_definition = parsed
	else:
		push_error("Invalid district systems definition")


func reset() -> void:
	_load_definition()
	credits = int(_definition.get("starting_credits", 120))
	xp = 0
	rank = 1
	walking_distance = 0.0
	_purchases.clear()
	_commissions.clear()
	_destroyed.clear()
	_rewarded.clear()
	_journal.clear()
	_journal_sequence = 0
	_has_walk_sample = false
	last_notice = ""
	updated.emit()


func set_paused(value: bool) -> void:
	paused = value
	# A resume, vehicle exit or respawn starts a new sample instead of adding a jump.
	_has_walk_sample = false


func reset_walk_sample() -> void:
	_has_walk_sample = false


func get_status() -> Dictionary:
	_load_definition()
	var ranks: Array = _definition.get("ranks", [])
	var rank_name: String = str(ranks[rank - 1]["name"]) if rank >= 1 and rank <= ranks.size() else ""
	return {"credits": credits, "xp": xp, "rank": rank, "rank_name": rank_name, "completed_challenges": _rewarded.size(), "max_rank": ranks.size()}


func get_stats() -> Dictionary:
	return {
		"max_stamina": 120.0 if _purchases.has("stamina") else 100.0,
		"tool_damage_multiplier": 1.2 if _purchases.has("tool_power") else 1.0,
		"bike_accel_multiplier": 1.15 if _purchases.has("vehicle_service") else 1.0
	}


func get_offers() -> Array[Dictionary]:
	_load_definition()
	var result: Array[Dictionary] = []
	for offer: Dictionary in _definition.get("offers", []):
		var row: Dictionary = offer.duplicate(true)
		var count: int = int(_purchases.get(offer["id"], 0))
		row["purchased"] = count
		row["unlocked"] = rank >= int(offer["unlock_rank"])
		row["sold_out"] = count >= int(offer["max_purchases"])
		row["affordable"] = credits >= int(offer["cost"])
		row["available"] = row["unlocked"] and not row["sold_out"] and row["affordable"]
		result.append(row)
	return result


func get_challenges() -> Array[Dictionary]:
	_load_definition()
	var result: Array[Dictionary] = []
	for challenge: Dictionary in _definition.get("challenges", []):
		var row: Dictionary = challenge.duplicate(true)
		row["progress"] = minf(_progress_for(str(row["id"])), float(row["goal"]))
		row["completed"] = _rewarded.has(row["id"])
		result.append(row)
	return result


func get_journal() -> Array:
	return _journal.duplicate(true)


func purchase(id: String, current_health: float = 100.0) -> Dictionary:
	_load_definition()
	# A shop menu pauses world activity, but an explicit purchase remains available.
	if not is_finite(current_health) or current_health < 0.0 or current_health > 100.0:
		return _purchase_error("invalid_health", "生命資料不正確，這次沒有扣款。")
	var offer := _offer(id)
	if offer.is_empty():
		return _purchase_error("unknown_item", "這項補給目前沒有販售。")
	if rank < int(offer["unlock_rank"]):
		return _purchase_error("locked", "完成街區挑戰，提升等級後就能購買。")
	if int(_purchases.get(id, 0)) >= int(offer["max_purchases"]):
		return _purchase_error("sold_out", "這項整備已完成，或補給已領完。")
	if id == "healing" and current_health >= 100.0:
		return _purchase_error("full_health", "生命已滿，不需要急救補給。")
	if credits < int(offer["cost"]):
		return _purchase_error("insufficient_credits", "補給金不夠，完成街區挑戰後再來。")
	credits -= int(offer["cost"])
	_purchases[id] = int(_purchases.get(id, 0)) + 1
	var effects: Dictionary = offer["effect"].duplicate(true)
	if id == "healing":
		effects["healing"] = minf(float(effects["healing"]), 100.0 - current_health)
		effects["health_after"] = current_health + float(effects["healing"])
	_record_journal("purchase", id, "購買「%s」，支出 %d 補給金。" % [offer["title"], offer["cost"]])
	_announce("%s已完成，剩下 %d 補給金。" % [offer["title"], credits])
	updated.emit()
	return {"ok": true, "reason": "", "id": id, "cost": int(offer["cost"]), "credits": credits, "effects": effects, "stats": get_stats()}


func _purchase_error(reason: String, message: String) -> Dictionary:
	_announce(message)
	return {"ok": false, "reason": reason, "credits": credits, "effects": {}}


func record_walk(position_value: Vector3, delta: float, on_foot: bool, grounded: bool = true) -> float:
	_load_definition()
	if paused or not on_foot or not grounded or not _valid_position(position_value) or not is_finite(delta) or delta <= 0.0 or delta > MAX_SAMPLE_DELTA:
		_has_walk_sample = false
		return 0.0
	if not _has_walk_sample:
		_walk_sample = position_value
		_has_walk_sample = true
		return 0.0
	var difference: Vector3 = position_value - _walk_sample
	_walk_sample = position_value
	var distance: float = Vector2(difference.x, difference.z).length()
	# Reject a teleport instead of clamping it into a plausible walking reward.
	if absf(difference.y) > 1.25 or distance > MAX_WALK_SPEED * delta + 0.05:
		return 0.0
	var previous: int = floori(walking_distance)
	var added: float = minf(distance, maxf(0.0, _goal("walk") - walking_distance))
	walking_distance += added
	_check_challenges()
	if floori(walking_distance) != previous:
		updated.emit()
	return added


func record_action(event_name: String, target_key: String, source_uuid: String) -> bool:
	_load_definition()
	if paused or not _valid_source(source_uuid) or _has_source(source_uuid):
		return false
	var records: Dictionary
	if event_name == "side_completed" and target_key in _definition.get("commission_targets", []):
		records = _commissions
	elif event_name == "destroy" and target_key in _definition.get("tool_targets", []):
		records = _destroyed
	else:
		return false
	if records.has(target_key):
		return false
	records[target_key] = source_uuid
	_check_challenges()
	updated.emit()
	return true


func _has_source(source_uuid: String) -> bool:
	return source_uuid in _commissions.values() or source_uuid in _destroyed.values()


func _offer(id: String) -> Dictionary:
	for offer: Dictionary in _definition.get("offers", []):
		if str(offer["id"]) == id:
			return offer
	return {}


func _goal(id: String) -> float:
	for challenge: Dictionary in _definition.get("challenges", []):
		if str(challenge["id"]) == id:
			return float(challenge["goal"])
	return 0.0


func _progress_for(id: String) -> float:
	if id == "walk":
		return walking_distance
	if id == "commissions":
		return float(_commissions.size())
	if id == "tools":
		return float(_destroyed.size())
	return 0.0


func _check_challenges() -> void:
	for challenge: Dictionary in _definition.get("challenges", []):
		var id: String = str(challenge["id"])
		if not _rewarded.has(id) and _progress_for(id) >= float(challenge["goal"]):
			_rewarded.append(id)
			credits += int(challenge["reward_credits"])
			xp += int(challenge["reward_xp"])
			rank = _rank_for(xp)
			_record_journal("reward", id, "完成「%s」，獲得 %d 補給金與 %d 經驗。" % [challenge["title"], challenge["reward_credits"], challenge["reward_xp"]])
			_announce("%s完成！獲得 %d 補給金，等級 %d。" % [challenge["title"], challenge["reward_credits"], rank])
			rewarded.emit({"id": id, "credits": int(challenge["reward_credits"]), "xp": int(challenge["reward_xp"]), "rank": rank})
			updated.emit()


func _rank_for(value: int) -> int:
	var result: int = 1
	for entry: Dictionary in _definition.get("ranks", []):
		if value >= int(entry["xp"]):
			result = int(entry["rank"])
	return result


func _record_journal(event_name: String, id: String, message: String) -> void:
	_journal_sequence += 1
	_journal.append({"sequence": _journal_sequence, "event": event_name, "id": id, "text": message, "credits": credits, "xp": xp})
	while _journal.size() > MAX_JOURNAL:
		_journal.pop_front()


func _announce(message: String) -> void:
	last_notice = message
	notice.emit(message)


func to_dict() -> Dictionary:
	return {"schema": 1, "credits": credits, "xp": xp, "rank": rank, "walking_distance": walking_distance, "purchases": _purchases.duplicate(true), "commissions": _commissions.duplicate(true), "destroyed": _destroyed.duplicate(true), "rewarded": _rewarded.duplicate(), "journal": _journal.duplicate(true), "journal_sequence": _journal_sequence}


func from_dict(data: Dictionary) -> bool:
	_load_definition()
	if not _valid_state(data):
		return false
	credits = int(data["credits"])
	xp = int(data["xp"])
	rank = int(data["rank"])
	walking_distance = float(data["walking_distance"])
	_purchases = data["purchases"].duplicate(true)
	for id: String in _purchases:
		_purchases[id] = int(_purchases[id])
	_commissions = data["commissions"].duplicate(true)
	_destroyed = data["destroyed"].duplicate(true)
	_rewarded = data["rewarded"].duplicate()
	_journal = data["journal"].duplicate(true)
	for entry: Dictionary in _journal:
		for key: String in ["sequence", "credits", "xp"]:
			entry[key] = int(entry[key])
	_journal_sequence = int(data["journal_sequence"])
	_has_walk_sample = false
	last_notice = ""
	updated.emit()
	return true


func _valid_state(data: Dictionary) -> bool:
	if not _whole(data.get("schema"), 1, 1) or _definition.is_empty():
		return false
	if not _whole(data.get("credits"), 0, 430) or not _whole(data.get("xp"), 0, 280) or not _whole(data.get("rank"), 1, 4):
		return false
	if not _number(data.get("walking_distance"), 0.0, _goal("walk")):
		return false
	for key: String in ["purchases", "commissions", "destroyed"]:
		if not data.get(key) is Dictionary:
			return false
	var sources: Array = []
	if not _valid_records(data["commissions"], _definition["commission_targets"], sources) or not _valid_records(data["destroyed"], _definition["tool_targets"], sources):
		return false
	if not data.get("rewarded") is Array or data["rewarded"].size() > 3:
		return false
	var expected_rewards: Array = []
	var expected_xp: int = 0
	var expected_credits: int = int(_definition["starting_credits"])
	for challenge: Dictionary in _definition["challenges"]:
		var progress: float = float(data["walking_distance"])
		if challenge["id"] == "commissions":
			progress = float(data["commissions"].size())
		elif challenge["id"] == "tools":
			progress = float(data["destroyed"].size())
		if progress >= float(challenge["goal"]):
			expected_rewards.append(challenge["id"])
			expected_xp += int(challenge["reward_xp"])
			expected_credits += int(challenge["reward_credits"])
	var observed: Array = []
	for reward_id: Variant in data["rewarded"]:
		if not reward_id is String or reward_id not in expected_rewards or reward_id in observed:
			return false
		observed.append(reward_id)
	if observed.size() != expected_rewards.size() or int(data["xp"]) != expected_xp or int(data["rank"]) != _rank_for(expected_xp):
		return false
	var purchase_count: int = 0
	for id: Variant in data["purchases"]:
		if not id is String:
			return false
		var offer: Dictionary = _offer(id)
		var count: Variant = data["purchases"][id]
		if offer.is_empty() or not _whole(count, 1, int(offer["max_purchases"])) or int(data["rank"]) < int(offer["unlock_rank"]):
			return false
		expected_credits -= int(count) * int(offer["cost"])
		purchase_count += int(count)
	if int(data["credits"]) != expected_credits or expected_credits < 0:
		return false
	return _valid_journal(data, purchase_count + expected_rewards.size())


func _valid_records(records: Dictionary, allowed: Array, sources: Array) -> bool:
	if records.size() > allowed.size():
		return false
	for id: Variant in records:
		if not id is String or id not in allowed or not records[id] is String or not _valid_source(records[id]) or records[id] in sources:
			return false
		sources.append(records[id])
	return true


func _valid_journal(data: Dictionary, count: int) -> bool:
	if not data.get("journal") is Array or not _whole(data.get("journal_sequence"), 0, 18) or int(data["journal_sequence"]) != count:
		return false
	var entries: Array = data["journal"]
	if entries.size() != mini(count, MAX_JOURNAL):
		return false
	var previous: int = maxi(0, count - MAX_JOURNAL)
	var purchase_tally: Dictionary = {}
	var reward_tally: Array = []
	var seen_credits: int = int(_definition["starting_credits"])
	var seen_xp: int = 0
	for entry: Variant in entries:
		if not entry is Dictionary or not _whole(entry.get("sequence"), previous + 1, previous + 1) or not _whole(entry.get("credits"), 0, 430) or not _whole(entry.get("xp"), 0, 280) or not entry.get("text") is String or entry["text"].length() > 300:
			return false
		previous += 1
		var event_name: Variant = entry.get("event")
		var id: Variant = entry.get("id")
		if not id is String:
			return false
		if event_name == "purchase":
			var offer: Dictionary = _offer(id)
			if offer.is_empty() or _rank_for(seen_xp) < int(offer["unlock_rank"]):
				return false
			purchase_tally[id] = int(purchase_tally.get(id, 0)) + 1
			seen_credits -= int(offer["cost"])
			if entry["text"] != "購買「%s」，支出 %d 補給金。" % [offer["title"], offer["cost"]]:
				return false
		elif event_name == "reward":
			var found: bool = false
			for challenge: Dictionary in _definition["challenges"]:
				if challenge["id"] == id:
					if id in reward_tally or id not in data["rewarded"]:
						return false
					found = true
					reward_tally.append(id)
					seen_credits += int(challenge["reward_credits"])
					seen_xp += int(challenge["reward_xp"])
					if entry["text"] != "完成「%s」，獲得 %d 補給金與 %d 經驗。" % [challenge["title"], challenge["reward_credits"], challenge["reward_xp"]]:
						return false
			if not found:
				return false
		else:
			return false
		if int(entry["credits"]) != seen_credits or int(entry["xp"]) != seen_xp or seen_credits < 0:
			return false
	if purchase_tally.size() != data["purchases"].size():
		return false
	for id: String in purchase_tally:
		if not data["purchases"].has(id) or int(data["purchases"][id]) != int(purchase_tally[id]):
			return false
	return reward_tally == data["rewarded"] and seen_credits == int(data["credits"]) and seen_xp == int(data["xp"])


func _valid_source(value: String) -> bool:
	if value.is_empty() or value.length() > 96:
		return false
	for index: int in value.length():
		var character: int = value.unicode_at(index)
		if not ((character >= 48 and character <= 57) or (character >= 65 and character <= 90) or (character >= 97 and character <= 122) or character in [45, 46, 58, 95]):
			return false
	return true


func _valid_position(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z) and absf(value.x) <= 200.0 and absf(value.y) <= 50.0 and absf(value.z) <= 200.0


func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum


func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, float(minimum), float(maximum)) and float(value) == floor(float(value))
