extends "content_r7.gd"
## R9 exercises the actual case models and all visible investigation stages.
func run() -> void:
	var c := Content.new()
	c.start("second_help")
	while c.pending() >= 0: c.collect(c.target_position())
	c.cite(0,2); c.cite(1,2); c.compare_choice(0)
	for choice: int in [1,2]:
		check(not c.choose_action(choice) and not c.entry().complete,"unsafe_actions_remain_unsealed")
		var result: Dictionary = c.street_result()
		check(result.count == (1 if choice == 2 else 2),"live_retention_object_count")
		check(result.payment.contains("付款") and result.line.contains("美晴"),"live_payment_and_npc_response")
	check(c.choose_action(0),"evidence_backed_action_completes")
	var record := c.to_dict()
	for choice: int in 3:
		c.street_choice = choice
		check(c.street_result().count == (1 if choice == 2 else 2),"archived_action_replay_object_count")
		check(c.to_dict() == record,"street_replay_cannot_mutate_archive")
	check(Save.save_state({"schema":1,"investigations":record},96) == OK,"r9_save")
	var copy := Content.new()
	check(copy.from_dict(Save.load_state(96).investigations) and copy.records == c.records,"r9_exact_archive_disk_roundtrip")
	c.start("three_voices")
	while c.pending() >= 0: c.collect(c.target_position())
	c.begin_pin_review(); c.reference_support(0)
	check(not c.choose_pin(1,2) and c.feedback.contains("17：50") and c.feedback.contains("18：10"),"first_only_names_actual_and_missing_record")
	c.entry().support_refs = [2]
	check(not c.choose_pin(1,2) and c.feedback.begins_with("已引用 18：10") and c.feedback.contains("17：50"),"last_only_names_actual_and_missing_record")
	Engine.set_meta("seven_district_no_records",true)
	game = Main.new(); root.add_child(game)
	var frames := 0
	while not game.expansion_complete and frames < 20000: await process_frame; frames += 1
	check(game.expansion_complete,"r9_world_loaded")
	game.is_test_mode = true; game._new_game(); game.set_process(false); game.player.set_physics_process(false)
	var panel: CanvasLayer = game.investigation_panel
	for size_value: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(430,932),Vector2i(568,320),Vector2i(844,390),Vector2i(1032,1376),Vector2i(1024,768),Vector2i(1366,600),Vector2i(1280,640)]:
		root.size = size_value; root.content_scale_size = size_value
		ready("second_help")
		game.investigations.cite(0,2); game.investigations.cite(1,2); game.investigations.compare_choice(0)
		game.investigations.choose_action(2); panel.show_page(); await settle(); layout("r9_latest_only_explanation"); check_ink(panel)
		game.investigations.choose_action(0)
		for stage: String in ["evidence","chain","history"]:
			panel.page = stage; panel.show_page(); await settle(); layout("r9_archive_"+stage); check_ink(panel)
		ready("before_night")
		for i: int in 3: game.investigations.place_time(i,i)
		for relation: int in 2:
			panel.page = "relations"; panel.relation_index = relation; panel.show_page(); await settle(); layout("r9_named_arrows"); check_ink(panel)
			check(JSON.stringify(panel.diagnostics().buttons).contains(" → "),"direction_visible_without_sentence_reading")
		game.investigations.choose_relation(0,1); game.investigations.choose_relation(1,1)
		check(not game.investigations.verify_time() and game.investigations.feedback.contains("附件"),"wrong_arrow_quotes_reversed_phrase")
		game.investigations.choose_relation(0,0)
		check(game.investigations.entry().relations["1"] == 1 and game.investigations.verify_time(),"local_arrow_repair_preserves_other_relation")
		game.investigations.seal_time(0); panel.page = "evidence"; panel.show_page(); await settle(); layout("r9_receipt_archive"); check_ink(panel)
		check(game.investigations.street_result().line.contains("17：42"),"receipt_street_result")
		ready("three_voices"); game.investigations.begin_pin_review()
		for refs: Array in [[],[0],[2],[0,2]]:
			game.investigations.entry().support_refs = refs
			panel.page = "judgement"; panel.pin_index = 1; panel.show_page(); await settle(); layout("r9_actual_missing_ref"); check_ink(panel)
		for i: int in 3: game.investigations.choose_pin(i,[1,2,0][i]); game.investigations.pin_record(i)
		game.investigations.uncite_support(0)
		check(game.investigations.entry().pins == [0,2] and not game.investigations.entry().pin_choices.has("1"),"unciting_reopens_only_composed_pin")
		check(game.investigations.valid(game.investigations.to_dict()),"unciting_keeps_save_valid")
		game.investigations.reference_support(0); game.investigations.choose_pin(1,2); game.investigations.pin_record(1)
		game.investigations.unpin_record(0)
		check(game.investigations.entry().pins.size() == 2 and 1 in game.investigations.entry().pins and 2 in game.investigations.entry().pins,"unpin_preserves_other_records")
		game.investigations.choose_pin(0,1); game.investigations.pin_record(0); game.investigations.seal_records()
		panel.page = "chain"; panel.show_page(); await settle(); layout("r9_full_names_archive"); check_ink(panel)
		check(JSON.stringify(panel.diagnostics().labels).contains("吳安琪"),"archive_uses_full_name")
	panel.close(); game.queue_free(); await settle()
	print("CONTENT_R9_CHECKS=%d FAILURES=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
