extends "content_r5.gd"
## Extra R6 checks supplement all retained R5 layout/drag/save assertions.
func run() -> void:
	var c := Content.new()
	c.start("second_help")
	while c.pending() >= 0: c.collect(c.target_position())
	for doc: int in 2:
		check(c.definition().documents[doc].fields.size() >= 5,"two_non_fee_sentences_per_original")
		for field: int in [1,3,4]:
			check(c.cite(doc,field) and not c.entry().citations.has(str(doc)),"wrong_ink_leaves_only_view_trace")
		check(c.cite(doc,2) and c.entry().citations[str(doc)] == 2,"fee_clause_marks_paper")
		c.cite(doc,4)
		check(c.entry().citations[str(doc)] == 2,"wrong_view_does_not_replace_saved_highlight")
	c.cite(0,2); c.cite(1,2)
	check(c.compare_choice(0) and c.choose_action(0),"paper_case_completes")
	c.start("before_night")
	while c.pending() >= 0: c.collect(c.target_position())
	for i: int in 3: c.place_time(i,i)
	c.choose_relation(0,0); c.choose_relation(1,1)
	check(c.verify_time() and c.seal_time(0),"timeline_case_completes")
	c.start("three_voices")
	while c.pending() >= 0: c.collect(c.target_position())
	c.pair(0,1,1); c.pair(1,0,1); c.begin_pin_review()
	check(not c.pin_record(0) and not c.seal_records(),"must_choose_before_pin_and_seal")
	c.reference_support(0); c.reference_support(2)
	c.choose_pin(0,0); c.pin_record(0)
	check(not c.pins_correct() and not c.seal_records(),"wrong_judgment_cannot_seal")
	check(c.unpin_record(0) and not c.entry().pin_choices.has("0"),"unpin_allows_new_choice")
	for i: int in 3:
		c.reference_support(0); c.reference_support(2)
		check(c.choose_pin(i,[1,2,0][i]) and c.pin_record(i),"player_judges_each_record")
		check(c.valid(c.to_dict()),"mid_judgment_save_valid")
	check(not c.entry().complete and c.pins_correct(),"all_pins_still_require_explicit_seal")
	check(c.seal_records(),"player_judgments_seal")
	check(Save.save_state({"schema":1,"investigations":c.to_dict()},96) == OK,"three_cases_disk_save")
	var copy := Content.new()
	check(copy.from_dict(Save.load_state(96).investigations),"three_cases_disk_read")
	for id: String in c.records:
		check(copy.records[id] == c.records[id] and copy.records[id].complete,"archive_identical_after_reload_"+id)
	var bad := c.to_dict(); bad.records.three_voices.pin_choices["0"] = 0
	check(not copy.valid(bad),"sealed_wrong_judgment_rejected")
	bad = c.to_dict(); bad.records.three_voices.pin_choices["3"] = 1
	check(not copy.valid(bad),"unknown_pin_choice_rejected")
	bad = c.to_dict(); bad.records.three_voices.pins = 1
	check(not copy.valid(bad),"malformed_pin_list_rejected_without_exception")
	Engine.set_meta("seven_district_no_records",true)
	game = Main.new(); root.add_child(game)
	var frames := 0
	while not game.expansion_complete and frames < 20000: await process_frame; frames += 1
	check(game.expansion_complete,"world_ready")
	game.is_test_mode = true; game._new_game(); game.set_process(false); game.player.set_physics_process(false)
	var panel: CanvasLayer = game.investigation_panel
	for size_value: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(430,932),Vector2i(568,320),Vector2i(844,390),Vector2i(1032,1376),Vector2i(1024,768),Vector2i(1366,600),Vector2i(1280,640)]:
		root.size = size_value; root.content_scale_size = size_value
		ready("three_voices"); game.investigations.begin_pin_review()
		for index: int in 3:
			panel.pin_index = index; panel.page = "judgement"; panel.show_page(); await settle(); layout("choose_judgment")
			game.investigations.reference_support(0); game.investigations.reference_support(2)
			game.investigations.choose_pin(index,[1,2,0][index]); game.investigations.pin_record(index)
			panel.page = "pinning"; panel.show_page(); await settle(); layout("player_pinned")
		game.investigations.seal_records(); panel.show_page(); await settle(); layout("judgments_archive")
		ready("before_night")
		for index: int in 3: game.investigations.place_time(index,index)
		panel.show_page(); await settle(); layout("single_answer_area_full")
		check(panel.timeline_cards.size() == 3,"one_copy_of_each_original_after_placement")
		var starts: Array = []
		for card: Button in panel.timeline_cards: starts.append(card.get_global_rect().position)
		var touch := InputEventScreenTouch.new(); touch.pressed = true; touch.position = panel.timeline_cards[0].get_global_rect().get_center(); panel._input(touch)
		var previous := Vector2(-999,-999)
		for index: int in 3:
			var target: Rect2 = panel.drop_zone.get_global_rect()
			var drag := InputEventScreenDrag.new(); drag.position = Vector2(target.position.x+target.size.x*(index+.5)/3,target.position.y+target.size.y*.65)
			panel._input(drag); await settle()
			check(panel.drag_ghost.position.x > previous.x,"dragged_original_moves_with_each_touch")
			check(panel.rail.preview == index and panel.slot_labels[index].text.contains("放下後"),"filled_destination_explains_drop")
			previous = panel.drag_ghost.position
		var return_drag := InputEventScreenDrag.new()
		return_drag.position = touch.position+Vector2(1,0)
		panel._input(return_drag); await settle()
		# R10 replaces screen-edge clamping with a stricter paper-safe lane.
		var safe: Rect2 = panel.drag_lane.get_global_rect()
		var expected := Vector2(clampf(return_drag.position.x-panel.drag_ghost.size.x*.5,safe.position.x+8,safe.end.x-panel.drag_ghost.size.x-8),safe.position.y+4)
		check(panel.drag_ghost.position.distance_to(expected) < .5 and safe.encloses(panel.drag_ghost.get_global_rect()) and not panel.drag_ghost.get_global_rect().intersects(panel.drop_zone.get_global_rect()),"drag_keeps_following_inside_start_threshold_and_paper_safety")
		panel.show_page()
	panel.close(); game.queue_free(); await settle()
	print("CONTENT_R6_CHECKS=%d FAILURES=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
