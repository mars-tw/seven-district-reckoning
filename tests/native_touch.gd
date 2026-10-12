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
	game.is_test_mode = true
	root.add_child(game)
	var wait_frames := 0
	while not game.startup_complete and wait_frames < 900:
		await process_frame
		wait_frames += 1
	check(game.startup_complete, "Native scene reaches the title before input checks")
	if not game.startup_complete:
		print("NATIVE_TOUCH_CHECKS=", checks, " FAILURES=", failures)
		quit(1)
		return
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
