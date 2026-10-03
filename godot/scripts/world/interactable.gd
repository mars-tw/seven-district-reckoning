extends StaticBody3D
class_name DistrictObject

signal used(object_id: String)
signal destroyed(object_id: String)
signal hit_received(object_id: String)

var object_id: String = ""
var event_name: String = ""
var caption: String = ""
var destructible: bool = false
var health: float = 35.0
var initial_health: float = 35.0
var broken: bool = false
var collected: bool = false
var visual: Node3D
var text_label: Label3D
var consumed_hits: Dictionary = {}
var collision: CollisionShape3D
var initial_transform: Transform3D
var damage_gate: Callable
var non_solid: bool = false

func configure(id: String, text: String, event: String, model: PackedScene, size: Vector3, can_break: bool = false) -> void:
	object_id = id
	caption = text
	event_name = event
	destructible = can_break
	name = id
	collision_layer = 1
	collision_mask = 0
	collision = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position.y = size.y * 0.5
	add_child(collision)
	if model:
		visual = model.instantiate() as Node3D
		add_child(visual)
	text_label = Label3D.new()
	text_label.text = text
	text_label.font_size = 36
	text_label.pixel_size = 0.012
	text_label.outline_size = 6
	text_label.modulate = Color(1.0, 0.86, 0.40)
	text_label.position = Vector3(0, size.y + 0.45, 0)
	text_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text_label.no_depth_test = true
	if ResourceLoader.exists("res://assets/fonts/SevenDistrictSansTC-Regular.otf"):
		text_label.font = load("res://assets/fonts/SevenDistrictSansTC-Regular.otf") as Font
	add_child(text_label)
	add_to_group("interactables")
	if destructible:
		add_to_group("damageable")
	initial_transform = transform

func interact() -> void:
	if not collected:
		used.emit(object_id)

func apply_hit(hit_id: String, _source_id: String, damage: float) -> void:
	if not destructible or broken or consumed_hits.has(hit_id):
		return
	if damage_gate.is_valid() and not damage_gate.call(object_id):
		return
	consumed_hits[hit_id] = true
	health = maxf(0.0, health - damage)
	hit_received.emit(object_id)
	if visual:
		visual.rotation.z = 0.06 if health > 0 else 0.5
	if health <= 0:
		broken = true
		collision.set_deferred("disabled", true)
		text_label.text = caption + "｜已損壞"
		text_label.modulate = Color(0.8, 0.8, 0.75)
		if visual:
			visual.scale.y *= 0.42
			visual.rotation.z = 0.7
		destroyed.emit(object_id)

func set_collected(value: bool) -> void:
	collected = value
	visible = not value
	if collision:
		collision.set_deferred("disabled", value or broken or non_solid)

func restore(data: Dictionary) -> void:
	health = float(data.get("health", initial_health))
	broken = bool(data.get("broken", false))
	collected = bool(data.get("collected", false))
	consumed_hits.clear()
	if collision:
		collision.set_deferred("disabled", broken or collected or non_solid)
	visible = not collected
	if visual:
		visual.scale = Vector3.ONE
		visual.rotation = Vector3.ZERO
		if broken:
			visual.scale.y = 0.42
			visual.rotation.z = 0.7
	text_label.text = caption + ("｜已損壞" if broken else "")

func state() -> Dictionary:
	return {"health": health, "broken": broken, "collected": collected}
