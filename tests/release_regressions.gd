extends SceneTree

const Save = preload("res://scripts/save/save_manager.gd")
const Scene = preload("res://scenes/main.tscn")
var world: Node3D
var failures: Array[String] = []
var passed: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, name: String) -> void:
	if condition:
		passed.append(name)
		print("REVIEW_PASS ", name)
	else:
		failures.append(name)
		push_error("REVIEW_FAIL " + name)

func fresh() -> void:
	paused = false
	if is_instance_valid(world):
		world.free()
	world = Scene.instantiate()
	root.add_child(world)
	current_scene = world
	# The product's _save() normally writes slot 1. Disconnect automatic saves;
	# this isolated driver only calls AlphaSave with slot 95 explicitly.
	world.missions.mission_completed.disconnect(world._on_mission_completed)
	world.missions.chapter_completed.disconnect(world._on_chapter_complete)
	world.is_test_mode = true

func begin() -> void:
	fresh()
	world._new_game()

func advance_to_practice() -> void:
	world._use_object("mei")
	world._use_object("phone")
	world._use_object("wrench")

func advance_to_rescues() -> void:
	world._event("practice_hit", "practice_1")
	world._event("practice_hit", "practice_2")
	world._event("alternate_route", "service_gate")
	world._event("disable_sign", "fake_sign")
	world._event("collect_pass", "pass")
	world._event("mount_bicycle", "bicycle")
	for id: String in ["route_1", "route_2", "route_3"]:
		world._event("route_checkpoint", id)
	world._event("return_shop", "mei_shop")
	world._event("unlock_car", "car")

func strike(id: String) -> void:
	var object: Node3D = world.objects[id]
	world.player.global_position = object.global_position + Vector3(0, 0.12, -1.6)
	world.player.velocity = Vector3.ZERO
	world.player.set("_facing", Vector3(0, 0, 1))
	await physics_frame
	check(world.player.begin_attack(), "actual_attack_begins_" + id)
	await create_timer(0.75).timeout

func _run() -> void:
	begin()
	for id: String in ["practice_1", "practice_2", "fake_sign", "equipment_1", "equipment_2", "equipment_3", "record_1", "record_2"]:
		var object: Node = world.objects[id]
		object.apply_hit("early:" + id, "review", 100.0)
		check(not object.broken and object.health == 35.0, "premature_damage_protected_" + id)
	advance_to_practice()
	world._use_object("practice_1")
	world._use_object("practice_2")
	check(world.missions.mission_index == 0 and world.missions.current_objective == 3, "E_cannot_complete_practice")
	await strike("practice_1")
	await strike("practice_2")
	check(world.missions.mission_index == 1, "actual_player_hits_complete_practice")

	begin()
	advance_to_practice()
	var mid_save: Dictionary = world._snapshot()
	check(Save.save_state(mid_save, 95) == OK, "slot95_mid_mission_save")
	fresh()
	var loaded: Dictionary = Save.load_state(95)
	world._load(95)
	check(world.play_started and world.missions.current_objective == 3, "fresh_scene_load_mid_MAIN001")
	check(world.objects["wrench"].collected, "loaded_wrench_collected_before_retry")
	world._retry()
	check(world.missions.current_objective == 0 and not world.objects["wrench"].collected, "retry_restores_replayable_wrench")
	advance_to_practice()
	check(world.missions.current_objective == 3 and world.player.inventory["melee"].has("wrench"), "retry_can_reach_practice_again")

	var alive_save: Dictionary = world._snapshot()
	for guard: Node in world.guards.values():
		guard.apply_hit("kill:" + guard.name, "review", 100.0)
	await create_timer(1.0).timeout
	check(world.guards["guard_1"].health == 0, "guard_defeat_reached")
	check(world._restore(alive_save), "restore_pre_fight_save")
	check(world.guards["guard_1"].health == 75 and world.guards["guard_1"].is_in_group("damageable"), "pre_fight_restore_revives_guard")

	world.player.global_position = world.bicycle.global_position + Vector3(2, 0, 0)
	check(world.bicycle.enter(world.player), "bike_mount_for_saved_occupancy")
	var mounted_save: Dictionary = world._snapshot()
	check(Save.save_state(mounted_save, 95) == OK, "slot95_mounted_save")
	check(world._restore(Save.load_state(95)), "mounted_save_restore")
	check(world.player.mounted_vehicle == world.bicycle and world.bicycle.occupied and not world.car.occupied, "single_vehicle_occupancy_after_restore")
	world._retry()
	check(world.player.mounted_vehicle == null and not world.bicycle.occupied and not world.car.occupied, "retry_releases_checkpoint_vehicle_occupancy")

	begin()
	world.player.grant_weapon("pulse")
	world.player.pulse_energy = 3
	world._use_object("pulse_pickup")
	world._use_object("pulse_pickup")
	check(world.player.pulse_energy == 3, "repeat_pulse_pickup_does_not_refill")
	advance_to_practice()
	advance_to_rescues()
	check(world.missions.mission_index == 3, "rescue_fixture_reached")
	world.nearest = world.people["rescue_A"]
	world._interact()
	world.people["rescue_A"].global_position = world.people["rescue_A"].safe_point
	await create_timer(0.12).timeout
	check(not world.people["rescue_A"].arrived and world.people["rescue_A"].following, "early_safe_arrival_keeps_retrying")
	world.nearest = world.people["rescue_B"]
	world._interact()
	world.people["rescue_B"].global_position = world.people["rescue_B"].safe_point + Vector3(1, 0, 0)
	await create_timer(0.15).timeout
	check(world.missions.mission_index == 4 and world.missions.scores["rescued_count"] == 2, "early_safe_arrival_then_second_release_completes")
	world._event("select_branch", "smash")
	for id: String in ["equipment_1", "equipment_2", "equipment_3"]:
		world._use_object(id)
	check(world.missions.current_objective == 1 and world.missions.get_current_objective().get("completed", 0) == 0, "E_cannot_complete_smash")
	for id: String in ["equipment_1", "equipment_2", "equipment_3"]:
		world.objects[id].apply_hit("active:" + id, "review", 100.0)
	check(world.missions.current_objective == 2, "real_object_destruction_advances_smash")
	var broken_save: Dictionary = world._snapshot()
	check(world._valid_world_save(broken_save), "legitimate_broken_objects_save_is_valid")
	check(Save.save_state(broken_save, 95) == OK, "slot95_broken_objects_save")
	check(world._restore(Save.load_state(95)), "broken_objects_JSON_roundtrip_restores")
	check(world.objects["equipment_1"].broken and world.objects["equipment_1"].health == 0, "broken_object_roundtrip_preserves_zero_health")
	world._new_game()
	check(world.missions.mission_index == 0 and world.missions.current_objective == 0 and not world.objects["wrench"].collected, "repeat_testmode_new_game_resets_mission_and_objects")
	var old_scene_id: int = world.get_instance_id()
	world.is_test_mode = false
	world._new_game()
	await process_frame
	await process_frame
	await process_frame
	world = current_scene
	check(is_instance_valid(world) and world.get_instance_id() != old_scene_id and world.play_started and world.missions.mission_index == 0 and not world.objects["wrench"].collected, "normal_new_game_reloads_and_autostarts_scene")
	print("RELEASE_REVIEW_RESULT ", JSON.stringify({"passed": passed, "failures": failures, "slot": 95, "human_playthrough": false}))
	quit(1 if not failures.is_empty() else 0)
