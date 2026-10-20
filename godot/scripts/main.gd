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
const TouchScript = preload("res://scripts/ui/mobile_touch_controls.gd")
const RevisitScript = preload("res://scripts/content/chapter_revisits.gd")
const SystemsScript = preload("res://scripts/systems/district_systems.gd")
const StreetScript = preload("res://scripts/systems/street_state.gd")
const UrbanScript = preload("res://scripts/world/urban_detail.gd")
const ContactShadowScript = preload("res://scripts/world/contact_shadow.gd")
const TaiwanLifeScript = preload("res://scripts/content/taiwan_life.gd")
const TaiwanActivitiesScript = preload("res://scripts/content/taiwan_activities.gd")
const TaiwanActivityPanelScript = preload("res://scripts/ui/taiwan_activity_panel.gd")
const TaiwanWorldScript = preload("res://scripts/content/taiwan_world.gd")
const TaiwanExpansionScript = preload("res://scripts/world/taiwan_expansion.gd")
const DeviceScript = preload("res://scripts/systems/device_profiles.gd")
const HitFeedbackScript = preload("res://scripts/systems/hit_feedback.gd")
const BeaconScript = preload("res://scripts/world/objective_beacon.gd")
const EvidenceInspectorScript = preload("res://scripts/ui/evidence_inspector.gd")
const RunRecordsScript = preload("res://scripts/systems/run_records.gd")
const StoryIntroScript = preload("res://scripts/ui/story_intro.gd")
const MusicScript = preload("res://scripts/systems/music_director.gd")
const FraudCaseScript = preload("res://scripts/content/fraud_case.gd")
const InvestigationScript = preload("res://scripts/content/content_investigations.gd")
const InvestigationPanel = preload("res://scripts/ui/investigation_panel.gd")

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
var district_systems: Node
var street_state: RefCounted
var urban_detail: Node3D
var district_environment: WorldEnvironment
var district_sun: DirectionalLight3D
var _light_clock: float = 0.0
var contact_people: Array[Node3D] = []
var _relocated_save: bool = false
var taiwan_life: Node
var taiwan_activities: Node
var activity_panel: RefCounted
var taiwan_world: Node3D
var taiwan_expansion: Node3D
var device_profiles: Node
var _device_settings: Dictionary = {}
const WORLD_RADIUS: float = 400.0
const StartupScript = preload("res://scripts/systems/startup_progress.gd")
var startup_complete := false
var expansion_complete := false
var _title_world_hidden := false
var _startup_started := false
var _startup_progress: RefCounted
# R1 fun/polish layer.
var hit_feedback: Node3D
var objective_beacon: Node3D
var run_records: RefCounted
var music: Node
var story_intro: CanvasLayer
var _sfx: Dictionary = {}
var _feedback_mission: int = -1
var _feedback_objective: int = -1
var _ground_texture: NoiseTexture2D
var revisits: Node
var fraud_case: RefCounted
var investigations: RefCounted
var investigation_panel: CanvasLayer

func _ready() -> void:
	if _startup_started: return
	_startup_started = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	set_physics_process(false)
	set_process_unhandled_input(false)
	_startup_progress = StartupScript.new()
	_startup_progress.setup(self)
	if not await _startup_progress.first_frame(): return
	street_state = StreetScript.new()
	street_state.world_radius = WORLD_RADIUS-5.0
	street_state.reset()
	if Engine.has_meta("seven_district_preferences"):
		street_state.from_dict(Engine.get_meta("seven_district_preferences"))
		Engine.remove_meta("seven_district_preferences")
	low_quality = "--low" in OS.get_cmdline_user_args()
	low_quality = low_quality or OS.has_feature("web")
	is_test_mode = "--self-test" in OS.get_cmdline_user_args()
	_register_inputs()
	_create_lighting()
	if not await _startup_progress.checkpoint(0,true): return
	_startup_progress.phase("base_world")
	if not await _create_world(): return
	missions = MissionScript.new()
	add_child(missions)
	optional = OptionalScript.new()
	add_child(optional)
	district_systems = SystemsScript.new()
	add_child(district_systems)
	taiwan_life = TaiwanLifeScript.new()
	add_child(taiwan_life)
	taiwan_activities = TaiwanActivitiesScript.new()
	add_child(taiwan_activities)
	if not await _startup_progress.checkpoint(0,true): return
	_startup_progress.phase("actors")
	if not await _startup_progress.checkpoint(0,true): return
	player = PlayerScript.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.name = "Player"
	add_child(player)
	player.position = Vector3(-56, 0.2, 52)
	if not await _startup_progress.checkpoint(1,true): return
	player.setup_visual(_model("hero"))
	if not await _startup_progress.checkpoint(1,true): return
	player.interaction_requested.connect(_interact)
	player.mount_requested.connect(_mount)
	player.health_changed.connect(_on_health)
	player.attacked.connect(_on_attack)
	_create_vehicles()
	if not await _startup_progress.checkpoint(1,true): return
	_create_guards()
	if not await _startup_progress.checkpoint(1,true): return
	_create_rescues()
	if not await _startup_progress.checkpoint(1,true): return
	_polish_characters()
	_startup_progress.phase("district_life")
	city_life = CityScript.bootstrap(self)
	city_life.process_mode = Node.PROCESS_MODE_PAUSABLE
	city_life.setup(player)
	if not await _startup_progress.checkpoint(0,true): return
	_startup_progress.phase("content_world")
	content_world = ContentWorldScript.new()
	add_child(content_world)
	content_world.setup(self, optional, player)
	if not await _startup_progress.checkpoint(0,true): return
	_startup_progress.phase("contacts")
	_create_contact_people()
	for model: Node3D in contact_people: _apply_character_rim(model)
	if not await _startup_progress.checkpoint(0,true): return
	_startup_progress.phase("expansion_terrain")
	taiwan_expansion = TaiwanExpansionScript.new()
	taiwan_expansion.name = "TaiwanExpansion"
	add_child(taiwan_expansion)
	if not await taiwan_expansion.prepare_world(player): return
	if not await _startup_progress.checkpoint(0,true): return
	_startup_progress.phase("bindings")
	hud = HUDScript.new()
	add_child(hud)
	hud.bind_missions(missions)
	hud.bind_optional(optional)
	hud.bind_systems(district_systems,street_state)
	hud.bind_life(taiwan_life,{"start":_start_life_task,"route":_choose_life_route,"act":_act_life_station,"cancel":_cancel_life_task,"mark":_mark_life_station,"discover":_discover_life_station,"resume":_resume,"activities":_open_activities,"activity_station":_open_station_activity})
	activity_panel = TaiwanActivityPanelScript.new()
	activity_panel.setup(hud,taiwan_activities,{"start":_start_activity,"input":_activity_input,"visit":_visit_activity_station,"cancel":_cancel_activity,"mark":_mark_life_station,"resume":_resume_activity,"close":_open_life})
	hud.bind_activities(taiwan_activities)
	hud.life_requested.connect(_open_life)
	hud.device_selected.connect(_select_device)
	var all_bounds: Array[AABB] = base_obstacle_bounds.duplicate()
	all_bounds.append_array(city_life.get_obstacle_bounds())
	var all_regions: Array[Dictionary] = city_life.get_districts()
	var map_points: Dictionary = {"car":Vector2(car.position.x,car.position.z),"bicycle":Vector2(bicycle.position.x,bicycle.position.z),"mei_shop":Vector2(-58,57),"safe_point":Vector2(-46,42)}
	for id: String in taiwan_life.stations:
		var p: Array = taiwan_life.stations[id]["position"]
		map_points[id] = Vector2(float(p[0]),float(p[1]))
	hud.setup_district_map(all_regions,all_bounds,map_points)
	var empty_roads: Array[Dictionary] = []
	hud.set_expanded_map(WORLD_RADIUS,empty_roads)
	hud.supplies_requested.connect(_open_supplies)
	hud.purchase_requested.connect(_purchase_supply)
	hud.waypoint_selected.connect(_set_waypoint)
	hud.waypoint_cleared.connect(func() -> void: street_state.has_waypoint = false)
	hud.setting_changed.connect(_setting_changed)
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
	hud.menu_opened.connect(touch_controls.release_all)
	touch_controls.camera_step.connect(player.nudge_camera)
	hud.camera_requested.connect(player.nudge_camera)
	touch_controls.phone_requested.connect(hud.show_optional_phone)
	touch_controls.pause_requested.connect(hud.show_pause)
	touch_controls.map_requested.connect(func() -> void: if play_started: hud.show_district_map())
	touch_controls.jobs_requested.connect(_open_life)
	taiwan_life.notice.connect(_notice)
	taiwan_activities.notice.connect(_notice)
	taiwan_life.completed.connect(func(_id: String,_result: Dictionary) -> void: _notice("街坊生活工作已完成，進度可隨存檔保存"))
	optional.notice.connect(_notice)
	optional.rewarded.connect(_optional_rewarded)
	district_systems.notice.connect(_notice)
	district_systems.updated.connect(_refresh_system_stats)
	missions.updated.connect(_on_mission_updated)
	missions.mission_completed.connect(_on_mission_completed)
	missions.chapter_completed.connect(_on_chapter_complete)
	hit_player = AudioStreamPlayer.new()
	add_child(hit_player)
	if ResourceLoader.exists("res://assets/audio/hit.wav"):
		hit_player.stream = load("res://assets/audio/hit.wav")
		hit_player.volume_db = -10
	_setup_fun_layer()
	revisits = RevisitScript.new()
	revisits.persist = not is_test_mode and not Engine.has_meta("seven_district_no_records")
	add_child(revisits)
	revisits.notice.connect(func(text: String) -> void: hud.show_toast(text); _notice(text))
	revisits.completed.connect(func(_id: String) -> void: _play_sfx("mission"); hud.show_revisits())
	hud.bind_revisits(revisits,_start_revisit)
	fraud_case = FraudCaseScript.new()
	fraud_case.changed.connect(_case_changed)
	hud.bind_fraud_case(fraud_case)
	investigations = InvestigationScript.new()
	investigations.changed.connect(func() -> void: _save(false); hud._refresh_mission())
	investigation_panel = InvestigationPanel.new()
	add_child(investigation_panel)
	investigation_panel.setup(hud,investigations)
	var investigation_field := preload("res://scripts/content/investigation_field.gd").new()
	add_child(investigation_field)
	investigation_field.setup(self,investigations)
	hud.investigations = investigations
	hud.investigation_panel = investigation_panel
	device_profiles = DeviceScript.new()
	add_child(device_profiles)
	device_profiles.profile_changed.connect(_device_changed)
	_initialize_device()
	_refresh_system_stats()
	_apply_preferences(false)
	if not _startup_progress.running(): return
	if not _startup_progress.release_to_play(): return
	startup_complete = true
	hud.show_title()
	if music: music.play("title")
	# The title is a CanvasLayer. Suspending its 3D backdrop on mobile keeps
	# the Start button responsive while the outer neighbourhood is constructed.
	if OS.has_feature("mobile"): _set_title_world_hidden(true)
	print("SEVEN_TITLE "+JSON.stringify({"menu":hud.get_menu_mode(),"world_render_suspended":_title_world_hidden,"loading_layer_visible":is_instance_valid(_startup_progress._layer) and _startup_progress._layer.visible}))
	set_process(true)
	set_physics_process(true)
	set_process_unhandled_input(true)
	_setup_web_bridge()
	# The title is drawn and its Start button is live before outer kits are baked.
	# This coroutine keeps the original expansion order and continues through pause.
	call_deferred("_complete_expansion_background")
	if Engine.has_meta("seven_district_autostart"):
		Engine.remove_meta("seven_district_autostart")
		_new_game()

func _complete_expansion_background() -> void:
	if not await _startup_progress.playable_frame(): return
	_startup_progress.phase("urban_detail")
	urban_detail = await UrbanScript.bootstrap(self)
	if not _startup_progress.running() or not is_instance_valid(urban_detail): return
	if not await urban_detail.setup(player): return
	if not _startup_progress.running(): return
	_apply_urban_material_quality()
	# UrbanDetail arrived after the first device-profile pass. Apply the active
	# visibility/shadow budget before building another streamed district.
	device_profiles.apply_scene(self,player)
	district_sun.shadow_enabled = street_state.quality=="quality" and bool(_device_settings.get("shadows",false))
	_startup_progress.phase("expansion")
	taiwan_expansion.seed_streaming_profile(_device_settings)
	if not await taiwan_expansion.build_world():
		if _startup_progress.running(): push_error("TaiwanExpansion did not complete; core remains playable")
		return
	if not _startup_progress.running(): return
	_startup_progress.phase("taiwan_world")
	taiwan_world = TaiwanWorldScript.new()
	add_child(taiwan_world)
	taiwan_world.setup(self,taiwan_life,player)
	if not await _startup_progress.checkpoint(0,true): return
	var all_bounds: Array[AABB] = base_obstacle_bounds.duplicate()
	all_bounds.append_array(city_life.get_obstacle_bounds())
	all_bounds.append_array(taiwan_expansion.get_obstacle_bounds())
	var all_regions: Array[Dictionary] = city_life.get_districts()
	all_regions.append_array(taiwan_expansion.get_regions())
	var map_points: Dictionary = {"car":Vector2(car.position.x,car.position.z),"bicycle":Vector2(bicycle.position.x,bicycle.position.z),"mei_shop":Vector2(-58,57),"safe_point":Vector2(-46,42)}
	for id: String in taiwan_life.stations:
		var p: Array = taiwan_life.stations[id]["position"]
		map_points[id] = Vector2(float(p[0]),float(p[1]))
	hud.setup_district_map(all_regions,all_bounds,map_points)
	hud.set_expanded_map(WORLD_RADIUS,taiwan_expansion.get_navigation_roads())
	if not _device_settings.is_empty():
		taiwan_world.apply_profile(_device_settings)
		taiwan_expansion.apply_profile(_device_settings)
		device_profiles.apply_scene(self,player)
		district_sun.shadow_enabled = street_state.quality=="quality" and bool(_device_settings.get("shadows",false))
	taiwan_expansion.set_hour(street_state.hour)
	if not _startup_progress.running() or not _startup_progress.finish(): return
	expansion_complete = true
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
		"quick_save": KEY_F5, "quick_load": KEY_F9, "district_map":KEY_M,"life_jobs":KEY_J}
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
	if not startup_complete: return
	if event.is_action_pressed("pause") and play_started:
		if get_tree().paused:
			_resume()
		else:
			hud.show_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("phone") and play_started:
		hud.show_phone()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("district_map") and play_started:
		if hud.get_menu_mode()=="map": _resume()
		else: hud.show_district_map()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("life_jobs") and play_started:
		_open_life()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_save") and play_started:
		_save()
	elif event.is_action_pressed("quick_load"):
		_load()

func _process(delta: float) -> void:
	if not startup_complete: return
	_update_web_bridge(delta)
	if music: music.set_ducked(play_started and hud.is_menu_open())
	# R1: a slow orbit gives the title screen a living street backdrop.
	if not play_started and hud.get_menu_mode() == "title" and player: player.nudge_camera(delta * 0.06)
	if optional:
		optional.set_paused(get_tree().paused)
	if district_systems and district_systems.paused != get_tree().paused:
		district_systems.set_paused(get_tree().paused)
	if taiwan_life: taiwan_life.set_paused(get_tree().paused)
	if taiwan_activities:
		var culture_open: bool = play_started and hud._mode=="culture_activity"
		var walk_active: bool = play_started and not get_tree().paused and taiwan_activities.status=="active" and taiwan_activities.activities[taiwan_activities.active_id]["kind"]=="walk"
		taiwan_activities.set_paused(not (culture_open or walk_active))
		if culture_open: taiwan_activities.advance_time(delta)
	if not play_started or get_tree().paused:
		last_frame_time_us = 0
		return
	if not expansion_complete and (absf(player.global_position.x)>145 or absf(player.global_position.z)>145):
		# Outer scenery/colliders are committed together, district by district.
		# Keep the player on known core ground until that full world is ready.
		if player.mounted_vehicle: player.mounted_vehicle.reset()
		var boundary_position := _safe_saved_position(Vector3(clampf(player.global_position.x,-130,130),.2,clampf(player.global_position.z,-130,130)))
		if absf(boundary_position.x)>145 or absf(boundary_position.z)>145:
			boundary_position = Vector3(-56,.2,52)
		player.global_position = boundary_position
		player.velocity = Vector3.ZERO
		_notice("周邊街區還在準備，先在這一區行動。")
	seconds_played += delta
	if revisits: revisits.advance(delta)
	taiwan_life.advance_time(delta)
	street_state.advance(delta)
	_update_daylight(delta)
	district_systems.record_walk(player.global_position,delta,player.mounted_vehicle==null,player.is_on_floor())
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
	if taiwan_life.status in ["active","returning"] and not taiwan_life.get_target_key().is_empty(): active_target = taiwan_life.get_target_key()
	if taiwan_activities.status=="active" and not taiwan_activities.get_target_key().is_empty(): active_target = taiwan_activities.get_target_key()
	if revisits and revisits.active >= 0:
		targets["chapter_revisit"] = revisits.target_position()
		active_target = "chapter_revisit"
	if street_state.has_waypoint:
		targets["custom_waypoint"] = Vector3(street_state.waypoint.x,0.1,street_state.waypoint.y)
		active_target = "custom_waypoint"
		if Vector2(player.position.x,player.position.z).distance_to(street_state.waypoint)<3:
			street_state.has_waypoint = false
			_notice("已到達自訂目的地，恢復任務導引")
	if investigations and investigations.pending() >= 0:
		targets["investigation"] = investigations.target_position()
		active_target = "investigation"
	elif investigations and not investigations.street_result().is_empty() and not investigations.street_at_source:
		targets["investigation"] = investigations.result_position()
		active_target = "investigation"
	targets["car"] = car.position
	targets["bicycle"] = bicycle.position
	for id: String in guards:
		targets[id] = guards[id].position
	if targets.has(active_target):
		hud.set_map_markers(Vector2(player.global_position.x, player.global_position.z), Vector2(targets[active_target].x, targets[active_target].z))
	_update_guidance(active_target)
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
	if touch_controls.enabled:
		prompt = prompt.replace("左鍵｜","點攻擊｜").replace("E｜","點互動｜").replace("F｜","點上下車｜")
		if player.mounted_vehicle: prompt = "點上下車可下車｜跳／煞可煞車｜取回可重置"
		var verb := ""
		if nearest: verb = "攻擊" if nearest.get("event_name") in ["practice_hit","destroy_target","sandbox"] else "交談" if nearest.get("event_name") == "talk_mei" else "互動"
		if nearest and not player.mounted_vehicle:
			prompt = ("點攻擊｜" if verb == "攻擊" else "點互動｜")+_caption(nearest)
		if revisits and revisits.is_near(player.global_position,player.mounted_vehicle == null):
			verb = "核對" if revisits.step == 1 else "記錄"
			prompt = "點右下綠鍵｜"+revisits.active_text()
		touch_controls.set_interaction_context(verb if verb != "攻擊" else "")
		touch_controls.set_action_context((nearest != null and nearest.get("event_name") in ["practice_hit","destroy_target","sandbox"]) or not guards.values().filter(func(g: Node3D) -> bool: return g.global_position.distance_to(player.global_position) < 8.0).is_empty(),player.mounted_vehicle != null)
	if investigations and investigations.nearby(player.global_position,player.mounted_vehicle == null):
		prompt = "點互動留證｜"+investigations.definition().documents[investigations.pending()].place if touch_controls.enabled else "E｜核對新案件原件"
		touch_controls.set_interaction_context("留證")
	if investigations.street_at_source and not investigations.street_result().is_empty():
		touch_controls.set_interaction_context("互動")
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
	hud.update_survival(player.stamina,player.maximum_stamina,street_state.time_text(),touch_controls.enabled)
	hud.update_world_vehicles(Vector2(car.position.x,car.position.z),Vector2(bicycle.position.x,bicycle.position.z))
	if player.global_position.y < -12 or absf(player.global_position.x) > WORLD_RADIUS or absf(player.global_position.z) > WORLD_RADIUS:
		if player.mounted_vehicle: player.mounted_vehicle.reset()
		player.global_position = Vector3(-56, 0.2, 52)
		player.velocity = Vector3.ZERO
		_notice("已返回安全街區")

func _create_lighting() -> void:
	var world := WorldEnvironment.new()
	district_environment = world
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := PanoramaSkyMaterial.new()
	sky_material.panorama = load("res://assets/art/r8/dusk-sky.webp")
	sky.sky_material = sky_material
	env.sky = sky
	# R1: sky-tinted ambient (mixed with a warm fill colour) instead of a flat
	# grey fill, mild glow for the guidance beacon/sparks and a gentle grade.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_sky_contribution = 0.30
	env.ambient_light_color = Color(0.69, 0.78, 0.86)
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.10
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.95
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.96
	env.adjustment_contrast = 1.02
	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.76, 0.80)
	env.fog_density = 0.0014
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.set_meta("device_original_shadow",true)
	district_sun = sun
	sun.rotation_degrees = Vector3(-37, -32, 0)
	sun.light_color = Color(1.0, 0.86, 0.69)
	sun.light_energy = 0.75
	sun.shadow_enabled = not low_quality
	add_child(sun)

func _create_world() -> bool:
	if not _startup_progress.running(): return false
	_ground(Vector3(0, -0.16, 0), Vector3(300, 0.30, 300), Color(0.50, 0.50, 0.45))
	if not await _startup_progress.checkpoint(): return false
	var shop_model: Node3D = _building("urban_shopfront",Vector3(-54,0,65),Vector3(16,8,8))
	if shop_model: shop_model.rotation.y = PI
	if not await preload("res://scripts/world/opening_street.gd").dress(self): return false
	if not await _startup_progress.checkpoint(): return false
	# Narrow arcade paving and asphalt forecourt have distinct materials.
	_ground(Vector3(-55,0.034,47),Vector3(28,0.025,30),Color("57514a"),false)
	if not await _startup_progress.checkpoint(): return false
	for x: float in [-62.0,-58.8,-55.6,-52.4]:
		_ground(Vector3(x,0.061,35),Vector3(0.10,0.01,5.5),Color("e5d9af"),false)
		if not await _startup_progress.checkpoint(): return false
	_ground(Vector3(-57.2,0.061,32.25),Vector3(9.6,0.01,0.10),Color("e5d9af"),false)
	if not await _startup_progress.checkpoint(): return false
	_ground(Vector3(0, 0.005, 0), Vector3(300, 0.06, 15), Color(0.14, 0.17, 0.19))
	if not await _startup_progress.checkpoint(): return false
	_ground(Vector3(0, 0.005, 0), Vector3(15, 0.06, 300), Color(0.14, 0.17, 0.19))
	if not await _startup_progress.checkpoint(): return false
	for z: float in [-76.0, 76.0]:
		_ground(Vector3(0, 0.005, z), Vector3(160, 0.06, 12), Color(0.16, 0.19, 0.20))
		if not await _startup_progress.checkpoint(): return false
	for x: float in [-76.0, 76.0]:
		_ground(Vector3(x, 0.005, 0), Vector3(12, 0.06, 160), Color(0.16, 0.19, 0.20))
		if not await _startup_progress.checkpoint(): return false
	for i: int in range(-7, 8):
		_ground(Vector3(i * 18.0, 0.046, 0), Vector3(7, 0.01, 0.12), Color(0.95, 0.89, 0.65), false)
		if not await _startup_progress.checkpoint(): return false
		_ground(Vector3(0, 0.046, i * 18.0), Vector3(0.12, 0.01, 7), Color(0.95, 0.89, 0.65), false)
		if not await _startup_progress.checkpoint(): return false
	for x: float in [-20.0, 22.0, 60.0, -58.0, 104.0, -108.0]:
		for z: float in [-42.0, -112.0]:
			var which := "office_tower_a" if int(absf(x)) % 3 == 0 else "office_tower_b"
			_building(which, Vector3(x, 0, z), Vector3(18, 30 + absf(x) * 0.15, 19))
			if not await _startup_progress.checkpoint(): return false
	_building("office_tower_c", Vector3(-59, 0, 90), Vector3(24, 14, 19))
	if not await _startup_progress.checkpoint(): return false
	_building("office_tower_c", Vector3(58, 0, 95), Vector3(23, 22, 19))
	if not await _startup_progress.checkpoint(): return false
	_ground(Vector3(37, 0.055, 32), Vector3(49, 0.1, 43), Color(0.67, 0.67, 0.61))
	if not await _startup_progress.checkpoint(): return false
	_place("office_lobby", Vector3(38, 0.1, 28))
	if not await _startup_progress.checkpoint(): return false
	for i: int in range(14):
		var z: float = -115.0 + float(i) * 17.0
		_place("tree", Vector3(11, 0.04, z))
		if not await _startup_progress.checkpoint(): return false
		_place("tree", Vector3(-11, 0.04, z))
		if not await _startup_progress.checkpoint(): return false
		if i % 2 == 0:
			_place("streetlight", Vector3(10, 0.04, z + 5))
			if not await _startup_progress.checkpoint(): return false
	for p: Vector3 in [Vector3(-52, 0, 39), Vector3(21, 0, 20), Vector3(59, 0, 21), Vector3(-38, 0, -15)]:
		_place("planter", p)
		if not await _startup_progress.checkpoint(): return false
		_place("bench", p + Vector3(3, 0, 1))
		if not await _startup_progress.checkpoint(): return false
	_add_object("mei", "美晴車店｜交談", "talk_mei", "desk", Vector3(-52, 0.10, 57), Vector3(1.5, 1.0, 0.8))
	if not await _startup_progress.checkpoint(): return false
	_add_object("supply_shop", "美晴補給台｜補給與整備", "supply_menu", "desk", Vector3(-58,0.10,57),Vector3(1.5,1.0,0.8))
	if not await _startup_progress.checkpoint(): return false
	_add_object("phone", "查看失聯訊息", "read_phone", "display", Vector3(-54, 0.10, 59), Vector3(0.5, 1.0, 0.4))
	if not await _startup_progress.checkpoint(): return false
	_add_object("wrench", "借用扳手", "pickup_wrench", "wrench", Vector3(-48, 0.25, 56), Vector3(0.7, 0.5, 0.4))
	if not await _startup_progress.checkpoint(): return false
	_add_object("practice_1", "練習目標 A", "practice_hit", "barrier", Vector3(-44, 0.05, 53), Vector3(1, 1.1, 0.4), true)
	if not await _startup_progress.checkpoint(): return false
	_add_object("practice_2", "練習目標 B", "practice_hit", "barrier", Vector3(-41, 0.05, 53), Vector3(1, 1.1, 0.4), true)
	if not await _startup_progress.checkpoint(): return false
	_add_object("service_gate", "替代路線｜側門", "alternate_route", "barrier", Vector3(-21, 0.1, -14), Vector3(1.4, 1.4, 0.3))
	if not await _startup_progress.checkpoint(): return false
	_add_object("fake_sign", "恆曜假客服招牌", "disable_sign", "sign", Vector3(-37, 0.1, -21), Vector3(2.6, 1.7, 0.5), true)
	if not await _startup_progress.checkpoint(): return false
	_add_object("pass", "前站通行物", "collect_pass", "display", Vector3(-33, 0.15, -26), Vector3(0.6, 0.8, 0.5))
	if not await _startup_progress.checkpoint(): return false
	_add_object("summary", "保存留言摘要", "collect_evidence", "display", Vector3(-40, 0.15, -26), Vector3(0.7, 0.8, 0.5))
	if not await _startup_progress.checkpoint(): return false
	_add_object("mei_shop", "車店集合點", "return_shop", "sign", Vector3(-56, 0.1, 43), Vector3(1.1, 1.2, 0.3))
	if not await _startup_progress.checkpoint(): return false
	_add_object("shift_note", "保存輪班便條", "collect_evidence", "display", Vector3(27, 0.1, 31), Vector3(0.6, 1.0, 0.5))
	if not await _startup_progress.checkpoint(): return false
	_add_object("branch_console", "選擇行動重心｜E", "branch_menu", "display", Vector3(32, 0.1, 25), Vector3(0.8, 1.2, 0.5))
	if not await _startup_progress.checkpoint(): return false
	for i: int in range(1, 4):
		_add_object("equipment_%d" % i, "詐團設備 %d" % i, "destroy_target", ["server", "desk", "display"][i - 1], Vector3(37 + i * 3, 0.1, 23), Vector3(1.5, 1.6, 0.8), true)
		if not await _startup_progress.checkpoint(): return false
	_add_object("record_1", "保存紀錄 A", "collect_evidence", "display", Vector3(28, 0.15, 19), Vector3(0.6, 0.9, 0.5), true)
	if not await _startup_progress.checkpoint(): return false
	_add_object("record_2", "保存紀錄 B", "collect_evidence", "display", Vector3(31, 0.15, 19), Vector3(0.6, 0.9, 0.5), true)
	if not await _startup_progress.checkpoint(): return false
	_add_object("console", "中止前站營運", "disable_console", "server", Vector3(47, 0.1, 18), Vector3(1.2, 1.6, 0.8))
	if not await _startup_progress.checkpoint(): return false
	_add_object("bat_pickup", "撿取球棒", "pickup_weapon", "bat", Vector3(-22, 0.15, 14), Vector3(0.7, 0.5, 0.4))
	if not await _startup_progress.checkpoint(): return false
	_add_object("pulse_pickup", "撿取虛構脈衝器具", "pickup_weapon", "pulse", Vector3(19, 0.15, 22), Vector3(0.7, 0.5, 0.4))
	if not await _startup_progress.checkpoint(): return false
	for i: int in range(8):
		var model_name: String = ["barrier", "glass", "desk", "sign", "server", "display"][i % 6]
		_add_object("sandbox_%d" % i, "沙盒試打物", "sandbox", model_name, Vector3(80 + (i % 4) * 4, 0.1, 31 + (i / 4) * 6), Vector3(1.0, 1.5, 0.5), true)
		if not await _startup_progress.checkpoint(): return false
	var routes: Array[Vector3] = [Vector3(-75, 0.1, 25), Vector3(-75, 0.1, -55), Vector3(-15, 0.1, -75)]
	for i: int in range(3):
		targets["route_%d" % (i + 1)] = routes[i]
		_marker("路標 %d" % (i + 1), routes[i], Color(1.0, 0.67, 0.24))
		if not await _startup_progress.checkpoint(): return false
	targets["safe_point"] = Vector3(-46, 0.1, 42)
	_marker("撤離安全點", targets["safe_point"], Color(0.30, 0.95, 0.65))
	if not await _startup_progress.checkpoint(): return false
	return _startup_progress.running()

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
		guard.add_child(ContactShadowScript.new())
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
		var characters: Dictionary = {"rescue_A":"civilian_human","rescue_B":"zhou_human","extra_A":"yuan_human","extra_B":"civilian_human"}
		person.configure(id, _model(characters[id]))
		add_child(person)
		person.position = positions[id]
		person.add_child(ContactShadowScript.new())
		person.target = player
		person.safe_arrival.connect(_safe_arrival)
		people[id] = person
		targets[id] = person.position

func _add_object(id: String, caption: String, event: String, model_name: String, p: Vector3, size: Vector3, can_break: bool = false) -> void:
	var object: StaticBody3D = ObjectScript.new()
	object.configure(id, caption, event, _model(model_name), size, can_break)
	if id in ["mei","supply_shop"] and object.visual:
		preload("res://scripts/world/street_art.gd").dress_counter(object.visual)
		object.visual.visible = false
	object.damage_gate = _can_damage_object
	add_child(object)
	object.position = p
	object.text_label.visibility_range_end = 24.0
	object.text_label.font_size = 26
	object.text_label.pixel_size = 0.007
	object.text_label.visible = false
	if id == "wrench" and object.visual: object.visual.visible = false
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
	# R1: large surfaces get a subtle world-space paving/asphalt grain instead
	# of a flat fill; thin road markings stay crisp.
	if size.x * size.z >= 40.0:
		material.albedo_texture = _ground_grain()
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE * 0.6
	render.material_override = material
	body.add_child(render)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	add_child(body)

func _ground_grain() -> NoiseTexture2D:
	if _ground_texture: return _ground_texture
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.09
	noise.fractal_octaves = 4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.86, 0.86, 0.84))
	ramp.set_color(1, Color(1.0, 1.0, 0.98))
	_ground_texture = NoiseTexture2D.new()
	_ground_texture.width = 256
	_ground_texture.height = 256
	_ground_texture.seamless = true
	_ground_texture.noise = noise
	_ground_texture.color_ramp = ramp
	_ground_texture.generate_mipmaps = true
	return _ground_texture

func _model(key: String) -> PackedScene:
	if key == "hero": return load("res://assets/models/r10/hero_human.glb") as PackedScene
	if key == "mei_human": return load("res://assets/models/r9/mei_human.glb") as PackedScene
	var aliases: Dictionary = {"hero":"hero_human","guard":"guard_human","civilian":"civilian_human","office_tower_a":"urban_tower_a","office_tower_b":"urban_tower_b","office_tower_c":"urban_tower_c"}
	var upgraded: String = str(aliases.get(key,key))
	if ResourceLoader.exists("res://assets/models/%s.glb" % upgraded): key = upgraded
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

func _building(key: String, p: Vector3, size: Vector3) -> Node3D:
	var model := _place(key, p)
	if not model:
		return null
	var bounds := _visual_bounds(model)
	if bounds.size.x > 0.01 and bounds.size.y > 0.01 and bounds.size.z > 0.01:
		model.scale = size / bounds.size
	preload("res://scripts/world/street_art.gd").dress_building(model, key == "urban_shopfront")
	if key == "urban_shopfront": preload("res://scripts/world/street_art.gd").dress_shop(self)
	var body := StaticBody3D.new()
	body.position = p + Vector3(0, size.y * 0.5, 0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	base_obstacle_bounds.append(AABB(p - Vector3(size.x * 0.5, 0, size.z * 0.5), size))
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return model

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
	label.pixel_size = 0.007
	label.visibility_range_end = 55.0
	label.modulate = color
	if ResourceLoader.exists("res://assets/fonts/SevenDistrictSansTC-Regular.otf"):
		label.font = load("res://assets/fonts/SevenDistrictSansTC-Regular.otf") as Font
	add_child(label)

func _new_game() -> void:
	if not startup_complete: return
	if play_started and not is_test_mode:
		Engine.set_meta("seven_district_autostart", true)
		Engine.set_meta("seven_district_preferences",street_state.to_dict())
		get_tree().reload_current_scene()
		return
	_set_title_world_hidden(false)
	_resume()
	play_started = true
	seconds_played = 0
	heat = 0
	route_done.clear()
	for object: StaticBody3D in objects.values():
		object.restore({})
	optional.reset()
	if revisits: revisits.cancel()
	if fraud_case: fraud_case.reset()
	if investigations: investigations.reset()
	taiwan_life.reset()
	taiwan_activities.reset()
	district_systems.reset()
	street_state.hour = 17.25
	street_state.has_waypoint = false
	_apply_preferences()
	for person: CharacterBody3D in people.values():
		person.following = false
		person.arrived = false
	player.clear_inventory()
	player.restore_health()
	car.force_release()
	bicycle.force_release()
	car.reset()
	bicycle.reset()
	_feedback_mission = 0
	_feedback_objective = 0
	missions.start_campaign()
	if hud: hud.set_chain_progress(0)
	if hit_feedback: hit_feedback.reset_combo()
	if music: music.play("street")
	player.global_position = Vector3(-56, 0.2, 52)
	player.reset_view(PI+atan2(4.0,5.0))
	player.velocity = Vector3.ZERO
	checkpoint_state = _snapshot(false)
	_announce_mission()

func _case_changed() -> void:
	_save(false)
	if hud and fraud_case.stage == 4: _play_sfx("objective")

func _resume() -> void:
	if not startup_complete: return
	if investigation_panel: investigation_panel.dismiss()
	if hud and hud.has_method("hide_menus"):
		hud.hide_menus()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if OS.has_feature("web") or (touch_controls and touch_controls.enabled) else Input.MOUSE_MODE_CAPTURED

func _set_title_world_hidden(value: bool) -> void:
	_title_world_hidden = value
	visible = not value

func _initialize_device() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var touch: bool = DisplayServer.is_touchscreen_available()
	var hint: String = OS.get_name().to_lower()
	var requested: String = "auto"
	if OS.has_feature("web"):
		var window = JavaScriptBridge.get_interface("window")
		var device = window.sevenDistrictDevice
		if device:
			touch = bool(device.pointer_touch)
			hint = str(device.device_hint)
			requested = str(device.requested_profile)
			viewport_size = Vector2(float(window.innerWidth),float(window.innerHeight))
	elif OS.has_feature("mobile"):
		var dpi: float = maxf(160,DisplayServer.screen_get_dpi())
		viewport_size = Vector2(DisplayServer.screen_get_size())*(160.0/dpi)
		hint = "phone" if minf(viewport_size.x,viewport_size.y)<600 else "tablet"
		# Keep native UI coordinates in density-independent units, as the Web
		# profiles already do. Canvas-items stretching preserves the 3D aspect.
		get_window().content_scale_size = Vector2i(viewport_size)
	device_profiles.initialize(viewport_size,touch,hint,not is_test_mode)
	if requested in ["phone","tablet","desktop"]: device_profiles.set_profile(requested,not is_test_mode)
	_device_changed(device_profiles.get_settings())

func _select_device(value: String) -> void:
	if device_profiles: device_profiles.set_profile(value,not is_test_mode)

func _device_changed(settings: Dictionary) -> void:
	_device_settings = settings.duplicate(true)
	if not expansion_complete and is_instance_valid(taiwan_expansion):
		taiwan_expansion.seed_streaming_profile(settings)
	if not player or not hud or not touch_controls: return
	touch_controls.set_profile(settings)
	touch_controls.set_enabled(str(settings.get("input_mode","keyboard_mouse"))=="touch")
	hud.set_device_profile(settings)
	if expansion_complete:
		taiwan_world.apply_profile(settings)
		taiwan_expansion.apply_profile(settings)
	device_profiles.apply_scene(self,player)
	district_sun.shadow_enabled = street_state.quality=="quality" and bool(settings.get("shadows",false))
	player.mouse_sensitivity = .003*float(settings.get("sensitivity",1))
	if settings.has("muted"): AudioServer.set_bus_mute(0,bool(settings["muted"]))
	_emit_web_state()

func _outer_world_loading_notice() -> void:
	var message := "周邊街區還在準備，稍後就能使用這項功能。"
	_notice(message)
	if hud: hud.show_message(message)

func _open_life() -> void:
	if play_started: hud.show_life_phone()

func _open_activities() -> void:
	if play_started: activity_panel.show_directory()

func _open_station_activity(id: String) -> void:
	if play_started and taiwan_activities.activities.has(id): activity_panel.show_activity(id)

func _start_activity(id: String) -> void:
	if not play_started: return
	if not expansion_complete:
		_outer_world_loading_notice()
		return
	taiwan_activities.set_paused(false)
	taiwan_activities.start(id,player.global_position,_activity_vehicle())
	activity_panel.show_activity(id)

func _activity_vehicle() -> String:
	var vehicle: String = _life_vehicle()
	return "foot" if vehicle=="on_foot" else vehicle

func _activity_input(action: String) -> void:
	if not play_started or hud._mode!="culture_activity": return
	taiwan_activities.set_paused(false)
	taiwan_activities.handle_input(action)

func _visit_activity_station(id: String) -> void:
	if not play_started: return
	taiwan_activities.set_paused(false)
	taiwan_activities.visit_station(id,player.global_position,_activity_vehicle())
	if not taiwan_activities.active_id.is_empty(): activity_panel.show_activity(taiwan_activities.active_id)

func _cancel_activity() -> void:
	taiwan_activities.cancel()
	activity_panel.show_directory()

func _resume_activity() -> void:
	if taiwan_activities.status=="active" and taiwan_activities.activities[taiwan_activities.active_id]["kind"]!="walk": taiwan_activities.cancel()
	_resume()

func _start_life_task(id: String) -> void:
	if not play_started: return
	if not expansion_complete:
		_outer_world_loading_notice()
		return
	if taiwan_life.start_task(id):
		_resume()
	else: hud.show_life_phone()

func _choose_life_route(id: String) -> void:
	if taiwan_life.choose_route(id): _resume()
	else: hud.show_life_phone()

func _cancel_life_task() -> void:
	taiwan_life.cancel_task()
	hud.show_life_phone()

func _life_vehicle() -> String:
	return "bicycle" if player.mounted_vehicle==bicycle else "car" if player.mounted_vehicle==car else "on_foot"

func _act_life_station(id: String, item: String = "", code: String = "") -> void:
	if not play_started: return
	var step: Dictionary = taiwan_life.get_current_step()
	var was_paused: bool = taiwan_life.paused
	taiwan_life.set_paused(false)
	var accepted: bool = taiwan_life.handle_action(str(step.get("action","")),id,_life_vehicle(),player.global_position,item,code)
	taiwan_life.set_paused(was_paused)
	if accepted:
		if taiwan_life.status=="choosing": hud.show_life_phone()
		else: _resume()
	else: hud.show_life_station(id)

func _mark_life_station(id: String) -> void:
	if not taiwan_life.stations.has(id): return
	var point: Array = taiwan_life.stations[id]["position"]
	_set_waypoint(Vector2(float(point[0]),float(point[1])))
	hud.show_district_map()

func _discover_life_station(id: String) -> void:
	if play_started: taiwan_life.discover_station(id,player.global_position)

func _create_contact_people() -> void:
	var entries: Array = [
		["mei_human",Vector3(-52,0.12,57),"美晴｜車店主理人"],
		["yuan_human",Vector3(-99,0.06,98),"予安｜街區整理者"],
		["zhou_human",Vector3(-48,0.06,40),"周成｜集合點"]
	]
	for entry: Array in entries:
		var model: Node3D = _place(str(entry[0]),entry[1])
		if not model: continue
		model.process_mode = Node.PROCESS_MODE_PAUSABLE
		if str(entry[0])=="mei_human":
			model.rotation.y = PI + atan2(4.0,5.0)
			model.scale = Vector3.ONE*1.15
			targets["mei"] = model.global_position
			preload("res://scripts/world/opening_street.gd").dress_mei(model)
			for mesh: Node in model.find_children("*","MeshInstance3D",true,false):
				for i: int in mesh.mesh.get_surface_count():
					var old: Material = mesh.get_active_material(i)
					if old is StandardMaterial3D:
						var face: StandardMaterial3D = old.duplicate()
						face.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
						if old.resource_name.contains("Skin"): face.albedo_texture = load("res://assets/art/content-r13/meiqing-skin.png")
						mesh.set_surface_override_material(i,face)
		model.add_child(ContactShadowScript.new())
		contact_people.append(model)
		var animations: Array[Node] = model.find_children("*","AnimationPlayer",true,false)
		if not animations.is_empty():
			var animation: AnimationPlayer = animations[0] as AnimationPlayer
			for name_value: StringName in animation.get_animation_list():
				if str(name_value)=="idle" or str(name_value).ends_with("/idle"):
					animation.get_animation(name_value).loop_mode = Animation.LOOP_LINEAR
					animation.play(name_value)
					break
		var label := Label3D.new()
		label.text = str(entry[2])
		label.position.y = 1.97
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font = load("res://assets/fonts/SevenDistrictSansTC-Regular.otf") as Font
		label.font_size = 28
		label.pixel_size = 0.012
		label.visible = str(entry[0]) == "mei_human"
		label.visibility_range_end = 18
		label.pixel_size = .006
		label.modulate = Color("dfd4ac")
		model.add_child(label)

func _is_near_supply_shop() -> bool:
	return play_started and player.global_position.distance_to(Vector3(-58,0.1,57))<=6.0 and player.mounted_vehicle==null

func _open_supplies() -> void:
	if play_started: hud.show_systems(_is_near_supply_shop())

func _purchase_supply(id: String) -> void:
	if not _is_near_supply_shop():
		_notice("到美晴車店補給台附近，先下車再購買")
		hud.show_systems(false)
		return
	var result: Dictionary = district_systems.purchase(id,player.health)
	if result.get("ok",false):
		var effects: Dictionary = result["effects"]
		if effects.has("health_after"): player.heal(float(effects["health_after"])-player.health)
		_refresh_system_stats()
	hud.show_systems(true)

func _refresh_system_stats() -> void:
	if not district_systems or not player or not bicycle: return
	var stats: Dictionary = district_systems.get_stats()
	player.maximum_stamina = float(stats["max_stamina"])
	player.stamina = minf(player.stamina,player.maximum_stamina)
	player.tool_damage_multiplier = float(stats["tool_damage_multiplier"])
	bicycle.acceleration_multiplier = float(stats["bike_accel_multiplier"])

func _optional_rewarded(reward: Dictionary) -> void:
	if not freeze_events and reward.get("first_completion",false):
		var task_id: String = str(reward.get("task_id",""))
		district_systems.record_action("side_completed",task_id,"optional:"+task_id)
	_notice("街坊委託成果已記錄")

func _set_waypoint(point: Vector2) -> void:
	if not play_started or not point.is_finite(): return
	if not expansion_complete and (absf(point.x)>=150 or absf(point.y)>=150):
		_outer_world_loading_notice()
		return
	var desired := Vector3(point.x,0.12,point.y)
	var safe_position: Vector3 = content_world._safe_location(desired) if absf(point.x)<150 and absf(point.y)<150 else _safe_expansion_point(desired)
	if street_state.set_waypoint(Vector2(safe_position.x,safe_position.z)):
		_notice("已標示目的地；青色方向線提供導引")

func _safe_expansion_point(point: Vector3) -> Vector3:
	for offset: Vector3 in [Vector3.ZERO,Vector3(6,0,0),Vector3(-6,0,0),Vector3(0,0,6),Vector3(0,0,-6),Vector3(12,0,0),Vector3(-12,0,0),Vector3(0,0,12),Vector3(0,0,-12),Vector3(24,0,0),Vector3(-24,0,0)]:
		var candidate: Vector3 = point+offset
		if taiwan_expansion.is_walkable(candidate,.8): return candidate
	return Vector3(clampf(point.x,-395,395),.12,clampf(point.z,-395,395))

func _safe_saved_position(point: Vector3) -> Vector3:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.85
	for offset: Vector3 in [Vector3.ZERO,Vector3(0,0,-6),Vector3(6,0,-6),Vector3(-6,0,-6),Vector3(0,0,6),Vector3(10,0,0),Vector3(-10,0,0)]:
		var candidate: Vector3 = content_world._safe_location(point+offset)
		candidate.y = maxf(candidate.y,0.08)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY,candidate+Vector3.UP*0.98)
		query.collision_mask = 3
		query.exclude = [player.get_rid()]
		if get_world_3d().direct_space_state.intersect_shape(query,4).is_empty(): return candidate
	return Vector3(-56,0.2,52)

func _setting_changed(key: String, value: String) -> void:
	match key:
		"quality":
			if value in StreetScript.QUALITIES: street_state.quality = value
		"difficulty":
			if value in StreetScript.DIFFICULTIES: street_state.difficulty = value
		"sensitivity":
			if value in ["0.7","1.0","1.4"]:
				street_state.sensitivity = float(value)
				if device_profiles: device_profiles.set_preference("sensitivity",float(value),not is_test_mode)
		"muted":
			if value in ["off","on"]:
				street_state.muted = value=="on"
				if device_profiles: device_profiles.set_preference("muted",street_state.muted,not is_test_mode)
		"cycle":
			if value in ["off","on"]: street_state.cycle_enabled = value=="on"
		"hour":
			if value in ["10.0","17.5","21.0"]: street_state.hour = float(value)
	_apply_preferences()

func _apply_preferences(apply_device_scene: bool = true) -> void:
	if not player or not district_sun: return
	player.mouse_sensitivity = 0.003 * street_state.sensitivity
	player.incoming_damage_multiplier = 0.65 if street_state.difficulty=="relaxed" else 1.0
	for guard: CharacterBody3D in guards.values():
		guard.detection_range = 11.0 if street_state.difficulty=="relaxed" else 14.0
		guard.chase_speed = 2.5 if street_state.difficulty=="relaxed" else 3.2
	district_sun.shadow_enabled = street_state.quality=="quality" and not ("--low" in OS.get_cmdline_user_args())
	_apply_urban_material_quality()
	AudioServer.set_bus_mute(0,street_state.muted)
	if device_profiles:
		var settings: Dictionary = device_profiles.get_settings()
		player.mouse_sensitivity = .003*float(settings.get("sensitivity",1))
		AudioServer.set_bus_mute(0,bool(settings.get("muted",false)))
		if apply_device_scene: device_profiles.apply_scene(self,player)
		district_sun.shadow_enabled = street_state.quality=="quality" and bool(settings.get("shadows",false))
	_update_daylight(1.0)

func _apply_urban_material_quality() -> void:
	if not urban_detail: return
	for material: StandardMaterial3D in urban_detail._materials.values():
		material.normal_enabled = street_state.quality!="performance" and material.normal_texture!=null
		material.ao_enabled = street_state.quality!="performance" and material.ao_texture!=null

var _last_lit_hour := INF
var _last_lit_quality := ""

func _update_daylight(delta: float) -> void:
	_light_clock += delta
	if _light_clock < 0.2 or not district_environment: return
	_light_clock = 0
	var daylight: float = street_state.daylight()
	if expansion_complete: taiwan_expansion.set_hour(street_state.hour)
	# A paused clock or fixed-hour setting should not resend identical sky and
	# lighting resources. The normal day/night cycle still updates at 5 Hz.
	if is_equal_approx(_last_lit_hour,street_state.hour) and _last_lit_quality == street_state.quality: return
	_last_lit_hour = street_state.hour
	_last_lit_quality = street_state.quality
	var dusk: float = 1.0-clampf(absf(street_state.hour-17.5)/3.8,0,1)
	var env: Environment = district_environment.environment
	# Civil clock time maps to a sun still above the horizon at dusk.
	district_sun.rotation_degrees = Vector3(-maxf(8.0,sin((street_state.hour-6.0)*PI/12.0)*65.0),-55,0)
	if daylight<=0.01: district_sun.rotation_degrees = Vector3(-45,35,0)
	district_sun.light_energy = lerpf(0.13,1.0,daylight)
	district_sun.light_color = Color(0.75,0.82,1.0).lerp(Color(1.0,0.96,0.87),daylight).lerp(Color(1.0,0.61,0.35),dusk*0.6)
	env.ambient_light_energy = lerpf(0.30,0.62,daylight) + dusk*0.16
	env.ambient_light_color = Color("667792").lerp(Color("d8d2c4"),daylight).lerp(Color("e0b48c"),dusk*0.3)
	env.fog_light_color = Color("2e394e").lerp(Color("bcc9cc"),daylight).lerp(Color("d49d72"),dusk*0.3)
	env.fog_density = 0.0030 if street_state.quality=="performance" else 0.0036
	var sky_material := env.sky.sky_material as PanoramaSkyMaterial
	sky_material.energy_multiplier = lerpf(0.20,2.1,daylight)
	env.fog_sky_affect = 0.0

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
		"new_game": _start_story()
		"pause":
			if play_started: hud.show_pause()
		"phone":
			if play_started: hud.show_optional_phone()
		"revisits":
			if play_started: hud.show_revisits()
		"case":
			if play_started: hud.show_fraud_case()
		"investigations":
			if play_started: hud.show_investigations()
		"map":
			if play_started: hud.show_district_map()
		"supplies": _open_supplies()
		"settings": hud.show_settings()
		"jobs": _open_life()
		"profile_auto": _select_device("auto")
		"profile_phone": _select_device("phone")
		"profile_tablet": _select_device("tablet")
		"profile_desktop": _select_device("desktop")
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
	var ratio: float = clampf(float(_web_window.devicePixelRatio),1.0,2.0)
	var device = _web_window.sevenDistrictDevice
	if device: ratio = clampf(float(device.pixel_ratio),1.0,2.0)
	var logical_size := Vector2i(roundi(get_window().size.x / ratio), roundi(get_window().size.y / ratio))
	if logical_size.x > 0 and logical_size.y > 0 and get_window().content_scale_size != logical_size:
		get_window().content_scale_size = logical_size
	_emit_web_state()

func _emit_web_state() -> void:
	if _web_window == null or not hud or not optional: return
	var state = JavaScriptBridge.create_object("Object")
	state.phase = "title" if not play_started else ("menu" if get_tree().paused else "playing")
	state.play_started = play_started
	state.version = str(ProjectSettings.get_setting("application/config/version",""))
	state.device_profile = device_profiles.get_profile() if device_profiles else "desktop"
	state.requested_profile = device_profiles.get_requested_profile() if device_profiles else "auto"
	state.resolution_scale = get_viewport().scaling_3d_scale
	state.camera_distance = player.get_camera().far
	state.touch_controls = touch_controls.enabled
	state.visible_citizens = 0
	state.visible_traffic = 0
	for actor: Node3D in get_tree().get_nodes_in_group("ambient_citizens"):
		if actor.visible: state.visible_citizens = int(state.visible_citizens)+1
	for actor: Node3D in get_tree().get_nodes_in_group("ambient_traffic"):
		if actor.visible: state.visible_traffic = int(state.visible_traffic)+1
	state.draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	state.render_primitives = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	state.process_ms = float(Performance.get_monitor(Performance.TIME_PROCESS))*1000.0
	state.physics_ms = float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))*1000.0
	state.frame_fps = int(Performance.get_monitor(Performance.TIME_FPS))
	state.life_title = taiwan_life.get_active_title() if taiwan_life else ""
	state.life_objective = taiwan_life.get_active_text() if taiwan_life else ""
	state.life_cash = taiwan_life.cash if taiwan_life else 0
	state.cargo_count = taiwan_life.cargo.size() if taiwan_life else 0
	state.culture_activity = taiwan_activities.active_id if taiwan_activities else ""
	state.culture_badges = taiwan_activities.badges.size() if taiwan_activities else 0
	state.stamina = player.stamina
	state.max_stamina = player.maximum_stamina
	state.credits = district_systems.credits
	state.rank = str(district_systems.get_status()["rank_name"])
	state.time = street_state.time_text()
	state.navigation = "自訂目的地" if street_state.has_waypoint else "任務導引"
	state.main_title = hud._player_mission_title()
	state.revisit = revisits.active_text() if revisits else ""
	state.notebook_pages = revisits.records.size() if revisits else 0
	state.case_stage = fraud_case.stage if fraud_case else 0
	if investigations:
		var actions: Array = []
		for button: Button in touch_controls._action_buttons:
			if not button.is_visible_in_tree(): continue
			var rect: Rect2 = button.get_global_rect()
			actions.append({"action":touch_controls._action_buttons[button],"text":button.text,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
		var menu_buttons: Array = []
		for button: Node in hud._modal_box.find_children("*","Button",true,false):
			if not button.is_visible_in_tree(): continue
			var rect: Rect2 = button.get_global_rect()
			menu_buttons.append({"text":button.text,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
		var stick: Rect2 = touch_controls.joystick.get_global_rect()
		state.investigations = JavaScriptBridge.get_interface("JSON").parse(JSON.stringify({"progress":investigations.to_dict(),"ui":investigation_panel.diagnostics(),"field":{"nearby":investigations.nearby(player.global_position,player.mounted_vehicle == null),"source":investigations.definition().documents[investigations.pending()].place if investigations.pending() >= 0 else "","actions":actions,"joystick_rect":[stick.position.x,stick.position.y,stick.size.x,stick.size.y],"objective":hud.objective_text()},"hud_buttons":menu_buttons,"save_path":ProjectSettings.globalize_path("user://save1.json")}))
		state.investigations.street_result = JavaScriptBridge.get_interface("JSON").parse(JSON.stringify(investigations.street_result()))
		state.investigations.street_objects = JavaScriptBridge.get_interface("JSON").parse(JSON.stringify(get_node("InvestigationField").result_diagnostics()))
	state.layout = JavaScriptBridge.get_interface("JSON").parse(JSON.stringify(hud.layout_diagnostics()))
	state.menu = hud.get_menu_mode()
	state.world_ready = expansion_complete
	var camera: Camera3D = player.get_camera()
	var hero_feet: Vector2 = camera.unproject_position(player.global_position)
	var hero_head: Vector2 = camera.unproject_position(player.global_position + Vector3.UP * 1.78)
	var mei_position: Vector3 = contact_people[0].global_position if not contact_people.is_empty() else Vector3(-50.3,0.06,56.4)
	var mei_feet: Vector2 = camera.unproject_position(mei_position)
	var mei_head: Vector2 = camera.unproject_position(mei_position + Vector3.UP * 1.70)
	state.art = JavaScriptBridge.get_interface("JSON").parse(JSON.stringify({
		"hero_height_px":absf(hero_feet.y-hero_head.y),"mei_height_px":absf(mei_feet.y-mei_head.y),
		"hud_coverage":hud.hud_coverage(),"hero_feet":[hero_feet.x,hero_feet.y],"hero_head":[hero_head.x,hero_head.y],
		"mei_feet":[mei_feet.x,mei_feet.y],"mei_head":[mei_head.x,mei_head.y],
		"seal_visible":hud._mode == "case" and fraud_case.stage == 4,
		"details":_art_details()}))
	state.notice = info_text
	state.objective = hud.objective_text()
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
	# A legible nearby caption replaces distant overlapping yellow text.
	for object: Node3D in objects.values():
		object.text_label.visible = object == nearest and not object.collected and object.object_id != "mei" and investigations.pending() < 0
	for person: Node3D in contact_people:
		for child: Node in person.get_children():
			# The fixed interaction caption already carries the person's identity.
			if child is Label3D: child.visible = not investigations.active.is_empty() and person == contact_people[0] and person.global_position.distance_to(player.global_position) < 8

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
	if play_started and not get_tree().paused and investigations:
		var found: int = investigations.collect(player.global_position,player.mounted_vehicle == null)
		if found >= 0:
			touch_controls.confirm_interaction()
			_play_sfx("objective")
			investigation_panel.collected(found)
			return
	if play_started and not get_tree().paused and revisits and revisits.is_near(player.global_position,player.mounted_vehicle == null):
		var result: String = revisits.interact_at(player.global_position)
		if not result.is_empty():
			touch_controls.confirm_interaction()
			_play_sfx("objective")
			if result == "question": hud.show_revisit_question()
			return
	if not nearest or not play_started:
		return
	touch_controls.confirm_interaction()
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
	if taiwan_world and taiwan_world.station_ids.has(id):
		hud.show_life_station(str(taiwan_world.station_ids[id]))
		return
	if id=="supply_shop":
		_open_supplies()
		return
	var object: StaticBody3D = objects[id]
	if content_world.use_object(id):
		return
	if object.event_name in ["practice_hit", "destroy_target", "sandbox"]:
		_notice("點右下「攻擊」敲擊這個物件" if touch_controls.enabled else "使用左鍵攻擊這個物件")
		return
	if id == "branch_console":
		hud.show_phone()
		return
	if object.event_name == "pickup_weapon":
		var weapon := "bat" if id == "bat_pickup" else "pulse"
		if player.grant_weapon(weapon):
			player.equip_weapon(weapon)
			object.set_collected(true)
			_notice("取得器具｜點「換工具」切換" if touch_controls.enabled else "取得器具｜Q 切換")
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
	# A receipt is available only after preserving the message and meeting Mei
	# on foot at the actual desk. The original mission event remains unchanged.
	if id == "mei" and play_started and fraud_case.stage == 1 and player.mounted_vehicle == null and player.global_position.distance_to(object.global_position) < 3.0:
		if fraud_case.meet_witness(): hud.show_fraud_case()

func _start_revisit(index: int) -> void:
	if not play_started or not revisits.start(index): return
	street_state.has_waypoint = false
	_resume()
	_notice("回訪已接下｜跟隨光柱，靠近後互動")

func _hit_object(id: String) -> void:
	# Impact audio/FX come from HitFeedback via SevenPlayer.hit_landed.
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
	if not freeze_events and not get_tree().paused and objects.has(id) and objects[id].broken:
		district_systems.record_action("destroy",id,"destroy:"+id)
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
	_mission_feedback()
	if missions.mission_index != mission_state:
		mission_state = missions.mission_index
		checkpoint_state = _snapshot(false)
	if missions.mission_index == 2 and missions.get_target_key() == "car" and player.global_position.distance_to(car.global_position) < 4:
		_event("unlock_car", "car")

func _on_mission_completed(_id: String) -> void:
	_notice("任務完成｜進度已保存")
	_save(false)

func _on_chapter_complete(branch: String) -> void:
	hud.set_chain_progress(5)
	_play_sfx("mission")
	hud.show_chapter_complete(branch, _record_run(branch))
	_save(false)

func _on_health(current: float, _maximum: float) -> void:
	if current <= 0 and play_started:
		_notice("受傷倒下，回到本段檢查點")
		_retry()

func _on_attack(_weapon: String) -> void:
	heat_clock = 0
	_play_sfx("swing", randf_range(0.92, 1.1))

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
	result["district_systems"] = district_systems.to_dict()
	result["street_state"] = street_state.to_dict()
	result["player"]["stamina"] = player.stamina
	result["player"]["camera_yaw"] = player.get_view_yaw()
	result["taiwan_life"] = taiwan_life.to_dict()
	result["taiwan_activities"] = taiwan_activities.to_dict()
	if fraud_case: result["fraud_case"] = fraud_case.to_dict()
	if investigations: result["investigations"] = investigations.to_dict()
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
	if not startup_complete: return
	if not play_started:
		return
	if not expansion_complete and (absf(player.position.x)>=150 or absf(player.position.z)>=150):
		_outer_world_loading_notice()
		return
	var error: int = SaveScript.save_state(_snapshot(), 98 if is_test_mode else 1)
	if show_notice:
		_notice("進度已儲存" if error == OK else "儲存失敗，舊檔仍保留")

func _load(slot: int = 1) -> void:
	if not startup_complete: return
	if not expansion_complete:
		_outer_world_loading_notice()
		return
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
	_set_title_world_hidden(false)
	_resume()
	_notice("已讀取進度；原位置新增店面，已移到附近人行空間" if _relocated_save else "已讀取進度")

func _valid_world_save(data: Dictionary) -> bool:
	if data.has("investigations") and not investigations.valid(data["investigations"]): return false
	if data.has("fraud_case") and not FraudCaseScript.valid(data["fraud_case"]): return false
	if data.get("schema_version") != 1:
		return false
	for key: String in ["missions", "player", "objects", "rescues", "vehicles", "route_done"]:
		if not data.get(key) is Dictionary:
			return false
	var player_data: Dictionary = data["player"]
	if player_data.has("stamina") and not _valid_number(player_data["stamina"],0,120): return false
	if player_data.has("camera_yaw") and not _valid_number(player_data["camera_yaw"],-10000,10000): return false
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
	if data.has("district_systems"):
		if not data["district_systems"] is Dictionary: return false
		var system_probe := SystemsScript.new()
		var system_valid: bool = system_probe.from_dict(data["district_systems"])
		system_probe.free()
		if not system_valid: return false
	if data.has("street_state"):
		if not data["street_state"] is Dictionary: return false
		var street_probe := StreetScript.new()
		street_probe.world_radius = WORLD_RADIUS-5.0
		if not street_probe.from_dict(data["street_state"]): return false
	if data.has("taiwan_life"):
		if not data["taiwan_life"] is Dictionary: return false
		var life_probe := TaiwanLifeScript.new()
		var life_valid: bool = life_probe.from_dict(data["taiwan_life"])
		life_probe.free()
		if not life_valid: return false
	if data.has("taiwan_activities"):
		if not data["taiwan_activities"] is Dictionary: return false
		var activity_probe := TaiwanActivitiesScript.new()
		var activity_valid: bool = activity_probe.from_dict(data["taiwan_activities"])
		activity_probe.free()
		if not activity_valid: return false
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
	if fraud_case:
		if data.has("fraud_case"): fraud_case.from_dict(data["fraud_case"])
		else: fraud_case.reset()
	if investigations:
		if data.has("investigations"): investigations.from_dict(data["investigations"])
		else: investigations.reset()
	mission_state = missions.mission_index
	car.force_release()
	bicycle.force_release()
	var p_data: Dictionary = data.get("player", {})
	player.position = _from_vec(p_data.get("position"), Vector3(-56, 0.2, 52))
	_relocated_save = false
	var shop_bounds := AABB(Vector3(-62,0,61),Vector3(16,8,8)).grow(0.5)
	if p_data.get("vehicle","")=="" and shop_bounds.has_point(player.position+Vector3.UP):
		player.position = _safe_saved_position(player.position)
		_relocated_save = true
	player.velocity = Vector3.ZERO
	player.reset_view(float(p_data.get("camera_yaw",PI+atan2(4.0,5.0))))
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
	if data.has("district_systems"): district_systems.from_dict(data["district_systems"])
	else: district_systems.reset()
	if data.has("street_state"): street_state.from_dict(data["street_state"])
	else: street_state.reset()
	if data.has("taiwan_life"): taiwan_life.from_dict(data["taiwan_life"])
	else: taiwan_life.reset()
	if data.has("taiwan_activities"): taiwan_activities.from_dict(data["taiwan_activities"])
	else: taiwan_activities.reset()
	_refresh_system_stats()
	player.set_stamina(float(p_data.get("stamina",player.maximum_stamina)))
	district_systems.reset_walk_sample()
	_apply_preferences()
	freeze_events = false
	# Loaded/rolled-back progress is not a fresh completion: resync R1 feedback.
	_feedback_mission = missions.mission_index
	_feedback_objective = missions.current_objective
	if hud: hud.set_chain_progress(5 if missions.chapter_complete else missions.mission_index)
	return true

func _retry() -> void:
	if not startup_complete: return
	_resume()
	var keep_optional: Dictionary = optional.to_dict()
	var keep_systems: Dictionary = district_systems.to_dict()
	var keep_street: Dictionary = street_state.to_dict()
	var keep_life: Dictionary = taiwan_life.to_dict()
	var keep_activities: Dictionary = taiwan_activities.to_dict()
	var keep_optional_objects: Dictionary = {}
	for id: String in objects:
		if id.begins_with("SIDE_") or id.begins_with("ACT_"):
			keep_optional_objects[id] = objects[id].state()
	missions.restart_current()
	if not checkpoint_state.is_empty():
		var rollback := checkpoint_state.duplicate(true)
		rollback["missions"] = missions.to_dict()
		rollback["optional"] = keep_optional
		rollback["district_systems"] = keep_systems
		rollback["street_state"] = keep_street
		rollback["taiwan_life"] = keep_life
		rollback["taiwan_activities"] = keep_activities
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
	district_systems.reset_walk_sample()
	_notice("已回到本段檢查點")

# ---------------------------------------------------------------- R1 fun/polish
func _setup_fun_layer() -> void:
	hit_feedback = HitFeedbackScript.new()
	hit_feedback.name = "HitFeedback"
	add_child(hit_feedback)
	hit_feedback.setup(player, hit_player)
	player.hit_landed.connect(hit_feedback.on_hit)
	hit_feedback.combo_changed.connect(hud.set_combo)
	objective_beacon = BeaconScript.new()
	add_child(objective_beacon)
	objective_beacon.setup(player)
	run_records = RunRecordsScript.new()
	music = MusicScript.new()
	music.name = "MusicDirector"
	add_child(music)
	for key: String in ["swing", "objective", "mission", "chain", "ui"]:
		var path := "res://assets/audio/%s.wav" % key
		if not ResourceLoader.exists(path): continue
		var sfx := AudioStreamPlayer.new()
		sfx.name = "Sfx_" + key
		sfx.stream = load(path)
		sfx.volume_db = -12.0 if key == "swing" else -8.0
		add_child(sfx)
		_sfx[key] = sfx
	hud.story_start_requested.connect(_start_story)

func _play_sfx(key: String, pitch: float = 1.0) -> void:
	var sfx: AudioStreamPlayer = _sfx.get(key)
	if sfx == null or not MusicScript.audio_live(): return
	sfx.pitch_scale = pitch
	sfx.play()

## Title CTA: start the campaign, then play the cold-open story over it.
func _start_story() -> void:
	if not startup_complete: return
	if play_started:
		_new_game()
		return
	_new_game()
	if is_test_mode or not is_inside_tree():
		_announce_mission()
		return
	story_intro = StoryIntroScript.new()
	story_intro.finished.connect(_on_story_finished)
	add_child(story_intro)
	get_tree().paused = true

func _on_story_finished(_skipped: bool) -> void:
	story_intro = null
	_resume()
	_announce_mission()
	if fraud_case.preserve_message():
		hud.show_toast("客服訊息已留存｜到美晴車店核對收據")
		_notice("反詐案卷已開啟｜沿光柱找美晴，靠近後交談")

func _announce_mission() -> void:
	if not hud or not missions or missions.chapter_complete: return
	var mission: Dictionary = missions.get_current_mission()
	if mission.is_empty(): return
	hud.set_chain_progress(missions.mission_index)
	hud.show_banner("斷鏈行動｜第 %d／5 環" % [missions.mission_index + 1], str(mission.get("title", "")), str(mission.get("dialogue", "")))

## Objective/mission completion feedback driven by the mission manager state.
func _mission_feedback() -> void:
	if not hud or not missions.started: return
	var index: int = missions.mission_index
	var objective: int = missions.current_objective
	if missions.chapter_complete:
		_feedback_mission = index
		_feedback_objective = objective
		return
	if index == _feedback_mission + 1:
		var finished: Dictionary = missions.missions[_feedback_mission] if _feedback_mission >= 0 and _feedback_mission < missions.missions.size() else {}
		hud.show_toast("✓ 任務完成｜+%d 零件券" % int(finished.get("parts_vouchers", 0)), Color("ffd36b"))
		_play_sfx("chain")
		_announce_mission()
	elif index == _feedback_mission and objective == _feedback_objective + 1:
		hud.show_toast("✓ 目標完成")
		_play_sfx("objective")
	_feedback_mission = index
	_feedback_objective = objective

func _update_guidance(active_target: String) -> void:
	if not objective_beacon: return
	if targets.has(active_target) and (not missions.chapter_complete or active_target == "investigation"):
		var point: Vector3 = targets[active_target]
		if active_target == "mei" and not contact_people.is_empty(): point = contact_people[0].global_position
		objective_beacon.set_target(point)
		hud.set_target_distance(Vector2(player.global_position.x - point.x, player.global_position.z - point.z).length())
	else:
		objective_beacon.clear_target()
		hud.set_target_distance(-1.0)
	hud.set_controls_hint_visible(seconds_played < 45.0)

func _record_run(branch: String) -> Dictionary:
	var result: Dictionary = missions.scores.duplicate(true)
	result["seconds"] = seconds_played
	result["branch"] = branch
	if run_records == null: return {}
	run_records.persist = not is_test_mode
	var outcome: Dictionary = run_records.record(branch, result)
	outcome["time_text"] = "%d:%02d" % [floori(seconds_played / 60.0), int(seconds_played) % 60]
	outcome["progress"] = run_records.progress_text(branch)
	return outcome

func _polish_characters() -> void:
	if player: _apply_character_rim(player)
	for guard: Node in guards.values(): _apply_character_rim(guard)
	for person: Node in people.values(): _apply_character_rim(person)

## Rim light lifts dark clothing off the street and makes 64px silhouettes read.
func _apply_character_rim(root: Node) -> void:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null or mesh_node.get_script() != null: continue
		for surface: int in mesh_node.mesh.get_surface_count():
			var material := mesh_node.get_active_material(surface) as BaseMaterial3D
			if material == null or material.rim_enabled: continue
			var polished := material.duplicate() as BaseMaterial3D
			polished.rim_enabled = true
			polished.rim = 0.55
			polished.rim_tint = 0.35
			mesh_node.set_surface_override_material(surface, polished)

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
		# Evidence captures can force a device profile so phone/tablet layouts
		# are reproducible on a desktop GPU without a touchscreen.
		if arg.begins_with("--capture-profile=") and device_profiles:
			device_profiles.set_profile(arg.trim_prefix("--capture-profile="),false)
	await get_tree().process_frame
	_new_game()
	if mode not in ["start", "combat", "title"]:
		player.position = Vector3(-54, 0.2, 44)
	if mode == "combat":
		# Wrench in hand facing the first practice target, captured mid-swing.
		_event("talk_mei", "mei")
		_event("read_phone", "phone")
		_use_object("wrench")
		player.position = Vector3(-44, 0.2, 55.4)
		player.reset_view(0.0)
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
	if "--capture-no-overlay" in OS.get_cmdline_user_args():
		hud._overlay.visible = false
	if "--capture-hide-hud" in OS.get_cmdline_user_args():
		hud._hud.visible = false
		objective_beacon.visible = false
		objective_beacon.set_process(false)
	if mode == "combat":
		player.begin_attack()
		await get_tree().create_timer(0.24).timeout
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

func _exit_tree() -> void:
	if _startup_progress != null: _startup_progress.cancel()
	# Stop R1 audio so no playback object outlives the scene at shutdown.
	for sfx: AudioStreamPlayer in _sfx.values():
		if is_instance_valid(sfx): sfx.stop()
	if is_instance_valid(hit_player): hit_player.stop()


func _art_details() -> Dictionary:
	var result := {"hour":street_state.hour,"photos":[],"touch":[],"inspection":false,"seal":{},"case_labels":[]}
	if hud._mode == "case":
		for label: Node in hud._modal_box.find_children("*","Label",true,false):
			if not label.is_visible_in_tree(): continue
			var label_rect: Rect2 = label.get_global_rect()
			result.case_labels.append({"text":label.text,"rect":[label_rect.position.x,label_rect.position.y,label_rect.size.x,label_rect.size.y]})
	for name_value: String in ["InspectMessage","InspectReceipt"]:
		var b := hud._modal_box.find_child(name_value,true,false) as Button
		if b and b.is_visible_in_tree():
			var rect := b.get_global_rect()
			result.photos.append({"name":name_value,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
	var inspector: Node = hud._root.get_node_or_null("EvidenceInspector")
	if inspector:
		var rect: Rect2 = inspector._close.get_global_rect()
		var labels: Array = []
		for label: Node in inspector.find_children("*","Label",true,false):
			if not label.is_visible_in_tree(): continue
			var r: Rect2 = label.get_global_rect()
			labels.append({"text":label.text,"rect":[r.position.x,r.position.y,r.size.x,r.size.y]})
		var paper_rect: Rect2 = inspector._paper.get_global_rect()
		var marks: Array = []
		for marker: Node in inspector.find_children("*","PanelContainer",true,false):
			if marker is EvidenceInspectorScript.MarkedField:
				var marker_rect: Rect2 = marker.get_global_rect()
				marks.append({"text":marker.get_child(0).text,"circled":marker.circled,"rect":[marker_rect.position.x,marker_rect.position.y,marker_rect.size.x,marker_rect.size.y]})
		result.inspection = {"receipt":inspector.receipt,"close":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"paper":[paper_rect.position.x,paper_rect.position.y,paper_rect.size.x,paper_rect.size.y],"labels":labels,"marks":marks}
	for b: Button in touch_controls._action_buttons:
		if b.is_visible_in_tree(): result.touch.append({"action":touch_controls._action_buttons[b],"text":b.text})
	var seal := hud._modal_box.get_node_or_null("ArchiveSeal") as TextureRect
	if seal:
		var tape := hud._modal_box.get_node_or_null("ArchiveAdhesive") as Control
		var paper := hud._modal_panel.get_node_or_null("PaperImpact") as Control
		result.seal = {"scale":seal.scale.x,"paper_rotation":paper.rotation if paper else 0.0,"tape_alpha":tape.modulate.a if tape else 0.0,"applicator":seal.has_node("StampApplicator")}
	return result
