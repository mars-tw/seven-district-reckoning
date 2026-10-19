extends SceneTree
## Catch the actual clipping and empty annotation regressions from Muse R4.
const HUD = preload("res://scripts/ui/game_hud.gd")
const Case = preload("res://scripts/content/fraud_case.gd")
const Inspector = preload("res://scripts/ui/evidence_inspector.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("R8_FAIL "+label)
func settle() -> void:
	for i: int in 16: await process_frame
func run() -> void:
	var hud := HUD.new()
	root.add_child(hud)
	var data := Case.new()
	hud.bind_fraud_case(data)
	for screen: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(430,932),Vector2i(844,390),Vector2i(667,375),Vector2i(1032,1376),Vector2i(1376,1032),Vector2i(1366,600)]:
		root.size = screen
		root.content_scale_size = screen
		hud.set_device_profile({"profile":"phone" if screen.x<900 else "tablet"})
		data.stage = 2
		hud.show_fraud_case()
		await settle()
		var paper := hud._modal_panel.get_global_rect()
		for label: Node in hud._modal_box.find_children("*","Label",true,false):
			check(label.get_global_rect().position.x >= paper.position.x+40,"case_binding_safe_area")
		for name_value: String in ["InspectMessage","InspectReceipt"]:
			hud._modal_box.find_child(name_value,true,false).pressed.emit()
			await settle()
			var view: Node = hud._root.get_node("EvidenceInspector")
			var document: Rect2 = view._paper.get_global_rect()
			var back: Rect2 = view._close.get_global_rect()
			check(root.get_visible_rect().encloses(document),"document_in_view")
			check(not document.intersects(back),"return_does_not_cut_document")
			var circles := 0
			for label: Node in view.find_children("*","Label",true,false):
				if not label.is_visible_in_tree(): continue
				check(document.encloses(label.get_global_rect()),"every_evidence_label_inside_paper")
			for marker: Node in view.find_children("*","PanelContainer",true,false):
				if not marker is Inspector.MarkedField: continue
				var word: Label = marker.get_child(0)
				check(marker.size.x <= word.size.x+19,"highlight_matches_actual_word_width")
				if marker.circled:
					circles += 1
					check(word.text == "林○翔（個人）","circle_has_a_real_questioned_value")
			check(circles == (1 if view.receipt else 0),"no_empty_or_duplicate_circles")
			check(view.find_child("TransferReceipt" if view.receipt else "CustomerMessageBubble",true,false)!=null,"documents_have_distinct_structure")
			view._close.pressed.emit()
			await settle()
		hud.hide_menus()
		if screen.y >= 600:
			data.stage = 4
			hud.show_fraud_case()
			var title: Label = hud._modal_box.get_child(0)
			for delta: float in [0.05,0.08,0.19]:
				await create_timer(delta,true).timeout
				var seal: Control = hud._modal_box.get_node("ArchiveSeal")
				var applicator: Control = seal.get_node_or_null("StampApplicator")
				check(applicator != null,"real_stamp_present_during_reward_motion")
				if applicator:
					check(hud._modal_panel.get_global_rect().encloses(applicator.get_global_rect()),"moving_stamp_stays_on_paper")
					check(not applicator.get_global_rect().intersects(title.get_global_rect()),"moving_stamp_never_covers_heading")
			hud.hide_menus()
		hud.show_pause()
		await settle()
		check(not hud._modal_panel.get_node("DossierBinding").visible,"binding_does_not_leak_to_other_menus")
		hud.hide_menus()
	hud.queue_free()
	await settle()
	print("R8_ART_CHECKS=%d FAILURES=%d" % [checks,failures])
	quit(1 if failures else 0)
