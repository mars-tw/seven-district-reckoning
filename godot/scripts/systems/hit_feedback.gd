class_name HitFeedback
extends Node3D
## R1 impact layer: sparks, rising damage numbers, overlay flash, camera shake,
## skeletal hit-pause and a combo counter. It never changes damage, hit windows
## or Engine.time_scale, so the deterministic strike regressions stay intact.

signal combo_changed(count: int)

const COMBO_WINDOW := 1.6
const FLASH_TIME := 0.09
const NUMBER_TIME := 0.75

var combo: int = 0
var _combo_clock: float = 0.0
var _flash_material: StandardMaterial3D
var _spark_material: StandardMaterial3D
var _font: Font
var _player: Node3D
var _audio: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var spawned_effects: int = 0
# Pending overlay flashes, cleared from _process (no SceneTreeTimer keeps
# resources alive past scene teardown).
var _flashes: Array[Dictionary] = []

func setup(player: Node3D, hit_audio: AudioStreamPlayer = null) -> void:
	_player = player
	_audio = hit_audio
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.seed = 7
	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.albedo_color = Color(1.0, 0.93, 0.78, 0.55)
	_spark_material = StandardMaterial3D.new()
	_spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_material.vertex_color_use_as_albedo = true
	_spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if ResourceLoader.exists("res://assets/fonts/SevenDistrictSansTC-Regular.otf"):
		_font = load("res://assets/fonts/SevenDistrictSansTC-Regular.otf") as Font

func on_hit(target: Node3D, damage: float) -> void:
	if not is_instance_valid(target): return
	var point: Vector3 = target.global_position + Vector3.UP * 1.0
	if is_instance_valid(_player):
		# Sparks sit on the side of the target that faces the attacker.
		var toward: Vector3 = _player.global_position - target.global_position
		toward.y = 0.0
		if toward.length_squared() > 0.01: point += toward.normalized() * 0.35
	_spawn_sparks(point)
	_spawn_number(point + Vector3.UP * 0.35, damage)
	_flash(target)
	if is_instance_valid(_player):
		if _player.has_method("add_camera_shake"): _player.call("add_camera_shake", 0.16 if damage < 30.0 else 0.24)
		if _player.has_method("hit_pause"): _player.call("hit_pause", 0.07)
	if _audio and _audio.stream and AudioServer.get_driver_name().to_lower() != "dummy":
		_audio.pitch_scale = _rng.randf_range(0.88, 1.16)
		_audio.play()
	combo += 1
	_combo_clock = COMBO_WINDOW
	combo_changed.emit(combo)

func reset_combo() -> void:
	if combo == 0: return
	combo = 0
	_combo_clock = 0.0
	combo_changed.emit(0)

func _process(delta: float) -> void:
	for index: int in range(_flashes.size() - 1, -1, -1):
		_flashes[index]["time"] = float(_flashes[index]["time"]) - delta
		if float(_flashes[index]["time"]) <= 0.0:
			_clear_flash(_flashes[index])
			_flashes.remove_at(index)
	if combo > 0:
		_combo_clock -= delta
		if _combo_clock <= 0.0: reset_combo()

func _spawn_sparks(point: Vector3) -> void:
	var sparks := CPUParticles3D.new()
	sparks.name = "HitSparks"
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.amount = 18
	sparks.lifetime = 0.42
	sparks.local_coords = false
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	quad.material = _spark_material
	sparks.mesh = quad
	sparks.direction = Vector3.UP
	sparks.spread = 75.0
	sparks.initial_velocity_min = 2.5
	sparks.initial_velocity_max = 5.5
	sparks.gravity = Vector3(0, -9.0, 0)
	sparks.scale_amount_min = 0.6
	sparks.scale_amount_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.62, 1.0))
	ramp.set_color(1, Color(1.0, 0.42, 0.12, 0.0))
	sparks.color_ramp = ramp
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.set_meta("device_keep_visible", true)
	add_child(sparks)
	sparks.global_position = point
	sparks.emitting = true
	spawned_effects += 1
	sparks.finished.connect(sparks.queue_free)

func _spawn_number(point: Vector3, damage: float) -> void:
	var label := Label3D.new()
	label.name = "DamageNumber"
	label.text = str(int(round(damage)))
	label.font_size = 44 if damage < 30.0 else 56
	label.pixel_size = 0.008
	label.outline_size = 10
	label.outline_modulate = Color(0.12, 0.05, 0.02, 0.9)
	label.modulate = Color(1.0, 0.86, 0.36) if damage < 30.0 else Color(1.0, 0.55, 0.28)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.set_meta("device_keep_visible", true)
	if _font: label.font = _font
	add_child(label)
	label.global_position = point + Vector3(_rng.randf_range(-0.25, 0.25), 0, 0)
	label.scale = Vector3.ONE * 0.6
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector3.ONE * 1.15, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y + 0.9, NUMBER_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, NUMBER_TIME * 0.55).set_delay(NUMBER_TIME * 0.45)
	tween.chain().tween_callback(label.queue_free)

func _flash(target: Node3D) -> void:
	var meshes: Array[Node] = target.find_children("*", "MeshInstance3D", true, false)
	var flashed: Array[MeshInstance3D] = []
	for node: Node in meshes:
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.material_overlay != null or mesh.get_script() != null: continue
		mesh.material_overlay = _flash_material
		flashed.append(mesh)
	if flashed.is_empty(): return
	_flashes.append({"meshes": flashed, "time": FLASH_TIME})

func _clear_flash(entry: Dictionary) -> void:
	for mesh: MeshInstance3D in entry["meshes"]:
		if is_instance_valid(mesh) and mesh.material_overlay == _flash_material: mesh.material_overlay = null

func _exit_tree() -> void:
	for entry: Dictionary in _flashes: _clear_flash(entry)
	_flashes.clear()
