extends "content_r5.gd"
## Added decisions are required in the model, including save validation.
func check_ink(panel: CanvasLayer) -> void:
	for ink: Control in panel.surface.find_children("*","Label",true,false)+panel.surface.find_children("*","Button",true,false):
		var displayed: String = ink.get("text")
		var original: String = ink.get_meta("original_text",displayed)
		check(displayed.replace("\n","") == original.replace("\n",""),"typesetting_preserves_every_source_character")
		for line: String in displayed.split("\n"):
			check(line.is_empty() or not line[0] in ["。","，","：","；","？","！","」","』","）","、"],"no_orphan_cjk_closing_punctuation")

func run() -> void:
	var c := Content.new()
	c.start("second_help")
	while c.pending() >= 0: c.collect(c.target_position())
	c.compare_choice(0)
	check(not c.choose_action(0),"cannot_seal_without_both_original_highlights")
	c.cite(0,2)
	check(not c.choose_action(0),"single_original_insufficient")
	c.cite(1,2)
	for wrong: int in [1,2]:
		check(not c.choose_action(wrong) and not c.entry().complete and c.feedback.contains("甲") and c.feedback.contains("乙"),"unsafe_action_explains_both_sources")
	check(c.choose_action(0),"safe_action_keeps_both_originals")
	c.start("before_night")
	while c.pending() >= 0: c.collect(c.target_position())
	for i: int in 3: c.place_time(i,i)
	check(not c.verify_time(),"chronological_sort_alone_insufficient")
	c.choose_relation(0,1); c.choose_relation(1,0)
	check(not c.verify_time() and c.entry().order == [0,1,2],"wrong_relations_preserve_local_work")
	c.choose_relation(0,0); c.choose_relation(1,1)
	check(c.verify_time() and c.seal_time(0),"two_original_relations_plus_bounded_conclusion")
	c.start("three_voices")
	while c.pending() >= 0: c.collect(c.target_position())
	c.begin_pin_review()
	check(not c.choose_pin(1,2),"boundary_single_record_cannot_support_both_sides")
	c.reference_support(0)
	check(not c.choose_pin(1,2),"one_side_cannot_support_both_sides")
	c.reference_support(2)
	for i: int in 3:
		check(c.choose_pin(i,[1,2,0][i]) and c.pin_record(i),"pin_supported_player_judgment")
	check(c.seal_records(),"both_sides_explicitly_referenced")
	check(Save.save_state({"schema":1,"investigations":c.to_dict()},96) == OK,"r7_three_cases_save")
	var copy := Content.new()
	check(copy.from_dict(Save.load_state(96).investigations) and copy.records == c.records,"r7_exact_disk_roundtrip")
	var bad := c.to_dict(); bad.records.three_voices.support_refs = [0]
	check(not copy.valid(bad),"reject_sealed_one_sided_support")
	bad = c.to_dict(); bad.records.before_night.relations = {"0":1,"1":1}
	check(not copy.valid(bad),"reject_sealed_wrong_relation")
	Engine.set_meta("seven_district_no_records",true)
	game = Main.new(); root.add_child(game)
	var frames := 0
	while not game.expansion_complete and frames < 20000: await process_frame; frames += 1
	check(game.expansion_complete,"r7_world_loaded")
	game.is_test_mode = true; game._new_game(); game.set_process(false); game.player.set_physics_process(false)
	var panel: CanvasLayer = game.investigation_panel
	for size_value: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(430,932),Vector2i(568,320),Vector2i(844,390),Vector2i(1032,1376),Vector2i(1024,768),Vector2i(1366,600),Vector2i(1280,640)]:
		root.size = size_value; root.content_scale_size = size_value
		ready("second_help")
		for doc: int in 2:
			panel.page = "inspect"; panel.document = doc; panel.show_page(); await settle(); layout("r7_typeset_original_document"); check_ink(panel)
		game.investigations.cite(0,2); game.investigations.cite(1,2); game.investigations.compare_choice(0); game.investigations.choose_action(0)
		panel.show_page(); await settle(); layout("r7_typeset_sealed_fee_originals"); check_ink(panel)
		ready("before_night")
		for i: int in 3: game.investigations.place_time(i,i)
		panel.page = "relations"
		for i: int in 2:
			panel.relation_index = i; panel.show_page(); await settle(); layout("r7_relations")
		game.investigations.choose_relation(0,1); game.investigations.choose_relation(1,0); game.investigations.verify_time()
		panel.show_page(); await settle(); layout("r7_wrong_relations_feedback")
		game.investigations.choose_relation(0,0); game.investigations.choose_relation(1,1); game.investigations.verify_time(); game.investigations.seal_time(0)
		panel.show_page(); await settle(); layout("r7_typeset_three_sealed_originals"); check_ink(panel)
		ready("three_voices"); game.investigations.begin_pin_review()
		for i: int in 3:
			panel.page = "judgement"; panel.pin_index = i; panel.show_page(); await settle(); layout("r7_raw_record_same_screen")
			if i == 1:
				game.investigations.choose_pin(1,2); panel.show_page(); await settle(); layout("r7_single_side_rejected_feedback")
			var source_ink := JSON.stringify(panel.diagnostics().labels)
			check(source_ink.contains("索引原文") if i == 1 else source_ink.contains("原件記載") and source_ink.contains("記錄人") and source_ink.contains("未記發言"),"selected_raw_record_visible")
			check_ink(panel)
		var backdrop: ColorRect = panel.surface.find_child("OpaqueDossierBackdrop",true,false)
		check(backdrop.color.a == 1 and backdrop.get_global_rect() == root.get_visible_rect(),"modal_covers_all_underlying_hud")
	panel.close(); game.queue_free(); await settle()
	print("CONTENT_R7_CHECKS=%d FAILURES=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
