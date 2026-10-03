extends SceneTree
## Actual RootScene integration fixtures. Save interception isolates this test to slot 94.
## Fixture placement checks interactions/physics, not human travel or browser/mobile rendering.

const ActualScene = preload("res://scenes/main.tscn")
const Save = preload("res://scripts/save/save_manager.gd")
const SLOT := 94

class ReviewRoot extends "res://scripts/main.gd":
	func _save(_show_notice: bool = true) -> void:
		if play_started:
			SaveScript.save_state(_snapshot(), 94)

var world: Node3D
var failures: Array[String] = []
var passed: Array[String] = []
var navigation: Dictionary = {}
var approaches: Dictionary = {}
var shape: CapsuleShape3D

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	if condition:
		passed.append(label)
		print("V02_INTEGRATION_PASS ", label)
	else:
		failures.append(label)
		push_error("V02_INTEGRATION_FAIL " + label)

func _same_saved_value(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not _same_saved_value(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index: int in a.size():
			if not _same_saved_value(a[index], b[index]): return false
		return true
	return a == b

func _run() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists("user://save94.json" + suffix):
			push_error("Review slot 94 already exists; test preserves it and exits.")
			quit(2)
			return
	world = ActualScene.instantiate()
	world.set_script(ReviewRoot)
	root.add_child(world)
	current_scene = world
	world.is_test_mode = true
	world._new_game()
	world._process(0)
	await physics_frame
	await physics_frame
	check(world.optional.tasks.size() == 10 and world.city_life.get_counts()["districts"] == 6, "actual_root_has_ten_tasks_and_six_districts")
	shape = CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = 1.76
	_build_navigation()
	_check_target_approaches()
	check(navigation.size() > 3000, "actual_static_physics_navigation_connected_to_player_spawn")
	for task: Dictionary in world.optional.tasks:
		if task["type"] == "side":
			await _play_task(String(task["id"]))
	check(world.optional.wallet == 850, "actual_world_six_sides_reward_once_850")
	var before_retry: Dictionary = world.optional.to_dict()
	world._retry()
	world._process(0)
	check(world.optional.to_dict() == before_retry, "main_retry_preserves_completed_side_ledger")
	world._save(false)
	var saved: Dictionary = Save.load_state(SLOT)
	world.optional.reset()
	world._load(SLOT)
	world._process(0)
	check(_same_saved_value(world.optional.to_dict(), before_retry), "slot94_load_preserves_optional_ledger_with_actual_root_restore")
	var old_alpha: Dictionary = saved.duplicate(true)
	old_alpha.erase("optional")
	old_alpha.erase("city_life")
	for key: String in old_alpha["objects"].keys():
		if key.begins_with("SIDE_") or key.begins_with("ACT_") or key == "optional_board":
			old_alpha["objects"].erase(key)
	check(world._restore(old_alpha) and world.optional.status == "idle" and world.optional.wallet == 0, "old_alpha_without_optional_fields_migrates_to_empty_optional_ledger")
	check(world._restore(saved), "actual_root_restores_current_save_after_old_alpha_migration")
	world._process(0)
	await _check_pause_and_timer()
	await _play_task("ACT-001")
	await _play_task("ACT-002")
	await _check_album_retention()
	await _play_task("ACT-005")
	await _play_task("ACT-006")
	check(world.optional.wallet == 1100, "actual_world_all_ten_tasks_reward_once_1100")
	await _check_car_parking_boundary()
	await _check_external_brake_ownership()
	await _check_touch_tap()
	await _check_touch_resize_release()
	await _check_viewport_layout(Vector2i(844, 390))
	await _check_viewport_layout(Vector2i(462, 260))
	await _check_viewport_layout(Vector2i(390, 219))
	print("V02_INTEGRATION_RESULT ", JSON.stringify({"passed_count": passed.size(), "failures": failures, "navigation_points": navigation.size(), "approachable_targets": approaches.size(), "browser_play_verified": false, "mobile_device_matrix_verified": false}))
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save94.json" + suffix))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _clear_at(point: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, Vector3(point.x, 1.03, point.z))
	query.collision_mask = 1
	return world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _build_navigation() -> void:
	# A 4m connected grid is checked at intermediate samples, against actual static collisions.
	var start := Vector2i(-56, 52)
	var queue: Array[Vector2i] = [start]
	navigation[start] = true
	var tested: Dictionary = {start: true}
	var cursor := 0
	while cursor < queue.size():
		var current: Vector2i = queue[cursor]
		cursor += 1
		for direction: Vector2i in [Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, 4), Vector2i(0, -4)]:
			var next := current + direction
			if tested.has(next) or abs(next.x) > 140 or abs(next.y) > 140:
				continue
			tested[next] = true
			var clear := true
			for fraction: float in [0.25, 0.5, 0.75, 1.0]:
				var p := Vector2(current).lerp(Vector2(next), fraction)
				if not _clear_at(Vector3(p.x, 0, p.y)):
					clear = false
					break
			if clear:
				navigation[next] = true
				queue.append(next)

func _check_target_approaches() -> void:
	for id: String in world.content_world.created_ids:
		var target: Node3D = world.objects[id]
		var best := INF
		for grid: Vector2i in navigation:
			var point := Vector3(grid.x, 0.15, grid.y)
			var distance: float = point.distance_to(target.position)
			if distance > 6.0:
				continue
			# Refine close connected grid cells by reachable 1m samples.
			for offset: Vector3 in [Vector3.ZERO, Vector3(1,0,0), Vector3(-1,0,0), Vector3(0,0,1), Vector3(0,0,-1), Vector3(2,0,0), Vector3(-2,0,0), Vector3(0,0,2), Vector3(0,0,-2)]:
				var candidate := point + offset
				var candidate_distance: float = candidate.distance_to(target.position)
				if candidate_distance >= 2.7 or candidate_distance >= best or not _clear_at(candidate) or not _clear_at(point.lerp(candidate, 0.5)):
					continue
				var ray := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP, target.global_position + Vector3.UP * 0.8, 1)
				var result: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
				if not result.is_empty() and result.get("collider") != target:
					continue
				best = candidate_distance
				approaches[id] = candidate
		if not approaches.has(id):
			var clear_samples := 0
			var visible_samples := 0
			for x_index: int in range(-11, 12):
				for z_index: int in range(-11, 12):
					var candidate: Vector3 = target.position + Vector3(x_index * 0.25, 0.03, z_index * 0.25)
					if candidate.distance_to(target.position) >= 2.95 or not _clear_at(candidate): continue
					clear_samples += 1
					var ray := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP, target.global_position + Vector3.UP * 0.8, 1)
					var result: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
					if result.is_empty() or result.get("collider") == target:
						visible_samples += 1
						approaches[id] = candidate
			print("TARGET_FINE_SAMPLE_EVIDENCE ", JSON.stringify({"id": id, "position": str(target.position), "clear_samples": clear_samples, "visible_samples": visible_samples}))
		check(approaches.has(id), "actual_capsule_connected_approach_and_line_of_sight_" + id)

func _release_vehicles() -> void:
	world.car.force_release()
	world.bicycle.force_release()

func _place_for(id: String, requested_vehicle: String = "") -> void:
	_release_vehicles()
	if requested_vehicle.is_empty():
		world.player.position = approaches.get(id, world.targets[id] + Vector3(2, 0.03, 0))
	else:
		var vehicle: CharacterBody3D = world.bicycle if requested_vehicle == "bicycle" else world.car
		vehicle.rotation = Vector3.ZERO
		vehicle.position = approaches.get(id, world.targets[id] + Vector3(2, 0.03, 0))
		vehicle.velocity = Vector3.ZERO
		vehicle.speed_mps = 0
		world.player.position = vehicle.position + Vector3(1, 0, 0)
		check(vehicle.enter(world.player), "actual_vehicle_enter_" + id)
		world.player._physics_process(0)
	world.player.velocity = Vector3.ZERO
	world._process(0)

func _play_task(id: String) -> void:
	world.hud.show_optional_phone("activity" if id.begins_with("ACT") else "side")
	world.hud.optional_selected.emit(id)
	world._process(0)
	check(world.optional.active_id == id and world.optional.status == "active", "actual_HUD_selection_starts_" + id)
	var loops := 0
	while world.optional.status == "active" and loops < 35:
		loops += 1
		var objective: Dictionary = world.optional.get_active_objective()
		var target: String = objective["remaining_targets"][0]
		if not approaches.has(target):
			check(false, "cannot_claim_actual_world_completion_without_reachable_" + target)
			world.optional.cancel_task()
			break
		var old_progress: Dictionary = world.optional.to_dict()
		var kind: String = objective["world_kind"]
		var requested_vehicle: String = objective.get("vehicle", "")
		if not requested_vehicle.is_empty():
			_place_for(target)
			world._update_interaction()
			if kind.contains("checkpoint") or kind == "parking":
				world.content_world.step(1.6)
			elif world.nearest and world.nearest.get("object_id") == target:
				world.player.interaction_requested.emit()
			check(world.optional.to_dict() == old_progress, "wrong_vehicle_rejected_in_actual_world_" + target)
		_place_for(target, requested_vehicle)
		if kind.contains("checkpoint") or kind == "parking":
			world.content_world.step(1.6 if kind == "parking" else 0.01)
		else:
			world._update_interaction()
			check(world.nearest != null and world.nearest.get("object_id") == target, "actual_nearest_object_" + target)
			if world.nearest != null and world.nearest.get("object_id") == target:
				world.player.interaction_requested.emit()
		check(world.optional.to_dict() != old_progress, "actual_world_interaction_advances_" + target)
		if world.optional.to_dict() == old_progress:
			break
		await process_frame
	check(world.optional.status == "completed", "actual_world_completes_" + id)
	_release_vehicles()

func _check_pause_and_timer() -> void:
	world.hud.optional_selected.emit("ACT-001")
	world._process(0)
	check(not world.optional.timer_started and world.optional.elapsed == 0, "timer_waits_for_actual_bicycle_start")
	_place_for("ACT_001_start", "bicycle")
	world._update_interaction()
	world.player.interaction_requested.emit()
	check(world.optional.timer_started, "actual_start_begins_timer")
	world.optional.advance_time(3.0)
	world.hud.show_optional_phone()
	world._process(0)
	var positions: Array[Vector3] = [world.player.position, world.car.position, world.bicycle.position]
	for guard: Node3D in world.guards.values(): positions.append(guard.position)
	for person: Node3D in world.people.values(): positions.append(person.position)
	var life_clock: float = world.city_life.clock
	var elapsed: float = world.optional.elapsed
	await create_timer(0.3, true).timeout
	var after: Array[Vector3] = [world.player.position, world.car.position, world.bicycle.position]
	for guard: Node3D in world.guards.values(): after.append(guard.position)
	for person: Node3D in world.people.values(): after.append(person.position)
	check(after == positions and world.city_life.clock == life_clock and world.optional.elapsed == elapsed, "actual_phone_pause_freezes_all_gameplay_actors_and_timer")
	world._resume()
	world._process(0)
	world.optional.advance_time(90)
	check(world.optional.status == "failed", "actual_optional_timer_failure")
	world.hud.show_optional_phone("activity")
	world.hud.optional_selected.emit("ACT-001")
	world._process(0)
	check(world.optional.status == "active" and world.optional.elapsed == 0 and not world.optional.timer_started, "actual_phone_failed_activity_restarts_cleanly")
	world.optional.cancel_task()
	_release_vehicles()

func _check_album_retention() -> void:
	world.hud.optional_selected.emit("ACT-005")
	world._process(0)
	_place_for("ACT_005_photo_1")
	world._update_interaction()
	world.player.interaction_requested.emit()
	var wallet: int = world.optional.wallet
	check(world.optional.collected_points == ["ACT_005_photo_1"] and world.objects["ACT_005_photo_1"].collected, "actual_photo_collects_one_world_object_and_album_point")
	var active_state: Dictionary = world.optional.to_dict()
	world._retry()
	world._process(0)
	check(world.optional.to_dict() == active_state and world.objects["ACT_005_photo_1"].collected, "main_retry_preserves_active_album_progress_and_collected_object")
	world._save(false)
	world.optional.cancel_task()
	world._load(SLOT)
	world._process(0)
	if not _same_saved_value(world.optional.to_dict(), active_state) or not world.objects["ACT_005_photo_1"].collected:
		var differing: Dictionary = {}
		for key: String in active_state:
			if active_state[key] != world.optional.to_dict()[key]: differing[key] = {"before": active_state[key], "after": world.optional.to_dict()[key]}
		print("ALBUM_LOAD_EVIDENCE ", JSON.stringify({"differing": differing, "object_collected": world.objects["ACT_005_photo_1"].collected, "world_notice": world.info_text, "save_message": Save.last_message, "save_world_valid": world._valid_world_save(Save.load_state(SLOT))}))
	check(_same_saved_value(world.optional.to_dict(), active_state) and world.objects["ACT_005_photo_1"].collected, "slot94_load_preserves_active_album_and_collected_object")
	world.optional.cancel_task()
	world.hud.optional_selected.emit("ACT-005")
	world._process(0)
	check(world.optional.wallet == wallet and world.optional.collected_points == ["ACT_005_photo_1"] and world.objects["ACT_005_photo_1"].collected and "ACT_005_photo_1" not in world.optional.get_active_target_keys(), "cancel_reselect_restores_album_without_duplicate_photo_reward")
	world.optional.cancel_task()

func _check_car_parking_boundary() -> void:
	world.hud.optional_selected.emit("ACT-002")
	world._process(0)
	for target: String in ["ACT_002_start", "ACT_002_cp_1", "ACT_002_cp_2", "ACT_002_cp_3"]:
		_place_for(target, "car")
		if target.ends_with("start"):
			world._update_interaction()
			world.player.interaction_requested.emit()
		else:
			world.content_world.step(0.01)
	var target_point: Vector3 = world.targets["ACT_002_parking"]
	var collision: CollisionShape3D = world.car.get_node("VehicleCollision")
	var box_query := PhysicsShapeQueryParameters3D.new()
	box_query.shape = collision.shape
	box_query.transform = Transform3D(Basis.IDENTITY, target_point + collision.position)
	box_query.collision_mask = 1
	var blockers: Array[Dictionary] = world.get_world_3d().direct_space_state.intersect_shape(box_query, 6)
	check(blockers.is_empty(), "real_car_body_has_clear_space_at_parking_centre")
	world.car.position = target_point + Vector3(3.0, 0, 0)
	world.car.rotation.y = PI * 0.5
	world.car.speed_mps = 0
	world.player._physics_process(0)
	world.content_world.step(1.6)
	check(world.optional.status != "completed", "parking_rejects_car_centre_3m_outside_designated_space")
	print("PARKING_BOUNDARY_EVIDENCE ", JSON.stringify({"target": str(target_point), "car": str(world.car.position), "rotation_y": world.car.rotation.y, "status": world.optional.status}))
	world.car.position = target_point
	world.car.rotation.y = 0
	world.car.speed_mps = 3.0
	world.player._physics_process(0)
	world.content_world.step(1.6)
	check(world.optional.status == "active", "parking_rejects_aligned_vehicle_still_moving")
	world.car.speed_mps = 0
	world.content_world.step(0.75)
	check(world.optional.status == "active", "parking_requires_continuous_stationary_hold")
	world.content_world.step(0.8)
	check(world.optional.status == "completed", "parking_accepts_entire_aligned_stationary_vehicle_after_hold")
	world.optional.cancel_task()
	_release_vehicles()

func _find_button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption: return node
	for child: Node in node.get_children():
		var found := _find_button(child, caption)
		if found: return found
	return null

func _check_external_brake_ownership() -> void:
	for enabled: bool in [false, true]:
		_release_vehicles()
		world.touch_controls.set_enabled(enabled)
		world._resume()
		world.car.position = world.targets["ACT_002_parking"]
		world.car.rotation = Vector3.ZERO
		world.player.position = world.car.position + Vector3(3, 0, 0)
		var entered: bool = world.car.enter(world.player)
		world.car.speed_mps = 5.0
		Input.action_press("brake")
		await process_frame
		await physics_frame
		await physics_frame
		check(entered and Input.is_action_pressed("brake") and world.car.speed_mps < 4.9, "external_brake_survives_actual_touch_process_and_slows_car_enabled_" + str(enabled))
		Input.action_release("brake")
	_release_vehicles()
	world.touch_controls.set_enabled(true)
	world._resume()
	await process_frame
	var jump_button: Button = _find_button(world.touch_controls, "跳／煞")
	var down := InputEventMouseButton.new()
	down.position = jump_button.get_global_rect().get_center()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down, true)
	check(Input.is_action_pressed("jump") and Input.is_action_pressed("brake"), "actual_GUI_touch_jump_owns_paired_brake")
	world.touch_controls.set_enabled(false)
	await process_frame
	check(not Input.is_action_pressed("jump") and not Input.is_action_pressed("brake"), "disabling_actual_held_touch_jump_releases_its_paired_brake")
	var up := down.duplicate()
	up.pressed = false
	root.push_input(up, true)

func _check_touch_tap() -> void:
	world._resume()
	world._process(0)
	world.touch_controls.set_enabled(true)
	world._resume()
	world.player.position = approaches["optional_board"] if approaches.has("optional_board") else Vector3(-59, 0.15, 51)
	world.player.velocity = Vector3.ZERO
	world._update_interaction()
	await process_frame
	var button: Button = _find_button(world.touch_controls, "互動")
	check(button != null and button.is_visible_in_tree(), "actual_touch_interact_button_present")
	if button:
		var position_value := button.get_global_rect().get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = position_value
		root.push_input(motion, true)
		var down := InputEventMouseButton.new()
		down.position = position_value
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		root.push_input(down, true)
		var up := down.duplicate()
		up.pressed = false
		root.push_input(up, true)
		print("TOUCH_TAP_EVIDENCE ", JSON.stringify({"button_rect": str(button.get_global_rect()), "held_after_tap": world.touch_controls.held.duplicate(), "nearest": str(world.nearest.get("object_id")) if world.nearest else "", "mouse_mode": Input.mouse_mode}))
		await physics_frame
		await physics_frame
		check(world.hud.get_menu_mode() == "optional", "real_GUI_quick_tap_triggers_player_interaction_once")
		await process_frame
		check(not Input.is_action_pressed("interact"), "menu_pause_releases_touch_action")
	world._resume()
	world.touch_controls.set_enabled(false)

func _check_touch_resize_release() -> void:
	root.content_scale_size = Vector2i(844, 390)
	root.size = Vector2i(844, 390)
	world.touch_controls.set_enabled(true)
	world._resume()
	world.touch_controls._layout()
	await process_frame
	await process_frame
	var button: Button = _find_button(world.touch_controls, "↑")
	var down := InputEventMouseButton.new()
	down.position = button.get_global_rect().get_center()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down, true)
	await process_frame
	check(Input.is_action_pressed("move_forward"), "actual_GUI_hold_enters_movement_action")
	root.content_scale_size = Vector2i(462, 260)
	root.size = Vector2i(462, 260)
	world.touch_controls._layout()
	await process_frame
	check(not Input.is_action_pressed("move_forward"), "shrinking_touch_viewport_releases_hidden_held_action")
	var up := down.duplicate()
	up.pressed = false
	root.push_input(up, true)
	world.touch_controls.release_all()
	world.touch_controls.set_enabled(false)

func _check_viewport_layout(size: Vector2i) -> void:
	root.content_scale_size = size
	root.size = size
	world.touch_controls.set_enabled(true)
	world._resume()
	world.touch_controls._layout()
	world.hud._resize_modal()
	await process_frame
	await process_frame
	var visible_rect: Rect2 = root.get_visible_rect()
	var all_buttons_fit := true
	var visible_buttons := 0
	for button: Node in world.touch_controls.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			visible_buttons += 1
			all_buttons_fit = all_buttons_fit and visible_rect.encloses(button.get_global_rect())
	var fallback: bool = world.touch_controls.small_view_hint != null and world.touch_controls.small_view_hint.is_visible_in_tree() and visible_rect.encloses(world.touch_controls.small_view_hint.get_global_rect())
	check(all_buttons_fit and (visible_buttons > 0 or fallback), "visible_touch_controls_fit_or_explain_required_larger_viewport_%dx%d" % [size.x, size.y])
	world.hud.show_optional_phone()
	await process_frame
	await process_frame
	var modal: Rect2 = world.hud._modal_panel.get_global_rect()
	check(visible_rect.encloses(modal), "optional_menu_fits_viewport_%dx%d" % [size.x, size.y])
	print("VIEWPORT_EVIDENCE ", JSON.stringify({"size": str(size), "visible_rect": str(visible_rect), "modal_rect": str(modal), "touch_buttons_fit": all_buttons_fit, "visible_touch_buttons": visible_buttons, "larger_viewport_hint": fallback}))
	world._resume()
	world.touch_controls.set_enabled(false)
