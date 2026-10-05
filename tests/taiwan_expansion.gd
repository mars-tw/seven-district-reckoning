extends SceneTree

const Expansion = preload("res://scripts/world/taiwan_expansion.gd")
var passed: Array[String] = []
var failures: Array[String] = []
var world: Node3D
var expansion: TaiwanExpansion
var capsule: CapsuleShape3D

func _initialize() -> void: call_deferred("_run")
func check(ok: bool,label: String) -> void:
	if ok:
		passed.append(label)
		print("TAIWAN_MAP_PASS ",label)
	else:
		failures.append(label)
		push_error("TAIWAN_MAP_FAIL "+label)

func _clear(p: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY,Vector3(p.x,1.0,p.z))
	query.collision_mask = 1
	query.collide_with_areas = false
	return world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _floor(p: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(Vector3(p.x,2,p.z),Vector3(p.x,-2,p.z),1)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and absf((hit["position"] as Vector3).y+.01)<.05

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	# Simulates only the preserved floor. Original gameplay blockers and station
	# interactions belong to Root's integration suite, not this unit's evidence.
	var core := StaticBody3D.new()
	core.position = Vector3(0,-.16,0)
	var collision := CollisionShape3D.new()
	var core_shape := BoxShape3D.new()
	core_shape.size = Vector3(300,.30,300)
	collision.shape = core_shape
	core.add_child(collision)
	world.add_child(core)
	expansion = Expansion.bootstrap(world)
	capsule = CapsuleShape3D.new()
	capsule.radius = .45
	capsule.height = 1.72
	await physics_frame
	await physics_frame
	var counts := expansion.get_counts()
	check(counts["regions"]==8 and counts["stations"]==32,"eight_original_regions_32_actual_station_positions")
	check(counts["terrain_bodies"]==4 and counts["terrain_area_m2"]==550000.0,"four_contiguous_outer_plates_expand_300m_core_to_800m")
	check(counts["missing_assets"].is_empty(),"all_original_GLBs_are_loaded")
	check(counts["assets"].size()>=16 and counts["asset_instances"]>=300,"distinct_Taiwan_kit_and_shipped_public_furniture_present")
	check(counts["collider_sectors"]<80 and counts["collider_shapes"]>160,"shared_sector_bodies_keep_furniture_physics_bounded")
	check(counts["lod_levels"]>=20,"actual_imported_index_LODs_preserved_in_combined_kit_meshes")
	check(counts["roads"]==16,"12_outer_cardinal_roads_and_four_core_spurs")
	check(Expansion.bootstrap(world)==expansion and expansion.get_counts()==counts,"bootstrap_idempotent")
	check(not expansion.is_walkable(Vector3(INF,0,0)) and not expansion.is_walkable(Vector3(400,0,0)) and not expansion.is_walkable(Vector3(0,0,-400)),"invalid_and_outside_world_points_rejected")
	var stations := expansion.get_station_positions()
	for region: Dictionary in expansion.get_regions():
		var marker: Array = region["marker"]
		var p := Vector3(float(marker[0]),0,float(marker[1]))
		check(absf(p.x)>150 or absf(p.z)>150,"new_region_outside_preserved_core_"+str(region["id"]))
		check(expansion.is_walkable(p) and _clear(p) and _floor(p),"region_marker_has_real_floor_and_capsule_clearance_"+str(region["id"]))
		var court_clear := true
		for dx: float in [-15,-12,0,12,15]:
			for dz: float in [-15,-12,0,12,15]: court_clear = court_clear and expansion.is_walkable(p+Vector3(dx,0,dz)) and _clear(p+Vector3(dx,0,dz)) and _floor(p+Vector3(dx,0,dz))
		check(court_clear,"all_30m_station_forecourt_clear_"+str(region["id"]))
	for id: String in stations:
		var point: Vector3 = stations[id]
		check(expansion.is_walkable(point,.8) and _clear(point) and _floor(point),"station_floor_and_interaction_capsule_"+id)
	var road_samples := 0
	for road: Dictionary in expansion.get_navigation_roads():
		var aa: Array = road["a"]
		var bb: Array = road["b"]
		var a := Vector3(float(aa[0]),0,float(aa[1]))
		var b := Vector3(float(bb[0]),0,float(bb[1]))
		var direction := (b-a).normalized()
		var right := Vector3(direction.z,0,-direction.x)
		var samples := ceili(a.distance_to(b)/3)+1
		var road_clear := true
		for index: int in samples:
			var center := a.lerp(b,float(index)/float(samples-1))
			for lane: float in [-4,0,4]:
				var p := center+right*lane
				if not expansion.is_walkable(p,.45) or not _clear(p) or not _floor(p):
					road_clear = false
					if failures.size()<4: print("ROAD_BLOCKER ",road["id"]," ",p)
				road_samples += 1
		check(road_clear,"real_12m_road_lane_clearance_continuous_"+str(road["id"]))
	# Floor at seam and outer corners proves the actual 800 m claim.
	for x: float in [-398,-150.1,-149.9,0,149.9,150.1,398]:
		for z: float in [-398,-150.1,-149.9,0,149.9,150.1,398]:
			check(_floor(Vector3(x,0,z)),"continuous_floor_x%d_z%d"%[roundi(x*10),roundi(z*10)])
	var all_sectors_local := true
	var distinct_sectors: Dictionary = {}
	for child: Node in expansion.get_children():
		if not child is MultiMeshInstance3D: continue
		var draw := child as MultiMeshInstance3D
		distinct_sectors[str(draw.position)] = true
		all_sectors_local = all_sectors_local and draw.position!=Vector3.ZERO and draw.visibility_range_end>0
		for index: int in draw.multimesh.instance_count:
			var transform_value := draw.multimesh.get_instance_transform(index)
			all_sectors_local = all_sectors_local and absf(transform_value.origin.x)<=45.05 and absf(transform_value.origin.z)<=45.05
	check(all_sectors_local and distinct_sectors.size()>=40,"all_MultiMeshes_have_local_90m_sector_origins_for_distance_culling")
	var collision_count_before: int = int(counts["collider_shapes"])
	var visual_count_before: int = int(counts["asset_instances"])
	for profile: Dictionary in [{"view_distance":190,"prop_distance":70},{"view_distance":280,"prop_distance":110},{"view_distance":440,"prop_distance":180}]:
		expansion.apply_profile(profile)
		check(expansion.get_counts()["view_distance"]==profile["view_distance"] and expansion.get_counts()["prop_distance"]==profile["prop_distance"],"profile_distances_applied_%d"%int(profile["view_distance"]))
		check(expansion.get_counts()["collider_shapes"]==collision_count_before and expansion.get_counts()["asset_instances"]==visual_count_before,"profiles_preserve_world_physics_and_stations_%d"%int(profile["view_distance"]))
	expansion.set_hour(20)
	check(expansion.get_counts()["night_lanterns"],"night_lantern_emission_enabled_at_20h")
	expansion.set_hour(12)
	check(not expansion.get_counts()["night_lanterns"],"lantern_emission_disabled_at_noon")
	var bounds_valid := true
	for bound: AABB in expansion.get_visual_bounds(): bounds_valid = bounds_valid and bound.position.is_finite() and bound.size.is_finite() and bound.size.length()>0 and absf(bound.get_center().x)<401 and absf(bound.get_center().z)<401
	check(bounds_valid and expansion.get_visual_bounds().size()>1800,"CPU_geometry_bounds_verify_actual_batch_world_extent")
	check(expansion.citizens.size()==16 and expansion.traffic.size()==4,"16_new_animated_ambient_people_and_four_real_car_models")
	var people_valid := true
	var routes_clear := true
	for citizen: Dictionary in expansion.citizens:
		var body := citizen["body"] as CharacterBody3D
		people_valid = people_valid and body.is_in_group("ambient_citizens") and citizen["animation"] is AnimationPlayer and citizen["clips"].has("walk") and citizen["clips"].has("run") and not body.is_in_group("damageable") and not body.has_method("apply_hit")
		var route: Array = citizen["route"]
		for index: int in route.size():
			var a: Vector3 = route[index]
			var b: Vector3 = route[(index+1)%route.size()]
			for step: int in 37:
				var point := a.lerp(b,float(step)/36)
				routes_clear = routes_clear and expansion.is_walkable(point,.35) and _clear(point) and _floor(point)
	check(people_valid,"ambient_people_have_real_rig_walk_run_and_noncombat_physics")
	check(routes_clear,"all_16_ambient_walking_loop_segments_have_real_capsule_floor_clearance")
	var citizen_body := expansion.citizens[0]["body"] as CharacterBody3D
	var citizen_animation := expansion.citizens[0]["animation"] as AnimationPlayer
	var traffic_model := expansion.traffic[0]["model"] as Node3D
	check(expansion.traffic[0]["wheels"].size()==4 and expansion.traffic[0]["sensor"] is Area3D and traffic_model.is_in_group("ambient_traffic"),"real_car_wheel_meshes_and_player_braking_sensor")
	var citizen_start := citizen_body.position
	var car_start := traffic_model.position
	var wheel := expansion.traffic[0]["wheels"][0] as Node3D
	var wheel_start := wheel.rotation.x
	await create_timer(1).timeout
	check(citizen_body.position.distance_to(citizen_start)>.6 and citizen_animation.is_playing(),"real_physics_moves_people_with_running_skeletal_animation")
	check(traffic_model.position.distance_to(car_start)>1 and absf(wheel.rotation.x-wheel_start)>.5,"real_car_motion_rotates_its_actual_wheel_meshes")
	citizen_body.set_meta("device_budget_active",false)
	traffic_model.set_meta("device_budget_active",false)
	citizen_start = citizen_body.position
	car_start = traffic_model.position
	await create_timer(.4).timeout
	check(citizen_body.position==citizen_start and citizen_body.velocity==Vector3.ZERO and not citizen_animation.active and traffic_model.position==car_start,"distance_or_device_budget_freezes_AI_physics_and_skeletons")
	citizen_body.set_meta("device_budget_active",true)
	traffic_model.set_meta("device_budget_active",true)
	await create_timer(.4).timeout
	check(citizen_body.position.distance_to(citizen_start)>.25 and citizen_animation.active and traffic_model.position.distance_to(car_start)>.2,"reactivation_resumes_same_ambient_actors")
	var pedestrian := CharacterBody3D.new()
	pedestrian.collision_layer = 2
	pedestrian.collision_mask = 0
	var pedestrian_collision := CollisionShape3D.new()
	var pedestrian_shape := CapsuleShape3D.new()
	pedestrian_shape.radius = .35
	pedestrian_shape.height = 1.72
	pedestrian_collision.shape = pedestrian_shape
	pedestrian_collision.position.y = .86
	pedestrian.add_child(pedestrian_collision)
	pedestrian.position = traffic_model.position+traffic_model.basis.z*5
	world.add_child(pedestrian)
	await create_timer(.8).timeout
	check(expansion.traffic[0]["stopped"] and float(expansion.traffic[0]["speed"])<.4,"actual_area_overlap_brakes_outer_car_for_real_pedestrian_body")
	pedestrian.position = Vector3(0,0,0)
	await create_timer(.5).timeout
	check(not expansion.traffic[0]["stopped"] and float(expansion.traffic[0]["speed"])>.5,"outer_car_resumes_when_real_pedestrian_clears_road")
	pedestrian.queue_free()
	paused = true
	var old_clock := expansion.clock
	citizen_start = citizen_body.position
	car_start = traffic_model.position
	await create_timer(.25,true).timeout
	check(expansion.clock==old_clock and citizen_body.position==citizen_start and traffic_model.position==car_start,"pause_freezes_world_AI_clock_people_and_traffic")
	paused = false
	var report := {"passed":passed.size(),"failures":failures,"road_capsule_samples":road_samples,"counts":expansion.get_counts(),"browser_fps_claimed":false}
	var output := FileAccess.open(ProjectSettings.globalize_path("res://../qa/taiwan-expansion-result.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	print("TAIWAN_MAP_RESULT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
