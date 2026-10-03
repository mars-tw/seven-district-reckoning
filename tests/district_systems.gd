extends SceneTree

const Systems = preload("res://scripts/systems/district_systems.gd")
const Optional = preload("res://scripts/content/optional_content.gd")
var passed: Array[String] = []
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, label: String) -> void:
	if condition:
		passed.append(label)
	else:
		failures.append(label)
		push_error("DISTRICT_SYSTEMS_FAIL " + label)


func fresh() -> Node:
	var manager := Systems.new()
	root.add_child(manager)
	return manager


func complete_walk(manager: Node) -> void:
	manager.reset_walk_sample()
	manager.record_walk(Vector3(-100, 0, 0), 0.1, true)
	for i: int in range(1, 401):
		manager.record_walk(Vector3(-100 + i * 0.5, 0, 0), 0.1, true)
	for i: int in range(1, 401):
		manager.record_walk(Vector3(100 - i * 0.5, 0, 0), 0.1, true)


func complete_actions(manager: Node) -> void:
	for id: String in ["SIDE-001", "SIDE-004", "SIDE-007"]:
		check(manager.record_action("side_completed", id, "optional:" + id), "first_unique_commission_" + id)
	for i: int in range(8):
		var id: String = "sandbox_%d" % i
		check(manager.record_action("destroy", id, "destroy:" + id), "actual_unique_training_target_" + id)


func roundtrip(manager: Node, label: String) -> void:
	var serialized: Dictionary = manager.to_dict()
	var target: Node = fresh()
	check(target.from_dict(serialized), label + "_dictionary_load")
	check(target.to_dict() == serialized, label + "_dictionary_equal")
	var json_value: Variant = JSON.parse_string(JSON.stringify(serialized))
	check(json_value is Dictionary and target.from_dict(json_value), label + "_JSON_load")
	check(target.to_dict() == serialized, label + "_JSON_equal")
	check(target.get_stats() == manager.get_stats(), label + "_passive_stats_equal")
	target.queue_free()


func reject(manager: Node, value: Dictionary, label: String) -> void:
	var previous: Dictionary = manager.to_dict()
	check(not manager.from_dict(value), label + "_rejected")
	check(manager.to_dict() == previous, label + "_does_not_mutate")


func _run() -> void:
	var manager: Node = fresh()
	var optional: Node = Optional.new()
	root.add_child(optional)
	var original_optional: Dictionary = optional.to_dict()
	check(manager.credits == 120 and manager.xp == 0 and manager.rank == 1, "separate_starting_ledger_120")
	check(manager.get_offers().size() == 4 and manager.get_challenges().size() == 3, "four_offers_three_challenges")
	check(manager.get_status()["rank_name"] == "初到街區", "original_Traditional_Chinese_rank")
	check(manager.get_stats() == {"max_stamina": 100.0, "tool_damage_multiplier": 1.0, "bike_accel_multiplier": 1.0}, "baseline_stats")
	check(manager.get_offers()[0]["available"] and not manager.get_offers()[1]["unlocked"], "rank_one_only_first_aid_unlocked")
	var offer_copy: Array = manager.get_offers()
	offer_copy[0]["cost"] = 0
	check(manager.get_offers()[0]["cost"] == 35, "offer_copy_cannot_change_cost")
	var challenge_copy: Array = manager.get_challenges()
	challenge_copy[0]["reward_credits"] = 999
	check(manager.get_challenges()[0]["reward_credits"] == 90, "challenge_copy_cannot_change_reward")
	check(not manager.purchase("healing", 100)["ok"] and manager.credits == 120, "full_health_no_payment")
	for health: float in [NAN, INF, -1.0, 100.1]:
		check(not manager.purchase("healing", health)["ok"] and manager.credits == 120, "invalid_health_no_payment_" + str(health))
	check(not manager.purchase("stamina", 20)["ok"] and manager.credits == 120, "locked_upgrade_no_payment")
	check(not manager.purchase("unknown", 20)["ok"] and manager.credits == 120, "unknown_offer_no_payment")
	var bought: Dictionary = manager.purchase("healing", 80)
	check(bought["ok"] and bought["effects"]["healing"] == 20 and bought["effects"]["health_after"] == 100, "healing_caps_at_actual_missing_health")
	check(manager.credits == 85 and manager.get_journal().size() == 1, "successful_healing_charges_once_records_journal")
	manager.set_paused(true)
	var before_pause: Dictionary = manager.to_dict()
	check(not manager.record_action("side_completed", "SIDE-001", "optional:SIDE-001"), "paused_completion_rejected")
	check(not manager.record_action("destroy", "sandbox_0", "destroy:sandbox_0"), "paused_destruction_rejected")
	check(manager.record_walk(Vector3.ZERO, 0.1, true) == 0 and manager.to_dict() == before_pause, "paused_walking_no_progress")
	check(manager.purchase("healing", 1)["ok"] and manager.credits == 50, "explicit_paused_shop_purchase_allowed")
	manager.set_paused(false)
	roundtrip(manager, "partial_healing")
	manager.reset()

	check(manager.record_walk(Vector3.ZERO, 0.1, true) == 0, "first_sample_is_baseline")
	check(manager.record_walk(Vector3(0.5, 0, 0), 0.1, true) == 0.5, "actual_half_metre_walk")
	check(manager.record_walk(Vector3(100, 0, 0), 0.1, true) == 0 and manager.walking_distance == 0.5, "teleport_rejected_without_clamping")
	check(manager.record_walk(Vector3(100.5, 0, 0), 0.1, true) == 0.5, "walk_after_teleport_has_new_baseline")
	check(manager.record_walk(Vector3(102, 0, 0), 0.1, true) == 0, "impossible_speed_rejected")
	check(manager.record_walk(Vector3(102.5, 2, 0), 0.1, true) == 0, "large_vertical_jump_rejected")
	check(manager.record_walk(Vector3(103, 2, 0), 0.1, false) == 0, "vehicle_motion_excluded")
	check(manager.record_walk(Vector3(104, 2, 0), 0.1, true) == 0, "vehicle_exit_resets_baseline")
	check(manager.record_walk(Vector3(105, 2, 0), 0.1, true, false) == 0, "airborne_motion_excluded")
	check(manager.record_walk(Vector3(105.5, 2, 0), 0.1, true) == 0, "landing_resets_baseline")
	for bad_delta: float in [NAN, INF, -0.1, 0.0, 0.251]:
		check(manager.record_walk(Vector3(106, 2, 0), bad_delta, true) == 0, "invalid_physics_delta_" + str(bad_delta))
	for bad_position: Vector3 in [Vector3(NAN, 0, 0), Vector3(0, INF, 0), Vector3(201, 0, 0)]:
		check(manager.record_walk(bad_position, 0.1, true) == 0, "invalid_world_position_" + str(bad_position))
	manager.set_paused(true)
	manager.set_paused(false)
	check(manager.record_walk(Vector3(-100, 0, 0), 0.1, true) == 0, "pause_resume_never_counts_jump")
	roundtrip(manager, "partial_walking")
	manager.reset()
	var grants: Array = []
	manager.rewarded.connect(func(reward: Dictionary) -> void: grants.append(reward))
	complete_walk(manager)
	check(manager.walking_distance == 400 and manager.credits == 210 and manager.xp == 80 and manager.rank == 2, "400_real_metres_unlock_rank_two_once")
	check(grants.size() == 1 and grants[0]["id"] == "walk", "walk_completion_emits_one_reward")
	complete_walk(manager)
	check(manager.walking_distance == 400 and manager.credits == 210 and grants.size() == 1, "additional_walk_cannot_farm_credits")
	check(manager.get_challenges()[0]["completed"] and manager.get_challenges()[0]["progress"] == 400, "completed_walk_ui_progress")
	check(manager.purchase("stamina", 100)["ok"] and manager.get_stats()["max_stamina"] == 120 and manager.credits == 120, "rank_two_stamina_upgrade_applies")
	check(not manager.purchase("stamina", 100)["ok"] and manager.credits == 120, "permanent_upgrade_cannot_buy_twice")
	roundtrip(manager, "walking_and_upgrade")

	for event_name: String in ["destroy_target", "hit", "side_completed"]:
		check(not manager.record_action(event_name, "sandbox_0", "bad:" + event_name), "event_type_must_match_" + event_name)
	for id: String in ["practice_1", "record_1", "record_2", "guard_1", "civilian", "unknown", "mei"]:
		check(not manager.record_action("destroy", id, "destroy:" + id), "not_legal_challenge_target_" + id)
	for id: String in ["ACT-001", "MAIN-001", "SIDE-002", "SIDE-099"]:
		check(not manager.record_action("side_completed", id, "optional:" + id), "commission_whitelist_" + id)
	for source: String in ["", "with spaces", "has\nnewline", "../escape", "{forged}", "a".repeat(97)]:
		check(not manager.record_action("destroy", "sandbox_0", source), "invalid_source_id_" + str(source.length()))
	check(manager.record_action("side_completed", "SIDE-001", "optional:SIDE-001"), "first_side_recorded")
	check(not manager.record_action("side_completed", "SIDE-001", "optional:new-run"), "same_side_new_UUID_cannot_farm")
	check(not manager.record_action("destroy", "sandbox_0", "optional:SIDE-001"), "source_UUID_unique_across_event_types")
	check(manager.record_action("side_completed", "SIDE-004", "optional:SIDE-004"), "second_distinct_side_partial")
	check(manager.credits == 120 and manager.xp == 80, "partial_commissions_no_reward")
	roundtrip(manager, "two_unique_commissions")
	check(manager.record_action("side_completed", "SIDE-007", "optional:SIDE-007"), "third_distinct_side_completed")
	check(manager.credits == 240 and manager.xp == 190 and manager.rank == 3 and grants.size() == 2, "three_commissions_grant_once_unlock_rank_three")
	check(manager.purchase("tool_power", 100)["ok"] and manager.get_stats()["tool_damage_multiplier"] == 1.2 and manager.credits == 100, "rank_three_tool_upgrade_applies")
	check(not manager.purchase("vehicle_service", 100)["ok"] and manager.credits == 100, "insufficient_credits_no_charge")
	for i: int in range(7):
		check(manager.record_action("destroy", "sandbox_%d" % i, "destroy:sandbox_%d" % i), "partial_distinct_destroy_%d" % i)
	check(manager.credits == 100 and manager.xp == 190, "seven_destroyed_targets_no_early_reward")
	check(not manager.record_action("destroy", "sandbox_0", "destroy:reload_0"), "same_destroyed_target_new_source_cannot_farm")
	roundtrip(manager, "seven_tool_targets")
	check(manager.record_action("destroy", "sandbox_7", "destroy:sandbox_7"), "eighth_tool_target_completed")
	check(manager.credits == 200 and manager.xp == 280 and manager.rank == 4 and grants.size() == 3, "tools_grant_once_max_rank")
	check(manager.purchase("vehicle_service", 100)["ok"] and manager.get_stats()["bike_accel_multiplier"] == 1.15 and manager.credits == 95, "bicycle_adjustment_real_multiplier")
	for id: String in ["SIDE-010", "SIDE-011", "SIDE-012"]:
		check(manager.record_action("side_completed", id, "optional:" + id), "later_unique_commission_" + id)
	for id: String in ["fake_sign", "equipment_1", "equipment_2", "equipment_3", "SIDE_001_sign_1", "SIDE_001_sign_2", "SIDE_001_sign_3", "SIDE_012_breakfast_sign"]:
		check(manager.record_action("destroy", id, "destroy:" + id), "later_legal_target_" + id)
	check(manager.credits == 95 and manager.xp == 280 and grants.size() == 3, "completed_challenge_extra_targets_never_pay_again")
	check(optional.to_dict() == original_optional, "independent_manager_never_changes_optional_1100_contract")
	var journal_copy: Array = manager.get_journal()
	journal_copy[0]["credits"] = 999
	check(manager.get_journal()[0]["credits"] != 999, "journal_copy_cannot_mutate_receipts")
	check(manager.get_journal().size() <= 30, "journal_is_bounded")
	roundtrip(manager, "all_challenges_all_upgrades")

	var bad: Dictionary
	for key: String in ["schema", "credits", "xp", "rank", "walking_distance", "purchases", "commissions", "destroyed", "rewarded", "journal", "journal_sequence"]:
		bad = manager.to_dict()
		bad.erase(key)
		reject(manager, bad, "required_saved_field_" + key)
	for key: String in ["credits", "xp", "rank", "journal_sequence"]:
		for value: Variant in [-1, NAN, INF, "1", true, 1.5]:
			bad = manager.to_dict()
			bad[key] = value
			reject(manager, bad, "invalid_number_" + key + "_" + str(value))
	bad = manager.to_dict()
	bad["schema"] = 2
	reject(manager, bad, "future_schema")
	bad = manager.to_dict()
	bad["credits"] += 1
	reject(manager, bad, "forged_wallet")
	bad = manager.to_dict()
	bad["xp"] -= 1
	reject(manager, bad, "XP_must_match_challenges")
	bad = manager.to_dict()
	bad["rank"] = 3
	reject(manager, bad, "rank_must_match_XP")
	for value: Variant in [-1, NAN, INF, 400.1, "400"]:
		bad = manager.to_dict()
		bad["walking_distance"] = value
		reject(manager, bad, "invalid_walking_progress_" + str(value))
	bad = manager.to_dict()
	bad["rewarded"].append("walk")
	reject(manager, bad, "duplicate_reward")
	bad = manager.to_dict()
	bad["rewarded"].erase("walk")
	reject(manager, bad, "completed_challenge_missing_receipt")
	bad = manager.to_dict()
	bad["rewarded"][0] = "daily-refresh"
	reject(manager, bad, "unknown_challenge_reward")
	bad = manager.to_dict()
	bad["destroyed"]["record_1"] = "destroy:record_1"
	reject(manager, bad, "saved_evidence_not_legal_target")
	bad = manager.to_dict()
	bad["commissions"]["ACT-001"] = "optional:ACT-001"
	reject(manager, bad, "saved_activity_not_commission")
	bad = manager.to_dict()
	bad["destroyed"]["sandbox_0"] = bad["commissions"]["SIDE-001"]
	reject(manager, bad, "saved_source_UUID_duplicate_cross_type")
	bad = manager.to_dict()
	bad["destroyed"]["sandbox_0"] = ""
	reject(manager, bad, "saved_blank_source")
	for count: Variant in [0, -1, 2, NAN, 0.5]:
		bad = manager.to_dict()
		bad["purchases"]["tool_power"] = count
		reject(manager, bad, "invalid_permanent_purchase_count_" + str(count))
	bad = manager.to_dict()
	bad["purchases"]["premium"] = 1
	reject(manager, bad, "unknown_saved_item")
	bad = manager.to_dict()
	bad["journal_sequence"] += 1
	reject(manager, bad, "journal_sequence_matches_number_of_transactions")
	bad = manager.to_dict()
	bad["journal"].remove_at(0)
	reject(manager, bad, "journal_missing_transaction")
	for key: String in ["event", "id", "text", "credits", "xp", "sequence"]:
		bad = manager.to_dict()
		bad["journal"][0][key] = "forged"
		reject(manager, bad, "journal_forged_" + key)
	bad = manager.to_dict()
	bad["journal"].reverse()
	reject(manager, bad, "journal_transaction_order")
	bad = manager.to_dict()
	bad["journal"][0]["id"] = "tools"
	reject(manager, bad, "journal_reward_id_order")
	var locked: Node = fresh()
	bad = locked.to_dict()
	bad["purchases"]["tool_power"] = 1
	bad["credits"] = 0
	reject(locked, bad, "saved_upgrade_cannot_bypass_unlock")
	locked.queue_free()

	manager.reset()
	complete_walk(manager)
	complete_actions(manager)
	for i: int in range(12):
		check(manager.purchase("healing", 1)["ok"], "bounded_repeatable_first_aid_%d" % i)
	check(manager.credits == 10 and not manager.purchase("healing", 1)["ok"], "first_aid_limit_and_finite_wallet")
	check(manager.get_offers()[0]["sold_out"] and manager.get_offers()[0]["purchased"] == 12, "sold_out_supply_shown_in_offers")
	roundtrip(manager, "max_first_aid_receipts")
	manager.reset()
	check(manager.credits == 120 and manager.xp == 0 and manager.rank == 1 and manager.get_journal().is_empty(), "explicit_new_game_resets_own_ledger")
	check(manager.get_stats()["max_stamina"] == 100 and manager.to_dict()["commissions"].is_empty(), "reset_clears_upgrades_records")
	roundtrip(manager, "fresh_reset")
	manager.queue_free()
	optional.queue_free()
	print("DISTRICT_SYSTEMS_RESULT " + JSON.stringify({"passed_count": passed.size(), "failures": failures}))
	quit(1 if not failures.is_empty() else 0)
