extends SceneTree
## Native OpenGL art and profile review of the shipping Root, with explicit placement fixtures.
## This records renderer workloads on the development PC, not mobile hardware FPS.
const ActualScene = preload("res://scenes/main.tscn")
class CaptureRoot extends "res://scripts/main.gd":
	func _save(_show_notice: bool = true) -> void: pass
	func _run_integration_checks() -> void: pass
var world: Node3D
var camera: Camera3D
var output: String
var records: Array[Dictionary] = []

func _initialize() -> void: call_deferred("_capture")
func _capture() -> void:
	output = ProjectSettings.globalize_path("res://../qa/art/taiwan/integrated")
	DirAccess.make_dir_recursive_absolute(output)
	world = ActualScene.instantiate()
	world.set_script(CaptureRoot)
	root.add_child(world)
	current_scene = world
	world.is_test_mode = true
	world._new_game()
	world.set_process(false)
	world.player.set_physics_process(false)
	world.player.global_position = Vector3(-269,.05,-269)
	world.player.velocity = Vector3.ZERO
	world.street_state.hour = 15.5
	world._update_daylight(1.0)
	camera = Camera3D.new()
	camera.fov = 62
	world.add_child(camera)
	world.player.get_camera().current = false
	camera.current = true
	camera.position = Vector3(-264,2.45,-264)
	camera.look_at(Vector3(-270,1,-272))
	var sizes: Dictionary = {"phone":Vector2i(390,844),"tablet":Vector2i(1024,768),"desktop":Vector2i(1366,768)}
	for profile: String in ["phone","tablet","desktop"]:
		root.size = sizes[profile]
		root.content_scale_size = sizes[profile]
		world.device_profiles.set_profile(profile,false)
		world.device_profiles.update_ambient(world.player)
		for i: int in 12: await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_png(output+"/"+profile+"_street.png")
		var times: Array[float] = []
		var draws: Array[int] = []
		for i: int in 90:
			var started := Time.get_ticks_usec()
			await process_frame
			times.append((Time.get_ticks_usec()-started)/1000.0)
			draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		times.sort()
		draws.sort()
		var settings: Dictionary = world.device_profiles.get_settings()
		records.append({"profile":profile,"viewport":[image.get_width(),image.get_height()],"scale_3d":root.scaling_3d_scale,"camera_far":camera.far,"lod":root.mesh_lod_threshold,"touch":world.touch_controls.enabled,"draw_calls_median":draws[45],"frame_ms_median":times[45],"frame_ms_p95":times[85],"citizen_budget":settings["max_citizens"],"traffic_budget":settings["max_traffic"]})
		world.hud.show_life_phone("food")
		for i: int in 6: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/"+profile+"_jobs.png")
		world._resume()
	# Direct actor lineup is an art fixture, separate from the street screenshots.
	root.size = Vector2i(1600,760)
	root.content_scale_size = root.size
	world.hud._hud.visible = false
	world.device_profiles.set_profile("desktop",false)
	world.player.global_position = Vector3(0,.1,-200)
	world.player.visible = false
	var index := 0
	for row: Dictionary in world.taiwan_world.actors:
		var actor: Node3D = row["node"]
		actor.global_position = Vector3(-5.25+index*1.5,.08,-208)
		actor.rotation.y = 0
		index += 1
	camera.position = Vector3(0,1.25,-199)
	camera.look_at(Vector3(0,1.05,-208))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.0
	for i: int in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/story_people.png")
	var report := {"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"gpu":RenderingServer.get_video_adapter_name(),"profiles":records,"scope":"Native shipping scene art/renderer fixture, 90 frames per profile on development PC; no claim of phone/tablet hardware performance."}
	var file := FileAccess.open(output+"/rendered-review.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("V04_RENDERED_CAPTURE_RESULT ",JSON.stringify(report))
	quit()
