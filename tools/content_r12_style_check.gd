extends SceneTree
## Verify the actual shared Godot styles, not a copied CSS interpretation.
const Dossier = preload("res://scripts/ui/investigation_panel.gd")
const Art = preload("res://scripts/ui/art_theme.gd")

func _initialize() -> void:
	var panel := Dossier.new()
	var styles: Dictionary = {}
	for state: String in ["selected","wrong","correct"]:
		var b := Button.new(); b.text = "測試判定"
		Art.skin_button(b,false)
		panel.selected(b,true)
		if state == "wrong": panel.wrong_choice(b,true)
		if state == "correct": panel.checked_choice(b,true)
		var box: StyleBoxFlat = b.get_theme_stylebox("normal")
		assert(box.bg_color == Art.PAPER)
		assert(box.border_color == (Art.RED if state == "wrong" else Art.CHARCOAL))
		assert(box.border_width_left == (6 if state == "correct" else 3))
		assert(box.border_width_right == 3)
		assert(b.get_theme_color("font_color") == (Art.RED if state == "wrong" else Art.CHARCOAL))
		assert(b.text.begins_with("你選的｜") == (state == "wrong"))
		styles[state] = {"background":box.bg_color.to_html(),"border":box.border_color.to_html(),"left":box.border_width_left,"right":box.border_width_right,"text_color":b.get_theme_color("font_color").to_html()}
		b.free()
	panel.free()
	print("CONTENT_R12_STYLES "+JSON.stringify({"status":"VERIFIED","checks":18,"styles":styles}))
	quit()
