extends SceneTree
const Revisits = preload("res://scripts/content/chapter_revisits.gd")
const Main = preload("res://scripts/main.gd")
class TestRoot extends "res://scripts/main.gd":
	func _save(_notice: bool = true) -> void: pass

var checks := 0
var failures := 0
var game: Node3D
var approaches: Dictionary = {}
var capsule := CapsuleShape3D.new()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("R2_FAIL "+label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	await record_contract()
	Engine.set_meta("seven_district_no_records",true)
	game = TestRoot.new()
	root.add_child(game)
	var frames := 0
	while not game.expansion_complete and frames < 15000:
		await process_frame
		frames += 1
	check(game.expansion_complete,"real_world_finishes_startup")
	if not game.expansion_complete:
		quit(1)
		return
	game.is_test_mode = true
	game._new_game()
	for guard: Node in game.guards.values(): guard.set_physics_process(false)
	game.device_profiles.set_profile("phone",false)
	check_walk_paths()
	await world_contract()
	await layout_contract()
	await touch_contract()
	game.touch_controls.release_all()
	paused = false
	game.queue_free()
	await process_frame
	await process_frame
	Engine.remove_meta("seven_district_no_records")
	print("R2_MOBILE_CHECKS=",checks," FAILURES=",failures)
	quit(0 if failures == 0 else 1)

func record_contract() -> void:
	var r := Revisits.new()
	r.persist = false
	root.add_child(r)
	check(r.unlocked(0) and not r.unlocked(1) and not r.start(2),"sequential_unlock_enforced")
	check(not r.start(-1) and not r.start(3),"route_bounds_enforced")
	for index: int in 3:
		check(r.start(index) and not r.start(index),"no_double_start_"+str(index))
		check(r.interact_at(Vector3(300,1,300)).is_empty(),"remote_visit_rejected")
		check(r.interact_at(r.target_position(),false).is_empty(),"mounted_visit_rejected")
		check(r.interact_at(Vector3(NAN,0,0)).is_empty(),"invalid_position_rejected")
		r.advance(30.0+index)
		check(r.interact_at(r.target_position()) == "clue" and r.step == 1,"first_stop_gives_clue")
		check(not r.answer(0),"answer_requires_local_question")
		check(r.interact_at(r.target_position()) == "question","second_stop_opens_question")
		check(not r.answer(1-int(r.ROUTES[index]["answer"])) and r.step == 1,"wrong_answer_retry_no_progress")
		check(r.answer(int(r.ROUTES[index]["answer"])) and r.step == 2,"correct_answer_unlocks_return")
		check(not r.answer(int(r.ROUTES[index]["answer"])),"duplicate_answer_rejected")
		check(r.interact_at(r.target_position()) == "complete" and r.active == -1,"third_stop_records_notebook")
	check(r.records.size() == 3,"all_three_pages_collectible")
	check(r.recommended(100) != r.recommended(101),"daily_recommendation_rotates_unlocked_routes")
	var best: float = r.records["messages"]["best_seconds"]
	r.start(0)
	r.advance(200)
	r.interact_at(r.target_position())
	r.interact_at(r.target_position())
	r.answer(0)
	r.interact_at(r.target_position())
	check(r.records["messages"]["runs"] == 2 and r.records["messages"]["best_seconds"] == best,"replay_count_and_best_never_regress")
	r.records_path = "user://r2-notebook-test.cfg"
	check(r.save_records() == OK,"notebook_can_persist")
	var reload := Revisits.new()
	reload.persist = false
	reload.records_path = r.records_path
	reload.load_records()
	check(reload.records == r.records,"notebook_roundtrip_exact")
	var cfg := ConfigFile.new()
	cfg.set_value("notebook","records",{"messages":{"runs":1,"best_seconds":NAN},"door":{"runs":1,"best_seconds":1}})
	cfg.save(r.records_path)
	reload.load_records()
	check(reload.records.is_empty(),"malformed_record_cannot_unlock_later_pages")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(r.records_path))
	r.queue_free()
	reload.free()
	await process_frame

func find_button(text: String) -> Button:
	for button: Node in game.hud._root.find_children("*","Button",true,false):
		if button.is_visible_in_tree() and button.text == text: return button
	return null

func click(text: String) -> void:
	var button := find_button(text)
	check(button != null,"real_UI_has_"+text)
	if button: button.pressed.emit()

func stand_at(point: Vector3) -> void:
	game._resume()
	game.player.position = point+Vector3(0,.2,0)
	game.player.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	game._process(.016)

func world_contract() -> void:
	var initial_mission: Dictionary = game.missions.to_dict()
	var initial_money: int = game.district_systems.credits
	for index: int in 3:
		game.hud.show_pause()
		click("章節回訪")
		game.hud.show_revisits(index)
		click("接下回訪")
		check(game.revisits.active == index and not paused,"menu_starts_real_assignment_"+str(index))
		game._process(1)
		check(game.objective_beacon.target_position.distance_to(game.revisits.target_position()*Vector3(1,0,1)) < .1,"guidance_targets_revisit")
		for stop: int in 3:
			var point: Vector3 = game.revisits.target_position()
			await stand_at(approaches.get("%d:%d" % [index,stop],point+Vector3(0,0,1.8)))
			# A real physics ray finds ground at every actual interaction approach.
			var query := PhysicsRayQueryParameters3D.create(game.player.position+Vector3.UP,game.player.position-Vector3.UP*3,1)
			check(not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"station_has_real_ground_%d_%d" % [index,stop])
			check(game.revisits.is_near(game.player.position),"station_is_physically_reachable_%d_%d" % [index,stop])
			game._interact()
			if stop == 1:
				check(paused and game.hud.get_menu_mode() == "revisit_question","real_interact_opens_question")
				var route: Dictionary = game.revisits.ROUTES[index]
				click(route["choices"][1-int(route["answer"])])
				check(game.revisits.step == 1,"real_wrong_choice_keeps_retry")
				click(route["choices"][int(route["answer"])])
				check(not paused and game.revisits.step == 2,"real_correct_choice_resumes_return")
		check(game.revisits.records.has(game.revisits.ROUTES[index]["id"]),"real_route_awards_page_"+str(index))
		game.hud.show_revisits(index)
		click("閱讀後記")
		check(game.hud.get_menu_mode() == "revisit_note","collected_page_readable")
	check(game.missions.to_dict() == initial_mission,"revisits_preserve_main_mission_contract")
	check(game.district_systems.credits == initial_money,"notebook_cannot_duplicate_money")
	game._resume()
	game._start_revisit(0)
	game.hud.show_pause()
	var old: float = game.revisits.elapsed
	game._process(10)
	check(game.revisits.elapsed == old,"pause_excludes_revisit_timer")
	game.hud.show_revisits(0)
	click("放下回訪，恢復主線導引")
	check(game.revisits.active == -1 and not paused,"cancel_restores_main_guidance")
	await stand_at(game.targets["mei"]+Vector3(0,0,1.8))
	check("點互動" in game.hud._prompt_label.text and not "E｜" in game.hud._prompt_label.text and not "按 E" in game.hud._objective_label.text,"mobile_nearby_prompt_and_mission_card_use_touch_instructions")
	var contextual := false
	for button: Button in game.touch_controls._action_buttons:
		if game.touch_controls._action_buttons[button] == "interact": contextual = button.text == "交談"
	check(contextual,"nearby_character_changes_real_green_button_to_talk")
	await stand_at(Vector3(-56,.1,52))

func walk_clear(point: Vector3) -> bool:
	var shape := PhysicsShapeQueryParameters3D.new()
	shape.shape = capsule
	shape.transform = Transform3D(Basis.IDENTITY,Vector3(point.x,1.12,point.z))
	shape.collision_mask = 1
	if not game.get_world_3d().direct_space_state.intersect_shape(shape,1).is_empty(): return false
	var floor_ray := PhysicsRayQueryParameters3D.create(Vector3(point.x,.4,point.z),Vector3(point.x,-1,point.z),1)
	return not game.get_world_3d().direct_space_state.intersect_ray(floor_ray).is_empty()

func segment_clear(a: Vector3,b: Vector3) -> bool:
	var samples := maxi(1,ceili(a.distance_to(b)))
	for index: int in range(1,samples+1):
		if not walk_clear(a.lerp(b,float(index)/samples)): return false
	return true

func check_walk_paths() -> void:
	capsule.radius = .35
	capsule.height = 1.7
	var queue: Array[Vector2i] = [Vector2i(-56,52)]
	var visited: Dictionary = {queue[0]:true}
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		for direction: Vector2i in [Vector2i(4,0),Vector2i(-4,0),Vector2i(0,4),Vector2i(0,-4)]:
			var next := current+direction
			if visited.has(next) or abs(next.x)>112 or abs(next.y)>112: continue
			visited[next] = true
			if segment_clear(Vector3(current.x,0,current.y),Vector3(next.x,0,next.y)): queue.append(next)
	check(queue.size()>500,"capsule_walk_grid_connected_to_actual_spawn")
	for index: int in 3:
		for stop: int in 3:
			var point: Vector3 = Revisits.ROUTES[index]["stops"][stop]
			var key := "%d:%d" % [index,stop]
			for node: Vector2i in queue:
				var grid := Vector3(node.x,.1,node.y)
				if grid.distance_to(point)>8: continue
				for dx: int in range(-3,4):
					for dz: int in range(-3,4):
						var candidate := point+Vector3(dx,0,dz)
						if candidate.distance_to(point)>2.7 or not walk_clear(candidate) or not segment_clear(grid,candidate): continue
						approaches[key] = candidate
				if approaches.has(key): break
			check(approaches.has(key),"real_capsule_path_from_spawn_to_revisit_"+key)

func layout_contract() -> void:
	for screen: Vector2i in [Vector2i(390,844),Vector2i(844,390),Vector2i(1366,600),Vector2i(1280,640)]:
		root.content_scale_size = screen
		root.size = screen
		game.device_profiles.set_profile("phone" if screen.x < 900 else "desktop",false)
		for page: int in 3:
			game.hud.show_pause(page)
			await process_frame
			await process_frame
			check_buttons("pause_"+str(screen)+"_"+str(page))
			check(game.hud._modal_scroll.get_v_scroll_bar().max_value <= game.hud._modal_scroll.size.y+1,"pause_page_needs_no_scroll_"+str(screen)+str(page))
		game.hud.show_revisits(0)
		await process_frame
		await process_frame
		check_buttons("revisit_"+str(screen))
		for open_menu: Callable in [game.hud.show_phone,game.hud.show_optional_phone,game.hud.show_settings,game.hud.show_district_map]:
			open_menu.call()
			await process_frame
			await process_frame
			var footer: Control = game.hud._return_footer
			check(root.get_visible_rect().encloses(footer.get_global_rect()),"fixed_return_visible_"+game.hud.get_menu_mode()+str(screen))
			check(footer.get_child(0).size.y >= 44,"fixed_return_44px")
		game._resume()

func check_buttons(label: String) -> void:
	var buttons: Array[Button] = []
	for item: Node in game.hud._root.find_children("*","Button",true,false):
		if item.is_visible_in_tree(): buttons.append(item)
	for button: Button in buttons:
		check(root.get_visible_rect().grow(.5).encloses(button.get_global_rect()) and button.size.x >= 44 and button.size.y >= 44,label+"_visible_44_"+button.text)
		for other: Button in buttons:
			if other != button: check(not button.get_global_rect().intersects(other.get_global_rect()),label+"_no_overlap_"+button.text+"_"+other.text)

func touch_contract() -> void:
	root.content_scale_size = Vector2i(390,844)
	root.size = Vector2i(390,844)
	game.device_profiles.set_profile("phone",false)
	game.touch_controls.set_enabled(true)
	await process_frame
	await process_frame
	var touch = game.touch_controls
	var press := InputEventScreenTouch.new()
	press.index = 77
	press.pressed = true
	press.position = touch.joystick_origin
	root.push_input(press,true)
	var drag := InputEventScreenDrag.new()
	drag.index = 77
	drag.position = press.position+Vector2(52,0)
	drag.relative = Vector2(52,0)
	root.push_input(drag,true)
	var before: Vector3 = game.player.position
	for index: int in 20: await physics_frame
	check(game.player.position.distance_to(before) > .2,"actual_touch_moves_real_animated_player")
	var interact: Button
	for button: Button in touch._action_buttons:
		if touch._action_buttons[button] == "interact": interact = button
	press.index = 78
	press.position = interact.get_global_rect().get_center()
	root.push_input(press,true)
	check(Input.is_action_pressed("move_right") and Input.is_action_pressed("interact"),"two_fingers_move_and_interact_together")
	check(interact.get_theme_stylebox("normal") == interact.get_theme_stylebox("pressed"),"touch_press_has_visual_feedback")
	var yaw: float = game.player.get_view_yaw()
	drag.index = 78
	drag.position = Vector2(380,300)
	drag.relative = Vector2(0,-120)
	root.push_input(drag,true)
	drag.relative = Vector2(50,0)
	root.push_input(drag,true)
	check(is_equal_approx(yaw,game.player.get_view_yaw()),"canceled_action_finger_never_becomes_camera_drag")
	check(interact.get_theme_stylebox("normal") != interact.get_theme_stylebox("pressed"),"cancel_removes_pressed_visual")
	touch.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not Input.is_action_pressed("move_right") and not Input.is_action_pressed("interact"),"focus_loss_releases_all_input")
	touch._press_action("move_forward","background_probe")
	touch.notification(NOTIFICATION_APPLICATION_PAUSED)
	check(not Input.is_action_pressed("move_forward"),"application_background_releases_input_without_native_patch")
	press.pressed = false
	root.push_input(press,true)
	press.index = 77
	root.push_input(press,true)
