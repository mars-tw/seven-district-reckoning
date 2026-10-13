extends SceneTree
const SaveScript = preload("res://scripts/save/save_manager.gd")

var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	if not condition: failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var started_ms := Time.get_ticks_msec()
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game: Node = scene.instantiate()
	root.add_child(game)
	var frames_to_core := 0
	while not game.startup_complete and frames_to_core < 2000:
		await process_frame
		frames_to_core += 1
	check(game.startup_complete, "core_ready")
	if not game.startup_complete:
		print("STARTUP_STREAMING_TEST ", JSON.stringify({"failures": failures, "core_frames": frames_to_core, "headless": true}))
		quit(1)
		return
	check(not game.expansion_complete, "outer_world_not_falsely_ready_at_title")
	check(game.hud.get_menu_mode() == "title", "title_visible")
	check(game.visible, "core_world_visible")
	check(paused, "title_pauses_gameplay")
	check(game._startup_progress.core_released and not game._startup_progress.complete, "streaming_scheduler_retained")
	check(not game._startup_progress.first_frame_drawn, "headless_does_not_claim_native_frame")
	var core_ms := Time.get_ticks_msec() - started_ms
	var title_items: int = game._startup_progress._total_units
	for index in 10: await process_frame
	check(game._startup_progress._total_units > title_items, "outer_build_continues_while_title_paused")
	game.is_test_mode = true
	game._new_game()
	check(game.play_started and not paused, "start_and_core_gameplay_before_expansion")
	game.hud.show_pause()
	check(paused, "pause_still_freezes_gameplay")
	var pause_items: int = game._startup_progress._total_units
	for index in 10: await process_frame
	check(game._startup_progress._total_units > pause_items, "outer_build_continues_while_player_paused")
	game._resume()
	var core_position: Vector3 = game.player.global_position
	Input.action_press("move_forward")
	for index in 12: await physics_frame
	Input.action_release("move_forward")
	check(game.player.global_position.distance_to(core_position) > 0.1, "core_player_moves_while_outer_builds")
	check(not game.expansion_complete, "outer_build_still_running_during_core_movement")
	game.player.global_position = Vector3(160,.2,52)
	await process_frame
	await process_frame
	check(absf(game.player.global_position.x) <= 145, "unfinished_outer_area_has_safe_core_boundary")
	var life_status: String = game.taiwan_life.status
	var life_id: String = str(game.taiwan_life.tasks.keys()[0])
	game._start_life_task(life_id)
	check(game.taiwan_life.status == life_status, "outer_life_mission_not_started_half_built")
	var optional_id: String = str(game.optional.tasks[0]["id"])
	game._start_optional(optional_id)
	check(game.optional.status == "active", "core_optional_mission_works_while_outer_builds")
	game._save(false)
	var stored: Dictionary = SaveScript.load_state(98)
	check(not stored.is_empty(), "core_progress_saves_during_streaming")
	var frames_to_full := 0
	while not game.expansion_complete and frames_to_full < 30000:
		await process_frame
		frames_to_full += 1
	check(game.expansion_complete, "original_outer_world_finishes")
	if game.expansion_complete:
		var counts: Dictionary = game.taiwan_expansion.get_counts()
		check(counts["regions"] == 8 and counts["stations"] == 32 and counts["roads"] == 16, "all_regions_stations_roads")
		check(counts["citizens"] == 16 and counts["moving_vehicles"] == 4, "all_outer_actors")
		check(counts["terrain_bodies"] == 4 and counts["terrain_area_m2"] == 550000.0, "full_800m_terrain")
		check(counts["missing_assets"].is_empty(), "no_missing_asset")
		check(game.taiwan_world.actors.size() == 8 and game.taiwan_world.station_ids.size() == 32, "all_story_people_stations")
		check(game.optional.tasks.size() == 10, "all_optional_missions_retained")
		check(game._startup_progress.complete and game.taiwan_expansion._startup_progress == null, "deterministic_finish")
		check(game.play_started and game.missions.mission_index == 0, "core_mission_survives_world_completion")
		check(game.optional.status == "active" and game.optional.active_id == optional_id, "core_optional_mission_survives_world_completion")
		game._load(98)
		check(game.play_started and game.missions.mission_index == 0, "saved_core_progress_loads_after_full_world")
	game.queue_free()
	await process_frame
	print("STARTUP_STREAMING_TEST ", JSON.stringify({"failures": failures, "core_frames": frames_to_core, "outer_frames": frames_to_full, "core_ms": core_ms, "full_ms": Time.get_ticks_msec() - started_ms, "headless": true, "native_render_verified": false}))
	quit(0 if failures.is_empty() else 1)
