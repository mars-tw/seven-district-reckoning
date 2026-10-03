class_name DistrictMap
extends Control

signal waypoint_selected(position_value: Vector2)
var districts: Array[Dictionary] = []
var blocks: Array[AABB] = []
var markers: Dictionary = {}
var player_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var waypoint_position: Vector2 = Vector2.ZERO
var has_target: bool = false
var has_waypoint: bool = false
var map_font: Font

func _ready() -> void:
	custom_minimum_size = Vector2(maxf(180,custom_minimum_size.x),maxf(180,custom_minimum_size.y))
	map_font = load("res://assets/fonts/SevenDistrictSansTC-Regular.otf") as Font
	tooltip_text = "點地圖標示目的地；標記只提供方向，不會移動角色。"
	resized.connect(queue_redraw)

func setup(region_data: Array[Dictionary], building_bounds: Array[AABB], points: Dictionary) -> void:
	districts = region_data.duplicate(true)
	blocks = building_bounds.duplicate()
	markers = points.duplicate(true)
	queue_redraw()

func _area() -> Rect2:
	var length: float = maxf(20, minf(size.x,size.y)-16)
	return Rect2((size-Vector2.ONE*length)*0.5,Vector2.ONE*length)

func world_to_map(point: Vector2) -> Vector2:
	var area: Rect2 = _area()
	return area.position + (point + Vector2(150,150)) / 300.0 * area.size

func map_to_world(point: Vector2) -> Vector2:
	var area: Rect2 = _area()
	return (point-area.position) / area.size * 300.0 - Vector2(150,150)

func _gui_input(event: InputEvent) -> void:
	var pressed: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	pressed = pressed or (event is InputEventScreenTouch and event.pressed)
	if pressed and _area().has_point(event.position):
		var point: Vector2 = map_to_world(event.position).clamp(Vector2(-145,-145),Vector2(145,145))
		waypoint_selected.emit(point)
		accept_event()

func _draw() -> void:
	var area: Rect2 = _area()
	draw_rect(area,Color("213b3b"))
	var colors: Array[Color] = [Color("40584b"),Color("324d59"),Color("42664d"),Color("535348"),Color("3c4e60"),Color("4a5351")]
	for index: int in districts.size():
		var region: Dictionary = districts[index]
		var bounds: Array = region.get("bounds",[])
		if bounds.size() != 4: continue
		var a := world_to_map(Vector2(float(bounds[0]),float(bounds[1])))
		var b := world_to_map(Vector2(float(bounds[2]),float(bounds[3])))
		draw_rect(Rect2(a,b-a),colors[index % colors.size()])
	for street: float in [-137.0,0.0,137.0]:
		var width: float = area.size.x * (15.0 if street == 0 else 10.0) / 300.0
		var end_value: float = 147.0 if street == 0 else 137.0
		draw_line(world_to_map(Vector2(-end_value,street)),world_to_map(Vector2(end_value,street)),Color("728181"),width,true)
		draw_line(world_to_map(Vector2(street,-end_value)),world_to_map(Vector2(street,end_value)),Color("728181"),width,true)
	for street: float in [-76.0,76.0]:
		draw_line(world_to_map(Vector2(-80,street)),world_to_map(Vector2(80,street)),Color("728181"),area.size.x*12/300,true)
		draw_line(world_to_map(Vector2(street,-80)),world_to_map(Vector2(street,80)),Color("728181"),area.size.x*12/300,true)
	for side: float in [-1.0,1.0]:
		draw_line(world_to_map(Vector2(side*80,76)),world_to_map(Vector2(side*137,76)),Color("728181"),area.size.x*10/300,true)
		draw_line(world_to_map(Vector2(side*76,80)),world_to_map(Vector2(side*76,137)),Color("728181"),area.size.x*10/300,true)
	for block: AABB in blocks:
		var a := world_to_map(Vector2(block.position.x,block.position.z))
		var b := world_to_map(Vector2(block.end.x,block.end.z))
		draw_rect(Rect2(a,b-a),Color("a3aca5"))
	for index: int in districts.size():
		var region: Dictionary = districts[index]
		var value: Variant = region.get("marker",[])
		if not value is Array or value.size()!=2: continue
		var at := world_to_map(Vector2(float(value[0]),float(value[1])))
		if map_font and area.size.x > 250:
			draw_string(map_font,at + Vector2(-24,-6),str(region.get("name",region.get("title","街區"))),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("e2e9de"))
	for key: String in markers:
		var at := world_to_map(markers[key])
		var color: Color = Color("76bfd0") if key=="car" else Color("9ccc83") if key=="bicycle" else Color("dfcc99")
		draw_circle(at,4,color)
	if has_target:
		draw_line(world_to_map(player_position),world_to_map(target_position),Color("dfbd72"),2,true)
		draw_rect(Rect2(world_to_map(target_position)-Vector2.ONE*4,Vector2.ONE*8),Color("efc56b"))
	if has_waypoint:
		draw_line(world_to_map(player_position),world_to_map(waypoint_position),Color("70d1ce"),1.5,true)
		draw_circle(world_to_map(waypoint_position),6,Color("70d1ce"),false,2,true)
	draw_circle(world_to_map(player_position),5,Color("f1f2e5"))
	draw_rect(area,Color("78908a"),false,1)
