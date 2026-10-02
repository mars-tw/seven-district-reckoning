extends SceneTree
const GuardScript = preload("res://scripts/combat/guard.gd")
var checks: int = 0
var failures: int = 0
var defeats: int = 0
func _initialize() -> void:
	call_deferred("run")
func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)
func on_defeated() -> void:
	defeats += 1
func run() -> void:
	var guard: SevenGuard = GuardScript.new()
	guard.position = Vector3(2.0, 0.0, 4.0)
	guard.setup_visual(load("res://assets/models/guard.glb") as PackedScene)
	root.add_child(guard)
	guard.set_physics_process(false)
	guard.defeated.connect(on_defeated)
	var alive: Dictionary = guard.get_state()
	expect(alive["health"] == 75.0 and alive["position"] == [2.0, 0.0, 4.0], "snapshot includes live health and world position")
	guard.apply_hit("death", "fixture", 100.0)
	guard.call("_update_knockdown", 0.80)
	expect(defeats == 1 and guard.health == 0.0, "normal death emits once")
	var dead: Dictionary = guard.get_state()
	var serialized: Dictionary = JSON.parse_string(JSON.stringify(dead)) as Dictionary
	guard.position = Vector3(20.0, 3.0, 20.0)
	expect(guard.restore_state(serialized), "JSON dead state restores")
	expect(guard.health == 0.0 and guard.position == Vector3(2.0, 0.0, 4.0), "dead position and zero health persist")
	expect(guard.collision_layer == 0 and guard.collision_mask == 1 and not guard.is_in_group("damageable"), "dead collision and damage group persist")
	guard.call("_update_knockdown", 2.0)
	expect(defeats == 1, "loaded dead guard does not duplicate defeat event")
	var animation_player: AnimationPlayer = guard.get("_animation_player") as AnimationPlayer
	expect(animation_player != null and not animation_player.is_playing(), "loaded corpse holds knockdown pose")
	expect(guard.restore_state(alive), "earlier living checkpoint restores")
	expect(guard.health == 75.0 and guard.state == "patrol", "live state returns to patrol")
	expect(guard.collision_layer == 2 and guard.collision_mask == 3 and guard.is_in_group("damageable"), "live collision and damage group restore")
	guard.apply_hit("death", "fixture", 100.0)
	guard.call("_update_knockdown", 0.80)
	expect(defeats == 2, "restored living guard can die once with rebuilt hit state")
	var before: Dictionary = guard.get_state()
	expect(not guard.restore_state({"health": "bad", "position": [1, 2, 3]}), "nonnumeric health is rejected")
	expect(not guard.restore_state({"health": 10, "position": [1, "bad", 3]}), "nonnumeric coordinate is rejected")
	expect(not guard.restore_state({"health": 1000, "position": [1, 2, 3]}), "out-of-range health is rejected")
	expect(not guard.restore_state({"health": 10, "position": [1, 2]}), "wrong coordinate count is rejected")
	expect(guard.get_state() == before, "all invalid snapshots preserve live state")
	print("GUARD_SAVE_CHECKS=", checks, " FAILURES=", failures)
	quit(0 if failures == 0 else 1)
