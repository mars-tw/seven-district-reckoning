extends SceneTree
const Detail = preload("res://scripts/world/urban_detail.gd")
var passes: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	if condition:
		passes += 1
		print("URBAN_PASS ",label)
	else:
		failures.append(label)
		push_error("URBAN_FAIL "+label)

func _run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var detail := Detail.bootstrap(host)
	await process_frame
	var counts: Dictionary = detail.get_counts()
	check(counts["surface_instances"] > 250,"instanced_road_surface_details")
	check(counts["kit_instances"] >= 200,"real_imported_sidewalk_and_bench_kit")
	check(counts["crossings"] == 12,"twelve_striped_crossings")
	check(counts["draw_groups"] <= 20,"surface_and_kit_draw_groups_bounded")
	check(counts["missing_assets"].is_empty(),"no_missing_urban_assets")
	check(Detail.bootstrap(host)==detail and detail.get_counts()==counts,"bootstrap_idempotent")
	check(detail.get_bounds().is_empty(),"zero_new_blocking_bounds")
	check(detail.process_mode==Node.PROCESS_MODE_PAUSABLE,"pause_contract")
	var bodies := 0
	var meshes := 0
	var contained := true
	var queue: Array[Node] = [detail]
	while not queue.is_empty():
		var node := queue.pop_back() as Node
		queue.append_array(node.get_children())
		if node is CollisionObject3D or node is CollisionShape3D: bodies+=1
		if node is MultiMeshInstance3D:
			meshes+=1
			check(node.multimesh != null and node.multimesh.instance_count>0,"nonempty_MultiMesh_"+node.name)
	for box: AABB in detail.get_visual_bounds():
		contained = contained and box.position.x>=-150 and box.end.x<=150 and box.position.z>=-150 and box.end.z<=150
	check(bodies==0,"no_solid_or_sensor_nodes_added")
	check(meshes==counts["draw_groups"],"reported_draw_groups_match_scene")
	check(contained,"all_visual_instances_inside_existing_300m_boundary")
	var roads := detail.get_node("UrbanSurface_asphalt") as MultiMeshInstance3D
	# Dummy RenderingServer returns identity when reading MultiMesh transforms.
	# Inspect the actual CPU-authored matrices submitted to the renderer instead.
	var transforms: Array = detail.get("_groups")["asphalt"]["transforms"]
	var ew: AABB = transforms[0]*roads.multimesh.mesh.get_aabb()
	var ns: AABB = transforms[1]*roads.multimesh.mesh.get_aabb()
	check(absf(ew.size.x-294.0)<.02 and absf(ew.size.z-15.0)<.02,"east_west_road_matches_original_axes_and_length")
	check(absf(ns.size.z-294.0)<.02 and absf(ns.size.x-15.0)<.02,"north_south_road_matches_original_axes_and_length")
	for key: String in ["urban_tower_a","urban_tower_b","urban_tower_c","urban_sidewalk","urban_shopfront","urban_bench"]:
		var path := "res://assets/models/"+key+".glb"
		check(ResourceLoader.exists(path),"import_exists_"+key)
		var packed := load(path) as PackedScene
		check(packed!=null,"real_PackedScene_"+key)
		if packed==null: continue
		var model := packed.instantiate() as Node3D
		host.add_child(model)
		queue=[model]
		var found := 0
		while not queue.is_empty():
			var node := queue.pop_back() as Node
			queue.append_array(node.get_children())
			if node is MeshInstance3D and node.mesh != null: found+=1
		check(found>0 and found<=8,"bounded_real_geometry_"+key)
		model.queue_free()
	print("URBAN_SUMMARY ",JSON.stringify({"passed":passes,"failed":failures.size(),"counts":counts}))
	host.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
