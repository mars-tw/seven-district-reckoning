extends "content_r7.gd"
## R8 guards check content semantics as well as the actual visible preview.
func run() -> void:
	var c := Content.new()
	c.start("second_help")
	while c.pending() >= 0: c.collect(c.target_position())
	var sizes: Array = c.definition().action_choices.map(func(t: String) -> int: return t.length())
	check(sizes.max()-sizes.min() <= 4,"equally_plausible_equal_length_actions")
	c.cite(0,2); c.cite(1,2); c.compare_choice(0)
	for wrong: int in [1,2]:
		check(not c.choose_action(wrong),"wrong_action_does_not_seal")
		check(c.feedback.contains("本案協助不收任何預付費。") and c.feedback.contains("本案須先付代辦費，才受理協助。"),"wrong_feedback_quotes_both_marked_originals")
	check(c.choose_action(0) and c.entry().history.size() == 3,"actions_and_wrong_feedback_retained")
	check(Save.save_state({"schema":1,"investigations":c.to_dict()},96) == OK,"r8_history_disk_save")
	var copy := Content.new()
	check(copy.from_dict(Save.load_state(96).investigations) and copy.records == c.records,"r8_history_exact_disk_roundtrip")
	var bad := c.to_dict(); bad.records.second_help.history = [1]
	check(not copy.valid(bad),"reject_malformed_history")
	bad = c.to_dict(); bad.records.second_help.history[0].choice = 999
	check(not copy.valid(bad),"reject_invalid_history_choice")
	Engine.set_meta("seven_district_no_records",true)
	game = Main.new(); root.add_child(game)
	var frames := 0
	while not game.expansion_complete and frames < 20000: await process_frame; frames += 1
	check(game.expansion_complete,"r8_world_loaded")
	game.is_test_mode = true; game._new_game(); game.set_process(false); game.player.set_physics_process(false)
	var panel: CanvasLayer = game.investigation_panel
	for size_value: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(568,320),Vector2i(844,390),Vector2i(1024,768),Vector2i(1366,600),Vector2i(1280,640),Vector2i(1032,1376)]:
		root.size = size_value; root.content_scale_size = size_value
		ready("second_help")
		game.investigations.cite(0,2); game.investigations.cite(1,2); game.investigations.compare_choice(0)
		game.investigations.choose_action(1); panel.show_page(); await settle(); layout("r8_quoted_action_error")
		game.investigations.choose_action(0)
		panel.show_page(); await settle(); layout("r8_archive_top")
		panel.page = "history"; panel.show_page(); await settle(); layout("r8_archive_history")
		check(JSON.stringify(panel.diagnostics().labels).contains("你當時的選擇"),"readonly_replay_includes_actual_decision")
		panel.page = "chain"; panel.show_page(); await settle(); layout("r8_archive_original_highlights")
		ready("before_night")
		for i: int in 3: game.investigations.place_time(i,i)
		panel.page = "relations"; panel.show_page(); await settle(); layout("r8_relations_empty")
		var reveal: Dictionary = panel.diagnostics().buttons.filter(func(b: Dictionary) -> bool: return b.text == "揭時核對")[0]
		check(reveal.disabled,"reveal_disabled_when_both_missing")
		game.investigations.choose_relation(0,0); panel.show_page(); await settle(); layout("r8_relations_one")
		check(panel.diagnostics().buttons.filter(func(b: Dictionary) -> bool: return b.text == "揭時核對")[0].disabled,"reveal_disabled_when_one_missing")
		game.investigations.choose_relation(1,1); panel.show_page(); await settle(); layout("r8_relations_both")
		check(not panel.diagnostics().buttons.filter(func(b: Dictionary) -> bool: return b.text == "揭時核對")[0].disabled,"reveal_enabled_when_both_chosen")
		panel.page = "solve"; panel.show_page(); await settle()
		for slot: int in 3:
			var source: Button = panel.timeline_cards.filter(func(b: Button) -> bool: return b.get_meta("card_index") == 0)[0]
			var touch := InputEventScreenTouch.new(); touch.pressed = true; touch.position = source.get_global_rect().get_center(); panel._input(touch)
			var drag := InputEventScreenDrag.new(); var zone: Rect2 = panel.drop_zone.get_global_rect()
			drag.position = Vector2(zone.position.x+zone.size.x*(slot+.5)/3,zone.position.y+zone.size.y*.8); panel._input(drag); await settle()
			var predicted: Array = game.investigations.entry().order.duplicate(); predicted.erase(0); predicted.insert(slot,0)
			check(panel.diagnostics().slot_order == predicted,"visible_slots_match_exact_insertion_preview")
			check(panel.drag_ghost.text.count("時間被遮蔽") == 1 and not panel.drag_ghost.text.contains("時間：〔遮蔽〕") and panel.drag_ghost.text.contains(game.investigations.definition().documents[0].event),"full_paper_ghost_keeps_quote_and_one_explicit_masked_time_label")
			check(panel.drag_lane.get_global_rect().encloses(panel.drag_ghost.get_global_rect()),"full_original_stays_inside_paper_safe_lane")
			check(not panel.drag_ghost.get_global_rect().intersects(zone),"full_original_does_not_cover_drop_slots")
			touch.pressed = false; touch.position = drag.position; panel._input(touch); await settle()
			check(game.investigations.entry().order == predicted,"actual_drop_equals_visible_preview")
		ready("three_voices"); game.investigations.begin_pin_review(); game.investigations.reference_support(0); game.investigations.reference_support(2)
		for doc: int in 3:
			panel.page = "inspect"; panel.document = doc; panel.show_page(); await settle(); layout("r8_testimony_original_names")
			check(not JSON.stringify(panel.diagnostics().labels).contains("甲") and not JSON.stringify(panel.diagnostics().labels).contains("乙") and not JSON.stringify(panel.diagnostics().labels).contains("丙"),"testimony_uses_same_names_in_landscape_magnifier")
		for i: int in 3: game.investigations.choose_pin(i,[0,2,0][i]); game.investigations.pin_record(i)
		panel.page = "pinning"; panel.show_page(); await settle(); layout("r8_wrong_pin_reason")
		check(not game.investigations.pin_error(0).is_empty() and game.investigations.pin_error(1).is_empty() and game.investigations.pin_error(2).is_empty(),"only_wrong_pin_flagged")
		game.investigations.unpin_record(0); game.investigations.choose_pin(0,1); game.investigations.pin_record(0)
		check(game.investigations.pins_correct() and game.investigations.entry().pins.size() == 3,"repair_preserves_other_two_pins")
	panel.close(); game.queue_free(); await settle()
	print("CONTENT_R8_CHECKS=%d FAILURES=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
