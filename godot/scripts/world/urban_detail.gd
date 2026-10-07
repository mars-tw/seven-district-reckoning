class_name UrbanDetail
extends Node3D

## Original metric art overlays. There are deliberately no physics bodies here.
## Main and DistrictLife retain authority over streets, obstacles and target access.
const TEXTURES := "res://assets/textures/urban/"
const MODELS := "res://assets/models/"
var player: Node3D = null
var _startup_progress: RefCounted
var _temporary_scene_owner: Node3D
var _built: bool = false
var _groups: Dictionary = {}
var _materials: Dictionary = {}
var _instance_bounds: Array[AABB] = []
var _counts: Dictionary = {"surface_instances": 0, "kit_instances": 0, "crossings": 0, "draw_groups": 0, "missing_assets": []}

static func bootstrap(host: Node3D) -> UrbanDetail:
	var old := host.get_node_or_null("UrbanDetail")
	if old is UrbanDetail:
		return old as UrbanDetail
	var detail := UrbanDetail.new()
	detail.name = "UrbanDetail"
	host.add_child(detail)
	if not await detail.setup(): return null
	if not is_instance_valid(detail) or not detail._built: return null
	return detail

func setup(optional_player: Node3D = null) -> bool:
	player = optional_player
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if _built: return true
	_startup_progress = get_parent().get("_startup_progress")
	await _retexture_existing_terrain()
	if not _startup_running(): return false
	await _build_roads()
	if not _startup_running(): return false
	await _build_footways()
	if not _startup_running(): return false
	await _build_courts()
	if not _startup_running(): return false
	await _flush_surfaces()
	if not _startup_running(): return false
	if not _startup_running(): return false
	_built = true
	_startup_progress = null
	add_to_group("urban_detail")
	return true

func get_counts() -> Dictionary:
	return _counts.duplicate(true)

func get_bounds() -> Array[AABB]:
	# Every addition is visual; zero new blockers is part of the API contract.
	return []

func get_visual_bounds() -> Array[AABB]:
	# CPU-authored bounds are available even with Godot's dummy headless renderer.
	return _instance_bounds.duplicate()

func _material(key: String, color: Color, texture_key: String = "") -> StandardMaterial3D:
	if _materials.has(key): return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	if not texture_key.is_empty():
		var albedo := TEXTURES + "urban_" + texture_key + "_albedo.png"
		if ResourceLoader.exists(albedo):
			material.albedo_texture = load(albedo) as Texture2D
			material.albedo_color = Color.WHITE
			material.uv1_triplanar = true
			material.uv1_world_triplanar = true
			material.uv1_scale = Vector3(0.5, 0.5, 0.5)
			material.normal_enabled = true
			material.normal_texture = load(TEXTURES + "urban_" + texture_key + "_normal.png") as Texture2D
			material.normal_scale = 0.12
			material.ao_enabled = true
			material.ao_texture = load(TEXTURES + "urban_" + texture_key + "_orm.png") as Texture2D
			material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			material.roughness_texture = material.ao_texture
			material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	_materials[key] = material
	return material

func _retexture_existing_terrain() -> void:
	# Only large flat ground surfaces are retouched, never targets or actors.
	for body: Node in get_parent().get_children():
		if _startup_progress != null and not await _startup_progress.checkpoint(): return
		if not body is StaticBody3D: continue
		for child: Node in body.get_children():
			if _startup_progress != null and not await _startup_progress.checkpoint(): return
			if not child is MeshInstance3D: continue
			var visual := child as MeshInstance3D
			if not visual.mesh is BoxMesh: continue
			var size_value: Vector3 = (visual.mesh as BoxMesh).size
			if size_value.x >= 299.0 and size_value.z >= 299.0:
				visual.material_override = _material("soil", Color("72786b"))
			elif size_value.x > 30.0 and size_value.z > 30.0 and size_value.y < 0.2:
				visual.material_override = _material("pavers", Color("a19e90"), "pavers")

func _slab(key: String, position_value: Vector3, dimensions: Vector3, color: Color, texture_key: String = "", yaw: float = 0.0) -> void:
	if not _groups.has(key): _groups[key] = {"transforms": [], "material": _material(key, color, texture_key)}
	# Scale the unit box in its local axes before rotation. Global scaling would
	# swap a horizontal road's 294 m length and 15 m width at a 90-degree yaw.
	var basis := Basis(Vector3.UP, yaw)*Basis.from_scale(dimensions)
	var transform_value := Transform3D(basis, position_value)
	_groups[key]["transforms"].append(transform_value)
	_instance_bounds.append(transform_value*AABB(Vector3(-.5,-.5,-.5),Vector3.ONE))
	_counts["surface_instances"] += 1

func _road(a: Vector3, b: Vector3, width: float, y: float) -> void:
	var length_value := a.distance_to(b)
	var direction := (b-a).normalized()
	var yaw := atan2(direction.x, direction.z)
	var center := (a+b)*0.5
	center.y = y
	_slab("asphalt", center, Vector3(width, 0.012, length_value), Color("303638"), "asphalt", yaw)
	var right := Vector3(direction.z, 0.0, -direction.x)
	# Closely paired Taiwan-style yellow centre lines and white lane edge lines.
	for sign_value: float in [-1.0, 1.0]:
		if _startup_progress != null and not await _startup_progress.checkpoint(): return
		_slab("centre_yellow", center+right*0.10+Vector3(0,.009,0) if sign_value>0 else center-right*0.10+Vector3(0,.009,0), Vector3(.075,.006,length_value), Color("c5a951"), "", yaw)
		_slab("edge_white", center+right*(width*.5-.34)*sign_value+Vector3(0,.009,0),Vector3(.085,.006,length_value),Color("bdbfb6"),"",yaw)
	# Road patch repairs read at street height without expensive decals.
	for index: int in int(length_value/41.0):
		if _startup_progress != null and not await _startup_progress.checkpoint(): return
		var p := a+direction*(19.0+float(index)*41.0)+right*1.7
		p.y = y+.010
		_slab("repair", p, Vector3(1.10,.006,2.8), Color("33393a"), "", yaw)

func _crossing(p: Vector3, width: float, yaw: float, y: float) -> void:
	_counts["crossings"] += 1
	var right := Basis(Vector3.UP,yaw)*Vector3.RIGHT
	var count := int(width/.72)
	for i: int in count:
		if _startup_progress != null and not await _startup_progress.checkpoint(): return
		var point := p+right*(float(i)-float(count-1)*.5)*.72
		point.y = y
		_slab("crossing",point,Vector3(.40,.005,3.5),Color("c8c9c0"),"",yaw)

func _build_roads() -> void:
	await _road(Vector3(-147,0,0),Vector3(147,0,0),15.0,.064)
	await _road(Vector3(0,0,-147),Vector3(0,0,147),15.0,.078)
	for side: float in [-1.0, 1.0]:
		if _startup_progress != null and not await _startup_progress.checkpoint(): return
		await _road(Vector3(-80,0,side*76),Vector3(80,0,side*76),12.0,.064)
		await _road(Vector3(side*76,0,-80),Vector3(side*76,0,80),12.0,.078)
		await _road(Vector3(-137,0,side*137),Vector3(137,0,side*137),10.0,.115)
		await _road(Vector3(side*137,0,-137),Vector3(side*137,0,137),10.0,.128)
		await _road(Vector3(side*80,0,76),Vector3(side*137,0,76),10.0,.115)
		await _road(Vector3(side*76,0,80),Vector3(side*76,0,137),10.0,.115)
		await _crossing(Vector3(side*13,0,0),14.0,PI*.5,.098)
		await _crossing(Vector3(0,0,side*13),14.0,0.0,.098)
		await _crossing(Vector3(side*76,0,63),11.0,0.0,.098)
		await _crossing(Vector3(63,0,side*76),11.0,PI*.5,.098)
		await _crossing(Vector3(side*137,0,124),9.0,0.0,.145)
		await _crossing(Vector3(124,0,side*137),9.0,PI*.5,.145)
	# An opaque centre square clears previous dashed markings at the intersection.
	_slab("asphalt",Vector3(0,.092,0),Vector3(15.0,.008,15.0),Color("303638"),"asphalt")

func _build_footways() -> void:
	var segments: Array[Transform3D] = []
	for sign_value: float in [-1.0,1.0]:
		if _startup_progress != null and not await _startup_progress.checkpoint(): return
		for i: int in range(-17,18):
			if _startup_progress != null and not await _startup_progress.checkpoint(): return
			segments.append(Transform3D(Basis(Vector3.UP,PI if sign_value<0 else 0.0),Vector3(sign_value*11.0,.035,float(i)*8.0)))
			segments.append(Transform3D(Basis(Vector3.UP,PI*.5 if sign_value>0 else -PI*.5),Vector3(float(i)*8.0,.035,sign_value*11.0)))
		for i: int in range(-15,16):
			if _startup_progress != null and not await _startup_progress.checkpoint(): return
			segments.append(Transform3D(Basis(Vector3.UP,PI*.5 if sign_value<0 else -PI*.5),Vector3(float(i)*8.0,.060,sign_value*129.0)))
			segments.append(Transform3D(Basis(Vector3.UP,PI if sign_value>0 else 0.0),Vector3(sign_value*129.0,.060,float(i)*8.0)))
	await _instanced_kit("urban_sidewalk",segments,215.0)
	for sign_value: float in [-1.0,1.0]:
		if _startup_progress != null and not await _startup_progress.checkpoint(): return
		for i: int in 14:
			if _startup_progress != null and not await _startup_progress.checkpoint(): return
			var p := Vector3(sign_value*11.0,.142,-115.0+float(i)*17.0)
			for j: int in 5:
				if _startup_progress != null and not await _startup_progress.checkpoint(): return
				_slab("tree_grate",p+Vector3(0,0,float(j-2)*.14),Vector3(1.12,.006,.04),Color("4b5550"))
	# Street additions are flat and contain no collision surfaces, safe for old route loops.
	var benches: Array[Transform3D] = []
	for sign_value: float in [-1.0,1.0]:
		if _startup_progress != null and not await _startup_progress.checkpoint(): return
		for z: float in [-96.0,-62.0,-28.0,42.0,96.0]:
			if _startup_progress != null and not await _startup_progress.checkpoint(): return
			benches.append(Transform3D(Basis(Vector3.UP,sign_value*PI*.5),Vector3(sign_value*14.5,.04,z)))
	await _instanced_kit("urban_bench",benches,120.0)

func _build_courts() -> void:
	for spec: Array in [[Vector3(-102.5,.098,40),Vector3(12,.006,56)], [Vector3(108,.098,-70),Vector3(30,.006,39)], [Vector3(-1,.098,-93),Vector3(142,.006,13)], [Vector3(103,.098,35),Vector3(15,.006,47)]]:
		if _startup_progress != null and not await _startup_progress.checkpoint(): return
		_slab("pavers",spec[0],spec[1],Color("a19e90"),"pavers")
	_slab("asphalt",Vector3(104,.080,113),Vector3(36,.006,38),Color("303638"),"asphalt")
	# Resurface beneath the playable ACT006 bay; its own authored bay markings stay visible.
	for x: float in [92.0,100.0,108.0]:
		if _startup_progress != null and not await _startup_progress.checkpoint(): return
		for z: float in [124.0,129.0]:
			if _startup_progress != null and not await _startup_progress.checkpoint(): return
			_slab("parking_white",Vector3(x+3,.090,z),Vector3(.10,.005,4.2),Color("c3c5bc"))
	for p: Vector3 in [Vector3(-102.5,.105,40),Vector3(108,.105,-70),Vector3(-1,.105,-93),Vector3(103,.105,35)]:
		if _startup_progress != null and not await _startup_progress.checkpoint(): return
		# A few expansion joints break up uniformly coloured original courts.
		_slab("joint",p,Vector3(.016,.002,10),Color("72756e"))

func _flush_surfaces() -> void:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	for key: String in _groups:
		if _startup_progress != null and not await _startup_progress.checkpoint(): return
		var group: Dictionary = _groups[key]
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = cube
		instances.instance_count = group["transforms"].size()
		for i: int in instances.instance_count:
			if _startup_progress != null and not await _startup_progress.checkpoint(): return
			instances.set_instance_transform(i, group["transforms"][i])
		var draw := MultiMeshInstance3D.new()
		draw.name = "UrbanSurface_"+key
		draw.multimesh = instances
		draw.material_override = group["material"]
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(draw)
		_counts["draw_groups"] += 1

func _instanced_kit(key: String, transforms: Array[Transform3D], range_end: float) -> void:
	var path := MODELS+key+".glb"
	if not ResourceLoader.exists(path):
		_counts["missing_assets"].append(key)
		return
	var source := (load(path) as PackedScene).instantiate() as Node3D
	if not _own_temporary_scene(source): return
	var queue: Array[Node] = [source]
	while not queue.is_empty():
		if _startup_progress != null and not await _startup_progress.checkpoint(): return
		var node := queue.pop_back() as Node
		queue.append_array(node.get_children())
		if not node is MeshInstance3D: continue
		var part := node as MeshInstance3D
		var local_transform := source.global_transform.affine_inverse()*part.global_transform
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = part.mesh
		instances.instance_count = transforms.size()
		for i: int in transforms.size():
			if _startup_progress != null and not await _startup_progress.checkpoint(): return
			var transform_value := transforms[i]*local_transform
			instances.set_instance_transform(i,transform_value)
			_instance_bounds.append(transform_value*part.mesh.get_aabb())
		var draw := MultiMeshInstance3D.new()
		draw.name = key+"_"+part.name
		draw.multimesh = instances
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.visibility_range_end = range_end
		draw.visibility_range_end_margin = 15.0
		add_child(draw)
		_counts["draw_groups"] += 1
	_counts["kit_instances"] += transforms.size()
	source.free()

func _startup_running() -> bool:
	return _startup_progress == null or _startup_progress.running()
func _own_temporary_scene(source: Node3D) -> bool:
	if not _startup_running():
		source.free()
		return false
	if not is_instance_valid(_temporary_scene_owner):
		_temporary_scene_owner = Node3D.new()
		_temporary_scene_owner.name = "_StartupTemporaryScenes"
		_temporary_scene_owner.visible = false
		_temporary_scene_owner.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(_temporary_scene_owner)
		if _startup_progress != null: _startup_progress.track_temporary_root(_temporary_scene_owner)
	source.visible = false
	source.process_mode = Node.PROCESS_MODE_DISABLED
	_temporary_scene_owner.add_child(source)
	return true
