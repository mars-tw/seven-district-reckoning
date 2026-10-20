extends "content_r10.gd"
## R11: selected errors, consistent pickup, honest index and stable dossier header.
func press_text(text: String) -> void:
	if text == "18：00\n點此貼入":
		drag_attachment()
		return
	var aliases := {"反駁林秀蘭：\n全在前":"林秀蘭｜七號簿上那兩筆，全在傍晚六點以前。","反駁陳奕廷：\n全在後":"陳奕廷｜我記得七號簿那兩筆都在六點以後。","支持吳安琪：\n前後都有":"吳安琪｜同一本簿，有六點以前，也有六點以後。"}
	if root.get_visible_rect().size.y >= 400: text = aliases.get(text,text)
	else: text = {"反駁林秀蘭：\n全在前":"林秀蘭：\n兩筆全在前","反駁陳奕廷：\n全在後":"陳奕廷：\n兩筆全在後","支持吳安琪：\n前後都有":"吳安琪：\n前後都有"}.get(text,text)
	var found := false
	for b: Button in game.investigation_panel.surface.find_children("*","Button",true,false):
		if b.get_meta("original_text",b.text) == text and not b.disabled:
			b.pressed.emit(); found = true; break
	check(found,"r11_reachable_"+text)

func drag_attachment(correct: bool = true) -> void:
	var panel: CanvasLayer = game.investigation_panel
	check(is_instance_valid(panel.attachment_receipt) and is_instance_valid(panel.attachment_target),"attachment_real_drag_targets")
	var touch := InputEventScreenTouch.new(); touch.pressed = true
	touch.position = panel.attachment_receipt.get_global_rect().get_center(); panel._input(touch)
	var motion := InputEventScreenDrag.new()
	motion.position = panel.attachment_target.get_global_rect().get_center() if correct else Vector2(10,20)
	panel._input(motion)
	check(panel.attachment_moved,"attachment_crosses_drag_threshold")
	touch.position = motion.position; touch.pressed = false; panel._input(touch)

func persisted(tag: String) -> void:
	var state: Dictionary = game.investigations.to_dict()
	check(Save.save_state({"schema":1,"investigations":state},96) == OK,tag+"_disk_saved")
	var copy := Content.new()
	check(copy.from_dict(Save.load_state(96).investigations) and copy.to_dict() == state,tag+"_exact_disk_roundtrip")

func header() -> Array:
	var ui: Dictionary = game.investigation_panel.diagnostics()
	var result: Array = []
	for l: Dictionary in ui.labels:
		if l.text == "晚班之前的收據": result.append(l.rect[1])
	for name_value: String in ["證物","推論","放大"]:
		for b: Dictionary in ui.buttons:
			if b.text == name_value: result.append(b.rect[1])
	check(result.size() == 4,"r11_title_and_three_tabs_visible")
	return result

func run() -> void:
	Engine.set_meta("seven_district_no_records",true)
	game = Main.new(); root.add_child(game)
	var frames := 0
	while not game.expansion_complete and frames < 20000: await process_frame; frames += 1
	check(game.expansion_complete,"r11_world_loaded")
	game.is_test_mode = true; game._new_game(); game.set_process(false); game.player.set_physics_process(false)
	var panel: CanvasLayer = game.investigation_panel
	for size_value: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(430,932),Vector2i(568,320),Vector2i(844,390),Vector2i(1032,1376),Vector2i(1024,768),Vector2i(1366,600),Vector2i(1280,640)]:
		root.size = size_value; root.content_scale_size = size_value
		ready("second_help")
		game.investigations.cite(0,2); game.investigations.cite(1,2); game.investigations.compare_choice(0)
		panel.page = "solve"; panel.show_page(); await settle()
		press_text("展開原件 甲"); await settle(); press_text("收起原件，返回判定"); await settle()
		press_text("展開原件 乙"); await settle(); press_text("收起原件，返回判定"); await settle()
		for wrong: int in [1,2]:
			panel.page = "solve"; panel.show_page(); await settle()
			press_text(game.investigations.definition().action_choices[wrong]); await settle()
			layout("r11_wrong_action"); check_ink(panel)
			var chosen: Array = panel.diagnostics().buttons.filter(func(b: Dictionary) -> bool: return b.text.begins_with("你選的｜"))
			check(chosen.size() == 1 and chosen[0].text == "你選的｜"+game.investigations.definition().action_choices[wrong],"r11_only_actual_wrong_choice_marked")
			check(chosen.size() == 1 and chosen[0].color == "c4271cff","r11_error_choice_matches_red_feedback")
			persisted("r11_wrong_action")
			panel.show_page(); await settle()
			check(panel.diagnostics().buttons.any(func(b: Dictionary) -> bool: return b.text.begins_with("你選的｜")),"r11_selection_survives_redraw")
		press_text(game.investigations.definition().action_choices[0]); await settle()
		check(game.investigations.entry().complete,"r11_fee_completes"); persisted("r11_fee")
		ready("before_night"); panel.show_page(); await settle(); layout("r11_sort")
		var before_header: Array = header() if size_value.y >= 400 else []
		for i: int in 3: game.investigations.place_time(i,i)
		game.investigations.choose_relation(0,1); game.investigations.choose_relation(1,1)
		panel.page = "relations"; panel.show_page(); await settle(); layout("r11_wrong_relations"); check_ink(panel)
		if size_value.y >= 400:
			var relation_header := header()
			check(relation_header == before_header,"r11_step_1_2_header_exactly_aligned")
		game.investigations.choose_relation(0,0); check(game.investigations.verify_time(),"r11_reveal_after_repair")
		for i: int in 3: game.investigations.reveal_time(i,3)
		panel.page = "solve"; panel.show_page(); await settle(); layout("r11_before_pickup")
		if size_value.y >= 400: check(header() == before_header,"r11_step_1_3_header_exactly_aligned")
		press_text("17：42\n點選拿起收據"); await settle(); layout("r11_after_pickup"); check_ink(panel)
		var text := JSON.stringify(panel.diagnostics().buttons+panel.diagnostics().labels)
		check(text.contains("已備妥・按住拖曳") and not text.contains("點選拿起收據") and not game.investigations.entry().complete,"r11_pickup_state_consistent_and_unsealed")
		press_text("18：00\n點此貼入"); await settle()
		check(game.investigations.entry().complete,"r11_attachment_completes"); persisted("r11_receipt")
		ready("three_voices"); game.investigations.begin_pin_review()
		panel.pin_index = 1; panel.page = "judgement"; panel.show_page(); await settle(); layout("r11_index"); check_ink(panel)
		text = JSON.stringify(panel.diagnostics().labels)
		check(text.contains("吳安琪提供，只供定位") and (text.contains("分界：18：00（非原件）") if size_value.y < 400 else text.contains("18：00  ┄ 分界，不是原件 ┄") and panel.surface.find_child("JudgementTimeAxis",true,false) != null),"r11_index_explicit_boundary_and_provider")
		var doc: Dictionary = game.investigations.definition().documents[2]
		check(doc.text.contains("不能代替原件作證") and not JSON.stringify(doc).contains("中筆"),"r11_all_index_surfaces_agree")
		game.investigations.reference_support(0)
		check(not game.investigations.choose_pin(1,2),"r11_one_side_still_insufficient")
		game.investigations.reference_support(2)
		for i: int in 3: game.investigations.choose_pin(i,[1,2,0][i]); game.investigations.pin_record(i)
		game.investigations.unpin_record(0)
		check(game.investigations.entry().pins == [1,2],"r11_local_unpin_keeps_other_two")
		game.investigations.choose_pin(0,1); game.investigations.pin_record(0)
		check(game.investigations.seal_records(),"r11_voices_completes"); persisted("r11_voices")
		panel.page = "chain"; panel.show_page(); await settle(); layout("r11_sealed_chain"); check_ink(panel)
	panel.close(); game.queue_free(); await settle()
	print("CONTENT_R11_CHECKS=%d FAILURES=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
