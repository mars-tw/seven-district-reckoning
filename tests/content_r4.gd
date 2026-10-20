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
		push_error("CONTENT_R4_FAIL "+message)
func settle() -> void:
	for i: int in 8: await process_frame
func ui_check(tag: String) -> Dictionary:
	var ui: Dictionary = game.investigation_panel.diagnostics()
	var viewport := root.get_visible_rect()
	for b: Dictionary in ui.buttons+ui.labels:
		var r := Rect2(b.rect[0],b.rect[1],b.rect[2],b.rect[3])
		check(viewport.encloses(r),str(root.size)+tag+" within_viewport "+str(r)+" "+b.text)
	for i: int in ui.buttons.size():
		var b: Dictionary = ui.buttons[i]
		check(b.rect[2] >= 44 and b.rect[3] >= 44,tag+" touch44 "+b.text)
		var rect := Rect2(b.rect[0],b.rect[1],b.rect[2],b.rect[3])
		for j: int in range(i+1,ui.buttons.size()):
			var other: Array = ui.buttons[j].rect
			check(not rect.intersects(Rect2(other[0],other[1],other[2],other[3])),tag+" button_overlap")
	return ui
func masked(ui: Dictionary, tag: String) -> void:
	var text := JSON.stringify(ui.buttons)+JSON.stringify(ui.labels)
	for time: String in ["17：42","17：55","18：00","17:42","17:55","18:00"]:
		check(not text.contains(time),tag+" no_time_any_visible_text "+time)
func fixture(name_value: String) -> void:
	var directory := OS.get_environment("CONTENT_R4_CAPTURE_PATH")
	if directory.is_empty(): return
	DirAccess.make_dir_recursive_absolute(directory)
	var f := FileAccess.open(directory.path_join(name_value+".json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema":1,"data":game._snapshot(false)}))
func run() -> void:
	var c := Content.new()
	c.start("before_night")
	while c.pending() >= 0: c.collect(c.target_position())
	check(c.place_time(2,0) and c.place_time(0,0) and c.place_time(1,1),"drag_insert_and_reorder")
	check(c.entry().order == [0,1,2] and not c.entry().time_revealed,"drag_does_not_reveal")
	check(Save.save_state({"schema":1,"investigations":c.to_dict()},96) == OK,"drag_state_saved")
	var copy := Content.new()
	check(copy.from_dict(Save.load_state(96).investigations) and copy.entry().order == [0,1,2],"drag_disk_roundtrip")
	c.choose_relation(0,0); c.choose_relation(1,1)
	check(c.verify_time() and not c.entry().complete,"drag_verify_requires_conclusion")
	check(not c.seal_time(1) and c.seal_time(0),"drag_bounded_conclusion")
	Engine.set_meta("seven_district_no_records",true)
	game = Main.new(); root.add_child(game)
	var frames := 0
	while not game.expansion_complete and frames < 20000:
		await process_frame; frames += 1
	check(game.expansion_complete,"world_loaded")
	if not game.expansion_complete: quit(1); return
	game.is_test_mode = true; game._new_game(); game.set_process(false); game.player.set_physics_process(false)
	for spec: Dictionary in game.investigations.definitions:
		game.investigation_panel.open_case(spec.id)
		while game.investigations.pending() >= 0:
			var index: int = game.investigations.pending()
			game.investigation_panel.close()
			game.player.global_position = game.investigations.target_position()+Vector3(-2.0,-.08,-1.8)
			game.player.reset_view(PI+atan2(2.0,1.8)+.22)
			check(game.investigations.nearby(game.player.global_position),"fixture_on_foot_near_source")
			fixture(spec.id+"-field-"+str(index))
			game._interact()
			check(game.investigations.entry().collected.size() == index+1,"real_world_collection_"+spec.id)
		fixture(spec.id+"-ready")
		game.investigations.cite(0,2); game.investigations.cite(1,2)
		if spec.mode == "contradiction": game.investigations.compare_choice(0); game.investigations.choose_action(0)
		elif spec.mode == "timeline":
			for i: int in 3: game.investigations.place_time(i,i)
			game.investigations.choose_relation(0,0); game.investigations.choose_relation(1,1)
			game.investigations.verify_time(); game.investigations.seal_time(0)
		else:
			for i: int in 3: game.investigations.pair(i,2,1 if i < 2 else 0)
		check(game.investigations.entry().complete and Save.load_state(98).investigations.records[spec.id].complete,"world_completion_autosaved_"+spec.id)
	for actor: Dictionary in game.taiwan_world.actors:
		check(actor.node.has_node("PersonalSpace/CollisionShape3D"),"npc_has_real_collision")
	for size_value: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(430,932),Vector2i(568,320),Vector2i(844,390),Vector2i(1032,1376),Vector2i(1024,768),Vector2i(1366,600),Vector2i(1280,640)]:
		root.size = size_value; root.content_scale_size = size_value
		game.investigations.reset(); game.investigations.start("before_night")
		while game.investigations.pending() >= 0: game.investigations.collect(game.investigations.target_position())
		game.investigation_panel.open_case("before_night"); game.investigation_panel.page = "solve"; game.investigation_panel.show_page(); await settle()
		masked(ui_check(str(size_value)+" unsorted"),"unsorted")
		for i: int in 3:
			game.investigations.place_time(i,i); game.investigation_panel.show_page(); await settle()
			masked(ui_check("sorting"),"sorting")
		for i: int in 3:
			game.investigation_panel.page = "inspect"; game.investigation_panel.document = i; game.investigation_panel.show_page(); await settle()
			masked(ui_check("magnified"),"magnified")
			game.investigation_panel.page = "evidence"; game.investigation_panel.show_page(); await settle()
			masked(ui_check("original"),"original")
		game.investigations.choose_relation(0,0); game.investigations.choose_relation(1,1)
		game.investigations.verify_time()
		for i: int in 3: game.investigations.reveal_time(i,3)
		game.investigation_panel.page = "solve"; game.investigation_panel.show_page(); await settle()
		check(JSON.stringify(ui_check("revealed").buttons).contains("17：42"),"confirmation_reveals_time")
		game.investigations.start("second_help")
		while game.investigations.pending() >= 0: game.investigations.collect(game.investigations.target_position())
		game.investigation_panel.open_case("second_help"); game.investigation_panel.page = "solve"; game.investigation_panel.show_page(); await settle()
		var ui := ui_check("comparison_summary")
		var text := JSON.stringify(ui.labels)
		check(text.contains("已留存甲 服務承諾") and text.contains("已留存乙 同案補充通知"),"same_summary_every_viewport")
		for i: int in 2:
			game.investigation_panel.page = "inspect"; game.investigation_panel.document = i; game.investigation_panel.show_page(); await settle()
			var field_button: Button = game.investigation_panel.surface.find_child("CitedField2",true,false)
			field_button.pressed.emit(); await settle(); ui_check("cited_original")
		for b: Button in game.investigation_panel.surface.find_children("*","Button",true,false):
			if b.text == "核對兩處黃標": b.pressed.emit(); break
		await settle()
		check(game.investigations.entry().compared and not game.investigations.entry().complete,"body_field_comparison_advances_only_first_layer")
		check(Save.load_state(98).investigations.records.second_help.compared,"body_field_comparison_autosaved")
	game.investigation_panel.close(); game.queue_free(); await settle()
	print("CONTENT_R4_CHECKS=%d FAILURES=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
