class_name DistrictLife
extends Node3D

## The existing mission streets remain the authority for the central district.
## This module adds a bounded perimeter and uses the shipped GLBs for its art.
const DATA_PATH: String = "res://data/district_life.json"
const MODEL_DIR: String = "res://assets/models/"
const MAX_CITIZENS: int = 8
const MAX_TRAFFIC: int = 4
const THINK_INTERVAL: float = 0.20

static var _scenes: Dictionary = {}
static var _bounds_cache: Dictionary = {}
static var _font: Font = null

var player: Node3D = null
var clock: float = 0.0
var citizens: Array[Dictionary] = []
var traffic: Array[Dictionary] = []
var _districts: Array[Dictionary] = []
var _obstacles: Array[AABB] = []
var _asset_counts: Dictionary = {}
var _signals: Array[Dictionary] = []
var _materials: Dictionary = {}
var _built: bool = false
var _think_clock: float = 0.0
var _last_attack_position: Vector3 = Vector3(INF, 0, INF)
var _alarm_until: float = 0.0
var _player_callback: Callable
var _missing_assets: Array[String] = []
var _citizen_probe: CapsuleShape3D = null

static func bootstrap(parent: Node3D) -> DistrictLife:
	var existing: Node = parent.get_node_or_null("DistrictLife")
	if existing is DistrictLife:
		return existing as DistrictLife
	var life := DistrictLife.new()
	life.name = "DistrictLife"
	parent.add_child(life)
	life.setup()
	return life

func setup(optional_player: Node3D = null) -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if is_instance_valid(player) and player.has_signal("attacked") and _player_callback.is_valid() and player.is_connected("attacked", _player_callback):
		player.disconnect("attacked", _player_callback)
	player = optional_player
	_player_callback = Callable(self, "_on_player_attack")
	if is_instance_valid(player) and player.has_signal("attacked"):
		player.connect("attacked", _player_callback)
	if _built:
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not data is Dictionary:
		push_error("DistrictLife: district data could not be read")
		return
	for entry: Dictionary in data.get("districts", []):
		_districts.append(entry.duplicate(true))
	if ResourceLoader.exists("res://assets/fonts/SevenDistrictSansTC-Regular.otf") and _font == null:
		_font = load("res://assets/fonts/SevenDistrictSansTC-Regular.otf") as Font
	_citizen_probe = CapsuleShape3D.new()
	_citizen_probe.radius = 0.28
	_citizen_probe.height = 1.5
	_create_streets()
	for building: Dictionary in data.get("buildings", []):
		_create_building(building)
	_create_district_details()
	_create_citizens()
	_create_traffic(data.get("traffic_loop", []))
	_built = true
	add_to_group("district_life")

func get_districts() -> Array[Dictionary]:
	return _districts.duplicate(true)

func get_counts() -> Dictionary:
	return {"districts": _districts.size(), "citizens": citizens.size(), "moving_vehicles": traffic.size(), "assets": _asset_counts.duplicate(), "obstacles": _obstacles.size(), "signals": _signals.size(), "cached_scenes": _scenes.size(), "missing_assets": _missing_assets.duplicate()}

func get_status() -> Dictionary:
	var fleeing: int = 0
	var stopped: int = 0
	for citizen: Dictionary in citizens:
		if float(citizen["flee_until"]) > clock:
			fleeing += 1
	for vehicle: Dictionary in traffic:
		if bool(vehicle["stopped"]):
			stopped += 1
	return {"clock": clock, "fleeing_citizens": fleeing, "stopped_traffic": stopped, "signal_phase": int(clock / 12.0) % 2, "palette": "fixed_day"}

func get_obstacle_bounds() -> Array[AABB]:
	return _obstacles.duplicate()

func to_dict() -> Dictionary:
	# Ambient actors are deterministic and restart on their routes on load.
	return {"version": 1, "clock": clock}

func from_dict(state: Dictionary) -> bool:
	var value: Variant = state.get("clock", 0.0)
	if not value is float and not value is int:
		return false
	var restored_clock: float = float(value)
	if not is_finite(restored_clock) or restored_clock < 0.0 or restored_clock > 100000000.0:
		return false
	clock = restored_clock
	_alarm_until = 0.0
	for citizen: Dictionary in citizens:
		citizen["flee_until"] = 0.0
		citizen["observed_alarm"] = 0.0
	return true

func is_walkable(p: Vector3, radius: float = 0.45) -> bool:
	if not p.is_finite() or absf(p.x) > 143.0 or absf(p.z) > 143.0:
		return false
	for bounds: AABB in _obstacles:
		if bounds.grow(radius).has_point(Vector3(p.x, bounds.position.y + 0.5, p.z)):
			return false
	return true

func _scene(key: String) -> PackedScene:
	if not _scenes.has(key):
		var path: String = MODEL_DIR + key + ".glb"
		if not ResourceLoader.exists(path):
			if not _missing_assets.has(key):
				_missing_assets.append(key)
			return null
		_scenes[key] = load(path) as PackedScene
	return _scenes[key] as PackedScene

func _place(key: String, p: Vector3, yaw: float = 0.0, scale_value: Vector3 = Vector3.ONE, range_end: float = 160.0) -> Node3D:
	var packed: PackedScene = _scene(key)
	if packed == null:
		return null
	var model: Node3D = packed.instantiate() as Node3D
	model.name = key.capitalize().replace(" ", "")
	model.position = p
	model.rotation.y = yaw
	model.scale = scale_value
	add_child(model)
	_set_render_range(model, range_end)
	_asset_counts[key] = int(_asset_counts.get(key, 0)) + 1
	return model

func _set_render_range(node: Node, range_end: float) -> void:
	if node is GeometryInstance3D:
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		geometry.visibility_range_end = range_end
		geometry.visibility_range_end_margin = 12.0
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children():
		_set_render_range(child, range_end)

func _visual_bounds(model: Node3D) -> AABB:
	var result: AABB = AABB()
	var found: bool = false
	var queue: Array[Node] = [model]
	while not queue.is_empty():
		var node: Node = queue.pop_back()
		if node is MeshInstance3D:
			var mesh_node: MeshInstance3D = node as MeshInstance3D
			if mesh_node.mesh != null:
				var local: AABB = model.global_transform.affine_inverse() * mesh_node.global_transform * mesh_node.get_aabb()
				result = local if not found else result.merge(local)
				found = true
		queue.append_array(node.get_children())
	return result

func _create_building(spec: Dictionary) -> void:
	var p: Vector3 = _v3(spec["position"])
	var size_value: Vector3 = _v3(spec["size"])
	var key: String = str(spec["asset"])
	var model: Node3D = _place(key, p, 0.0, Vector3.ONE, 280.0)
	if model == null:
		return
	if not _bounds_cache.has(key):
		_bounds_cache[key] = _visual_bounds(model)
	var bounds: AABB = _bounds_cache[key]
	model.scale = size_value / bounds.size
	# Ground and centre the imported geometry, including its existing awning.
	model.position = p - Vector3(bounds.get_center().x * model.scale.x, bounds.position.y * model.scale.y, bounds.get_center().z * model.scale.z)
	var body := StaticBody3D.new()
	body.name = "DistrictBuildingCollider"
	body.collision_layer = 1
	body.collision_mask = 2
	body.position = p + Vector3(0, size_value.y * 0.5, 0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	_obstacles.append(AABB(p - Vector3(size_value.x * 0.5, 0, size_value.z * 0.5), size_value))
	_sign(str(spec["caption"]), p + Vector3(0, minf(4.0, size_value.y - 1.0), size_value.z * 0.5 + 0.25), Color(str(spec["color"])), 0.0, 6.0)

func _material(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.95
		_materials[key] = material
	return _materials[key] as StandardMaterial3D

func _surface(p: Vector3, size_value: Vector3, color: Color) -> void:
	# Only pavement/paint uses primitive geometry; no actors or buildings do.
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_node.mesh = mesh
	mesh_node.material_override = _material(color)
	mesh_node.position = p
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_node.visibility_range_end = 220.0
	add_child(mesh_node)

func _road_segment(a: Vector3, b: Vector3, width: float = 10.0) -> void:
	var length_value: float = a.distance_to(b)
	var direction: Vector3 = (b - a).normalized()
	var yaw: float = atan2(direction.x, direction.z)
	var count: int = int(ceil(length_value / 12.0))
	for index: int in count:
		var tile_length: float = minf(12.0, length_value - float(index) * 12.0)
		var p: Vector3 = a + direction * (float(index) * 12.0 + tile_length * 0.5)
		p.y = 0.047
		_place("road_straight", p, yaw, Vector3(width / 12.0, 0.08, tile_length / 12.0), 210.0)

func _create_streets() -> void:
	var corners: Array[Vector3] = [Vector3(-137, 0, -137), Vector3(137, 0, -137), Vector3(137, 0, 137), Vector3(-137, 0, 137)]
	for index: int in 4:
		_road_segment(corners[index], corners[(index + 1) % 4])
	for side: float in [-1.0, 1.0]:
		# Connect original +/-76m streets to the perimeter without blocking them.
		_road_segment(Vector3(side * 80, 0, 76), Vector3(side * 137, 0, 76), 10.0)
		_road_segment(Vector3(side * 76, 0, 80), Vector3(side * 76, 0, 137), 10.0)
		_surface(Vector3(side * 129, 0.055, 0), Vector3(4, 0.06, 258), Color("b5b2a3"))
		_surface(Vector3(0, 0.055, side * 129), Vector3(254, 0.06, 4), Color("b5b2a3"))
		for distance_value: float in [-114.0, -76.0, -38.0, 0.0, 38.0, 76.0, 114.0]:
			_place("streetlight", Vector3(side * 130, 0.08, distance_value), -side * PI * 0.5)
			_place("streetlight", Vector3(distance_value, 0.08, side * 130), 0 if side < 0 else PI)
	for index: int in 4:
		var p: Vector3 = corners[index] * (129.0 / 137.0)
		_place("road_crossing", corners[index] + Vector3(0, 0.052, 0), float(index) * PI * 0.5, Vector3(0.83, 0.08, 0.83), 210.0)
		_place("traffic_light", p, float(index) * PI * 0.5)
		var lamp := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.16
		sphere.height = 0.32
		lamp.mesh = sphere
		lamp.position = p + Vector3(0, 3.25, 0)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lamp)
		_signals.append({"lamp": lamp, "axis": index % 2})

func _create_district_details() -> void:
	for district: Dictionary in _districts:
		var p: Vector3 = _v2(district["marker"])
		var color: Color = Color(str(district["color"]))
		_sign(str(district["name"]) + "\n" + str(district["subtitle"]), p + Vector3(0, 3.0, 0), color, 0.0, 5.2)
	# Old street has small storefronts, outdoor desks and a clear walking strip.
	_surface(Vector3(-102.5, 0.06, 40), Vector3(12, 0.06, 56), Color("bfa88e"))
	for z: float in [23.0, 46.0, 64.0]:
		_place("bench", Vector3(-111, 0.10, z), PI * 0.5)
		_place("planter", Vector3(-112, 0.10, z - 4))
	_place("desk", Vector3(-112, 0.10, 18))
	_place("display", Vector3(-112, 0.94, 18))
	_place("bicycle", Vector3(-112, 0.08, 56), PI * 0.5)
	# Office courts connect to the original roads; existing towers stay in place.
	_surface(Vector3(108, 0.06, -70), Vector3(30, 0.06, 39), Color("afb6b7"))
	for p: Vector3 in [Vector3(98, 0.08, -90), Vector3(115, 0.08, -85), Vector3(117, 0.08, -54)]:
		_place("planter", p, 0, Vector3(1.7, 1.4, 1.7))
		_place("bench", p + Vector3(0, 0, 3), PI * 0.5)
	# Park paths are level with the existing terrain, so every entrance is open.
	_surface(Vector3(-110, 0.045, 108), Vector3(45, 0.035, 42), Color("739760"))
	_surface(Vector3(-110, 0.072, 91), Vector3(32, 0.025, 4), Color("cbc2a5"))
	_surface(Vector3(-110, 0.072, 115), Vector3(32, 0.025, 4), Color("cbc2a5"))
	_surface(Vector3(-100, 0.072, 103), Vector3(4, 0.025, 28), Color("cbc2a5"))
	_surface(Vector3(-121, 0.072, 103), Vector3(4, 0.025, 28), Color("cbc2a5"))
	_surface(Vector3(-115.5, 0.072, 103.5), Vector3(12, 0.025, 4), Color("cbc2a5"))
	for x: float in [-128.0, -117.0, -94.0]:
		for z: float in [86.0, 123.0]:
			_tree(Vector3(x, 0.08, z), 1.1 if x == -117 else 1.35)
	for z: float in [100.0, 111.0]:
		_tree(Vector3(-128, 0.08, z), 1.2)
		_tree(Vector3(-93, 0.08, z), 1.2)
	for p: Vector3 in [Vector3(-126, 0.10, 96), Vector3(-95, 0.10, 106), Vector3(-111, 0.10, 120)]:
		_place("bench", p, PI * 0.5)
	# Parking layout and a GLB tower make the southeast district recognisable.
	_surface(Vector3(104, 0.045, 113), Vector3(36, 0.035, 38), Color("657078"))
	for x: float in [92.0, 100.0, 108.0]:
		for z: float in [124.0, 129.0]:
			_surface(Vector3(x + 3, 0.074, z), Vector3(0.10, 0.02, 4.2), Color("e0d6b3"))
			_place("car", Vector3(x, 0.08, z), PI * 0.5, Vector3.ONE, 130.0)
	_sign("Ｐ\n南苑停車場", Vector3(117, 5.2, 112), Color("597f8a"), 0, 3.0)
	# Forecourt rests south of the old northern towers, with access from MAIN003.
	_surface(Vector3(-1, 0.06, -93), Vector3(142, 0.06, 13), Color("a7b4c0"))
	for x: float in [-65.0, -24.0, 24.0, 65.0]:
		_place("bench", Vector3(x, 0.10, -87))
		_place("planter", Vector3(x, 0.10, -99))
	_sign("七期前站\n北側入口", Vector3(-39, 4.5, -115), Color("91a7bc"), 0, 7.0)
	# A protected waiting strip stands apart from the existing sandbox targets.
	_surface(Vector3(103, 0.06, 35), Vector3(15, 0.06, 47), Color("b8aa98"))
	for z: float in [17.0, 39.0, 58.0]:
		_place("bench", Vector3(109, 0.10, z), -PI * 0.5)
		_place("planter", Vector3(109, 0.10, z - 3))
	_sign("東園轉運站\n１、２號候車處", Vector3(110, 3.0, 55), Color("b99b81"), -PI * 0.5, 4.0)

func _tree(p: Vector3, scale_value: float) -> void:
	_place("tree", p, 0, Vector3.ONE * scale_value)
	var body := StaticBody3D.new()
	body.name = "ParkTreeTrunk"
	body.position = p + Vector3(0, 1.0, 0)
	body.collision_layer = 1
	body.collision_mask = 2
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.35 * scale_value
	shape.height = 2.0
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	var radius: float = shape.radius
	_obstacles.append(AABB(p - Vector3(radius, 0, radius), Vector3(radius * 2, 2, radius * 2)))

func _sign(caption: String, p: Vector3, color: Color, yaw: float, width: float) -> void:
	var label := Label3D.new()
	label.text = caption
	label.position = p
	label.rotation.y = yaw
	label.font = _font
	label.font_size = 36
	label.pixel_size = 0.012
	label.modulate = Color("f4f1e5")
	label.outline_modulate = Color("25343c")
	label.outline_size = 5
	label.no_depth_test = false
	label.visibility_range_end = 115.0
	label.visibility_range_end_margin = 8.0
	add_child(label)
	var panel := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width, 1.65 if caption.contains("\n") else 1.1)
	panel.mesh = mesh
	panel.material_override = _material(color.darkened(0.40))
	panel.position = p - Vector3(sin(yaw), 0, cos(yaw)) * 0.035
	panel.rotation.y = yaw
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.visibility_range_end = 120.0
	add_child(panel)

func _create_citizens() -> void:
	for index: int in MAX_CITIZENS:
		var district: Dictionary = _districts[index % _districts.size()]
		var route: Array[Vector3] = []
		for point: Array in district["walk_loop"]:
			route.append(_v2(point) + Vector3(0, 0.10, 0))
		var start_index: int = 2 if index >= _districts.size() else 0
		var body := CharacterBody3D.new()
		body.name = "Citizen_%02d" % index
		body.collision_layer = 2
		body.collision_mask = 1
		body.floor_snap_length = 0.3
		body.position = route[start_index]
		var collision := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.28
		shape.height = 1.72
		collision.shape = shape
		collision.position.y = 0.86
		body.add_child(collision)
		add_child(body)
		body.add_to_group("ambient_citizens")
		var model: Node3D = _place("civilian", Vector3.ZERO, 0, Vector3.ONE, 110.0)
		if model == null:
			body.queue_free()
			continue
		model.reparent(body, false)
		var animation: AnimationPlayer = _find_animation(model)
		var animation_names: Dictionary = _animation_names(animation)
		if animation != null and animation_names.has("walk"):
			animation.get_animation(animation_names["walk"]).loop_mode = Animation.LOOP_LINEAR
			if animation_names.has("run"):
				animation.get_animation(animation_names["run"]).loop_mode = Animation.LOOP_LINEAR
			animation.play(animation_names["walk"])
			animation.advance(float(index) * 0.075)
		citizens.append({"body": body, "model": model, "animation": animation, "clips": animation_names, "route": route, "waypoint": (start_index + 1) % route.size(), "step": 1, "observed_alarm": 0.0, "speed": 1.15 + float(index % 3) * 0.13, "direction": Vector3.ZERO, "flee_until": 0.0, "stuck_time": 0.0, "previous": body.position, "district": district["id"]})

func _create_traffic(points: Array) -> void:
	var route: Array[Vector3] = []
	for point: Array in points:
		route.append(_v2(point) + Vector3(0, 0.08, 0))
	for index: int in MAX_TRAFFIC:
		var model: Node3D = _place("car", route[index].lerp(route[(index + 1) % 4], 0.33), 0, Vector3.ONE, 165.0)
		if model == null:
			continue
		model.name = "BackgroundCar_%02d" % index
		model.add_to_group("ambient_traffic")
		model.rotation.y = atan2((route[(index + 1) % 4] - model.position).x, (route[(index + 1) % 4] - model.position).z)
		var area := Area3D.new()
		area.name = "ForwardPedestrianSensor"
		area.collision_layer = 0
		area.collision_mask = 2
		area.monitoring = true
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(3.4, 2.6, 8.0)
		collision.shape = shape
		collision.position = Vector3(0, 1.1, 5.0)
		area.add_child(collision)
		model.add_child(area)
		var wheels: Array[Node3D] = []
		_find_wheels(model, wheels)
		traffic.append({"model": model, "route": route.duplicate(), "waypoint": (index + 1) % 4, "sensor": area, "wheels": wheels, "speed": 0.0, "cruise_speed": 5.0 + float(index) * 0.35, "stopped": false, "distance": 0.0})

func _physics_process(delta: float) -> void:
	if not _built:
		return
	clock += delta
	_think_clock += delta
	if _think_clock >= THINK_INTERVAL:
		_think_clock = 0.0
		_think_citizens()
		_think_traffic()
		_update_signals()
	for citizen: Dictionary in citizens:
		_move_citizen(citizen, delta)
	for vehicle: Dictionary in traffic:
		_move_traffic(vehicle, delta)

func _on_player_attack(_weapon_id: String = "") -> void:
	if is_instance_valid(player):
		_last_attack_position = player.global_position
		_alarm_until = clock + 4.0

func _think_citizens() -> void:
	for citizen: Dictionary in citizens:
		var body: CharacterBody3D = citizen["body"]
		var route: Array = citizen["route"]
		var new_alarm: bool = clock < _alarm_until and float(citizen["observed_alarm"]) < _alarm_until and body.global_position.distance_to(_last_attack_position) < 12.0
		if new_alarm:
			citizen["observed_alarm"] = _alarm_until
			citizen["flee_until"] = clock + 3.0
		var target: Vector3 = route[int(citizen["waypoint"])]
		if body.position.distance_to(target) < 0.65:
			citizen["waypoint"] = (int(citizen["waypoint"]) + int(citizen["step"]) + route.size()) % route.size()
			target = route[int(citizen["waypoint"])]
		if new_alarm:
			# Retreat along the same clear edge. Compare the immediate directions,
			# not remote endpoint distances that could send someone toward danger.
			var previous_index: int = (int(citizen["waypoint"]) - int(citizen["step"]) + route.size()) % route.size()
			var retreat: Vector3 = (route[previous_index] as Vector3) - body.position
			var onward: Vector3 = target - body.position
			var away_from_attack: Vector3 = body.global_position - _last_attack_position
			retreat.y = 0
			onward.y = 0
			away_from_attack.y = 0
			if retreat.normalized().dot(away_from_attack) > onward.normalized().dot(away_from_attack):
				citizen["waypoint"] = previous_index
				citizen["step"] = -int(citizen["step"])
				target = route[previous_index]
		var direction: Vector3 = target - body.position
		direction.y = 0.0
		direction = direction.normalized()
		var fleeing: bool = clock < float(citizen["flee_until"])
		if is_instance_valid(player):
			var away: Vector3 = body.global_position - player.global_position
			away.y = 0.0
			if away.length() < 1.6 and away.length() > 0.05:
				var alternative: Vector3 = (direction + away.normalized() * 1.5).normalized()
				if is_walkable(body.position + alternative * 0.8) and _world_clearance(body.position + alternative * 0.8):
					direction = alternative
		if not is_walkable(body.position + direction * 0.8) or not _world_clearance(body.position + direction * 0.8):
			direction = Vector3.ZERO
			citizen["waypoint"] = (int(citizen["waypoint"]) - int(citizen["step"]) + route.size()) % route.size()
			citizen["step"] = -int(citizen["step"])
		citizen["direction"] = direction
		if body.position.distance_to(citizen["previous"]) < 0.05 and direction.length_squared() > 0.0:
			citizen["stuck_time"] = float(citizen["stuck_time"]) + THINK_INTERVAL
		else:
			citizen["stuck_time"] = 0.0
		citizen["previous"] = body.position
		if float(citizen["stuck_time"]) > 3.0:
			citizen["waypoint"] = (int(citizen["waypoint"]) - int(citizen["step"]) + route.size()) % route.size()
			citizen["step"] = -int(citizen["step"])
			citizen["stuck_time"] = 0.0
		var animation: AnimationPlayer = citizen["animation"]
		if animation != null:
			animation.active = not is_instance_valid(player) or body.global_position.distance_to(player.global_position) < 110.0
			var clip: StringName = citizen["clips"].get("run" if fleeing else "walk", &"")
			if not clip.is_empty() and animation.current_animation != clip:
				animation.play(clip, 0.15)

func _world_clearance(p: Vector3) -> bool:
	# Integrators may add a desk or a pickup after this scenery was built.
	# Query real static physics before choosing an avoidance direction.
	# The raised probe excludes level pavement while still seeing low objects.
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _citizen_probe
	query.transform = Transform3D(Basis.IDENTITY, global_transform * (p + Vector3(0, 0.95, 0)))
	query.collision_mask = 1
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _move_citizen(citizen: Dictionary, delta: float) -> void:
	var body: CharacterBody3D = citizen["body"]
	var direction: Vector3 = citizen["direction"]
	var speed_value: float = 3.2 if clock < float(citizen["flee_until"]) else float(citizen["speed"])
	body.velocity.x = direction.x * speed_value
	body.velocity.z = direction.z * speed_value
	body.velocity.y = -1.0 if body.is_on_floor() else body.velocity.y - 18.0 * delta
	body.move_and_slide()
	if direction.length_squared() > 0.01:
		var model: Node3D = citizen["model"]
		model.rotation.y = lerp_angle(model.rotation.y, atan2(direction.x, direction.z), minf(1, delta * 8))
	if body.position.y < -5.0:
		# A missing terrain is a safe test/host failure, rather than an actor leak.
		var route: Array = citizen["route"]
		var safe: Vector3 = route[(int(citizen["waypoint"]) - int(citizen["step"]) + route.size()) % route.size()]
		if is_walkable(safe):
			body.position = safe
			body.velocity = Vector3.ZERO

func _think_traffic() -> void:
	for vehicle: Dictionary in traffic:
		var model: Node3D = vehicle["model"]
		var area: Area3D = vehicle["sensor"]
		var stopped: bool = not area.get_overlapping_bodies().is_empty()
		# A mounted player loses their own physics layer, so detect their actual
		# vehicle as well. Ambient cars have no solid body and cannot pin it.
		if is_instance_valid(player):
			var difference: Vector3 = player.global_position - model.global_position
			if difference.dot(model.basis.z) > 0 and difference.dot(model.basis.z) < 9 and absf(difference.dot(model.basis.x)) < 2.6:
				stopped = true
		var route: Array = vehicle["route"]
		var target: Vector3 = route[int(vehicle["waypoint"])]
		if model.position.distance_to(target) < 9.0 and int(clock / 12.0) % 2 != int(vehicle["waypoint"]) % 2:
			stopped = true
		vehicle["stopped"] = stopped

func _move_traffic(vehicle: Dictionary, delta: float) -> void:
	var model: Node3D = vehicle["model"]
	var route: Array = vehicle["route"]
	var target: Vector3 = route[int(vehicle["waypoint"])]
	var speed_target: float = 0.0 if bool(vehicle["stopped"]) else float(vehicle["cruise_speed"])
	vehicle["speed"] = move_toward(float(vehicle["speed"]), speed_target, (9.0 if bool(vehicle["stopped"]) else 2.4) * delta)
	var distance_value: float = minf(float(vehicle["speed"]) * delta, model.position.distance_to(target))
	var direction: Vector3 = (target - model.position).normalized()
	model.position += direction * distance_value
	model.rotation.y = atan2(direction.x, direction.z)
	vehicle["distance"] = float(vehicle["distance"]) + distance_value
	for wheel: Node3D in vehicle["wheels"]:
		wheel.rotation.x += distance_value / 0.31
	if model.position.distance_to(target) < 0.05:
		vehicle["waypoint"] = (int(vehicle["waypoint"]) + 1) % route.size()

func _update_signals() -> void:
	for signal_value: Dictionary in _signals:
		var lamp: MeshInstance3D = signal_value["lamp"]
		lamp.material_override = _material(Color("75ce81") if int(signal_value["axis"]) == int(clock / 12.0) % 2 else Color("e87159"))

func _find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var result: AnimationPlayer = _find_animation(child)
		if result != null:
			return result
	return null

func _animation_names(animation: AnimationPlayer) -> Dictionary:
	var names: Dictionary = {}
	if animation != null:
		for clip: StringName in animation.get_animation_list():
			for requested: String in ["walk", "run", "idle"]:
				if str(clip).to_lower() == requested or str(clip).to_lower().ends_with("/" + requested):
					names[requested] = clip
	return names

func _find_wheels(node: Node, result: Array[Node3D]) -> void:
	if node is MeshInstance3D and str(node.name).to_lower().contains("wheel"):
		result.append(node as Node3D)
	for child: Node in node.get_children():
		_find_wheels(child, result)

func _v2(value: Array) -> Vector3:
	return Vector3(float(value[0]), 0, float(value[1]))

func _v3(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
