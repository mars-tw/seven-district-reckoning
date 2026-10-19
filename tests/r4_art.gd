extends SceneTree
## R4 checks real UI resources, layout, responsive controls and story portraits.
const HUD = preload("res://scripts/ui/game_hud.gd")
const Case = preload("res://scripts/content/fraud_case.gd")
const Intro = preload("res://scripts/ui/story_intro.gd")
const Art = preload("res://scripts/ui/art_theme.gd")
var checks := 0
var failures := 0
var layouts: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("R4_FAIL " + label)

func settle() -> void:
	for i: int in 8: await process_frame

func check_buttons(hud: CanvasLayer, screen: Vector2i, page: String) -> void:
	var used: Array[Rect2] = []
	for node: Node in hud._root.find_children("*","Button",true,false):
		var b := node as Button
		if not b.is_visible_in_tree(): continue
		var rect := b.get_global_rect()
		check(rect.size.x >= 44 and rect.size.y >= 44,page+"_44px_"+b.text)
		check(Rect2(Vector2.ZERO,Vector2(screen)).encloses(rect),page+"_in_view_"+b.text)
		if hud._modal_box.is_ancestor_of(b): check(hud._modal_scroll.get_global_rect().encloses(rect),page+"_no_scroll_"+b.text)
		for other: Rect2 in used: check(not rect.intersects(other),page+"_nonoverlap_"+b.text)
		used.append(rect)

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/r4/manifest.json"))
	check(manifest.generated_master_count == 10 and manifest.runtime_image_count == 13,"asset_inventory_not_placeholder")
	for record: Dictionary in manifest.outputs:
		var path: String = "res://" + str(record.path).trim_prefix("godot/")
		var tex := load(path) as Texture2D
		check(tex != null and tex.get_width() == int(record["size"][0]) and tex.get_height() == int(record["size"][1]),"imported_"+str(record.id))
		if record.has("character_gate"): check(record["character_gate"]["pass"],"portrait_dual_gate_"+str(record.id))
	var hud := HUD.new()
	root.add_child(hud)
	var data := Case.new()
	hud.bind_fraud_case(data)
	for screen: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(844,390),Vector2i(768,1024),Vector2i(1024,768),Vector2i(1366,600),Vector2i(1280,640),Vector2i(1920,1080),Vector2i(430,932),Vector2i(1032,1376)]:
		root.size = screen
		root.content_scale_size = screen
		hud.set_device_profile({"profile":"phone" if screen.x < 700 or screen.y < 500 else "tablet"})
		hud.show_title()
		await settle()
		check(hud._title_art.visible and hud._title_art.texture != null,"title_uses_illustration_"+str(screen))
		check(hud._title_start_button.has_focus(),"title_focus_"+str(screen))
		check_buttons(hud,screen,"title_"+str(screen))
		for stage: int in 5:
			data.stage = stage
			data.selected_claim = -1
			data.feedback = ""
			hud.show_fraud_case()
			await settle()
			check(hud._modal_panel.get_theme_stylebox("panel") is StyleBoxTexture,"case_uses_real_paper")
			check_buttons(hud,screen,"case_"+str(screen)+"_"+str(stage))
			for node: Node in hud._modal_box.find_children("*","Label",true,false):
				check(not "按 E" in node.text and not "WASD" in node.text,"mobile_case_has_no_keyboard_instruction")
		layouts.append({"logical_size":[screen.x,screen.y],"title_start":str(hud._title_start_button.get_global_rect()),"native_pixels_verified":false})
		hud.hide_menus()
	hud.queue_free()
	await process_frame
	for screen: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(844,390),Vector2i(768,1024)]:
		root.size = screen
		root.content_scale_size = screen
		var intro := Intro.new()
		root.add_child(intro)
		for card: int in 4:
			await settle()
			check(intro._portrait.texture == Art.texture("meiqing-portrait" if card == 3 else "ayuan-portrait"),"speaker_identity_"+str(card))
			check(Rect2(Vector2.ZERO,Vector2(screen)).encloses(intro._column.get_global_rect()),"intro_content_in_view_"+str(screen)+"_"+str(card))
			if card < 3: intro.advance()
		intro.queue_free()
		await process_frame
	print("R4_ART_LAYOUTS ",JSON.stringify(layouts))
	print("R4_ART_CHECKS=",checks," FAILURES=",failures)
	quit(1 if failures else 0)
