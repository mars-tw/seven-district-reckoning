class_name SevenGuard
extends CharacterBody3D

signal defeated
signal health_changed(current: float, maximum: float)

@export var maximum_health: float = 75.0
@export var detection_range: float = 14.0
@export var chase_speed: float = 3.2
@export var patrol_speed: float = 1.6
@export var visual_scale: Vector3 = Vector3.ONE

var health: float = 75.0
var target: SevenPlayer = null
var patrol_points: Array[Vector3] = []
var state: String = "patrol"
var animations_missing: Array[String] = []

var _visual_scene: PackedScene = null
var _visual: Node3D = null
var _animation_player: AnimationPlayer = null
var _active_animation: StringName = &""
var _gravity: float = 20.0
var _patrol_index: int = 0
var _home: Vector3 = Vector3.ZERO
var _received_hits: Dictionary = {}
var _attack_sequence: int = 0
var _attack_clock: float = -1.0
var _attack_connected: bool = false
var _attack_visual: bool = false
var _cooldown: float = 0.0
var _stagger: float = 0.0
var _knockdown_clock: float = 0.0
var _defeated_emitted: bool = false

func _ready() -> void:
	health = maximum_health
	collision_layer = 2
	collision_mask = 3
	floor_snap_length = 0.25
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 20.0))
	_home = global_position
	var collision: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.80
	collision.shape = capsule
	collision.position.y = 0.90
	add_child(collision)
	add_to_group("damageable")
	add_to_group("guards")
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
	_visual.name = "GuardVisual"
	_visual.scale = visual_scale
	add_child(_visual)
	var model: Node = _visual_scene.instantiate()
	_visual.add_child(model)
	_animation_player = _find_animation_player(model)
	animations_missing.clear()
	_configure_animation_loops()
	_active_animation = &""
	_play_animation("idle")

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if health <= 0.0:
		_update_knockdown(delta)
	elif _stagger > 0.0:
		_stagger -= delta
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
	elif _attack_clock >= 0.0:
		_update_attack(delta)
	else:
		_update_ai(delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()

func _update_ai(delta: float) -> void:
	if not is_instance_valid(target):
		var possible: Node = get_tree().get_first_node_in_group("player")
		target = possible as SevenPlayer
	var pursuing: bool = is_instance_valid(target) and target.health > 0.0 and not is_instance_valid(target.mounted_vehicle)
	if pursuing:
		pursuing = global_position.distance_to(target.global_position) <= detection_range and absf(target.global_position.y - global_position.y) < 3.0
	var destination: Vector3 = _home
	var speed: float = patrol_speed
	if pursuing:
		state = "chase"
		destination = target.global_position
		speed = chase_speed
		if global_position.distance_to(destination) < 1.65 and _has_line_of_sight(target):
			velocity.x = 0.0
			velocity.z = 0.0
			if _cooldown <= 0.0:
				_start_attack()
			return
	else:
		state = "patrol"
		if not patrol_points.is_empty():
			destination = patrol_points[_patrol_index]
			if global_position.distance_to(destination) < 0.6:
				_patrol_index = (_patrol_index + 1) % patrol_points.size()
				destination = patrol_points[_patrol_index]
	var direction: Vector3 = destination - global_position
	direction.y = 0.0
	if direction.length() < 0.45:
		velocity.x = move_toward(velocity.x, 0.0, delta * 12.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 12.0)
		_play_animation("idle")
		return
	direction = _avoid_wall(direction.normalized())
	velocity.x = move_toward(velocity.x, direction.x * speed, 12.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 12.0 * delta)
	if is_instance_valid(_visual):
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(direction.x, direction.z), minf(1.0, 10.0 * delta))
	_play_animation("run" if pursuing else "walk")

func _avoid_wall(direction: Vector3) -> Vector3:
	var origin: Vector3 = global_position + Vector3.UP * 0.8
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * 1.0)
	query.collision_mask = 3
	query.exclude = [get_rid()]
	var obstruction: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if obstruction.is_empty():
		return direction
	var normal: Vector3 = obstruction["normal"]
	var slide: Vector3 = direction.slide(normal)
	slide.y = 0.0
	if slide.length_squared() < 0.05:
		slide = Vector3(-direction.z, 0.0, direction.x)
	return slide.normalized()

func _start_attack() -> void:
	state = "attack"
	_attack_clock = 0.0
	_attack_sequence += 1
	_attack_connected = false
	_attack_visual = _play_animation("attack", true) or is_instance_valid(_visual)
	if is_instance_valid(_visual) and is_instance_valid(target):
		var direction: Vector3 = target.global_position - global_position
		_visual.rotation.y = atan2(direction.x, direction.z)

func _update_attack(delta: float) -> void:
	var previous_clock: float = _attack_clock
	_attack_clock += delta
	if is_instance_valid(_visual) and _animation_name("attack").is_empty():
		_visual.rotation.x = -0.24 * sin(clampf(_attack_clock / 0.75, 0.0, 1.0) * PI)
	if _attack_visual and not _attack_connected and _attack_clock >= 0.28 and previous_clock <= 0.43 and is_instance_valid(target):
		var difference: Vector3 = target.global_position - global_position
		var facing: Vector3 = _visual.global_basis.z if is_instance_valid(_visual) else Vector3.FORWARD
		difference.y = 0.0
		if difference.length() <= 1.9 and facing.normalized().dot(difference.normalized()) >= 0.5 and _has_line_of_sight(target):
			_attack_connected = true
			target.apply_hit("guard:%s:%s" % [get_instance_id(), _attack_sequence], str(get_instance_id()), 12.0)
	if _attack_clock >= 0.75:
		_attack_clock = -1.0
		_cooldown = 0.55
		if is_instance_valid(_visual):
			_visual.rotation.x = 0.0

func _has_line_of_sight(target_node: Node3D) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0, target_node.global_position + Vector3.UP * 0.9)
	query.collision_mask = 3
	query.exclude = [get_rid()]
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return result.is_empty() or result.get("collider") == target_node

func apply_hit(hit_id: String, _source_id: String, damage: float) -> void:
	if health <= 0.0 or _received_hits.has(hit_id) or damage <= 0.0:
		return
	_received_hits[hit_id] = true
	if _received_hits.size() > 128:
		_received_hits.erase(_received_hits.keys()[0])
	health = maxf(0.0, health - damage)
	_attack_clock = -1.0
	_stagger = 0.32
	state = "hit"
	_play_animation("hit", true)
	health_changed.emit(health, maximum_health)
	if health <= 0.0:
		state = "knockdown"
		remove_from_group("damageable")
		_knockdown_clock = 0.0
		collision_layer = 0
		collision_mask = 1
		_play_animation("knockdown", true)

func get_state() -> Dictionary:
	return {"health": health, "position": [global_position.x, global_position.y, global_position.z], "state": state}

func restore_state(data: Dictionary) -> bool:
	var saved_health: Variant = data.get("health", maximum_health)
	if not (saved_health is int or saved_health is float):
		return false
	var new_health: float = float(saved_health)
	if not is_finite(new_health) or new_health < 0.0 or new_health > maximum_health:
		return false
	var saved_position: Variant = data.get("position", [global_position.x, global_position.y, global_position.z])
	if not saved_position is Array or saved_position.size() != 3:
		return false
	for coordinate: Variant in saved_position:
		if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)):
			return false
	var new_position: Vector3 = Vector3(float(saved_position[0]), float(saved_position[1]), float(saved_position[2]))
	health = new_health
	global_position = new_position
	velocity = Vector3.ZERO
	_received_hits.clear()
	_attack_clock = -1.0
	_attack_connected = false
	_cooldown = 0.0
	_stagger = 0.0
	_patrol_index = 0
	_defeated_emitted = health <= 0.0
	if is_instance_valid(_visual):
		_visual.rotation.x = 0.0
		_visual.rotation.z = 0.0
		_visual.position.y = 0.0
	if health > 0.0:
		state = "patrol"
		_knockdown_clock = 0.0
		collision_layer = 2
		collision_mask = 3
		if not is_in_group("damageable"):
			add_to_group("damageable")
		_play_animation("idle", true)
	else:
		state = "defeated"
		_knockdown_clock = 0.75
		collision_layer = 0
		collision_mask = 1
		remove_from_group("damageable")
		if _play_animation("knockdown", true):
			var clip_name: StringName = _animation_name("knockdown")
			var clip: Animation = _animation_player.get_animation(clip_name)
			_animation_player.seek(clip.length, true)
			_animation_player.pause()
		elif is_instance_valid(_visual):
			_visual.rotation.z = -PI * 0.48
			_visual.position.y = -0.10
	health_changed.emit(health, maximum_health)
	return true

func _update_knockdown(delta: float) -> void:
	_knockdown_clock += delta
	velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
	if is_instance_valid(_visual) and _animation_name("knockdown").is_empty():
		_visual.rotation.z = lerpf(0.0, -PI * 0.48, clampf(_knockdown_clock / 0.65, 0.0, 1.0))
		_visual.position.y = -0.10
	if _knockdown_clock >= 0.75 and not _defeated_emitted:
		_defeated_emitted = true
		state = "defeated"
		defeated.emit()

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null

func _animation_name(requested: String) -> StringName:
	if not is_instance_valid(_animation_player):
		return &""
	for name_value: StringName in _animation_player.get_animation_list():
		var name_text: String = str(name_value).to_lower()
		if name_text == requested or name_text.ends_with("/" + requested) or name_text.ends_with("_" + requested):
			return name_value
	return &""

func _configure_animation_loops() -> void:
	for requested: String in ["idle", "walk", "run", "pedal", "drive", "attack", "hit", "knockdown"]:
		var clip_name: StringName = _animation_name(requested)
		if clip_name.is_empty():
			continue
		var clip: Animation = _animation_player.get_animation(clip_name)
		clip.loop_mode = Animation.LOOP_NONE if requested in ["attack", "hit", "knockdown"] else Animation.LOOP_LINEAR

func _play_animation(requested: String, restart: bool = false) -> bool:
	var animation: StringName = _animation_name(requested)
	if animation.is_empty():
		if not animations_missing.has(requested):
			animations_missing.append(requested)
		return false
	if restart or _active_animation != animation:
		_animation_player.play(animation, 0.12)
		_active_animation = animation
	return true
