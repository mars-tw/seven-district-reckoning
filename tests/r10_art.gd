extends SceneTree
## Muse R6 regressions: state ambiguity, duplicate exits, mixed stamps and empty paper.
const HUD = preload("res://scripts/ui/game_hud.gd")
const Case = preload("res://scripts/content/fraud_case.gd")
const Art = preload("res://scripts/ui/art_theme.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("R10_FAIL "+label)
func settle() -> void:
	for i: int in 16: await process_frame
func run() -> void:
	var hud := HUD.new()
	root.add_child(hud)
	var data := Case.new()
	hud.bind_fraud_case(data)
	for screen: Vector2i in [Vector2i(320,568),Vector2i(568,320),Vector2i(390,844),Vector2i(430,932),Vector2i(844,390),Vector2i(1024,768),Vector2i(1032,1376),Vector2i(1376,1032),Vector2i(1366,600)]:
		root.size = screen
		root.content_scale_size = screen
		hud.set_device_profile({"profile":"phone" if screen.x<900 else "tablet"})
		data.stage = 2
		data.selected_claim = -1
		hud.show_fraud_case()
		await settle()
		var gate: Label = hud._modal_content.get_node("CaseGateReason")
		check(gate.is_visible_in_tree() and gate.text.begins_with("尚缺"),"disabled_continue_explains_missing_step")
		check(root.get_visible_rect().encloses(gate.get_global_rect()),"missing_step_stays_above_reachable_footer")
		data.selected_claim = 0
		hud.show_fraud_case()
		await settle()
		for i: int in 3:
			var compare: Button = hud._modal_box.find_child("CompareProof%d" % i,true,false)
			check(compare.get_theme_stylebox("normal").bg_color != Art.AMBER,"pending_compare_is_never_selected_yellow")
			check(compare.get_theme_stylebox("focus").bg_color != Art.AMBER,"focus_does_not_mean_selected")
		for n: String in ["InspectMessage","InspectReceipt"]:
			hud._modal_box.find_child(n,true,false).pressed.emit()
			await settle()
			var view: Node = hud._root.get_node("EvidenceInspector")
			check(root.get_visible_rect().encloses(view._paper.get_global_rect()),"whole_document_stays_in_view")
			check(not view._paper.get_global_rect().intersects(view._close.get_global_rect()),"return_never_cuts_receipt_notes")
			var notes: Control = view.get_node_or_null("EvidenceCrossNotes")
			# Notes are inside the paper hierarchy, preserving the document/return contract.
			notes = view._notes
			if screen.y >= 650:
				check(notes.is_visible_in_tree(),"real_related_information_in_lower_paper")
				check(notes.get_global_rect().end.y > screen.y*.65,"notes_reach_lower_half")
				check(view._paper.get_global_rect().encloses(notes.get_global_rect()),"notes_inside_paper")
			if not view.receipt:
				var bubble: Control = view.find_child("CustomerMessageBubble",true,false)
				var quote: Label = bubble.get_child(0)
				check(quote.text.contains("\u2060"),"quoted_term_and_both_marks_are_unbreakable")
			view._close.pressed.emit()
			await settle()
		data.stage = 4
		hud.show_fraud_case()
		await create_timer(.13,true).timeout
		check(not hud._return_footer.get_child(0).visible and not hud._return_footer.get_child(1).visible,"one_return_action_after_sealing")
		check(hud._modal_box.find_child("ArchiveAdhesive",true,false)==null,"no_blank_animated_strip")
		if screen.y >= 600:
			var seal: TextureRect = hud._modal_box.get_node("ArchiveSeal")
			var moving: TextureRect = seal.get_node("StampApplicator")
			check(moving.texture == seal.texture,"exact_same_impression_in_motion_and_completion")
		hud.hide_menus()
		hud.show_pause()
		await settle()
		check(not hud._modal_content.get_node("CaseGateReason").visible,"case_reason_does_not_leak_into_pause")
		check(hud._return_footer.get_child(0).visible,"back_restored_in_other_menus")
		hud.hide_menus()
	hud.queue_free()
	await settle()
	print("R10_ART_CHECKS=%d FAILURES=%d" % [checks,failures])
	quit(1 if failures else 0)
