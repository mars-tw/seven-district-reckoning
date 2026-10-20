extends "content_r14.gd"
## R15: observable states, source review gates, bounded drag, honest hints.
func run() -> void:
	Engine.set_meta("seven_district_no_records",true)
	game = Main.new(); root.add_child(game)
	while not game.expansion_complete: await process_frame
	game.is_test_mode = true; game._new_game(); game.set_process(false); game.player.set_physics_process(false)
	var panel: CanvasLayer = game.investigation_panel
	for viewport: Vector2i in [Vector2i(390,844),Vector2i(320,568),Vector2i(844,390),Vector2i(1024,768)]:
		root.size = viewport; root.content_scale_size = viewport
		ready("second_help"); game.investigations.cite(0,2); game.investigations.cite(1,2); game.investigations.compare_choice(0)
		panel.show_page(); await settle(); layout("r15_review_locked")
		for b: Dictionary in panel.diagnostics().buttons:
			if b.text in game.investigations.definition().action_choices: check(b.disabled,"r15_actions_locked_before_review")
		press_text("展開原件 甲"); await settle(); press_text("收起原件，返回判定"); await settle()
		for b: Dictionary in panel.diagnostics().buttons:
			if b.text in game.investigations.definition().action_choices: check(b.disabled,"r15_one_review_insufficient")
		press_text("展開原件 乙"); await settle(); layout("r15_original_b")
		check(JSON.stringify(panel.diagnostics().labels).contains("備註："),"r15_original_note_visible")
		press_text("收起原件，返回判定"); await settle()
		for b: Dictionary in panel.diagnostics().buttons:
			if b.text in game.investigations.definition().action_choices: check(not b.disabled,"r15_both_reviews_enable_actions")
		game.investigations.choose_action(0); panel.show_page(); await settle(); persisted("r15_fee")
		ready("before_night")
		for i: int in 3: game.investigations.place_time(i,i)
		game.investigations.choose_relation(0,0); game.investigations.choose_relation(1,1); game.investigations.verify_time()
		for i: int in 3: game.investigations.reveal_time(i,3)
		panel.show_page(); await settle(); layout("r15_ready_to_drag")
		check(not JSON.stringify(panel.diagnostics().labels).contains("收據早於晚班"),"r15_no_inference_before_attachment")
		press_text("17：42\n點選拿起收據"); await settle(); layout("r15_picked_receipt")
		press_text("18：00\n拖到此處"); await settle(); check(not game.investigations.entry().complete,"r15_tap_cannot_complete")
		var touch := InputEventScreenTouch.new(); touch.pressed = true; touch.position = panel.attachment_receipt.get_global_rect().get_center(); panel._input(touch)
		var motion := InputEventScreenDrag.new(); motion.position = Vector2(15,20); panel._input(motion); await settle()
		var ghost: Rect2 = panel.drag_ghost.get_global_rect()
		check(ghost.size == Vector2(96,48) and panel.attachment_lane.get_global_rect().encloses(ghost),"r15_ghost_stays_in_dedicated_lane "+str(ghost)+str(panel.attachment_lane.get_global_rect()))
		for b: Dictionary in panel.diagnostics().labels:
			check(not ghost.intersects(Rect2(b.rect[0],b.rect[1],b.rect[2],b.rect[3])),"r15_drag_does_not_cover_labels")
		touch.position = motion.position; touch.pressed = false; panel._input(touch); await settle()
		check(panel.selected_document == -1 and panel.notice == "位置不對，收據已退回原位。","r15_return_clears_selection")
		check(JSON.stringify(panel.diagnostics().buttons).contains("已退回原位") and not JSON.stringify(panel.diagnostics().buttons).contains("已拿起"),"r15_return_wording_consistent")
		drag_attachment(); await settle(); layout("r15_attached"); persisted("r15_receipt")
		check(panel.surface.find_child("TapedReceipt",true,false) != null,"r15_actual_taped_receipt_visible")
		ready("three_voices"); game.investigations.begin_pin_review(); panel.pin_index = 0; panel.page = "judgement"; panel.show_page(); await settle(); layout("r15_candidates")
		var candidates: Array = panel.diagnostics().buttons.filter(func(b: Dictionary) -> bool: return b.text.begins_with("林秀蘭") or b.text.begins_with("陳奕廷") or b.text.begins_with("吳安琪"))
		check(candidates.size() == 3,"r15_three_claims")
		for b: Dictionary in candidates: check(not b.text.contains("反駁") and not b.text.contains("支持") and not b.text.contains("17：50") and not b.text.contains("18：10"),"r15_claims_without_assigned_answers")
		game.investigations.choose_pin(0,0); game.investigations.pin_record(0)
		check(game.investigations.pin_error(0) == "先看這筆在 18：00 哪一側，再核對『全部』。","r15_first_error_direction_only")
		game.investigations.unpin_record(0); game.investigations.choose_pin(0,0); game.investigations.pin_record(0)
		check(game.investigations.pin_error(0).begins_with("再看陳奕廷") and not game.investigations.pin_error(0).contains("應反駁"),"r15_second_error_question_not_solution")
		game.investigations.unpin_record(0); game.investigations.reference_support(0); game.investigations.reference_support(2)
		for i: int in 3: game.investigations.choose_pin(i,[1,2,0][i]); game.investigations.pin_record(i)
		game.investigations.seal_records(); panel.page = "chain"; panel.show_page(); await settle(); layout("r15_chain"); persisted("r15_voices")
		check(not FileAccess.get_file_as_string(Content.DATA).contains("三筆"),"r15_original_counts_consistent")
	panel.close(); game.queue_free(); await settle()
	print("CONTENT_R15_CHECKS=%d FAILURES=%d" % [checks,failures]); quit(0 if failures == 0 else 1)
