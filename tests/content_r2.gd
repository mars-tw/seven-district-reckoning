extends SceneTree
const Content = preload("res://scripts/content/content_investigations.gd")
const Main = preload("res://scripts/main.gd")
const Save = preload("res://scripts/save/save_manager.gd")
var checks := 0
var failures := 0
var game: Node3D
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("CONTENT_R2_FAIL "+message)
func settle() -> void:
	for i: int in 10: await process_frame
func fixture(name_value: String) -> void:
	var directory := OS.get_environment("CONTENT_R2_CAPTURE_PATH")
	if directory.is_empty(): return
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join(name_value+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"data":game._snapshot(false)}))
func layout(tag: String) -> void:
	var bounds := Rect2(Vector2.ZERO,root.size)
	var rectangles: Array[Rect2] = []
	for b: Node in game.investigation_panel.surface.find_children("*","Button",true,false):
		var rect: Rect2 = b.get_global_rect()
		check(bounds.grow(.5).encloses(rect),"button_in_view_"+tag+"_"+b.text)
		check(rect.size.x >= 44 and rect.size.y >= 44,"touch44_"+tag)
		for other: Rect2 in rectangles: check(not rect.intersects(other),"no_overlap_"+tag)
		rectangles.append(rect)
	for l: Node in game.investigation_panel.surface.find_children("*","Label",true,false):
		check(bounds.grow(.5).encloses(l.get_global_rect()),"text_in_view_"+tag+"_"+l.text)
	var sheet: Control = game.investigation_panel.surface.find_child("CaseSheet",true,false)
	check(bounds.grow(.5).encloses(sheet.get_global_rect()),"content_sized_sheet_"+tag)
func run() -> void:
	var c := Content.new()
	c.changed.connect(func() -> void: check(c.valid(c.to_dict()),"every_autosave_is_valid"))
	var chronological := 0
	for attempt: int in 10:
		c.reset(); c.start("before_night")
		if c.time_cards() == [0,1,2]: chronological += 1
		check(c.time_cards() == [2,0,1],"new_open_uses_unsorted_sources_"+str(attempt))
		check(c.time_cards().size() == 3,"three_cards_retained")
	check(chronological < 8 and chronological == 0,"ten_new_opens_never_give_left_to_right_solution")
	c.reset(); c.start("second_help")
	check(not c.choose_action(0),"action_cannot_skip_field_or_comparison")
	while c.pending() >= 0: c.collect(c.target_position())
	check(not c.choose_action(0),"action_cannot_skip_comparison")
	for wrong: int in [-1,1,2,3]: check(not c.compare_choice(wrong),"wrong_comparison_cannot_progress")
	c.cite(0,2); c.cite(1,2)
	check(c.compare_choice(0) and c.entry().compared and not c.entry().complete,"first_layer_does_not_seal")
	check(Save.save_state({"schema":1,"investigations":c.to_dict()},96) == OK,"first_layer_atomic_disk_save")
	var resumed := Content.new()
	check(resumed.from_dict(Save.load_state(96).investigations) and resumed.entry().compared and not resumed.entry().complete,"first_layer_disk_reload")
	for wrong: int in [-1,1,2,3]: check(not resumed.choose_action(wrong) and not resumed.entry().complete,"unsafe_action_retry")
	check(resumed.choose_action(0) and resumed.entry().complete,"second_layer_seals")
	var legacy: Dictionary = resumed.to_dict()
	for record: Dictionary in legacy.records.values(): record.erase("compared")
	check(c.from_dict(legacy) and c.entry().compared,"r1_completed_save_compatibility")
	var malformed: Dictionary = c.to_dict()
	malformed.records.second_help.compared = false
	check(not c.from_dict(malformed),"completed_without_first_layer_rejected")
	Engine.set_meta("seven_district_no_records",true)
	game = Main.new(); root.add_child(game)
	var frames := 0
	while not game.expansion_complete and frames < 20000:
		await process_frame; frames += 1
	check(game.expansion_complete,"world_loaded")
	if not game.expansion_complete: quit(1); return
	game.is_test_mode = true; game._new_game(); game.set_process(false); game.player.set_physics_process(false)
	fixture("new-game")
	for spec: Dictionary in game.investigations.definitions:
		game.investigation_panel.open_case(spec.id)
		while game.investigations.pending() >= 0:
			var index: int = game.investigations.pending()
			game.investigation_panel.close()
			game.player.global_position = game.investigations.target_position()+Vector3(-1.7,-.08,-2.15)
			game.player.reset_view(PI+atan2(1.7,2.15))
			check(game.investigations.nearby(game.player.global_position),"field_fixture_within_real_interaction_range")
			check(game._restore(game._snapshot(false)) and game.investigations.nearby(game.player.global_position),"normal_reload_keeps_field_source_reachable")
			fixture(spec.id+"-field-"+str(index))
			game._interact()
			check(game.investigations.entry().collected.size() == index+1,"world_interaction_collects_one_original")
			check(Save.load_state(98).investigations.records[spec.id].collected.size() == index+1,"field_autosave")
		fixture(spec.id+"-ready")
		if spec.mode == "contradiction":
			game.investigations.cite(0,2); game.investigations.cite(1,2)
			game.investigations.compare_choice(0)
			fixture("second_help-action")
			game.investigations.choose_action(0)
		elif spec.mode == "timeline":
			for i: int in 3: game.investigations.add_time(i)
			game.investigations.choose_relation(0,0); game.investigations.choose_relation(1,1)
			game.investigations.verify_time(); game.investigations.seal_time(0)
		else:
			for i: int in 3: game.investigations.pair(i,2,1 if i < 2 else 0)
		check(game.investigations.entry().complete,"case_completed_"+spec.id)
	var completed: Dictionary = game.investigations.to_dict()
	for size_value: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(430,932),Vector2i(844,390),Vector2i(568,320),Vector2i(768,1024),Vector2i(1024,768),Vector2i(1032,1376),Vector2i(1366,600),Vector2i(1280,640)]:
		root.size = size_value; root.content_scale_size = size_value
		for spec: Dictionary in game.investigations.definitions:
			game.investigations.from_dict(completed)
			game.investigation_panel.open_case(spec.id)
			await settle(); layout(str(size_value)+spec.id+"-sealed")
			game.investigations.entry().complete = false
			game.investigation_panel.page = "solve"
			game.investigation_panel.show_page(); await settle(); layout(str(size_value)+spec.id+"-solve")
			if spec.mode == "contradiction":
				game.investigations.entry().compared = false
				game.investigations.compare_choice(1)
				game.investigation_panel.show_page(); await settle(); layout(str(size_value)+"-comparison-retry")
				game.investigations.cite(0,2); game.investigations.cite(1,2)
				game.investigations.compare_choice(0); game.investigations.choose_action(1)
				game.investigation_panel.show_page(); await settle(); layout(str(size_value)+"-action-retry")
			elif spec.mode == "timeline":
				game.investigations.entry().order = [2,0,1]
				game.investigations.choose_relation(0,0); game.investigations.choose_relation(1,1)
				check(not game.investigations.verify_time(),"wrong_timeline_stays_open")
				game.investigation_panel.show_page(); await settle(); layout(str(size_value)+"-timeline-error")
				game.investigations.undo_time()
				game.investigation_panel.show_page(); await settle(); layout(str(size_value)+"-timeline-undo")
	# Replace the packet in memory; UI facts and both answer indices must follow it.
	var variant := Content.new()
	var definition: Dictionary = variant.definition("second_help")
	definition.reference = "VARIANT_REFERENCE"
	definition.short_question = "VARIANT_QUESTION"
	definition.compact_comparison = "VARIANT_COMPACT"
	definition.seal_comparison = "VARIANT_SEAL"
	definition.choices = ["DECOY_A","DECOY_B","VARIANT_COMPARE"]
	definition.answer = 2
	definition.action_choices = ["DECOY_C","DECOY_D","VARIANT_SAFE_ACTION"]
	definition.action_answer = 2
	variant.start("second_help")
	while variant.pending() >= 0: variant.collect(variant.target_position())
	game.investigation_panel.manager = variant
	root.size = Vector2i(390,844); root.content_scale_size = root.size
	game.investigation_panel.open_case("second_help"); game.investigation_panel.page = "solve"
	game.investigation_panel.show_page(); await settle()
	var texts := JSON.stringify(game.investigation_panel.diagnostics().labels)
	check(texts.contains("VARIANT_REFERENCE") and texts.contains("VARIANT_QUESTION"),"replacement_json_controls_reference_and_question")
	variant.cite(0,2); variant.cite(1,2)
	check(not variant.compare_choice(0) and variant.compare_choice(2),"replacement_comparison_answer_is_respected")
	check(not variant.choose_action(0) and variant.choose_action(2),"replacement_action_answer_is_respected")
	game.investigation_panel.show_page(); await settle()
	texts = JSON.stringify(game.investigation_panel.diagnostics().labels)
	check(texts.contains("VARIANT_SEAL") and texts.contains("VARIANT_SAFE_ACTION"),"sealed_facts_follow_replacement_packet")
	check(not texts.contains("岸七") and not texts.contains("不收預付費"),"no_stale_case_facts_in_replacement_seal")
	variant.entry().complete = false; variant.entry().compared = false
	root.size = Vector2i(568,320); root.content_scale_size = root.size
	game.investigation_panel.show_page(); await settle()
	check(JSON.stringify(game.investigation_panel.diagnostics().labels).contains("VARIANT_COMPACT"),"compact_facts_follow_replacement_packet")
	game.investigation_panel.close(); game.queue_free(); await settle()
	print("CONTENT_R2_CHECKS=%d FAILURES=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
