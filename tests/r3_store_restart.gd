extends SceneTree
const Main = preload("res://scripts/main.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func run() -> void:
	Engine.set_meta("seven_district_no_records",true)
	var game := Main.new()
	root.add_child(game)
	var frames := 0
	while not game.expansion_complete and frames < 15000:
		await process_frame
		frames += 1
	check(game.expansion_complete,"new_process_finishes_startup")
	if game.expansion_complete:
		game.is_test_mode = true
		check(not game.play_started and game.hud.get_menu_mode() == "title","cold_relaunch_starts_at_title")
		game._load(98)
		check(game.play_started and not paused,"persisted_campaign_loads_in_new_process")
		check(game.fraud_case.stage == 4,"new_process_preserves_sealed_case")
		check(game.missions.current_objective > 0,"new_process_preserves_first_objective")
		game.hud.show_fraud_case()
		check(game.hud.get_menu_mode() == "case","persisted_case_can_be_read")
		game._resume()
	game.queue_free()
	await process_frame
	await process_frame
	Engine.remove_meta("seven_district_no_records")
	print("R3_RESTART_CHECKS=",checks," FAILURES=",failures)
	quit(0 if failures == 0 else 1)
