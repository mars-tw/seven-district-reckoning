extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func run_checks() -> void:
	root.content_scale_size = Vector2i(390, 844)
	var game = MainScene.instantiate()
	root.add_child(game)
	# Startup streams the world in phases; two frames are not a readiness contract.
	var deadline := Time.get_ticks_msec() + 30000
	while not game.expansion_complete and Time.get_ticks_msec() < deadline:
		await process_frame
	check(game.expansion_complete and game.device_profiles != null, "Native world reaches its startup readiness contract")
	if not game.expansion_complete or game.device_profiles == null:
		print("NATIVE_TOUCH_CHECKS=", checks, " FAILURES=", failures)
		quit(1)
		return
	game.is_test_mode = true
	game.device_profiles.initialize(Vector2(390, 844), true, "phone", false)
	game.hud.new_game_requested.emit()
	await process_frame
	check(not OS.has_feature("web"), "Probe uses native Godot without JS controls")
	check(game.play_started and game.touch_controls.enabled, "Native title starts the real game with touch controls")
	check(ResourceLoader.exists("res://assets/fonts/SevenDistrictSansTC-Regular.otf"), "Bundled CJK font exists")
	var controls = game.touch_controls
	var start: Vector3 = game.player.global_position
	var press := InputEventScreenTouch.new()
	press.index = 42
	press.pressed = true
	press.position = controls.joystick_origin
	controls._input(press)
	var drag := InputEventScreenDrag.new()
	drag.index = 42
	drag.position = press.position + Vector2(48, 0)
	controls._input(drag)
	check(Input.get_action_strength("move_right") > .5, "Native joystick presses the original movement action")
	for frame in range(15):
		await physics_frame
	check(game.player.global_position.distance_to(start) > .2, "Real player physics responds to touch movement")
	controls.notification(NOTIFICATION_APPLICATION_PAUSED)
	check(not Input.is_action_pressed("move_right"), "Background releases held native input")
	var interact: Button
	for button in controls._action_buttons:
		if controls._action_buttons[button] == "interact": interact = button
	check(interact != null, "Native primary interact action button is present")
	press.position = interact.get_global_rect().get_center()
	controls._input(press)
	check(Input.is_action_pressed("interact"), "Touch action button reaches original interaction action")
	controls.release_all()
	check(not Input.is_action_pressed("interact"), "Primary action can be released")
	game.touch_controls.pause_requested.emit()
	check(paused, "Native pause command opens the real menu")
	game.hud.resume_requested.emit()
	check(not paused, "Native resume command works")
	print("NATIVE_TOUCH_CHECKS=", checks, " FAILURES=", failures)
	quit(1 if failures else 0)
