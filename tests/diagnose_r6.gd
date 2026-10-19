extends SceneTree
func _initialize(): call_deferred("run")
func run():
 root.size=Vector2i(390,844)
 root.content_scale_size=root.size
 var hud=load("res://scripts/ui/game_hud.gd").new()
 root.add_child(hud)
 var data=load("res://scripts/content/fraud_case.gd").new()
 data.stage=2
 hud.bind_fraud_case(data)
 hud.show_fraud_case()
 for i in 12: await process_frame
 hud.fraud_panel.inspect(true)
 for i in 12: await process_frame
 var view=hud._root.get_node("EvidenceInspector")
 print("DIAG paper=",view._paper.get_global_rect()," minimum=",view._paper.get_combined_minimum_size()," stylemin=",view._paper.get_theme_stylebox("panel").get_minimum_size()," column=",view._column.get_combined_minimum_size()," close=",view._close.get_global_rect()," paused=",paused)
 var touch=load("res://scripts/ui/mobile_touch_controls.gd").new()
 root.add_child(touch)
 touch.set_profile({"profile":"phone","touch_button_size":54})
 touch.set_enabled(true)
 for i in 12: await process_frame
 print("DIAG touch enabled=",touch.enabled," controls=",touch.controls.visible," paused=",paused)
 quit()
