extends SceneTree
const Main = preload("res://scripts/main.gd")
const Content = preload("res://scripts/content/content_investigations.gd")
const Save = preload("res://scripts/save/save_manager.gd")
var checks := 0
var failures := 0
var game: Node3D
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("CONTENT_R5_FAIL "+message)
func settle() -> void:
	for i: int in 10: await process_frame
func layout(tag: String) -> void:
	var ui: Dictionary = game.investigation_panel.diagnostics()
	var bounds := root.get_visible_rect().grow(.5)
	var sheet: Control = game.investigation_panel.surface.find_child("CaseSheet",true,false)
	check(bounds.encloses(sheet.get_global_rect()),tag+" sheet_visible "+str(sheet.get_global_rect()))
	for b: Dictionary in ui.buttons+ui.labels:
		check(bounds.encloses(Rect2(b.rect[0],b.rect[1],b.rect[2],b.rect[3])),tag+" visible "+str(b.rect)+b.text)
	for i: int in ui.labels.size():
		var a: Array = ui.labels[i].rect
		for j: int in range(i+1,ui.labels.size()):
			var b: Array = ui.labels[j].rect
			check(not Rect2(a[0],a[1],a[2],a[3]).intersects(Rect2(b[0],b[1],b[2],b[3])),tag+" readable_labels "+ui.labels[i].text+" / "+ui.labels[j].text)
	for i: int in ui.buttons.size():
		var b: Dictionary = ui.buttons[i]
		check(b.rect[2] >= 44 and b.rect[3] >= 44,tag+" touch44")
		for j: int in range(i+1,ui.buttons.size()):
			var o: Array = ui.buttons[j].rect
			check(not Rect2(b.rect[0],b.rect[1],b.rect[2],b.rect[3]).intersects(Rect2(o[0],o[1],o[2],o[3])),tag+" distinct_targets")
func ready(id: String) -> void:
	game.investigations.reset(); game.investigation_panel.open_case(id)
	while game.investigations.pending() >= 0: game.investigations.collect(game.investigations.target_position())
	game.investigation_panel.page = "solve"; game.investigation_panel.show_page()
func run() -> void:
	var c := Content.new()
	c.start("second_help")
	check(not c.cite(0,2),"cannot_cite_uncollected")
	while c.pending() >= 0: c.collect(c.target_position())
	check(c.cite(0,1) and c.feedback.contains("案號"),"wrong_field_explained")
	check(c.cite(0,2) and c.cite(1,2),"paper_clauses_selectable")
	check(c.entry().viewed_fields["0"] == [1,2],"viewed_ink_trace_retained")
	check(Save.save_state({"schema":1,"investigations":c.to_dict()},96) == OK,"citation_disk_save")
	var copy := Content.new()
	check(copy.from_dict(Save.load_state(96).investigations) and copy.entry().citations == c.entry().citations,"citation_disk_reload")
	var bad := c.to_dict(); bad.records.second_help.citations["0"] = 99
	check(not copy.valid(bad),"reject_invalid_field")
	bad = c.to_dict(); bad.records.second_help.viewed_fields["0"] = [1,1]
	check(not copy.valid(bad),"reject_duplicate_viewed_field")
	c.reset(); c.start("three_voices")
	while c.pending() >= 0: c.collect(c.target_position())
	check(c.pin_record(0) and c.pin_record(1) and not c.entry().complete,"pins_do_not_invent_verdict")
	check(Save.save_state({"schema":1,"investigations":c.to_dict()},96) == OK,"pins_disk_save")
	check(copy.from_dict(Save.load_state(96).investigations) and copy.entry().pins == [0,1],"pins_disk_reload")
	bad = c.to_dict(); bad.records.three_voices.pins = [3]
	check(not copy.valid(bad),"reject_out_of_range_pin")
	for order_value: Array in [[0,1,2],[0,2,1],[1,0,2],[1,2,0],[2,0,1],[2,1,0]]:
		c.reset(); c.start("before_night")
		while c.pending() >= 0: c.collect(c.target_position())
		for i: int in order_value: check(c.place_time(i,2),"all_card_permutations_playable")
		check(c.entry().order == order_value and not c.entry().time_revealed,"random_order_stays_masked")
		for i: int in 3: c.place_time(i,i)
		c.choose_relation(0,0); c.choose_relation(1,1)
		check(c.verify_time() and not c.entry().complete,"arranging_does_not_seal")
		check(c.seal_time(0) and c.entry().complete,"attachment_bounded_result")
	Engine.set_meta("seven_district_no_records",true)
	game = Main.new(); root.add_child(game)
	var frames := 0
	while not game.expansion_complete and frames < 20000:
		await process_frame; frames += 1
	check(game.expansion_complete,"world_loaded")
	if not game.expansion_complete: quit(1); return
	game.is_test_mode = true; game._new_game(); game.set_process(false); game.player.set_physics_process(false)
	var panel: CanvasLayer = game.investigation_panel
	for size_value: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(430,932),Vector2i(568,320),Vector2i(844,390),Vector2i(1032,1376),Vector2i(1024,768),Vector2i(1366,600),Vector2i(1280,640)]:
		root.size = size_value; root.content_scale_size = size_value
		ready("second_help"); await settle(); layout("paper_blank "+str(size_value))
		for doc: int in 2:
			panel.document = doc; panel.show_page(); await settle()
			var ink: Button = panel.surface.find_child("CitedField2",true,false)
			var paper: Control = ink.get_parent().get_parent()
			check(paper.get_global_rect().encloses(ink.get_global_rect()),"ink_hit_target_inside_document")
			ink.pressed.emit(); await settle(); layout("paper_marked")
			check(game.investigations.entry().citations[str(doc)] == 2,"ink_marks_autosave")
		game.investigations.cite(0,2); game.investigations.cite(1,2)
		game.investigations.compare_choice(0); panel.show_page(); await settle(); layout("spread_before_seal")
		game.investigations.choose_action(0); panel.show_page(); await settle(); layout("spread_sealed")
		ready("before_night"); await settle(); layout("three_empty_slots")
		var card: Button = panel.timeline_cards[1]
		var touch := InputEventScreenTouch.new(); touch.pressed = true; touch.position = card.get_global_rect().get_center()
		panel._input(touch)
		for slot: int in 3:
			var drag := InputEventScreenDrag.new()
			var r: Rect2 = panel.drop_zone.get_global_rect()
			drag.position = Vector2(r.position.x+r.size.x*(slot+.5)/3,r.get_center().y)
			panel._input(drag); await settle()
			check(panel.rail.preview == slot,"exact_drop_slot_preview")
			check(card.modulate.a < .3 and is_instance_valid(panel.drag_ghost),"source_is_empty_while_one_ghost_moves")
			layout("drag_preview")
		touch.pressed = false; touch.position = panel.drop_zone.get_global_rect().get_center(); panel._input(touch); await settle()
		check(game.investigations.entry().order == [0],"drop_updates_order_without_confirmation")
		check(JSON.stringify(panel.diagnostics().labels).contains("目前：甲"),"live_order_immediate")
		for i: int in [2,0,1]: game.investigations.place_time(i,2)
		game.investigations.choose_relation(0,0); game.investigations.choose_relation(1,1)
		check(not game.investigations.verify_time(),"wrong_order_stays_open")
		panel.show_page(); await settle(); layout("wrong_order_recovery")
		for i: int in 3: game.investigations.place_time(i,i)
		game.investigations.choose_relation(0,0); game.investigations.choose_relation(1,1)
		game.investigations.verify_time(); panel.show_page(); await settle(); layout("attachment_before_pick")
		panel.selected_document = 0; panel.show_page(); await settle(); layout("attachment_before_place")
		ready("three_voices")
		for person: int in 3:
			panel.statement = person; panel.show_page(); await settle(); layout("record_focus")
			var strip: Control = panel.surface.find_child("RecordRibbon",true,false)
			check(strip.highlights == [[2],[0],[0,1,2]][person],"only_relevant_record_lit")
		panel.page = "pinning"; panel.show_page(); await settle(); layout("pinning")
		for i: int in 3: game.investigations.pair(i,2,1 if i < 2 else 0)
		panel.show_page(); await settle(); layout("record_sealed")
		for person: int in 3:
			panel.page = "fieldnote"; panel.document = person; game.investigations.entry().complete = false; panel.show_page(); await settle()
			check(game.hud.objective_text().contains(["林秀蘭","陳奕廷","吳安琪"][person]),"objective_matches_current_interview")
			layout("current_interview")
	panel.close(); game.queue_free(); await settle()
	print("CONTENT_R5_CHECKS=%d FAILURES=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
