extends SceneTree
## R1 fun/polish contract: replay grades, HUD feedback, impact layer, story
## cold open, objective guidance, chain progress and touch command layout.
## Headless and deterministic; records never persist to the player's profile.

const Records = preload("res://scripts/systems/run_records.gd")
const Hud = preload("res://scripts/ui/game_hud.gd")
const Missions = preload("res://scripts/missions/mission_manager.gd")
const Feedback = preload("res://scripts/systems/hit_feedback.gd")
const Player = preload("res://scripts/player/player_controller.gd")
const ActualScene = preload("res://scenes/main.tscn")

class R1Root extends "res://scripts/main.gd":
	# Mission completion autosaves; this fixture never writes campaign slots.
	func _save(_show_notice: bool = true) -> void:
		pass

class Probe extends Node3D:
	var health: float = 100.0
	func apply_hit(_hit: String, _source: String, amount: float) -> void:
		health -= amount

class RefusingProbe extends Node3D:
	var health: float = 100.0
	func apply_hit(_hit: String, _source: String, _amount: float) -> void:
		pass

var checks: int = 0
var failures: int = 0
var world: Node3D
var coverage_evidence: String = ""

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("R1_PASS ", label)
	else:
		failures += 1
		push_error("R1_FAIL " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_records()
	await _check_hud()
	await _check_feedback()
	await _check_world()
	print("R1_HUD_COVERAGE ", coverage_evidence)
	print("R1_FUN_POLISH_CHECKS=", checks, " FAILURES=", failures)
	if is_instance_valid(world): world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _check_records() -> void:
	check(Records.grade({"evidence_score": 46, "community_trust": 63, "rescued_count": 4, "seconds": 800, "heat_level": 0}) == "S", "fast_complete_rescue_run_grades_S")
	check(Records.grade({"evidence_score": 26, "community_trust": 55, "rescued_count": 2, "seconds": 800, "heat_level": 0, "branch": "smash"}) == "S", "fast_clean_smash_run_can_reach_S")
	check(Records.grade({"evidence_score": 10, "community_trust": 40, "rescued_count": 2, "seconds": 3000, "heat_level": 5}) == "C", "slow_loud_low_trust_run_grades_C")
	check(Records.score({"evidence_score": INF, "community_trust": -50, "rescued_count": 99, "seconds": NAN, "heat_level": -3}) == int(round(100 * 0.3 + 0 + 4 * 5)), "score_clamps_invalid_inputs")
	var records = Records.new("user://r1-records-should-not-exist.cfg", false)
	var first: Dictionary = records.record("smash", {"evidence_score": 10, "community_trust": 50, "rescued_count": 2, "seconds": 3000, "heat_level": 3, "branch": "smash"})
	check(first["new_best"] and records.best["smash"] == first["grade"], "first_run_sets_branch_best")
	var worse: Dictionary = records.record("smash", {"evidence_score": 0, "community_trust": 0, "rescued_count": 0, "seconds": 9000, "heat_level": 5})
	check(not worse["new_best"] and records.best["smash"] == first["grade"], "worse_run_never_lowers_best")
	check(records.completed_count() == 1 and records.next_suggestion("smash") == "evidence", "next_suggestion_points_to_untried_branch")
	check("解法完成 1／3" in records.progress_text("smash") and "蒐證" in records.progress_text("smash"), "progress_text_shows_branch_completion_and_next_try")
	check(not records.record("unknown", {})["new_best"], "unknown_branch_is_not_recorded")
	check(not FileAccess.file_exists("user://r1-records-should-not-exist.cfg"), "non_persistent_records_write_no_file")
	var stored = Records.new("user://r1-records-roundtrip.cfg", true)
	stored.record("rescue", {"evidence_score": 46, "community_trust": 63, "rescued_count": 4, "seconds": 800})
	var reloaded = Records.new("user://r1-records-roundtrip.cfg", true)
	check(reloaded.best.get("rescue", "") == "S" and is_equal_approx(float(reloaded.best_seconds.get("rescue", 0)), 800.0), "persistent_records_roundtrip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://r1-records-roundtrip.cfg"))

func _check_hud() -> void:
	root.size = Vector2i(1280, 720)
	var missions := Missions.new()
	root.add_child(missions)
	missions.start_campaign()
	var hud := Hud.new()
	root.add_child(hud)
	hud.bind_missions(missions)
	hud.update_status(64.0, "wrench", 1, "", "E｜車店集合點")
	await process_frame
	await process_frame
	var coverage: float = hud.hud_coverage()
	coverage_evidence = JSON.stringify({"viewport": "1280x720", "coverage": snappedf(coverage, 0.001)})
	check(coverage > 0.0 and coverage <= 0.20, "desktop_hud_covers_at_most_20_percent_of_view")
	check(hud._mission_panel.size.x <= 480.0, "desktop_mission_card_is_narrow")
	check(is_equal_approx(hud._health_bar.value, 64.0), "health_bar_tracks_safety_value")
	hud.show_banner("第 1／5 環", "賠掉的存款", "美晴：地址還在？")
	check(hud.banner_text == "賠掉的存款" and hud.dialogue_text.begins_with("美晴") and hud._banner_line.visible, "banner_shows_mission_title_and_speaker_line")
	hud.show_toast("✓ 目標完成")
	check(hud.toast_text == "✓ 目標完成" and hud._toast.modulate.a > 0.9, "objective_toast_visible")
	hud.set_chain_progress(2)
	check(hud.get_chain_progress() == 2, "chain_progress_breaks_links")
	hud.set_chain_progress(9)
	check(hud.get_chain_progress() == 5, "chain_progress_clamps_to_five_links")
	hud.set_combo(3)
	check(hud._combo_label.text == "連擊 ×3" and hud._combo_label.modulate.a > 0.9, "combo_counter_shows_from_second_hit")
	hud.set_target_distance(18.4)
	check(hud._distance_label.text == "▶ 目標 18 公尺" and hud._distance_label.visible, "target_distance_text")
	hud.set_target_distance(-1)
	check(not hud._distance_label.visible, "distance_hidden_without_target")
	hud.show_title()
	await process_frame
	check(not hud._hud.visible and hud.get_menu_mode() == "title", "title_hides_gameplay_hud")
	check(hud._title_start_button.text == "開始行動" and hud._title_start_button.size.y >= 56, "title_primary_cta_is_large")
	var all_buttons: Array[Node] = hud._root.find_children("*", "Button", true, false)
	var small: int = 0
	for button: Button in all_buttons:
		if button.is_visible_in_tree() and button.size.y < 44: small += 1
	check(small == 0, "title_buttons_at_least_44px")
	var started: Array[bool] = [false]
	hud.new_game_requested.connect(func() -> void: started[0] = true)
	hud._title_start_button.pressed.emit()
	check(started[0] and hud._hud.visible and not paused, "standalone_title_cta_starts_and_restores_hud")
	hud.show_chapter_complete("rescue", {"grade": "A", "score": 50, "time_text": "14:05", "new_best": true, "progress": "解法完成 1／3"})
	await process_frame
	var grade := hud._modal_box.find_child("RunGrade", true, false) as Label
	check(grade != null and grade.text == "A", "chapter_complete_shows_run_grade")
	hud.hide_menus()
	hud.queue_free()
	missions.queue_free()
	await process_frame

func _check_feedback() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var player := Player.new()
	holder.add_child(player)
	var feedback := Feedback.new()
	holder.add_child(feedback)
	feedback.setup(player)
	var target := Probe.new()
	holder.add_child(target)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	target.add_child(mesh)
	target.position = Vector3(0, 0, -1.2)
	var landed: Array = []
	player.hit_landed.connect(func(node: Node3D, amount: float) -> void: landed.append([node, amount]))
	player.hit_landed.connect(feedback.on_hit)
	player._attack_sequence = 1
	player._deliver_hit(target, 24.0)
	check(landed.size() == 1 and landed[0][0] == target and is_equal_approx(float(landed[0][1]), 24.0), "accepted_hit_emits_hit_landed_once")
	check(is_equal_approx(target.health, 76.0), "impact_layer_does_not_change_damage")
	var refusing := RefusingProbe.new()
	holder.add_child(refusing)
	player._deliver_hit(refusing, 24.0)
	check(landed.size() == 1, "refused_hit_emits_no_impact")
	check(feedback.spawned_effects == 1 and feedback.find_children("HitSparks", "CPUParticles3D", true, false).size() == 1, "hit_spawns_sparks")
	check(feedback.find_children("DamageNumber", "Label3D", true, false).size() == 1, "hit_spawns_damage_number")
	check(mesh.material_overlay != null, "hit_flashes_target")
	feedback._process(Feedback.FLASH_TIME + 0.01)
	feedback.combo = 1
	feedback._combo_clock = Feedback.COMBO_WINDOW
	check(mesh.material_overlay == null, "hit_flash_clears_after_flash_time")
	check(feedback.combo == 1, "first_hit_starts_combo")
	feedback.on_hit(target, 24.0)
	check(feedback.combo == 2, "second_hit_in_window_increments_combo")
	feedback._process(Feedback.COMBO_WINDOW + 0.1)
	check(feedback.combo == 0, "combo_resets_after_window")
	check(player._shake > 0.0, "hit_adds_camera_shake")
	player._update_impact(0.016)
	check(player._camera.h_offset != 0.0 or player._camera.v_offset != 0.0, "camera_shake_offsets_lens_only")
	var facing_before: Vector3 = player._facing
	player._update_impact(1.0)
	check(player._camera.h_offset == 0.0 and player._camera.v_offset == 0.0 and player._facing == facing_before, "camera_shake_decays_without_changing_aim")
	player.hit_pause(0.07)
	check(player.is_hit_paused(), "hit_pause_starts")
	player._update_impact(0.1)
	check(not player.is_hit_paused(), "hit_pause_ends_after_duration")
	check(player._spring_arm.process_mode == Node.PROCESS_MODE_ALWAYS, "camera_arm_resolves_while_menus_pause")
	check(player.find_child("CharacterFillLight", true, false) is OmniLight3D and not (player.find_child("CharacterFillLight", true, false) as OmniLight3D).shadow_enabled, "character_fill_light_is_shadowless")
	holder.queue_free()
	await process_frame

func _check_world() -> void:
	world = ActualScene.instantiate()
	world.set_script(R1Root)
	root.add_child(world)
	current_scene = world
	var frames: int = 0
	while not world.expansion_complete and frames < 30000:
		await process_frame
		frames += 1
	check(world.expansion_complete, "full_world_ready_for_r1_fixture")
	if not world.expansion_complete: return
	check(world.music != null and world.music.has_track("street") and world.music.has_track("title") and world.music.missing.is_empty(), "street_and_title_music_tracks_are_shipped")
	check(world.music.mode == "title", "title_plays_title_mode_music")
	world.is_test_mode = false
	world._start_story()
	await process_frame
	check(is_instance_valid(world.story_intro) and paused and world.play_started, "title_cta_plays_story_over_paused_campaign")
	var cards: int = 0
	while is_instance_valid(world.story_intro) and cards < 10:
		world.story_intro.advance()
		cards += 1
		await process_frame
	check(cards == 4 and not is_instance_valid(world.story_intro) and not paused, "story_has_four_cards_then_resumes")
	check(world.hud.banner_text == "賠掉的存款" and world.hud.dialogue_text.begins_with("美晴"), "story_end_announces_MAIN_001_with_dialogue")
	check(world.music.mode == "street", "gameplay_switches_to_street_music")
	world.is_test_mode = true
	world.set_process(false)
	world._process(0.016)
	var mei: Vector3 = world.targets["mei"]
	check(world.objective_beacon.has_target and world.objective_beacon.target_position.is_equal_approx(Vector3(mei.x, 0, mei.z)), "beacon_marks_current_objective")
	check(world.hud._distance_label.text.begins_with("▶"), "hud_shows_objective_distance")
	world._event("talk_mei", "mei")
	check(world.hud.toast_text == "✓ 目標完成", "objective_completion_pops_toast")
	world._process(0.016)
	var phone: Vector3 = world.targets["phone"]
	check(world.objective_beacon.target_position.is_equal_approx(Vector3(phone.x, 0, phone.z)), "beacon_follows_next_objective")
	world._event("read_phone", "phone")
	world._use_object("wrench")
	world._event("practice_hit", "practice_1")
	world._event("practice_hit", "practice_2")
	check(world.missions.mission_index == 1 and world.hud.get_chain_progress() == 1, "first_mission_breaks_first_chain_link")
	check("任務完成" in world.hud.toast_text and world.hud.banner_text == "假客服的門面", "mission_completion_toast_and_next_banner")
	var outcome: Dictionary = world._record_run("smash")
	check(outcome.has("grade") and outcome.has("progress") and not world.run_records.persist, "test_mode_run_record_not_persisted")
	world.hud.show_pause()
	world._process(0.016)
	check(world.music.ducked, "menus_duck_street_music")
	world._resume()
	world._process(0.016)
	check(not world.music.ducked, "resume_restores_music")
	for pair: Array in [[Vector2i(390, 844), "portrait"], [Vector2i(844, 390), "landscape"], [Vector2i(826, 340), "browser_landscape"]]:
		root.content_scale_size = pair[0]
		root.size = pair[0]
		world.device_profiles.set_profile("phone", false)
		world.touch_controls.set_enabled(true)
		world.touch_controls._layout()
		world.hud._resize_modal()
		world._process(0.016)
		await process_frame
		await process_frame
		var commands: Control = world.touch_controls.panels[2]
		var command_rect: Rect2 = commands.get_global_rect()
		var mission_rect: Rect2 = world.hud._mission_panel.get_global_rect()
		var prompt_rect: Rect2 = world.hud._prompt_panel.get_global_rect() if world.hud._prompt_panel.is_visible_in_tree() else Rect2()
		var sprint_rect: Rect2 = world.touch_controls._floating_sprint.get_global_rect()
		var screen: Rect2 = root.get_visible_rect()
		var sized: bool = true
		for button: Node in commands.get_children():
			sized = sized and (button as Button).size.x >= 44 and (button as Button).size.y >= 44
		print("R1_TOUCH_LAYOUT ", JSON.stringify({"viewport": str(pair[0]), "commands": str(command_rect), "mission": str(mission_rect), "prompt": str(prompt_rect), "sprint": str(sprint_rect)}))
		check(screen.encloses(command_rect) and sized, "phone_commands_on_screen_and_44px_" + str(pair[1]))
		check(not command_rect.intersects(mission_rect), "phone_commands_do_not_cover_mission_card_" + str(pair[1]))
		check(prompt_rect.size == Vector2.ZERO or not command_rect.intersects(prompt_rect), "phone_commands_do_not_cover_prompt_" + str(pair[1]))
		check(prompt_rect.size == Vector2.ZERO or not sprint_rect.intersects(prompt_rect), "prompt_does_not_cover_sprint_toggle_" + str(pair[1]))
		check(not sprint_rect.intersects(mission_rect), "mission_card_does_not_cover_sprint_toggle_" + str(pair[1]))
		check(not sprint_rect.intersects(world.touch_controls.joystick.get_global_rect()) and not sprint_rect.intersects(world.touch_controls.panels[1].get_global_rect()), "sprint_toggle_clear_of_joystick_and_actions_" + str(pair[1]))
		var center := Rect2(screen.size * Vector2(0.3, 0.35), screen.size * Vector2(0.4, 0.3))
		check(not command_rect.intersects(center), "phone_commands_leave_screen_centre_clear_" + str(pair[1]))
	world.touch_controls.set_enabled(false)
