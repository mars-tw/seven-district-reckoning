extends "content_r11.gd"
## R12: all three dossier headers, shared state semantics and actual mask objects.
func header12() -> Array:
	var ui: Dictionary = game.investigation_panel.diagnostics()
	var result: Array = [ui.paper_rect[1]]
	for l: Dictionary in ui.labels:
		if l.text == game.investigations.definition().title: result.append(l.rect[1])
	for b: Dictionary in ui.buttons:
		if b.text in ["證物","封存結論"]: result.append(b.rect[1])
	check(result.size() == 3,"r12_paper_title_tabs_present")
	return result

func run() -> void:
	Engine.set_meta("seven_district_no_records",true)
	game = Main.new(); root.add_child(game)
	var frames := 0
	while not game.expansion_complete and frames < 20000: await process_frame; frames += 1
	check(game.expansion_complete,"r12_world_loaded")
	game.is_test_mode = true; game._new_game(); game.set_process(false); game.player.set_physics_process(false)
	var panel: CanvasLayer = game.investigation_panel
	for size_value: Vector2i in [Vector2i(320,568),Vector2i(390,844)]:
		root.size = size_value; root.content_scale_size = size_value
		ready("second_help"); panel.page = "inspect"; panel.show_page(); await settle()
		var h := header12(); layout("r12_fee_inspect")
		game.investigations.cite(0,2); game.investigations.cite(1,2); game.investigations.compare_choice(0)
		panel.page = "solve"; panel.show_page(); await settle()
		check(h == header12(),"r12_fee_header_zero_delta")
		for wrong: int in [1,2]:
			press_text(game.investigations.definition().action_choices[wrong]); await settle(); layout("r12_fee_wrong")
			check(panel.diagnostics().buttons.filter(func(b: Dictionary) -> bool: return b.text.begins_with("你選的｜") and b.color == "c4271cff").size() == 1,"r12_fee_one_red_wrong")
		game.investigations.choose_action(0); panel.show_page(); await settle(); check(h == header12(),"r12_fee_sealed_header_zero_delta"); persisted("r12_fee")
		ready("before_night"); panel.show_page(); await settle(); h = header12()
		for i: int in 3: game.investigations.place_time(i,i)
		game.investigations.choose_relation(0,1); game.investigations.choose_relation(1,1)
		panel.page = "relations"; panel.show_page(); await settle(); layout("r12_receipt_wrong")
		check(h == header12(),"r12_receipt_relations_header_zero_delta")
		check(panel.diagnostics().buttons.any(func(b: Dictionary) -> bool: return b.text == "你選的｜交接摘要 → 車店收據" and b.color == "c4271cff"),"r12_direction_shared_wrong_style")
		game.investigations.choose_relation(0,0); game.investigations.verify_time()
		panel.reveal_count = 1; panel.reveal_clock = .4; panel.page = "solve"; panel.show_page(); await settle()
		check(is_instance_valid(panel.surface.find_child("VisibleTimeMask",true,false)),"r12_real_visible_mask")
		check(panel.diagnostics().buttons.any(func(b: Dictionary) -> bool: return b.text == "貼回收據｜揭時後開放" and b.disabled),"r12_attachment_locked_while_revealing")
		panel.reveal_count = 3; panel.show_page(); await settle(); press_text("17：42\n點選拿起收據"); await settle()
		check(is_instance_valid(panel.surface.find_child("AttachmentTarget",true,false)),"r12_amber_target_frame")
		for b: Dictionary in panel.diagnostics().buttons:
			if b.text.contains("右側"): check(b.rendered_text.contains("右側"),"r12_right_side_never_split")
		check(h == header12(),"r12_receipt_pickup_header_zero_delta"); layout("r12_picked"); check_ink(panel)
		press_text("18：00\n點此貼入"); await settle(); check(game.investigations.entry().complete,"r12_receipt_complete"); check(h == header12(),"r12_receipt_sealed_header_zero_delta"); persisted("r12_receipt")
		ready("three_voices"); game.investigations.begin_pin_review(); panel.pin_index = 1; panel.page = "judgement"; panel.show_page(); await settle(); h = header12()
		game.investigations.reference_support(0); panel.show_page(); await settle(); check(h == header12(),"r12_one_side_header_zero_delta")
		game.investigations.reference_support(2)
		for i: int in 3: game.investigations.choose_pin(i,[0,2,0][i]); game.investigations.pin_record(i)
		panel.page = "pinning"; panel.show_page(); await settle(); layout("r12_wrong_pin"); check(h == header12(),"r12_wrong_pin_header_zero_delta")
		var ink := "\n".join(panel.diagnostics().labels.map(func(l: Dictionary) -> String: return l.text))
		check(ink.contains("你選的｜") and ink.count("反駁林秀蘭") == 1 and ink.contains("18：10 在後"),"r12_distinct_pin_source_and_wrong_choice")
		game.investigations.unpin_record(0); check(game.investigations.entry().pins == [1,2],"r12_local_unpin_preserves_two")
		game.investigations.choose_pin(0,1); game.investigations.pin_record(0); game.investigations.seal_records()
		panel.page = "chain"; panel.show_page(); await settle(); layout("r12_voices_chain"); check(h == header12(),"r12_voices_sealed_header_zero_delta"); persisted("r12_voices")
		game.investigations.street_at_source = true
		game.hud.device_profile = "phone"; game.hud.set_target_distance(384); game.hud.update_status(100,"none",0,"", "已讀取進度")
		check(not game.hud._objective_label.text.contains("公尺"),"r12_npc_no_distance_leak")
		check(game.hud._prompt_label.text.begins_with("點互動｜") and game.hud._prompt_label.text.ends_with("｜交談"),"r12_street_prompt_not_load_notice")
	panel.close(); game.queue_free(); await settle()
	print("CONTENT_R12_CHECKS=%d FAILURES=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
