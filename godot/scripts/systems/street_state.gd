class_name StreetState
extends RefCounted

const QUALITIES: Array[String] = ["performance", "balanced", "quality"]
const DIFFICULTIES: Array[String] = ["standard", "relaxed"]
const SENSITIVITIES: Array[float] = [0.7, 1.0, 1.4]
var hour: float = 15.5
var cycle_enabled: bool = true
var quality: String = "balanced"
var difficulty: String = "standard"
var sensitivity: float = 1.0
var muted: bool = false
var waypoint: Vector2 = Vector2.ZERO
var has_waypoint: bool = false

func reset() -> void:
	hour = 15.5
	cycle_enabled = true
	quality = "performance" if OS.has_feature("web") else "balanced"
	difficulty = "standard"
	sensitivity = 1.0
	muted = false
	has_waypoint = false
	waypoint = Vector2.ZERO

func advance(delta: float) -> void:
	if cycle_enabled and is_finite(delta) and delta > 0 and delta <= 1:
		hour = fposmod(hour + delta * 0.02, 24.0)

func time_text() -> String:
	var total: int = int(hour * 60) % 1440
	return "%02d:%02d" % [total / 60, total % 60]

func daylight() -> float:
	return clampf(sin((hour - 6.0) * PI / 12.0), 0.0, 1.0)

func set_waypoint(value: Vector2) -> bool:
	if not value.is_finite() or absf(value.x) > 145 or absf(value.y) > 145:
		return false
	waypoint = value
	has_waypoint = true
	return true

func to_dict() -> Dictionary:
	return {"version":1,"hour":hour,"cycle_enabled":cycle_enabled,"quality":quality,"difficulty":difficulty,"sensitivity":sensitivity,"muted":muted,"has_waypoint":has_waypoint,"waypoint":[waypoint.x,waypoint.y]}

func from_dict(data: Dictionary) -> bool:
	if not _number(data.get("version"),1,1): return false
	if not _number(data.get("hour"),0,23.999999): return false
	if not data.get("quality") is String or not data.get("difficulty") is String: return false
	if data["quality"] not in QUALITIES or data["difficulty"] not in DIFFICULTIES: return false
	if not _number(data.get("sensitivity"),0.7,1.4): return false
	for key: String in ["cycle_enabled","muted","has_waypoint"]:
		if not data.get(key) is bool: return false
	var values: Variant = data.get("waypoint")
	if not values is Array or values.size() != 2: return false
	if not _number(values[0],-145,145) or not _number(values[1],-145,145): return false
	hour = float(data["hour"])
	cycle_enabled = data["cycle_enabled"]
	quality = data["quality"]
	difficulty = data["difficulty"]
	sensitivity = float(data["sensitivity"])
	muted = data["muted"]
	has_waypoint = data["has_waypoint"]
	waypoint = Vector2(float(values[0]),float(values[1]))
	return true

func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum
