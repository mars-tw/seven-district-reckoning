extends SceneTree
## Exercise layout convergence, including the scrollbar threshold and rotations.
const HUD = preload("res://scripts/ui/game_hud.gd")
const Case = preload("res://scripts/content/fraud_case.gd")
const Intro = preload("res://scripts/ui/story_intro.gd")
var checks := 0
var failures := 0
var observations: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("R4_1_FAIL " + label)
func settle() -> void:
	for i: int in 12: await process_frame

func run() -> void:
	var hud := HUD.new()
	root.add_child(hud)
	var data := Case.new()
	hud.bind_fraud_case(data)
	for screen: Vector2i in [Vector2i(430,932),Vector2i(390,844),Vector2i(320,568),Vector2i(932,430),Vector2i(768,1024),Vector2i(1024,768),Vector2i(1032,1376),Vector2i(1376,1032),Vector2i(430,932)]:
		root.size = screen
		root.content_scale_size = screen
		var tablet := screen.x >= 700 and screen.y >= 600
		hud.set_device_profile({"profile":"tablet" if tablet else "phone"})
		for stage: int in 5:
			for repeat: int in 3:
				data.stage = stage
				data.selected_claim = repeat - 1 if stage == 2 else -1
				data.feedback = "這項紀錄還無法支持判斷，請再核對。" if repeat == 2 else ""
				var old_resize: int = hud.modal_resize_count
				var old_sorts: int = hud.modal_sort_count
				hud.show_fraud_case()
				await settle()
				check(hud.modal_resize_count - old_resize <= 3,"bounded_explicit_resize")
				check(hud.modal_sort_count - old_sorts <= 24 and hud.modal_sort_peak <= 32,"bounded_deferred_container_sort")
				var stable_sorts: int = hud.modal_sort_count
				var stable_rect: Rect2 = hud._modal_box.get_global_rect()
				await settle()
				check(hud.modal_sort_count == stable_sorts and hud._modal_box.get_global_rect() == stable_rect,"settled_without_background_reflow")
				check(Rect2(Vector2.ZERO,Vector2(screen)).encloses(hud._modal_panel.get_global_rect()),"case_within_view")
				# A scrollbar becoming necessary must not change the text wrapping width.
				var width: float = hud._modal_box.size.x
				var spacer := Control.new()
				spacer.custom_minimum_size.y = 1400
				hud._modal_box.add_child(spacer)
				await settle()
				check(hud._modal_box.size.x == width,"overflow_does_not_change_wrap_width")
				hud._modal_box.remove_child(spacer)
				spacer.queue_free()
				await settle()
				check(hud._modal_box.size.x == width,"short_content_keeps_same_gutter")
				if tablet: check(hud._modal_panel.size.x >= screen.x * 0.80,"tablet_case_uses_available_width")
		observations.append({"size":[screen.x,screen.y],"layout":hud.layout_diagnostics()})
		hud.hide_menus()
		if tablet:
			var intro := Intro.new()
			root.add_child(intro)
			for card: int in 4:
				await settle()
				check(intro._column.size.x >= screen.x * 0.80,"tablet_dialogue_width")
				check(Rect2(Vector2.ZERO,Vector2(screen)).encloses(intro._column.get_global_rect()),"tablet_dialogue_in_view")
				if card < 3: intro.advance()
			intro.queue_free()
			await process_frame
	hud.queue_free()
	await process_frame
	print("R4_1_LAYOUTS ",JSON.stringify(observations))
	print("R4_1_RESIZE_CHECKS=",checks," FAILURES=",failures)
	quit(1 if failures else 0)
