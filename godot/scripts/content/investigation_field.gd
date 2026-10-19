extends Node3D
## A real-world source caption, visible only at the active field destination.
var manager: RefCounted
var host: Node3D
var caption: Label3D
var result_papers: Array[MeshInstance3D] = []
var result_root: Node3D
var replay_layer: CanvasLayer
var replay_mark: Label

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
	for i: int in 3:
		var original := MeshInstance3D.new()
		original.name = "RetainedOriginal"+str(i)
		var paper := QuadMesh.new(); paper.size = Vector2(.58,.8); original.mesh = paper
		var paper_material := StandardMaterial3D.new()
		paper_material.albedo_texture = load("res://assets/art/r4/case-paper.webp")
		paper_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		paper_material.roughness = 1
		original.material_override = paper_material
		original.position = Vector3((i-1)*.65,0,0)
		var ink := Label3D.new()
		ink.name = "OriginalInk"
		ink.font = load("res://assets/fonts/SevenDistrictSansTC-Regular.otf")
		ink.font_size = 32
		ink.pixel_size = .002
		ink.modulate = Color("16181d")
		ink.outline_size = 0
		ink.position.z = -.015
		ink.double_sided = true
		ink.billboard = BaseMaterial3D.BILLBOARD_ENABLED
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

func _process(_delta: float) -> void:
	var index: int = manager.pending()
	var result: Dictionary = manager.street_result()
	replay_layer.visible = result.get("replay",false)
	var at_source: bool = not result.is_empty() and host.player.global_position.distance_to(manager.result_position()) <= 6
	if manager.street_at_source != at_source:
		manager.street_at_source = at_source
		host.hud._refresh_mission()
	result_root.visible = not result.is_empty()
	if result_root.visible:
		var source_index: int = 2 if manager.active == "three_voices" else 0
		var pos: Array = manager.definition().documents[source_index].position
		result_root.position = Vector3(float(pos[0]),1.15,float(pos[1]))+host.player.get_camera().global_basis.x*.95+host.player.get_camera().global_basis.z*.4
		result_root.look_at(host.player.get_camera().global_position,Vector3.UP)
		for i: int in 3:
			result_papers[i].visible = i < int(result.count)
			if result_papers[i].visible:
				var ink: Label3D = result_papers[i].get_node("OriginalInk")
				ink.text = str(result.papers[i])+"\n原件\n已留存"
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
	return {"objects":visible_papers,"at":result_root.position,"visible":result_root.visible,"replay_mark":replay_layer.visible}
