extends SceneTree
## Bounded, genuinely headless capability probe. Never fabricate screenshots.
func _initialize() -> void:
	call_deferred("probe")

func probe() -> void:
	root.size = Vector2i(390, 844)
	var hud = load("res://scripts/ui/game_hud.gd").new()
	root.add_child(hud)
	hud.show_title()
	for i: int in 5: await process_frame
	var driver := RenderingServer.get_current_rendering_driver_name()
	var result := {"status": "BLOCKED", "display": DisplayServer.get_name(), "driver": driver,
		"reason": "Godot headless dummy renderer does not render pixels. Browser and windowed capture are outside this task's authorization.",
		"requested_sizes": [[1290,2796],[2064,2752]], "screenshots_written": 0}
	if DisplayServer.get_name() != "headless":
		var texture := root.get_texture()
		if texture:
			var img := texture.get_image()
			if img and not img.is_empty():
				result["status"] = "EXECUTED"
				result["reason"] = "A non-dummy headless backend is available; full capture still required."
	print("ART_CAPTURE_RESULT ", JSON.stringify(result))
	hud.queue_free()
	await process_frame
	quit()
