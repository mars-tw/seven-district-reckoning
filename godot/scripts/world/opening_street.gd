extends RefCounted
## R6 assembles existing CC0 Blender assets. No replacement collision geometry.
static func fit(host: Node3D, key: String, p: Vector3, size_value: Vector3, yaw: float = 0.0) -> Node3D:
	var model: Node3D = host._place(key,p)
	if not model: return null
	var bounds: AABB = host._visual_bounds(model)
	model.scale = size_value / bounds.size
	model.rotation.y = yaw
	model.set_meta("r6_opening_scenery",true)
	for mesh: Node in model.find_children("*","MeshInstance3D",true,false):
		mesh.set_meta("device_keep_visible",true)
		if key == "tw_scooter":
			for i: int in mesh.mesh.get_surface_count():
				var original := mesh.get_active_material(i) as StandardMaterial3D
				if original and original.albedo_color.g > original.albedo_color.r*1.3:
					var enamel := original.duplicate() as StandardMaterial3D
					enamel.albedo_color = Color("777d70")
					enamel.roughness = 0.56
					mesh.set_surface_override_material(i,enamel)
		if key in ["tw_arcade_shop","tw_rowhouse"]:
			for i: int in mesh.mesh.get_surface_count():
				var old := mesh.get_active_material(i) as StandardMaterial3D
				if old and ("Masonry" in old.resource_name or "Cream" in old.resource_name):
					mesh.set_surface_override_material(i,load("res://scripts/world/street_art.gd").plaster_surface())
	return model

static func dress(host: Node3D) -> bool:
	# Continuous arcade frontage replaces the visible empty west edge of the shop.
	for spec: Array in [
		["tw_arcade_shop",Vector3(-72,0,65),Vector3(16,9,8),PI],
		["tw_rowhouse",Vector3(-88,0,65),Vector3(16,12,8),PI],
		["tw_arcade_shop",Vector3(-104,0,65),Vector3(16,9,8),PI],
		["tw_rowhouse",Vector3(-32,0,65),Vector3(18,12,8),PI],
		["tw_arcade_shop",Vector3(-15,0,65),Vector3(16,9,8),PI],
		["tw_scooter",Vector3(-66,0.10,55),Vector3(0.72,1.18,1.85),0.35],
		["tw_scooter",Vector3(-47.8,0.10,57.3),Vector3(0.72,1.18,1.85),0.35],
		["tw_scooter",Vector3(-46.5,0.10,58.2),Vector3(0.72,1.18,1.85),0.35],
		["tw_scooter",Vector3(-69,0.10,54.8),Vector3(0.72,1.18,1.85),0.35],
		["tw_scooter",Vector3(-72,0.10,54.8),Vector3(0.72,1.18,1.85),0.35]]:
		fit(host,spec[0],spec[1],spec[2],spec[3])
		if not await host._startup_progress.checkpoint(): return false
	# Distant building belt: real licensed geometry, not a horizon illustration.
	for side: int in 4:
		for slot: int in 6:
			var angle: float = float(side)*PI*0.5
			var p := Vector3(-125.0+float(slot)*50.0,0,165).rotated(Vector3.UP,angle)
			fit(host,"tw_rowhouse",p,Vector3(51,18+float(slot%3)*3,14),PI+angle)
			if not await host._startup_progress.checkpoint(): return false
	# Existing asphalt and authored road-marking primitives are reused as road surfaces.
	var road := MeshInstance3D.new()
	road.name = "R6_ForecourtRoad"
	var plane := PlaneMesh.new()
	plane.size = Vector2(54,10)
	road.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/art/r7/street-asphalt.webp")
	mat.uv1_scale = Vector3(4,1,1)
	mat.albedo_color = Color("a6a09c")
	mat.roughness = 0.94
	road.material_override = mat
	road.position = Vector3(-56,0.09,39)
	host.add_child(road)
	var sidewalk := MeshInstance3D.new()
	sidewalk.name = "ShopArcadeSidewalk"
	var pavement := PlaneMesh.new()
	pavement.size = Vector2(28,2.5)
	sidewalk.mesh = pavement
	var brick := StandardMaterial3D.new()
	brick.albedo_texture = load("res://assets/art/r4/arcade-tile.webp")
	brick.uv1_scale = Vector3(4,1,1)
	brick.albedo_color = Color("b0a08a")
	brick.roughness = 0.95
	sidewalk.material_override = brick
	sidewalk.position = Vector3(-55,0.13,59.2)
	host.add_child(sidewalk)
	for i: int in 7:
		host._ground(Vector3(-64+float(i)*1.05,0.105,39),Vector3(0.58,0.01,6),Color("ddd2b6"),false)
	# Drain grates sit along the curb rather than floating props in the play lane.
	for i: int in 18:
		host._ground(Vector3(-79+float(i)*2.4,0.10,44.1),Vector3(1.9,0.01,0.19),Color("434645"),false)
		for j: int in 5:
			host._ground(Vector3(-79.7+float(i)*2.4+float(j)*0.34,0.112,44.1),Vector3(0.035,0.01,0.18),Color("a39b86"),false)
	return true

static func dress_mei(model: Node3D) -> void:
	# R9 carries a fitted, skinned apron and bob; retain only the real hand tool
	# below. Do not add the old flat donor apron over the new cloth.
	if model.find_child("MeiFittedApron",true,false):
		attach_wrench(model)
		return
	# Retain Mei's identity, face and original rig. Transfer only the existing
	# skinned apron surface from YA, which was authored from the same female base.
	var original_mesh := model.find_child("TailoredHuman",true,false) as MeshInstance3D
	var donor := (load("res://assets/models/tw_person_ya.glb") as PackedScene).instantiate() as Node3D
	var donor_mesh := donor.find_child("TailoredHuman",true,false) as MeshInstance3D
	if original_mesh and donor_mesh:
		for i: int in donor_mesh.mesh.get_surface_count():
			var source_material := donor_mesh.get_active_material(i) as StandardMaterial3D
			if not source_material or not source_material.resource_name.ends_with("_Details"): continue
			var outfit := MeshInstance3D.new()
			outfit.name = "MeiExistingSkinnedApron"
			var geometry := ArrayMesh.new()
			geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,donor_mesh.mesh.surface_get_arrays(i))
			outfit.mesh = geometry
			outfit.skin = original_mesh.skin
			outfit.skeleton = original_mesh.skeleton
			var cloth := source_material.duplicate() as StandardMaterial3D
			cloth.albedo_color = Color("b64f2f")
			cloth.albedo_texture = null
			outfit.material_override = cloth
			original_mesh.get_parent().add_child(outfit)
	donor.free()
	for node: Node in model.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		for i: int in mesh.mesh.get_surface_count():
			var old := mesh.get_active_material(i) as StandardMaterial3D
			if not old: continue
			var mat := old.duplicate() as StandardMaterial3D
			if mat.resource_name.ends_with("_Fabric"):
				mat.albedo_color = Color("8ca381")
			else: continue
			mesh.set_surface_override_material(i,mat)
	attach_wrench(model)

static func attach_wrench(model: Node3D) -> void:
	var skeletons := model.find_children("*","Skeleton3D",true,false)
	if skeletons.is_empty(): return
	var skeleton := skeletons[0] as Skeleton3D
	var hand := skeleton.find_bone("hand_r")
	if hand < 0: hand = skeleton.find_bone("hand.r")
	if hand < 0:
		for i: int in skeleton.get_bone_count():
			if "hand" in skeleton.get_bone_name(i).to_lower() and ("right" in skeleton.get_bone_name(i).to_lower() or skeleton.get_bone_name(i).to_lower().ends_with("_r")):
				hand = i
				break
	if hand < 0: return
	var socket := BoneAttachment3D.new()
	socket.name = "MeiWrenchSocket"
	socket.bone_name = skeleton.get_bone_name(hand)
	skeleton.add_child(socket)
	var wrench := (load("res://assets/models/wrench.glb") as PackedScene).instantiate() as Node3D
	wrench.name = "MeiHeldWrench"
	wrench.scale = Vector3.ONE*0.8
	wrench.rotation_degrees = Vector3(0,0,-12)
	socket.add_child(wrench)
