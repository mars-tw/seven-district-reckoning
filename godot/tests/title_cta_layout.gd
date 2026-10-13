extends SceneTree

const HUDScript = preload("res://scripts/ui/game_hud.gd")
var failures: Array[String] = []
var starts := 0

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func _on_start() -> void:
	starts += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var hud: GameHUD = HUDScript.new()
	root.add_child(hud)
	hud.new_game_requested.connect(_on_start)
	hud.set_device_profile({"profile":"phone"})
	var layouts: Array[Vector2i] = [Vector2i(640,360),Vector2i(568,320),Vector2i(800,450),Vector2i(390,844),Vector2i(360,640),Vector2i(1024,768)]
	var bounds: Array[Dictionary] = []
	var full_scene_touch_started := false
	for logical_size: Vector2i in layouts:
		root.size = logical_size
		root.content_scale_size = logical_size
		await process_frame
		hud.show_title()
		await process_frame
		await process_frame
		var viewport: Vector2 = hud.get_viewport().get_visible_rect().size
		var button: Button = hud._title_start_button
		var rect: Rect2 = button.get_global_rect()
		var scroll: Rect2 = hud._modal_scroll.get_global_rect()
		check(viewport.is_equal_approx(Vector2(logical_size)),"viewport_"+str(logical_size))
		check(button.text=="開始新遊戲" and button.is_visible_in_tree() and not button.disabled and button.has_focus() and hud._title_footer.visible,"fixed_start_visible_focusable_"+str(logical_size))
		check(rect.size.x>=160 and rect.size.y>=48 and rect.position.x>=8 and rect.position.y>=8 and rect.end.x<=viewport.x-8 and rect.end.y<=viewport.y-8,"fixed_start_inside_viewport_"+str(logical_size))
		check(rect.position.y>=scroll.end.y-1,"fixed_start_outside_scroll_"+str(logical_size))
		var narrative := ""
		var secondary: Array[String] = []
		var last_secondary: Button
		for item: Node in hud._modal_box.get_children():
			if item is Label: narrative += (item as Label).text
			if item is Button:
				secondary.append((item as Button).text)
				last_secondary = item as Button
		check(narrative.contains("阿遠失去了存款") and narrative.contains("所有人物、公司與地點均為虛構"),"title_narrative_disclaimer_preserved_"+str(logical_size))
		check(secondary.has("讀取存檔") and secondary.has("畫面與操作設定") and secondary.has("離開遊戲") and not secondary.has("開始新遊戲"),"secondary_options_remain_scrollable_"+str(logical_size))
		if logical_size==Vector2i(640,360):
			last_secondary.grab_focus()
			await process_frame
			await process_frame
			var secondary_rect: Rect2 = last_secondary.get_global_rect()
			var scrolled_rect: Rect2 = hud._modal_scroll.get_global_rect()
			check(hud._modal_scroll.scroll_vertical>0 and secondary_rect.position.y>=scrolled_rect.position.y-1 and secondary_rect.end.y<=scrolled_rect.end.y+1,"focused_secondary_scrolls_into_view")
			hud.show_title()
			await process_frame
			check(hud._title_start_button.has_focus() and hud._title_start_button.is_visible_in_tree(),"title_restores_fixed_start_focus")
		bounds.append({"logical":[logical_size.x,logical_size.y],"actual":[viewport.x,viewport.y],"start":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"scrollEndY":scroll.end.y})
		hud.show_pause()
		await process_frame
		check(not hud._title_footer.visible and not button.is_visible_in_tree(),"footer_title_only_"+str(logical_size))
	# A real GUI pointer press on the fixed button invokes the original action.
	hud.show_title()
	await process_frame
	var center: Vector2 = hud._title_start_button.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = center
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = center
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
	check(starts==1 and not hud.is_menu_open(),"fixed_start_keeps_original_action")
	# The paused title also accepts the native indexed touch path.
	hud.show_title()
	await process_frame
	var old_mouse_emulation := Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = true
	center = hud._title_start_button.get_global_rect().get_center()
	var touch_down := InputEventScreenTouch.new()
	touch_down.index = 0
	touch_down.position = center
	touch_down.pressed = true
	Input.parse_input_event(touch_down)
	await process_frame
	var touch_up := InputEventScreenTouch.new()
	touch_up.index = 0
	touch_up.position = center
	touch_up.pressed = false
	Input.parse_input_event(touch_up)
	await process_frame
	Input.emulate_mouse_from_touch = old_mouse_emulation
	check(starts==2 and not hud.is_menu_open(),"fixed_start_accepts_native_touch")
	# The real game scene must wire that same footer action into playable state.
	hud.queue_free()
	await process_frame
	root.size = Vector2i(640,360)
	root.content_scale_size = Vector2i(640,360)
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	var core_frames := 0
	while not game.startup_complete and core_frames < 2000:
		await process_frame
		core_frames += 1
	check(game.startup_complete,"full_scene_core_ready_for_title_touch")
	if game.startup_complete:
		game.device_profiles.set_profile("phone",false)
		game.hud.show_title()
		await process_frame
		var full_button: Button = game.hud._title_start_button
		var full_rect: Rect2 = full_button.get_global_rect()
		check(full_button.is_visible_in_tree() and full_rect.position.y>=8 and full_rect.end.y<=360-8,"full_scene_phone_start_in_viewport")
		game.is_test_mode = true
		old_mouse_emulation = Input.emulate_mouse_from_touch
		Input.emulate_mouse_from_touch = true
		var down := InputEventScreenTouch.new()
		down.index = 0
		down.position = full_rect.get_center()
		down.pressed = true
		Input.parse_input_event(down)
		await process_frame
		var up := InputEventScreenTouch.new()
		up.index = 0
		up.position = full_rect.get_center()
		up.pressed = false
		Input.parse_input_event(up)
		await process_frame
		Input.emulate_mouse_from_touch = old_mouse_emulation
		full_scene_touch_started = game.play_started and not paused and game.visible
		check(full_scene_touch_started,"full_scene_phone_touch_starts_play")
		game.queue_free()
		await process_frame
	print("TITLE_CTA_LAYOUT_TEST "+JSON.stringify({"failures":failures,"layouts":bounds,"startRequests":starts,"fullSceneTouchStarted":full_scene_touch_started,"headless":true,"nativePixelsVerified":false}))
	quit(0 if failures.is_empty() else 1)
