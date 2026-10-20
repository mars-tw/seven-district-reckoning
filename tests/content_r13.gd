extends "content_r12.gd"
## Input-driven cover, safe save migration and small-phone layout contracts.
func run() -> void:
	Engine.set_meta("seven_district_no_records",true)
	game = Main.new(); root.add_child(game)
	while not game.expansion_complete: await process_frame
	game.is_test_mode = true; game._new_game(); game.set_process(false); game.player.set_physics_process(false)
	var panel: CanvasLayer = game.investigation_panel
	for viewport: Vector2i in [Vector2i(390,844),Vector2i(320,568),Vector2i(844,390),Vector2i(1024,768)]:
		root.size = viewport; root.content_scale_size = viewport
		ready("before_night")
		for i: int in 3: game.investigations.place_time(i,i)
		game.investigations.choose_relation(0,0); game.investigations.choose_relation(1,1); game.investigations.verify_time()
		panel.page = "solve"; panel.show_page(); await settle()
		var mask: Control = panel.surface.find_child("VisibleTimeMask",true,false)
		check(is_instance_valid(mask),"r13_manual_cover_present")
		for i: int in 3:
			for step: int in [1,2,1,3]:
				var touch := InputEventScreenTouch.new(); touch.pressed = true; touch.position = Vector2(mask.size.x*(i+.1)/3,60); mask._cover_input(touch)
				var motion := InputEventScreenDrag.new(); motion.position = Vector2(mask.size.x*i/3+10+(mask.size.x/3-20)*step/3.0,60); mask._cover_input(motion)
				touch.pressed = false; mask._cover_input(touch)
				check(game.investigations.entry().reveal_steps[i] == step,"r13_drag_exact_detent")
				await create_timer(.1,true).timeout
				check(game.investigations.entry().reveal_steps[i] == step,"r13_release_freezes_cover")
				if not game.investigations.entry().reveal_steps == [3,3,3]:
					check(panel.diagnostics().buttons.any(func(b: Dictionary) -> bool: return b.text == "貼回收據｜揭時後開放" and b.disabled),"r13_partial_cannot_attach")
				persisted("r13_cover")
		await settle(); layout("r13_manual_reveal")
		press_text("17：42\n點選拿起收據"); await settle(); layout("r13_target_inset")
		var frame: Control = panel.surface.find_child("AttachmentTarget",true,false)
		var heading: Label = panel.surface.find_children("*","Label",true,false).filter(func(l: Label) -> bool: return l.get_meta("original_text",l.text).begins_with("丙｜輪值資料"))[0]
		check(heading.get_global_rect().position.x-frame.get_global_rect().position.x >= 4,"r13_frame_four_pixels_clear_of_heading")
		for ink: Dictionary in panel.diagnostics().buttons+panel.diagnostics().labels:
			for line: String in ink.rendered_text.split("\n"): check(not line.begins_with("｜"),"r13_no_leading_separator")
		press_text("18：00\n點此貼入"); await settle(); persisted("r13_receipt_complete")
		var ui: Dictionary = panel.diagnostics()
		check(ui.buttons.any(func(b: Dictionary) -> bool: return b.text == "封存結論" and b.current_tab),"r13_archive_has_current_tab")
		check(viewport.y-ui.paper_rect[1]-ui.paper_rect[3] <= viewport.y*.05,"r13_black_bottom_under_five_percent")
		ready("second_help"); game.investigations.compare_choice(0)
		check(not game.investigations.choose_action(0),"r13_guess_without_citations_cannot_seal")
		game.investigations.cite(0,2); game.investigations.cite(1,2); game.investigations.choose_action(1)
		panel.page = "solve"; panel.show_page(); await settle(); layout("r13_first_hint")
		check(not JSON.stringify(panel.diagnostics().labels).contains("最新補充未撤回甲，付款仍有矛盾"),"r13_first_hint_does_not_disclose_answer")
		var before: Dictionary = game.investigations.to_dict(); panel.open_original(1); await settle(); layout("r13_full_original")
		check(game.investigations.to_dict() == before,"r13_original_preserves_progress")
		press_text("收起原件，返回判定"); await settle()
		check(panel.page == "solve" and panel.diagnostics().buttons.any(func(b: Dictionary) -> bool: return b.text.begins_with("你選的｜")),"r13_return_keeps_wrong_frame")
		game.investigations.choose_action(2); panel.show_page(); await settle(); layout("r13_second_hint")
		check(JSON.stringify(panel.diagnostics().labels).contains("只留乙會失去甲"),"r13_second_attempt_has_full_comparison")
		game.investigations.choose_action(0); panel.show_page(); await settle(); persisted("r13_fee_complete")
		var sealed_sources: Array = panel.diagnostics().buttons.filter(func(b: Dictionary) -> bool: return b.text.begins_with("承諾：") or b.text.begins_with("要求："))
		check(sealed_sources.size() == 2 and sealed_sources.all(func(b: Dictionary) -> bool: return b.disabled),"r13_sealed_source_highlights_are_read_only")
		game.hud.update_survival(100,100,"18：00",true)
		if viewport.y > viewport.x:
			check(root.get_visible_rect().encloses(game.hud._stamina_caption.get_global_rect()) and game.hud._stamina_caption.visible,"r13_portrait_stamina_visible_inside_independent_hud")
		var saved_result: Dictionary = game.investigations.to_dict()
		var field: Node3D = game.get_node("InvestigationField")
		game.investigations.street_choice = 2; field._process(0)
		check(field.result_papers[0].get_node("OriginalInk").text.begins_with("乙要求"),"r13_latest_only_replay_labels_actual_retained_original")
		check(game.investigations.to_dict() == saved_result,"r13_replay_never_changes_archive")
		game.investigations.street_choice = 0; field._process(0)
		check(field.result_papers[0].get_node("OriginalInk").text.begins_with("甲承諾") and field.result_papers[1].get_node("OriginalInk").text.begins_with("乙要求"),"r13_actual_two_originals_restored_after_replay")
		ready("three_voices"); game.investigations.begin_pin_review(); panel.pin_index = 1; panel.page = "judgement"; panel.show_page(); await settle(); layout("r13_people_quotes")
		if viewport.y >= 400:
			var text := JSON.stringify(panel.diagnostics().buttons)
			for quote: String in ["七號簿上那兩筆，全在傍晚六點以前。","我記得七號簿那兩筆都在六點以後。","同一本簿，有六點以前，也有六點以後。"]: check(text.contains(quote),"r13_complete_quote_without_zoom")
			check(JSON.stringify(panel.diagnostics().labels).contains("分界，不是原件"),"r13_boundary_separate")
		game.investigations.choose_pin(0,0); game.investigations.pin_record(0)
		check(not panel.first_hint("pin",game.investigations.pin_error(0)).contains("應反駁"),"r13_first_pin_error_only_hint")
		var original_hint: String = game.investigations.entry().history[0].feedback
		game.investigations.unpin_record(0); game.investigations.choose_pin(0,0); game.investigations.pin_record(0)
		check(panel.first_hint("pin",game.investigations.pin_error(0)).contains("再看陳奕廷的原話"),"r13_second_pin_error_explains")
		check(game.investigations.entry().history[0].feedback == original_hint,"r13_first_pin_hint_preserved")
		ready("before_night"); game.investigations.choose_relation(0,1)
		check(not panel.first_hint("relation",game.investigations.relation_error(0)).contains("應為"),"r13_first_direction_error_only_hint")
		game.investigations.choose_relation(1,1); game.investigations.choose_relation(0,1)
		check(panel.first_hint("relation",game.investigations.relation_error(0)).contains("應為：車店收據 → 交接摘要"),"r13_second_direction_error_explains")
		game.investigations.choose_relation(0,0)
		check(game.investigations.entry().relations == {"0":0,"1":1},"r13_correct_link_retained")
	game.hud.show_message("已讀取存檔。")
	await create_timer(1.6,true).timeout
	game.hud._refresh_mission()
	check(game.hud._notice_label.text.is_empty(),"r13_expired_notice_never_resurrects")
	check(game.hud._stamina_caption.get_parent() != game.hud._objective_label.get_parent(),"r13_stamina_outside_dialogue_card")
	panel.close(); game.queue_free(); await settle()
	print("CONTENT_R13_CHECKS=%d FAILURES=%d" % [checks,failures]); quit(0 if failures == 0 else 1)
