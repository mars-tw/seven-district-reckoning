extends Node3D

const PlayerScript = preload("res://scripts/player/player_controller.gd")
const VehicleScript = preload("res://scripts/vehicles/arcade_vehicle.gd")
const GuardScript = preload("res://scripts/combat/guard.gd")
const ObjectScript = preload("res://scripts/world/interactable.gd")
const RescueScript = preload("res://scripts/world/rescue.gd")
const MissionScript = preload("res://scripts/missions/mission_manager.gd")
const HUDScript = preload("res://scripts/ui/game_hud.gd")
const SaveScript = preload("res://scripts/save/save_manager.gd")
const OptionalScript = preload("res://scripts/content/optional_content.gd")
const CityScript = preload("res://scripts/world/district_life.gd")
const ContentWorldScript = preload("res://scripts/content/content_world.gd")
const TouchScript = preload("res://scripts/ui/touch_controls.gd")

var player: CharacterBody3D
var missions: Node
var hud: CanvasLayer
var car: CharacterBody3D
var bicycle: CharacterBody3D
var objects: Dictionary = {}
var people: Dictionary = {}
var guards: Dictionary = {}
var targets: Dictionary = {}
var route_done: Dictionary = {}
var nearest: Node3D
var nearest_vehicle: CharacterBody3D
var play_started: bool = false
var mission_state: int = 0
var heat: float = 0.0
var heat_clock: float = 0.0
var seconds_played: float = 0.0
var hit_player: AudioStreamPlayer
var info_text: String = ""
var info_time: float = 0.0
var samples: Array[float] = []
var checkpoint_state: Dictionary = {}
var freeze_events: bool = false
var low_quality: bool = false
var is_test_mode: bool = false
var last_frame_time_us: int = 0
var optional: Node
var city_life: Node3D
var content_world: Node
var touch_controls: CanvasLayer
var _web_callback_ref
var _web_window
var _web_clock: float = 0
var base_obstacle_bounds: Array[AABB] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	low_quality = "--low" in OS.get_cmdline_user_args()
	low_quality = low_quality or OS.has_feature("web")
	is_test_mode = "--self-test" in OS.get_cmdline_user_args()
	_register_inputs()
	_create_lighting()
	_create_world()
	missions = MissionScript.new()
	add_child(missions)
	optional = OptionalScript.new()
	add_child(optional)
	player = PlayerScript.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.name = "Player"
	add_child(player)
	player.position = Vector3(-56, 0.2, 52)
	player.setup_visual(_model("hero"))
	player.interaction_requested.connect(_interact)
	player.mount_requested.connect(_mount)
	player.health_changed.connect(_on_health)
	player.attacked.connect(_on_attack)
	_create_vehicles()
	_create_guards()
	_create_rescues()
	city_life = CityScript.bootstrap(self)
	city_life.process_mode = Node.PROCESS_MODE_PAUSABLE
	city_life.setup(player)
	content_world = ContentWorldScript.new()
	add_child(content_world)
	content_world.setup(self, optional, player)
	hud = HUDScript.new()
	add_child(hud)
	hud.bind_missions(missions)
	hud.bind_optional(optional)
	hud.optional_selected.connect(_start_optional)
	hud.optional_cancelled.connect(func() -> void: optional.cancel_task(); hud.show_optional_phone())
	hud.new_game_requested.connect(_new_game)
	hud.resume_requested.connect(_resume)
	hud.save_requested.connect(_save)
	hud.load_requested.connect(_load)
	hud.retry_requested.connect(_retry)
	hud.quit_requested.connect(func() -> void: get_tree().quit())
	hud.branch_selected.connect(func(branch: String) -> void: _event("select_branch", branch); _resume())
	touch_controls = TouchScript.new()
	add_child(touch_controls)
	touch_controls.camera_step.connect(player.nudge_camera)
	touch_controls.phone_requested.connect(hud.show_optional_phone)
	touch_controls.pause_requested.connect(hud.show_pause)
	optional.notice.connect(_notice)
	optional.rewarded.connect(func(_reward: Dictionary) -> void: _notice("街坊委託成果已記錄"))
	missions.updated.connect(_on_mission_updated)
	missions.mission_completed.connect(_on_mission_completed)
	missions.chapter_completed.connect(_on_chapter_complete)
	hit_player = AudioStreamPlayer.new()
	add_child(hit_player)
	if ResourceLoader.exists("res://assets/audio/hit.wav"):
		hit_player.stream = load("res://assets/audio/hit.wav")
		hit_player.volume_db = -10
	hud.show_title()
	_setup_web_bridge()
	if Engine.has_meta("seven_district_autostart"):
		Engine.remove_meta("seven_district_autostart")
		_new_game()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_capture(arg.trim_prefix("--capture="))
		if arg == "--self-test":
			_run_integration_checks()
		if arg.begins_with("--profile="):
			_profile_scene(arg.trim_prefix("--profile="))

func _register_inputs() -> void:
	var keys: Dictionary = {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
		"sprint": KEY_SHIFT, "jump": KEY_SPACE, "brake": KEY_SPACE, "interact": KEY_E, "mount": KEY_F,
		"cycle_weapon": KEY_Q, "reset_vehicle": KEY_R, "pause": KEY_ESCAPE, "phone": KEY_TAB,
		"quick_save": KEY_F5, "quick_load": KEY_F9}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mouse)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and play_started:
		if get_tree().paused:
			_resume()
		else:
			hud.show_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("phone") and play_started:
		hud.show_phone()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_save") and play_started:
		_save()
	elif event.is_action_pressed("quick_load"):
		_load()

func _process(delta: float) -> void:
	_update_web_bridge(delta)
	if optional:
		optional.set_paused(get_tree().paused)
	if not play_started or get_tree().paused:
		last_frame_time_us = 0
		return
	seconds_played += delta
	optional.advance_time(delta)
	content_world.step(delta)
	var now_us: int = Time.get_ticks_usec()
	if last_frame_time_us > 0:
		samples.append(float(now_us - last_frame_time_us) / 1000.0)
	last_frame_time_us = now_us
	if samples.size() > 18000:
		samples.pop_front()
	heat_clock += delta
	if heat_clock > 10.0:
		heat_clock = 0
		heat = maxf(0.0, heat - 1.0)
	missions.scores["heat_level"] = int(ceil(heat))
	var active_target: String = missions.get_target_key()
	if optional.status == "active":
		var optional_targets: Array[String] = optional.get_active_target_keys()
		if not optional_targets.is_empty(): active_target = optional_targets[0]
	targets["car"] = car.position
	targets["bicycle"] = bicycle.position
	for id: String in guards:
		targets[id] = guards[id].position
	if targets.has(active_target):
		hud.set_map_markers(Vector2(player.global_position.x, player.global_position.z), Vector2(targets[active_target].x, targets[active_target].z))
	_update_interaction()
	_update_routes()
	var prompt := ""
	if nearest:
		var event_type: Variant = nearest.get("event_name")
		prompt = ("左鍵｜" if event_type in ["practice_hit", "destroy_target", "sandbox"] else "E｜") + _caption(nearest)
	elif nearest_vehicle:
		prompt = "F｜騎自行車" if nearest_vehicle == bicycle else "F｜上車"
	if player.get("mounted_vehicle") != null:
		prompt = "F 下車　Space 煞車　R 取回載具"
	if info_time > 0:
		info_time -= delta
		prompt = info_text
	var weapon_value: Variant = player.get("weapon_id")
	if weapon_value == null:
		weapon_value = player.get("equipped_weapon")
	var health_value: Variant = player.get("health")
	var vehicle_caption: String = ""
	if player.get("mounted_vehicle") == car:
		vehicle_caption = "car"
	elif player.get("mounted_vehicle") == bicycle:
		vehicle_caption = "bicycle"
	hud.update_status(float(health_value if health_value != null else 100), String(weapon_value if weapon_value != null else "none"), int(ceil(heat)), vehicle_caption, prompt)
	if player.global_position.y < -12 or absf(player.global_position.x) > 150 or absf(player.global_position.z) > 150:
		player.global_position = Vector3(-56, 0.2, 52)
		player.velocity = Vector3.ZERO
		_notice("已返回安全街區")

func _create_lighting() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.30, 0.49, 0.66)
	sky_material.sky_horizon_color = Color(0.87, 0.81, 0.68)
	sky_material.ground_bottom_color = Color(0.25, 0.29, 0.30)
	sky_material.ground_horizon_color = Color(0.80, 0.80, 0.72)
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.69, 0.78, 0.86)
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.76, 0.80)
	env.fog_density = 0.0014
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-37, -32, 0)
	sun.light_color = Color(1.0, 0.86, 0.69)
	sun.light_energy = 0.75
	sun.shadow_enabled = not low_quality
	add_child(sun)

func _create_world() -> void:
	_ground(Vector3(0, -0.16, 0), Vector3(300, 0.30, 300), Color(0.45, 0.49, 0.45))
	_ground(Vector3(0, 0.005, 0), Vector3(300, 0.06, 15), Color(0.14, 0.17, 0.19))
	_ground(Vector3(0, 0.005, 0), Vector3(15, 0.06, 300), Color(0.14, 0.17, 0.19))
	for z: float in [-76.0, 76.0]:
		_ground(Vector3(0, 0.005, z), Vector3(160, 0.06, 12), Color(0.16, 0.19, 0.20))
	for x: float in [-76.0, 76.0]:
		_ground(Vector3(x, 0.005, 0), Vector3(12, 0.06, 160), Color(0.16, 0.19, 0.20))
	for i: int in range(-7, 8):
		_ground(Vector3(i * 18.0, 0.046, 0), Vector3(7, 0.01, 0.12), Color(0.95, 0.89, 0.65), false)
		_ground(Vector3(0, 0.046, i * 18.0), Vector3(0.12, 0.01, 7), Color(0.95, 0.89, 0.65), false)
	for x: float in [-20.0, 22.0, 60.0, -58.0, 104.0, -108.0]:
		for z: float in [-42.0, -112.0]:
			var which := "office_tower_a" if int(absf(x)) % 3 == 0 else "office_tower_b"
			_building(which, Vector3(x, 0, z), Vector3(18, 30 + absf(x) * 0.15, 19))
	_building("office_tower_c", Vector3(-59, 0, 90), Vector3(24, 14, 19))
	_building("office_tower_c", Vector3(58, 0, 95), Vector3(23, 22, 19))
	_ground(Vector3(37, 0.055, 32), Vector3(49, 0.1, 43), Color(0.67, 0.67, 0.61))
	_place("office_lobby", Vector3(38, 0.1, 28))
	for i: int in range(14):
		var z: float = -115.0 + float(i) * 17.0
		_place("tree", Vector3(11, 0.04, z))
		_place("tree", Vector3(-11, 0.04, z))
		if i % 2 == 0:
			_place("streetlight", Vector3(10, 0.04, z + 5))
	for p: Vector3 in [Vector3(-52, 0, 39), Vector3(21, 0, 20), Vector3(59, 0, 21), Vector3(-38, 0, -15)]:
		_place("planter", p)
		_place("bench", p + Vector3(3, 0, 1))
	_add_object("mei", "美晴車店｜交談", "talk_mei", "desk", Vector3(-52, 0.10, 57), Vector3(1.5, 1.0, 0.8))
	_add_object("phone", "查看失聯訊息", "read_phone", "display", Vector3(-54, 0.10, 59), Vector3(0.5, 1.0, 0.4))
	_add_object("wrench", "借用扳手", "pickup_wrench", "wrench", Vector3(-48, 0.25, 56), Vector3(0.7, 0.5, 0.4))
	_add_object("practice_1", "練習目標 A", "practice_hit", "barrier", Vector3(-44, 0.05, 53), Vector3(1, 1.1, 0.4), true)
	_add_object("practice_2", "練習目標 B", "practice_hit", "barrier", Vector3(-41, 0.05, 53), Vector3(1, 1.1, 0.4), true)
	_add_object("service_gate", "替代路線｜側門", "alternate_route", "barrier", Vector3(-21, 0.1, -14), Vector3(1.4, 1.4, 0.3))
	_add_object("fake_sign", "恆曜假客服招牌", "disable_sign", "sign", Vector3(-37, 0.1, -21), Vector3(2.6, 1.7, 0.5), true)
	_add_object("pass", "前站通行物", "collect_pass", "display", Vector3(-33, 0.15, -26), Vector3(0.6, 0.8, 0.5))
	_add_object("summary", "保存留言摘要", "collect_evidence", "display", Vector3(-40, 0.15, -26), Vector3(0.7, 0.8, 0.5))
	_add_object("mei_shop", "車店集合點", "return_shop", "sign", Vector3(-56, 0.1, 43), Vector3(1.1, 1.2, 0.3))
	_add_object("shift_note", "保存輪班便條", "collect_evidence", "display", Vector3(27, 0.1, 31), Vector3(0.6, 1.0, 0.5))
	_add_object("branch_console", "選擇行動重心｜E", "branch_menu", "display", Vector3(32, 0.1, 25), Vector3(0.8, 1.2, 0.5))
	for i: int in range(1, 4):
		_add_object("equipment_%d" % i, "詐團設備 %d" % i, "destroy_target", ["server", "desk", "display"][i - 1], Vector3(37 + i * 3, 0.1, 23), Vector3(1.5, 1.6, 0.8), true)
	_add_object("record_1", "保存紀錄 A", "collect_evidence", "display", Vector3(28, 0.15, 19), Vector3(0.6, 0.9, 0.5), true)
	_add_object("record_2", "保存紀錄 B", "collect_evidence", "display", Vector3(31, 0.15, 19), Vector3(0.6, 0.9, 0.5), true)
	_add_object("console", "中止前站營運", "disable_console", "server", Vector3(47, 0.1, 18), Vector3(1.2, 1.6, 0.8))
	_add_object("bat_pickup", "撿取球棒", "pickup_weapon", "bat", Vector3(-22, 0.15, 14), Vector3(0.7, 0.5, 0.4))
	_add_object("pulse_pickup", "撿取虛構脈衝器具", "pickup_weapon", "pulse", Vector3(19, 0.15, 22), Vector3(0.7, 0.5, 0.4))
	for i: int in range(8):
		var model_name: String = ["barrier", "glass", "desk", "sign", "server", "display"][i % 6]
		_add_object("sandbox_%d" % i, "沙盒試打物", "sandbox", model_name, Vector3(80 + (i % 4) * 4, 0.1, 31 + (i / 4) * 6), Vector3(1.0, 1.5, 0.5), true)
	var routes: Array[Vector3] = [Vector3(-75, 0.1, 25), Vector3(-75, 0.1, -55), Vector3(-15, 0.1, -75)]
	for i: int in range(3):
		targets["route_%d" % (i + 1)] = routes[i]
		_marker("路標 %d" % (i + 1), routes[i], Color(1.0, 0.67, 0.24))
	targets["safe_point"] = Vector3(-46, 0.1, 42)
	_marker("撤離安全點", targets["safe_point"], Color(0.30, 0.95, 0.65))

func _create_vehicles() -> void:
	car = VehicleScript.new()
	car.process_mode = Node.PROCESS_MODE_PAUSABLE
	car.name = "Car"
	car.type = "car"
	car.position = Vector3(-57, 0.12, 35)
	add_child(car)
	car.setup_visual(_model("car"))
	bicycle = VehicleScript.new()
	bicycle.process_mode = Node.PROCESS_MODE_PAUSABLE
	bicycle.name = "Bicycle"
	bicycle.type = "bike"
	bicycle.position = Vector3(-48, 0.12, 45)
	add_child(bicycle)
	bicycle.setup_visual(_model("bicycle"))
	targets["car"] = car.position
	targets["bicycle"] = bicycle.position

func _create_guards() -> void:
	for i: int in range(1, 3):
		var guard: CharacterBody3D = GuardScript.new()
		guard.process_mode = Node.PROCESS_MODE_PAUSABLE
		guard.name = "guard_%d" % i
		guard.position = Vector3(-33 + i * 4, 0.15, -19)
		add_child(guard)
		guard.target = player
		guard.setup_visual(_model("guard"))
		var patrol: Array[Vector3] = [guard.position, guard.position + Vector3(6, 0, 4)]
		guard.patrol_points = patrol
		guard.defeated.connect(func() -> void: _event("defeat_guard", guard.name))
		guards[guard.name] = guard
		targets[guard.name] = guard.position

func _create_rescues() -> void:
	var positions: Dictionary = {"rescue_A": Vector3(25, 0.15, 29), "rescue_B": Vector3(29, 0.15, 34), "extra_A": Vector3(44, 0.15, 31), "extra_B": Vector3(48, 0.15, 31)}
	for id: String in positions:
		var person: CharacterBody3D = RescueScript.new()
		person.process_mode = Node.PROCESS_MODE_PAUSABLE
		person.configure(id, _model("civilian"))
		add_child(person)
		person.position = positions[id]
		person.target = player
		person.safe_arrival.connect(_safe_arrival)
		people[id] = person
		targets[id] = person.position

func _add_object(id: String, caption: String, event: String, model_name: String, p: Vector3, size: Vector3, can_break: bool = false) -> void:
	var object: StaticBody3D = ObjectScript.new()
	object.configure(id, caption, event, _model(model_name), size, can_break)
	object.damage_gate = _can_damage_object
	add_child(object)
	object.position = p
	object.used.connect(_use_object)
	object.destroyed.connect(_destroyed_object)
	object.hit_received.connect(_hit_object)
	objects[id] = object
	targets[id] = p

func _ground(p: Vector3, size: Vector3, color: Color, solid: bool = true) -> void:
	var body := StaticBody3D.new()
	body.position = p
	var render := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	render.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	render.material_override = material
	body.add_child(render)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	add_child(body)

func _model(key: String) -> PackedScene:
	var path := "res://assets/models/%s.glb" % key
	if ResourceLoader.exists(path):
		return load(path) as PackedScene
	return null

func _place(key: String, p: Vector3) -> Node3D:
	var packed := _model(key)
	if not packed:
		return null
	var model: Node3D = packed.instantiate() as Node3D
	model.position = p
	add_child(model)
	return model

func _building(key: String, p: Vector3, size: Vector3) -> void:
	var model := _place(key, p)
	if not model:
		return
	var bounds := _visual_bounds(model)
	if bounds.size.x > 0.01 and bounds.size.y > 0.01 and bounds.size.z > 0.01:
		model.scale = size / bounds.size
	var body := StaticBody3D.new()
	body.position = p + Vector3(0, size.y * 0.5, 0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	base_obstacle_bounds.append(AABB(p - Vector3(size.x * 0.5, 0, size.z * 0.5), size))
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _visual_bounds(root: Node3D) -> AABB:
	var bounds := AABB()
	var found: bool = false
	var queue: Array[Node] = [root]
	while not queue.is_empty():
		var node: Node = queue.pop_back()
		if node is MeshInstance3D and node.mesh:
			var local: AABB = root.global_transform.affine_inverse() * node.global_transform * node.get_aabb()
			bounds = local if not found else bounds.merge(local)
			found = true
		for child in node.get_children():
			queue.append(child)
	return bounds

func _marker(text: String, p: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = p + Vector3(0, 2.5, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.pixel_size = 0.013
	label.modulate = color
	if ResourceLoader.exists("res://assets/fonts/SevenDistrictSansTC-Regular.otf"):
		label.font = load("res://assets/fonts/SevenDistrictSansTC-Regular.otf") as Font
	add_child(label)

func _new_game() -> void:
	if play_started and not is_test_mode:
		Engine.set_meta("seven_district_autostart", true)
		get_tree().reload_current_scene()
		return
	_resume()
	play_started = true
	seconds_played = 0
	heat = 0
	route_done.clear()
	for object: StaticBody3D in objects.values():
		object.restore({})
	optional.reset()
	for person: CharacterBody3D in people.values():
		person.following = false
		person.arrived = false
	player.clear_inventory()
	player.restore_health()
	car.force_release()
	bicycle.force_release()
	car.reset()
	bicycle.reset()
	missions.start_campaign()
	player.global_position = Vector3(-56, 0.2, 52)
	player.velocity = Vector3.ZERO
	checkpoint_state = _snapshot(false)

func _resume() -> void:
	if hud and hud.has_method("hide_menus"):
		hud.hide_menus()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if OS.has_feature("web") or (touch_controls and touch_controls.enabled) else Input.MOUSE_MODE_CAPTURED

func _start_optional(id: String) -> void:
	if not play_started:
		_notice("先開始新遊戲，再選街坊委託")
		return
	if optional.start_task(id):
		content_world.prepare_task(id)
		_resume()
	else:
		hud.show_optional_phone()

func _setup_web_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_web_window = JavaScriptBridge.get_interface("window")
	_web_callback_ref = JavaScriptBridge.create_callback(_web_command)
	_web_window.sevenDistrictCommand = _web_callback_ref
	_emit_web_state()

func _web_command(arguments: Array) -> void:
	if arguments.is_empty(): return
	var command: String = String(arguments[0])
	match command:
		"new_game": _new_game()
		"pause":
			if play_started: hud.show_pause()
		"phone":
			if play_started: hud.show_optional_phone()
		"resume":
			if play_started: _resume()
		"save": _save()
		"load": _load()
		"touch_toggle":
			touch_controls.set_enabled(not touch_controls.enabled)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		"camera_left": player.nudge_camera(-0.3)
		"camera_right": player.nudge_camera(0.3)
	_emit_web_state()

func _update_web_bridge(delta: float) -> void:
	if not OS.has_feature("web") or _web_window == null: return
	_web_clock += delta
	if _web_clock < 0.35: return
	_web_clock = 0
	var ratio: float = clampf(float(_web_window.devicePixelRatio), 1.0, 2.0)
	var logical_size := Vector2i(roundi(get_window().size.x / ratio), roundi(get_window().size.y / ratio))
	if logical_size.x > 0 and logical_size.y > 0 and get_window().content_scale_size != logical_size:
		get_window().content_scale_size = logical_size
	_emit_web_state()

func _emit_web_state() -> void:
	if _web_window == null or not hud or not optional: return
	var state = JavaScriptBridge.create_object("Object")
	state.phase = "title" if not play_started else ("menu" if get_tree().paused else "playing")
	state.main_title = missions.get_current_title()
	state.objective = missions.get_objective_text()
	state.optional_title = optional.get_active_title()
	state.optional_text = optional.get_active_text()
	var sides: int = 0
	var activities: int = 0
	for entry: Dictionary in optional.get_menu_entries():
		if entry["completed"]:
			if entry["type"] == "side": sides += 1
			else: activities += 1
	state.completed_sides = sides
	state.completed_activities = activities
	state.coins = int(missions.parts_vouchers) + int(optional.wallet)
	state.touch = touch_controls.enabled
	state.player_x = player.global_position.x
	state.player_z = player.global_position.z
	_web_window.sevenDistrictGame = state
	var options = JavaScriptBridge.create_object("Object")
	options.detail = state
	var event = JavaScriptBridge.create_object("CustomEvent", "seven-district-state", options)
	_web_window.dispatchEvent(event)

func _update_interaction() -> void:
	nearest = null
	nearest_vehicle = null
	var best: float = 3.0
	for object: Node3D in objects.values():
		if object.collected:
			continue
		if String(object.object_id).begins_with("SIDE_") or String(object.object_id).begins_with("ACT_"):
			if object.object_id not in optional.get_active_target_keys(): continue
		var distance: float = player.global_position.distance_to(object.global_position)
		if distance < best and _line_visible(object):
			best = distance
			nearest = object
	for person: Node3D in people.values():
		if person.arrived:
			continue
		var distance: float = player.global_position.distance_to(person.global_position)
		if distance < best and _line_visible(person):
			best = distance
			nearest = person
	for vehicle: CharacterBody3D in [car, bicycle]:
		if player.global_position.distance_to(vehicle.global_position) < 4.0:
			nearest_vehicle = vehicle

func _caption(node: Node3D) -> String:
	if node.get("caption") != null:
		return node.caption
	return "幫受困者離開"

func _line_visible(node: Node3D) -> bool:
	var start := player.global_position + Vector3.UP * 1.0
	var finish := node.global_position + Vector3.UP * 0.8
	var query := PhysicsRayQueryParameters3D.create(start, finish, 1, [player.get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == node

func _safe_arrival(id: String) -> void:
	if not _event("escort_safe", id):
		# A person can arrive before the second captive is released. Keep retrying
		# the safe-point event once the escort objective becomes active.
		people[id].arrived = false
		people[id].following = true
		people[id].label.text = "受困者｜在集合點等候"

func _interact() -> void:
	if not nearest or not play_started:
		return
	if nearest.has_method("interact"):
		nearest.interact()
	elif nearest.get("person_id") != null:
		var person: CharacterBody3D = nearest
		var event: String = "free_rescue" if person.person_id.begins_with("rescue") else "escort_safe"
		if event == "escort_safe":
			if missions.mission_index == 4 and missions.branch == "rescue":
				person.following = true
				person.label.text = "受困者｜正在跟隨"
		else:
			if _event(event, person.person_id):
				person.following = true
				person.label.text = "受困者｜正在跟隨"

func _use_object(id: String) -> void:
	var object: StaticBody3D = objects[id]
	if content_world.use_object(id):
		return
	if object.event_name in ["practice_hit", "destroy_target", "sandbox"]:
		_notice("使用左鍵攻擊這個物件")
		return
	if id == "branch_console":
		hud.show_phone()
		return
	if object.event_name == "pickup_weapon":
		var weapon := "bat" if id == "bat_pickup" else "pulse"
		if player.grant_weapon(weapon):
			player.equip_weapon(weapon)
			object.set_collected(true)
			_notice("取得器具｜Q 切換")
		return
	if id == "wrench":
		if _event("pickup_wrench", id):
			player.grant_weapon("wrench")
			player.equip_weapon("wrench")
			object.set_collected(true)
		return
	if _event(object.event_name, id):
		if id in ["pass", "record_1", "record_2", "summary", "shift_note"]:
			object.set_collected(true)
	else:
		_notice("先完成目前的任務目標")

func _hit_object(id: String) -> void:
	if hit_player and hit_player.stream:
		hit_player.play()
	if id.begins_with("practice"):
		_event("practice_hit", id)

func _can_damage_object(id: String) -> bool:
	if not play_started or objects[id].collected:
		return false
	if id.begins_with("sandbox"):
		return true
	if id.begins_with("SIDE_") or id.begins_with("ACT_"):
		return content_world.can_damage(id)
	var objective: Dictionary = missions.get_current_objective()
	if id.begins_with("practice"):
		return missions.mission_index == 0 and "practice_hit" in objective.get("events", [])
	if id.begins_with("equipment"):
		return missions.mission_index == 4 and missions.branch == "smash" and "destroy_target" in objective.get("events", [])
	if id == "fake_sign":
		return missions.mission_index == 1 and "disable_sign" in objective.get("events", [])
	if id.begins_with("record"):
		return missions.mission_index == 4
	return true

func _destroyed_object(id: String) -> void:
	heat = minf(5, heat + 1)
	if id.begins_with("SIDE_"):
		content_world.accept("disable_sign", id)
		return
	if id == "fake_sign":
		_event("disable_sign", id)
	elif id.begins_with("equipment"):
		_event("destroy_target", id)
	elif id.begins_with("record"):
		_event("evidence_destroyed", id)
	else:
		_notice("物件已損壞")

func _mount() -> void:
	var mounted: Variant = player.get("mounted_vehicle")
	if mounted != null:
		mounted.exit()
		return
	if not nearest_vehicle:
		return
	if nearest_vehicle.enter(player):
		if nearest_vehicle == bicycle:
			_event("mount_bicycle", "bicycle")
		elif missions.mission_index >= 2:
			_event("unlock_car", "car")

func _update_routes() -> void:
	if missions.mission_index != 2:
		return
	for id: String in ["route_1", "route_2", "route_3"]:
		if not route_done.has(id) and player.global_position.distance_to(targets[id]) < 7.0:
			if _event("route_checkpoint", id):
				route_done[id] = true

func _event(event_name: String, target_id: String) -> bool:
	if freeze_events:
		return false
	return missions.handle_event(event_name, target_id)

func _on_mission_updated() -> void:
	if freeze_events:
		return
	if missions.mission_index != mission_state:
		mission_state = missions.mission_index
		checkpoint_state = _snapshot(false)
	if missions.mission_index == 2 and missions.get_target_key() == "car" and player.global_position.distance_to(car.global_position) < 4:
		_event("unlock_car", "car")

func _on_mission_completed(_id: String) -> void:
	_notice("任務完成｜進度已保存")
	_save(false)

func _on_chapter_complete(branch: String) -> void:
	hud.show_chapter_complete(branch)
	_save(false)

func _on_health(current: float, _maximum: float) -> void:
	if current <= 0 and play_started:
		_notice("受傷倒下，回到本段檢查點")
		_retry()

func _on_attack(_weapon: String) -> void:
	heat_clock = 0

func _notice(text: String) -> void:
	info_text = text
	info_time = 4.0

func _snapshot(include_checkpoint: bool = true) -> Dictionary:
	var world_objects: Dictionary = {}
	for id: String in objects:
		world_objects[id] = objects[id].state()
	var rescue_states: Dictionary = {}
	for id: String in people:
		var person: CharacterBody3D = people[id]
		rescue_states[id] = {"position": _vec(person.position), "following": person.following, "arrived": person.arrived}
	var saved_vehicle: String = "car" if player.get("mounted_vehicle") == car else ("bicycle" if player.get("mounted_vehicle") == bicycle else "")
	var guard_states: Dictionary = {}
	for id: String in guards:
		guard_states[id] = guards[id].get_state()
	var result: Dictionary = {"schema_version": 1, "missions": missions.to_dict(), "player": {"position": _vec(player.position), "health": player.get("health"), "inventory": player.get("inventory"), "weapon": player.get("equipped_weapon"), "pulse_energy": player.get("pulse_energy"), "vehicle": saved_vehicle},
		"objects": world_objects, "rescues": rescue_states, "vehicles": {"car": _vec(car.position), "bicycle": _vec(bicycle.position)}, "route_done": route_done.duplicate(), "heat": heat, "seconds_played": seconds_played}
	result["guards"] = guard_states
	result["optional"] = optional.to_dict()
	result["city_life"] = city_life.to_dict()
	if include_checkpoint:
		result["checkpoint"] = checkpoint_state.duplicate(true)
	return result

func _vec(p: Vector3) -> Array[float]:
	return [p.x, p.y, p.z]

func _from_vec(data: Variant, fallback: Vector3) -> Vector3:
	if data is Array and data.size() == 3:
		return Vector3(float(data[0]), float(data[1]), float(data[2]))
	return fallback

func _save(show_notice: bool = true) -> void:
	if not play_started:
		return
	var error: int = SaveScript.save_state(_snapshot(), 98 if is_test_mode else 1)
	if show_notice:
		_notice("進度已儲存" if error == OK else "儲存失敗，舊檔仍保留")

func _load(slot: int = 1) -> void:
	var data: Dictionary = SaveScript.load_state(slot)
	if data.is_empty():
		_notice("尚無可用存檔")
		return
	if not _valid_world_save(data):
		_notice("存檔內容不完整，保留目前進度")
		return
	if not _restore(data):
		_notice("任務資料不合法，保留目前進度")
		return
	if data.get("checkpoint") is Dictionary and _valid_world_save(data["checkpoint"]):
		checkpoint_state = data["checkpoint"].duplicate(true)
	else:
		# Backward-compatible recovery for alpha saves created before checkpoints.
		checkpoint_state = _snapshot(false)
		var reset_objects: Dictionary = checkpoint_state["objects"]
		if missions.mission_index == 0:
			reset_objects["wrench"] = {"health": 35.0, "broken": false, "collected": false}
			reset_objects["practice_1"] = {"health": 35.0, "broken": false, "collected": false}
			reset_objects["practice_2"] = {"health": 35.0, "broken": false, "collected": false}
	play_started = true
	_resume()
	_notice("已讀取進度")

func _valid_world_save(data: Dictionary) -> bool:
	if data.get("schema_version") != 1:
		return false
	for key: String in ["missions", "player", "objects", "rescues", "vehicles", "route_done"]:
		if not data.get(key) is Dictionary:
			return false
	var player_data: Dictionary = data["player"]
	if not _valid_vector_data(player_data.get("position")) or not _valid_number(player_data.get("health"), 0, 100):
		return false
	if not _valid_number(player_data.get("pulse_energy", 12), 0, 12):
		return false
	if not player_data.get("inventory", {}) is Dictionary:
		return false
	var inventory: Dictionary = player_data.get("inventory", {})
	for category: String in inventory:
		if category not in ["melee", "ranged"] or not inventory[category] is Array:
			return false
		var allowed: Array = ["wrench", "bat"] if category == "melee" else ["pulse"]
		if inventory[category].size() > allowed.size():
			return false
		var found: Dictionary = {}
		for item: Variant in inventory[category]:
			if not item is String or item not in allowed or found.has(item):
				return false
			found[item] = true
	if not player_data.get("weapon", "") is String or player_data.get("weapon", "") not in ["", "wrench", "bat", "pulse"]:
		return false
	if player_data.get("vehicle", "") not in ["", "car", "bicycle"]:
		return false
	for dictionary_key: String in ["objects", "rescues"]:
		for key: String in data[dictionary_key]:
			if not data[dictionary_key][key] is Dictionary:
				return false
	for key: String in data["objects"]:
		var object_state: Dictionary = data["objects"][key]
		if not _valid_number(object_state.get("health", 35), 0, 35):
			return false
		if not object_state.get("broken", false) is bool or not object_state.get("collected", false) is bool:
			return false
	for key: String in data["rescues"]:
		var rescue_state: Dictionary = data["rescues"][key]
		if not _valid_vector_data(rescue_state.get("position")):
			return false
		if not rescue_state.get("following", false) is bool or not rescue_state.get("arrived", false) is bool:
			return false
	for key: String in data["vehicles"]:
		if key not in ["car", "bicycle"] or not _valid_vector_data(data["vehicles"][key]):
			return false
	if data.has("guards"):
		if not data["guards"] is Dictionary:
			return false
		for key: String in data["guards"]:
			var state: Variant = data["guards"][key]
			if not state is Dictionary or not _valid_number(state.get("health"), 0, 75) or not _valid_vector_data(state.get("position")):
				return false
	if not _valid_number(data.get("heat", 0), 0, 5) or not _valid_number(data.get("seconds_played", 0), 0, 10000000):
		return false
	if data.has("optional"):
		if not data["optional"] is Dictionary:
			return false
		var probe := OptionalScript.new()
		var valid: bool = probe.from_dict(data["optional"])
		probe.free()
		if not valid: return false
	if data.has("city_life"):
		if not data["city_life"] is Dictionary or not _valid_number(data["city_life"].get("clock", 0), 0, 100000000): return false
	return true

func _valid_number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

func _valid_vector_data(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for component: Variant in value:
		if not _valid_number(component, -1000, 1000):
			return false
	return true

func _restore(data: Dictionary) -> bool:
	if not _valid_world_save(data):
		return false
	freeze_events = true
	if not missions.from_dict(data.get("missions", {})):
		freeze_events = false
		return false
	mission_state = missions.mission_index
	car.force_release()
	bicycle.force_release()
	var p_data: Dictionary = data.get("player", {})
	player.position = _from_vec(p_data.get("position"), Vector3(-56, 0.2, 52))
	player.velocity = Vector3.ZERO
	player.set("health", float(p_data.get("health", 100)))
	var inventory_data: Dictionary = p_data.get("inventory", {})
	player.clear_inventory()
	for category: String in inventory_data:
		for weapon: String in inventory_data[category]:
			player.grant_weapon(weapon)
	var equipped: String = String(p_data.get("weapon", "wrench"))
	player.equip_weapon(equipped)
	player.set("pulse_energy", int(p_data.get("pulse_energy", 12)))
	var o_data: Dictionary = data.get("objects", {})
	for id: String in objects:
		objects[id].restore(o_data.get(id, {}))
	var r_data: Dictionary = data.get("rescues", {})
	for id: String in people:
		var person: CharacterBody3D = people[id]
		var state: Dictionary = r_data.get(id, {})
		person.position = _from_vec(state.get("position"), targets[id])
		person.following = bool(state.get("following", false))
		person.arrived = bool(state.get("arrived", false))
	var v_data: Dictionary = data.get("vehicles", {})
	car.position = _from_vec(v_data.get("car"), targets["car"])
	bicycle.position = _from_vec(v_data.get("bicycle"), targets["bicycle"])
	car.velocity = Vector3.ZERO
	bicycle.velocity = Vector3.ZERO
	var g_data: Dictionary = data.get("guards", {})
	for id: String in guards:
		if g_data.has(id):
			guards[id].restore_state(g_data[id])
	var vehicle_id: String = String(p_data.get("vehicle", ""))
	if vehicle_id in ["car", "bicycle"]:
		var restored_vehicle: CharacterBody3D = car if vehicle_id == "car" else bicycle
		if not restored_vehicle.enter(player):
			player.position = restored_vehicle.position + Vector3(3, 0.1, 0)
	route_done = data.get("route_done", {}).duplicate()
	heat = float(data.get("heat", 0))
	seconds_played = float(data.get("seconds_played", 0))
	if data.has("optional"): optional.from_dict(data["optional"])
	else: optional.reset()
	if data.has("city_life"): city_life.from_dict(data["city_life"])
	freeze_events = false
	return true

func _retry() -> void:
	_resume()
	var keep_optional: Dictionary = optional.to_dict()
	var keep_optional_objects: Dictionary = {}
	for id: String in objects:
		if id.begins_with("SIDE_") or id.begins_with("ACT_"):
			keep_optional_objects[id] = objects[id].state()
	missions.restart_current()
	if not checkpoint_state.is_empty():
		var rollback := checkpoint_state.duplicate(true)
		rollback["missions"] = missions.to_dict()
		rollback["optional"] = keep_optional
		for id: String in keep_optional_objects: rollback["objects"][id] = keep_optional_objects[id]
		_restore(rollback)
	car.force_release()
	bicycle.force_release()
	player.restore_health()
	var retry_position := Vector3(-56, 0.2, 52) if missions.mission_index < 3 else Vector3(21, 0.2, 25)
	if missions.mission_index == 2 and missions.current_objective >= 2:
		var previous_route: int = mini(missions.current_objective - 1, 3)
		retry_position = targets["route_%d" % previous_route] + Vector3(1, 0.1, 0)
		bicycle.position = retry_position + Vector3(1, 0, 0)
	player.position = retry_position
	player.velocity = Vector3.ZERO
	_notice("已回到本段檢查點")

func _capture(path: String) -> void:
	var mode: String = "gameplay"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-size="):
			var dimensions: PackedStringArray = arg.trim_prefix("--capture-size=").split("x")
			if dimensions.size() == 2:
				var size_value := Vector2i(int(dimensions[0]), int(dimensions[1]))
				get_window().size = size_value
				get_window().content_scale_size = size_value
		if arg.begins_with("--capture-view="):
			mode = arg.trim_prefix("--capture-view=")
	await get_tree().process_frame
	_new_game()
	player.position = Vector3(-54, 0.2, 44)
	if mode == "bike":
		player.position = bicycle.position + Vector3(1.5, 0, 0)
		bicycle.enter(player)
	elif mode == "car":
		player.position = car.position + Vector3(2.5, 0, 0)
		car.enter(player)
	elif mode == "office":
		player.position = Vector3(37, 0.2, 35)
	elif mode == "title":
		hud.show_title()
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("CAPTURE_WRITE_FAILED " + error_string(error))
		get_tree().quit(1)
		return
	print("CAPTURE_SAVED ", path)
	get_tree().quit()

func _profile_scene(path: String) -> void:
	await get_tree().process_frame
	_new_game()
	player.position = Vector3(0, 0.2, 22)
	await get_tree().create_timer(2.0).timeout
	samples.clear()
	last_frame_time_us = 0
	await get_tree().create_timer(12.0).timeout
	var ordered: Array[float] = samples.duplicate()
	ordered.sort()
	if ordered.size() < 120:
		push_error("PROFILE_INSUFFICIENT_FRAMES")
		get_tree().quit(1)
		return
	var p95: float = ordered[mini(int(ceil(ordered.size() * 0.95)) - 1, ordered.size() - 1)]
	var p99: float = ordered[mini(int(ceil(ordered.size() * 0.99)) - 1, ordered.size() - 1)]
	var result: Dictionary = {"scope": "alpha_static_rendered_scene_after_two_second_warmup", "measurement": "monotonic_wall_clock_between_process_callbacks", "renderer": "gl_compatibility", "resolution": [get_viewport().size.x, get_viewport().size.y],
		"frames": ordered.size(), "p95_ms": p95, "p99_ms": p99, "godot_static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"vram_bytes": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED), "guards": 2, "rescue_people": 4,
		"limitations": "Short alpha scene measurement; does not validate full-MVP stress, mobile, or long-term stability."}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("PROFILE_WRITE_FAILED")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(result, "  "))
	print("PROFILE_SAVED p95=", p95, " p99=", p99)
	get_tree().quit()

func _run_integration_checks() -> void:
	await get_tree().process_frame
	_new_game()
	var checks: Array[String] = []
	assert(objects.size() >= 24)
	checks.append("world_interactables_present")
	assert(not _event("read_phone", "phone"))
	assert(_event("talk_mei", "mei"))
	assert(_event("read_phone", "phone"))
	_use_object("wrench")
	assert(player.get("inventory") != null)
	assert(_event("practice_hit", "practice_1"))
	assert(not _event("practice_hit", "practice_1"))
	assert(_event("practice_hit", "practice_2"))
	checks.append("mission_order_and_event_deduplication")
	assert(_event("alternate_route", "service_gate"))
	assert(_event("disable_sign", "fake_sign"))
	assert(_event("collect_pass", "pass"))
	assert(_event("mount_bicycle", "bicycle"))
	for id: String in ["route_1", "route_2", "route_3"]:
		assert(_event("route_checkpoint", id))
	assert(_event("return_shop", "mei_shop"))
	assert(_event("unlock_car", "car"))
	checks.append("bike_and_car_mission_unlocks")
	for id: String in ["rescue_A", "rescue_B"]:
		assert(_event("free_rescue", id))
	for id: String in ["rescue_A", "rescue_B"]:
		assert(_event("escort_safe", id))
	assert(missions.scores["rescued_count"] == 2)
	checks.append("rescue_identity_and_safe_point_counting")
	assert(_event("select_branch", "evidence"))
	assert(_event("collect_evidence", "record_1"))
	assert(_event("collect_evidence", "record_2"))
	assert(_event("disable_console", "console"))
	assert(_event("return_shop", "mei_shop"))
	checks.append("five_mission_evidence_branch")
	var snapshot := _snapshot()
	assert(SaveScript.save_state(snapshot, 97) == OK)
	var loaded: Dictionary = SaveScript.load_state(97)
	assert(missions.from_dict(loaded["missions"]))
	assert(missions.chapter_complete and missions.branch == "evidence")
	assert(missions.scores["evidence_score"] == 30)
	assert(missions.scores["rescued_count"] == 2)
	assert(_restore(loaded))
	assert(player.get("inventory")["melee"].has("wrench"))
	checks.append("atomic_save_roundtrip")
	_resume()
	player.position = Vector3(0, 0.2, 10)
	var before: Vector3 = player.position
	Input.action_press("move_forward")
	await get_tree().create_timer(0.5).timeout
	Input.action_release("move_forward")
	assert(player.position.distance_to(before) > 0.5)
	checks.append("player_actual_physics_movement")
	player.position = bicycle.position + Vector3(2, 0, 0)
	assert(bicycle.enter(player))
	var bike_before: Vector3 = bicycle.position
	Input.action_press("move_forward")
	await get_tree().create_timer(0.8).timeout
	Input.action_release("move_forward")
	assert(bicycle.position.distance_to(bike_before) > 0.3)
	Input.action_press("brake")
	await get_tree().create_timer(0.4).timeout
	Input.action_release("brake")
	assert(bicycle.exit())
	checks.append("bicycle_actual_physics_enter_move_exit")
	player.position = car.position + Vector3(3, 0, 0)
	assert(car.enter(player))
	var car_before: Vector3 = car.position
	Input.action_press("move_forward")
	await get_tree().create_timer(0.8).timeout
	Input.action_release("move_forward")
	assert(car.position.distance_to(car_before) > 0.3)
	Input.action_press("brake")
	await get_tree().create_timer(0.4).timeout
	Input.action_release("brake")
	var exited_car: bool = car.exit()
	assert(exited_car, "Car exit failed: %s, speed=%s, position=%s" % [car.last_exit_error, car.speed_mps, car.position])
	checks.append("car_actual_physics_enter_move_exit")
	print("INTEGRATION_PASS ", JSON.stringify(checks))
	get_tree().quit()
