extends "content_r7.gd"
## R10: wrong direction never unlocks time; repaired evidence survives disk.
func run() -> void:
	var c := Content.new()
	c.start("before_night")
	while c.pending() >= 0: c.collect(c.target_position())
	for i: int in 3: c.place_time(i,i)
	c.choose_relation(0,1); c.choose_relation(1,1)
	check(not c.verify_time() and not c.entry().time_revealed,"wrong_arrow_cannot_reveal")
	check(c.relation_error(0).contains("你選的：交接摘要 → 車店收據") and c.relation_error(0).contains("應為：車店收據 → 交接摘要"),"exact_wrong_and_correct_directions")
	c.choose_relation(0,0)
	check(c.entry().relations["1"] == 1 and c.verify_time(),"local_repair_preserves_other_link")
	check(not c.entry().complete and c.seal_time(0),"attachment_required_to_complete")
	check(Save.save_state({"schema":1,"investigations":c.to_dict()},96) == OK,"r10_disk_save")
	var copy := Content.new()
	check(copy.from_dict(Save.load_state(96).investigations) and copy.to_dict() == c.to_dict(),"r10_exact_disk_reload")
	Engine.set_meta("seven_district_no_records",true)
	game = Main.new(); root.add_child(game)
	var frames := 0
	while not game.expansion_complete and frames < 20000: await process_frame; frames += 1
	check(game.expansion_complete,"r10_world_loaded")
	game.is_test_mode = true; game._new_game(); game.set_process(false); game.player.set_physics_process(false)
	var panel: CanvasLayer = game.investigation_panel
	for size_value: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(430,932),Vector2i(568,320),Vector2i(844,390),Vector2i(1032,1376),Vector2i(1024,768),Vector2i(1366,600),Vector2i(1280,640)]:
		root.size = size_value; root.content_scale_size = size_value
		ready("before_night")
		for i: int in 3: game.investigations.place_time(i,i)
		for pair_index: int in 2:
			game.investigations.choose_relation(0,0); game.investigations.choose_relation(1,1)
			game.investigations.choose_relation(pair_index,[1,0][pair_index])
			panel.relation_index = pair_index; panel.page = "relations"; panel.show_page(); await settle()
			layout("r10_wrong_links"); check_ink(panel)
			check(is_instance_valid(panel.surface.find_child("DocumentLinks",true,false)),"real_three_document_diagram")
			for b: Dictionary in panel.diagnostics().buttons:
				if b.text == "揭時核對": check(b.disabled,"wrong_direction_disables_reveal")
			check(not JSON.stringify(panel.diagnostics().labels).contains("✓"),"wrong_state_no_checkmarks")
		game.investigations.choose_relation(0,0); game.investigations.choose_relation(1,1)
		panel.show_page(); await settle(); layout("r10_correct_links")
		game.investigations.verify_time(); panel.page = "solve"; panel.show_page(); await settle(); layout("r10_attachment")
		ready("second_help")
		panel.page = "inspect"; panel.show_page(); await settle(); layout("r10_source_context"); check_ink(panel)
		ready("three_voices"); game.investigations.begin_pin_review()
		game.investigations.reference_support(0); game.investigations.reference_support(2)
		for i: int in 3: game.investigations.choose_pin(i,[1,2,0][i]); game.investigations.pin_record(i)
		var before: Dictionary = game.investigations.to_dict()
		game.investigations.uncite_support(0)
		check(game.investigations.entry().pins == [0,2] and not game.investigations.entry().pin_choices.has("1"),"only_player_inference_reopens")
		check(game.investigations.entry().pin_choices["0"] == 1 and game.investigations.entry().pin_choices["2"] == 0,"original_record_judgments_preserved")
		game.investigations.reference_support(0); game.investigations.choose_pin(1,2); game.investigations.pin_record(1); game.investigations.seal_records()
		panel.page = "chain"; panel.show_page(); await settle(); layout("r10_inference_chain"); check_ink(panel)
		check(JSON.stringify(panel.diagnostics().labels).contains("玩家推論"),"inference_explicitly_named")
	panel.close(); game.queue_free(); await settle()
	print("CONTENT_R10_CHECKS=%d FAILURES=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
