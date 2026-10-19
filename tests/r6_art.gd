extends SceneTree
## User-visible regressions: evidence inspection, touch density and seal sequence.
const HUD = preload("res://scripts/ui/game_hud.gd")
const Case = preload("res://scripts/content/fraud_case.gd")
const Touch = preload("res://scripts/ui/mobile_touch_controls.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("R6_FAIL "+label)
func settle() -> void:
	for i: int in 12: await process_frame
func run() -> void:
	var hud := HUD.new()
	root.add_child(hud)
	var data := Case.new()
	hud.bind_fraud_case(data)
	for screen: Vector2i in [Vector2i(390,844),Vector2i(844,390),Vector2i(1032,1376),Vector2i(1366,600)]:
		root.size = screen
		root.content_scale_size = screen
		hud.set_device_profile({"profile":"phone" if screen.x < 900 else "tablet"})
		data.stage = 2
		data.selected_claim = -1
		hud.show_fraud_case()
		await settle()
		for name_value: String in ["InspectMessage","InspectReceipt"]:
			var photo := hud._modal_box.find_child(name_value,true,false) as Button
			check(photo != null and photo.size.x >= 44 and photo.size.y >= 44,"photograph_is_tappable")
			photo.pressed.emit()
			await settle()
			var inspector := hud._root.get_node("EvidenceInspector") as Control
			check(root.get_visible_rect().encloses(inspector._paper.get_global_rect()),"inspection_document_in_view")
			check(root.get_visible_rect().encloses(inspector._close.get_global_rect()),"inspection_return_in_view")
			check(not inspector._paper.get_global_rect().intersects(inspector._close.get_global_rect()),"document_and_return_do_not_overlap")
			var words := ""
			for label: Node in inspector.find_children("*","Label",true,false): words += label.text
			check(("林○翔（個人）" in words and "上週五 14：32" in words and "三十八萬元" in words) if inspector.receipt else "恆曜公司專戶" in words,"fictional_fields_exact")
			check(data.stage == 2 and data.selected_claim == -1,"inspection_does_not_mutate_investigation")
			inspector._close.pressed.emit()
			await settle()
			check(hud._root.get_node_or_null("EvidenceInspector") == null,"return_closes_inspection")
			var focused := root.gui_get_focus_owner()
			check(focused is Button and hud._modal_box.is_ancestor_of(focused) and not focused.has_meta("evidence_photo"),"return_restores_primary_choice_focus")
		hud.hide_menus()
		paused = false
		var touch := Touch.new()
		root.add_child(touch)
		touch.set_profile({"profile":"phone","touch_button_size":54})
		touch.set_enabled(true)
		await settle()
		var commands := 0
		for node: Node in touch.panels[2].get_children():
			if node is Button and node.visible: commands += 1
		check(commands == 3,"only_three_street_commands")
		for context: Array in [[false,false,2],[true,false,4],[false,true,4]]:
			touch.set_action_context(context[0],context[1])
			await settle()
			var visible := 0
			for b: Button in touch._action_buttons:
				if b.is_visible_in_tree():
					visible += 1
					check(root.get_visible_rect().encloses(b.get_global_rect()) and b.size.x >= 44 and b.size.y >= 44,"context_action_reachable")
			check(visible == context[2],"context_shows_only_relevant_actions")
		touch.queue_free()
		await settle()
	hud.queue_free()
	await process_frame
	print("R6_ART_CHECKS=%d FAILURES=%d" % [checks,failures])
	quit(1 if failures else 0)
