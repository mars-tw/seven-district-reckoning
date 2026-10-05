extends SceneTree
## Real shipping RootScene review; placement is a fixture, never human travel evidence.
## The runner isolates all source/user data. Only reserved slots 91 and 92 are used.
const ActualScene = preload("res://scenes/main.tscn")
const Save = preload("res://scripts/save/save_manager.gd")

class ReviewRoot extends "res://scripts/main.gd":
	func _save(_show_notice: bool = true) -> void:
		if play_started: SaveScript.save_state(_snapshot(),91)

var world: Node3D
var passed: Array[String] = []
var failures: Array[String] = []
var navigation: Dictionary = {}
var approaches: Dictionary = {}
var capsule: CapsuleShape3D
var action_count := 0
var reviewed_cargo: Dictionary = {}
var completed_ui_routes: Array[String] = []

func _initialize() -> void: call_deferred("_run")
func check(ok: bool,label: String) -> void:
	if ok: passed.append(label)
	else:
		failures.append(label)
		push_error("V04_INTEGRATION_FAIL "+label)
func _equal(a: Variant,b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return is_equal_approx(float(a),float(b))
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not _equal(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i: int in a.size():
			if not _equal(a[i],b[i]): return false
		return true
	return a==b
func _run() -> void:
	for slot: int in [91,92]:
		for suffix: String in ["",".bak",".tmp"]:
			if FileAccess.file_exists("user://save%d.json%s"%[slot,suffix]):
				push_error("Reserved review slot already exists; preserving it.")
				quit(2)
				return
	world = ActualScene.instantiate()
	world.set_script(ReviewRoot)
	root.add_child(world)
	current_scene = world
	world.is_test_mode = true
	world._new_game()
	world.set_process(false)
	world.player.set_physics_process(false)
	await physics_frame
	await physics_frame
	check(world.taiwan_life.stations.size()==32 and world.taiwan_world.station_ids.size()==32,"shipping_root_has_all_32_real_station_interactables")
	check(world.taiwan_world.actors.size()==8,"shipping_root_has_eight_authored_story_actor_instances")
	check(world.WORLD_RADIUS==400 and world.street_state.world_radius==395,"root_playable_world_is_800m_across")
	capsule = CapsuleShape3D.new()
	capsule.radius = .36
	capsule.height = 1.76
	_build_navigation()
	_check_approaches()
	await _check_people_and_map()
	if "--v04-quick" not in OS.get_cmdline_user_args():
		await _play_job("DEL-FOOD-01")
		await _play_job("DEL-CONVENIENCE-01")
		await _play_job("DEL-PARCEL-01",true)
		await _check_story()
		await _check_returns_and_timeout()
		await _check_all_ui_routes()
		await _check_profiles()
		await _check_real_traffic_brake()
		await _check_real_player_attack()
		await _check_culture_activities()
		await _check_save_retry_and_pause()
	print("V04_INTEGRATION_RESULT ",JSON.stringify({"passed_count":passed.size(),"failures":failures,"connected_capsule_points":navigation.size(),"station_approaches":approaches.size(),"actual_ui_actions":action_count,"completed_ui_routes":completed_ui_routes,"completed_ui_route_count":completed_ui_routes.size(),"scope":"Actual shipping RootScene, native deterministic fixtures and container rectangles","browser_verified":false,"mobile_hardware_verified":false,"human_travel_verified":false}))
	for slot: int in [91,92]:
		for suffix: String in ["",".bak",".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save%d.json%s"%[slot,suffix]))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
func _clear(point: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY,Vector3(point.x,1.15,point.z))
	query.collision_mask = 1
	if not world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	var floor_ray := PhysicsRayQueryParameters3D.create(Vector3(point.x,.4,point.z),Vector3(point.x,-1.0,point.z),1)
	return not world.get_world_3d().direct_space_state.intersect_ray(floor_ray).is_empty()
func _segment_clear(a: Vector3,b: Vector3) -> bool:
	var count := maxi(1,ceili(a.distance_to(b)))
	for i: int in range(1,count+1):
		if not _clear(a.lerp(b,float(i)/count)): return false
	return true
func _build_navigation() -> void:
	var start := Vector2i(-56,52)
	var queue: Array[Vector2i] = [start]
	var tested: Dictionary = {start:true}
	navigation[start] = true
	var cursor := 0
	while cursor<queue.size():
		var current := queue[cursor]
		cursor += 1
		for direction: Vector2i in [Vector2i(8,0),Vector2i(-8,0),Vector2i(0,8),Vector2i(0,-8)]:
			var next := current+direction
			if tested.has(next) or abs(next.x)>392 or abs(next.y)>392: continue
			tested[next] = true
			if _segment_clear(Vector3(current.x,0,current.y),Vector3(next.x,0,next.y)):
				navigation[next] = true
				queue.append(next)
	check(navigation.size()>6000,"capsule_grid_connected_from_old_spawn_in_actual_combined_physics_world")
func _check_approaches() -> void:
	for id: String in world.taiwan_life.stations:
		var key := "TW_station_"+id
		var target: Node3D = world.objects[key]
		var best := INF
		for grid: Vector2i in navigation:
			var point := Vector3(grid.x,.15,grid.y)
			if point.distance_to(target.position)>9: continue
			for x: int in range(-7,8):
				for z: int in range(-7,8):
					var candidate := point+Vector3(x,0,z)
					var distance := candidate.distance_to(target.position)
					if distance>=2.75 or distance>=best or not _clear(candidate) or not _segment_clear(point,candidate): continue
					var ray := PhysicsRayQueryParameters3D.create(candidate+Vector3.UP,target.global_position+Vector3.UP*.8,1)
					if not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
					best = distance
					approaches[id] = candidate
		check(approaches.has(id),"capsule_connected_and_visible_station_"+id)
		if not approaches.has(id): print("V04_UNREACHABLE_STATION ",JSON.stringify({"id":id,"position":str(target.position)}))
func _button(text: String) -> Button:
	for node: Node in world.hud._modal_box.find_children("*","Button",true,false):
		if node.text==text and not node.disabled: return node as Button
	return null
func _press(text: String,label: String) -> bool:
	var button := _button(text)
	check(button!=null,label+"_actual_enabled_UI_button")
	if button==null: return false
	button.pressed.emit()
	world._process(0)
	return true
func _start_ui(id: String) -> bool:
	var task: Dictionary = world.taiwan_life.tasks[id]
	var category: String = str(task.get("category","story"))
	for page: int in 6:
		world.hud.show_life_phone(category,page)
		var button := _button(str(task["title"]))
		if button:
			button.pressed.emit()
			world._process(0)
			check(world.taiwan_life.active_id==id and world.taiwan_life.status=="active","actual_jobs_UI_starts_"+id)
			return world.taiwan_life.active_id==id
	check(false,"actual_jobs_UI_can_select_"+id)
	return false
func _place_station(id: String,vehicle: String = "any") -> bool:
	if not approaches.has(id): return false
	world._resume()
	world.car.force_release()
	world.bicycle.force_release()
	world.player.position = approaches[id]
	world.player.velocity = Vector3.ZERO
	if vehicle in ["car","bicycle"]:
		var ride: CharacterBody3D = world.car if vehicle=="car" else world.bicycle
		ride.position = approaches[id]
		ride.velocity = Vector3.ZERO
		ride.speed_mps = 0
		world.player.position = ride.position+Vector3(1,0,0)
		check(ride.enter(world.player),"actual_vehicle_enter_at_"+id)
		world.player._physics_process(0)
	world._process(0)
	world._update_interaction()
	check(world.nearest!=null and world.nearest.get("object_id")=="TW_station_"+id,"actual_nearest_station_"+id)
	if world.nearest==null or world.nearest.get("object_id")!="TW_station_"+id: return false
	world.player.interaction_requested.emit()
	world._process(0)
	check(world.hud._mode=="life_station" and paused,"actual_player_interaction_opens_station_UI_"+id)
	return world.hud._mode=="life_station"
func _act_ui(step: Dictionary,negative_code := false) -> bool:
	var id := str(step["target"])
	if not _place_station(id,str(step.get("required_vehicle","any"))): return false
	var before: Dictionary = world.taiwan_life.to_dict()
	var action := str(step["action"])
	if action=="verify_code":
		var entries: Array[Node] = world.hud._modal_box.find_children("FictionalPickupCode","LineEdit",true,false)
		check(entries.size()==1,"actual_parcel_UI_has_pickup_code_entry")
		if entries.is_empty(): return false
		var entry := entries[0] as LineEdit
		if negative_code:
			entry.text = "0000"
			_press("確認取件碼","wrong_pickup_code")
			check(world.taiwan_life.step_index==int(before["step_index"]) and world.taiwan_life.cargo.is_empty(),"actual_wrong_code_keeps_index_and_no_cargo")
			entries = world.hud._modal_box.find_children("FictionalPickupCode","LineEdit",true,false)
			entry = entries[0] as LineEdit
		entry.text = str(step["code"])
		if not _press("確認取件碼","correct_pickup_code"): return false
	elif action=="pickup":
		var title: String = world.hud.life_panel._item_title(str(step["item_id"]))
		if not _press("領取："+title,"pickup_"+str(step["item_id"])): return false
	else:
		var caption := "交談" if action=="talk" else "交付工作單物品" if action=="deliver" else "退回物品"
		if not _press(caption,action+"_"+id): return false
	action_count += 1
	check(not _equal(before,world.taiwan_life.to_dict()),"real_UI_action_advances_"+id+"_"+action)
	await process_frame
	_check_cargo_geometry()
	return not _equal(before,world.taiwan_life.to_dict())
func _check_cargo_geometry() -> void:
	if world.taiwan_life.cargo.is_empty():
		check(not is_instance_valid(world.taiwan_world.carried_visual),"empty_cargo_does_not_leave_a_visible_carry_object")
		return
	var carry: Node3D = world.taiwan_world.carried_visual
	check(is_instance_valid(carry),"real_picked_up_cargo_has_a_physical_model")
	if not is_instance_valid(carry): return
	var asset := str(carry.get_meta("cargo_asset",""))
	check(carry.is_inside_tree() and world.player._visual_root.is_ancestor_of(carry) and carry.visible and int(carry.get_meta("cargo_count",0))==world.taiwan_life.cargo.size(),"cargo_model_is_attached_visible_and_tracks_real_count")
	if reviewed_cargo.has(asset): return
	reviewed_cargo[asset] = true
	var bounds := AABB()
	var found := false
	for node: Node in carry.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		var transform_value: Transform3D = carry.global_transform.affine_inverse()*mesh.global_transform
		var local_bounds: AABB = transform_value*mesh.get_aabb()
		bounds = bounds.merge(local_bounds) if found else local_bounds
		found = true
	check(asset in ["tw_carry_food","tw_carry_shop","tw_carry_parcel"] and not str(carry.scene_file_path).contains("tw_parcel_shelf"),"actual_cargo_uses_specific_authored_carry_prop_"+asset)
	check(found and bounds.size.x>.1 and bounds.size.y>.1 and bounds.size.z>.1 and bounds.size.x<.8 and bounds.size.y<.8 and bounds.size.z<.8,"actual_cargo_mesh_has_real_carry_size_"+asset)
	print("V04_CARGO_GEOMETRY ",JSON.stringify({"asset":asset,"path":carry.scene_file_path,"kind":str(carry.get_meta("cargo_kind","")),"local_bounds":str(bounds)}))
func _play_job(id: String,negative_code := false,chosen_route: String = "") -> bool:
	var task: Dictionary = world.taiwan_life.tasks[id]
	var selected_route: String = ""
	var reward: Dictionary = task.get("reward",{}).duplicate(true)
	var route_choices: Array = task.get("choices",[])
	if not route_choices.is_empty():
		selected_route = str(route_choices[0]["id"]) if chosen_route.is_empty() else chosen_route
		var valid_choice := false
		for option: Dictionary in route_choices:
			if str(option["id"])==selected_route:
				valid_choice = true
				reward = option.get("reward",task.get("reward",{})).duplicate(true)
		check(valid_choice,"requested_UI_branch_exists_"+id+"_"+selected_route)
		if not valid_choice: return false
	var result_key := "default" if selected_route.is_empty() else selected_route
	var before_cash: int = world.taiwan_life.cash
	var npc := str(task.get("npc_id",""))
	var before_trust: int = int(world.taiwan_life.trust.get(npc,0))
	var before_count: int = int(world.taiwan_life.records.get(id,{}).get(result_key,0))
	if not _start_ui(id): return false
	var iterations := 0
	while world.taiwan_life.status in ["active","choosing"] and iterations<24:
		iterations += 1
		if world.taiwan_life.status=="choosing":
			world.hud.show_life_phone("story")
			var choices: Array = world.taiwan_life.get_choices()
			var selected: Dictionary = choices[0]
			for row: Dictionary in choices:
				if str(row["id"])==selected_route: selected = row
			if not _press(str(selected["label"]),"actual_route_choice_"+str(selected["id"])): break
			check(world.taiwan_life.route_id==selected_route,"actual_HUD_choice_sets_requested_branch_"+id+"_"+selected_route)
		else:
			if not await _act_ui(world.taiwan_life.get_current_step(),negative_code): break
	var completed: bool = world.taiwan_life.status=="completed" and world.taiwan_life.active_id==id
	check(completed and world.taiwan_life.cargo.is_empty() and world.taiwan_life.cargo_origins.is_empty(),"actual_root_UI_and_world_complete_"+id+"_"+result_key)
	if completed:
		var snapshot: Dictionary = world.taiwan_life.to_dict()
		check(int(snapshot["records"].get(id,{}).get(result_key,0))==before_count+1,"actual_UI_completion_record_increments_once_"+id+"_"+result_key)
		check(world.taiwan_life.cash==before_cash+int(reward.get("cash",0)),"actual_UI_cash_matches_authored_branch_reward_"+id+"_"+result_key)
		if not npc.is_empty(): check(int(world.taiwan_life.trust.get(npc,0))==mini(100,before_trust+int(reward.get("trust",0))),"actual_UI_trust_matches_authored_branch_reward_"+id+"_"+result_key)
		check(world.taiwan_life.last_result.get("task_id","")==id and world.taiwan_life.last_result.get("route_id","")==result_key and int(world.taiwan_life.last_result.get("cash",-1))==int(reward.get("cash",0)) and int(world.taiwan_life.last_result.get("trust",-1))==int(reward.get("trust",0)),"actual_UI_result_reports_correct_route_and_reward_"+id+"_"+result_key)
	world._resume()
	return completed
func _play_prerequisites_ui(id: String) -> bool:
	for prerequisite: String in world.taiwan_life.tasks[id].get("prerequisites",[]):
		if world.taiwan_life.records.get(prerequisite,{}).is_empty():
			if not await _play_prerequisites_ui(prerequisite): return false
			if not await _play_job(prerequisite): return false
	check(world.taiwan_life.is_unlocked(id),"actual_UI_prerequisites_unlock_"+id)
	return world.taiwan_life.is_unlocked(id)
func _check_all_ui_routes() -> void:
	check(world.taiwan_life.tasks.size()==34,"full_root_UI_route_matrix_has_sixteen_chapters_and_eighteen_delivery_orders")
	for id: String in world.taiwan_life.tasks:
		var task: Dictionary = world.taiwan_life.tasks[id]
		var routes: Array[String] = []
		for option: Dictionary in task.get("choices",[]): routes.append(str(option["id"]))
		if routes.is_empty(): routes.append("")
		for selected_route: String in routes:
			# Each independent case resets via the production manager API. Its
			# prerequisites then earn records/cash/trust through real Root UI actions.
			world._resume()
			world.car.force_release()
			world.bicycle.force_release()
			world.taiwan_life.reset()
			await process_frame
			if not await _play_prerequisites_ui(id): continue
			if await _play_job(id,false,selected_route):
				var key := id+":"+("default" if selected_route.is_empty() else selected_route)
				completed_ui_routes.append(key)
				print("V04_UI_ROUTE_COMPLETED ",JSON.stringify({"route":key,"cash":world.taiwan_life.cash,"trust":world.taiwan_life.trust,"cargo":world.taiwan_life.cargo,"records":world.taiwan_life.records}))
	check(completed_ui_routes.size()==41,"all_forty_one_authored_routes_complete_through_actual_Root_UI")
	var unique: Dictionary = {}
	for key: String in completed_ui_routes: unique[key] = true
	check(unique.size()==41,"all_completed_Root_UI_routes_are_distinct_including_seven_extra_choices")
	# Keep the later save/retry probe meaningful: earn nonzero story trust and
	# rewards through the UI, in addition to the last completed parcel order.
	# No progress records, wallet or cargo are patched to create this fixture.
	await _play_job("TW-LIN-01",false,"separate")
	await _play_job("TW-LIN-02")
	check(world.taiwan_life.cash>0 and int(world.taiwan_life.trust.get("LIN",0))>0 and world.taiwan_life.records.size()>=3,"later_save_retry_fixture_has_real_nonzero_UI_earned_rewards_trust_records")
func _check_people_and_map() -> void:
	var unique_models: Dictionary = {}
	for row: Dictionary in world.taiwan_world.actors:
		var actor := row["node"] as Node3D
		var id := str(row["id"])
		var spec: Dictionary = world.taiwan_life.characters[id]
		unique_models[actor.scene_file_path] = true
		check(actor.scene_file_path=="res://assets/models/"+str(spec["appearance_key"])+".glb","story_actor_uses_actual_individual_asset_"+id)
		check(actor.name=="Story_"+id and actor.is_in_group("taiwan_story_people"),"real_story_actor_identity_"+id)
		check(actor.find_children("*","MeshInstance3D",true,false).size()>0 and actor.find_children("*","Skeleton3D",true,false).size()>0,"authored_skinned_character_mesh_"+id)
		var skeletons: Array[Node] = actor.find_children("*","Skeleton3D",true,false)
		check(not skeletons.is_empty() and (skeletons[0] as Skeleton3D).get_bone_count()>=53,"story_character_has_full_53_bone_body_rig_"+id)
		check(row["animation"]!=null and (row["animation"] as AnimationPlayer).is_playing(),"story_actor_real_idle_animation_"+id)
		check(row["animation"]!=null and (row["animation"] as AnimationPlayer).get_animation_list().size()>=8,"story_actor_has_eight_real_animation_clips_"+id)
		var labels: Array[Node] = actor.find_children("*","Label3D",true,false)
		check(labels.size()==1 and labels[0].text==str(spec["name"])+"｜"+str(spec["role"]),"rendered_character_name_and_role_"+id)
		if _place_station(str(spec["home_station"])):
			var label_text := ""
			for label: Node in world.hud._modal_box.find_children("*","Label",true,false): label_text += label.text
			check(label_text.contains(str(spec["name"])) and label_text.contains(str(spec["arc_dialogue"][0])),"actual_station_interaction_has_character_dialogue_"+id)
	check(unique_models.size()==8,"eight_story_people_use_eight_distinct_authored_models")
	world.hud.show_district_map()
	await process_frame
	await process_frame
	var map: Control = world.hud._large_map
	check(map.world_radius==400 and map.navigation_roads.size()>0,"actual_large_map_800m_span_and_expansion_roads")
	for id: String in world.taiwan_life.stations:
		check(map.markers.has(id),"actual_map_has_station_marker_"+id)
		if map.markers.has(id):
			var point: Vector2 = map.markers[id]
			check(map._area().has_point(map.world_to_map(point)) and map.map_to_world(map.world_to_map(point)).distance_to(point)<.01,"station_marker_mapping_within_expanded_map_"+id)
	world._resume()
func _check_story() -> void:
	check(not world.taiwan_life.is_unlocked("TW-LIN-02"),"second_character_chapter_initially_locked")
	await _play_job("TW-LIN-01",false,"separate")
	check(world.taiwan_life.trust.get("LIN",0)==4 and world.taiwan_life.is_unlocked("TW-LIN-02"),"actual_choice_rewards_trust_and_unlocks_second_chapter")
	await _play_job("TW-LIN-02")
	check(world.taiwan_life.trust.get("LIN",0)==9 and world.taiwan_life.records.has("TW-LIN-02"),"actual_second_chapter_finishes_with_cumulative_character_trust")
	if _place_station("market_square"):
		var dialogue_text := ""
		for label: Node in world.hud._modal_box.find_children("*","Label",true,false): dialogue_text += label.text
		check(dialogue_text.contains(str(world.taiwan_life.characters["LIN"]["arc_dialogue"][2])),"actual_station_person_remembers_completed_two_chapter_arc")
func _check_returns_and_timeout() -> void:
	if _start_ui("DEL-FOOD-06"):
		await _act_ui(world.taiwan_life.get_current_step())
		await _act_ui(world.taiwan_life.get_current_step())
		check(world.taiwan_life.cargo.size()==2 and world.taiwan_life.cargo_origins.values().size()==2,"real_UI_pickups_keep_two_distinct_origins")
		world.hud.show_life_phone("food")
		_press("停止接單／退回未送物品","actual_cargo_cancel")
		check(world.taiwan_life.status=="returning","actual_cancel_retains_cargo_and_requires_return")
		var previous_cash: int = world.taiwan_life.cash
		await _act_ui(world.taiwan_life.get_current_step())
		check(world.taiwan_life.cargo.size()==1 and world.taiwan_life.return_station=="arcade_bakery","real_first_return_keeps_other_origin")
		await _act_ui(world.taiwan_life.get_current_step())
		check(world.taiwan_life.status=="idle" and world.taiwan_life.cash==previous_cash,"real_final_return_gives_no_false_delivery_reward")
	if _start_ui("DEL-FOOD-02"):
		await _act_ui(world.taiwan_life.get_current_step())
		world._resume()
		world._process(0)
		for i: int in int(world.taiwan_life.tasks["DEL-FOOD-02"]["limit_seconds"])+1: world.taiwan_life.advance_time(1)
		check(world.taiwan_life.status=="failed" and world.taiwan_life.cargo.size()==1,"real_timed_work_fails_without_discarding_food")
		world.hud.show_life_phone("food")
		_press("停止接單／退回未送物品","actual_timeout_cancel")
		await _act_ui(world.taiwan_life.get_current_step())
		check(world.taiwan_life.status=="idle" and world.taiwan_life.cargo.is_empty(),"actual_timed_food_return_clears_work")
func _check_profiles() -> void:
	var profiles: Dictionary = {"phone":Vector2i(480,844),"tablet":Vector2i(1024,768),"desktop":Vector2i(1366,768)}
	var all_citizens: Array[Node] = get_nodes_in_group("ambient_citizens")
	var all_traffic: Array[Node] = get_nodes_in_group("ambient_traffic")
	check(all_citizens.size()==24 and all_traffic.size()==8,"whole_root_has_24_ambient_citizens_and_eight_traffic_actors")
	for name_value: String in profiles:
		world._resume()
		root.size = profiles[name_value]
		root.content_scale_size = profiles[name_value]
		world._select_device(name_value)
		var settings: Dictionary = world.device_profiles.get_settings()
		world.player.position = Vector3(-270,.2,-270)
		world.device_profiles.update_ambient(world.player)
		check(is_equal_approx(root.scaling_3d_scale,float(settings["resolution_scale"])) and is_equal_approx(root.mesh_lod_threshold,float(settings["lod_threshold"])),"actual_viewport_3d_scale_and_lod_"+name_value)
		check(world.player._camera.far==float(settings["camera_distance"]),"actual_camera_distance_"+name_value)
		check(world.hit_player.max_polyphony==int(settings["audio_voices"]),"actual_audio_voice_budget_"+name_value)
		var prop_draws := 0
		var invalid_draws := 0
		for info: Dictionary in world.taiwan_expansion._draws:
			if bool(info["large"]): continue
			prop_draws += 1
			var draw := info["node"] as GeometryInstance3D
			if not is_equal_approx(draw.visibility_range_end,float(settings["prop_distance"])+50): invalid_draws += 1
		check(prop_draws>0 and invalid_draws==0,"actual_sector_prop_visibility_preserves_corner_margin_"+name_value)
		if invalid_draws>0: print("V04_SECTOR_RANGE_CONFLICT ",JSON.stringify({"profile":name_value,"small_sector_draws":prop_draws,"incorrect_ranges":invalid_draws,"expected_range":float(settings["prop_distance"])+50}))
		check(not world.district_sun.shadow_enabled if name_value!="desktop" else true,"actual_mobile_shadow_budget_"+name_value)
		var citizen_count := 0
		var traffic_count := 0
		for actor: Node in all_citizens:
			if bool(actor.get_meta("device_budget_active",false)): citizen_count += 1
		for actor: Node in all_traffic:
			if bool(actor.get_meta("device_budget_active",false)): traffic_count += 1
		check(citizen_count>0 and citizen_count<=int(settings["max_citizens"]) and traffic_count<=int(settings["max_traffic"]),"actual_whole_world_ambient_budget_"+name_value)
		check(world.touch_controls.enabled==(name_value!="desktop"),"actual_device_input_mode_"+name_value)
		world.hud.show_life_phone("food")
		await process_frame
		await process_frame
		var panel_rect: Rect2 = world.hud._modal_panel.get_global_rect()
		print("V04_DEVICE_RECT ",JSON.stringify({"profile":name_value,"viewport":str(profiles[name_value]),"panel":str(panel_rect),"touch_enabled":world.touch_controls.enabled,"citizens":citizen_count,"traffic":traffic_count}))
		check(panel_rect.position.x>=-1 and panel_rect.position.y>=-1 and panel_rect.end.x<=profiles[name_value].x+1 and panel_rect.end.y<=profiles[name_value].y+1,"actual_modal_inside_device_viewport_"+name_value)
		var columns: Array[Node] = world.hud._modal_box.find_children("*","HBoxContainer",true,false)
		var split := false
		for column: Node in columns:
			if column.get_child_count()==2 and column.get_child(0) is VBoxContainer and column.get_child(1) is VBoxContainer:
				var left: Rect2 = (column.get_child(0) as Control).get_global_rect()
				var right: Rect2 = (column.get_child(1) as Control).get_global_rect()
				split = left.size.x>0 and right.size.x>0 and left.end.x<=right.position.x+1
		check(split==(name_value!="phone"),"actual_rendered_work_columns_"+name_value)
	for pair: Array in [["phone",Vector2i(360,800)],["phone",Vector2i(844,390)],["tablet",Vector2i(768,1024)]]:
		root.size = pair[1]
		root.content_scale_size = pair[1]
		world._select_device(pair[0])
		world.hud.show_life_phone("story")
		await process_frame
		await process_frame
		var device_size: Vector2i = pair[1]
		var panel_rect: Rect2 = world.hud._modal_panel.get_global_rect()
		check(panel_rect.position.x>=-1 and panel_rect.position.y>=-1 and panel_rect.end.x<=device_size.x+1 and panel_rect.end.y<=device_size.y+1,"actual_portrait_landscape_story_modal_fits_"+str(pair[0])+"_"+str(pair[1]))
		print("V04_ADDITIONAL_DEVICE_RECT ",JSON.stringify({"profile":pair[0],"viewport":str(device_size),"panel":str(panel_rect)}))
	world._resume()
func _check_real_traffic_brake() -> void:
	world._resume()
	var vehicle: Dictionary = world.city_life.traffic[0]
	var model := vehicle["model"] as Node3D
	world.player.position = model.position+model.basis.z*5+Vector3(0,.2,0)
	world.player.velocity = Vector3.ZERO
	world.device_profiles.update_ambient(world.player)
	await create_timer(.8).timeout
	print("V04_BASE_TRAFFIC_BRAKE ",JSON.stringify({"player":str(world.player.position),"car":str(model.position),"difference_local":str(model.basis.inverse()*(world.player.position-model.position)),"active":bool(model.get_meta("device_budget_active",false)),"stopped":vehicle["stopped"],"speed":vehicle["speed"],"overlap_count":(vehicle["sensor"] as Area3D).get_overlapping_bodies().size()}))
	check(bool(model.get_meta("device_budget_active",false)) and vehicle["stopped"] and float(vehicle["speed"])<.4,"actual_root_old_traffic_stops_before_real_player")
	# A normal budget tick, rather than a test flag, must wake a distant actor.
	world.player.position = Vector3(-270,.2,-270)
	world.device_profiles.update_ambient(world.player)
	check(not bool(model.get_meta("device_budget_active",true)),"far_player_makes_old_traffic_inactive_through_real_budget")
	world.player.position = model.position+model.basis.z*5+Vector3(0,.2,0)
	await create_timer(.55).timeout
	check(bool(model.get_meta("device_budget_active",false)),"normal_profile_process_activates_nearby_traffic_within_half_second_tick")
	await create_timer(.8).timeout
	check(vehicle["stopped"] and float(vehicle["speed"])<.4,"normal_budget_activation_still_brakes_real_nearby_traffic")
	world.player.position = model.position+model.basis.x*12+Vector3(0,.2,0)
	world.device_profiles.update_ambient(world.player)
	await create_timer(.6).timeout
	check(not vehicle["stopped"] and float(vehicle["speed"])>.4,"actual_root_old_traffic_resumes_after_real_player_clears")
func _check_real_player_attack() -> void:
	world._resume()
	world.car.force_release()
	world.bicycle.force_release()
	var citizen: Dictionary = world.taiwan_expansion.citizens[0]
	var body := citizen["body"] as CharacterBody3D
	world.player.position = body.position+Vector3(1.5,.1,0)
	world.player.velocity = Vector3.ZERO
	world.device_profiles.update_ambient(world.player)
	check(bool(body.get_meta("device_budget_active",false)),"expanded_citizen_is_active_for_real_attack_probe")
	check(world.player.grant_weapon("wrench") and world.player.equip_weapon("wrench"),"real_player_has_visible_tool_for_expanded_citizen_probe")
	check(world.player.begin_attack(),"actual_player_attack_emits_shipping_one_argument_signal")
	check(float(citizen["flee_until"])>world.taiwan_expansion.clock,"actual_one_argument_player_signal_sets_expanded_citizen_flee_clock")
	await physics_frame
	await physics_frame
	check(float(citizen["flee_until"])>world.taiwan_expansion.clock and Vector2(body.velocity.x,body.velocity.z).length()>float(citizen["speed"]),"real_expansion_physics_uses_flee_speed_after_player_attack")
func _culture_view_ui(id: String) -> bool:
	world.hud.show_life_phone()
	if not _press("文化活動：陀螺、木屐、手作與集章","actual_culture_directory"): return false
	var title := str(world.taiwan_activities.activities[id]["title"])
	return _press("查看「"+title+"」","actual_culture_view_"+id)
func _culture_start_ui(id: String) -> bool:
	world._resume()
	world.player.position = Vector3(-56,.2,52)
	world.car.force_release()
	world.bicycle.force_release()
	if not _culture_view_ui(id): return false
	var tries: int = world.taiwan_activities.attempts[id]
	_press("在現場開始／重玩","actual_remote_activity_start_"+id)
	check(world.taiwan_activities.status!="active" and world.taiwan_activities.attempts[id]==tries,"root_activity_remote_start_has_no_attempt_or_score_"+id)
	var station := str(world.taiwan_activities.activities[id]["station_id"])
	if not _place_station(station): return false
	if not _press("參加這一站的文化活動","actual_station_activity_entry_"+id): return false
	if not _press("在現場開始／重玩","actual_local_activity_start_"+id): return false
	check(world.taiwan_activities.active_id==id and world.taiwan_activities.status=="active","actual_foot_player_starts_culture_at_real_station_"+id)
	return world.taiwan_activities.status=="active"
func _check_culture_activities() -> void:
	check(world.taiwan_activities.activities.size()==4,"actual_root_has_four_culture_activities")
	var money_before: int = world.taiwan_life.cash
	var trust_before: Dictionary = world.taiwan_life.trust.duplicate(true)
	for id: String in ["TW-ACT-TOP","TW-ACT-CLOGS"]:
		if not _culture_start_ui(id): continue
		var task: Dictionary = world.taiwan_activities.activities[id]
		world.hud.show_pause()
		var pause_time: float = world.taiwan_activities.elapsed
		world._process(.3)
		check(world.taiwan_activities.elapsed==pause_time,"ordinary_pause_menu_freezes_culture_clock_"+id)
		world.activity_panel.show_activity(id)
		for beat: int in 8:
			world._process(float(task["targets"][beat])-world.taiwan_activities.round_elapsed)
			var button_text := "轉動（空白鍵）" if id=="TW-ACT-TOP" else "左腳（方向鍵）" if beat%2==0 else "右腳（方向鍵）"
			var old_hits: int = world.taiwan_activities.hits
			_press(button_text,"real_culture_beat_"+id+"_"+str(beat))
			check(world.taiwan_activities.hits==old_hits+1,"actual_root_clock_and_UI_score_exact_hit_"+id+"_"+str(beat))
			world._process(float(task["period"])-world.taiwan_activities.round_elapsed+.00001)
		check(world.taiwan_activities.status=="completed" and world.taiwan_activities.best[id]==100,"real_culture_UI_completes_eight_beats_"+id)
	if _culture_start_ui("TW-ACT-CRAFT"):
		_press("圓點","actual_wrong_craft_material")
		check(world.taiwan_activities.craft_index==0 and world.taiwan_activities.mistakes==1,"actual_wrong_craft_material_does_not_skip_recipe")
		for caption: String in ["紅色","白色","花朵","藍色","白色","條紋","白色","紅色","圓點"]: _press(caption,"actual_craft_recipe_"+caption)
		check(world.taiwan_activities.status=="completed" and world.taiwan_activities.score==90 and world.taiwan_activities.craft_index==9,"actual_craft_UI_finishes_three_recipes_with_exact_error_deduction")
	if _culture_start_ui("TW-ACT-WALK"):
		_press("在現場蓋這一站","actual_remote_walk_stamp")
		check(world.taiwan_activities.round_index==0,"actual_remote_walk_stamp_cannot_advance")
		_press("標示下一個集章站","actual_walk_map_next_station")
		var target := str(world.taiwan_activities.get_target_key())
		var p: Array = world.taiwan_life.stations[target]["position"]
		check(world.hud._mode=="map" and world.street_state.waypoint.distance_to(Vector2(p[0],p[1]))<.01,"walk_UI_marks_actual_expanded_station_on_root_map")
		for station: String in ["market_square","old_arcade","river_checkpoint","community_green"]:
			if not _place_station(station) or not _culture_view_ui("TW-ACT-WALK"): break
			_press("在現場蓋這一站","actual_local_stamp_"+station)
		check(world.taiwan_activities.status=="completed" and world.taiwan_activities.best["TW-ACT-WALK"]==100,"actual_walk_UI_completes_four_physically_reachable_stamps")
	check(world.taiwan_activities.badges.size()==4,"actual_root_earns_four_culture_badges_from_real_inputs")
	check(world.taiwan_life.cash==money_before and world.taiwan_life.trust==trust_before,"culture_inputs_do_not_change_delivery_cash_or_person_trust")
	for pair: Array in [["phone",Vector2i(360,800)],["phone",Vector2i(844,390)],["tablet",Vector2i(1024,768)],["desktop",Vector2i(1366,768)]]:
		root.size = pair[1]
		root.content_scale_size = pair[1]
		world._select_device(pair[0])
		if not _culture_start_ui("TW-ACT-TOP"): continue
		await process_frame
		await process_frame
		var clip: Rect2 = world.hud._modal_scroll.get_global_rect()
		var gauge: Rect2 = world.activity_panel.gauge.get_global_rect()
		var tap := _button("轉動（空白鍵）")
		check(tap!=null,"active_culture_real_touch_button_exists_"+str(pair[0])+"_"+str(pair[1]))
		if tap:
			var tap_rect: Rect2 = tap.get_global_rect()
			check(clip.encloses(gauge) and clip.encloses(tap_rect),"activity_gauge_and_action_both_operable_in_same_device_clip_"+str(pair[0])+"_"+str(pair[1]))
			print("V04_ACTIVITY_LAYOUT ",JSON.stringify({"profile":pair[0],"viewport":str(pair[1]),"clip":str(clip),"gauge":str(gauge),"action":str(tap_rect)}))
		_press("停止這次活動","actual_activity_stop_after_layout_review")
	world._resume()
func _check_save_retry_and_pause() -> void:
	world._select_device("phone")
	world.device_profiles.set_preference("sensitivity",1.6,true)
	world.device_profiles.set_preference("muted",true,true)
	world.player.position = Vector3(320,.2,0)
	world._process(0)
	check(world.player.position.x>300,"expanded_position_does_not_snap_back_to_old_150m_boundary")
	world._save(false)
	var saved: Dictionary = Save.load_state(91)
	check(not saved.is_empty() and world._valid_world_save(saved),"slot91_expanded_world_snapshot_is_valid")
	check(Save.save_state(saved,92)==OK,"slot92_expanded_world_snapshot_atomic_write")
	world.player.position = Vector3(-56,.2,52)
	world._load(92)
	check(world.player.position.x>300,"slot92_load_restores_expanded_world_position")
	for version: String in ["0.1","0.2","0.3"]:
		var old := saved.duplicate(true)
		old.erase("taiwan_life")
		old.erase("taiwan_activities")
		old.erase("checkpoint")
		for key: String in old["objects"].keys():
			if key.begins_with("TW_station_"): old["objects"].erase(key)
		if version=="0.1":
			old.erase("optional")
			old.erase("city_life")
		if version in ["0.1","0.2"]:
			old.erase("district_systems")
			old.erase("street_state")
		old["player"]["position"] = [-56,.2,52]
		if old.has("street_state"):
			old["street_state"]["sensitivity"] = .7
			old["street_state"]["muted"] = false
			old["street_state"]["waypoint"] = [110,-50]
		check(world._restore(old) and world.player.position.distance_to(Vector3(-56,.2,52))<1,"actual_restore_legacy_"+version+"_at_valid_playable_spawn")
		check(world.device_profiles.get_profile()=="phone" and is_equal_approx(world.player.mouse_sensitivity,.003*1.6) and AudioServer.is_bus_mute(0),"legacy_campaign_does_not_replace_device_preferences_"+version)
		check(world.taiwan_activities.badges.is_empty(),"legacy_campaign_without_culture_migrates_to_empty_results_"+version)
	check(world._restore(saved),"restore_current_snapshot_after_legacy_probes")
	check(world.taiwan_activities.badges.size()==4,"current_expanded_save_restores_four_earned_culture_badges")
	if _start_ui("DEL-FOOD-06"):
		await _act_ui(world.taiwan_life.get_current_step())
		var life_before: Dictionary = world.taiwan_life.to_dict()
		check(int(life_before["cash"])>0 and not life_before["trust"].is_empty() and not life_before["records"].is_empty() and not life_before["cargo"].is_empty(),"main_retry_probes_nonzero_UI_earned_life_ledger_and_active_cargo")
		var activities_before: Dictionary = world.taiwan_activities.to_dict()
		world._retry()
		world._process(0)
		check(_equal(world.taiwan_life.to_dict(),life_before),"main_retry_keeps_life_rewards_trust_records_and_active_cargo")
		check(_equal(world.taiwan_activities.to_dict(),activities_before),"main_retry_keeps_earned_culture_results_and_attempts")
		await process_frame
		check(is_instance_valid(world.taiwan_world.carried_visual),"actual_active_cargo_has_a_real_visible_object")
		if is_instance_valid(world.taiwan_world.carried_visual):
			check(not str(world.taiwan_world.carried_visual.scene_file_path).contains("tw_parcel_shelf"),"carried_cargo_is_not_a_shrunken_multilevel_station_shelf")
		world.hud.show_life_phone("food")
		world._process(0)
		var before: Dictionary = world.taiwan_life.to_dict()
		var positions: Array[Vector3] = []
		for node: Node in get_nodes_in_group("ambient_citizens"): positions.append((node as Node3D).position)
		for node: Node in get_nodes_in_group("ambient_traffic"): positions.append((node as Node3D).position)
		await create_timer(.12,true).timeout
		world._process(.12)
		check(_equal(world.taiwan_life.to_dict(),before),"actual_pause_freezes_work_clock_deadline_and_cargo")
		var index := 0
		var frozen := true
		for group: String in ["ambient_citizens","ambient_traffic"]:
			for node: Node in get_nodes_in_group(group):
				if not (node as Node3D).position.is_equal_approx(positions[index]): frozen = false
				index += 1
		check(frozen,"actual_pause_freezes_old_and_expanded_ambient_actors")
		world._resume()
