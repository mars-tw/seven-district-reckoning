extends SceneTree
## Validate the actual person objective and dossier visibility without changing rules.
const HUD = preload("res://scripts/ui/game_hud.gd")
const Case = preload("res://scripts/content/fraud_case.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("R7_FAIL "+label)
func settle() -> void:
	for i: int in 12: await process_frame
func run() -> void:
	var hud := HUD.new()
	root.add_child(hud)
	var data := Case.new()
	hud.bind_fraud_case(data)
	for size_value: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(844,390),Vector2i(1032,1376),Vector2i(1366,600)]:
		root.size = size_value
		root.content_scale_size = size_value
		hud.set_device_profile({"profile":"phone" if size_value.x < 900 else "tablet"})
		data.stage = 2
		hud.show_fraud_case()
		await settle()
		check(not hud._hud.is_visible_in_tree(),"case_hides_all_game_hud")
		check(hud._dim.color.a == 1.0,"case_has_opaque_scrim")
		check(hud._modal_scroll.get_v_scroll_bar().self_modulate.a == 0.0,"stable_scroll_gutter_has_no_system_chrome")
		check(not hud._health_bar.visible and hud._stamina_bar.visible and hud._stamina_caption.text.begins_with("體力"),"one_bar_has_an_explicit_stamina_label")
		check(root.get_visible_rect().encloses(hud._return_footer.get_global_rect()),"footer_stays_reachable")
		hud.hide_menus()
		await settle()
		check(hud._hud.is_visible_in_tree(),"closing_case_restores_game_hud")
	hud.queue_free()
	await settle()
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i: int in 30000:
		await process_frame
		if scene.startup_complete and scene.expansion_complete:break
	check(scene.startup_complete,"world_ready")
	check(scene.player._spring_arm.position.x >= 0.5,"shoulder_camera_separates_person_silhouettes")
	var mei: Node3D = scene.contact_people[0]
	scene._update_guidance("mei")
	check(Vector2(scene.objective_beacon.target_position.x,scene.objective_beacon.target_position.z).distance_to(Vector2(mei.global_position.x,mei.global_position.z))<.01,"beacon_is_on_real_mei")
	check(scene.targets["mei"].is_equal_approx(mei.global_position),"mission_target_is_the_person")
	check(mei.find_child("MeiHeldWrench",true,false)!=null,"mei_holds_wrench")
	check(scene.find_child("MeiToolWorkbench",true,false)!=null,"authored_workbench_is_instantiated")
	scene.queue_free()
	await settle()
	print("R7_ART_CHECKS=%d FAILURES=%d" % [checks,failures])
	quit(1 if failures else 0)
