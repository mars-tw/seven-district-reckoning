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
		push_error("CONTENT_R1_FAIL "+message)
func settle() -> void:
	for i: int in 12: await process_frame
func capture_save(id: String) -> void:
	# Optional local capture artifact from actual collected world progress.
	# Never shipped and never used to assert gameplay completion.
	var directory := OS.get_environment("CONTENT_R1_CAPTURE_PATH")
	if directory.is_empty(): return
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join(id+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"data":game._snapshot(false)}))
func click(text: String) -> void:
	var found := false
	for b: Node in game.investigation_panel.surface.find_children("*","Button",true,false):
		if b.get_meta("original_text",b.text) == text and not b.disabled:
			b.pressed.emit()
			found = true
			break
	check(found,"reachable_action_"+text)
func layout(tag: String) -> void:
	var screen := Rect2(Vector2.ZERO,root.size)
	var buttons: Array[Rect2] = []
	for b: Node in game.investigation_panel.surface.find_children("*","Button",true,false):
		var r: Rect2 = b.get_global_rect()
		check(screen.grow(.5).encloses(r),"button_in_view_"+tag+"_"+b.text)
		check(r.size.y >= 44 and r.size.x >= 44,"touch_44_"+tag)
		for other: Rect2 in buttons: check(not r.intersects(other),"no_button_overlap_"+tag)
		buttons.append(r)
	for l: Node in game.investigation_panel.surface.find_children("*","Label",true,false):
		check(screen.grow(.5).encloses(l.get_global_rect()),"text_in_view_"+tag)
func run() -> void:
	var c := Content.new()
	var audit_progress := func() -> void: check(c.valid(c.to_dict()),"every_autosave_signal_exposes_valid_progress")
	c.changed.connect(audit_progress)
	check(c.definitions.size() == 3,"three_data_driven_cases")
	check(not c.start("missing"),"unknown_case_rejected")
	for spec: Dictionary in c.definitions:
		c.start(spec.id)
		check(not c.ready_to_solve(),"cannot_solve_without_field_documents")
		check(c.collect(Vector3(999,0,999)) == -1,"remote_collection_rejected")
		check(c.collect(c.target_position(),false) == -1,"must_dismount")
		while c.pending() >= 0:
			var index: int = c.pending()
			check(c.collect(c.target_position()) == index,"collect_one_original_at_actual_location")
			var copy := Content.new()
			check(copy.from_dict(JSON.parse_string(JSON.stringify(c.to_dict()))),"mid_case_json_roundtrip")
		check(c.ready_to_solve(),"complete_packet_available")
		if spec.mode == "contradiction":
			c.cite(0,2); c.cite(1,2)
			check(not c.compare_choice(1) and not c.compare_choice(2),"wrong_contradiction_retry")
			c.cite(0,2); c.cite(1,2)
			check(c.compare_choice(0) and c.entry().compared and not c.entry().complete,"same_case_contradiction_requires_action")
			check(c.choose_action(0) and c.entry().complete,"same_case_contradiction_sealed")
		elif spec.mode == "timeline":
			for perm: Array in [[0,2,1],[1,0,2],[1,2,0],[2,0,1],[2,1,0]]:
				c.entry().order = []
				for i: int in perm: c.add_time(i)
				c.choose_relation(0,0); c.choose_relation(1,1)
				check(not c.verify_time() and not c.entry().complete,"wrong_permutation_does_not_finish")
			c.entry().order = []
			check(c.add_time(2) and not c.add_time(2),"unique_time_card")
			c.undo_time()
			for i: int in 3: check(c.add_time(i),"time_card_clicked")
			c.choose_relation(0,0); c.choose_relation(1,1)
			check(c.verify_time() and not c.entry().complete,"earlier_receipt_requires_bounded_conclusion")
			check(c.seal_time(0),"earlier_receipt_overturns_first_impression")
		else:
			for person: int in 3:
				for doc: int in 3:
					for verdict: int in 2:
						if doc == spec.pair_documents[person] and verdict == spec.pair_verdicts[person]: continue
						if doc == 2 and person < 2 and verdict == 1: continue
						check(not c.pair(person,doc,verdict),"every_wrong_pair_retry")
				if person < 2:
					check(c.pair(person,2,1),"complete_index_is_a_valid_counterexample")
					check(Content.new().from_dict(JSON.parse_string(JSON.stringify(c.to_dict()))),"alternative_valid_pair_persists")
				check(c.pair(person,spec.pair_documents[person],spec.pair_verdicts[person]),"cross_evidence_pair")
		check(c.entry().complete,"case_has_bounded_conclusion")
	c.changed.disconnect(audit_progress)
	var before := c.to_dict()
	for broken: Dictionary in [{},{"schema":2},{"schema":1,"active":false,"records":{} }]:
		check(not c.from_dict(broken) and c.to_dict() == before,"malformed_preserves_state")
	for bad: Variant in [true,1.5,-1,99,NAN,"0"]:
		var malformed: Dictionary = before.duplicate(true)
		malformed.records.before_night.collected = [bad]
		check(not c.from_dict(malformed),"malformed_evidence_index_rejected")
	check(Save.save_state({"schema":1,"investigations":before},96) == OK,"atomic_content_save")
	check(Content.new().from_dict(Save.load_state(96).investigations),"actual_disk_json_load")
	Engine.set_meta("seven_district_no_records",true)
	game = Main.new()
	root.add_child(game)
	var frames := 0
	while not game.expansion_complete and frames < 20000:
		await process_frame
		frames += 1
	check(game.expansion_complete,"full_world_loaded_headlessly")
	if not game.expansion_complete: quit(1); return
	game.is_test_mode = true
	game._new_game()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.hud.show_pause()
	for b: Node in game.hud._modal_box.find_children("*","Button",true,false):
		if b.text == "查證": b.pressed.emit(); break
	var entry_found := false
	for b: Node in game.hud._modal_box.find_children("*","Button",true,false):
		if b.text == "街坊查證簿・三宗新案": b.pressed.emit(); entry_found = true; break
	check(entry_found and paused,"normal_pause_menu_entry")
	for spec: Dictionary in game.investigations.definitions:
		game.investigation_panel.open_case(spec.id)
		while game.investigations.pending() >= 0:
			game.investigation_panel.close()
			game.player.global_position = game.investigations.target_position()
			var n: int = game.investigations.entry().collected.size()
			game._interact()
			check(game.investigations.entry().collected.size() == n+1 and paused,"real_world_interact_opens_collected_document")
			check(Save.load_state(98).investigations.records[spec.id].collected.size() == n+1,"field_progress_autosaved")
		capture_save(spec.id)
		click("證物已齊，開始推論")
		if spec.mode == "contradiction":
			# Follow the redesigned paper ink targets; keep the wrong-answer gate.
			click("甲 原件"); click("案號：岸七"); click("乙 原件"); click("要求：本案須先付代辦費，才受理協助。")
			check(game.investigation_panel.surface.find_children("*","Button",true,false).any(func(b: Button) -> bool: return b.text == "核對兩處黃標" and b.disabled),"wrong_field_keeps_comparison_disabled")
			check(not game.investigations.entry().compared,"wrong_paper_field_cannot_advance")
			click("甲 原件"); click("承諾：本案協助不收任何預付費。"); click("核對兩處黃標")
			check(not game.investigations.entry().complete,"panel_requires_second_decision")
			click("暫停付款，留存甲乙兩份原件")
		elif spec.mode == "timeline":
			for text: String in ["丙 輪值資料","甲 車店收據","乙 交接摘要","核對關係","車店收據 → 交接摘要","乙與丙","交接摘要 → 輪值資料","揭時核對","回排序改排","撤回末張","撤回末張","撤回末張","甲 17：42","乙 17：55","丙 18：00","核對關係","車店收據 → 交接摘要","乙與丙","交接摘要 → 輪值資料","揭時核對","17：42\n點選拿起收據","18：00\n貼入收據 →"]:
				click(text)
				if text == "揭時核對" and game.investigations.entry().time_checked:
					check(game.investigation_panel.reveal_count == 0,"time_masks_begin_closed")
					await create_timer(2.7,true).timeout
					check(game.investigation_panel.reveal_count == 3,"all_three_masks_reveal_before_attachment")
		else:
			for i: int in 3:
				click(["末筆 陳奕廷\n18：10","首筆 林秀蘭\n17：50","索引 吳安琪"][i])
				click("支持這句" if i == 2 else "推翻這句")
				if i < 2: click("換一句 %d／3" % (i+1))
			for text: String in ["判定 17：50","反駁陳奕廷：\n全在後","釘上 17：50","判定 前後合看","引用 17：50","引用 18：10","支持吳安琪：\n前後都有","釘上 前後合看","判定 18：10","反駁林秀蘭：\n全在前","釘上 18：10","封存三筆判定"]: click(text)
		check(game.investigations.entry().complete,"actual_panel_completed_"+spec.id)
		check(Save.load_state(98).investigations.records[spec.id].complete,"completion_autosaved_"+spec.id)
	var saved: Dictionary = game._snapshot(false)
	check(game._restore(saved),"world_save_restores_content")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("investigations")
	check(game._restore(legacy) and game.investigations.records.second_help.collected.is_empty(),"legacy_world_save_supported")
	game._restore(saved)
	for size_value: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(844,390),Vector2i(568,320),Vector2i(768,1024),Vector2i(1024,768),Vector2i(1032,1376),Vector2i(1366,600),Vector2i(1280,640)]:
		root.size = size_value
		root.content_scale_size = size_value
		game.investigation_panel.open_hub()
		await settle()
		layout(str(size_value)+"hub")
		for spec: Dictionary in game.investigations.definitions:
			game.investigation_panel.open_case(spec.id)
			await settle()
			layout(str(size_value)+spec.id+"sealed")
			game.investigations.entry().complete = false
			var originals: Array = game.investigations.entry().collected.duplicate()
			for doc: int in spec.documents.size():
				game.investigation_panel.page = "evidence"
				game.investigation_panel.document = doc
				game.investigation_panel.show_page()
				await settle()
				layout(str(size_value)+spec.id+"document"+str(doc))
			game.investigations.entry().collected = []
			game.investigation_panel.document = 0
			game.investigation_panel.show_page()
			await settle()
			layout(str(size_value)+spec.id+"pending")
			game.investigations.entry().collected = originals
			game.investigation_panel.page = "solve"
			game.investigation_panel.show_page()
			await settle()
			layout(str(size_value)+spec.id+"solve")
			game.investigations.entry().complete = true
	game.investigation_panel.close()
	game.queue_free()
	await settle()
	print("CONTENT_R1_CHECKS=%d FAILURES=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
