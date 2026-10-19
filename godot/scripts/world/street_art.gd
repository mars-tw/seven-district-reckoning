extends RefCounted
## R5 surface treatment of the existing licensed Blender kit. No collision/mesh replacement.
const PATH := "res://assets/art/r5/"
const HERO_FABRIC := preload("res://assets/art/r5/hero_fabric.gdshader")

static func surface(id: String, scale_value: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = "R5_" + id
	mat.albedo_texture = load(PATH + id + ".webp") as Texture2D
	mat.roughness = 0.86
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if scale_value > 0.0:
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3.ONE * scale_value
	return mat

static func plaster_surface() -> StandardMaterial3D:
	var plaster := StandardMaterial3D.new()
	plaster.albedo_texture = load("res://assets/art/r7/warm-plaster.webp")
	plaster.albedo_color = Color("c2b395")
	plaster.uv1_triplanar = true
	plaster.uv1_world_triplanar = true
	plaster.uv1_scale = Vector3.ONE * 0.20
	plaster.roughness = 0.94
	return plaster

static func dress_building(model: Node3D, shop: bool) -> void:
	var tile := surface("ceramic-tile", 0.13 if shop else 0.08)
	var plaster := plaster_surface()
	var glass: ShaderMaterial
	if shop:
		glass = ShaderMaterial.new()
		glass.shader = preload("res://assets/art/r5/workshop_glass.gdshader")
		glass.set_shader_parameter("window_texture",load(PATH + "workshop-window.webp"))
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for i: int in mesh.mesh.get_surface_count():
			var old := mesh.get_active_material(i) as StandardMaterial3D
			if not old: continue
			var key := old.resource_name
			if "PaleConcrete" in key:
				mesh.set_surface_override_material(i, plaster)
			elif shop and "Stone" in key:
				mesh.set_surface_override_material(i, tile)
			elif shop and "Glazing" in key:
				mesh.set_surface_override_material(i, glass)
			elif "Glazing" in key:
				var muted := old.duplicate() as StandardMaterial3D
				muted.albedo_color = Color("869394")
				muted.roughness = 0.52
				muted.metallic = 0.16
				mesh.set_surface_override_material(i, muted)

static func decal(host: Node3D, id: String, position_value: Vector3, size_value: Vector2) -> MeshInstance3D:
	var draw := MeshInstance3D.new()
	draw.name = "R5_" + id.replace("-", "_")
	var plane := QuadMesh.new()
	plane.size = size_value
	draw.mesh = plane
	draw.material_override = surface(id)
	draw.position = position_value
	draw.rotation.y = PI
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	draw.set_meta("device_keep_visible", true)
	host.add_child(draw)
	return draw

static func dress_shop(host: Node3D) -> void:
	var court := MeshInstance3D.new()
	court.name = "GarageForecourtAsphalt"
	var ground := PlaneMesh.new()
	ground.size = Vector2(28,30)
	court.mesh = ground
	court.position = Vector3(-55,0.11,47)
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_texture = load("res://assets/art/r10/forecourt-asphalt.webp")
	asphalt.albedo_color = Color("e5dcd0")
	asphalt.roughness = 0.88
	asphalt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	court.material_override = asphalt
	court.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	court.set_meta("device_keep_visible",true)
	host.add_child(court)
	var drainage := (load("res://assets/models/r10/forecourt-detail.glb") as PackedScene).instantiate() as Node3D
	drainage.name = "GarageCurbAndDrain"
	drainage.position = Vector3(-55,0.11,60.2)
	host.add_child(drainage)
	for mesh: Node in drainage.find_children("*","MeshInstance3D",true,false): mesh.set_meta("device_keep_visible",true)
	var fixtures := (load("res://assets/models/r8/garage-life.glb") as PackedScene).instantiate() as Node3D
	fixtures.name = "GarageLifeFixtures"
	fixtures.position = Vector3(-51,0.12,61.0)
	for mesh: Node in fixtures.find_children("*","MeshInstance3D",true,false): mesh.set_meta("device_keep_visible",true)
	host.add_child(fixtures)
	# Artwork attached to the existing frontage; not a new 3D asset.
	decal(host, "shop-sign", Vector3(-49.4, 3.72, 60.94), Vector2(5.2, 1.73))
	decal(host, "rolling-shutter", Vector3(-46.7, 2.35, 60.75), Vector2(3.4, 4.5))
	var lamp := OmniLight3D.new()
	lamp.name = "R5_WorkshopPractical"
	lamp.position = Vector3(-52, 3.0, 58.8)
	lamp.light_color = Color("ffcb85")
	lamp.light_energy = 0.72
	lamp.omni_range = 7.0
	lamp.shadow_enabled = false
	host.add_child(lamp)
	var workbench := (load("res://assets/models/r10/mei-workbench.glb") as PackedScene).instantiate() as Node3D
	workbench.name = "MeiToolWorkbench"
	workbench.position = Vector3(-54,0.06,58.5)
	workbench.rotation.y = PI
	for mesh: Node in workbench.find_children("*","MeshInstance3D",true,false): mesh.set_meta("device_keep_visible",true)
	host.add_child(workbench)
	var bench_shadow := preload("res://scripts/world/contact_shadow.gd").new()
	bench_shadow.name = "WorkbenchContactShadow"
	bench_shadow.position = Vector3(-54,0.17,58.5)
	bench_shadow.scale = Vector3(2.4,1,1.25)
	host.add_child(bench_shadow)
	for spec: Array in [[Vector3(-54,0,58.5),Vector3(2.4,1,1.25)],[Vector3(-49,0,60.6),Vector3(5.8,1,.75)],[Vector3(-58,0,60.6),Vector3(5.8,1,.75)]]:
		var contact := preload("res://scripts/world/contact_shadow.gd").new()
		contact.name = "GarageBaseContact"
		contact.position = spec[0]
		contact.scale = spec[1]
		host.add_child(contact)
	preload("res://scripts/world/opening_street.gd").fit(host,"bicycle",Vector3(-52.7,0.10,59.2),Vector3(1.7,1.05,0.48),PI*0.5)

static func dress_hero(model: Node) -> void:
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for i: int in mesh.mesh.get_surface_count():
			var old := mesh.get_active_material(i) as StandardMaterial3D
			if not old: continue
			if old.resource_name.ends_with("_Fabric"):
				var cloth := ShaderMaterial.new()
				cloth.shader = preload("res://assets/art/r7/hero_fabric.gdshader")
				cloth.set_shader_parameter("fabric_texture", old.albedo_texture)
				mesh.set_surface_override_material(i, cloth)
			elif old.resource_name.ends_with("_Shoes"):
				var shoes := old.duplicate() as StandardMaterial3D
				shoes.albedo_color = Color("ddd9cb")
				shoes.albedo_texture = null
				mesh.set_surface_override_material(i, shoes)

static func dress_counter(model: Node3D) -> void:
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for i: int in mesh.mesh.get_surface_count():
			var old := mesh.get_active_material(i) as StandardMaterial3D
			if not old: continue
			var mat := old.duplicate() as StandardMaterial3D
			mat.albedo_color = Color("644734") if "wood" in old.resource_name else Color("424a49")
			mat.roughness = 0.86
			mesh.set_surface_override_material(i,mat)
