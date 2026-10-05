extends SceneTree
## Every shipping work order runs through the real manager at its real station positions.
## No production state is patched to complete a route. Corruption fixtures are separate probes.
const Life = preload("res://scripts/content/taiwan_life.gd")
var passed: Array[String] = []
var failures: Array[String] = []
var route_count := 0
var action_count := 0

func _initialize() -> void: call_deferred("_run")
func check(ok: bool,label: String) -> void:
	if ok: passed.append(label)
	else:
		failures.append(label)
		push_error("TAIWAN_LIFE_FAIL "+label)
func _new() -> TaiwanLife:
	var life := Life.new()
	root.add_child(life)
	life.load_definition()
	return life
func _p(life: TaiwanLife,target: String) -> Vector3:
	var point: Array = life.stations[target]["position"]
	return Vector3(float(point[0]),.08,float(point[1]))
func _equal(a: Variant,b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int): return is_equal_approx(float(a),float(b))
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not _equal(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for index: int in a.size():
			if not _equal(a[index],b[index]): return false
		return true
	return a==b
func _roundtrip(life: TaiwanLife,label: String) -> void:
	var probe := _new()
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(life.to_dict()))
	check(probe.from_dict(snapshot),label+"_json_float_snapshot_loads")
	check(_equal(probe.to_dict(),life.to_dict()) and _equal(probe.get_current_step(),life.get_current_step()),label+"_snapshot_is_exact")
	probe.free()
func _no_action(life: TaiwanLife,args: Array,label: String) -> void:
	var before := life.to_dict()
	check(not life.handle_action.callv(args),label+"_rejected")
	check(_equal(before,life.to_dict()),label+"_no_progress")
func _send(life: TaiwanLife,step: Dictionary,label: String,negative := false) -> bool:
	var target := str(step["target"])
	var action := str(step["action"])
	var item := str(step.get("item_id",""))
	var code := str(step.get("code",""))
	var required := str(step.get("required_vehicle","any"))
	var vehicle := "foot" if required=="any" else required
	var point := _p(life,target)
	if negative:
		_no_action(life,["teleport",target,vehicle,point,item,code],label+"_wrong_action")
		_no_action(life,[action,"missing_station",vehicle,point,item,code],label+"_wrong_station")
		_no_action(life,[action,target,vehicle,point+Vector3(4.51,0,0),item,code],label+"_remote")
		_no_action(life,[action,target,vehicle,Vector3(NAN,0,0),item,code],label+"_nan")
		life.set_paused(true)
		_no_action(life,[action,target,vehicle,point,item,code],label+"_paused")
		life.set_paused(false)
		if required!="any": _no_action(life,[action,target,"foot",point,item,code],label+"_wrong_vehicle")
		if action in ["pickup","deliver","return"]: _no_action(life,[action,target,vehicle,point,"wrong_item",code],label+"_wrong_item")
		if action=="verify_code":
			_no_action(life,[action,target,vehicle,point,item,"0000"],label+"_wrong_code")
	var ok := life.handle_action(action,target,vehicle,point,item,code)
	check(ok,label+"_real_action")
	action_count += 1
	return ok
func _finish(life: TaiwanLife,id: String,chosen: String = "",negative := false,roundtrip := true) -> void:
	for prerequisite: String in life.tasks[id].get("prerequisites",[]):
		if life._task_count(prerequisite)==0: _finish(life,prerequisite,"",false,false)
	check(life.start_task(id),id+"_starts")
	if negative:
		check(not life.choose_route("unknown"),id+"_cannot_choose_before_prefix")
	var sequence := 0
	while life.status in ["active","choosing"] and sequence<30:
		if life.status=="choosing":
			if negative:
				var before := life.to_dict()
				check(not life.choose_route("unknown") and _equal(before,life.to_dict()),id+"_unknown_choice_does_not_move")
			var selected := chosen if not chosen.is_empty() else str(life.get_choices()[0]["id"])
			check(life.choose_route(selected),id+"_choose_"+selected)
		else:
			var step := life.get_current_step()
			if step.is_empty():
				check(false,id+"_active_has_step")
				break
			if not _send(life,step,id+"_"+str(sequence),negative): break
		if roundtrip: _roundtrip(life,id+"_"+str(sequence))
		sequence += 1
	check(life.status=="completed" and life.cargo.is_empty() and life.cargo_origins.is_empty(),id+"_completed_with_empty_cargo")
func _corrupt(life: TaiwanLife,data: Dictionary,label: String) -> void:
	var before := life.to_dict()
	check(not life.from_dict(data),label+"_rejects")
	check(_equal(before,life.to_dict()),label+"_atomic")

func _run() -> void:
	var definition := _new()
	check(definition.tasks.size()==34 and definition.stations.size()==32 and definition.characters.size()==8,"shipping_data_34_tasks_32_stations_8_people")
	check(definition.get_entries("story").size()==16 and definition.get_entries("food").size()==6 and definition.get_entries("convenience").size()==6 and definition.get_entries("parcel").size()==6,"real_categories_16_story_and_18_repeatable")
	check(definition.definition["foods"].size()==16 and definition.definition["items"].size()>=40,"taiwan_food_and_cargo_catalogues")
	check(not definition.start_task("MAIN-001") and not definition.start_task("unknown"),"foreign_or_unknown_task_is_rejected")
	for row: Dictionary in definition.get_character_rows():
		check(row["mission_ids"].size()==2 and row["completed_episodes"]==0 and row["trust"]==0,"two_episodes_"+str(row["id"]))
		check(not definition.start_task(str(row["mission_ids"][1])),"episode_two_locked_"+str(row["id"]))
	for station: String in definition.stations:
		check(definition.discover_station(station,_p(definition,station)),"discover_actual_"+station)
		check(not definition.discover_station(station,_p(definition,station)),"discovery_unique_"+station)
	check(definition.get_discovery_rows().size()==32,"all_32_discoveries_visible")
	_roundtrip(definition,"full_discovery_album")
	for id: String in definition.tasks:
		var task: Dictionary = definition.tasks[id]
		var routes: Array[String] = []
		for route: Dictionary in task.get("choices",[]): routes.append(str(route["id"]))
		if routes.is_empty(): routes.append("")
		for route: String in routes:
			var life := _new()
			_finish(life,id,route,true)
			route_count += 1
			var reward: Dictionary = life._reward(task,route)
			check(life.records.get(id,{}).get("default" if route.is_empty() else route,0)==1,id+"_"+route+"_exact_route_record")
			check(life.last_result.get("cash",-1)==reward["cash"] and life.last_result.get("trust",-1)==reward["trust"],id+"_"+route+"_reward_matches_data")
			var before := life.to_dict()
			check(not life.handle_action("deliver","parcel_receiver","car",_p(life,"parcel_receiver"),"cloth_bundle"),id+"_"+route+"_no_double_finish")
			check(_equal(before,life.to_dict()),id+"_"+route+"_reward_not_repeated")
			if not task["repeatable"]: check(not life.start_task(id),id+"_"+route+"_story_once")
			life.free()
	check(route_count==41,"all_41_actual_routes_finished")
	var all := _new()
	for id: String in all.tasks: _finish(all,id,"",false,false)
	check(all.records.size()==34 and all.get_entries().filter(func(row: Dictionary) -> bool: return row["completed"]).size()==34,"all34_real_records_and_menu_completion")
	for row: Dictionary in all.get_character_rows(): check(row["completed_episodes"]==2 and row["trust"]>=7,"complete_arc_"+str(row["id"]))
	_roundtrip(all,"all_orders_ledger")
	all.free()
	await _cancel_timeout_and_cooldown()
	_validate_corruption()
	definition.free()
	print("TAIWAN_LIFE_RESULT ",JSON.stringify({"passed_count":passed.size(),"failures":failures,"route_count":route_count,"action_count":action_count}))
	quit(0 if failures.is_empty() else 1)

func _cancel_timeout_and_cooldown() -> void:
	var life := _new()
	check(life.start_task("DEL-FOOD-06"),"cancel_two_origins_start")
	_send(life,life.get_current_step(),"cancel_pickup_soup")
	_send(life,life.get_current_step(),"cancel_pickup_mochi")
	check(life.cargo.size()==2 and life.cargo_origins.values().size()==2,"two_actual_pickup_origins")
	life.cancel_task()
	check(life.status=="returning" and not life.start_task("DEL-PARCEL-01"),"cargo_cancel_requires_return_before_new_order")
	_roundtrip(life,"two_origin_cancel")
	_no_action(life,["return","arcade_bakery","foot",_p(life,"arcade_bakery")],"return_wrong_first_origin")
	check(life.handle_action("return","market_breakfast","foot",_p(life,"market_breakfast")),"return_soup_to_actual_origin")
	check(life.cargo==["mochi"] and life.return_station=="arcade_bakery","remaining_cargo_keeps_other_origin")
	_roundtrip(life,"partial_return")
	check(life.handle_action("return","arcade_bakery","foot",_p(life,"arcade_bakery")),"return_last_origin")
	check(life.status=="idle" and life.cash==0 and life.records.is_empty() and life.cargo_origins.is_empty(),"cancel_gives_no_reward_and_clears_cargo")
	check(life.start_task("DEL-FOOD-06"),"cancelled_work_can_restart")
	life.cancel_task()
	check(life.status=="idle","empty_cancel_is_idle")
	check(life.start_task("DEL-FOOD-02"),"timed_food_starts")
	_send(life,life.get_current_step(),"timed_food_pickup")
	var limit: int = int(life.tasks[life.active_id]["limit_seconds"])
	life.set_paused(true)
	var snapshot := life.to_dict()
	for i: int in 5: life.advance_time(1)
	check(_equal(snapshot,life.to_dict()),"pause_freezes_work_limit_and_global_cooldown_clock")
	life.set_paused(false)
	life.advance_time(INF)
	life.advance_time(-1)
	life.advance_time(1.1)
	check(_equal(snapshot,life.to_dict()),"invalid_time_steps_do_not_corrupt_clock")
	for i: int in limit: life.advance_time(1)
	check(life.status=="active","exact_deadline_is_still_active")
	life.advance_time(.1)
	check(life.status=="failed" and not life.cargo.is_empty() and life.cash==0,"over_limit_fails_without_discard_or_reward")
	_roundtrip(life,"failed_work_with_cargo")
	check(not life.start_task("DEL-CONVENIENCE-01"),"failed_cargo_blocks_new_job")
	life.cancel_task()
	check(life.status=="returning","failed_work_cancel_requires_return")
	check(life.handle_action("return",life.return_station,"foot",_p(life,life.return_station)),"failed_food_is_actually_returned")
	_finish(life,"DEL-CONVENIENCE-01","",false)
	var first_cash := life.cash
	check(not life.start_task("DEL-CONVENIENCE-01"),"completed_repeatable_has_cooldown")
	for i: int in 44: life.advance_time(1)
	check(not life.start_task("DEL-CONVENIENCE-01"),"cooldown_not_early")
	life.advance_time(1)
	_finish(life,"DEL-CONVENIENCE-01","",false)
	check(life.cash==first_cash*2 and life._task_count("DEL-CONVENIENCE-01")==2,"new_completed_run_rewards_once_after_real_cooldown")
	_roundtrip(life,"repeatable_second_record")
	life.free()

func _validate_corruption() -> void:
	var life := _new()
	_corrupt(life,{},"missing_new_section_is_not_a_valid_live_state")
	var empty := life.to_dict()
	var changes: Dictionary = {"version":2,"cash":1,"step_index":.5,"status":"cheat","clock":NAN,"elapsed":-1,"active_id":"unknown","cargo":["cloth_bundle"],"cargo_origins":{"cloth_bundle":"orange_parcel"},"return_station":"orange_parcel","trust":{"AN":10},"records":{"unknown":{"default":1}},"cooldowns":{"DEL-FOOD-01":45},"discovered_stations":["unknown"]}
	for key: String in changes:
		var bad := empty.duplicate(true)
		bad[key] = changes[key]
		_corrupt(life,bad,"empty_corruption_"+key)
	check(life.start_task("DEL-PARCEL-01"),"validation_parcel_starts")
	_send(life,life.get_current_step(),"validation_actual_code")
	_send(life,life.get_current_step(),"validation_actual_pickup")
	var carrying := life.to_dict()
	changes = {"cash":50,"trust":{"AN":3},"step_index":4,"route_id":"wrong","cargo":["book_bundle"],"cargo_origins":{"cloth_bundle":"parcel_sort"},"return_station":"parcel_sort","status":"completed","records":{"DEL-PARCEL-01":{"default":.5}},"discovered_stations":["orange_parcel","orange_parcel"]}
	for key: String in changes:
		var bad := carrying.duplicate(true)
		bad[key] = changes[key]
		_corrupt(life,bad,"carrying_corruption_"+key)
	life.cancel_task()
	check(life.handle_action("return","orange_parcel","foot",_p(life,"orange_parcel")),"validation_returns_then_can_complete_story")
	_finish(life,"TW-LIN-01","warm",false,false)
	check(life.is_unlocked("TW-LIN-02"),"honest_three_trust_unlocks_second_episode")
	var story_done := life.to_dict()
	var bad := story_done.duplicate(true)
	bad["cash"] += 1
	_corrupt(life,bad,"ledger_cash_cannot_be_injected")
	bad = story_done.duplicate(true)
	bad["trust"]["LIN"] += 1
	_corrupt(life,bad,"ledger_trust_cannot_be_injected")
	bad = story_done.duplicate(true)
	bad["records"]["TW-LIN-01"] = {"warm":1,"separate":1}
	bad["cash"] = 125
	bad["trust"] = {"LIN":7}
	_corrupt(life,bad,"story_multiple_routes_cannot_be_rewarded")
	bad = story_done.duplicate(true)
	bad["route_id"] = "separate"
	bad["step_index"] = life._steps(life.tasks["TW-LIN-01"],"separate").size()
	_corrupt(life,bad,"completed_route_must_match_rewarded_story_record")
	var prefix := _new()
	check(prefix.start_task("TW-LIN-01"),"validation_route_prefix_starts")
	bad = prefix.to_dict()
	bad["route_id"] = "warm"
	_corrupt(prefix,bad,"route_cannot_be_selected_before_required_talk")
	prefix.free()
	var mixed := _new()
	check(mixed.start_task("TW-LIN-01"),"validation_group_return_starts")
	_send(mixed,mixed.get_current_step(),"validation_group_return_talk")
	check(mixed.choose_route("warm"),"validation_group_return_chooses_warm")
	for index: int in 3: _send(mixed,mixed.get_current_step(),"validation_group_pickup_"+str(index))
	mixed.cancel_task()
	bad = mixed.to_dict()
	bad["cargo"].erase("fried_noodles")
	bad["cargo_origins"].erase("fried_noodles")
	_corrupt(mixed,bad,"cancel_return_cannot_discard_only_one_item_from_same_origin")
	mixed.free()
	var prerequisite := _new()
	_finish(prerequisite,"TW-LIN-02","",false,false)
	bad = prerequisite.to_dict()
	bad["records"].erase("TW-LIN-01")
	bad["cash"] -= 70
	bad["trust"]["LIN"] -= 3
	_corrupt(prerequisite,bad,"completed_second_episode_cannot_lose_prerequisite")
	bad = prerequisite.to_dict()
	prerequisite.tasks["TW-LIN-02"]["required_trust"]["min"] = 99
	_corrupt(prerequisite,bad,"completed_episode_cannot_self_reward_its_required_trust")
	prerequisite.free()
	# The required_trust contract must be validated, rather than incidentally masked
	# by today's first-episode reward. The manager still executes all work honestly.
	life.tasks["TW-LIN-02"]["required_trust"]["min"] = 99
	check(not life.is_unlocked("TW-LIN-02") and not life.start_task("TW-LIN-02"),"runtime_required_trust_gate_is_real")
	bad = story_done.duplicate(true)
	bad["active_id"] = "TW-LIN-02"
	bad["route_id"] = ""
	bad["step_index"] = 0
	bad["status"] = "active"
	_corrupt(life,bad,"save_cannot_bypass_required_trust_gate")
	life.free()
