class_name SevenPlayer
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal attacked(weapon_id: String)
signal weapon_changed(weapon_id: String)
signal interaction_requested
signal mount_requested
signal defeated

@export var walk_speed: float = 4.6
@export var sprint_speed: float = 7.5
@export var jump_speed: float = 5.3
@export var maximum_health: float = 100.0
@export var mouse_sensitivity: float = 0.003
@export var visual_scale: Vector3 = Vector3.ONE

var health: float = 100.0
var inventory: Dictionary = {"melee": [], "ranged": []}
var equipped_weapon: String = ""
var pulse_energy: int = 12
var controls_enabled: bool = true
var mounted_vehicle: Node3D = null
var animations_missing: Array[String] = []
var weapons_missing: Array[String] = []
var weapon_visual_available: bool = false
var last_attack_had_visual: bool = false

const WEAPONS: Dictionary = {
	"wrench": {"kind": "melee", "damage": 24.0, "reach": 2.1, "duration": 0.60, "start": 0.18, "end": 0.36, "cone": 0.45},
	"bat": {"kind": "melee", "damage": 36.0, "reach": 2.8, "duration": 0.82, "start": 0.25, "end": 0.49, "cone": 0.30},
	"pulse": {"kind": "ranged", "damage": 45.0, "reach": 20.0, "duration": 0.70, "start": 0.23, "end": 0.28, "cone": 0.97}
}

var _visual_root: Node3D = null
var _animation_player: AnimationPlayer = null
var _collision: CollisionShape3D = null
var _camera_pivot: Node3D = null
var _spring_arm: SpringArm3D = null
var _camera: Camera3D = null
var _weapon_mount: Node3D = null
var _weapon_visual: Node3D = null
var _weapon_rest_transform: Transform3D = Transform3D.IDENTITY
var _visual_scene: PackedScene = null
var _facing: Vector3 = Vector3.FORWARD
var _pitch: float = -0.18
var _attack_clock: float = -1.0
var _attack_sequence: int = 0
var _attack_hits: Dictionary = {}
var _received_hits: Dictionary = {}
var _attack_weapon: String = ""
var _hit_reaction: float = 0.0
var _mounted_seat: Vector3 = Vector3.ZERO
var _riding: bool = false
var _gravity: float = 20.0
var _active_animation: StringName = &""

func _ready() -> void:
	health = maximum_health
	collision_layer = 2
	collision_mask = 3
	floor_snap_length = 0.25
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 20.0))
	_collision = CollisionShape3D.new()
	_collision.name = "PlayerCapsule"
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.80
	_collision.shape = capsule
	_collision.position.y = 0.90
	add_child(_collision)
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraOrbit"
	_camera_pivot.position.y = 1.45
	add_child(_camera_pivot)
	_spring_arm = SpringArm3D.new()
	_spring_arm.name = "CameraCollisionArm"
	_spring_arm.spring_length = 5.4
	_spring_arm.margin = 0.25
	_spring_arm.collision_mask = 3
	_spring_arm.add_excluded_object(get_rid())
	_spring_arm.rotation.x = _pitch
	_camera_pivot.add_child(_spring_arm)
	_camera = Camera3D.new()
	_camera.name = "ThirdPersonCamera"
	_camera.fov = 68.0
	_camera.near = 0.08
	_camera.current = true
	_spring_arm.add_child(_camera)
	_facing = -_camera.global_basis.z
	_facing.y = 0.0
	_facing = _facing.normalized()
	add_to_group("player")
	if _visual_scene != null:
		_build_visual()
	health_changed.emit(health, maximum_health)

func setup_visual(scene: PackedScene) -> void:
	if scene == null:
		return
	_visual_scene = scene
	if is_inside_tree():
		_build_visual()

func _build_visual() -> void:
	if is_instance_valid(_visual_root):
		_visual_root.queue_free()
	_visual_root = Node3D.new()
	_visual_root.name = "HeroVisual"
	_visual_root.scale = visual_scale
	_visual_root.rotation.y = atan2(_facing.x, _facing.z)
	add_child(_visual_root)
	var model: Node = _visual_scene.instantiate()
	_visual_root.add_child(model)
	_animation_player = _find_animation_player(model)
	animations_missing.clear()
	_configure_animation_loops()
	_active_animation = &""
	_weapon_mount = Node3D.new()
	_weapon_mount.name = "WeaponSwing"
	var hand_socket: Node3D = _find_named_node(model, "HandToolSocket")
	var skeleton: Skeleton3D = _find_skeleton(model)
	var hand_bone: int = -1
	if skeleton != null:
		for bone_index: int in skeleton.get_bone_count():
			var bone_name: String = skeleton.get_bone_name(bone_index).to_lower()
			if bone_name == "arm-right" or bone_name.contains("righthand") or bone_name == "hand.r" or bone_name == "right_hand":
				hand_bone = bone_index
				break
	if hand_socket != null and skeleton != null and hand_bone >= 0:
		var attachment: BoneAttachment3D = BoneAttachment3D.new()
		attachment.name = "RightHandToolAttachment"
		attachment.bone_name = skeleton.get_bone_name(hand_bone)
		skeleton.add_child(attachment)
		var rest_global: Transform3D = skeleton.global_transform * skeleton.get_bone_global_rest(hand_bone)
		attachment.add_child(_weapon_mount)
		_weapon_mount.transform = rest_global.affine_inverse() * hand_socket.global_transform
	elif hand_socket != null:
		hand_socket.add_child(_weapon_mount)
	else:
		_weapon_mount.position = Vector3(0.45, 1.00, 0.28)
		_visual_root.add_child(_weapon_mount)
	_weapon_rest_transform = _weapon_mount.transform
	_update_weapon_visual()
	_play_animation("idle")

func get_camera() -> Camera3D:
	return _camera

func get_seat_hip_offset() -> Vector3:
	if is_instance_valid(_visual_root):
		var hip_socket: Node3D = _find_named_node(_visual_root, "SeatHipSocket")
		if hip_socket != null:
			return to_local(hip_socket.global_position)
	return Vector3(0.0, 0.46, 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and is_instance_valid(_camera_pivot):
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_camera_pivot.rotation.y -= motion.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - motion.relative.y * mouse_sensitivity, -0.95, 0.30)
		_spring_arm.rotation.x = _pitch

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_camera):
		return
	if Input.is_action_just_pressed("interact") and controls_enabled and health > 0.0:
		interaction_requested.emit()
	if Input.is_action_just_pressed("mount") and controls_enabled and health > 0.0:
		mount_requested.emit()
	if is_instance_valid(mounted_vehicle):
		global_position = mounted_vehicle.to_global(_mounted_seat)
		velocity = Vector3.ZERO
		if is_instance_valid(_visual_root):
			_visual_root.rotation.y = mounted_vehicle.rotation.y
		if _riding:
			_play_animation("pedal")
			if is_instance_valid(_animation_player) and mounted_vehicle.has_method("get_speed_kmh"):
				var riding_speed: float = float(mounted_vehicle.call("get_speed_kmh"))
				_animation_player.speed_scale = clampf(riding_speed / 12.0, 0.0, 2.0)
		return
	if mounted_vehicle != null:
		clear_mounted(global_position)
	if controls_enabled and health > 0.0:
		if Input.is_action_just_pressed("cycle_weapon"):
			_cycle_weapon()
		if Input.is_action_just_pressed("attack"):
			begin_attack()
		_update_movement(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()
	_update_attack(delta)
	_hit_reaction = maxf(0.0, _hit_reaction - delta)
	if health <= 0.0:
		_play_animation("knockdown")
	elif _attack_clock < 0.0 and _hit_reaction <= 0.0:
		var planar_speed: float = Vector2(velocity.x, velocity.z).length()
		_play_animation("run" if planar_speed > 5.0 else ("walk" if planar_speed > 0.15 else "idle"))

func _update_movement(delta: float) -> void:
	var movement: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera_forward: Vector3 = -_camera.global_basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var camera_right: Vector3 = _camera.global_basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()
	var direction: Vector3 = (camera_right * movement.x - camera_forward * movement.y).normalized()
	var speed: float = sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	if _attack_clock >= 0.0:
		speed *= 0.35
	velocity.x = move_toward(velocity.x, direction.x * speed, 22.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 22.0 * delta)
	if direction.length_squared() > 0.01 and _attack_clock < 0.0:
		_facing = direction
		if is_instance_valid(_visual_root):
			_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, atan2(direction.x, direction.z), 14.0 * delta)
	if Input.is_action_just_pressed("jump") and is_on_floor() and _attack_clock < 0.0:
		velocity.y = jump_speed

func _canonical_weapon(weapon_name: String) -> String:
	match weapon_name.to_lower():
		"wrench", "wpn-002", "扳手": return "wrench"
		"bat", "baseball_bat", "wpn-001", "球棒": return "bat"
		"pulse", "pulse_tool", "wpn-003", "脈衝器", "虛構脈衝器具": return "pulse"
	return ""

func grant_weapon(weapon_name: String) -> bool:
	var weapon: String = _canonical_weapon(weapon_name)
	if weapon.is_empty():
		return false
	var specification: Dictionary = WEAPONS[weapon]
	var kind: String = str(specification["kind"])
	var slot: Array = inventory[kind]
	if slot.has(weapon):
		return equip_weapon(weapon)
	var capacity: int = 2 if kind == "melee" else 1
	if slot.size() >= capacity:
		return false
	slot.append(weapon)
	inventory[kind] = slot
	return equip_weapon(weapon)

func clear_inventory() -> void:
	_attack_clock = -1.0
	if is_instance_valid(_weapon_mount):
		_weapon_mount.transform = _weapon_rest_transform
	if is_instance_valid(_visual_root):
		_visual_root.rotation.z = 0.0
	inventory = {"melee": [], "ranged": []}
	equipped_weapon = ""
	pulse_energy = 12
	_update_weapon_visual()
	weapon_changed.emit("")

func equip_weapon(weapon_name: String) -> bool:
	var weapon: String = _canonical_weapon(weapon_name)
	if weapon.is_empty() or _attack_clock >= 0.0:
		return false
	var specification: Dictionary = WEAPONS[weapon]
	var slot: Array = inventory[str(specification["kind"])]
	if not slot.has(weapon):
		return false
	equipped_weapon = weapon
	_update_weapon_visual()
	weapon_changed.emit(weapon)
	return true

func _cycle_weapon() -> void:
	var available: Array = []
	available.append_array(inventory["melee"])
	available.append_array(inventory["ranged"])
	if available.is_empty():
		return
	var index: int = available.find(equipped_weapon)
	equip_weapon(str(available[(index + 1) % available.size()]))

func _update_weapon_visual() -> void:
	if not is_instance_valid(_weapon_mount):
		return
	if is_instance_valid(_weapon_visual):
		_weapon_visual.queue_free()
	_weapon_visual = null
	weapon_visual_available = false
	if equipped_weapon.is_empty():
		return
	var path: String = "res://assets/models/%s.glb" % equipped_weapon
	if ResourceLoader.exists(path):
		var scene: PackedScene = load(path) as PackedScene
		if scene != null:
			_weapon_visual = scene.instantiate() as Node3D
			if _weapon_visual != null:
				_weapon_mount.add_child(_weapon_visual)
				var grip_socket: Node3D = _find_named_node(_weapon_visual, "GripSocket")
				if grip_socket != null:
					_weapon_visual.position = -_weapon_visual.to_local(grip_socket.global_position)
				weapon_visual_available = true
				weapons_missing.erase(equipped_weapon)
	if not weapon_visual_available and not weapons_missing.has(equipped_weapon):
		weapons_missing.append(equipped_weapon)

func begin_attack() -> bool:
	if not controls_enabled or health <= 0.0 or is_instance_valid(mounted_vehicle) or _attack_clock >= 0.0 or equipped_weapon.is_empty():
		return false
	if equipped_weapon == "pulse" and pulse_energy <= 0:
		return false
	if not weapon_visual_available:
		return false
	_attack_weapon = equipped_weapon
	_attack_sequence += 1
	_attack_clock = 0.0
	_attack_hits.clear()
	last_attack_had_visual = _play_animation("attack", true) or is_instance_valid(_visual_root)
	if not last_attack_had_visual:
		_attack_clock = -1.0
		return false
	if is_instance_valid(_visual_root):
		_visual_root.rotation.y = atan2(_facing.x, _facing.z)
	if _attack_weapon == "pulse":
		pulse_energy -= 1
		var aim: Vector3 = -_camera.global_basis.z
		aim.y = 0.0
		if aim.length_squared() > 0.01:
			_facing = aim.normalized()
			_visual_root.rotation.y = atan2(_facing.x, _facing.z)
	attacked.emit(_attack_weapon)
	return true

func _update_attack(delta: float) -> void:
	if _attack_clock < 0.0:
		return
	var specification: Dictionary = WEAPONS[_attack_weapon]
	var previous_clock: float = _attack_clock
	_attack_clock += delta
	var duration: float = float(specification["duration"])
	if is_instance_valid(_weapon_mount):
		# A visible model/weapon swing remains available when a GLB has no attack clip.
		var progress: float = clampf(_attack_clock / duration, 0.0, 1.0)
		var swing: float = sin(progress * PI)
		var swing_pitch: float = -0.1 * swing if _attack_weapon == "pulse" else 0.8 * swing
		var swing_yaw: float = 0.0 if _attack_weapon == "pulse" else -1.35 + 2.7 * progress
		_weapon_mount.transform = _weapon_rest_transform * Transform3D(Basis.from_euler(Vector3(swing_pitch, swing_yaw, -0.25 * swing)), Vector3.ZERO)
		if _animation_name("attack").is_empty() and is_instance_valid(_visual_root):
			_visual_root.rotation.z = -0.12 * swing
	if _attack_clock >= float(specification["start"]) and previous_clock <= float(specification["end"]):
		_check_attack_targets(specification)
	if _attack_clock >= duration:
		_attack_clock = -1.0
		if is_instance_valid(_weapon_mount):
			_weapon_mount.transform = _weapon_rest_transform
		if is_instance_valid(_visual_root):
			_visual_root.rotation.z = 0.0

func _check_attack_targets(specification: Dictionary) -> void:
	var candidates: Array[Node] = get_tree().get_nodes_in_group("damageable")
	var best_pulse_target: Node3D = null
	var best_distance: float = INF
	for candidate: Node in candidates:
		if candidate == self or not candidate is Node3D or not candidate.has_method("apply_hit"):
			continue
		var target_node: Node3D = candidate as Node3D
		var target_health: Variant = target_node.get("health")
		if target_health != null and float(target_health) <= 0.0:
			continue
		var identifier: int = target_node.get_instance_id()
		if _attack_hits.has(identifier):
			continue
		var difference: Vector3 = target_node.global_position - global_position
		var distance: float = difference.length()
		if distance > float(specification["reach"]) or absf(difference.y) > 2.0:
			continue
		difference.y = 0.0
		if difference.length_squared() > 0.01 and _facing.dot(difference.normalized()) < float(specification["cone"]):
			continue
		if not _has_line_of_sight(target_node):
			continue
		if _attack_weapon == "pulse":
			if distance < best_distance:
				best_distance = distance
				best_pulse_target = target_node
		else:
			_deliver_hit(target_node, float(specification["damage"]))
	if best_pulse_target != null and _attack_hits.is_empty():
		_deliver_hit(best_pulse_target, float(specification["damage"]))

func _has_line_of_sight(target_node: Node3D) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.1, target_node.global_position + Vector3.UP * 0.8)
	query.collision_mask = 3
	query.exclude = [get_rid()]
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var collider: Object = result.get("collider") as Object
	return collider == target_node or (collider is Node and target_node.is_ancestor_of(collider as Node))

func _deliver_hit(target_node: Node3D, damage: float) -> void:
	_attack_hits[target_node.get_instance_id()] = true
	var hit_id: String = "%s:%s" % [get_instance_id(), _attack_sequence]
	target_node.call("apply_hit", hit_id, str(get_instance_id()), damage)

func apply_hit(hit_id: String, _source_id: String, damage: float) -> void:
	if health <= 0.0 or _received_hits.has(hit_id) or damage <= 0.0:
		return
	_received_hits[hit_id] = true
	if _received_hits.size() > 128:
		_received_hits.erase(_received_hits.keys()[0])
	health = maxf(0.0, health - damage)
	_attack_clock = -1.0
	if is_instance_valid(_weapon_mount):
		_weapon_mount.transform = _weapon_rest_transform
	_hit_reaction = 0.3
	_play_animation("hit", true)
	health_changed.emit(health, maximum_health)
	if health <= 0.0:
		_attack_clock = -1.0
		defeated.emit()

func restore_health() -> void:
	health = maximum_health
	_received_hits.clear()
	controls_enabled = true
	if is_instance_valid(_visual_root):
		_visual_root.rotation.x = 0.0
		_visual_root.rotation.z = 0.0
	health_changed.emit(health, maximum_health)

func set_mounted(vehicle: Node3D, seat_position: Vector3, riding: bool = false) -> void:
	mounted_vehicle = vehicle
	_mounted_seat = seat_position
	_riding = riding
	_attack_clock = -1.0
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	if is_instance_valid(_collision):
		_collision.set_deferred("disabled", true)
	if is_instance_valid(_visual_root):
		_visual_root.visible = riding
		_visual_root.rotation.z = 0.0
		_weapon_mount.visible = false
	if riding:
		_play_animation("pedal", true)

func clear_mounted(exit_position: Vector3) -> void:
	mounted_vehicle = null
	_riding = false
	global_position = exit_position
	velocity = Vector3.ZERO
	collision_layer = 2
	collision_mask = 3
	if is_instance_valid(_animation_player):
		_animation_player.speed_scale = 1.0
	if is_instance_valid(_collision):
		_collision.set_deferred("disabled", false)
	if is_instance_valid(_visual_root):
		_visual_root.visible = true
		_visual_root.rotation.z = 0.0
		_weapon_mount.visible = true
	_play_animation("idle", true)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found: Skeleton3D = _find_skeleton(child)
		if found != null:
			return found
	return null

func _find_named_node(node: Node, requested: String) -> Node3D:
	if node is Node3D and str(node.name) == requested:
		return node as Node3D
	for child: Node in node.get_children():
		var found: Node3D = _find_named_node(child, requested)
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
