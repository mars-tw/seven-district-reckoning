extends SceneTree

const Life = preload("res://scripts/world/district_life.gd")
const Main = preload("res://scenes/main.tscn")
var failures: Array[String] = []
var passed: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	if condition:
		passed.append(label)
		print("CITY_LIFE_PASS ", label)
	else:
		failures.append(label)
		push_error("CITY_LIFE_FAIL " + label)

func _run() -> void:
	var world: Node3D = Main.instantiate()
	root.add_child(world)
	current_scene = world
	world.set("is_test_mode", true)
	world.call("_new_game")
	paused = false
	var player: CharacterBody3D = world.get("player") as CharacterBody3D
	var life: DistrictLife = Life.bootstrap(world)
	life.setup(player)
	await physics_frame
	await physics_frame
	var counts: Dictionary = life.get_counts()
	check(counts["districts"] == 6, "six_named_districts")
	check(counts["citizens"] == 8 and life.citizens.size() == 8, "eight_real_citizen_instances")
	check(counts["moving_vehicles"] == 4 and life.traffic.size() == 4, "four_real_background_vehicle_instances")
	check(counts["missing_assets"].is_empty(), "all_shipped_GLB_assets_loaded")
	var imported_buildings: int = 0
	for key: String in ["office_tower_a","office_tower_b","office_tower_c","urban_shopfront"]:
		imported_buildings += int(counts["assets"].get(key,0))
	check(counts["assets"].get("road_straight", 0) >= 90 and imported_buildings >= 9, "roads_and_buildings_use_real_GLBs")
	check(counts["assets"].get("tree", 0) >= 10 and counts["assets"].get("bench", 0) >= 10, "park_and_street_furniture_present")
	check(Life.bootstrap(world) == life and life.get_counts() == counts, "bootstrap_does_not_duplicate_scene")
	var districts: Array[Dictionary] = life.get_districts()
	var ids: Array[String] = []
	for district: Dictionary in districts:
		ids.append(str(district["id"]))
		var marker: Array = district["marker"]
		var bounds: Array = district["bounds"]
		check(float(marker[0]) >= float(bounds[0]) and float(marker[0]) <= float(bounds[2]) and float(marker[1]) >= float(bounds[1]) and float(marker[1]) <= float(bounds[3]), "marker_inside_" + str(district["id"]))
		check(life.is_walkable(Vector3(float(marker[0]), 0.1, float(marker[1]))), "marker_walkable_" + str(district["id"]))
	check(ids.size() == 6 and ids.has("old_street") and ids.has("commercial_core") and ids.has("park") and ids.has("parking_plaza") and ids.has("station_forecourt") and ids.has("transit"), "stable_district_ID_contract")
	var central: AABB = AABB(Vector3(-82, 0, -82), Vector3(164, 100, 164))
	var outer_only: bool = true
	for obstacle: AABB in life.get_obstacle_bounds():
		outer_only = outer_only and not central.intersects(obstacle)
	check(outer_only, "new_solid_obstacles_keep_MAIN001_to_MAIN005_centre_open")
	var probes: Array[Vector3] = [Vector3(-56, 1, 52), Vector3(-75, 1, 25), Vector3(-75, 1, -55), Vector3(-15, 1, -75), Vector3(-46, 1, 42), Vector3(24, 1, 29), Vector3(34, 1, 28), Vector3(74, 1, 31)]
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.72
	for index: int in probes.size():
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, probes[index])
		query.collision_mask = 1
		query.collide_with_areas = false
		var hits: Array[Dictionary] = world.get_world_3d().direct_space_state.intersect_shape(query, 8)
		check(hits.is_empty(), "real_player_capsule_clear_at_main_corridor_%d" % index)
	var route_clear: bool = true
	var animated_people: bool = true
	var immune_people: bool = true
	var reported_blockers: Dictionary = {}
	for citizen: Dictionary in life.citizens:
		var body: CharacterBody3D = citizen["body"]
		animated_people = animated_people and citizen["animation"] is AnimationPlayer and citizen["clips"].has("walk") and citizen["clips"].has("run")
		immune_people = immune_people and not body.is_in_group("damageable") and not body.has_method("apply_hit") and body.collision_layer == 2 and body.collision_mask == 1
		var route: Array = citizen["route"]
		for index: int in route.size():
			var a: Vector3 = route[index]
			var b: Vector3 = route[(index + 1) % route.size()]
			var sample_count: int = maxi(2, int(ceil(a.distance_to(b) / 0.25)) + 1)
			for sample_index: int in sample_count:
				var point: Vector3 = a.lerp(b, float(sample_index) / float(sample_count - 1))
				route_clear = route_clear and life.is_walkable(point)
				var route_query := PhysicsShapeQueryParameters3D.new()
				route_query.shape = shape
				route_query.transform = Transform3D(Basis.IDENTITY, Vector3(point.x, 1, point.z))
				route_query.collision_mask = 1
				route_query.collide_with_areas = false
				var route_hits: Array[Dictionary] = world.get_world_3d().direct_space_state.intersect_shape(route_query, 4)
				if not route_hits.is_empty():
					route_clear = false
					for route_hit: Dictionary in route_hits:
						var collider: Node3D = route_hit["collider"] as Node3D
						var blocker_key: String = str(citizen["district"]) + ":" + str(collider.get_instance_id())
						if not reported_blockers.has(blocker_key):
							reported_blockers[blocker_key] = true
							print("ROUTE_BLOCKER ", JSON.stringify({"district": citizen["district"], "route_point": str(point), "collider_path": str(collider.get_path()), "object_id": collider.get("object_id"), "collider_position": str(collider.global_position)}))
	check(route_clear, "all_citizen_route_segments_have_clearance")
	check(animated_people, "citizens_have_shipped_walk_and_run_rig_clips")
	check(immune_people, "ambient_citizens_are_noncombat_and_mask_world_only")
	var car_routes_bounded: bool = true
	var real_wheels: bool = true
	for car: Dictionary in life.traffic:
		car_routes_bounded = car_routes_bounded and car["route"].size() == 4
		for point: Vector3 in car["route"]:
			car_routes_bounded = car_routes_bounded and absf(point.x) <= 143 and absf(point.z) <= 143 and (absf(point.x) > 130 or absf(point.z) > 130)
		real_wheels = real_wheels and car["wheels"].size() == 4 and car["sensor"] is Area3D and not car["model"] is PhysicsBody3D
	check(car_routes_bounded, "traffic_stays_on_four_point_outer_road")
	check(real_wheels, "cars_animate_four_real_wheel_meshes_with_nonblocking_Area_sensor")
	var first_citizen: CharacterBody3D = life.citizens[0]["body"]
	var walk_start: Vector3 = first_citizen.position
	var first_car: Node3D = life.traffic[0]["model"]
	var wheel: Node3D = life.traffic[0]["wheels"][0]
	var wheel_start: float = wheel.rotation.x
	var car_start: Vector3 = first_car.position
	await create_timer(1.0).timeout
	check(first_citizen.position.distance_to(walk_start) > 0.65, "actual_physics_moves_citizen_on_route")
	check(first_car.position.distance_to(car_start) > 0.5 and absf(wheel.rotation.x - wheel_start) > 0.5, "actual_traffic_motion_turns_GLB_wheels")
	paused = true
	var pause_clock: float = life.clock
	var pause_car: Vector3 = first_car.position
	var pause_citizen: Vector3 = first_citizen.position
	await create_timer(0.25, true).timeout
	check(is_equal_approx(life.clock, pause_clock) and first_car.position == pause_car and first_citizen.position == pause_citizen, "pause_freezes_ambient_clock_citizens_and_traffic")
	paused = false
	var approach_direction: Vector3 = life.citizens[0]["direction"]
	player.global_position = first_citizen.global_position + approach_direction * 2.5 + Vector3(0, 0.05, 0)
	player.velocity = Vector3.ZERO
	player.call("grant_weapon", "wrench")
	await physics_frame
	check(player.call("begin_attack"), "real_player_weapon_swing_begins_near_ambient_citizen")
	await create_timer(0.30).timeout
	check(life.get_status()["fleeing_citizens"] >= 1, "weapon_signal_triggers_visible_citizen_flee_state")
	check(first_citizen.is_inside_tree() and not first_citizen.has_method("apply_hit"), "citizen_survives_weapon_swing")
	var flee_start: float = first_citizen.global_position.distance_to(player.global_position)
	await create_timer(1.0).timeout
	print("FLEE_EVIDENCE ", JSON.stringify({"distance_before": flee_start, "distance_after": first_citizen.global_position.distance_to(player.global_position), "citizen": str(first_citizen.position), "player": str(player.position), "direction": str(life.citizens[0]["direction"]), "step": life.citizens[0]["step"], "waypoint": life.citizens[0]["waypoint"]}))
	check(first_citizen.global_position.distance_to(player.global_position) > flee_start + 1.0, "fleeing_citizen_actually_moves_away_from_player_on_clear_route")
	# Move the actual player into a car's forward sensor, then remove them.
	var vehicle: Dictionary = life.traffic[0]
	player.global_position = first_car.global_position + first_car.basis.z * 5 + Vector3(0, 0.2, 0)
	player.velocity = Vector3.ZERO
	# Teleport is fixture placement. Apply the actual device budget at the placed
	# focus before measuring the original 0.8-second braking interval.
	world.device_profiles.update_ambient(player)
	await create_timer(0.8).timeout
	check(vehicle["stopped"] and float(vehicle["speed"]) < 0.4, "actual_area_sensor_brakes_for_player")
	player.global_position = Vector3(-56, 0.2, 52)
	player.velocity = Vector3.ZERO
	world.device_profiles.update_ambient(player)
	await create_timer(0.6).timeout
	check(not vehicle["stopped"] and float(vehicle["speed"]) > 0.4, "traffic_resumes_after_player_clears_sensor")
	var state: Dictionary = life.to_dict()
	check(state.keys().size() == 2 and state.has("clock") and state.has("version"), "ambient_save_contains_only_scene_clock")
	check(life.from_dict({"version": 1, "clock": 100.5}) and is_equal_approx(life.clock, 100.5), "ambient_scene_clock_roundtrip")
	check(not life.from_dict({"clock": "invalid"}) and not life.from_dict({"clock": -1}), "invalid_scene_clocks_are_rejected")
	var bounded_after_motion: bool = true
	for citizen: Dictionary in life.citizens:
		var p: Vector3 = citizen["body"].position
		bounded_after_motion = bounded_after_motion and p.is_finite() and absf(p.x) <= 143 and absf(p.z) <= 143 and p.y > -0.5 and life.is_walkable(p, 0.10)
	check(bounded_after_motion, "all_live_citizens_remain_on_supported_clear_terrain")
	print("CITY_LIFE_RESULT ", JSON.stringify({"passed": passed, "failures": failures, "counts": life.get_counts(), "status": life.get_status(), "human_visual_review": false}))
	quit(0 if failures.is_empty() else 1)
