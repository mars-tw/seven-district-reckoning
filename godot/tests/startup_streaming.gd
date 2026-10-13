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
	check(not is_instance_valid(game._startup_progress._layer) or not game._startup_progress._layer.visible, "loading_overlay_hidden_at_core_release")
	check(paused, "title_pauses_gameplay")
	check(game._startup_progress.core_released and not game._startup_progress.complete, "streaming_scheduler_retained")
	check(not game._startup_progress.first_frame_drawn, "headless_does_not_claim_native_frame")
	game.street_state.quality = "performance"
	game.device_profiles.set_profile("desktop",false)
	check(not game.district_sun.shadow_enabled, "desktop_performance_quality_disables_sun_shadow")
	var core_ms := Time.get_ticks_msec() - started_ms
	var title_items: int = game._startup_progress._total_units
	for index in 10: await process_frame
	check(game._startup_progress._total_units > title_items, "outer_build_continues_while_title_paused")
	var urban_frames := 0
	while not is_instance_valid(game.urban_detail) and urban_frames < 1000:
		await process_frame
		urban_frames += 1
	check(is_instance_valid(game.urban_detail), "late_urban_detail_created")
	check(not game.district_sun.shadow_enabled, "late_device_pass_preserves_performance_sun_shadow")
	game.device_profiles.set_profile("phone",false)
	check(game._device_settings.get("profile","") == "phone", "phone_budget_selected_during_outer_build")
	game._set_title_world_hidden(true)
	check(not game.visible and game.hud.visible and game.hud.get_menu_mode() == "title", "title_canvas_survives_mobile_world_suspend")
	game.is_test_mode = true
	game._new_game()
	check(game.visible and not game._title_world_hidden, "start_restores_3d_world")
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
	var bike_spawn: Vector3 = game.bicycle.global_position
	game.player.global_position = bike_spawn + Vector3(1,0,0)
	check(game.bicycle.enter(game.player), "bicycle_can_mount_during_outer_build")
	game.bicycle.global_position = Vector3(160,.12,45)
	for index in 3: await physics_frame
	for index in 2: await process_frame
	check(game.bicycle.global_position.distance_to(bike_spawn) < 3.0 and absf(game.player.global_position.x) <= 145, "bicycle_and_rider_cannot_cross_unfinished_outer_boundary")
	game.bicycle.force_release()
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
	game.device_profiles.set_profile("desktop",false)
	await process_frame
	check(game.taiwan_expansion._view_distance == 440.0 and game.taiwan_expansion._prop_distance == 180.0 and not game.district_sun.shadow_enabled, "mid_build_desktop_budget_updates_without_quality_shadow_regression")
	game.device_profiles.set_profile("phone",false)
	await process_frame
	check(game.taiwan_expansion._view_distance == 190.0 and game.taiwan_expansion._prop_distance == 70.0, "mid_build_phone_budget_updates_before_new_draws")
	var frames_to_full := 0
	var saw_profiled_stream_draw := false
	while not game.expansion_complete and frames_to_full < 30000:
		await process_frame
		frames_to_full += 1
		if not saw_profiled_stream_draw and not game.expansion_complete and not game.taiwan_expansion._draws.is_empty():
			var draw: GeometryInstance3D = game.taiwan_expansion._draws[0]["node"]
			check(draw.visibility_range_end > 0 and draw.visibility_range_end <= 190.0 and draw.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "streamed_draw_inherits_phone_visibility_shadow_budget_at_creation")
			saw_profiled_stream_draw = true
	check(game.expansion_complete, "original_outer_world_finishes")
	check(saw_profiled_stream_draw, "streamed_draw_profile_observed_before_full_ready")
	if game.expansion_complete:
		var counts: Dictionary = game.taiwan_expansion.get_counts()
		check(counts["regions"] == 8 and counts["stations"] == 32 and counts["roads"] == 16, "all_regions_stations_roads")
		check(counts["citizens"] == 16 and counts["moving_vehicles"] == 4, "all_outer_actors")
		check(counts["terrain_bodies"] == 4 and counts["terrain_area_m2"] == 550000.0, "full_800m_terrain")
		check(counts["draw_groups"] == 479 and counts["collider_shapes"] == 485 and counts["lod_levels"] == 55, "full_batch_collider_lod_counts")
		check(counts["view_distance"] == 190.0 and counts["prop_distance"] == 70.0, "phone_profile_retained_after_streaming")
		check(counts["missing_assets"].is_empty(), "no_missing_asset")
		var textured_materials := 0
		for material: StandardMaterial3D in game.urban_detail._materials.values():
			if material.normal_texture != null or material.ao_texture != null:
				textured_materials += 1
				check(not material.normal_enabled and not material.ao_enabled, "late_urban_material_respects_performance_quality")
		check(textured_materials > 0, "quality_test_covered_textured_urban_materials")
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
