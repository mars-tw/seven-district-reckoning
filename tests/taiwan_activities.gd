extends SceneTree
const ActivitiesScript = preload("res://scripts/content/taiwan_activities.gd")
const PanelScript = preload("res://scripts/ui/taiwan_activity_panel.gd")
const HudScript = preload("res://scripts/ui/game_hud.gd")
var checks: int = 0
var failures: int = 0
var manager: Node
var hud: CanvasLayer
var panel: RefCounted
var input_calls: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: "+label)

func point(id: String) -> Vector3:
	var p: Array = manager.stations[id]["position"]
	return Vector3(float(p[0]),0.1,float(p[1]))

func start(id: String, vehicle: String = "any") -> bool:
	return manager.start(id,point(str(manager.activities[id]["station_id"])),vehicle)

func finish_beats(id: String, wrong_index: int = -1, wrong_foot: bool = false) -> void:
	var task: Dictionary = manager.activities[id]
	for i: int in range(8):
		var target: float = float(task["targets"][i])
		var action: String = "tap" if task["kind"]=="rhythm" else str(task["sequence"][i])
		if i==wrong_index:
			if wrong_foot:
				manager.advance_time(target)
				check(not manager.handle_input("right" if action=="left" else "left"),"wrong_foot_rejected_"+str(i))
			else:
				check(not manager.handle_input(action),"early_beat_rejected_"+str(i))
		else:
			manager.advance_time(target)
			check(manager.handle_input(action),"real_beat_"+id+str(i))
			var hits: int = manager.hits
			check(not manager.handle_input(action) and manager.hits==hits,"same_beat_repeat_no_score_"+str(i))
		manager.advance_time(float(task["period"])-manager.round_elapsed+.00001)
		check(manager.round_index==i+1,"round_progress_"+str(i))

func _button(caption: String) -> Button:
	for node: Node in hud.find_children("*","Button",true,false):
		if (node as Button).text==caption and (node as Button).is_visible_in_tree(): return node as Button
	return null

func _key(keycode: Key, echo_value: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.echo = echo_value
	root.push_input(event,true)

func _press(button: Button) -> void:
	if not button: check(false,"real_gui_button_exists"); return
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event,true)
	await process_frame
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.pressed = false
	root.push_input(event,true)
	await process_frame

func run() -> void:
	manager = ActivitiesScript.new()
	root.add_child(manager)
	check(manager.load_definition() and manager.activities.size()==4,"four_real_activity_definitions")
	check(manager.stations.size()==32,"canonical_life_station_positions")
	for id: String in manager.activities:
		check(not manager.start(id,Vector3.ZERO),"remote_start_rejected_"+id)
		check(not manager.start(id,Vector3(NAN,0,0)),"nan_position_rejected_"+id)
		check(not start(id,"car"),"mounted_car_start_rejected_"+id)
	check(not manager.start("UNKNOWN",Vector3.ZERO),"unknown_activity_rejected")
	check(start("TW-ACT-TOP"),"top_start_at_classroom")
	check(not start("TW-ACT-CRAFT"),"cannot_replace_running_activity")
	manager.set_paused(true)
	manager.advance_time(3)
	check(manager.elapsed==0 and not manager.handle_input("tap"),"pause_stops_tick_and_input")
	manager.set_paused(false)
	manager.advance_time(NAN)
	manager.advance_time(INF)
	manager.advance_time(-1)
	manager.advance_time(61)
	check(manager.elapsed==0,"invalid_clock_steps_atomic")
	check(not manager.handle_input("score_100"),"no_arbitrary_score_command")
	finish_beats("TW-ACT-TOP")
	check(manager.status=="completed" and manager.score==100,"top_eight_real_hits_complete")
	check(manager.best["TW-ACT-TOP"]==100 and manager.completion_counts["TW-ACT-TOP"]==1 and manager.badges.has("TW-ACT-TOP"),"top_result_badge_record")
	check(start("TW-ACT-TOP"),"top_repeat_started")
	finish_beats("TW-ACT-TOP",0)
	check(manager.score==87 and manager.best["TW-ACT-TOP"]==100 and manager.completion_counts["TW-ACT-TOP"]==2,"repeat_preserves_best_updates_count")
	check(start("TW-ACT-TOP"),"top_failed_attempt_started")
	manager.advance_time(12)
	check(manager.status=="failed" and manager.hits==0 and manager.completion_counts["TW-ACT-TOP"]==2,"missed_all_beats_fail_without_completion")
	check(start("TW-ACT-CLOGS"),"clogs_at_temple")
	finish_beats("TW-ACT-CLOGS",0,true)
	check(manager.status=="completed" and manager.hits==7 and manager.score==87,"alternating_wrong_foot_loses_beat")
	check(start("TW-ACT-CLOGS"),"clogs_restart")
	for i: int in range(8):
		manager.advance_time(.64)
		var success: bool = manager.handle_input("left")
		check(success==(i%2==0),"must_alternate_not_spam_left_"+str(i))
		manager.advance_time(1.30-manager.round_elapsed+.00001)
	check(manager.status=="failed" and manager.hits==4,"same_foot_spam_fails")
	check(start("TW-ACT-CRAFT"),"craft_at_workshop")
	check(not manager.handle_input("dots") and manager.craft_index==0 and manager.mistakes==1,"incorrect_recipe_does_not_advance")
	check(not manager.handle_input("pay_100"),"foreign_craft_input_rejected")
	for action: String in ["red","white","flower","blue","white","stripes","white","red","dots"]:
		check(manager.handle_input(action),"craft_real_selection_"+action)
	check(manager.status=="completed" and manager.score==90 and manager.craft_index==9,"three_recipes_complete_with_error_deduction")
	check(start("TW-ACT-CRAFT"),"craft_repeat")
	for action: String in ["red","white","flower","blue","white","stripes","white","red","dots"]: manager.handle_input(action)
	check(manager.best["TW-ACT-CRAFT"]==100 and manager.completion_counts["TW-ACT-CRAFT"]==2,"craft_best_saved")
	check(start("TW-ACT-WALK","bicycle"),"walk_start_bicycle_allowed")
	check(not manager.visit_station("old_arcade",point("old_arcade")),"wrong_route_order_rejected")
	check(not manager.visit_station("market_square",Vector3.ZERO),"remote_stamp_rejected")
	check(not manager.visit_station("market_square",point("market_square"),"car"),"car_stamp_rejected")
	check(not manager.visit_station("market_square",Vector3(INF,0,0)),"infinite_stamp_position_rejected")
	manager.advance_time(50)
	check(manager.status=="active" and manager.round_index==0,"walk_no_countdown_auto_win")
	for id: String in ["market_square","old_arcade","river_checkpoint","community_green"]:
		check(manager.visit_station(id,point(id),"bicycle"),"actual_station_stamp_"+id)
		check(not manager.visit_station(id,point(id)),"duplicate_stamp_rejected_"+id)
	check(manager.status=="completed" and manager.score==100 and manager.badges.size()==4,"four_stamps_complete_collection")
	var saved: Dictionary = manager.to_dict()
	var restored := ActivitiesScript.new()
	restored.load_definition()
	check(restored.from_dict(JSON.parse_string(JSON.stringify(saved))),"honest_json_float_roundtrip")
	check(restored.to_dict()==saved,"all_best_badges_counts_roundtrip")
	check(start("TW-ACT-CRAFT"),"unfinished_session_for_reload")
	manager.handle_input("red")
	var interruption: Dictionary = manager.to_dict()
	check(manager.from_dict(interruption) and manager.status=="idle" and manager.active_id.is_empty() and manager.craft_index==0,"reload_discards_unfinished_session_preserves_collection")
	check(manager.best["TW-ACT-CRAFT"]==100,"reload_does_not_discard_best")
	check(start("TW-ACT-TOP"),"cancel_real_session")
	manager.cancel()
	check(manager.status=="idle" and manager.best["TW-ACT-TOP"]==100,"cancel_keeps_earned_results")
	var baseline: Dictionary = manager.to_dict()
	var probes: Array[Dictionary] = []
	var probe: Dictionary = baseline.duplicate(true)
	probe["best"]["TW-ACT-TOP"] = NAN; probes.append(probe)
	probe = baseline.duplicate(true); probe["best"]["TW-ACT-TOP"] = INF; probes.append(probe)
	probe = baseline.duplicate(true); probe["best"]["TW-ACT-TOP"] = 101; probes.append(probe)
	probe = baseline.duplicate(true); probe["best"]["TW-ACT-TOP"] = 99; probes.append(probe)
	probe = baseline.duplicate(true); probe["completion_counts"]["TW-ACT-WALK"] = -1; probes.append(probe)
	probe = baseline.duplicate(true); probe["completion_counts"]["TW-ACT-WALK"] = 1.5; probes.append(probe)
	probe = baseline.duplicate(true); probe["completion_counts"]["TW-ACT-WALK"] = true; probes.append(probe)
	probe = baseline.duplicate(true); probe["attempts"]["TW-ACT-WALK"] = 0; probes.append(probe)
	probe = baseline.duplicate(true); probe["best"]["TW-ACT-WALK"] = 25; probes.append(probe)
	probe = baseline.duplicate(true); probe["badges"].append("TW-ACT-TOP"); probes.append(probe)
	probe = baseline.duplicate(true); probe["badges"] = ["UNKNOWN"]; probes.append(probe)
	probe = baseline.duplicate(true); probe["badges"] = [1,2,3,4]; probes.append(probe)
	probe = baseline.duplicate(true); probe["active_id"] = "TW-ACT-TOP"; probes.append(probe)
	probe = baseline.duplicate(true); probe["best"].erase("TW-ACT-TOP"); probes.append(probe)
	probe = baseline.duplicate(true); probe["version"] = 2; probes.append(probe)
	for i: int in probes.size():
		check(not manager.from_dict(probes[i]),"malformed_save_rejected_"+str(i))
		check(manager.to_dict()==baseline,"malformed_save_atomic_"+str(i))
	restored.free()
	await _check_actual_ui()
	manager.reset()
	check(manager.badges.is_empty() and manager.best["TW-ACT-TOP"]==0 and manager.attempts["TW-ACT-TOP"]==0,"new_game_resets_collection")
	print("TAIWAN_ACTIVITY_CHECKS=",checks," FAILURES=",failures)
	quit(0 if failures==0 else 1)

func _on_input(action: String) -> void:
	input_calls += 1
	manager.handle_input(action)

func _check_actual_ui() -> void:
	hud = HudScript.new()
	root.add_child(hud)
	panel = PanelScript.new()
	panel.setup(hud,manager,{"input":_on_input,"start":func(id: String) -> void: start(id),"cancel":manager.cancel,"resume":func() -> void: pass})
	check(start("TW-ACT-TOP"),"ui_keyboard_trial_start")
	panel.show_activity("TW-ACT-TOP")
	await process_frame
	manager.advance_time(.54)
	var before: int = input_calls
	_key(KEY_SPACE,true)
	check(input_calls==before,"key_repeat_does_not_spam_rhythm")
	_key(KEY_SPACE)
	check(input_calls==before+1 and manager.hits==1,"actual_space_event_reaches_manager")
	check(_button("轉動（空白鍵）")!=null,"actual_rhythm_gui_button")
	var same_button: int = _button("轉動（空白鍵）").get_instance_id()
	manager.advance_time(.10)
	check(_button("轉動（空白鍵）").get_instance_id()==same_button,"frame_updates_keep_control_identity")
	manager.advance_time(1.20-manager.round_elapsed+.00001)
	for i: int in range(1,8):
		var target: float = float(manager.activities["TW-ACT-TOP"]["targets"][i])
		manager.advance_time(target)
		manager.handle_input("tap")
		manager.advance_time(1.20-manager.round_elapsed+.00001)
	await process_frame
	await process_frame
	check(_button("在現場開始／重玩")!=null and _button("轉動（空白鍵）")==null,"completed_ui_offers_direct_replay")
	manager.cancel()
	check(start("TW-ACT-CRAFT"),"ui_recipe_trial_start")
	panel.show_activity("TW-ACT-CRAFT")
	await process_frame
	await process_frame
	await _press(_button("紅色"))
	check(manager.craft_index==1,"real_mouse_button_selects_recipe_material")
	hud._open("settings","設定","其他選單不可接活動按鍵")
	before = input_calls
	_key(KEY_SPACE)
	check(input_calls==before,"leaving_panel_stops_keyboard_listener")
	manager.cancel()
	await _check_short_device_layouts()
	hud.queue_free()
	await process_frame

func _check_short_device_layouts() -> void:
	for pair: Array in [["phone",Vector2i(360,800)],["phone",Vector2i(844,390)],["tablet",Vector2i(1024,768)],["desktop",Vector2i(1366,768)]]:
		root.size = pair[1]
		root.content_scale_size = pair[1]
		hud.set_device_profile({"profile":pair[0]})
		for id: String in ["TW-ACT-TOP","TW-ACT-CLOGS","TW-ACT-CRAFT"]:
			check(start(id),"layout_activity_started_"+id+str(pair[1]))
			panel.show_activity(id)
			await process_frame
			await process_frame
			var clip: Rect2 = hud._modal_scroll.get_global_rect()
			if id!="TW-ACT-CRAFT":
				check(clip.encloses(panel.gauge.get_global_rect()),"gauge_in_operable_clip_"+id+str(pair[1]))
				for caption: String in (["轉動（空白鍵）"] if id=="TW-ACT-TOP" else ["左腳（方向鍵）","右腳（方向鍵）"]):
					var button: Button = _button(caption)
					check(button!=null and clip.encloses(button.get_global_rect()),"rhythm_action_same_clip_"+caption+str(pair[1]))
				if pair[1]==Vector2i(844,390):
					print("ACTIVITY_PHONE_LANDSCAPE ",id," clip=",clip," gauge=",panel.gauge.get_global_rect())
			else:
				for caption: String in ["紅色","藍色","白色","花朵","條紋","圓點"]:
					var button: Button = _button(caption)
					check(button!=null and clip.encloses(button.get_global_rect()),"craft_material_same_clip_"+caption+str(pair[1]))
				check(panel.info.text.contains("廟埕花布") and not panel.info.text.contains("河岸帆布"),"only_current_recipe_before_controls_"+str(pair[1]))
			manager.cancel()
