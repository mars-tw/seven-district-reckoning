extends SceneTree
## Deterministic native review. Fixture placement never represents human travel.
## Runner isolates user data; this fixture reserves save slot 93 and refuses an existing file.

const Street = preload("res://scripts/systems/street_state.gd")
const Player = preload("res://scripts/player/player_controller.gd")
const Map = preload("res://scripts/ui/district_map.gd")
const ContactShadow = preload("res://scripts/world/contact_shadow.gd")
const ActualScene = preload("res://scenes/main.tscn")
const Save = preload("res://scripts/save/save_manager.gd")
const SLOT := 93

class ReviewRoot extends "res://scripts/main.gd":
	func _save(_show_notice: bool = true) -> void:
		if play_started:
			SaveScript.save_state(_snapshot(), 93)

class DamageProbe extends Node3D:
	var damage: float = 0
	func apply_hit(_hit: String, _source: String, amount: float) -> void:
		damage = amount

var world: Node3D
var passed: Array[String] = []
var failures: Array[String] = []
var map_event_count: int = 0
var map_event_value: Vector2 = Vector2.ZERO

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	if condition:
		passed.append(label)
		print("V03_INTEGRATION_PASS ", label)
	else:
		failures.append(label)
		push_error("V03_INTEGRATION_FAIL " + label)

func _run() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists("user://save93.json" + suffix):
			push_error("Review slot 93 exists; test preserves it and exits.")
			quit(2)
			return
	_check_street_state()
	await _check_stamina_fixture()
	await _check_map_contract()
	if "--v03-preflight" not in OS.get_cmdline_user_args():
		await _check_production_world()
	print("V03_INTEGRATION_RESULT ", JSON.stringify({"passed_count": passed.size(), "failures": failures, "native_deterministic_review": true, "browser_play_verified": false, "mobile_hardware_verified": false, "photorealism_claimed": false, "real_Taichung_GIS_claimed": false}))
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save93.json" + suffix))
	if is_instance_valid(world): world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _check_street_state() -> void:
	var street := Street.new()
	street.reset()
	check(street.hour == 15.5 and street.time_text() == "15:30", "street_defaults_to_1530")
	for index: int in 1200: street.advance(1)
	check(is_equal_approx(street.hour, 15.5), "full_24h_cycle_takes_20_minutes_of_valid_gameplay")
	street.hour = 23.99
	street.advance(1)
	check(is_equal_approx(street.hour, 0.01), "midnight_wraps_without_invalid_save_hour")
	street.cycle_enabled = false
	street.advance(1)
	check(is_equal_approx(street.hour, 0.01), "fixed_time_does_not_advance")
	street.cycle_enabled = true
	var before: float = street.hour
	for delta: float in [-1.0, 0.0, 2.0, INF, NAN]: street.advance(delta)
	check(street.hour == before, "invalid_time_deltas_do_not_change_clock")
	street.hour = 12
	check(is_equal_approx(street.daylight(), 1), "noon_has_maximum_daylight")
	street.hour = 0
	check(street.daylight() == 0, "midnight_has_zero_daylight")
	check(street.set_waypoint(Vector2(120, -88)) and street.has_waypoint and street.waypoint == Vector2(120,-88), "waypoint_accepts_playable_world_coordinate")
	for point: Vector2 in [Vector2(146,0), Vector2(0,-146), Vector2(INF,0), Vector2(NAN,0)]:
		check(not street.set_waypoint(point) and street.waypoint == Vector2(120,-88), "waypoint_rejects_invalid_coordinate_" + str(point))
	street.hour = 19.25
	street.quality = "quality"
	street.difficulty = "relaxed"
	street.sensitivity = 1.4
	street.muted = true
	var expected := street.to_dict()
	var restored := Street.new()
	check(restored.from_dict(expected) and restored.to_dict() == expected, "street_settings_and_waypoint_roundtrip")
	var decoded: Variant = JSON.parse_string(JSON.stringify(expected))
	check(restored.from_dict(decoded) and _same_saved_value(restored.to_dict(), expected), "street_settings_and_waypoint_JSON_roundtrip")
	for field: String in ["version","hour","cycle_enabled","quality","difficulty","sensitivity","muted","has_waypoint","waypoint"]:
		var corrupt := expected.duplicate(true)
		corrupt[field] = "bad-value"
		check(not restored.from_dict(corrupt) and restored.to_dict() == expected, "street_corrupt_field_rejects_atomically_" + field)
	var invalid := expected.duplicate(true)
	invalid["waypoint"] = [145.01,0]
	check(not restored.from_dict(invalid) and restored.to_dict() == expected, "street_corrupt_waypoint_rejects_atomically")

func _check_stamina_fixture() -> void:
	for action: String in ["move_forward","move_back","move_left","move_right","sprint","jump","attack","interact","mount","cycle_weapon"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var player := Player.new()
	root.add_child(player)
	player.set_physics_process(false)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	await process_frame
	Input.action_press("move_forward")
	Input.action_press("sprint")
	player._update_movement(0.1)
	check(is_equal_approx(player.stamina,98.2), "moving_sprint_spends_actual_player_stamina")
	for index: int in 60: player._update_movement(0.1)
	check(player.stamina_exhausted and player.stamina < 20, "sprint_exhaustion_blocks_immediate_full_speed_restart")
	check(Vector2(player.velocity.x,player.velocity.z).length() <= player.walk_speed+0.001, "exhausted_player_uses_walk_speed")
	Input.action_release("sprint")
	for index: int in 20: player._update_movement(0.1)
	check(player.stamina > 20 and not player.stamina_exhausted, "walking_recovers_stamina_and_clears_exhaustion_at_threshold")
	Input.action_release("move_forward")
	player.set_stamina(50)
	Input.action_press("sprint")
	player._update_movement(0.1)
	check(player.stamina > 50, "stationary_shift_does_not_consume_stamina")
	Input.action_release("sprint")
	player.maximum_stamina = 120
	player.set_stamina(200)
	check(player.stamina == 120, "stamina_clamps_to_upgraded_maximum")
	player.set_stamina(-1)
	check(player.stamina == 0 and player.stamina_exhausted, "negative_stamina_clamps_and_enters_exhaustion")
	player.health = 35
	player.heal(40)
	check(player.health == 75, "healing_reaches_expected_health_after")
	player.heal(100)
	check(player.health == 100, "healing_cannot_exceed_maximum_health")
	for value: float in [-10.0,0,INF,NAN]: player.heal(value)
	check(player.health == 100, "invalid_heal_amounts_do_not_damage_or_corrupt_health")
	player.incoming_damage_multiplier = 0.65
	player.apply_hit("fixture-hit","fixture",20)
	check(player.health == 87, "relaxed_damage_multiplier_affects_real_apply_hit")
	player.apply_hit("fixture-hit","fixture",20)
	check(player.health == 87, "same_hit_still_applies_only_once")
	var target := DamageProbe.new()
	root.add_child(target)
	player.tool_damage_multiplier = 1.2
	player._deliver_hit(target,24)
	check(is_equal_approx(target.damage,28.8), "tool_upgrade_changes_real_delivered_damage")
	player.restore_health()
	check(player.health == 100 and player.stamina == 120 and not player.stamina_exhausted, "restore_health_restores_upgraded_stamina")
	player.queue_free()
	target.queue_free()
	await process_frame

func _check_map_contract() -> void:
	var map := Map.new()
	map.custom_minimum_size = Vector2(350,350)
	root.add_child(map)
	map.size = Vector2(540,320)
	await process_frame
	check(map.custom_minimum_size.x>=350 and map.custom_minimum_size.y>=350,"map_ready_preserves_callers_350px_minimum_size")
	for point: Vector2 in [Vector2(-150,-150),Vector2.ZERO,Vector2(145,145),Vector2(51,-62)]:
		check(map.map_to_world(map.world_to_map(point)).distance_to(point) < 0.0001, "map_coordinate_roundtrip_"+str(point))
	map.waypoint_selected.connect(func(point: Vector2) -> void: map_event_count += 1; map_event_value = point)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = map.world_to_map(Vector2(35,-70))
	map._gui_input(event)
	check(map_event_count == 1 and map_event_value.distance_to(Vector2(35,-70)) < 0.001, "map_left_click_emits_only_world_waypoint")
	event.position = Vector2.ZERO
	map._gui_input(event)
	check(map_event_count == 1, "map_margin_click_emits_no_waypoint")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = map.world_to_map(Vector2(148,148))
	map._gui_input(touch)
	check(map_event_count == 2 and map_event_value == Vector2(145,145), "map_touch_clamps_to_safe_boundary")
	map.queue_free()
	await process_frame

func _same_saved_value(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return is_equal_approx(float(a),float(b))
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not _same_saved_value(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index: int in a.size():
			if not _same_saved_value(a[index],b[index]): return false
		return true
	return a == b

func _check_production_world() -> void:
	world = ActualScene.instantiate()
	world.set_script(ReviewRoot)
	root.add_child(world)
	current_scene = world
	world.is_test_mode = true
	world.hud.show_settings()
	await process_frame
	var return_title := _find_button(world.hud,"返回開頭")
	check(return_title != null and not world.play_started,"title_settings_offer_return_to_title_before_gameplay")
	if return_title: return_title.pressed.emit()
	check(world.hud.get_menu_mode()=="title" and paused and not world.play_started,"title_settings_return_cannot_resume_unstarted_world")
	world._new_game()
	await physics_frame
	await physics_frame
	check(world.get("district_systems") != null and world.get("street_state") != null, "production_root_has_progression_and_street_state")
	if world.get("district_systems") == null or world.get("street_state") == null: return
	var mei_direction: Vector3 = (world.targets["mei"]-world.player.position)
	mei_direction.y = 0
	check(world.player._facing.dot(mei_direction.normalized())>0.999 and is_equal_approx(world.player.get_view_yaw(),PI+atan2(4.0,5.0)),"production_initial_camera_and_character_face_Mei_shop")
	world.set_process(false)
	await _check_human_imports()
	await _check_real_map_GUI()
	await _check_shop_and_stats()
	await _check_walking_and_pause()
	await _check_world_progression_callbacks()
	await _check_settings_controls()
	await _check_touch_sprint()
	await _check_save_migration_and_retry()
	await _check_shop_save_relocation()
	_check_new_game_reset()

func _find_map(node: Node) -> Control:
	if node.get_script() == Map: return node as Control
	for child: Node in node.get_children():
		var found := _find_map(child)
		if found: return found
	return null

func _find_button(node: Node, text_value: String, prefix: bool = false) -> Button:
	if node is Button and (node.text.begins_with(text_value) if prefix else node.text == text_value): return node as Button
	for child: Node in node.get_children():
		var found := _find_button(child,text_value,prefix)
		if found: return found
	return null

func _GUI_click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion,true)
	var down := InputEventMouseButton.new()
	down.position = at
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down,true)
	var up := down.duplicate()
	up.pressed = false
	root.push_input(up,true)

func _find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node as AnimationPlayer
	for child: Node in node.get_children():
		var found := _find_animation(child)
		if found: return found
	return null

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node as Skeleton3D
	for child: Node in node.get_children():
		var found := _find_skeleton(child)
		if found: return found
	return null

func _check_human_imports() -> void:
	for id: String in ["hero_human","guard_human","civilian_human","mei_human","yuan_human","zhou_human"]:
		var path := "res://assets/models/"+id+".glb"
		check(ResourceLoader.exists(path),"human_import_available_"+id)
		if not ResourceLoader.exists(path): continue
		var scene := load(path) as PackedScene
		check(scene != null,"human_asset_loads_as_real_PackedScene_"+id)
		if scene == null: continue
		var model := scene.instantiate() as Node3D
		world.add_child(model)
		var skeleton := _find_skeleton(model)
		var animator := _find_animation(model)
		check(skeleton != null and skeleton.get_bone_count() >= 50,"human_has_articulated_skeleton_"+id)
		var skinned_count := 0
		var textured_count := 0
		for mesh_node: Node in model.find_children("*","MeshInstance3D",true,false):
			if mesh_node.mesh != null and mesh_node.skin != null and not mesh_node.skeleton.is_empty(): skinned_count += 1
			if mesh_node.mesh == null: continue
			for surface_index: int in mesh_node.mesh.get_surface_count():
				var material := mesh_node.get_active_material(surface_index) as StandardMaterial3D
				if material and material.albedo_texture != null: textured_count += 1
		check(skinned_count >= 1 and textured_count >= 3,"human_has_real_skinned_textured_geometry_"+id)
		check(animator != null,"human_has_real_AnimationPlayer_"+id)
		if animator:
			for required: String in ["idle","walk","run","attack","hit","drive","pedal","knockdown"]:
				var found := false
				for name_value: StringName in animator.get_animation_list():
					if String(name_value).to_lower().ends_with(required):
						var clip := animator.get_animation(name_value)
						found = clip.length > 0 and clip.get_track_count() > 0
				check(found,"human_has_nonempty_skeletal_clip_"+id+"_"+required)
		model.queue_free()
		await process_frame
	check(world.player._visual_scene.resource_path.ends_with("hero_human.glb"),"production_player_uses_new_human_model")
	check(world.player.animations_missing.is_empty(),"production_player_has_no_missing_runtime_clips")
	for guard: Node in world.guards.values():
		check(guard._visual_scene.resource_path.ends_with("guard_human.glb"),"production_guard_uses_new_human_model_"+guard.name)
	var rescue_models := {"rescue_A":"civilian_human.glb","rescue_B":"zhou_human.glb","extra_A":"yuan_human.glb","extra_B":"civilian_human.glb"}
	for person: Node in world.people.values():
		check(person.visual.scene_file_path.ends_with(rescue_models[person.name]),"production_rescue_uses_new_human_model_"+person.name)
	for citizen: Dictionary in world.city_life.citizens:
		check(citizen["model"].scene_file_path.ends_with("civilian_human.glb"),"production_ambient_citizen_uses_new_human_model_"+str(citizen["body"].name))
	check(world.contact_people.size()==3,"production_world_has_three_distinct_story_character_models")
	for person: Node3D in world.contact_people:
		check(person.scene_file_path.get_file() in ["mei_human.glb","yuan_human.glb","zhou_human.glb"],"production_story_character_uses_distinct_human_asset_"+person.name)
		check(person.process_mode==Node.PROCESS_MODE_PAUSABLE,"production_story_character_animation_pauses_"+person.name)
	world.player.grant_weapon("wrench")
	check(world.player.find_child("RightHandToolAttachment",true,false) != null and world.player.weapon_visual_available,"new_human_hand_bone_has_real_held_tool")

func _check_real_map_GUI() -> void:
	world.hud.show_district_map()
	await process_frame
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var map := _find_map(world.hud)
	check(map != null and map.is_visible_in_tree(),"real_HUD_opens_interactive_district_map")
	if map:
		var old_regions: Array[Dictionary] = world.city_life.get_districts()
		var new_regions: Array[Dictionary] = world.taiwan_expansion.get_regions()
		check(old_regions.size()==6 and new_regions.size()==8 and map.districts.size()==14,"production_map_keeps_six_old_and_eight_new_authored_districts")
		for region: Dictionary in old_regions+new_regions:
			check(map.districts.has(region),"production_map_retains_complete_authored_region_"+str(region["id"]))
		check(map._area().size.x>=300 and map._area().size.y>=300 and map.map_font != null,"desktop_map_plot_is_large_enough_to_draw_region_names")
		var expected_blocks: Array[AABB] = world.base_obstacle_bounds.duplicate()
		expected_blocks.append_array(world.city_life.get_obstacle_bounds())
		expected_blocks.append_array(world.taiwan_expansion.get_obstacle_bounds())
		var complete_blocks: bool = map.blocks.size()==expected_blocks.size()
		for block: AABB in expected_blocks:
			if not map.blocks.has(block): complete_blocks = false
		check(complete_blocks,"production_map_receives_all_old_and_expanded_real_collision_bounds")
		check(map.blocks.has(AABB(Vector3(-62,0,61),Vector3(16,8,8))),"production_map_contains_new_Mei_shop_real_16x8_collision_footprint")
		var before_position: Vector3 = world.player.position
		var destination := Vector2(111,-58)
		_GUI_click(map.get_global_transform_with_canvas()*map.world_to_map(destination))
		await process_frame
		check(world.street_state.has_waypoint and world.street_state.waypoint.distance_to(destination)<0.5,"real_GUI_map_click_reaches_root_waypoint_state")
		check(world.player.position == before_position,"real_GUI_waypoint_marks_navigation_without_teleport")
		check(map.has_waypoint and map.waypoint_position.distance_to(destination)<0.5,"real_GUI_map_immediately_draws_selected_navigation_marker")
		check(root.get_visible_rect().encloses(world.hud._modal_panel.get_global_rect()),"production_map_modal_fits_native_viewport")
	var detail: Node = world.get_node_or_null("UrbanDetail")
	check(detail != null,"production_root_contains_real_urban_detail")
	if detail:
		var bounds: Array[AABB] = detail.get_visual_bounds()
		var contained := not bounds.is_empty()
		for box: AABB in bounds:
			contained = contained and box.position.x >= -150.001 and box.end.x <= 150.001 and box.position.z >= -150.001 and box.end.z <= 150.001
		check(contained,"urban_visual_bounds_stay_inside_300m_playable_map")
		var road := detail.get_node("UrbanSurface_asphalt") as MultiMeshInstance3D
		# Dummy RenderingServer returns identity when reading back MultiMesh transforms.
		# These CPU matrices are the same authored transforms submitted to the real renderer.
		var transforms: Array = detail._groups["asphalt"]["transforms"]
		var first: AABB = transforms[0]*road.multimesh.mesh.get_aabb()
		var second: AABB = transforms[1]*road.multimesh.mesh.get_aabb()
		check(absf(first.size.x-294)<0.02 and absf(first.size.z-15)<0.02,"actual_east_west_road_visual_has_correct_axes_and_width")
		check(absf(second.size.z-294)<0.02 and absf(second.size.x-15)<0.02,"actual_north_south_road_visual_has_correct_axes_and_width")
	world._resume()

func _rank_fixture(manager: Node) -> void:
	# A valid replay fixture unlocks offers; it is not reported as actual player travel.
	manager.reset()
	manager.set_paused(false)
	manager.record_walk(Vector3(-100,0,0),0.1,true)
	for index: int in range(1,401): manager.record_walk(Vector3(-100+index*0.5,0,0),0.1,true)
	for index: int in range(1,401): manager.record_walk(Vector3(100-index*0.5,0,0),0.1,true)
	for id: String in ["SIDE-001","SIDE-004","SIDE-007"]: manager.record_action("side_completed",id,"fixture:"+id)
	for index: int in 8: manager.record_action("destroy","sandbox_%d"%index,"fixture:destroy:%d"%index)
	world._refresh_system_stats()

func _check_shop_and_stats() -> void:
	var main_before: Dictionary = world.missions.to_dict()
	var optional_before: Dictionary = world.optional.to_dict()
	world.player.position = Vector3(0,0.1,20)
	world.player.velocity = Vector3.ZERO
	world.player.health = 30
	world._purchase_supply("healing")
	check(world.district_systems.credits == 120 and world.player.health == 30,"remote_supply_request_cannot_spend_or_heal")
	world.player.position = Vector3(-58,0.1,57)
	world.player.health = 100
	world._purchase_supply("healing")
	check(world.district_systems.credits == 120 and world.player.health == 100,"full_health_supply_request_does_not_spend_credits")
	await process_frame
	await process_frame
	var attempts: Array[int] = [0]
	var observe_purchase: Callable = func(id: String) -> void:
		if id=="healing": attempts[0]+=1
	world.hud.purchase_requested.connect(observe_purchase)
	var healing_offer := _find_button(world.hud,"急救補給",true)
	if healing_offer: _GUI_click(healing_offer.get_global_rect().get_center())
	await process_frame
	await process_frame
	world.hud.purchase_requested.disconnect(observe_purchase)
	var feedback: Label = null
	var feedback_index: int = -1
	var offer_index: int = -1
	var feedback_count: int = 0
	for item: Node in world.hud._modal_box.get_children():
		if item is Label and item.text==world.district_systems.last_notice:
			feedback = item as Label
			feedback_index = item.get_index()
			feedback_count+=1
		if item is Button and item.text.begins_with("急救補給"): offer_index=item.get_index()
	var feedback_visible: bool = feedback != null and feedback.is_visible_in_tree() and world.hud._modal_scroll.get_global_rect().grow(0.5).encloses(feedback.get_global_rect())
	check(attempts[0]==1 and world.district_systems.credits==120 and world.player.health==100 and world.district_systems.last_notice.contains("生命已滿") and feedback_count==1 and feedback_index>=0 and offer_index>feedback_index and feedback_visible,"actual_full_health_GUI_purchase_keeps_credits_and_shows_rejection_above_first_offer_in_visible_clip")
	world.player.health = 30
	world._purchase_supply("healing")
	check(world.district_systems.credits == 85 and world.player.health == 70,"near_shop_purchase_applies_exact_health_after_and_cost")
	world.player.position = Vector3(-58,0.1,63.1)
	world.player.health = 30
	world._purchase_supply("healing")
	check(world.district_systems.credits == 85 and world.player.health == 30,"outside_six_metre_shop_radius_cannot_purchase")
	_rank_fixture(world.district_systems)
	check(world.district_systems.rank == 4 and world.district_systems.credits == 430,"valid_progression_fixture_unlocks_final_rank")
	world.player.position = Vector3(-58,0.1,57)
	world.player.velocity = Vector3.ZERO
	for id: String in ["stamina","tool_power","vehicle_service"]: world._purchase_supply(id)
	check(world.player.maximum_stamina == 120 and world.player.stamina <=120,"purchased_stamina_upgrade_reaches_actual_player")
	check(is_equal_approx(world.player.tool_damage_multiplier,1.2),"purchased_tool_upgrade_reaches_actual_player")
	check(is_equal_approx(world.bicycle.acceleration_multiplier,1.15) and is_equal_approx(world.car.acceleration_multiplier,1),"purchased_bike_upgrade_only_changes_bicycle")
	check(world.district_systems.credits == 95,"three_real_upgrade_purchases_spend_exact_cost")
	var before: Dictionary = world.district_systems.to_dict()
	world._purchase_supply("tool_power")
	check(world.district_systems.to_dict() == before,"one_time_tool_upgrade_cannot_be_bought_twice")
	var probe := DamageProbe.new()
	world.add_child(probe)
	world.player._deliver_hit(probe,24)
	check(is_equal_approx(probe.damage,28.8),"shop_upgrade_changes_actual_delivered_tool_damage")
	probe.queue_free()
	world.bicycle.position = Vector3(0,0.1,25)
	world.player.position = world.bicycle.position+Vector3(1,0,0)
	world.bicycle.speed_mps = 0
	check(world.bicycle.enter(world.player),"actual_bicycle_accepts_player_for_upgrade_test")
	world.player._physics_process(0)
	check(world.player._contact_shadow != null and not world.player._contact_shadow.visible,"mounted_player_hides_non_solid_contact_shadow")
	world.bicycle.set_physics_process(false)
	Input.action_press("move_forward")
	world.bicycle._physics_process(0.1)
	check(is_equal_approx(world.bicycle.speed_mps,0.345),"shop_upgrade_changes_actual_bicycle_acceleration_step")
	Input.action_release("move_forward")
	world.bicycle.force_release()
	world.player._physics_process(0)
	var shadow: MeshInstance3D = world.player._contact_shadow
	var shadow_material := shadow.material_override as StandardMaterial3D
	var shared: bool = shadow_material != null and shadow_material.albedo_texture != null and shadow_material.albedo_texture.get_size()==Vector2(32,32)
	for node: Node in world.find_children("*","MeshInstance3D",true,false):
		if node.get_script()==ContactShadow:
			shared = shared and node.material_override==shadow_material and not node.is_in_group("damageable") and node.find_children("*","CollisionObject3D",true,false).is_empty() and node.find_children("*","CollisionShape3D",true,false).is_empty()
	check(shared and shadow.visible,"contact_shadows_share_32px_material_and_add_no_solid_or_damageable_objects")
	world.bicycle.set_physics_process(true)
	check(world.missions.to_dict() == main_before and world.optional.to_dict() == optional_before,"supply_and_growth_leave_original_mission_reward_ledgers_unchanged")

func _check_walking_and_pause() -> void:
	world.district_systems.reset()
	world._refresh_system_stats()
	world._resume()
	world._process(0)
	world.player.position = Vector3(0,0.15,20)
	world.player.velocity = Vector3.ZERO
	world.player._camera_pivot.rotation.y = 0
	world.player.set_stamina(100)
	await physics_frame
	await physics_frame
	world.district_systems.reset_walk_sample()
	Input.action_press("move_back")
	Input.action_press("sprint")
	var origin: Vector3 = world.player.position
	for index: int in 50:
		await physics_frame
		world._process(world.get_physics_process_delta_time())
	Input.action_release("move_back")
	Input.action_release("sprint")
	check(world.player.position.distance_to(origin)>3,"actual_player_physics_moves_on_real_city_street")
	check(world.district_systems.walking_distance>2 and world.district_systems.walking_distance<10,"root_records_actual_physics_walking_samples")
	check(world.player.stamina<98,"actual_player_physics_sprinting_consumes_stamina")
	world.hud.show_pause()
	world._process(0)
	var frozen_position: Vector3 = world.player.position
	var frozen_stamina: float = world.player.stamina
	var frozen_distance: float = world.district_systems.walking_distance
	var frozen_hour: float = world.street_state.hour
	Input.action_press("move_back")
	Input.action_press("sprint")
	await create_timer(0.3,true).timeout
	world._process(0.3)
	check(world.player.position == frozen_position and world.player.stamina == frozen_stamina,"actual_pause_freezes_player_position_and_stamina")
	check(world.district_systems.walking_distance == frozen_distance and world.street_state.hour == frozen_hour,"actual_pause_excludes_walking_reward_and_day_cycle_time")
	Input.action_release("move_back")
	Input.action_release("sprint")
	world._resume()
	world._process(0)
	world.player.position = Vector3(-56,0.2,52)
	world.player.velocity = Vector3.ZERO
	world._process(0.1)
	check(world.district_systems.walking_distance == frozen_distance,"respawn_style_large_position_jump_does_not_award_walking")

func _check_world_progression_callbacks() -> void:
	world._resume()
	world._process(0)
	var original_scores: Dictionary = world.missions.scores.duplicate(true)
	for index: int in 8:
		var id := "sandbox_%d"%index
		world.objects[id].restore({})
		world.player._deliver_hit(world.objects[id],45)
		check(world.objects[id].broken,"actual_training_object_breaks_"+id)
	check(world.district_systems.to_dict()["destroyed"].size()==8 and "tools" in world.district_systems.to_dict()["rewarded"],"real_world_destruction_callback_completes_tools_challenge")
	var credits: int = world.district_systems.credits
	world.objects["sandbox_0"].restore({})
	world.player._deliver_hit(world.objects["sandbox_0"],45)
	check(world.district_systems.credits==credits,"repeated_same_world_target_never_rewards_tools_twice")
	world._start_optional("SIDE-007")
	world._process(0)
	check(world.optional.active_id=="SIDE-007","production_optional_selection_starts_real_commission")
	for id: String in ["SIDE_007_backpack","SIDE_007_water","SIDE_007_safe"]:
		var target: Node3D = world.objects[id]
		world.player.position = target.position+Vector3(1.5,0.05,0)
		world.player.velocity = Vector3.ZERO
		world._update_interaction()
		check(world.nearest != null and world.nearest.get("object_id")==id,"actual_nearest_commission_target_"+id)
		if world.nearest != null and world.nearest.get("object_id")==id: world.player.interaction_requested.emit()
		await process_frame
	check(world.optional.status=="completed" and world.optional.wallet==140,"actual_world_commission_keeps_original_140_voucher_reward")
	check(world.district_systems.to_dict()["commissions"].has("SIDE-007"),"real_optional_completion_callback_reaches_growth_ledger")
	var preserved: Dictionary = world.district_systems.to_dict()
	world.optional.rewarded.emit({"task_id":"SIDE-007","first_completion":true})
	check(world.district_systems.to_dict()==preserved,"replayed_completed_commission_signal_cannot_duplicate_growth")
	for key: String in ["parts_vouchers","evidence_score","community_trust","rescued_count"]:
		check(world.missions.scores.get(key)==original_scores.get(key),"new_growth_callbacks_preserve_original_main_score_"+key)

func _check_settings_controls() -> void:
	world.hud.show_settings()
	await process_frame
	check(world.hud.get_menu_mode()=="settings" and paused,"actual_HUD_settings_pause_gameplay")
	for entry: Array in [["日間",10.0,"day"],["黃昏",17.5,"dusk"],["夜間",21.0,"night"]]:
		var button := _find_button(world.hud,str(entry[0]))
		check(button != null,"actual_HUD_time_preference_button_"+str(entry[2]))
		if button: button.pressed.emit()
		await process_frame
		check(world.street_state.hour==float(entry[1]),"actual_HUD_time_preference_updates_world_"+str(entry[2]))
		var expected_energy: float = lerpf(0.13,1.0,world.street_state.daylight())
		check(is_equal_approx(world.district_sun.light_energy,expected_energy),"actual_time_preference_changes_world_sunlight_"+str(entry[2]))
	var relaxed := _find_button(world.hud,"輕鬆",true)
	if relaxed: relaxed.pressed.emit()
	await process_frame
	check(world.street_state.difficulty=="relaxed" and is_equal_approx(world.player.incoming_damage_multiplier,0.65),"actual_HUD_difficulty_updates_damage_received")
	var power := _find_button(world.hud,"省電",true)
	if power: power.pressed.emit()
	await process_frame
	var normal_disabled := true
	for material: StandardMaterial3D in world.urban_detail._materials.values():
		normal_disabled = normal_disabled and not material.normal_enabled and not material.ao_enabled
	check(world.street_state.quality=="performance" and normal_disabled and not world.district_sun.shadow_enabled,"actual_HUD_performance_quality_applies_to_renderer_configuration")
	world._resume()

func _check_touch_sprint() -> void:
	root.content_scale_size = Vector2i(844,390)
	root.size = Vector2i(844,390)
	for menu: String in ["map","systems","settings"]:
		match menu:
			"map": world.hud.show_district_map()
			"systems": world.hud.show_systems(false)
			"settings": world.hud.show_settings()
		world.hud._resize_modal()
		await process_frame
		await process_frame
		check(root.get_visible_rect().encloses(world.hud._modal_panel.get_global_rect()),"new_"+menu+"_modal_fits_844x390_native_geometry")
		if menu=="map":
			var map := _find_map(world.hud)
			var clip_rect: Rect2 = world.hud._modal_scroll.get_global_rect().intersection(root.get_visible_rect())
			var vbar: VScrollBar = world.hud._modal_scroll.get_v_scroll_bar()
			if vbar.is_visible_in_tree(): clip_rect.size.x-=vbar.size.x
			var plot_rect: Rect2 = map.get_global_transform_with_canvas()*map._area()
			print("V03_MAP_VIEWPORT_EVIDENCE ",JSON.stringify({"viewport":"844x390","plot":str(plot_rect),"scroll_clip":str(clip_rect),"map_minimum":str(map.custom_minimum_size),"modal":str(world.hud._modal_panel.get_global_rect())}))
			check(clip_rect.grow(0.5).encloses(plot_rect),"landscape_844x390_map_entire_plot_is_visible_and_operable_inside_scroll_clip")
	world.touch_controls.set_enabled(true)
	world._resume()
	world.touch_controls._layout()
	world._process(0)
	await process_frame
	await process_frame
	var button := _find_button(world.touch_controls,"跑")
	check(button != null and button.is_visible_in_tree(),"actual_touch_controls_expose_sprint_button")
	var forward_button := _find_button(world.touch_controls,"↑")
	var forward_operable: bool = forward_button != null and forward_button.is_visible_in_tree() and root.get_visible_rect().encloses(forward_button.get_global_rect())
	if forward_operable:
		_GUI_click(forward_button.get_global_rect().get_center())
		forward_operable = Input.is_action_pressed("move_forward")
	var prompt_rect: Rect2 = world.hud._prompt_label.get_global_rect()
	var clear_prompt: bool = button != null and world.hud._prompt_label.is_visible_in_tree() and not button.get_global_rect().intersects(prompt_rect)
	print("V03_SPRINT_LAYOUT_EVIDENCE ",JSON.stringify({"viewport":"844x390","sprint":str(button.get_global_rect()) if button else "missing","prompt":str(prompt_rect),"forward_operable":forward_operable}))
	world.touch_controls.release_all()
	check(clear_prompt and forward_operable,"landscape_sprint_button_does_not_cover_prompt_and_forward_GUI_remains_operable")
	if button:
		var down := InputEventMouseButton.new()
		down.position = button.get_global_rect().get_center()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		root.push_input(down,true)
		check(Input.is_action_pressed("sprint"),"actual_GUI_held_sprint_button_presses_input_action")
		world.hud.show_pause()
		await process_frame
		# process_frame is emitted before Node._process; a second boundary observes its release.
		await process_frame
		check(not Input.is_action_pressed("sprint") and not world.touch_controls.held.has("sprint"),"menu_pause_releases_actual_held_touch_sprint")
		var up := down.duplicate()
		up.pressed = false
		root.push_input(up,true)
	world._resume()
	world.touch_controls.set_enabled(false)
	root.content_scale_size = Vector2i(390,219)
	root.size = Vector2i(390,219)
	world.hud.show_district_map()
	world.hud._resize_modal()
	await process_frame
	await process_frame
	check(root.get_visible_rect().encloses(world.hud._modal_panel.get_global_rect()),"tiny_390x219_map_modal_stays_inside_viewport")
	world._resume()
	root.content_scale_size = Vector2i(1152,648)
	root.size = Vector2i(1152,648)
	await process_frame

func _check_save_migration_and_retry() -> void:
	_rank_fixture(world.district_systems)
	world.player.position = Vector3(-58,0.2,57)
	world.player.velocity = Vector3.ZERO
	for id: String in ["stamina","tool_power","vehicle_service"]: world._purchase_supply(id)
	world.player.set_stamina(63)
	world.player.reset_view(0.72)
	world.street_state.hour = 20.5
	world.street_state.cycle_enabled = false
	world.street_state.quality = "performance"
	world.street_state.difficulty = "relaxed"
	world._setting_changed("sensitivity","1.4")
	world._setting_changed("muted","on")
	world._set_waypoint(Vector2(110,-50))
	world._apply_preferences()
	check(is_equal_approx(world.player.incoming_damage_multiplier,0.65),"real_preferences_apply_relaxed_damage_multiplier")
	check(is_equal_approx(world.player.mouse_sensitivity,0.0042),"real_preferences_apply_camera_sensitivity")
	check(AudioServer.is_bus_mute(0),"real_preferences_mute_actual_master_audio_bus")
	world._save(false)
	var saved: Dictionary = Save.load_state(SLOT)
	check(saved.has("district_systems") and saved.has("street_state") and saved["player"].has("stamina"),"slot93_contains_progression_environment_preferences_and_stamina")
	var expected_systems: Dictionary = world.district_systems.to_dict()
	var expected_street: Dictionary = world.street_state.to_dict()
	world.district_systems.reset()
	world.street_state.reset()
	world.player.set_stamina(10)
	world._load(SLOT)
	check(_same_saved_value(world.district_systems.to_dict(),expected_systems) and _same_saved_value(world.street_state.to_dict(),expected_street),"actual_slot93_load_restores_new_gameplay_state")
	check(world.player.maximum_stamina == 120 and world.player.stamina ==63 and is_equal_approx(world.player.tool_damage_multiplier,1.2) and is_equal_approx(world.bicycle.acceleration_multiplier,1.15),"actual_slot93_load_reapplies_upgrades_and_saved_stamina")
	check(is_equal_approx(world.player.get_view_yaw(),0.72) and is_equal_approx(float(saved["player"].get("camera_yaw",NAN)),0.72),"actual_slot93_JSON_roundtrip_retains_nondefault_camera_yaw")
	var old_preferences := saved.duplicate(true)
	old_preferences["street_state"]["sensitivity"] = .7
	old_preferences["street_state"]["muted"] = false
	var device_profile_before: String = world.device_profiles.get_profile()
	var hardware_before: String = world.device_profiles.get_hardware_profile()
	check(world._restore(old_preferences) and is_equal_approx(world.street_state.sensitivity,.7) and not world.street_state.muted,"old_saved_street_preferences_remain_parseable_campaign_data")
	check(world.device_profiles.get_profile()==device_profile_before and world.device_profiles.get_hardware_profile()==hardware_before and is_equal_approx(world.player.mouse_sensitivity,.0042) and AudioServer.is_bus_mute(0),"independent_device_preferences_override_old_save_camera_audio_without_hardware_change")
	check(world._restore(saved),"current_campaign_snapshot_restores_after_device_precedence_probe")
	world.hud.show_pause()
	world._process(0)
	var atomic_before: Dictionary = world._snapshot(false)
	for field: String in ["district_systems","street_state"]:
		var bad := saved.duplicate(true)
		bad["player"]["position"] = [70,1,30]
		bad[field] = {"corrupt":true}
		check(not world._restore(bad) and _same_saved_value(world._snapshot(false),atomic_before),"corrupt_new_save_dictionary_rejects_atomically_"+field)
	for value: Variant in ["bad",-1,121,INF]:
		var bad := saved.duplicate(true)
		bad["player"]["position"] = [70,1,30]
		bad["player"]["stamina"] = value
		check(not world._restore(bad) and _same_saved_value(world._snapshot(false),atomic_before),"corrupt_saved_stamina_rejects_atomically_"+str(value))
	var bad_yaw := saved.duplicate(true)
	bad_yaw["player"]["position"] = [70,1,30]
	bad_yaw["player"]["camera_yaw"] = NAN
	check(not world._restore(bad_yaw) and _same_saved_value(world._snapshot(false),atomic_before),"nonfinite_saved_camera_yaw_rejects_atomically_without_moving_player")
	var old02 := saved.duplicate(true)
	old02.erase("district_systems")
	old02.erase("street_state")
	old02["player"].erase("stamina")
	old02["player"].erase("camera_yaw")
	check(world._restore(old02) and world.district_systems.credits==120 and world.district_systems.rank==1 and world.player.maximum_stamina==100 and world.player.stamina==100,"old_02_save_migrates_to_default_growth_and_stamina")
	check(_same_saved_value(world.optional.to_dict(),old02["optional"]),"old_02_migration_preserves_existing_optional_ledger")
	var old01 := old02.duplicate(true)
	old01.erase("optional")
	old01.erase("city_life")
	for key: String in old01["objects"].keys():
		if key.begins_with("SIDE_") or key.begins_with("ACT_") or key in ["optional_board","supply_board"]: old01["objects"].erase(key)
	check(world._restore(old01) and world.optional.wallet ==0 and world.district_systems.rank==1 and world.street_state.hour==15.5,"old_01_save_migrates_without_optional_or_new_system_fields")
	check(world._restore(saved),"new_save_restores_after_old_save_migrations")
	world._retry()
	check(_same_saved_value(world.district_systems.to_dict(),expected_systems),"main_retry_preserves_grant_once_progression_and_purchases")
	check(_same_saved_value(world.street_state.to_dict(),expected_street),"main_retry_preserves_settings_daylight_and_waypoint")
	check(world.player.maximum_stamina==120 and world.player.stamina==120 and is_equal_approx(world.player.tool_damage_multiplier,1.2),"main_retry_heals_without_losing_upgraded_player_stats")

func _player_blockers_at(point: Vector3) -> Array[Dictionary]:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = world.player._collision.shape
	query.transform = Transform3D(Basis.IDENTITY,point+world.player._collision.position)
	query.collision_mask = 1
	return world.get_world_3d().direct_space_state.intersect_shape(query,8)

func _check_shop_save_relocation() -> void:
	world.hud.show_pause()
	world._process(0)
	var legacy: Dictionary = world._snapshot(false)
	legacy["player"]["position"] = [-54,0.1,65]
	legacy["player"].erase("camera_yaw")
	var expected_inventory: Dictionary = legacy["player"]["inventory"].duplicate(true)
	var expected_missions: Dictionary = legacy["missions"].duplicate(true)
	var expected_growth: Dictionary = legacy["district_systems"].duplicate(true)
	var accepted: bool = world._restore(legacy)
	await physics_frame
	var blockers: Array[Dictionary] = _player_blockers_at(world.player.position)
	var obstruction_names: Array[String] = []
	for result: Dictionary in blockers: obstruction_names.append(str(result["collider"].name))
	print("V03_SHOP_RELOCATION_EVIDENCE ",JSON.stringify({"accepted":accepted,"position":str(world.player.position),"blockers":obstruction_names,"inside_shop":AABB(Vector3(-62,0,61),Vector3(16,8,8)).grow(0.5).has_point(world.player.position+Vector3.UP)}))
	check(accepted and world.player.position.distance_to(Vector3(-54,0.1,65))>1 and blockers.is_empty() and not AABB(Vector3(-62,0,61),Vector3(16,8,8)).grow(0.5).has_point(world.player.position+Vector3.UP) and _same_saved_value(world.player.inventory,expected_inventory) and _same_saved_value(world.missions.to_dict(),expected_missions) and _same_saved_value(world.district_systems.to_dict(),expected_growth),"legacy_player_inside_new_shop_relocates_to_real_clear_capsule_without_losing_inventory_or_progress")

func _check_new_game_reset() -> void:
	world._new_game()
	check(world.district_systems.credits==120 and world.district_systems.xp==0 and world.district_systems.rank==1 and world.district_systems.walking_distance==0,"new_game_resets_growth_ledger_and_challenges")
	check(world.player.maximum_stamina==100 and world.player.stamina==100 and is_equal_approx(world.player.tool_damage_multiplier,1) and is_equal_approx(world.bicycle.acceleration_multiplier,1),"new_game_resets_actual_upgrade_stats")
	check(world.optional.wallet==0 and world.missions.mission_index==0,"new_game_still_resets_original_campaign_and_optional_progress")
