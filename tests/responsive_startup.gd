extends SceneTree
var failures: Array[String] = []
func check(ok: bool, name: String) -> void:
	if not ok: failures.append(name)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var expected_namespace := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-user-dir="): expected_namespace = arg.trim_prefix("--test-user-dir=")
	if expected_namespace.is_empty() or OS.get_user_data_dir().get_file() != expected_namespace:
		print("STARTUP_CANDIDATE_TEST user_namespace_not_isolated")
		quit(2)
		return
	var scene := load("res://scenes/main.tscn") as PackedScene
	var early: Node = scene.instantiate()
	root.add_child(early)
	var canceled: RefCounted = early._startup_progress
	check(not early.startup_complete,"not_ready_during_first_frame")
	early._new_game()
	early._resume()
	early._load()
	check(not early.play_started,"direct_start_resume_load_guarded")
	check(paused,"loader_pauses_gameplay_tree")
	early.queue_free()
	await process_frame
	await process_frame
	check(not canceled.running() and not canceled.complete,"scene_exit_never_fake_ready")
	check(not paused,"canceled_load_restores_prior_pause")
	check(not await canceled.checkpoint(),"canceled_future_batch_rejected")
	var game: Node = scene.instantiate()
	root.add_child(game)
	var frames := 0
	while not game.startup_complete and frames < 15000:
		await process_frame
		frames += 1
	check(game.startup_complete,"full_original_world_reaches_ready")
	if game.startup_complete:
		check(frames > 8,"batches_progress_across_real_process_frames")
		check(paused,"original_title_still_pauses_gameplay")
		check(not game._startup_progress.first_frame_drawn,"headless_never_claims_rendered_first_frame")
		var expansion: Dictionary = game.taiwan_expansion.get_counts()
		var district: Dictionary = game.city_life.get_counts()
		check(expansion["regions"]==8 and expansion["stations"]==32,"all_expansion_regions_stations")
		check(district["districts"]==6 and district["citizens"]==8 and district["moving_vehicles"]==4,"all_district_life_population")
		check(expansion["citizens"]==16 and expansion["moving_vehicles"]==4,"all_expansion_population")
		check(game.guards.size()==2 and game.people.size()==4 and game.contact_people.size()==3,"all_original_guards_rescues_contacts")
		check(game.taiwan_life.stations.size()==32 and game.taiwan_world.actors.size()==8,"all_life_stations_story_people")
		check(game.optional.tasks.size()==10,"all_optional_missions")
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/taiwan_asset_manifest.json"))
		for asset: Dictionary in manifest["assets"]:
			check(int(expansion["assets"].get(str(asset["name"]),0))>0,"full_kit_"+str(asset["name"]))
		check(expansion["missing_assets"].is_empty() and district["missing_assets"].is_empty(),"no_silent_missing_world_asset")
		check(game.taiwan_expansion._startup_progress == null and game.urban_detail._startup_progress == null,"finished_builders_detach_scheduler")
		var frame_before := Engine.get_process_frames()
		game.taiwan_expansion.apply_profile({"view_distance":310.0,"prop_distance":120.0})
		check(game.taiwan_expansion._view_distance==310.0 and game.taiwan_expansion._prop_distance==120.0,"runtime_profile_completes_synchronously")
		game.taiwan_expansion.set_hour(21.0)
		check(game.taiwan_expansion._hour==21.0,"runtime_hour_completes_synchronously")
		check(Engine.get_process_frames()==frame_before,"runtime_profile_hour_do_not_spawn_frame_tasks")
		check(await game._startup_progress.checkpoint(),"completed_scheduler_checkpoint_is_immediate")
		check(Engine.get_process_frames()==frame_before,"completed_scheduler_never_yields_or_touches_freed_label")
		game.is_test_mode = true
		game._new_game()
		check(game.play_started and not paused,"original_new_game_enabled_only_after_full_ready")
	game.queue_free()
	await process_frame
	print("STARTUP_CANDIDATE_TEST "+JSON.stringify({"failures":failures,"fullBuildFrames":frames,"headless":true,"nativeRenderVerified":false}))
	quit(0 if failures.is_empty() else 1)
