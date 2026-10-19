extends SceneTree
## New interaction regressions: archive lifecycle and selected/unselected navigation.
const HUD = preload("res://scripts/ui/game_hud.gd")
const Case = preload("res://scripts/content/fraud_case.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("R5_FAIL " + label)
func settle() -> void:
	for i: int in 12: await process_frame
func run() -> void:
	var hud := HUD.new()
	root.add_child(hud)
	var data := Case.new()
	hud.bind_fraud_case(data)
	for size_value: Vector2i in [Vector2i(390,844),Vector2i(844,390),Vector2i(1032,1376),Vector2i(1366,600)]:
		root.size = size_value
		root.content_scale_size = size_value
		hud.set_device_profile({"profile":"phone" if size_value.x < 900 else "tablet"})
		data.stage = 2
		data.selected_claim = -1
		data.feedback = ""
		hud.show_fraud_case()
		await settle()
		var resume: Button = hud._return_footer.get_child(1)
		check(resume.disabled,"unselected_claim_cannot_continue")
		check(hud._return_footer.get_child(0).visible,"back_always_available")
		hud.fraud_panel.choose_claim(0)
		await settle()
		check(not resume.disabled,"selected_claim_can_resume")
		hud.fraud_panel.choose_proof(0)
		await settle()
		check(data.stage == 3,"correct_proof_still_advances")
		if size_value.y >= 600:
			check(hud._modal_box.get_node_or_null("EvidenceContradiction") != null,"contradiction_visible")
		hud.fraud_panel.choose_reason(0)
		await settle()
		check(data.stage == 4,"correct_conclusion_still_seals")
		check(not resume.visible,"no_duplicate_continue_after_seal")
		var seal := hud._modal_box.get_node_or_null("ArchiveSeal") as TextureRect
		if size_value.y >= 600:
			check(seal != null and seal.custom_minimum_size.y >= 120,"large_archive_seal")
			await create_timer(0.08,true).timeout
			check(not seal.scale.is_equal_approx(Vector2.ONE),"stamp_scale_survives_container_layout")
			await create_timer(0.42,true).timeout
			check(seal.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(seal.modulate.a,1.0),"stamp_finishes_while_menu_paused")
		hud.show_pause()
		await settle()
		check(resume.visible and not resume.disabled,"leaving_archive_restores_navigation")
		hud.hide_menus()
	hud.queue_free()
	await process_frame
	print("R5_ART_CHECKS=%d FAILURES=%d" % [checks,failures])
	quit(1 if failures else 0)
