extends SceneTree

const PlayerScript = preload("res://scripts/player/player_controller.gd")
const VehicleScript = preload("res://scripts/vehicles/arcade_vehicle.gd")
const GuardScript = preload("res://scripts/combat/guard.gd")

var failures: int = 0
var checks: int = 0
var defeated_count: int = 0
var world: Node3D
var player: SevenPlayer

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)

func wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout

func body_box(size: Vector3, position: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = position
	body.collision_layer = 1
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	return body

func make_guard(position: Vector3) -> SevenGuard:
	var guard: SevenGuard = GuardScript.new()
	guard.position = position
	guard.setup_visual(load("res://assets/models/guard.glb") as PackedScene)
	world.add_child(guard)
	guard.set_physics_process(false)
	return guard

func make_vehicle(kind: String, position: Vector3) -> ArcadeVehicle:
	var vehicle: ArcadeVehicle = VehicleScript.new()
	vehicle.type = kind
	vehicle.position = position
	vehicle.setup_visual(load("res://assets/models/bicycle.glb" if kind == "bike" else "res://assets/models/car.glb") as PackedScene)
	world.add_child(vehicle)
	return vehicle

func on_defeated() -> void:
	defeated_count += 1

func run() -> void:
	for action: String in ["move_left", "move_right", "move_forward", "move_back", "sprint", "jump", "attack", "interact", "mount", "cycle_weapon", "brake", "reset_vehicle"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	world = Node3D.new()
	root.add_child(world)
	body_box(Vector3(500.0, 0.4, 500.0), Vector3(0.0, -0.2, 0.0))
	player = PlayerScript.new()
	player.position = Vector3(0.0, 0.05, 0.0)
	player.setup_visual(load("res://assets/models/hero.glb") as PackedScene)
	world.add_child(player)
	await physics_frame
	await physics_frame
	expect(player.get_camera() != null, "player owns third-person camera")
	expect(not player.equip_weapon("wrench"), "unowned weapon cannot be equipped")
	expect(player.grant_weapon("wrench") and player.weapon_visual_available, "wrench grant loads real held GLB")
	expect(player.find_child("RightHandToolAttachment", true, false) != null, "weapon follows actual right-arm bone")
	expect(player.grant_weapon("bat") and player.grant_weapon("pulse"), "two melee and one ranged grant")
	expect(player.inventory["melee"].size() == 2 and player.inventory["ranged"].size() == 1, "inventory capacities")
	player.pulse_energy = 9
	player.grant_weapon("pulse")
	expect(player.pulse_energy == 9, "repeated pulse pickup does not refill energy")
	player.equip_weapon("wrench")
	var guard: SevenGuard = make_guard(Vector3(0.0, 0.0, -1.5))
	expect(player.begin_attack(), "real animated attack starts")
	await wait_seconds(0.10)
	expect(is_equal_approx(guard.health, 75.0), "damage waits for strike window")
	await wait_seconds(0.35)
	expect(is_equal_approx(guard.health, 51.0), "one wrench strike deals exactly 24")
	await wait_seconds(0.30)
	expect(is_equal_approx(guard.health, 51.0), "same strike is deduplicated across physics frames")
	guard.position = Vector3(0.0, 0.0, 1.5)
	guard.health = 75.0
	player.begin_attack()
	await wait_seconds(0.70)
	expect(is_equal_approx(guard.health, 75.0), "targets behind player are excluded")
	guard.position = Vector3(0.0, 0.0, -1.6)
	var wall: StaticBody3D = body_box(Vector3(4.0, 2.0, 0.2), Vector3(0.0, 1.0, -0.8))
	await physics_frame
	player.begin_attack()
	await wait_seconds(0.70)
	expect(is_equal_approx(guard.health, 75.0), "wall prevents melee damage")
	wall.queue_free()
	await physics_frame
	await physics_frame
	guard.apply_hit("repeat-guard", "fixture", 10.0)
	guard.apply_hit("repeat-guard", "fixture", 10.0)
	expect(is_equal_approx(guard.health, 65.0), "guard received-hit deduplication")
	player.apply_hit("repeat-player", "fixture", 12.0)
	player.apply_hit("repeat-player", "fixture", 12.0)
	expect(is_equal_approx(player.health, 88.0), "player received-hit deduplication")
	player.restore_health()
	guard.defeated.connect(on_defeated)
	guard.apply_hit("defeat-guard", "fixture", 100.0)
	guard.set_physics_process(true)
	expect(defeated_count == 0, "defeat signal waits for knockdown")
	await wait_seconds(0.85)
	expect(guard.state == "defeated" and defeated_count == 1, "short knockdown emits one defeat signal")
	await wait_seconds(0.20)
	expect(defeated_count == 1, "defeat signal stays deduplicated")
	var close_guard: SevenGuard = make_guard(Vector3(0.0, 0.0, -8.0))
	var far_guard: SevenGuard = make_guard(Vector3(0.0, 0.0, -11.0))
	player.equip_weapon("pulse")
	player.pulse_energy = 2
	player.begin_attack()
	await wait_seconds(0.80)
	expect(is_equal_approx(close_guard.health, 30.0) and is_equal_approx(far_guard.health, 75.0), "pulse hits one nearest visible target")
	expect(player.pulse_energy == 1, "pulse costs one finite energy")
	player.begin_attack()
	await wait_seconds(0.80)
	expect(player.pulse_energy == 0 and not player.begin_attack(), "empty pulse cannot fire")
	player.position = Vector3(20.0, 0.05, 0.0)
	player.velocity = Vector3.ZERO
	await wait_seconds(0.10)
	var before: Vector3 = player.position
	Input.action_press("move_forward")
	await wait_seconds(0.50)
	Input.action_release("move_forward")
	var walked: float = player.position.distance_to(before)
	expect(player.position.z < before.z - 0.5, "W moves along camera forward")
	await wait_seconds(0.25)
	before = player.position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await wait_seconds(0.50)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	expect(player.position.distance_to(before) > walked * 1.25, "sprint is faster than walk")
	await wait_seconds(0.25)
	var floor_height: float = player.position.y
	Input.action_press("jump")
	await wait_seconds(0.20)
	Input.action_release("jump")
	expect(player.position.y > floor_height + 0.25, "jump leaves ground")
	await wait_seconds(1.20)
	expect(absf(player.position.y - floor_height) < 0.15, "jump returns to floor")
	var car: ArcadeVehicle = make_vehicle("car", Vector3(40.0, 0.05, 0.0))
	await physics_frame
	await physics_frame
	player.position = car.position + Vector3(2.0, 0.0, 0.0)
	expect(car.enter(player) and car.occupied and player.mounted_vehicle == car, "car enter occupancy links both actors")
	expect(player.collision_layer == 0, "mounted player walking collision is disabled")
	Input.action_press("move_forward")
	await wait_seconds(4.0)
	expect(car.get_speed_kmh() <= 60.01 and car.get_speed_kmh() > 40.0, "car actual acceleration respects 60kmh cap")
	Input.action_press("move_right")
	await wait_seconds(0.35)
	Input.action_release("move_right")
	Input.action_release("move_forward")
	expect(absf(car.rotation.y) > 0.05, "car turns under throttle")
	expect(not car.exit() and car.occupied, "high-speed exit is refused without losing occupancy")
	Input.action_press("brake")
	await wait_seconds(1.50)
	Input.action_release("brake")
	expect(car.get_speed_kmh() < 0.1, "car brake stops actual physics speed")
	expect(car.exit() and not car.occupied, "car safely exits after braking")
	await physics_frame
	expect(player.mounted_vehicle == null and player.collision_layer == 2, "safe exit restores player walking collision")
	expect(car.enter(player), "car re-entry succeeds")
	car.set_physics_process(false)
	var enclosure: StaticBody3D = body_box(Vector3(10.0, 3.0, 10.0), car.position + Vector3.UP * 1.5)
	await physics_frame
	expect(not car.exit() and car.occupied and player.mounted_vehicle == car, "fully blocked exits preserve occupancy")
	enclosure.queue_free()
	await physics_frame
	await physics_frame
	car.set_physics_process(true)
	expect(car.exit(), "exit succeeds when enclosure is removed")
	car.enter(player)
	car.speed_mps = 5.0
	car.force_release(Vector3(30.0, 0.05, 0.0))
	expect(not car.occupied and player.mounted_vehicle == null and player.position.distance_to(Vector3(30.0, 0.05, 0.0)) < 0.01, "checkpoint force release restores occupancy and position")
	car.position = Vector3(50.0, 0.1, 50.0)
	car.speed_mps = 10.0
	car.reset()
	expect(car.position.distance_to(Vector3(40.0, 0.05, 0.0)) < 0.01 and car.speed_mps == 0.0, "car reset uses captured spawn and clears speed")
	var bike: ArcadeVehicle = make_vehicle("bike", Vector3(-40.0, 0.05, 0.0))
	await physics_frame
	await physics_frame
	player.position = bike.position + Vector3(2.0, 0.0, 0.0)
	expect(bike.enter(player), "bicycle enter")
	Input.action_press("move_forward")
	await wait_seconds(3.0)
	Input.action_release("move_forward")
	expect(bike.get_speed_kmh() <= 25.01 and bike.get_speed_kmh() > 20.0, "bike actual acceleration respects 25kmh cap")
	var wheels: Array = bike.get("_wheels")
	var has_wheel_geometry: bool = wheels.size() >= 2
	for wheel: Node3D in wheels:
		has_wheel_geometry = has_wheel_geometry and (wheel is MeshInstance3D or not wheel.find_children("*", "MeshInstance3D", true, false).is_empty())
	expect(has_wheel_geometry and absf(wheels[0].rotation.x) > 0.1, "actual bicycle wheel geometry animates")
	Input.action_press("brake")
	await wait_seconds(0.80)
	Input.action_release("brake")
	expect(bike.exit() and not bike.occupied and player.mounted_vehicle == null, "bicycle brake and safe exit")
	expect(player.animations_missing.is_empty() and guard.animations_missing.is_empty(), "real GLBs provide all requested clips")
	var no_visual: SevenPlayer = PlayerScript.new()
	no_visual.position = Vector3(60.0, 0.05, 0.0)
	world.add_child(no_visual)
	no_visual.grant_weapon("wrench")
	expect(not no_visual.begin_attack(), "missing character/weapon model never causes invisible damage")
	print("CONTROL_CHECKS=", checks, " FAILURES=", failures)
	quit(0 if failures == 0 else 1)
