class_name ArcadeVehicle
extends CharacterBody3D

signal occupancy_changed(is_occupied: bool)
signal exit_blocked(reason: String)

@export_enum("car", "bike") var type: String = "car"
@export var visual_scale: Vector3 = Vector3.ONE
@export var seat_offset: Vector3 = Vector3.ZERO

var occupied: bool = false
var driver: SevenPlayer = null
var speed_mps: float = 0.0
var last_exit_error: String = ""

var _visual_scene: PackedScene = null
var _visual: Node3D = null
var _spawn_transform: Transform3D
var _spawn_saved: bool = false
var _gravity: float = 20.0
var _wheels: Array[Node3D] = []
var _wheel_rotations: Dictionary = {}
var _wheel_spin: float = 0.0
var _crank: Node3D = null
var _crank_rotation: Vector3 = Vector3.ZERO

func _ready() -> void:
	collision_layer = 2
	collision_mask = 3
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(42.0)
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 20.0))
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "VehicleCollision"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(0.55, 1.05, 1.75) if type == "bike" else Vector3(1.65, 1.30, 3.55)
	collision.shape = shape
	collision.position.y = 0.65 if type == "car" else 0.60
	add_child(collision)
	call_deferred("capture_spawn")
	add_to_group("vehicles")
	if _visual_scene != null:
		_build_visual()

func setup_visual(scene: PackedScene) -> void:
	if scene == null:
		return
	_visual_scene = scene
	if is_inside_tree():
		_build_visual()

func _build_visual() -> void:
	if is_instance_valid(_visual):
		_visual.queue_free()
	_visual = Node3D.new()
	_visual.name = "VehicleVisual"
	_visual.scale = visual_scale
	add_child(_visual)
	_visual.add_child(_visual_scene.instantiate())
	_wheels.clear()
	_wheel_rotations.clear()
	_find_wheels(_visual)
	_crank = _find_named_node(_visual, "Crank")
	if _crank != null:
		_crank_rotation = _crank.rotation

func _find_wheels(node: Node) -> void:
	var has_geometry: bool = node is MeshInstance3D or not node.find_children("*", "MeshInstance3D", true, false).is_empty()
	if node is Node3D and str(node.name).to_lower().contains("wheel") and has_geometry:
		var wheel: Node3D = node as Node3D
		_wheels.append(wheel)
		_wheel_rotations[wheel.get_instance_id()] = wheel.rotation
		return
	for child: Node in node.get_children():
		_find_wheels(child)

func _physics_process(delta: float) -> void:
	if occupied and not is_instance_valid(driver):
		occupied = false
		driver = null
		occupancy_changed.emit(false)
	var steer: float = 0.0
	if occupied:
		var throttle: float = Input.get_axis("move_back", "move_forward")
		steer = Input.get_axis("move_left", "move_right")
		var maximum_speed: float = 25.0 / 3.6 if type == "bike" else 60.0 / 3.6
		var acceleration: float = 3.0 if type == "bike" else 5.4
		var braking: bool = (InputMap.has_action("brake") and Input.is_action_pressed("brake")) or Input.is_action_pressed("jump")
		if braking:
			speed_mps = move_toward(speed_mps, 0.0, 12.0 * delta)
		elif absf(throttle) > 0.05:
			if signf(throttle) != signf(speed_mps) and absf(speed_mps) > 0.25:
				speed_mps = move_toward(speed_mps, 0.0, 9.0 * delta)
			else:
				speed_mps = clampf(speed_mps + throttle * acceleration * delta, -maximum_speed * 0.30, maximum_speed)
		else:
			speed_mps = move_toward(speed_mps, 0.0, (0.7 if type == "bike" else 0.9) * delta)
		var speed_fraction: float = clampf(absf(speed_mps) / maximum_speed, 0.0, 1.0)
		var turning: float = (1.9 if type == "bike" else 1.5) * lerpf(1.0, 0.55, speed_fraction)
		rotation.y += steer * turning * clampf(speed_mps / 2.4, -1.0, 1.0) * delta
		if InputMap.has_action("reset_vehicle") and Input.is_action_just_pressed("reset_vehicle"):
			reset()
	else:
		speed_mps = move_toward(speed_mps, 0.0, 5.0 * delta)
	var forward: Vector3 = global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var grip: float = minf(1.0, 12.0 * delta)
	velocity.x = lerpf(velocity.x, forward.x * speed_mps, grip)
	velocity.z = lerpf(velocity.z, forward.z * speed_mps, grip)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)
	move_and_slide()
	for index: int in get_slide_collision_count():
		var collision: KinematicCollision3D = get_slide_collision(index)
		if absf(collision.get_normal().y) < 0.5:
			speed_mps *= 0.50
			break
	_animate_wheels(delta, steer)
	if is_instance_valid(_visual) and type == "bike":
		_visual.rotation.z = lerpf(_visual.rotation.z, -steer * clampf(speed_mps / 6.0, -1.0, 1.0) * 0.22, minf(1.0, delta * 7.0))
	if global_position.y < -20.0:
		reset()

func _animate_wheels(delta: float, steer: float) -> void:
	_wheel_spin += speed_mps * delta / (0.34 if type == "bike" else 0.31)
	if is_instance_valid(_crank):
		_crank.rotation.x = _crank_rotation.x + _wheel_spin * 0.6
	for wheel: Node3D in _wheels:
		if not is_instance_valid(wheel):
			continue
		var original: Vector3 = _wheel_rotations[wheel.get_instance_id()]
		wheel.rotation.x = original.x + _wheel_spin
		var wheel_name: String = str(wheel.name).to_lower()
		if wheel_name.contains("front") or wheel_name.ends_with("fl") or wheel_name.ends_with("fr"):
			wheel.rotation.y = original.y + steer * 0.35

func enter(player: SevenPlayer) -> bool:
	if occupied or not is_instance_valid(player) or is_instance_valid(player.mounted_vehicle) or player.health <= 0.0:
		return false
	if player.global_position.distance_to(global_position) > 4.0:
		return false
	driver = player
	occupied = true
	var seat: Vector3 = Vector3(0.0, 0.45, -0.15) if type == "bike" else Vector3(-0.38, 0.45, 0.2)
	if seat_offset != Vector3.ZERO:
		seat = seat_offset
	elif is_instance_valid(_visual):
		var seat_node: Node3D = _find_named_node(_visual, "RiderSeat" if type == "bike" else "DriverSeat")
		if seat_node != null:
			seat = to_local(seat_node.global_position) - player.get_seat_hip_offset()
	driver.set_mounted(self, seat, type == "bike")
	occupancy_changed.emit(true)
	return true

func exit() -> bool:
	if not occupied or not is_instance_valid(driver):
		return false
	if absf(speed_mps) > 2.8:
		last_exit_error = "先煞車，再下車。"
		exit_blocked.emit(last_exit_error)
		return false
	var exit_position: Vector3 = _find_safe_exit()
	if not exit_position.is_finite():
		last_exit_error = "兩側出口都被擋住，換個停車位置。"
		exit_blocked.emit(last_exit_error)
		return false
	force_release(exit_position)
	last_exit_error = ""
	return true

func force_release(exit_position: Vector3 = Vector3(INF, INF, INF)) -> void:
	# Reserved for a validated saved position or mission checkpoint teleport.
	var former_driver: SevenPlayer = driver
	var was_occupied: bool = occupied
	driver = null
	occupied = false
	speed_mps = 0.0
	last_exit_error = ""
	velocity = Vector3.ZERO
	if is_instance_valid(former_driver):
		former_driver.clear_mounted(exit_position if exit_position.is_finite() else former_driver.global_position)
	if was_occupied:
		occupancy_changed.emit(false)

func _find_safe_exit() -> Vector3:
	var side: float = 1.2 if type == "bike" else 1.5
	var offsets: Array[Vector3] = [Vector3(side, 0.0, 0.0), Vector3(-side, 0.0, 0.0), Vector3(side, 0.0, -1.3), Vector3(-side, 0.0, -1.3), Vector3(0.0, 0.0, -2.8)]
	var excluded: Array[RID] = [get_rid(), driver.get_rid()]
	for offset: Vector3 in offsets:
		var candidate: Vector3 = to_global(offset)
		var ground_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 2.0, candidate - Vector3.UP * 3.0)
		ground_query.collision_mask = 1
		ground_query.exclude = excluded
		var ground: Dictionary = get_world_3d().direct_space_state.intersect_ray(ground_query)
		if ground.is_empty():
			continue
		var normal: Vector3 = ground["normal"]
		if normal.y < 0.65:
			continue
		var foot: Vector3 = ground["position"]
		var capsule: CapsuleShape3D = CapsuleShape3D.new()
		capsule.radius = 0.40
		capsule.height = 1.85
		var body_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		body_query.shape = capsule
		body_query.transform = Transform3D(Basis.IDENTITY, foot + Vector3.UP * 0.975)
		body_query.collision_mask = 3
		body_query.exclude = excluded
		var blockers: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(body_query, 4)
		if not blockers.is_empty():
			continue
		# Prevent stepping through a wall into an otherwise empty capsule position.
		var path_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0, foot + Vector3.UP * 1.0)
		path_query.collision_mask = 3
		path_query.exclude = excluded
		if get_world_3d().direct_space_state.intersect_ray(path_query).is_empty():
			return foot + Vector3.UP * 0.05
	return Vector3(INF, INF, INF)

func capture_spawn() -> void:
	_spawn_transform = global_transform
	_spawn_saved = true

func reset() -> void:
	if _spawn_saved:
		global_transform = _spawn_transform
	speed_mps = 0.0
	velocity = Vector3.ZERO
	if is_instance_valid(_visual):
		_visual.rotation.z = 0.0

func _find_named_node(node: Node, requested: String) -> Node3D:
	if node is Node3D and str(node.name) == requested:
		return node as Node3D
	for child: Node in node.get_children():
		var found: Node3D = _find_named_node(child, requested)
		if found != null:
			return found
	return null

func get_speed_kmh() -> float:
	return absf(speed_mps) * 3.6
