extends SceneTree
const Main = preload("res://scripts/main.gd")
const Case = preload("res://scripts/content/fraud_case.gd")
var checks := 0
var failures := 0
var game: Node3D

func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("R3_FAIL "+label)

func click(text: String) -> void:
	var found := false
	for b: Node in game.hud._root.find_children("*","Button",true,false):
		if b.is_visible_in_tree() and b.text == text:
			b.pressed.emit()
			found = true
			break
	check(found,"button_"+text)

func run() -> void:
	var c := Case.new()
	check(not c.link_proof(0) and not c.conclude(0),"no_remote_completion_before_evidence")
	check(not c.meet_witness(),"message_must_be_preserved_first")
	check(c.preserve_message() and not c.preserve_message(),"message_exactly_once")
	check(c.meet_witness() and not c.meet_witness(),"witness_exactly_once")
	check(not c.select_claim(-1) and not c.select_claim(3),"invalid_claim_rejected")
	for claim: int in 3:
		for proof: int in 3:
			if claim == 0 and proof == 0: continue
			c.select_claim(claim)
			check(not c.link_proof(proof) and c.stage == 2,"wrong_pair_retry_%d_%d" % [claim,proof])
	c.select_claim(0)
	check(c.link_proof(0) and c.stage == 3,"evidence_pair_is_required")
	check(not c.conclude(1) and not c.conclude(2) and c.stage == 3,"unsupported_inference_cannot_finish")
	check(c.conclude(0) and not c.conclude(0) and c.stage == 4,"grounded_conclusion_once")
	for invalid in [{},{"schema":1,"stage":true},{"schema":1,"stage":1.5},{"schema":1,"stage":-1},{"schema":1,"stage":5},{"schema":1,"stage":NAN},{"schema":2,"stage":4}]:
		check(not c.from_dict(invalid) and c.stage == 4,"malformed_case_preserves_state")
	Engine.set_meta("seven_district_no_records",true)
	game = Main.new()
	root.add_child(game)
	var frames := 0
	while not game.expansion_complete and frames < 15000:
		await process_frame
		frames += 1
	check(game.startup_complete and game.expansion_complete,"native_startup_condition_not_two_frames")
	if not game.expansion_complete:
		quit(1)
		return
	game.is_test_mode = true
	game.hud.story_start_requested.emit()
	check(game.play_started,"cold_title_starts_real_campaign")
	game._on_story_finished(true) # Same callback as the real SkipIntro button.
	check(game.fraud_case.stage == 1 and not paused,"intro_preserves_message_and_returns_to_world")
	game.hud.show_pause()
	click("反詐案卷")
	check(game.hud.get_menu_mode() == "case" and paused,"signature_case_accessible_immediately")
	click("收起案卷，去找美晴")
	check(not paused,"tutorial_returns_to_walkable_world")
	game._update_interaction()
	game._interact()
	check(game.fraud_case.stage == 1 and game.missions.current_objective == 0,"remote_witness_and_main_objective_rejected")
	game.device_profiles.set_profile("phone",false)
	# Exercise the actual native joystick and real player physics, not a mock.
	var controls = game.touch_controls
	var start: Vector3 = game.player.position
	var press := InputEventScreenTouch.new()
	press.index = 42
	press.pressed = true
	press.position = controls.joystick_origin
	controls._input(press)
	var drag := InputEventScreenDrag.new()
	drag.index = 42
	drag.position = press.position+Vector2(48,0)
	controls._input(drag)
	for frame: int in 15: await physics_frame
	check(game.player.position.distance_to(start) > .2,"native_touch_moves_real_character")
	controls.notification(NOTIFICATION_APPLICATION_PAUSED)
	check(not Input.is_action_pressed("move_right"),"background_releases_touch")
	controls.notification(NOTIFICATION_APPLICATION_RESUMED)
	check(game.play_started and not paused,"background_resume_keeps_campaign")
	controls.release_all()
	game.player.position = game.targets["mei"]+Vector3(0,.2,-1.8)
	game.player.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	game._update_interaction()
	check(game.nearest != null and game.nearest.get("object_id") == "mei","real_desk_is_in_interaction_range")
	game._interact()
	check(game.fraud_case.stage == 2 and game.hud.get_menu_mode() == "case","physical_witness_unlocks_second_source")
	check(game.missions.current_objective > 0,"first_main_objective_completed_by_same_interaction")
	var wallet: int = game.district_systems.credits
	click(Case.CLAIMS[0])
	game.hud._menu_back()
	check(game.hud.get_menu_mode() == "case" and game.fraud_case.selected_claim == -1,"back_can_change_selected_claim")
	click(Case.CLAIMS[1])
	click(Case.PROOFS[2])
	check(game.fraud_case.stage == 2,"real_wrong_pair_is_retryable")
	click(Case.CLAIMS[0])
	click(Case.PROOFS[0])
	click(Case.REASONS[1])
	check(game.fraud_case.stage == 3,"real_wrong_reason_does_not_complete")
	click(Case.REASONS[0])
	check(game.fraud_case.stage == 4 and game.district_systems.credits == wallet,"case_completes_without_money_duplication")
	click("回到街區，繼續斷鏈")
	controls._press_action("interact","r3-pause-release")
	check(Input.is_action_pressed("interact"),"pause_probe_starts_with_real_held_action")
	game.touch_controls.pause_requested.emit()
	check(not Input.is_action_pressed("interact"),"opening_menu_releases_input_in_same_call_without_waiting_for_frame")
	click("反詐案卷")
	check(paused and game.fraud_case.stage == 4,"completed_case_is_readable_from_pause")
	game.hud._menu_back()
	check(game.hud.get_menu_mode() == "pause","case_returns_to_pause_without_dead_end")
	game.hud.resume_requested.emit()
	check(not paused,"pause_can_resume")
	await layouts()
	var snapshot: Dictionary = game._snapshot()
	var bad: Dictionary = snapshot.duplicate(true)
	bad["fraud_case"] = {"schema":1,"stage":6}
	check(not game._valid_world_save(bad) and not game._restore(bad) and game.fraud_case.stage == 4,"bad_case_rejected_before_world_mutation")
	bad.erase("fraud_case")
	check(game._valid_world_save(bad),"older_campaigns_remain_loadable")
	bad["missions"] = {}
	bad["fraud_case"] = {"schema":1,"stage":0}
	check(not game._restore(bad) and game.fraud_case.stage == 4,"invalid_campaign_cannot_roll_back_case_before_validation")
	game._resume()
	game._save(false)
	check(FileAccess.file_exists("user://save98.json"),"campaign_and_case_saved_for_next_os_process")
	game.queue_free()
	await process_frame
	await process_frame
	Engine.remove_meta("seven_district_no_records")
	print("R3_STORE_CHECKS=",checks," FAILURES=",failures)
	quit(0 if failures == 0 else 1)

func layouts() -> void:
	for dimensions: Vector2i in [Vector2i(320,568),Vector2i(568,320),Vector2i(375,667),Vector2i(667,375),Vector2i(430,932),Vector2i(932,430),Vector2i(440,956),Vector2i(956,440),Vector2i(768,1024),Vector2i(1024,768),Vector2i(1032,1376),Vector2i(1376,1032),Vector2i(1366,600),Vector2i(1280,640)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		game.device_profiles.set_profile("phone" if dimensions.x < 700 or dimensions.y < 500 else "tablet",false)
		for scenario: int in 8:
			var stage: int = mini(scenario,4)
			game.fraud_case.stage = stage
			game.fraud_case.selected_claim = -1
			game.fraud_case.feedback = ""
			if scenario == 5:
				game.fraud_case.stage = 2
				game.fraud_case.select_claim(0)
			elif scenario == 6:
				game.fraud_case.stage = 2
				game.fraud_case.select_claim(1)
				game.fraud_case.link_proof(2)
			elif scenario == 7:
				game.fraud_case.stage = 3
				game.fraud_case.conclude(1)
			game.hud.show_fraud_case()
			for f: int in 4: await process_frame
			var buttons: Array[Rect2] = []
			for b: Node in game.hud._root.find_children("*","Button",true,false):
				if not b.is_visible_in_tree(): continue
				var rect: Rect2 = b.get_global_rect()
				check(rect.size.y >= 44 and rect.size.x >= 44,"touch_target_%s_%d_%s" % [dimensions,stage,b.text])
				check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(rect),"button_inside_view_%s_%d_%s" % [dimensions,stage,b.text])
				if game.hud._modal_box.is_ancestor_of(b): check(game.hud._modal_scroll.get_global_rect().encloses(rect),"no_scroll_to_action_%s_%d_%s" % [dimensions,stage,b.text])
				for other: Rect2 in buttons: check(not other.intersects(rect),"buttons_do_not_overlap")
				buttons.append(rect)
	game.fraud_case.stage = 4
