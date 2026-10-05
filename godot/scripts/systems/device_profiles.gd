class_name DeviceProfiles
extends Node

## Device preferences are intentionally not part of a street/campaign save.
## A desktop save imported on a phone cannot overwrite its render/input budget.
signal profile_changed(settings: Dictionary)

const DATA_PATH := "res://data/device_profiles.json"
const PROFILES := ["phone", "tablet", "desktop"]
const PREF_KEYS := ["resolution_scale", "muted", "sensitivity", "sprint_toggle"]
var settings_path := "user://device-preferences-v1.cfg"
var _profiles: Dictionary = {}
var _profile := "desktop"
var _requested := "auto"
var _hardware := "desktop"
var _preferences: Dictionary = {}
var _scene: Node
var _focus: Node3D
var _ambient: Array[Node3D] = []
var _traffic: Array[Node3D] = []
var _budget_clock := 0.0
var _config := ConfigFile.new()

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		for key: String in PROFILES:
			_profiles[key] = parsed.get(key, {}).duplicate(true)

static func classify(viewport: Vector2, pointer_touch: bool, device_hint: String = "") -> String:
	var hint := device_hint.to_lower()
	if hint in PROFILES: return hint
	# A touch-enabled Windows laptop keeps mouse/keyboard controls. Browser callers
	# should supply pointer:coarse, not maxTouchPoints, when no mobile hint exists.
	if hint in ["windows", "macos", "linux", "pc"]: return "desktop"
	if not pointer_touch: return "desktop"
	return "phone" if minf(viewport.x, viewport.y) < 600.0 else "tablet"

func initialize(viewport: Vector2, pointer_touch: bool, device_hint: String = "", load_preferences: bool = true) -> void:
	_hardware = classify(viewport, pointer_touch, device_hint)
	if load_preferences: _config.load(settings_path)
	var saved := str(_config.get_value("device_" + _hardware, "requested_profile", "auto"))
	_requested = saved if saved in PROFILES or saved == "auto" else "auto"
	_activate(_hardware if _requested == "auto" else _requested)

func set_profile(value: String, persist: bool = true) -> bool:
	if value not in PROFILES and value != "auto": return false
	_requested = value
	_activate(_hardware if value == "auto" else value)
	if persist:
		_config.set_value("device_" + _hardware, "requested_profile", value)
		_config.save(settings_path)
	return true

func get_profile() -> String: return _profile
func get_requested_profile() -> String: return _requested
func get_hardware_profile() -> String: return _hardware

func get_settings() -> Dictionary:
	var result: Dictionary = _profiles.get(_profile, {}).duplicate(true)
	result.merge(_preferences, true)
	result["profile"] = _profile
	result["requested_profile"] = _requested
	return result

func set_preference(key: String, value: Variant, persist: bool = true) -> bool:
	if key not in PREF_KEYS: return false
	if key == "resolution_scale" and (value is not float and value is not int or not is_finite(float(value)) or float(value) < 0.5 or float(value) > 1.0): return false
	if key == "sensitivity" and (value is not float and value is not int or not is_finite(float(value)) or float(value) < 0.5 or float(value) > 2.0): return false
	if key in ["muted", "sprint_toggle"] and value is not bool: return false
	_preferences[key] = value
	if persist:
		_config.set_value("profile_" + _profile, key, value)
		_config.save(settings_path)
	if is_instance_valid(_scene): apply_scene(_scene, _focus)
	profile_changed.emit(get_settings())
	return true

func _activate(value: String) -> void:
	_profile = value
	_preferences.clear()
	for key: String in PREF_KEYS:
		if _config.has_section_key("profile_" + value, key):
			var stored: Variant = _config.get_value("profile_" + value, key)
			# Stored files receive the same whitelist/type validation as menu input.
			if key in ["muted", "sprint_toggle"] and stored is bool: _preferences[key] = stored
			elif key == "resolution_scale" and (stored is float or stored is int) and is_finite(float(stored)) and float(stored) >= .5 and float(stored) <= 1: _preferences[key] = float(stored)
			elif key == "sensitivity" and (stored is float or stored is int) and is_finite(float(stored)) and float(stored) >= .5 and float(stored) <= 2: _preferences[key] = float(stored)
	if is_instance_valid(_scene): apply_scene(_scene, _focus)
	profile_changed.emit(get_settings())

func apply_scene(scene: Node, focus: Node3D = null) -> void:
	_scene = scene
	_focus = focus
	var settings := get_settings()
	var viewport := scene.get_viewport()
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = float(settings.get("resolution_scale", 1.0))
	viewport.mesh_lod_threshold = float(settings.get("lod_threshold", 1.0))
	_ambient.clear()
	_traffic.clear()
	_apply_node(scene, settings, false)
	if scene.is_inside_tree():
		for actor: Node in scene.get_tree().get_nodes_in_group("ambient_citizens"):
			if actor is Node3D and scene.is_ancestor_of(actor): _ambient.append(actor)
		for actor: Node in scene.get_tree().get_nodes_in_group("ambient_traffic"):
			if actor is Node3D and scene.is_ancestor_of(actor): _traffic.append(actor)
	update_ambient(focus)
	if settings.has("muted"): AudioServer.set_bus_mute(0, bool(settings["muted"]))

func _apply_node(node: Node, settings: Dictionary, protected_actor: bool) -> void:
	protected_actor = protected_actor or node.is_in_group("player") or node.is_in_group("guards") or node.is_in_group("rescue_npcs")
	if node is Camera3D: (node as Camera3D).far = float(settings["camera_distance"])
	if node is Light3D:
		if not node.has_meta("device_original_shadow"): node.set_meta("device_original_shadow", (node as Light3D).shadow_enabled)
		(node as Light3D).shadow_enabled = bool(settings["shadows"]) and bool(node.get_meta("device_original_shadow"))
	# Sector batches include an origin-to-corner allowance supplied by the map.
	# Their aggregate bounds cannot classify the individual props correctly.
	if node is GeometryInstance3D and not protected_actor and not bool(node.get_meta("device_keep_visible",false)) and not node.has_meta("device_world_sector"):
		var geometry := node as GeometryInstance3D
		if not geometry.has_meta("device_original_range"): geometry.set_meta("device_original_range", geometry.visibility_range_end)
		var original := float(geometry.get_meta("device_original_range"))
		var bounds := geometry.get_aabb()
		var world_size := bounds.size * geometry.global_transform.basis.get_scale().abs()
		# Large ground surfaces stay present; their center is not a useful culling
		# distance. Buildings use the skyline budget, small street props use detail.
		var kind := str(node.get_meta("device_geometry_kind",""))
		if kind not in ["terrain","character"] and maxf(world_size.x,world_size.z) <= 80.0 and not (world_size.y < 1.2 and maxf(world_size.x, world_size.z) > 30.0):
			var limit := float(settings["building_distance"] if kind == "landmark" or maxf(world_size.x, maxf(world_size.y, world_size.z)) >= 8 else settings["prop_distance"])
			geometry.visibility_range_end = minf(original, limit) if original > 0 else limit
			geometry.visibility_range_end_margin = minf(12, limit * .1)
	if node is AudioStreamPlayer: (node as AudioStreamPlayer).max_polyphony = int(settings["audio_voices"])
	if node is AudioStreamPlayer3D:
		(node as AudioStreamPlayer3D).max_polyphony = int(settings["audio_voices"])
		(node as AudioStreamPlayer3D).max_distance = float(settings["audio_distance"])
	for child: Node in node.get_children(): _apply_node(child, settings, protected_actor)

func update_ambient(focus: Node3D = null) -> void:
	if focus != null: _focus = focus
	var settings := get_settings()
	var origin := _focus.global_position if is_instance_valid(_focus) else Vector3.ZERO
	_budget_actors(_ambient, origin, int(settings["max_citizens"]), float(settings["ambient_distance"]))
	_budget_actors(_traffic, origin, int(settings["max_traffic"]), float(settings["ambient_distance"]))

func _budget_actors(actors: Array[Node3D], origin: Vector3, maximum: int, distance: float) -> void:
	for index: int in range(actors.size()-1,-1,-1):
		if not is_instance_valid(actors[index]): actors.remove_at(index)
	actors.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin))
	for index: int in actors.size():
		var actor := actors[index]
		if not is_instance_valid(actor): continue
		var active := index < maximum and actor.global_position.distance_squared_to(origin) <= distance * distance
		actor.set_meta("device_budget_active", active)
		actor.visible = active
		if actor is CollisionObject3D:
			var body: CollisionObject3D = actor as CollisionObject3D
			if not body.has_meta("device_original_collision_layer"): body.set_meta("device_original_collision_layer",body.collision_layer)
			body.collision_layer = int(body.get_meta("device_original_collision_layer")) if active else 0
		for animation: Node in actor.find_children("*", "AnimationPlayer", true, false): (animation as AnimationPlayer).active = active

func _process(delta: float) -> void:
	_budget_clock += delta
	if _budget_clock >= .5 and is_instance_valid(_scene):
		_budget_clock = 0
		update_ambient()
