class_name TaiwanExpansion
extends Node3D

## The old 300 m core keeps its terrain, objects, actors and save IDs. This
## module supplies the surrounding 800 m neighbourhood with real terrain,
## clear roads and the original metric Blender kit. It contains no task state.
const DATA_PATH := "res://data/taiwan_expansion.json"
const MODEL_DIR := "res://assets/models/"
const SECTOR_SIZE := 90.0
const WORLD_LIMIT := 400.0
var player: Node3D = null
var _built := false
var _regions: Array[Dictionary] = []
var _stations: Dictionary = {}
var _roads: Array[Dictionary] = []
var _obstacles: Array[AABB] = []
var _visual_bounds: Array[AABB] = []
var _mesh_cache: Dictionary = {}
var _mesh_bounds: Dictionary = {}
var _asset_manifest: Dictionary = {}
var _asset_groups: Dictionary = {}
var _surface_groups: Dictionary = {}
var _sector_bodies: Dictionary = {}
var _draws: Array[Dictionary] = []
var _materials: Dictionary = {}
var _night_materials: Array[StandardMaterial3D] = []
var _labels: Array[Label3D] = []
var _font: Font = null
var _view_distance := 440.0
var _prop_distance := 180.0
var _hour := 12.0
var citizens: Array[Dictionary] = []
var traffic: Array[Dictionary] = []
var clock := 0.0
var _think_clock := 0.0
var _attack_callback: Callable
var _counts: Dictionary = {"regions":0,"stations":0,"terrain_bodies":0,"terrain_area_m2":550000.0,"roads":0,"surface_instances":0,"asset_instances":0,"draw_groups":0,"collider_sectors":0,"collider_shapes":0,"lod_levels":0,"missing_assets":[],"assets":{}}

static func bootstrap(host: Node3D, optional_player: Node3D = null) -> TaiwanExpansion:
	var previous := host.get_node_or_null("TaiwanExpansion")
	if previous is TaiwanExpansion:
		if optional_player!=null: (previous as TaiwanExpansion).setup(optional_player)
		return previous as TaiwanExpansion
	var expansion := TaiwanExpansion.new()
	expansion.name = "TaiwanExpansion"
	host.add_child(expansion)
	expansion.setup(optional_player)
	return expansion

func setup(optional_player: Node3D = null) -> void:
	if is_instance_valid(player) and _attack_callback.is_valid() and player.has_signal("attacked") and player.is_connected("attacked",_attack_callback): player.disconnect("attacked",_attack_callback)
	player = optional_player
	_attack_callback = Callable(self,"_on_player_attack")
	if is_instance_valid(player) and player.has_signal("attacked"): player.connect("attacked",_attack_callback)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if _built: return
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not source is Dictionary:
		push_error("TaiwanExpansion data missing")
		return
	for region: Dictionary in source.get("regions", []): _regions.append(region.duplicate(true))
	for id: String in source.get("stations", {}): _stations[id] = _v2(source["stations"][id])
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(source["asset_manifest"])))
	if manifest is Dictionary:
		for asset: Dictionary in manifest.get("assets", []): _asset_manifest[str(asset["name"])] = asset
	_font = load("res://assets/fonts/SevenDistrictSansTC-Regular.otf") as Font
	_build_terrain()
	_build_roads()
	for region: Dictionary in _regions: _build_region(region)
	_build_connecting_frontages()
	_flush_batches()
	_create_ambient_actors()
	_counts["regions"] = _regions.size()
	_counts["stations"] = _stations.size()
	_counts["roads"] = _roads.size()
	_counts["collider_sectors"] = _sector_bodies.size()
	_counts["citizens"] = citizens.size()
	_counts["moving_vehicles"] = traffic.size()
	_built = true
	add_to_group("taiwan_expansion")
	apply_profile({"view_distance":_view_distance,"prop_distance":_prop_distance})
	set_hour(_hour)

func get_regions() -> Array[Dictionary]: return _regions.duplicate(true)
func get_station_positions() -> Dictionary: return _stations.duplicate()
func get_obstacle_bounds() -> Array[AABB]: return _obstacles.duplicate()
func get_navigation_roads() -> Array[Dictionary]: return _roads.duplicate(true)
func get_visual_bounds() -> Array[AABB]: return _visual_bounds.duplicate()
func get_counts() -> Dictionary: return _counts.duplicate(true)

func is_walkable(p: Vector3, radius: float = 0.45) -> bool:
	if not p.is_finite() or not is_finite(radius) or radius < 0 or absf(p.x)+radius >= WORLD_LIMIT or absf(p.z)+radius >= WORLD_LIMIT: return false
	for obstacle: AABB in _obstacles:
		if obstacle.grow(radius).has_point(Vector3(p.x,obstacle.position.y+minf(.7,obstacle.size.y*.5),p.z)): return false
	return true

func apply_profile(profile: Dictionary) -> void:
	_view_distance = clampf(float(profile.get("view_distance", profile.get("viewer_distance",profile.get("building_distance",440.0)))),150.0,600.0)
	_prop_distance = clampf(float(profile.get("prop_distance",profile.get("prop_budget",180.0))),50.0,300.0)
	for draw_info: Dictionary in _draws:
		var draw := draw_info["node"] as GeometryInstance3D
		# Each draw's origin and instance transforms are local to a 90 m sector.
		# The margin accounts for a sector's corner without showing all 800 m.
		draw.visibility_range_end = _view_distance if bool(draw_info["large"]) else _prop_distance+50.0
		draw.visibility_range_end_margin = 20.0
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(draw_info["cast_asset_shadow"]) and bool(profile.get("world_shadows",profile.get("shadows",false))) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for label: Label3D in _labels:
		label.visibility_range_end = minf(_prop_distance,140.0)
		label.visibility_range_end_margin = 12.0
	_counts["view_distance"] = _view_distance
	_counts["prop_distance"] = _prop_distance

func set_hour(hour: float) -> void:
	if not is_finite(hour): return
	_hour = fposmod(hour,24.0)
	var night := _hour >= 17.5 or _hour < 6.0
	for material: StandardMaterial3D in _night_materials:
		material.emission_enabled = night
		material.emission_energy_multiplier = 0.85 if night else 0.0
	_counts["night_lanterns"] = night

func _v2(p: Array) -> Vector3: return Vector3(float(p[0]),0,float(p[1]))
func _v3(p: Array) -> Vector3: return Vector3(float(p[0]),float(p[1]),float(p[2]))
func _sector(p: Vector3) -> Vector2i: return Vector2i(floori(p.x/SECTOR_SIZE),floori(p.z/SECTOR_SIZE))
func _sector_origin(sector: Vector2i) -> Vector3: return Vector3((float(sector.x)+.5)*SECTOR_SIZE,0,(float(sector.y)+.5)*SECTOR_SIZE)
func _sector_key(sector: Vector2i) -> String: return "%d_%d" % [sector.x,sector.y]

func _material(key: String,color: Color,texture_key: String = "") -> StandardMaterial3D:
	if _materials.has(key): return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .94
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if not texture_key.is_empty():
		var path := "res://assets/textures/taiwan/tw_"+texture_key+"_albedo.png"
		if ResourceLoader.exists(path):
			material.albedo_texture = load(path) as Texture2D
			material.albedo_color = Color.WHITE
			material.uv1_triplanar = true
			material.uv1_world_triplanar = true
			material.uv1_scale = Vector3(.5,.5,.5)
	_materials[key] = material
	return material

func _build_terrain() -> void:
	# Four nonoverlapping plates meet the original 300 m floor at exactly ±150.
	# Physics uses four bodies, instead of one body per street decoration.
	for spec: Array in [[Vector3(0,-.16,-275),Vector3(800,.30,250)], [Vector3(0,-.16,275),Vector3(800,.30,250)], [Vector3(-275,-.16,0),Vector3(250,.30,300)], [Vector3(275,-.16,0),Vector3(250,.30,300)]]:
		var body := StaticBody3D.new()
		body.name = "ExpansionTerrain_%d" % int(_counts["terrain_bodies"])
		body.position = spec[0]
		body.collision_layer = 1
		body.collision_mask = 2
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = spec[1]
		collision.shape = shape
		body.add_child(collision)
		var draw := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = spec[1]
		draw.mesh = mesh
		draw.material_override = _material("soil",Color("718069"))
		draw.set_meta("device_keep_visible",true)
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(draw)
		add_child(body)
		_counts["terrain_bodies"] += 1

func _slab(key: String,p: Vector3,size: Vector3,color: Color,texture: String = "",yaw: float = 0.0,large: bool = true) -> void:
	var sector := _sector(p)
	# Solid road markings and rails use per-instance colour on a shared PBR
	# material. Avoid an independent batch for each paint colour in a sector.
	var shared_key := "paint" if texture.is_empty() else "texture_"+texture
	var group_key := _sector_key(sector)+":"+shared_key+("_large" if large else "_prop")
	if not _surface_groups.has(group_key):
		var shared_material := _material(shared_key,Color.WHITE,texture)
		shared_material.vertex_color_use_as_albedo = texture.is_empty()
		_surface_groups[group_key] = {"sector":sector,"material":shared_material,"transforms":[],"colors":[],"large":large,"use_colors":texture.is_empty()}
	var transform_value := Transform3D(Basis(Vector3.UP,yaw)*Basis.from_scale(size),p-_sector_origin(sector))
	_surface_groups[group_key]["transforms"].append(transform_value)
	_surface_groups[group_key]["colors"].append(color)
	_visual_bounds.append(Transform3D(Basis(Vector3.UP,yaw)*Basis.from_scale(size),p)*AABB(Vector3(-.5,-.5,-.5),Vector3.ONE))
	_counts["surface_instances"] += 1

func _road(a: Vector3,b: Vector3,width: float,id: String) -> void:
	_roads.append({"id":id,"a":[a.x,a.z],"b":[b.x,b.z],"width":width,"surface_y":.055})
	var length := a.distance_to(b)
	var direction := (b-a).normalized()
	var right := Vector3(direction.z,0,-direction.x)
	var yaw := atan2(direction.x,direction.z)
	var count := maxi(1,ceili(length/75.0))
	for i: int in count:
		var segment_length := length/float(count)
		var p := a+direction*(float(i)+.5)*segment_length
		p.y = .052
		_slab("asphalt",p,Vector3(width,.016,segment_length+.03),Color("303638"),"asphalt",yaw)
		for side: float in [-1,1]:
			_slab("lane_yellow",p+right*.12*side+Vector3(0,.013,0),Vector3(.08,.007,segment_length),Color("d0b861"),"",yaw)
			_slab("lane_white",p+right*(width*.5-.35)*side+Vector3(0,.013,0),Vector3(.09,.007,segment_length),Color("d6d6c9"),"",yaw)
			var pavement := p+right*(width*.5+2.1)*side
			pavement.y=.043
			_slab("footway",pavement,Vector3(4.0,.035,segment_length+.03),Color("b6ac92"),"pavers",yaw)
			_slab("red_kerb",p+right*(width*.5+.18)*side+Vector3(0,.012,0),Vector3(.20,.025,segment_length),Color("ae5d4c"),"",yaw)
		for mark: int in int(segment_length/12.0):
			var q := p+direction*(-segment_length*.5+float(mark)*12+5)
			_slab("lane_dash",q+right*3.0+Vector3(0,.014,0),Vector3(.08,.007,4),Color("d8d7c8"),"",yaw)

func _crossing(p: Vector3,axis: float) -> void:
	var right := Basis(Vector3.UP,axis)*Vector3.RIGHT
	for i: int in 13: _slab("crossing",p+right*(float(i)-6)*.75+Vector3(0,.076,0),Vector3(.4,.006,3.5),Color("dedbca"),"",axis)

func _build_roads() -> void:
	for value: float in [-380,-270,270,380]:
		_road(Vector3(-396,0,value),Vector3(396,0,value),12,"east_west_%d"%int(value))
		_road(Vector3(value,0,-396),Vector3(value,0,396),12,"north_south_%d"%int(value))
	# Main's original cardinal roads meet these at ±137, then reach both rings.
	for side: float in [-1,1]:
		_road(Vector3(side*137,0,0),Vector3(side*396,0,0),14,"core_east" if side>0 else "core_west")
		_road(Vector3(0,0,side*137),Vector3(0,0,side*396),14,"core_south" if side>0 else "core_north")
	for region: Dictionary in _regions:
		var p := _v2(region["marker"])
		for side: float in [-1,1]:
			_crossing(p+Vector3(side*18,0,0),PI*.5)
			_crossing(p+Vector3(0,0,side*18),0)
	# Four perpendicular inner-ring spurs create a second continuous path to core.
	for side: float in [-1,1]:
		_road(Vector3(side*137,0,-137),Vector3(side*270,0,-137),10,"north_spur_%d"%int(side))
		_road(Vector3(-137,0,side*137),Vector3(-137,0,side*270),10,"west_spur_%d"%int(side))
	for x: float in [-380,-270,270,380]:
		for z: float in [-380,-270,270,380]:
			_slab("asphalt",Vector3(x,.073,z),Vector3(12.2,.012,12.2),Color("303638"),"asphalt")
	for region: Dictionary in _regions:
		var p := _v2(region["marker"])
		_slab("asphalt",p+Vector3(0,.073,0),Vector3(14.2,.012,14.2),Color("303638"),"asphalt")
		for side: float in [-1,1]:
			_slab("stop_line",p+Vector3(side*10,.080,3),Vector3(.25,.006,5.0),Color("dddccc"))
			_slab("stop_line",p+Vector3(3,.080,side*10),Vector3(5.0,.006,.25),Color("dddccc"))

func _build_region(region: Dictionary) -> void:
	var p := _v2(region["marker"])
	var kind := str(region["kind"])
	# All 32 task stations are within a deliberately level, unobstructed court.
	_slab("district_court",p+Vector3(0,.032,0),Vector3(38,.025,38),Color("b9ab8e"),"pavers")
	_sign(str(region["name"]),p+Vector3(-17,3.65,17),Color(str(region["color"])),PI*.25)
	if kind=="community" or kind=="river":
		_build_green_region(p,kind)
		return
	# Developed blocks have continuous paved ground in front of the stores;
	# the grassy open land remains in the park/river districts and outer edge.
	for x: float in [-40,0,40]:
		for z: float in [-40,0,40]: _slab("district_court",p+Vector3(x,.032,z),Vector3(40,.025,40),Color("b9ab8e"),"pavers")
	for offset: Vector3 in [Vector3(-21,0,-21),Vector3(21,0,-21),Vector3(-21,0,21),Vector3(21,0,21)]:
		_asset("tree",p+offset,0,false,Vector3.ONE*.90)
	for offset: Vector3 in [Vector3(-10,0,-23),Vector3(10,0,-23),Vector3(-10,0,23),Vector3(10,0,23),Vector3(-23,0,-10),Vector3(-23,0,10),Vector3(23,0,-10),Vector3(23,0,10)]: _asset("streetlight",p+offset,atan2(-offset.x,-offset.z),false)
	# Building rows are on opposite sides of a 42 m forecourt; front arcades face
	# the court. Road intersections and each ±15 m station zone remain clear.
	for side: float in [-1,1]:
		for offset: float in [-48,-36,-24,24,36,48]:
			var key := "tw_arcade_shop" if kind in ["arcade","creative","market"] else "tw_rowhouse"
			_asset(key,p+Vector3(offset,0,side*38),0 if side<0 else PI,true)
			_asset("tw_scooter",p+Vector3(offset-3,0,side*28),side*PI*.5,false)
			for mark: int in 3: _slab("scooter_bay",p+Vector3(offset-4+mark, .074,side*29),Vector3(.06,.006,2.2),Color("dfdccb"),"",0,false)
		for offset: float in [-44,-30,30,44]:
			_asset("tw_rowhouse",p+Vector3(side*51,0,offset),side*-PI*.5,true)
	if kind=="market":
		for side: float in [-1,1]:
			for offset: float in [-24,-18,-12,12,18,24]: _asset("tw_market_stall",p+Vector3(side*26,0,offset),-side*PI*.5,false)
		_asset("tw_breakfast_stall",p+Vector3(-23,0,-21),PI*.25,false)
		_sign("晨間蔬果・早餐",p+Vector3(-26,2.9,-15),Color("be975e"),-PI*.5)
	elif kind=="night_market":
		for side: float in [-1,1]:
			for offset: float in [-24,-18,-12,12,18,24]: _asset("tw_food_stall" if int(offset)%12==0 else "tw_breakfast_stall",p+Vector3(side*26,0,offset),-side*PI*.5,false)
		_asset("tw_lantern_gate",p+Vector3(-26,0,-30),0,false)
		_asset("tw_lantern_gate",p+Vector3(26,0,30),0,false)
		_sign("南星小吃・夜間市集",p+Vector3(-26,4.05,-30),Color("c56a45"))
	elif kind=="convenience":
		_asset("tw_convenience",p+Vector3(-26,0,-26),0,true)
		_asset("tw_bus_shelter",p+Vector3(24,0,24),-PI*.5,false)
		_asset("tw_parcel_shelf",p+Vector3(-23,0,-20),0,false)
		_sign("日常便利\n便當・列印・取件",p+Vector3(-26,3.3,-20),Color("58999a"))
	elif kind=="parcel":
		_asset("tw_parcel_station",p+Vector3(-26,0,-26),0,true)
		for x: float in [-32,-30,-22,-20]: _asset("tw_parcel_shelf",p+Vector3(x,0,-20),0,false)
		_asset("tw_bus_shelter",p+Vector3(24,0,24),-PI*.5,false)
		_sign("橘盒取貨站\n收件・寄件・退貨",p+Vector3(-26,3.3,-20),Color("d58a4c"))
	elif kind=="arcade":
		_asset("tw_breakfast_stall",p+Vector3(-23,0,-21),PI*.25,false)
		_asset("tw_lantern_gate",p+Vector3(-26,0,-26),0,false)
		_slab("brick_lane",p+Vector3(0,.073,21),Vector3(40,.006,3),Color("a47760"))
		_sign("犁光騎樓老街\n騎樓請留行人通道",p+Vector3(-26,4,-26),Color("ad7866"))
	elif kind=="creative":
		for x: float in [-26,26]:
			_asset("tw_market_stall",p+Vector3(x,0,-10),-signf(x)*PI*.5,false)
			_asset("tw_food_stall",p+Vector3(x,0,10),-signf(x)*PI*.5,false)
		_asset("tw_lantern_gate",p+Vector3(-26,0,-25),0,false)
		_sign("紙光文創聚落\n手作・街角演出",p+Vector3(-26,4,-25),Color("ad9a70"))

func _build_green_region(p: Vector3,kind: String) -> void:
	for side: float in [-1,1]:
		for i: int in 6:
			var z := float(i-2)*12-6
			_asset("tree",p+Vector3(side*39,0,z),0,false,Vector3.ONE*1.30)
			_asset("urban_bench",p+Vector3(side*27,0,z),-side*PI*.5,false)
		_slab("green_path",p+Vector3(side*26,.056,0),Vector3(4,.025,100),Color("c2bca0"),"pavers")
	_asset("tw_river_pavilion",p+Vector3(-25,0,-27),0,true)
	for x: float in [-2.5,2.5]:
		for z: float in [-2.5,2.5]: _collision(p+Vector3(-25+x,1.45,-27+z),Vector3(.20,2.9,.20))
	if kind=="community":
		_asset("tw_recycling_station",p+Vector3(25,0,27),PI,false)
		_asset("tw_arcade_shop",p+Vector3(-53,0,-26),PI*.5,true)
		_asset("tw_convenience",p+Vector3(53,0,26),-PI*.5,true)
		_sign("青蔭里活動場\n回收・共餐・綠廊散步",p+Vector3(0,3.6,-24),Color("799a66"))
	else:
		# Water is a visible side-channel west of the path. The level riverbank
		# is fenced; it never lies across the stations or the cardinal roads.
		_slab("river_water",p+Vector3(-67,.01,0),Vector3(10,.022,130),Color("648d8c"))
		for i: int in 14:
			var z := float(i)*9-58.5
			_slab("river_rail",p+Vector3(-59,1.05,z),Vector3(.06,.08,9),Color("687877"),"",0,false)
			_slab("river_rail_low",p+Vector3(-59,.55,z),Vector3(.06,.055,9),Color("687877"),"",0,false)
			_slab("river_post",p+Vector3(-59,.65,z-4.5),Vector3(.08,1.30,.08),Color("687877"),"",0,false)
		_collision(p+Vector3(-59,.7,0),Vector3(.20,1.4,131))
		for i: int in 4:
			_asset("bicycle",p+Vector3(-24,0,-26+float(i)*2.5),PI*.5,false)
		_sign("澄川河岸\n自行車道・休憩步道",p+Vector3(0,3.6,-24),Color("659294"))

func _build_connecting_frontages() -> void:
	# The trip between the preserved core and new districts has successive
	# actual shop fronts, lamps and planting, rather than only distant boxes.
	for side: float in [-1,1]:
		for value: float in [169,190,211,232]:
			for row: float in [-1,1]:
				_asset("tw_rowhouse",Vector3(side*value,0,row*25),row*PI if row>0 else 0,true)
				_asset("tw_arcade_shop",Vector3(row*25,0,side*value),row*-PI*.5,true)
				_asset("streetlight",Vector3(side*value,0,row*10),side*PI*.5,false)
				_asset("streetlight",Vector3(row*10,0,side*value),0,false)
				_asset("tw_scooter",Vector3(side*value+4,0,row*14),PI*.5,false)
	for region: Dictionary in _regions:
		var p := _v2(region["marker"])
		for offset: Vector3 in [Vector3(-65,0,-65),Vector3(65,0,-65),Vector3(-65,0,65),Vector3(65,0,65)]:
			_asset("streetlight",p+offset,0,false)
			_asset("tree",p+offset+Vector3(3,0,3),0,false)

func _asset(key: String,p: Vector3,yaw: float = 0.0,large: bool = false,scale_value: Vector3 = Vector3.ONE) -> void:
	var mesh := _mesh(key)
	if mesh==null: return
	var sector := _sector(p)
	var group_key := _sector_key(sector)+":"+key
	if not _asset_groups.has(group_key): _asset_groups[group_key] = {"sector":sector,"key":key,"mesh":mesh,"transforms":[],"large":large}
	var basis := Basis(Vector3.UP,yaw)*Basis.from_scale(scale_value)
	_asset_groups[group_key]["transforms"].append(Transform3D(basis,p-_sector_origin(sector)))
	_visual_bounds.append(Transform3D(basis,p)*(_mesh_bounds[key] as AABB))
	_counts["asset_instances"] += 1
	_counts["assets"][key] = int(_counts["assets"].get(key,0))+1
	for box: Array in _asset_manifest.get(key,{}).get("collision_boxes",[]):
		_collision(p+basis*_v3(box[0]),_v3(box[1])*scale_value,yaw)
	if key=="tree": _collision(p+Vector3(0,.9,0),Vector3(.55,1.8,.55)*scale_value)

func _mesh(key: String) -> ArrayMesh:
	if _mesh_cache.has(key): return _mesh_cache[key]
	var path := MODEL_DIR+key+".glb"
	if not ResourceLoader.exists(path):
		if not _counts["missing_assets"].has(key): _counts["missing_assets"].append(key)
		return null
	var source := (load(path) as PackedScene).instantiate() as Node3D
	# Imported meshes share source space; bake source transforms, retain UVs
	# and normals, then one MultiMesh per kit per spatial sector.
	var merged := ArrayMesh.new()
	var queue: Array[Node] = [source]
	var transforms: Dictionary = {source.get_instance_id():Transform3D.IDENTITY}
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		var parent_transform: Transform3D = transforms[node.get_instance_id()]
		for child: Node in node.get_children():
			transforms[child.get_instance_id()] = parent_transform*(child.transform if child is Node3D else Transform3D.IDENTITY)
			queue.append(child)
		if not node is MeshInstance3D: continue
		var part := node as MeshInstance3D
		if part.mesh==null: continue
		for surface: int in part.mesh.get_surface_count():
			var arrays := part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i: int in vertices.size(): vertices[i] = parent_transform*vertices[i]
			arrays[Mesh.ARRAY_VERTEX] = vertices
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var normal_basis := parent_transform.basis.inverse().transposed()
			for i: int in normals.size(): normals[i] = (normal_basis*normals[i]).normalized()
			arrays[Mesh.ARRAY_NORMAL] = normals
			# Preserve Godot's imported topology LOD index buffers. Transforming
			# positions does not change the original vertex/index correspondence.
			var lods: Dictionary = {}
			var imported_surface := RenderingServer.mesh_get_surface(part.mesh.get_rid(),surface)
			for lod: Dictionary in imported_surface.get("lods",[]):
				var bytes: PackedByteArray = lod.get("index_data",PackedByteArray())
				var stride := 2 if vertices.size()<=65536 else 4
				var indices := PackedInt32Array()
				indices.resize(bytes.size()/stride)
				for index: int in indices.size(): indices[index] = bytes.decode_u16(index*stride) if stride==2 else bytes.decode_u32(index*stride)
				if not indices.is_empty():
					lods[float(lod["edge_length"])] = indices
					_counts["lod_levels"] += 1
			merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],lods)
			var material := part.get_active_material(surface)
			if material is StandardMaterial3D: (material as StandardMaterial3D).texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			if key=="tw_lantern_gate" and material is StandardMaterial3D and str(material.resource_name).contains("Accent"):
				material = material.duplicate() as StandardMaterial3D
				(material as StandardMaterial3D).emission = Color("e6a365")
				_night_materials.append(material as StandardMaterial3D)
			merged.surface_set_material(merged.get_surface_count()-1,material)
	source.free()
	_mesh_cache[key] = merged
	_mesh_bounds[key] = merged.get_aabb()
	return merged

func _collision(p: Vector3,size: Vector3,yaw: float = 0.0) -> void:
	var sector := _sector(p)
	var key := _sector_key(sector)
	if not _sector_bodies.has(key):
		var body := StaticBody3D.new()
		body.name = "TaiwanSolids_"+key
		body.collision_layer = 1
		body.collision_mask = 2
		body.position = _sector_origin(sector)
		add_child(body)
		_sector_bodies[key] = body
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position = p-_sector_origin(sector)
	collider.rotation.y = yaw
	(_sector_bodies[key] as StaticBody3D).add_child(collider)
	_obstacles.append(Transform3D(Basis(Vector3.UP,yaw),p)*AABB(-size*.5,size))
	_counts["collider_shapes"] += 1

func _flush_batches() -> void:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	for groups: Dictionary in [_surface_groups,_asset_groups]:
		for key: String in groups:
			var group: Dictionary = groups[key]
			var instances := MultiMesh.new()
			instances.transform_format = MultiMesh.TRANSFORM_3D
			instances.use_colors = bool(group.get("use_colors",false))
			instances.mesh = group.get("mesh",cube)
			instances.instance_count = group["transforms"].size()
			for index: int in instances.instance_count:
				instances.set_instance_transform(index,group["transforms"][index])
				if instances.use_colors: instances.set_instance_color(index,group["colors"][index])
			var draw := MultiMeshInstance3D.new()
			draw.name = "TaiwanBatch_"+key.replace(":","_")
			draw.position = _sector_origin(group["sector"])
			draw.multimesh = instances
			if group.has("material"): draw.material_override = group["material"]
			draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			draw.set_meta("device_world_sector",true)
			draw.set_meta("device_geometry_kind","terrain" if group.has("material") and bool(group["large"]) else ("landmark" if bool(group["large"]) else "prop"))
			add_child(draw)
			_draws.append({"node":draw,"large":group["large"],"sector":group["sector"],"cast_asset_shadow":bool(group["large"]) and group.has("mesh")})
			_counts["draw_groups"] += 1
	# Construction-only lists are no longer needed after CPU bounds are stored.
	_asset_groups.clear()
	_surface_groups.clear()

func _sign(caption: String,p: Vector3,color: Color,yaw: float = 0.0) -> void:
	var label := Label3D.new()
	label.text = caption
	label.font = _font
	label.font_size = 34
	label.pixel_size = .015
	label.position = p
	label.rotation.y = yaw
	label.modulate = Color("f2ebd8")
	label.outline_modulate = color.darkened(.62)
	label.outline_size = 6
	label.no_depth_test = false
	add_child(label)
	_labels.append(label)

func _find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node as AnimationPlayer
	for child: Node in node.get_children():
		var result := _find_animation(child)
		if result!=null: return result
	return null

func _find_wheels(node: Node,output: Array[Node3D]) -> void:
	if node is MeshInstance3D and str(node.name).to_lower().contains("wheel"): output.append(node as Node3D)
	for child: Node in node.get_children(): _find_wheels(child,output)

func _actor_model(key: String) -> Node3D:
	var path := MODEL_DIR+key+".glb"
	if not ResourceLoader.exists(path):
		if not _counts["missing_assets"].has(key): _counts["missing_assets"].append(key)
		return null
	var model := (load(path) as PackedScene).instantiate() as Node3D
	return model

func _create_ambient_actors() -> void:
	for region: Dictionary in _regions:
		var center := _v2(region["marker"])
		var route: Array[Vector3] = [center+Vector3(-18,.10,-18),center+Vector3(18,.10,-18),center+Vector3(18,.10,18),center+Vector3(-18,.10,18)]
		for index: int in 2:
			var model := _actor_model("civilian_human" if index==0 else "zhou_human")
			if model==null: continue
			var body := CharacterBody3D.new()
			body.name = "TaiwanCitizen_"+str(region["id"])+"_"+str(index)
			body.position = route[index*2]
			body.collision_layer = 2
			body.collision_mask = 1
			body.floor_snap_length = .3
			body.add_to_group("ambient_citizens")
			var collision := CollisionShape3D.new()
			var shape := CapsuleShape3D.new()
			shape.radius = .28
			shape.height = 1.72
			collision.shape = shape
			collision.position.y = .86
			body.add_child(collision)
			body.add_child(model)
			add_child(body)
			var animation := _find_animation(model)
			var clips: Dictionary = {}
			if animation!=null:
				for clip: StringName in animation.get_animation_list():
					for request: String in ["walk","run"]:
						if str(clip).to_lower()==request or str(clip).to_lower().ends_with("/"+request): clips[request] = clip
				if clips.has("walk"):
					animation.get_animation(clips["walk"]).loop_mode = Animation.LOOP_LINEAR
					animation.play(clips["walk"])
					animation.advance(float(index)*.17)
				if clips.has("run"): animation.get_animation(clips["run"]).loop_mode = Animation.LOOP_LINEAR
			citizens.append({"body":body,"model":model,"animation":animation,"clips":clips,"route":route,"waypoint":index*2+1,"step":1,"speed":1.05+float(index)*.15,"flee_until":0.0,"region":region["id"]})
	var route: Array[Vector3] = [Vector3(-380,.08,-380),Vector3(380,.08,-380),Vector3(380,.08,380),Vector3(-380,.08,380)]
	for index: int in 4:
		var model := _actor_model("car")
		if model==null: continue
		model.name = "TaiwanTraffic_%d"%index
		model.position = route[index].lerp(route[(index+1)%4],.42)
		var direction := (route[(index+1)%4]-model.position).normalized()
		model.rotation.y = atan2(direction.x,direction.z)
		add_child(model)
		model.add_to_group("ambient_traffic")
		var sensor := Area3D.new()
		sensor.collision_layer = 0
		sensor.collision_mask = 2
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(3.4,2.6,8)
		collision.shape = shape
		collision.position = Vector3(0,1.1,5)
		sensor.add_child(collision)
		model.add_child(sensor)
		var wheels: Array[Node3D] = []
		_find_wheels(model,wheels)
		traffic.append({"model":model,"route":route,"waypoint":(index+1)%4,"sensor":sensor,"wheels":wheels,"speed":0.0,"cruise_speed":7.0+float(index)*.3,"stopped":false})

func _on_player_attack(_weapon: String,_mode: String = "") -> void:
	if not is_instance_valid(player): return
	for citizen: Dictionary in citizens:
		var body := citizen["body"] as CharacterBody3D
		if body.global_position.distance_to(player.global_position)<12 and bool(body.get_meta("device_budget_active",true)):
			citizen["flee_until"] = clock+4
			var route: Array = citizen["route"]
			var next := int(citizen["waypoint"])
			var previous := posmod(next-2*int(citizen["step"]),route.size())
			if (route[previous] as Vector3).distance_to(player.position)>(route[next] as Vector3).distance_to(player.position):
				citizen["step"] = -int(citizen["step"])
				citizen["waypoint"] = previous

func _physics_process(delta: float) -> void:
	if not _built: return
	clock += delta
	_think_clock += delta
	for citizen: Dictionary in citizens:
		var body := citizen["body"] as CharacterBody3D
		var active := bool(body.get_meta("device_budget_active",true))
		var animation := citizen["animation"] as AnimationPlayer
		if animation!=null: animation.active = active
		if not active:
			body.velocity = Vector3.ZERO
			continue
		var route: Array = citizen["route"]
		var target: Vector3 = route[int(citizen["waypoint"])]
		var difference := Vector3(target.x-body.position.x,0,target.z-body.position.z)
		if difference.length()<.28:
			citizen["waypoint"] = posmod(int(citizen["waypoint"])+int(citizen["step"]),route.size())
			continue
		var direction := difference.normalized()
		var fleeing := clock<float(citizen["flee_until"])
		var speed: float = 2.7 if fleeing else float(citizen["speed"])
		body.velocity.x = direction.x*speed
		body.velocity.z = direction.z*speed
		body.velocity.y = -1 if body.is_on_floor() else body.velocity.y-18*delta
		body.move_and_slide()
		(citizen["model"] as Node3D).rotation.y = lerp_angle((citizen["model"] as Node3D).rotation.y,atan2(direction.x,direction.z),minf(1,delta*8))
		if animation!=null:
			var clip: StringName = citizen["clips"].get("run" if fleeing else "walk",&"")
			if not clip.is_empty() and animation.current_animation!=clip: animation.play(clip,.15)
	for vehicle: Dictionary in traffic:
		var model := vehicle["model"] as Node3D
		if not bool(model.get_meta("device_budget_active",true)): continue
		var stopped := not (vehicle["sensor"] as Area3D).get_overlapping_bodies().is_empty()
		if is_instance_valid(player):
			var difference := player.global_position-model.global_position
			stopped = stopped or (difference.dot(model.basis.z)>0 and difference.dot(model.basis.z)<9 and absf(difference.dot(model.basis.x))<2.6)
		vehicle["stopped"] = stopped
		vehicle["speed"] = move_toward(float(vehicle["speed"]),0 if stopped else float(vehicle["cruise_speed"]),(10 if stopped else 3)*delta)
		var route: Array = vehicle["route"]
		var target: Vector3 = route[int(vehicle["waypoint"])]
		var direction := (target-model.position).normalized()
		var travel := minf(float(vehicle["speed"])*delta,model.position.distance_to(target))
		model.position += direction*travel
		model.rotation.y = atan2(direction.x,direction.z)
		for wheel: Node3D in vehicle["wheels"]: wheel.rotation.x += travel/.31
		if model.position.distance_to(target)<.1: vehicle["waypoint"] = (int(vehicle["waypoint"])+1)%route.size()
