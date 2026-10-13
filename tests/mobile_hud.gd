extends SceneTree

const HUDScript = preload("res://scripts/ui/game_hud.gd")
const TouchScript = preload("res://scripts/ui/touch_controls.gd")

class MissionFixture extends Node:
	signal updated
	var scores := {"evidence_score": 8, "community_trust": 55, "rescued_count": 2}
	var parts_vouchers := 3
	var notice := ""
	var objective := "到車店找美晴，按 E 交談。"
	func get_current_title() -> String: return "MAIN-001　賠掉的存款"
	func get_objective_text() -> String: return objective

class OptionalFixture extends Node:
	signal updated
	var status := "idle"
	var wallet := 0
	func get_active_text() -> String: return "幫街坊把急用物資送到指定地點。"

class SystemsFixture extends Node:
	func get_status() -> Dictionary: return {"credits": 120, "rank": 1}

var checks := 0
var failures := 0
var hud: GameHUD
var touches: TouchControls
var missions: MissionFixture
var optional: OptionalFixture

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)

func _settle() -> void:
	await process_frame
	await process_frame

func _set_size(value: Vector2i) -> void:
	root.content_scale_size = value
	root.size = value
	await _settle()

func _mission_rect() -> Rect2:
	return (hud._mission_padding.get_parent() as Control).get_global_rect()

func _run() -> void:
	await _set_size(Vector2i(853, 480))
	missions = MissionFixture.new()
	optional = OptionalFixture.new()
	var systems := SystemsFixture.new()
	root.add_child(missions)
	root.add_child(optional)
	root.add_child(systems)
	hud = HUDScript.new()
	root.add_child(hud)
	touches = TouchScript.new()
	root.add_child(touches)
	hud.bind_missions(missions)
	hud.bind_optional(optional)
	hud.bind_systems(systems, null)
	hud.set_device_profile({"profile": "phone"})
	hud.set_touch_input_enabled(true)
	hud.update_status(84.0, "wrench", 2, "", "靠近美晴，按「互動」交談。")
	hud.update_survival(72.0, 100.0, "18:13", true)
	touches.set_profile("phone")
	touches.set_enabled(true)
	touches.set_safe_insets(Vector4(12, 20, 12, 20))
	touches._layout()
	await _settle()
	var mission := _mission_rect()
	var command := touches.panels[2].get_global_rect()
	var objective := "到車店找美晴，按「互動」交談。"
	check(hud._mission_grid.columns == 2, "phone_landscape_uses_two_column_mission_card")
	check(hud.get_display_objective_text() == objective and hud._objective_label.max_lines_visible == -1, "full_touch_objective_preserved")
	check(hud._objective_label.get_visible_line_count() == hud._objective_label.get_line_count(), "objective_lines_not_clipped")
	check(hud._scores_label.is_visible_in_tree() and hud._optional_label.is_visible_in_tree(), "scores_and_optional_status_remain_visible")
	check(hud._survival_label.is_visible_in_tree() and hud._stamina_bar.is_visible_in_tree() and hud._survival_label.text.contains("體力 72／100"), "survival_status_and_bar_remain_visible")
	check(hud._compact_status_label.is_visible_in_tree() and hud._compact_status_label.text.contains("安全值 84／100") and hud._compact_status_label.text.contains("警戒 2／5"), "safety_weapon_heat_status_visible")
	check(hud._compact_prompt_label.is_visible_in_tree() and hud._compact_prompt_label.text.contains("互動") and not hud._prompt_panel.visible, "action_prompt_moves_to_top_without_bottom_overlay")
	check(mission.end.y <= command.position.y - 4 and mission.size.y <= 150, "phone_853x480_world_gap_above_touch_commands")
	check(hud._objective_label.get_global_rect().end.y <= mission.end.y and hud._compact_status_label.get_global_rect().end.y <= mission.end.y, "all_key_labels_inside_card")
	check(touches.panels[2].visible and touches.panels[1].visible and touches.joystick.visible, "phone_action_controls_remain_available")
	print("HUD_LAYOUT_EVIDENCE ", JSON.stringify({"size": "853x480", "mission": str(mission), "command": str(command)}))
	hud.set_touch_input_enabled(false)
	await _settle()
	check(hud.get_display_objective_text() == "到車店找美晴，按 E 交談。" and hud._prompt_panel.visible and hud._controls_hint.is_visible_in_tree(), "keyboard_fallback_restores_objective_and_controls")
	check(hud._status_label.is_visible_in_tree() and not hud._compact_prompt_label.visible, "keyboard_fallback_shows_safety_without_stale_touch_prompt")
	hud.set_touch_input_enabled(true)
	await _settle()
	check(hud.get_display_objective_text() == objective and hud._compact_prompt_label.is_visible_in_tree() and not hud._prompt_panel.visible, "touch_fallback_restores_compact_prompt")

	var long_objective := "帶兩名受困者到標示「安全集合點」的位置；人到場才算救出。"
	missions.objective = long_objective
	missions.updated.emit()
	optional.status = "active"
	optional.updated.emit()
	await _settle()
	check(hud.get_display_objective_text() == long_objective and hud._objective_label.get_visible_line_count() == hud._objective_label.get_line_count(), "long_objective_is_fully_wrapped")
	check(hud._optional_label.text.contains(optional.get_active_text()) and hud._optional_label.is_visible_in_tree(), "active_optional_task_is_not_discarded")

	await _set_size(Vector2i(844, 390))
	touches._layout()
	await _settle()
	check(hud._mission_grid.columns == 2 and hud._compact_status_label.is_visible_in_tree(), "short_landscape_keeps_full_compact_status")
	check(_mission_rect().end.y <= touches.panels[2].get_global_rect().position.y - 4, "long_objective_and_active_task_clear_short_landscape_commands")
	print("HUD_LAYOUT_EVIDENCE ", JSON.stringify({"size": "844x390", "mission": str(_mission_rect()), "command": str(touches.panels[2].get_global_rect())}))
	for small_size: Vector2i in [Vector2i(640, 360), Vector2i(568, 320)]:
		await _set_size(small_size)
		touches._layout()
		await _settle()
		check(hud._mission_grid.columns == 2 and _mission_rect().end.y <= touches.panels[2].get_global_rect().position.y - 4, "small_phone_landscape_keeps_mission_above_commands_" + str(small_size))
		check(hud.get_display_objective_text() == long_objective and hud._compact_status_label.is_visible_in_tree(), "small_phone_landscape_keeps_objective_and_status_" + str(small_size))
		print("HUD_LAYOUT_EVIDENCE ", JSON.stringify({"size": str(small_size), "mission": str(_mission_rect()), "command": str(touches.panels[2].get_global_rect())}))

	await _set_size(Vector2i(390, 844))
	hud.set_device_profile({"profile": "phone"})
	await _settle()
	check(hud._mission_grid.columns == 1 and not hud._compact_status_label.visible and hud._prompt_panel.visible, "portrait_restores_stacked_hud")
	check(hud.get_display_objective_text() == long_objective, "portrait_keeps_full_objective")

	await _set_size(Vector2i(1280, 720))
	hud.set_device_profile({"profile": "desktop"})
	hud.set_touch_input_enabled(false)
	await _settle()
	check(hud._mission_grid.columns == 1 and hud._map_panel.visible and hud._scores_label.visible, "desktop_1280x720_retains_expanded_layout")
	check(hud._prompt_panel.visible and not hud._compact_prompt_label.visible, "desktop_prompt_stays_in_bottom_panel")

	print("MOBILE_HUD_CHECKS=", checks, " FAILURES=", failures)
	quit(0 if failures == 0 else 1)
