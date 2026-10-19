class_name ObjectiveBeacon
extends Node3D
## R1 world-space guidance: a soft light column, a pulsing ground ring and a
## bobbing chevron above the active objective. Purely visual; no collision.

const FADE_NEAR := 2.5
const FADE_FAR := 7.0

var target_position := Vector3.ZERO
var has_target: bool = false
var distance_to_player: float = INF
var _player: Node3D
var _clock: float = 0.0
var _column: MeshInstance3D
var _ring: MeshInstance3D
var _chevron: MeshInstance3D
var _column_material: StandardMaterial3D
var _ring_material: StandardMaterial3D
var _chevron_material: StandardMaterial3D
var _alpha: float = 0.0

func setup(player: Node3D) -> void:
	_player = player
	name = "ObjectiveBeacon"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_column_material = _material(Color(1.0, 0.78, 0.36, 0.035))
	_ring_material = _material(Color(0.83, 0.78, 0.65, 0.65))
	_chevron_material = _material(Color(1.0, 0.86, 0.45, 0.95))
	var column_mesh := CylinderMesh.new()
	column_mesh.top_radius = 0.18
	column_mesh.bottom_radius = 0.42
	column_mesh.height = 3.0
	column_mesh.cap_top = false
	column_mesh.cap_bottom = false
	column_mesh.radial_segments = 16
	_column = _mesh_instance(column_mesh, _column_material)
	_column.visible = false
	_column.position.y = 1.5
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.68
	ring_mesh.outer_radius = 0.75
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 6
	_ring = _mesh_instance(ring_mesh, _ring_material)
	_ring.scale = Vector3(1, 0.08, 1)
	_ring.position.y = 0.13
	var chevron_mesh := PrismMesh.new()
	chevron_mesh.size = Vector3(0.7, 0.55, 0.16)
	_chevron = _mesh_instance(chevron_mesh, _chevron_material)
	_chevron.visible = false
	_chevron.rotation.z = PI
	_chevron.position.y = 2.6
	visible = false

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	material.set_meta("base_alpha", color.a)
	return material

func _mesh_instance(mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Device budgets must not cull the guidance marker with ordinary props.
	instance.set_meta("device_keep_visible", true)
	add_child(instance)
	return instance

func set_target(point: Vector3, active: bool = true) -> void:
	has_target = active and point.is_finite()
	if has_target: target_position = Vector3(point.x, 0.0, point.z)

func clear_target() -> void:
	has_target = false

func _process(delta: float) -> void:
	_clock += delta
	if not has_target or not is_instance_valid(_player):
		_alpha = move_toward(_alpha, 0.0, delta * 4.0)
	else:
		global_position = Vector3(target_position.x, 0.02, target_position.z)
		var flat := Vector2(_player.global_position.x - target_position.x, _player.global_position.z - target_position.z)
		distance_to_player = flat.length()
		# Fade out once the player stands at the objective so it never blocks the prompt.
		var wanted: float = clampf((distance_to_player - FADE_NEAR) / (FADE_FAR - FADE_NEAR), 0.15, 1.0)
		_alpha = move_toward(_alpha, wanted, delta * 3.0)
	visible = _alpha > 0.01
	if not visible: return
	var pulse: float = 0.5 + 0.5 * sin(_clock * 3.2)
	_ring.scale = Vector3(1.0 + pulse * 0.35, 0.08, 1.0 + pulse * 0.35)
	_chevron.position.y = 2.6 + sin(_clock * 2.6) * 0.12
	# Keep a broad silhouette facing the player; a spinning prism periodically
	# turns edge-on and falsely looks like an empty vertical bar.
	if is_instance_valid(_player):
		_chevron.rotation.y = atan2(_player.global_position.x-global_position.x,_player.global_position.z-global_position.z)
	for material: StandardMaterial3D in [_column_material, _ring_material, _chevron_material]:
		material.albedo_color.a = float(material.get_meta("base_alpha")) * _alpha * (1.0 - pulse * 0.35 if material == _ring_material else 1.0)

func get_alpha() -> float:
	return _alpha
