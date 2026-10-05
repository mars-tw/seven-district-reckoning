extends SceneTree

const ProfilesScript = preload("res://scripts/systems/device_profiles.gd")
const TouchScript = preload("res://scripts/ui/touch_controls.gd")
const PlayerScript = preload("res://scripts/player/player_controller.gd")
var checks := 0
var failures := 0
var touches: TouchControls
var world: Node3D
var player: SevenPlayer
var interactions := 0
var jobs := 0

func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: "+label)

func _touch(index: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event,true)

func _drag(index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = relative
	root.push_input(event,true)

func _button(caption: String) -> Button:
	for button: Node in touches.find_children("*","Button",true,false):
		if (button as Button).text == caption and (button as Button).is_visible_in_tree(): return button
	return null

func run() -> void:
	for action: String in ["move_left","move_right","move_forward","move_back","sprint","jump","attack","interact","mount","cycle_weapon","brake","reset_vehicle"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	await _check_classification_and_preferences()
	await _check_runtime_budgets()
	world = Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100,.4,100)
	shape.shape = box
	floor_body.position.y = -.2
	floor_body.add_child(shape)
	world.add_child(floor_body)
	player = PlayerScript.new()
	player.position.y = .05
	player.setup_visual(load("res://assets/models/hero.glb") as PackedScene)
	player.interaction_requested.connect(func() -> void: interactions += 1)
	world.add_child(player)
	touches = TouchScript.new()
	touches.jobs_requested.connect(func() -> void: jobs += 1)
	root.add_child(touches)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await physics_frame
	await physics_frame
	await _check_layouts()
	await _check_multitouch()
	print("DEVICE_PROFILE_CHECKS=",checks," FAILURES=",failures)
	quit(0 if failures == 0 else 1)

func _check_classification_and_preferences() -> void:
	for pair: Array in [[Vector2(360,800),"phone"],[Vector2(390,844),"phone"],[Vector2(844,390),"phone"],[Vector2(768,1024),"tablet"],[Vector2(1024,768),"tablet"],[Vector2(1280,800),"tablet"]]:
		check(ProfilesScript.classify(pair[0],true)==pair[1],"auto_coarse_"+str(pair[0]))
	for size: Vector2 in [Vector2(360,800),Vector2(1366,768),Vector2(1920,1080)]:
		check(ProfilesScript.classify(size,false)=="desktop","mouse_is_desktop_"+str(size))
	check(ProfilesScript.classify(Vector2(1366,768),true,"windows")=="desktop","hybrid_native_windows_keeps_desktop")
	check(ProfilesScript.classify(Vector2(1920,1080),false,"phone")=="phone","manual_hint_has_precedence")
	var path := "user://tests-device-profiles-"+str(Time.get_ticks_usec())+".cfg"
	var manager := ProfilesScript.new()
	manager.settings_path = path
	manager.initialize(Vector2(1366,768),false,"windows",false)
	check(manager.get_profile()=="desktop" and manager.get_requested_profile()=="auto","native_desktop_default")
	check(manager.set_preference("resolution_scale",.8),"desktop_preference_persists")
	check(not manager.set_preference("resolution_scale",NAN) and not manager.set_preference("muted","yes") and not manager.set_preference("injected",true),"preference_types_and_keys_validated")
	var phone := ProfilesScript.new()
	phone.settings_path = path
	phone.initialize(Vector2(390,844),true,"phone")
	check(phone.get_profile()=="phone" and is_equal_approx(phone.get_settings()["resolution_scale"],.7),"phone_does_not_inherit_desktop_render_preference")
	phone.set_preference("muted",true)
	phone.set_preference("sensitivity",1.4)
	var desktop := ProfilesScript.new()
	desktop.settings_path = path
	desktop.initialize(Vector2(1366,768),false,"windows")
	check(is_equal_approx(desktop.get_settings()["resolution_scale"],.8) and not desktop.get_settings()["muted"],"desktop_reloads_only_own_preferences")
	check(phone.set_profile("desktop") and phone.get_profile()=="desktop","manual_profile_switch_supported")
	check(phone.set_profile("auto") and phone.get_profile()=="phone" and phone.get_settings()["muted"],"auto_restores_hardware_and_its_preferences")
	check(not phone.set_profile("ultra_injected"),"profile_name_whitelist")
	var external := phone.get_settings()
	external["prop_distance"] = 99999
	check(phone.get_settings()["prop_distance"]==70,"settings_are_copy_not_mutable_authority")
	for node: Node in [manager,phone,desktop]: node.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _check_runtime_budgets() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var camera := Camera3D.new()
	fixture.add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	fixture.add_child(sun)
	var prop := MeshInstance3D.new()
	prop.mesh = BoxMesh.new()
	fixture.add_child(prop)
	var ground := MeshInstance3D.new()
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(800,.1,800)
	ground.mesh = ground_mesh
	fixture.add_child(ground)
	var landmark := MeshInstance3D.new()
	landmark.mesh = BoxMesh.new()
	landmark.set_meta("device_keep_visible",true)
	fixture.add_child(landmark)
	var actor := Node3D.new()
	actor.add_to_group("player")
	var actor_mesh := MeshInstance3D.new()
	actor_mesh.mesh = BoxMesh.new()
	actor.add_child(actor_mesh)
	fixture.add_child(actor)
	var audio := AudioStreamPlayer.new()
	fixture.add_child(audio)
	var spatial_audio := AudioStreamPlayer3D.new()
	fixture.add_child(spatial_audio)
	for index: int in 30:
		var ambient := Node3D.new()
		ambient.position = Vector3(index*.8,0,0)
		ambient.add_to_group("ambient_citizens")
		fixture.add_child(ambient)
	for index: int in 10:
		var traffic := Node3D.new()
		traffic.position = Vector3(index,0,2)
		traffic.add_to_group("ambient_traffic")
		fixture.add_child(traffic)
	var manager := ProfilesScript.new()
	fixture.add_child(manager)
	manager.initialize(Vector2(1366,768),false,"desktop",false)
	for name: String in ["phone","tablet","desktop"]:
		manager.set_profile(name,false)
		manager.apply_scene(fixture,actor)
		var settings := manager.get_settings()
		check(is_equal_approx(root.scaling_3d_scale,settings["resolution_scale"]) and root.scaling_3d_mode==Viewport.SCALING_3D_MODE_BILINEAR,"actual_viewport_bilinear_scale_"+name)
		check(is_equal_approx(camera.far,settings["camera_distance"]) and is_equal_approx(root.mesh_lod_threshold,settings["lod_threshold"]),"actual_camera_and_mesh_lod_"+name)
		check(sun.shadow_enabled==settings["shadows"],"real_directional_shadow_switch_"+name)
		check(is_equal_approx(prop.visibility_range_end,settings["prop_distance"]),"real_prop_draw_range_"+name)
		check(ground.visibility_range_end==0 and landmark.visibility_range_end==0 and actor_mesh.visibility_range_end==0,"terrain_landmark_and_player_not_generic_hidden_"+name)
		check(audio.max_polyphony==settings["audio_voices"] and spatial_audio.max_polyphony==settings["audio_voices"] and spatial_audio.max_distance==settings["audio_distance"],"actual_audio_voice_and_range_budget_"+name)
		var count := 0
		for item: Node in get_nodes_in_group("ambient_citizens"):
			if item.get_meta("device_budget_active",false) and item.visible: count += 1
		check(count==settings["max_citizens"],"actual_visible_ambient_limit_"+name)
		count = 0
		for item: Node in get_nodes_in_group("ambient_traffic"):
			if item.get_meta("device_budget_active",false) and item.visible: count += 1
		check(count==settings["max_traffic"],"actual_visible_traffic_limit_"+name)
	manager.set_profile("phone",false)
	actor.position = Vector3(1000,0,1000)
	manager.update_ambient(actor)
	check(not fixture.get_children().filter(func(item: Node) -> bool: return item.is_in_group("ambient_citizens") and bool(item.get_meta("device_budget_active",true))).size(),"distant_ambient_meta_inactive_without_deleting_gameplay")
	fixture.queue_free()
	await process_frame

func _check_layouts() -> void:
	for pair: Array in [[Vector2i(360,800),"phone"],[Vector2i(390,844),"phone"],[Vector2i(844,390),"phone"],[Vector2i(768,1024),"tablet"],[Vector2i(1024,768),"tablet"],[Vector2i(1280,800),"tablet"],[Vector2i(1366,768),"desktop"],[Vector2i(1920,1080),"desktop"]]:
		root.content_scale_size = pair[0]
		root.size = pair[0]
		touches.set_profile(pair[1])
		touches.set_enabled(true)
		touches.set_safe_insets(Vector4(12,20,12,20))
		touches._layout()
		await process_frame
		await process_frame
		var safe := Rect2(Vector2(12,20),Vector2(pair[0])-Vector2(24,40))
		var all_fit := true
		var touch_count := 0
		for button: Node in touches.find_children("*","Button",true,false):
			if (button as Button).is_visible_in_tree():
				touch_count += 1
				all_fit = all_fit and safe.grow(.5).encloses((button as Button).get_global_rect()) and (button as Button).size.x>=44 and (button as Button).size.y>=44
		check(all_fit and touch_count>=12,"real_control_rects_safe_and_44px_targets_"+str(pair[0]))
		check(touches.joystick.visible==(pair[1]!="desktop"),"distinct_joystick_vs_keyboard_fallback_"+str(pair[0]))
		if pair[1]!="desktop": check(safe.encloses(touches.joystick.get_global_rect()) and not touches.joystick.get_global_rect().intersects(touches.panels[1].get_global_rect()),"joystick_does_not_overlap_action_grid_"+str(pair[0]))
		print("DEVICE_LAYOUT_EVIDENCE ",JSON.stringify({"size":str(pair[0]),"profile":pair[1],"buttons":touch_count,"safe_fit":all_fit,"joystick":str(touches.joystick.get_global_rect())}))

func _check_multitouch() -> void:
	root.content_scale_size = Vector2i(844,390)
	root.size = Vector2i(844,390)
	touches.set_safe_insets(Vector4.ZERO)
	touches.set_profile("phone")
	touches.set_enabled(true)
	await process_frame
	await process_frame
	check(not Input.emulate_mouse_from_touch,"gameplay_touch_uses_indexed_events_not_desktop_attack_emulation")
	var origin := touches.joystick_origin
	_touch(3,origin,true)
	_drag(3,origin+Vector2(0,-50),Vector2(0,-50))
	check(touches.joystick_index==3 and Input.get_action_strength("move_forward")>.65,"indexed_floating_joystick_drives_analog_input")
	var position_before := player.position
	await create_timer(.2).timeout
	check(player.position.distance_to(position_before)>.3,"real_player_physics_moves_from_joystick")
	var yaw_before := player.get_view_yaw()
	_drag(3,Vector2(700,250),Vector2(60,0))
	check(is_equal_approx(player.get_view_yaw(),yaw_before),"joystick_owned_drag_cannot_rotate_camera_even_crossing_right_half")
	_drag(8,Vector2(680,220),Vector2(40,0))
	check(not is_equal_approx(player.get_view_yaw(),yaw_before) and touches.joystick_index==3,"independent_second_finger_rotates_camera_without_losing_movement")
	var jump := _button("跳／煞")
	_touch(11,jump.get_global_rect().get_center(),true)
	check(Input.is_action_pressed("jump") and Input.is_action_pressed("brake") and touches.joystick_index==3,"third_finger_can_brake_while_joystick_and_camera_are_active")
	_touch(11,jump.get_global_rect().get_center(),false)
	await create_timer(.16).timeout
	check(not Input.is_action_pressed("jump") and not Input.is_action_pressed("brake") and not touches.joystick_vector.is_zero_approx(),"brake_release_does_not_cancel_other_finger")
	_touch(3,Vector2(700,250),false,true)
	check(touches.joystick_index==-1 and not Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_forward"),"OS_touch_cancel_releases_owned_joystick")
	var interact := _button("互動")
	var before := interactions
	_touch(2,interact.get_global_rect().get_center(),true)
	_touch(2,interact.get_global_rect().get_center(),false)
	await physics_frame
	await physics_frame
	check(interactions==before+1,"indexed_quick_tap_reaches_real_player_interact_once")
	await create_timer(.16).timeout
	check(not Input.is_action_pressed("interact"),"quick_tap_minimum_window_expires")
	var sprint := _button("連跑")
	_touch(4,sprint.get_global_rect().get_center(),true)
	_touch(4,sprint.get_global_rect().get_center(),false)
	check(touches.sprint_toggle and Input.is_action_pressed("sprint"),"one_tap_enables_phone_sprint_toggle")
	_touch(4,sprint.get_global_rect().get_center(),true)
	_touch(4,sprint.get_global_rect().get_center(),false)
	check(not touches.sprint_toggle and not Input.is_action_pressed("sprint"),"second_tap_disables_sprint_toggle")
	var hold_settings := touches.settings.duplicate(true)
	hold_settings["profile"] = "phone"
	hold_settings["sprint_toggle"] = false
	touches.set_profile(hold_settings)
	await process_frame
	await process_frame
	var held_sprint := _button("跑")
	_touch(4,held_sprint.get_global_rect().get_center(),true)
	check(Input.is_action_pressed("sprint") and not touches.sprint_toggle,"phone_can_choose_hold_sprint_with_independent_finger")
	_touch(4,held_sprint.get_global_rect().get_center(),false)
	await create_timer(.16).timeout
	check(not Input.is_action_pressed("sprint"),"hold_sprint_releases_without_toggle")
	var jobs_button := _button("配送")
	_touch(5,jobs_button.get_global_rect().get_center(),true)
	_touch(5,jobs_button.get_global_rect().get_center(),false)
	check(jobs==1,"actual_indexed_jobs_button_emits_fixed_signal_once")
	_touch(3,origin,true)
	_drag(3,origin+Vector2(0,-50),Vector2(0,-50))
	paused = true
	await process_frame
	await process_frame
	check(touches.held.is_empty() and touches.joystick_index==-1 and not Input.is_action_pressed("move_forward"),"pause_releases_all_touch_owners")
	check(Input.emulate_mouse_from_touch,"pause_menu_restores_Godot_mouse_emulation_for_scroll_and_buttons")
	paused = false
	await process_frame
	_touch(3,origin,true)
	_drag(3,origin+Vector2(0,-50),Vector2(0,-50))
	root.size = Vector2i(390,844)
	root.content_scale_size = Vector2i(390,844)
	touches._layout()
	check(touches.held.is_empty() and touches.joystick_index==-1,"orientation_change_releases_active_fingers")
	touches.set_enabled(false)
	check(not Input.is_action_pressed("brake") and not Input.is_action_pressed("sprint"),"disable_leaves_no_paired_or_toggle_action")
