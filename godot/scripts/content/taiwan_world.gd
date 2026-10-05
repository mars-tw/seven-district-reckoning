extends Node3D
const ContactShadow = preload("res://scripts/world/contact_shadow.gd")
var host: Node3D
var life: Node
var player: CharacterBody3D
var actors: Array[Dictionary] = []
var station_ids: Dictionary = {}
var carried_visual: Node3D
var _think: float = 0.0
var _character_distance: float = 180.0

func setup(world: Node3D, manager: Node, avatar: CharacterBody3D) -> void:
	host = world
	life = manager
	player = avatar
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for id: String in life.stations:
		var station: Dictionary = life.stations[id]
		var point: Array = station["position"]
		var p := Vector3(float(point[0]),0.10,float(point[1]))
		var key: String = "TW_station_"+id
		host._add_object(key,str(station["title"])+"｜生活互動","life_station","",p,Vector3(.25,.3,.25))
		var object: StaticBody3D = host.objects[key]
		object.non_solid = true
		object.collision.set_deferred("disabled",true)
		object.text_label.position.y = 1.9
		object.text_label.pixel_size = .006
		object.text_label.font_size = 25
		object.text_label.visibility_range_end = 22
		object.text_label.modulate = Color("b9e0bd")
		station_ids[key] = id
		host.targets[id] = p
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = .7
		mesh.outer_radius = .75
		ring.mesh = mesh
		ring.position.y = .065
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("c7d0a5")
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.visibility_range_end = 30
		object.add_child(ring)
	for id: String in life.characters:
		var spec: Dictionary = life.characters[id]
		var station: Dictionary = life.stations[str(spec["home_station"])]
		var point: Array = station["position"]
		var p := Vector3(float(point[0])+1.8,0.06,float(point[1])-1.8)
		var scene: PackedScene = host._model(str(spec["appearance_key"]))
		if not scene: continue
		var actor: Node3D = scene.instantiate() as Node3D
		actor.name = "Story_"+id
		actor.position = p
		actor.rotation.y = PI
		actor.add_to_group("taiwan_story_people")
		add_child(actor)
		actor.add_child(ContactShadow.new())
		var tint: Color = Color.from_string(str(spec.get("appearance_variant","b1b8a0")),Color.WHITE)
		for mesh_node: Node in actor.find_children("*","MeshInstance3D",true,false):
			var instance: MeshInstance3D = mesh_node as MeshInstance3D
			instance.set_meta("device_geometry_kind","character")
			for surface: int in instance.mesh.get_surface_count():
				var original: Material = instance.get_active_material(surface)
				if not str(spec.get("appearance_variant","")).is_empty() and original is StandardMaterial3D and original.resource_name.to_lower().contains("fabric"):
					var clothing: StandardMaterial3D = original.duplicate() as StandardMaterial3D
					clothing.albedo_color = tint
					instance.set_surface_override_material(surface,clothing)
		var animation: AnimationPlayer
		var animations: Array[Node] = actor.find_children("*","AnimationPlayer",true,false)
		if not animations.is_empty():
			animation = animations[0] as AnimationPlayer
			for clip: StringName in animation.get_animation_list():
				if str(clip)=="idle" or str(clip).ends_with("/idle"):
					animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
					animation.play(clip)
					break
		var label := Label3D.new()
		label.text = str(spec["name"])+"｜"+str(spec["role"])
		label.position.y = 2.0
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font = load("res://assets/fonts/SevenDistrictSansTC-Regular.otf") as Font
		label.font_size = 23
		label.pixel_size = .006
		label.visibility_range_end = 24
		actor.add_child(label)
		actors.append({"id":id,"node":actor,"animation":animation,"station":spec["home_station"]})
	life.updated.connect(_sync_cargo)
	_sync_cargo()

func apply_profile(settings: Dictionary) -> void:
	_character_distance = float(settings.get("building_distance",180))
	for actor: Dictionary in actors:
		for mesh: Node in actor["node"].find_children("*","GeometryInstance3D",true,false):
			(mesh as GeometryInstance3D).visibility_range_end = _character_distance

func _process(delta: float) -> void:
	_think += delta
	if _think<.25 or not is_instance_valid(player): return
	_think = 0
	for actor: Dictionary in actors:
		var visible_near: bool = actor["node"].global_position.distance_squared_to(player.global_position)<=_character_distance*_character_distance
		if actor["animation"]: actor["animation"].active = visible_near
		if visible_near and actor["node"].global_position.distance_to(player.global_position)<8:
			var direction: Vector3 = player.global_position-actor["node"].global_position
			if Vector2(direction.x,direction.z).length()>.4:
				actor["node"].rotation.y = atan2(direction.x,direction.z)

func _sync_cargo() -> void:
	if is_instance_valid(carried_visual):
		carried_visual.visible = false
		carried_visual.queue_free()
	carried_visual = null
	if not player or life.cargo.is_empty(): return
	var kind: String = "parcel"
	for item: Dictionary in life.definition.get("items",[]):
		if str(item["id"])==life.cargo[0]:
			kind = str(item["kind"])
			break
	var asset: String = "tw_carry_food" if kind=="food" else "tw_carry_shop" if kind in ["convenience","produce"] else "tw_carry_parcel"
	var model: PackedScene = host._model(asset)
	if model:
		carried_visual = model.instantiate() as Node3D
		carried_visual.name = "LifeCargoVisual"
		carried_visual.set_meta("cargo_asset",asset)
		carried_visual.set_meta("cargo_kind",kind)
		carried_visual.set_meta("cargo_count",life.cargo.size())
		carried_visual.position = Vector3(0,.82,.30) if kind=="food" else Vector3(-.39,.65,.05)
		player._visual_root.add_child(carried_visual)

func get_counts() -> Dictionary:
	return {"stations":station_ids.size(),"story_people":actors.size(),"cargo_visible":is_instance_valid(carried_visual)}
