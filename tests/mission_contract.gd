extends SceneTree
const Missions = preload("res://scripts/missions/mission_manager.gd")
const Save = preload("res://scripts/save/save_manager.gd")
const Hud = preload("res://scripts/ui/game_hud.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + description)

func send(m: Node, event: String, target: String) -> void:
	expect(m.handle_event(event, target), "accepted " + event + "/" + target)

func campaign_to_branch(m: Node) -> void:
	m.start_campaign()
	expect(not m.handle_event("practice_hit", "practice_1"), "ignore premature destruction")
	send(m, "talk_mei", "mei")
	send(m, "read_phone", "phone")
	send(m, "pickup_wrench", "wrench")
	send(m, "practice_hit", "practice_1")
	expect(not m.handle_event("practice_hit", "practice_1"), "unique tutorial target")
	send(m, "practice_hit", "practice_2")
	expect(m.scores.evidence_score == 5 and m.parts_vouchers == 100, "MAIN001 reward")
	expect(not m.handle_event("alternate_route", "guard_1"), "reject crossed event target pair")
	send(m, "collect_evidence", "summary")
	send(m, "defeat_guard", "guard_1")
	send(m, "defeat_guard", "guard_2")
	send(m, "disable_sign", "fake_sign")
	send(m, "collect_pass", "pass")
	expect(m.scores.evidence_score == 13, "optional summary committed once")
	expect(not m.handle_event("route_checkpoint", "route_2"), "reject route ahead of mount")
	send(m, "mount_bicycle", "bicycle")
	send(m, "route_checkpoint", "route_1")
	var before_retry: Dictionary = m.to_dict()
	expect(m.from_dict(before_retry), "mid-route snapshot restores")
	m.restart_current()
	expect(m.current_objective == 2 and m.get_target_key() == "route_2", "retry preserves road checkpoint")
	send(m, "route_checkpoint", "route_2")
	send(m, "route_checkpoint", "route_3")
	send(m, "return_shop", "mei_shop")
	send(m, "unlock_car", "car")
	expect(m.scores.evidence_score == 18, "MAIN003 evidence reward")
	expect(not m.handle_event("escort_safe", "rescue_A"), "escort requires released NPCs")
	send(m, "collect_evidence", "shift_note")
	send(m, "free_rescue", "rescue_A")
	send(m, "free_rescue", "rescue_B")
	send(m, "escort_safe", "rescue_A")
	expect(not m.handle_event("escort_safe", "rescue_A"), "one rescue per unique NPC")
	expect(m.scores.rescued_count == 1, "only safe arrival counts")
	var rescue_snapshot: Dictionary = m.to_dict()
	expect(m.from_dict(rescue_snapshot), "mid-escort snapshot restores")
	m.restart_current()
	expect(m.scores.rescued_count == 0 and m.current_objective == 0, "failed escort rolls back temporary rescue")
	send(m, "collect_evidence", "shift_note")
	send(m, "free_rescue", "rescue_A")
	send(m, "free_rescue", "rescue_B")
	send(m, "escort_safe", "rescue_A")
	send(m, "escort_safe", "rescue_B")
	expect(m.scores.rescued_count == 2 and m.scores.community_trust == 55 and m.scores.evidence_score == 26, "MAIN004 reward and retry do not duplicate")

func test_branch(choice: String) -> Dictionary:
	var m := Missions.new()
	root.add_child(m)
	campaign_to_branch(m)
	send(m, "select_branch", choice)
	var snapshot: Dictionary = m.to_dict()
	expect(m.from_dict(snapshot), "branch restore " + choice)
	if choice == "smash":
		for target: String in ["equipment_1", "equipment_2", "equipment_3"]:
			send(m, "destroy_target", target)
	elif choice == "evidence":
		send(m, "collect_evidence", "record_1")
		send(m, "collect_evidence", "record_2")
		send(m, "disable_console", "console")
	else:
		send(m, "escort_safe", "extra_A")
		send(m, "escort_safe", "extra_B")
		send(m, "disable_console", "console")
	send(m, "return_shop", "mei_shop")
	expect(m.chapter_complete and m.mission_index == 5, "first chapter completes " + choice)
	expect(m.parts_vouchers == 780 and m.scores.heat_level == 0, "one-time rewards and calm return " + choice)
	expect(m.scores.evidence_score == (46 if choice == "evidence" else 26), "branch evidence " + choice)
	expect(m.scores.community_trust == (63 if choice == "rescue" else 55), "branch trust " + choice)
	expect(m.scores.rescued_count == (4 if choice == "rescue" else 2), "branch rescue " + choice)
	expect(not m.handle_event("return_shop", "mei_shop"), "completed campaign rejects duplicate return")
	var completed: Dictionary = m.to_dict()
	expect(m.from_dict(completed), "complete snapshot restores " + choice)
	var bad: Dictionary = completed.duplicate(true)
	bad["scores"]["evidence_score"] = "broken"
	expect(not m.from_dict(bad) and m.to_dict() == completed, "invalid load preserves live state")
	m.queue_free()
	return completed

func test_fallback() -> void:
	var m := Missions.new()
	root.add_child(m)
	campaign_to_branch(m)
	send(m, "select_branch", "evidence")
	send(m, "collect_evidence", "record_1")
	send(m, "evidence_destroyed", "record_2")
	expect(m.branch == "smash" and m.get_target_key() == "equipment_1", "lost record selects playable fallback")
	expect(not m.handle_event("collect_evidence", "record_2"), "destroyed evidence cannot be collected")
	for target: String in ["equipment_1", "equipment_2", "equipment_3"]:
		send(m, "destroy_target", target)
	send(m, "return_shop", "mei_shop")
	expect(m.chapter_complete and m.scores.evidence_score == 26, "fallback completes without branch reward stacking")
	m.queue_free()

func test_save(payload: Dictionary) -> void:
	var paths: Array[String] = ["user://save96.json", "user://save96.json.bak", "user://save96.json.tmp"]
	for path: String in paths:
		if FileAccess.file_exists(path):
			expect(false, "test slot96 must be unused; fixture left intact")
			return
	var first := {"schema":1,"missions":payload,"world":{"fixture":"first"}}
	expect(Save.save_state(first, 96) == OK, "first tmp save")
	expect(Save.load_state(96) == JSON.parse_string(JSON.stringify(first)), "saved roundtrip")
	var second: Dictionary = first.duplicate(true)
	second["world"]["fixture"] = "second"
	expect(Save.save_state(second, 96) == OK, "replace existing save atomically")
	expect(Save.load_state(96) == JSON.parse_string(JSON.stringify(second)), "newest primary roundtrip")
	expect(FileAccess.file_exists(paths[1]), "previous primary backed up")
	var restored := Missions.new()
	root.add_child(restored)
	expect(restored.from_dict(Save.load_state(96)["missions"]), "JSON campaign data actually restores")
	expect(restored.chapter_complete and restored.scores.rescued_count == 4, "JSON campaign restores actual chapter and rescue count")
	restored.queue_free()
	var f := FileAccess.open(paths[0], FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	expect(Save.load_state(96) == JSON.parse_string(JSON.stringify(first)), "corrupt primary recovers previous backup")
	expect(FileAccess.get_file_as_string(paths[0]) == "{broken", "recovery leaves corrupt primary untouched")
	expect(Save.save_state(second, 96) == ERR_FILE_CORRUPT, "save refuses to erase corrupt primary")
	expect(FileAccess.get_file_as_string(paths[0]) == "{broken", "failed explicit save preserves original")
	expect(Save.save_state({"schema":2}, 96) == ERR_INVALID_DATA, "unsupported save schema rejected")
	for path: String in paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func test_hud() -> void:
	root.size = Vector2i(1366, 600)
	var m := Missions.new()
	root.add_child(m)
	m.start_campaign()
	var hud := Hud.new()
	root.add_child(hud)
	hud.bind_missions(m)
	hud.update_status(80.0, "扳手", 2, "自行車", "E　交談")
	hud.set_map_markers(Vector2(1,2), Vector2(20,-25))
	hud.show_title()
	await process_frame
	await process_frame
	expect(hud.is_menu_open() and hud.get_menu_mode() == "title", "title modal is active")
	expect(hud._modal_scroll.size.y <= 480, "600px-high modal scroll fits viewport")
	var buttons: Array[Node] = hud._root.find_children("*", "Button", true, false)
	for button: Button in buttons:
		expect(button.size.y >= 44, "button touch target is at least 44px")
	hud.show_pause()
	expect(paused, "pause modal pauses world")
	hud.show_phone()
	expect(hud.get_menu_mode() == "phone", "phone modal opens")
	hud.hide_menus()
	expect(not paused and not hud.is_menu_open(), "resume hides modal and unpauses world")
	hud.show_chapter_complete("smash")
	expect(hud.get_menu_mode() == "complete", "chapter preview modal opens")
	hud.hide_menus()
	hud.queue_free()
	m.queue_free()

func run() -> void:
	var payload: Dictionary = {}
	for branch: String in ["smash", "evidence", "rescue"]:
		payload = test_branch(branch)
	test_fallback()
	test_save(payload)
	await test_hud()
	print("ALPHA_CONTRACT_CHECKS=", checks, " FAILURES=", failures)
	quit(0 if failures == 0 else 1)