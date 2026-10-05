extends SceneTree

## Actual native OpenGL renderer captures of the world module. These are art
## review views, not browser FPS evidence or complete gameplay screenshots.
const Expansion = preload("res://scripts/world/taiwan_expansion.gd")
var world: Node3D
var camera: Camera3D

func _initialize() -> void: call_deferred("_render")
func _render() -> void:
	root.size = Vector2i(1280,720)
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("bdd1d2")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c3d4ca")
	settings.ambient_light_energy = .25
	settings.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.environment = settings
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-30,0)
	sun.light_energy = .75
	sun.light_color = Color(1.0,.86,.69)
	sun.shadow_enabled = true
	world.add_child(sun)
	var expansion := Expansion.bootstrap(world)
	expansion.apply_profile({"view_distance":440,"prop_distance":180,"shadows":true})
	camera = Camera3D.new()
	camera.fov = 62
	camera.far = 550
	world.add_child(camera)
	camera.current = true
	var output := ProjectSettings.globalize_path("res://../qa/art/taiwan")
	DirAccess.make_dir_recursive_absolute(output)
	var views: Array[Dictionary] = [
		{"id":"market_native","camera":Vector3(-321,42,-212),"target":Vector3(-270,1,-270)},
		{"id":"convenience_native","camera":Vector3(282,4.8,17),"target":Vector3(244,1.7,-23)},
		{"id":"parcel_native","camera":Vector3(283,4.7,289),"target":Vector3(244,1.7,247)},
		{"id":"river_native","camera":Vector3(-255,6.5,315),"target":Vector3(-295,1.2,259)},
		{"id":"night_market_native","camera":Vector3(291,5,-241),"target":Vector3(246,2,-288)}
	]
	for view: Dictionary in views:
		camera.position = view["camera"]
		camera.look_at(view["target"])
		expansion.set_hour(20 if str(view["id"]).contains("night") else 12)
		for index: int in 8: await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var result := image.save_png(output+"/"+str(view["id"])+".png")
		print("TAIWAN_NATIVE_CAPTURE ",view["id"]," ",result," ",image.get_size())
	var report := {"counts":expansion.get_counts(),"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"note":"Native world-module review; not browser performance proof."}
	var file := FileAccess.open(output+"/native-review.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("TAIWAN_NATIVE_RENDER_RESULT ",JSON.stringify(report))
	quit()
