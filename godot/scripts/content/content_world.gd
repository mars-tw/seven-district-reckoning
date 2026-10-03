class_name ContentWorld
extends Node

var world: Node3D
var manager: Node
var player: CharacterBody3D
var parking_clock: float = 0.0
var parking_target: String = ""
var created_ids: Array[String] = []

const POINTS: Dictionary = {
	"SIDE_001_sign_1": [-111, 22], "SIDE_001_sign_2": [-113, 38], "SIDE_001_sign_3": [-104, 57], "SIDE_001_mei": [-61, 58],
	"SIDE_004_letter_1": [-36, -34], "SIDE_004_letter_2": [-105, 108], "SIDE_004_letter_3": [-112, 91], "SIDE_004_yuan": [-104, 96],
	"SIDE_007_backpack": [-67, -104], "SIDE_007_water": [106, 48], "SIDE_007_safe": [-47, 45],
	"SIDE_010_part_1": [106, 39], "SIDE_010_part_2": [99, 107], "SIDE_010_part_3": [-116, 48], "SIDE_010_workbench": [-62, 55],
	"SIDE_011_meals": [-109, 31], "SIDE_011_neighbor_1": [106, 96], "SIDE_011_neighbor_2": [-121, 115], "SIDE_011_surong": [-111, 35],
	"SIDE_012_breakfast_sign": [-106, 30], "SIDE_012_aid_box": [100, 35], "SIDE_012_safe_corner": [-49, 38],
	"ACT_001_start": [-79, 64], "ACT_001_cp_1": [-77, 0], "ACT_001_cp_2": [-76, -70], "ACT_001_cp_3": [0, -76], "ACT_001_cp_4": [0, 69],
	"ACT_002_start": [77, 64], "ACT_002_cp_1": [76, 0], "ACT_002_cp_2": [76, -72], "ACT_002_cp_3": [113, -76], "ACT_002_parking": [113, 104],
	"ACT_005_photo_1": [-105, 100], "ACT_005_photo_2": [106, -53], "ACT_005_photo_3": [106, 113], "ACT_005_photo_4": [103, 31],
	"ACT_005_photo_5": [-120, 46], "ACT_005_photo_6": [-55, -98], "ACT_005_photo_7": [53, -99], "ACT_005_photo_8": [-112, 123],
	"ACT_006_start": [-105, 35], "ACT_006_drop_1": [-118, 90], "ACT_006_drop_2": [-14, -97], "ACT_006_drop_3": [111, 23]
}

func setup(host: Node3D, content: Node, actor: CharacterBody3D) -> void:
	world = host
	manager = content
	player = actor
	world._add_object("optional_board", "街坊委託板｜E", "optional_menu", "sign", Vector3(-61, 0.12, 51), Vector3(0.8, 1.2, 0.4))
	for task: Dictionary in manager.tasks:
		for objective: Dictionary in task["objectives"]:
			for id: String in objective["targets"]:
				if created_ids.has(id):
					continue
				created_ids.append(id)
				var point: Array = POINTS.get(id, [90, 28])
				var position_value := Vector3(float(point[0]), 0.12, float(point[1]))
				position_value = _safe_location(position_value)
				var kind: String = String(objective["world_kind"])
				var model_name: String = "display"
				if kind in ["sign", "photo", "bike_start", "car_start", "delivery_start"]:
					model_name = "sign"
				elif kind == "repair" or kind == "contact":
					model_name = "desk"
				elif kind in ["item", "bike_item", "delivery"]:
					model_name = "wrench" if kind == "bike_item" else "planter"
				elif kind.contains("checkpoint") or kind == "parking":
					model_name = "barrier"
				var caption: String = String(task["title"]) + "｜" + _kind_label(kind)
				world._add_object(id, caption, String(objective["event"]), model_name, position_value, Vector3(0.7, 0.8, 0.4), kind == "sign")
				if kind == "parking":
					for x: float in [-2.2, 2.2]:
						world._ground(position_value + Vector3(x, -0.04, 0), Vector3(0.09, 0.02, 7.6), Color(0.97, 0.89, 0.54), false)
					world._ground(position_value + Vector3(0, -0.04, 3.8), Vector3(4.4, 0.02, 0.09), Color(0.97, 0.89, 0.54), false)
				var object: StaticBody3D = world.objects[id]
				if kind.contains("checkpoint") or kind in ["parking", "bike_start", "car_start"]:
					object.non_solid = true
					object.collision.disabled = true
				object.text_label.font_size = 25
				object.text_label.pixel_size = 0.009
				object.text_label.modulate = Color(0.44, 0.91, 0.83) if String(task["type"]) == "side" else Color(0.99, 0.69, 0.36)
	manager.updated.connect(_highlight)
	_highlight()

func _kind_label(kind: String) -> String:
	return String({"sign":"關閉看板", "evidence":"保存信件", "item":"領取物品", "bike_item":"騎車取件", "repair":"整理修復", "contact":"交付", "photo":"記錄街景", "bike_start":"騎車出發", "car_start":"駕車出發", "bike_checkpoint":"自行車路標", "car_checkpoint":"汽車路標", "parking":"停車區", "delivery_start":"領取急送", "delivery":"送達"}.get(kind, "互動"))

func _safe_location(p: Vector3) -> Vector3:
	if not world.city_life:
		return p
	for offset: Vector3 in [Vector3.ZERO, Vector3(3, 0, 0), Vector3(-3, 0, 0), Vector3(0, 0, 3), Vector3(0, 0, -3), Vector3(6, 0, 0), Vector3(-6, 0, 0), Vector3(0, 0, 6), Vector3(0, 0, -6), Vector3(12, 0, 0), Vector3(-12, 0, 0), Vector3(0, 0, 12), Vector3(0, 0, -12), Vector3(18, 0, 0), Vector3(-18, 0, 0)]:
		var clear: bool = world.city_life.is_walkable(p + offset, 0.8)
		for bounds: AABB in world.base_obstacle_bounds:
			if bounds.grow(0.8).has_point(p + offset + Vector3.UP): clear = false
		if clear:
			return p + offset
	return p

func use_object(id: String) -> bool:
	if id == "optional_board":
		world.hud.show_optional_phone()
		return true
	if id not in created_ids:
		return false
	var objective: Dictionary = manager.get_active_objective()
	if objective.is_empty() or id not in objective.get("remaining_targets", []):
		world._notice("先在任務手機接這份委託")
		return true
	if not _vehicle_matches(objective):
		world._notice("這個目標需要指定的載具")
		return true
	if String(objective["world_kind"]).contains("checkpoint") or String(objective["world_kind"]) == "parking":
		world._notice("通過路標，或把車停在標示區內")
		return true
	accept(String(objective["event"]), id)
	return true

func accept(event: String, id: String) -> bool:
	if not manager.handle_event(event, id):
		return false
	var kind: String = String(world.objects[id].event_name)
	if kind in ["collect_item", "collect_evidence", "collect_bike_part", "collect_street_view"]:
		world.objects[id].set_collected(true)
	world._notice(manager.last_notice if not manager.last_notice.is_empty() else "已完成這個委託目標")
	world._save(false)
	return true

func prepare_task(id: String) -> void:
	var task: Dictionary = manager.get_task(id)
	for objective: Dictionary in task.get("objectives", []):
		for key: String in objective["targets"]:
			if not world.objects.has(key):
				continue
			var remains_collected: bool = id == "ACT-005" and manager.collected_points.has(key)
			world.objects[key].restore({"collected": remains_collected})
	parking_clock = 0
	_highlight()

func can_damage(id: String) -> bool:
	var objective: Dictionary = manager.get_active_objective()
	return not objective.is_empty() and id in objective.get("remaining_targets", []) and String(objective["world_kind"]) == "sign"

func step(delta: float) -> void:
	if manager.status != "active":
		parking_clock = 0
		return
	var objective: Dictionary = manager.get_active_objective()
	if objective.is_empty() or not _vehicle_matches(objective):
		parking_clock = 0
		return
	var kind: String = String(objective["world_kind"])
	if not kind.contains("checkpoint") and kind != "parking":
		return
	for id: String in objective.get("remaining_targets", []):
		var point: Vector3 = world.targets[id]
		var offset: Vector3 = player.global_position - point
		offset.y = 0
		if offset.length() > (4.0 if kind == "parking" else 6.0):
			parking_clock = 0
			continue
		if kind == "parking":
			if absf(float(world.car.speed_mps)) > 0.6:
				parking_clock = 0
				continue
			var aligned: bool = absf(world.car.global_basis.z.dot(Vector3.BACK)) >= cos(deg_to_rad(25))
			var contained: bool = aligned
			for x: float in [-1.0, 1.0]:
				for z: float in [-2.1, 2.1]:
					var corner: Vector3 = world.car.global_transform * Vector3(x, 0, z) - point
					if absf(corner.x) > 2.2 or absf(corner.z) > 3.8: contained = false
			if not contained:
				parking_clock = 0
				world._notice("把整台車對齊車格，再煞停")
				continue
			if parking_target != id:
				parking_target = id
				parking_clock = 0
			parking_clock += delta
			if parking_clock < 1.5:
				world._notice("停穩車輛，等待驗收")
				return
		accept(String(objective["event"]), id)
		return

func _vehicle_matches(objective: Dictionary) -> bool:
	var requested: String = String(objective.get("vehicle", ""))
	if requested == "bicycle":
		return player.mounted_vehicle == world.bicycle
	if requested == "car":
		return player.mounted_vehicle == world.car
	return true

func _highlight() -> void:
	var active: Array[String] = manager.get_active_target_keys()
	for id: String in created_ids:
		var object: Node3D = world.objects[id]
		object.text_label.visible = active.has(id)
		if active.has(id):
			object.text_label.modulate = Color(1.0, 0.80, 0.34)
