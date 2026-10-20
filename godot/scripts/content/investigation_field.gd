extends Node3D
## A real-world source caption, visible only at the active field destination.
var manager: RefCounted
var host: Node3D
var caption: Label3D
var result_papers: Array[MeshInstance3D] = []
var result_root: Node3D
var boundary_ink: Label3D
var replay_layer: CanvasLayer
var replay_mark: Label
var staged := ""
var staged_results: Dictionary = {}
var settlement_clock := 0.0
var settlement_phase := "before"

func setup(world: Node3D, data: RefCounted) -> void:
	host = world
	manager = data
	name = "InvestigationField"
	replay_layer = CanvasLayer.new()
	replay_layer.layer = 44
	add_child(replay_layer)
	var tint := ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(.42,.25,.05,.28)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	replay_layer.add_child(tint)
	replay_mark = Label.new()
	replay_mark.text = "分支回放\n不改封存紀錄"
	replay_mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	replay_mark.offset_left = -122; replay_mark.offset_right = 122
	replay_mark.offset_top = -205; replay_mark.offset_bottom = -135
	replay_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	replay_mark.add_theme_font_override("font",load("res://assets/fonts/SevenDistrictSansTC-Regular.otf"))
	replay_mark.add_theme_font_size_override("font_size",24)
	replay_mark.add_theme_color_override("font_color",Color("f1e8d5"))
	var stamp := StyleBoxFlat.new(); stamp.bg_color = Color("16181d"); stamp.border_color = Color("c4271c"); stamp.set_border_width_all(4)
	replay_mark.add_theme_stylebox_override("normal",stamp)
	replay_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	replay_layer.add_child(replay_mark)
	result_root = Node3D.new()
	result_root.name = "RetainedOriginals"
	add_child(result_root)
	var board := MeshInstance3D.new()
	board.name = "WallMountedArchiveBoard"
	var backing := BoxMesh.new(); backing.size = Vector3(4.05,1.08,.18)
	board.mesh = backing
	var backing_material := StandardMaterial3D.new()
	backing_material.albedo_texture = load("res://assets/art/r4/case-paper.webp")
	backing_material.albedo_color = Color("a78a61")
	backing_material.roughness = 1
	board.material_override = backing_material
	result_root.add_child(board)
	# Joinery, projecting side rails, two floor posts and cross feet.
	for part: Array in [
		[Vector3(-2.08,0,.05),Vector3(.14,1.25,.3)], [Vector3(2.08,0,.05),Vector3(.14,1.25,.3)],
		[Vector3(0,.60,.05),Vector3(4.3,.14,.3)], [Vector3(0,-.60,.05),Vector3(4.3,.14,.3)],
		[Vector3(-1.8,-1.7,0),Vector3(.13,3.4,.2)], [Vector3(1.8,-1.7,0),Vector3(.13,3.4,.2)],
		[Vector3(-1.8,-3.35,.1),Vector3(.5,.12,.85)], [Vector3(1.8,-3.35,.1),Vector3(.5,.12,.85)]]:
		var support := MeshInstance3D.new(); support.name = "ArchiveJoinery"
		var timber := BoxMesh.new(); timber.size = part[1]; support.mesh = timber; support.position = part[0]
		var finish := StandardMaterial3D.new(); finish.albedo_texture = backing_material.albedo_texture
		finish.albedo_color = Color("745332"); finish.roughness = .9; support.material_override = finish
		result_root.add_child(support)
	boundary_ink = Label3D.new()
	boundary_ink.name = "BoundaryNotOriginal"
	boundary_ink.text = "18：00\n分界\n非原件"
	boundary_ink.font = load("res://assets/fonts/SevenDistrictSansTC-Regular.otf")
	boundary_ink.font_size = 64; boundary_ink.pixel_size = .0032
	boundary_ink.position.z = .15; boundary_ink.outline_size = 0
	boundary_ink.modulate = Color("f1e8d5")
	result_root.add_child(boundary_ink)
	for i: int in 3:
		var original := MeshInstance3D.new()
		original.name = "RetainedOriginal"+str(i)
		var paper := QuadMesh.new(); paper.size = Vector2(1.18,.90); original.mesh = paper
		var paper_material := StandardMaterial3D.new()
		paper_material.albedo_texture = load("res://assets/art/r4/case-paper.webp")
		paper_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		paper_material.roughness = 1
		original.material_override = paper_material
		original.position = Vector3((i-1)*.65,0,0)
		var ink := Label3D.new()
		ink.name = "OriginalInk"
		ink.font = load("res://assets/fonts/SevenDistrictSansTC-Regular.otf")
		ink.font_size = 64
		ink.pixel_size = .0032
		ink.modulate = Color("16181d")
		ink.outline_size = 0
		ink.position.z = .015
		ink.double_sided = true
		ink.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		original.add_child(ink)
		result_root.add_child(original)
		result_papers.append(original)
	caption = Label3D.new()
	caption.font = load("res://assets/fonts/SevenDistrictSansTC-Regular.otf")
	caption.font_size = 26
	caption.pixel_size = 0.006
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.modulate = Color("f1e8d5")
	caption.outline_size = 7
	caption.visibility_range_end = 18
	add_child(caption)
	# Dedicated painted storefront surfaces sit in the existing 3D streets.
	# They are facade details, not replacement character or building models.
	for i: int in 3:
		var d: Dictionary = manager.definition("three_voices").documents[i]
		var center := Vector3(float(d.position[0]),0,float(d.position[1]))
		var front := MeshInstance3D.new()
		front.name = "InvestigationFront"+str(i)
		var plane := QuadMesh.new()
		plane.size = Vector2(6,4.5)
		front.mesh = plane
		front.position = center+Vector3(2.3,2.25,2.1)
		front.rotation.y = PI+atan2(2.0,1.8)
		var material := StandardMaterial3D.new()
		material.albedo_texture = load("res://assets/art/content-r4/street-fronts.webp")
		material.uv1_scale = Vector3(1.0/3.0,1,1)
		material.uv1_offset = Vector3(float(i)/3.0,0,0)
		material.roughness = .96
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		front.material_override = material
		front.visibility_range_end = 70
		add_child(front)
		var sign := Label3D.new()
		sign.name = "SiteSign"+str(i)
		sign.text = ["晨光市場","街角便利店","橘盒取件站"][i]
		sign.font = caption.font
		sign.font_size = 60
		sign.pixel_size = .009
		sign.position = center+Vector3(2.26,4.08,2.06)
		sign.rotation.y = front.rotation.y
		sign.modulate = Color("16181d")
		sign.outline_size = 0
		sign.double_sided = true
		sign.visibility_range_end = 70
		add_child(sign)

func _process(delta: float) -> void:
	var index: int = manager.pending()
	var result: Dictionary = manager.street_result()
	replay_layer.visible = result.get("replay",false)
	var at_source: bool = not result.is_empty() and host.player.global_position.distance_to(manager.result_position()) <= 6
	if manager.street_at_source != at_source:
		manager.street_at_source = at_source
		# Inspect nearby faces at native render scale; restore the selected
		# device budget when leaving. This changes actual gameplay rendering.
		get_viewport().scaling_3d_scale = 1.0 if at_source else float(host.device_profiles.get_settings().get("resolution_scale",1.0))
		host.hud._refresh_mission()
	result_root.visible = not result.is_empty()
	if result_root.visible:
		var key: String = manager.active+str(manager.entry().complete)
		if key != staged:
			staged = key
			settlement_clock = 2.0 if staged_results.has(key) or result.get("replay",false) else 0.0
			staged_results[key] = true
		settlement_clock = minf(2.0,settlement_clock+delta)
		settlement_phase = "after" if settlement_clock >= 2 else "during" if settlement_clock > .25 else "before"
		var source_index: int = 2 if manager.active == "three_voices" else 0
		var pos: Array = manager.definition().documents[source_index].position
		# Fixed storefront display: never follows the player or rotates with the camera.
		result_root.position = Vector3(float(pos[0])+.8,1.3,float(pos[1])+.8)+Vector3(-2.73,0,-1.03)
		result_root.scale = Vector3.ONE*.38
		result_root.rotation.y = 4.02
		boundary_ink.visible = manager.active == "three_voices"
		for i: int in 3:
			result_papers[i].visible = i < int(result.count)
			if result_papers[i].visible:
				var ink: Label3D = result_papers[i].get_node("OriginalInk")
				var x: float = (i-1)*1.3 if manager.active == "before_night" else (i-.5)*1.3
				if manager.active == "three_voices": x = -1.3 if i == 0 else 1.3
				result_papers[i].position = Vector3(x,0,.15)
				result_papers[i].rotation.z = 0
				ink.font_size = 72
				ink.text = (["甲承諾\n不收預付費","乙要求\n先付代辦費"][0 if result.papers[i] == "甲" else 1] if manager.active == "second_help" else ["甲 收據\n17：42","乙 摘要\n17：55","丙 輪值\n18：00"][i] if manager.active == "before_night" else ["17：50\n原件","18：10\n原件",""][i])
	if host.taiwan_world: host.taiwan_world.set_investigation_focus(index >= 0)
	# Source and person now live in the fixed dossier HUD. Floating captions
	# otherwise overlap each other and the character silhouette in portrait.
	caption.visible = false
	if not caption.visible: return
	var doc: Dictionary = manager.definition().documents[index]
	caption.global_position = manager.target_position()+Vector3.UP*2.4
	caption.text = "到現場｜"+doc.place+"\n"+doc.title+"・靠近互動留證"

func result_diagnostics() -> Dictionary:
	var visible_papers := 0
	for original: MeshInstance3D in result_papers:
		if original.is_visible_in_tree(): visible_papers += 1
	return {"objects":visible_papers,"at":result_root.position,"visible":result_root.visible,"replay_mark":replay_layer.visible,"settlement_phase":settlement_phase,"settlement_clock":settlement_clock,"paper_positions":result_papers.map(func(p: MeshInstance3D) -> Vector3: return p.position)}
