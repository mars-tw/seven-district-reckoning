extends SceneTree
## Muse R5: continuous paper, separate compare tabs and solid portrait crops.
const HUD = preload("res://scripts/ui/game_hud.gd")
const Case = preload("res://scripts/content/fraud_case.gd")
const Intro = preload("res://scripts/ui/story_intro.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("R9_FAIL "+label)
func settle() -> void:
	for i: int in 16: await process_frame
func run() -> void:
	var hud := HUD.new()
	root.add_child(hud)
	var data := Case.new()
	hud.bind_fraud_case(data)
	for screen: Vector2i in [Vector2i(320,568),Vector2i(568,320),Vector2i(390,844),Vector2i(430,932),Vector2i(844,390),Vector2i(1032,1376),Vector2i(1376,1032),Vector2i(1366,600)]:
		root.size = screen
		root.content_scale_size = screen
		hud.set_device_profile({"profile":"phone" if screen.x<900 else "tablet"})
		data.stage = 2
		data.selected_claim = 0
		hud.show_fraud_case()
		await settle()
		var facts: Node = hud._modal_box.get_node("EvidenceFactList")
		check(facts != null,"proofs_use_a_document_list")
		for i: int in 3:
			var b := facts.find_child("CompareProof%d" % i,true,false) as Button
			check(b.text == Case.PROOFS[i],"original_evidence_semantics_retained")
			check(b.size.x < 70 and b.size.y >= 44,"compare_tab_is_separate_and_reachable")
			check(b.size.y <= 60,"hidden_accessibility_text_does_not_create_tall_rows")
			check(b.get_parent().get_child(0) is Label and b.get_parent().get_child(1) is Label,"caption_and_value_are_plain_labels")
		for name_value: String in ["InspectMessage","InspectReceipt"]:
			hud._modal_box.find_child(name_value,true,false).pressed.emit()
			await settle()
			var v: Node = hud._root.get_node("EvidenceInspector")
			var paper: Rect2 = v._paper.get_global_rect()
			var footer: Rect2 = v.get_node("PaperFooter").get_global_rect()
			var black_height: float = paper.position.y+screen.y-footer.end.y
			check(black_height/float(screen.y) <= .10,"black_height_at_most_ten_percent")
			check(absf(footer.position.y-paper.end.y) <= 1.1,"footer_connected_to_document")
			check(footer.encloses(v._close.get_global_rect()),"return_is_on_paper_footer")
			v._close.pressed.emit()
			await settle()
		hud.hide_menus()
		var intro := Intro.new()
		root.add_child(intro)
		intro.advance();intro.advance();intro.advance()
		await settle()
		check(intro._portrait.material == null,"no_dissolving_shader")
		check(intro._portrait_frame.clip_contents,"portrait_has_a_real_crop_boundary")
		check(root.get_visible_rect().encloses(intro._column.get_global_rect()),"waist_portrait_and_dialogue_fit")
		intro.queue_free()
		await settle()
	hud.queue_free()
	await settle()
	var actor: Node3D = (load("res://assets/models/r9/mei_human.glb") as PackedScene).instantiate()
	root.add_child(actor)
	var animation: AnimationPlayer = actor.find_children("*","AnimationPlayer",true,false)[0]
	animation.play("idle")
	animation.advance(0.2)
	preload("res://scripts/world/opening_street.gd").dress_mei(actor)
	await settle()
	var wrench := actor.find_child("MeiHeldWrench",true,false) as Node3D
	check(wrench.global_basis.y.normalized().dot(Vector3.UP) > 0.8,"bent_elbow_wrench_points_up_clear_of_courier")
	actor.queue_free()
	await settle()
	print("R9_ART_CHECKS=%d FAILURES=%d" % [checks,failures])
	quit(1 if failures else 0)
