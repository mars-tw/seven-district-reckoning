extends CharacterBody3D
class_name RescuePerson

signal safe_arrival(person_id: String)

var person_id: String
var target: Node3D
var safe_point := Vector3(-46, 0, 42)
var following: bool = false
var arrived: bool = false
var visual: Node3D
var label: Label3D
var animator: AnimationPlayer

func configure(id: String, model: PackedScene) -> void:
	person_id = id
	name = id
	collision_layer = 2
	collision_mask = 1
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.88
	add_child(collision)
	if model:
		visual = model.instantiate() as Node3D
		add_child(visual)
		animator = _find_animator(visual)
	label = Label3D.new()
	label.text = "受困者｜E 交談"
	label.position.y = 2.3
	label.font_size = 32
	label.pixel_size = 0.01
	label.modulate = Color(0.55, 1.0, 0.75)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	if ResourceLoader.exists("res://assets/fonts/SevenDistrictSansTC-Regular.otf"):
		label.font = load("res://assets/fonts/SevenDistrictSansTC-Regular.otf") as Font
	add_child(label)
	add_to_group("rescue_people")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	var direction := Vector3.ZERO
	if following and target and not arrived:
		var offset: Vector3 = target.global_position - global_position
		offset.y = 0
		if offset.length() > 2.5:
			direction = offset.normalized()
		if global_position.distance_to(safe_point) < 4.5:
			arrived = true
			following = false
			label.text = "已安全抵達"
			safe_arrival.emit(person_id)
	velocity.x = direction.x * 4.0
	velocity.z = direction.z * 4.0
	if visual and direction.length() > 0.1:
		visual.rotation.y = atan2(direction.x, direction.z)
	move_and_slide()
	_play("walk" if direction.length() > 0.1 else "idle")

func _find_animator(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animator(child)
		if found:
			return found
	return null

func _play(key: String) -> void:
	if not animator:
		return
	for clip in animator.get_animation_list():
		if String(clip).to_lower().ends_with(key) and animator.current_animation != String(clip):
			animator.play(clip)
			return
