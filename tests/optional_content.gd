extends SceneTree
const Content = preload("res://scripts/content/optional_content.gd")
const Missions = preload("res://scripts/missions/mission_manager.gd")
var checks: int = 0
var failures: int = 0
var rewards_seen: int = 0
var reward_vouchers: int = 0


func _initialize() -> void:
	call_deferred("run")


func expect(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + description)


func send(content: Node, event: String, target: String) -> void:
	expect(content.handle_event(event, target), "accepted " + event + "/" + target)


func on_reward(reward: Dictionary) -> void:
	rewards_seen += 1
	reward_vouchers += int(reward["parts_vouchers"])


func roundtrip(content: Node) -> void:
	var before: Dictionary = content.to_dict()
	var path := "user://optional_content_contract.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	expect(file != null, "local progress file opens")
	if file == null:
		return
	file.store_string(JSON.stringify(before))
	file.close()
	var read := FileAccess.open(path, FileAccess.READ)
	var restored: Variant = JSON.parse_string(read.get_as_text())
	read.close()
	expect(restored is Dictionary and content.from_dict(restored), "JSON file roundtrip loads")
	expect(content.to_dict() == before, "JSON roundtrip preserves exact optional progress")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func reject_unchanged(content: Node, state: Dictionary, description: String) -> void:
	var before: Dictionary = content.to_dict()
	expect(not content.from_dict(state), description)
	expect(content.to_dict() == before, "invalid load is atomic: " + description)


func finish_bike(content: Node, seconds: float) -> void:
	send(content, "begin_bike_race", "ACT_001_start")
	content.advance_time(seconds)
	for index: int in range(1, 5):
		send(content, "bike_checkpoint", "ACT_001_cp_%d" % index)


func run() -> void:
	var content := Content.new()
	root.add_child(content)
	content.rewarded.connect(on_reward)
	var campaign := Missions.new()
	root.add_child(campaign)
	campaign.start_campaign()
	var campaign_before: Dictionary = campaign.to_dict()
	expect(content.get_menu_entries().size() == 10, "six real sides plus four activities only")
	expect(content.get_task("SIDE-002").is_empty(), "planned unimplemented side is absent")
	expect(content.get_task("ACT-003").is_empty(), "planned unimplemented activity is absent")
	expect(not content.start_task("MAIN-001"), "main ID is not optional content")
	roundtrip(content)

	expect(content.start_task("SIDE-001"), "start sign cleanup")
	expect(not content.start_task("SIDE-004"), "single active optional slot")
	expect(not content.handle_event("deliver_item", "SIDE_001_mei"), "cannot report before cleanup")
	expect(not content.handle_event("disable_sign", "fake_sign"), "cannot use main sign as side progress")
	send(content, "disable_sign", "SIDE_001_sign_1")
	expect(not content.handle_event("disable_sign", "SIDE_001_sign_1"), "sign is unique")
	expect(content.wallet == 0, "side rewards only at completion")
	roundtrip(content)
	send(content, "disable_sign", "SIDE_001_sign_3")
	send(content, "disable_sign", "SIDE_001_sign_2")
	send(content, "deliver_item", "SIDE_001_mei")
	expect(content.wallet == 120 and content.achievements.has("signs_off"), "sign side grants 120 once")
	expect(not content.start_task("SIDE-001"), "completed side cannot be reaccepted")

	expect(content.start_task("SIDE-004"), "start letters")
	for index: int in range(1, 4):
		send(content, "collect_evidence", "SIDE_004_letter_%d" % index)
	send(content, "deliver_item", "SIDE_004_yuan")
	expect(content.scores.evidence_score == 8, "letters add independent evidence bonus")
	expect(content.start_task("SIDE-007"), "start belongings and supplies")
	expect(not content.handle_event("collect_item", "SIDE_007_water"), "supply requires backpack first")
	send(content, "collect_item", "SIDE_007_backpack")
	send(content, "collect_item", "SIDE_007_water")
	send(content, "deliver_supply", "SIDE_007_safe")
	expect(content.rescued_bonus == 0, "already rescued companion is not double counted")
	expect(content.start_task("SIDE-010"), "start parts collection")
	for index: int in range(1, 4):
		send(content, "collect_bike_part", "SIDE_010_part_%d" % index)
	send(content, "repair_item", "SIDE_010_workbench")
	expect(content.start_task("SIDE-011"), "start alley meals")
	send(content, "collect_item", "SIDE_011_meals")
	send(content, "deliver_by_bike", "SIDE_011_neighbor_2")
	send(content, "deliver_by_bike", "SIDE_011_neighbor_1")
	send(content, "deliver_item", "SIDE_011_surong")
	expect(content.start_task("SIDE-012"), "start breakfast repair")
	send(content, "repair_item", "SIDE_012_breakfast_sign")
	send(content, "collect_item", "SIDE_012_aid_box")
	send(content, "repair_item", "SIDE_012_safe_corner")
	expect(content.wallet == 850 and content.scores.community_trust == 20, "six side totals are deterministic")
	roundtrip(content)

	expect(content.start_task("ACT-001"), "start bike activity")
	content.advance_time(500.0)
	expect(content.elapsed == 0.0 and content.status == "active", "time does not start at acceptance")
	expect(not content.handle_event("bike_checkpoint", "ACT_001_cp_1"), "race needs departure")
	send(content, "begin_bike_race", "ACT_001_start")
	expect(not content.handle_event("bike_checkpoint", "ACT_001_cp_3"), "checkpoints are in order")
	content.advance_time(20.0)
	content.advance_time(NAN)
	content.advance_time(-5.0)
	expect(content.elapsed == 20.0, "invalid runtime delta cannot corrupt the clock")
	content.set_paused(true)
	content.advance_time(90.0)
	expect(content.elapsed == 20.0, "pause does not consume activity time")
	expect(not content.handle_event("bike_checkpoint", "ACT_001_cp_1"), "pause rejects progression")
	content.set_paused(false)
	roundtrip(content)
	content.advance_time(70.0)
	expect(content.status == "failed" and content.wallet == 850, "timeout fails without reward")
	expect(content.get_active_text().contains("重試"), "failed UI states retry action")
	expect(not content.handle_event("bike_checkpoint", "ACT_001_cp_1"), "failure cannot be completed by late events")
	roundtrip(content)
	expect(content.start_task("ACT-001"), "failed bike activity can retry")
	finish_bike(content, 35.0)
	expect(content.best_times["ACT-001"] == 35.0 and content.wallet == 880, "first bike finish saves record and reward")
	expect(content.start_task("ACT-001"), "bike activity repeatable")
	finish_bike(content, 22.0)
	expect(content.best_times["ACT-001"] == 22.0 and content.wallet == 880, "better repeat updates record only")
	expect(content.start_task("ACT-001"), "third bike lap")
	finish_bike(content, 42.0)
	expect(content.best_times["ACT-001"] == 22.0 and content.wallet == 880, "slower repeat preserves best and wallet")

	expect(content.start_task("ACT-002"), "start car activity")
	send(content, "begin_car_course", "ACT_002_start")
	expect(not content.handle_event("park_car", "ACT_002_parking"), "cannot skip slalom to park")
	content.advance_time(50.0)
	for index: int in range(1, 4):
		send(content, "car_checkpoint", "ACT_002_cp_%d" % index)
	send(content, "park_car", "ACT_002_parking")
	expect(content.best_times["ACT-002"] == 50.0 and content.wallet == 910, "car course first completion")

	expect(content.start_task("ACT-005"), "start photo collection")
	send(content, "collect_street_view", "ACT_005_photo_1")
	send(content, "collect_street_view", "ACT_005_photo_4")
	expect(content.wallet == 950 and content.collected_points.size() == 2, "first unique photo rewards")
	expect(not content.handle_event("collect_street_view", "ACT_005_photo_4"), "duplicate photo gives no reward")
	content.cancel_task()
	roundtrip(content)
	expect(content.start_task("ACT-005"), "resume album")
	expect(content.get_active_objective()["completed"] == 2, "album keeps collected progress")
	expect(not content.handle_event("collect_street_view", "ACT_005_photo_1"), "loaded photo cannot reward again")
	for index: int in [2, 3, 5, 6, 7, 8]:
		send(content, "collect_street_view", "ACT_005_photo_%d" % index)
	expect(content.wallet == 1070 and content.achievements.has("street_album"), "album rewards eight points once")
	expect(content.start_task("ACT-005") and content.status == "completed" and content.wallet == 1070, "revisiting full album cannot farm")

	expect(content.start_task("ACT-006"), "start community delivery")
	expect(not content.handle_event("deliver_parcel", "ACT_006_drop_2"), "delivery requires parcel pickup")
	send(content, "begin_delivery", "ACT_006_start")
	content.advance_time(60.0)
	send(content, "deliver_parcel", "ACT_006_drop_3")
	send(content, "deliver_parcel", "ACT_006_drop_1")
	roundtrip(content)
	expect(not content.handle_event("deliver_parcel", "ACT_006_drop_3"), "loaded parcel drop is unique")
	send(content, "deliver_parcel", "ACT_006_drop_2")
	expect(content.wallet == 1100 and reward_vouchers == 1100 and rewards_seen == 18, "all first rewards have one matching signal")
	expect(content.get_status()["completed_tasks"].size() == 10, "only implemented ten entries completed")
	expect(content.achievements.size() == 10, "each real task has achievement")
	expect(campaign.to_dict() == campaign_before and campaign.scores.rescued_count == 0, "optional manager never changes main ledger or rescue cap")
	roundtrip(content)

	var bad: Dictionary = content.to_dict()
	bad["schema"] = 999
	reject_unchanged(content, bad, "unknown schema rejected")
	bad = content.to_dict()
	bad["wallet"] += 1
	reject_unchanged(content, bad, "wallet must match grant-once ledger")
	bad = content.to_dict()
	bad["collected_points"].append("ACT_005_photo_1")
	reject_unchanged(content, bad, "duplicate saved collectible rejected")
	bad = content.to_dict()
	bad["scores"]["community_trust"] = 999
	reject_unchanged(content, bad, "forged state bonus rejected")
	bad = content.to_dict()
	bad["completed_tasks"]["SIDE-099"] = true
	reject_unchanged(content, bad, "unknown rewarded task rejected")
	bad = content.to_dict()
	bad["progress"]["drops"] = ["ACT_006_drop_1", "ACT_006_drop_1", "ACT_006_drop_2"]
	reject_unchanged(content, bad, "duplicate saved objective progress rejected")
	bad = content.to_dict()
	bad["elapsed"] = NAN
	reject_unchanged(content, bad, "nonfinite clock rejected")
	bad = content.to_dict()
	bad["timer_started"] = false
	reject_unchanged(content, bad, "timer state must match departed objective")
	bad = content.to_dict()
	bad["best_times"]["ACT-001"] = -1.0
	reject_unchanged(content, bad, "invalid personal best rejected")
	bad = content.to_dict()
	bad["best_times"]["ACT-006"] = 80.0
	reject_unchanged(content, bad, "personal best cannot be slower than completed run")
	bad = content.to_dict()
	bad["progress"].erase("start")
	reject_unchanged(content, bad, "completed run cannot omit departure")
	bad = content.to_dict()
	bad["active_id"] = "SIDE-002"
	reject_unchanged(content, bad, "unimplemented active task rejected")
	bad = content.to_dict()
	bad["achievements"]["fake_medal"] = true
	reject_unchanged(content, bad, "unknown achievement rejected")
	bad = content.to_dict()
	bad["objective_index"] = 99
	reject_unchanged(content, bad, "out of range objective rejected")
	content.cancel_task()
	expect(content.start_task("ACT-006"), "delivery replay after complete")
	send(content, "begin_delivery", "ACT_006_start")
	content.advance_time(30.0)
	for index: int in range(1, 4):
		send(content, "deliver_parcel", "ACT_006_drop_%d" % index)
	expect(content.wallet == 1100 and content.best_times["ACT-006"] == 30.0, "delivery repeat improves record without rewards")
	roundtrip(content)
	content.reset()
	expect(content.wallet == 0 and content.collected_points.is_empty() and content.achievements.is_empty() and content.status == "idle", "explicit new-game reset clears independent optional ledger")
	roundtrip(content)
	content.queue_free()
	campaign.queue_free()
	print("Optional content: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
