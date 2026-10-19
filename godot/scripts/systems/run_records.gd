class_name RunRecords
extends RefCounted
## R1 replay layer: grades a finished chapter run and keeps the best grade per
## branch. Stored apart from campaign saves; tests construct it with persist=false.

const BRANCHES := ["smash", "evidence", "rescue"]
const BRANCH_NAMES := {"smash": "破壞", "evidence": "蒐證", "rescue": "救援"}
const GRADE_ORDER := ["C", "B", "A", "S"]
const DEFAULT_PATH := "user://seven-district-records-v1.cfg"

var path: String = DEFAULT_PATH
var persist: bool = true
var best: Dictionary = {}
var best_seconds: Dictionary = {}

func _init(records_path: String = DEFAULT_PATH, should_persist: bool = true) -> void:
	path = records_path
	persist = should_persist
	if persist: load_records()

static func score(result: Dictionary) -> int:
	var evidence: float = clampf(float(result.get("evidence_score", 0)), 0, 100)
	var trust: float = clampf(float(result.get("community_trust", 50)), 0, 100)
	var rescued: int = clampi(int(result.get("rescued_count", 0)), 0, 4)
	var heat: int = clampi(int(result.get("heat_level", 0)), 0, 5)
	var seconds: float = float(result.get("seconds", 0))
	var time_bonus: int = 0
	if is_finite(seconds) and seconds > 0:
		time_bonus = 20 if seconds <= 900 else (12 if seconds <= 1500 else (6 if seconds <= 2400 else 0))
	# Smash yields little evidence/trust by design; decisive action earns parity.
	var branch_bonus: int = 6 if str(result.get("branch", "")) == "smash" else 0
	return int(round(evidence * 0.3 + trust * 0.3 + rescued * 5 + time_bonus + branch_bonus - heat * 3))

static func grade(result: Dictionary) -> String:
	var value: int = score(result)
	if value >= 58: return "S"
	if value >= 46: return "A"
	if value >= 34: return "B"
	return "C"

func record(branch: String, result: Dictionary) -> Dictionary:
	var achieved: String = grade(result)
	var previous: String = str(best.get(branch, ""))
	var improved: bool = branch in BRANCHES and (previous.is_empty() or GRADE_ORDER.find(achieved) > GRADE_ORDER.find(previous))
	if improved: best[branch] = achieved
	var seconds: float = float(result.get("seconds", 0))
	if branch in BRANCHES and is_finite(seconds) and seconds > 0 and (not best_seconds.has(branch) or seconds < float(best_seconds[branch])):
		best_seconds[branch] = seconds
	if persist and branch in BRANCHES: save_records()
	return {"grade": achieved, "score": score(result), "previous": previous, "new_best": improved}

func completed_count() -> int:
	var count: int = 0
	for branch: String in BRANCHES:
		if best.has(branch): count += 1
	return count

func next_suggestion(current: String) -> String:
	for branch: String in BRANCHES:
		if branch != current and not best.has(branch): return branch
	return ""

func progress_text(current: String) -> String:
	var marks: Array[String] = []
	for branch: String in BRANCHES:
		marks.append("%s %s" % [BRANCH_NAMES[branch], str(best.get(branch, "—"))])
	var text: String = "解法完成 %d／3｜%s" % [completed_count(), "　".join(marks)]
	var suggestion: String = next_suggestion(current)
	if not suggestion.is_empty():
		text += "\n下一局試試「%s」：同一章，完全不同的打法與結局。" % BRANCH_NAMES[suggestion]
	elif completed_count() == 3:
		text += "\n三種解法都完成了。挑戰把每一條都打到 S。"
	return text

func load_records() -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK: return
	for branch: String in BRANCHES:
		var stored: Variant = config.get_value("best", branch, "")
		if stored is String and stored in GRADE_ORDER: best[branch] = stored
		var seconds: Variant = config.get_value("seconds", branch, 0.0)
		if (seconds is float or seconds is int) and is_finite(float(seconds)) and float(seconds) > 0: best_seconds[branch] = float(seconds)

func save_records() -> void:
	var config := ConfigFile.new()
	for branch: String in best: config.set_value("best", branch, best[branch])
	for branch: String in best_seconds: config.set_value("seconds", branch, best_seconds[branch])
	config.save(path)
