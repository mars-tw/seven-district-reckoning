extends SceneTree
const Content = preload("res://scripts/content/content_investigations.gd")
const Save = preload("res://scripts/save/save_manager.gd")
const Main = preload("res://scripts/main.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("CONTENT_R3_FAIL "+message)
func run() -> void:
	var c := Content.new()
	c.changed.connect(func() -> void: check(c.valid(c.to_dict()),"atomic_state_valid"))
	for order_value: Array in [[0,1,2],[0,2,1],[1,0,2],[1,2,0],[2,0,1],[2,1,0]]:
		c.reset(); c.start("before_night")
		while c.pending() >= 0: c.collect(c.target_position())
		for i: int in order_value: check(c.add_time(i),"card_playable")
		check(not c.entry().time_revealed and not c.entry().complete,"random_card_clicks_never_seal")
		check(not c.seal_time(0),"cannot_skip_reveal")
		var correct := order_value == [0,1,2]
		c.choose_relation(0,0); c.choose_relation(1,1)
		check(c.verify_time() == correct and c.entry().time_revealed and not c.entry().complete,"verify_reveals_never_seals")
		check(Save.save_state({"schema":1,"investigations":c.to_dict()},96) == OK,"revealed_state_saved")
		var copy := Content.new()
		check(copy.from_dict(Save.load_state(96).investigations) and copy.entry().time_revealed and not copy.entry().complete,"reveal_disk_roundtrip")
		if not correct:
			check(not c.seal_time(0),"bad_order_cannot_seal")
			for i: int in 3: c.undo_time()
			for i: int in 3: c.add_time(i)
			c.choose_relation(0,0); c.choose_relation(1,1)
			check(c.verify_time(),"wrong_order_undo_recovery")
		check(not c.seal_time(1) and not c.entry().complete and c.feedback.contains("甲"),"overclaim_rejected_with_source")
		check(c.seal_time(0) and c.entry().complete,"bounded_conclusion_seals")
		var old := c.to_dict()
		for record: Dictionary in old.records.values():
			record.erase("time_revealed"); record.erase("time_checked")
		check(copy.from_dict(old) and copy.entry().complete,"r2_completed_timeline_compatibility")
		var bad := c.to_dict()
		bad.records.before_night.time_revealed = false
		check(not copy.from_dict(bad),"checked_without_reveal_rejected")
	var choices: Array = c.definition("second_help").action_choices
	var lengths: Array = choices.map(func(text: String) -> int: return text.length())
	check(lengths.max() == lengths.min(),"actions_exactly_equal_length")
	for text: String in choices:
		check(not (text.contains("停止付款") and text.contains("保存") and text.contains("求助")),"no_answer_triple")
	c.reset(); c.start("second_help")
	while c.pending() >= 0: c.collect(c.target_position())
	c.cite(0,2); c.cite(1,2)
	c.compare_choice(0)
	for wrong: int in [1,2]:
		check(not c.choose_action(wrong) and c.feedback.contains("甲") and c.feedback.contains("乙"),"wrong_action_names_originals")
	Engine.set_meta("seven_district_no_records",true)
	var game := Main.new(); root.add_child(game)
	var frames := 0
	while not game.expansion_complete and frames < 20000:
		await process_frame; frames += 1
	check(game.expansion_complete,"real_world_loaded")
	game.is_test_mode = true; game._new_game()
	game.investigations.start("second_help")
	game.player.global_position = game.investigations.target_position()+Vector3(-1.7,-.08,-6)
	game.player.reset_view(PI+atan2(1.7,6.0))
	check(game._restore(game._snapshot(false)) and not game.investigations.nearby(game.player.global_position),"approach_fixture_starts_outside_collection")
	var directory := OS.get_environment("CONTENT_R3_CAPTURE_PATH")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		var file := FileAccess.open(directory.path_join("second_help-approach.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"schema":1,"data":game._snapshot(false)}))
	game.taiwan_world.set_investigation_focus(true)
	for actor: Dictionary in game.taiwan_world.actors:
		for child: Node in actor.node.get_children():
			if child is Label3D: check(not child.visible,"no_overlapping_npc_nameplate")
	game.investigations.start("before_night")
	while game.investigations.pending() >= 0: game.investigations.collect(game.investigations.target_position())
	root.size = Vector2i(320,568); root.content_scale_size = root.size
	game.investigation_panel.open_case("before_night"); game.investigation_panel.page = "solve"; game.investigation_panel.show_page()
	for i: int in 12: await process_frame
	var ui: Dictionary = game.investigation_panel.diagnostics()
	check(not JSON.stringify(ui.buttons).contains("17：42") and not JSON.stringify(ui.buttons).contains("18：00"),"unsorted_numbers_hidden")
	for i: int in 3: game.investigations.add_time(i)
	game.investigation_panel.show_page()
	for i: int in 12: await process_frame
	ui = game.investigation_panel.diagnostics()
	for word: String in ["這張收據供摘要引用","這張摘要附有收據","這張輪值資料沿用摘要"]:
		check(JSON.stringify(ui.labels).contains(word),"small_phone_all_event_rows_"+word)
	for time: String in ["17：42","17：55","18：00"]:
		check(not (JSON.stringify(ui.labels)+JSON.stringify(ui.buttons)).contains(time),"all_visible_text_masked_"+time)
	game.investigations.start("three_voices")
	while game.investigations.pending() >= 0: game.investigations.collect(game.investigations.target_position())
	for screen: Vector2i in [Vector2i(320,568),Vector2i(390,844)]:
		root.size = screen; root.content_scale_size = screen
		game.investigation_panel.open_case("three_voices"); game.investigation_panel.page = "solve"; game.investigation_panel.show_page()
		for i: int in 12: await process_frame
		for b: Node in game.investigation_panel.surface.find_children("*","Button",true,false):
			if not (b.text.begins_with("首筆 林秀蘭") or b.text.begins_with("末筆 陳奕廷")): continue
			var font: Font = b.get_theme_font("font")
			var style: StyleBox = b.get_theme_stylebox("normal")
			var lines: PackedStringArray = b.text.split("\n")
			check(lines.size() == 2 and lines[1] in ["17：50","18：10"],"explicit_complete_timestamp_line_"+str(screen))
			var token: String = lines[1]
			var width: float = font.get_string_size(token,HORIZONTAL_ALIGNMENT_LEFT,-1,b.get_theme_font_size("font_size")).x
			check(width <= b.size.x-style.content_margin_left-style.content_margin_right,"whole_timestamp_fits_button_"+str(screen))
	game.investigation_panel.close(); game.queue_free()
	for i: int in 10: await process_frame
	print("CONTENT_R3_CHECKS=%d FAILURES=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
