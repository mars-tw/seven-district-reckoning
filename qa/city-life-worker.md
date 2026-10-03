# City life worker handoff

Status: VERIFIED by Godot 4.7.2 headless scene and physics execution on 2026-10-03.

## Scope

Changed only `godot/scripts/world/district_life.gd`, `godot/data/district_life.json`, `tests/district_life.gd`, and this report. The module preserves the 300 × 300 m terrain, existing MAIN001–MAIN005 objects, the original lighting and the fixed daytime palette. It adds ambient scenery and actors; optional contacts and mission events belong to the main integration worker.

The art instances reuse 15 existing shipped GLBs. No new asset, externally downloaded model, new character placeholder, new building placeholder or heavy post effect was introduced. Primitive render geometry is limited to pavement, parking paint, flat sign panels and four signal lamps. Building and tree collisions use inexpensive shapes.

## Integration API

```gdscript
const DistrictLifeScript = preload("res://scripts/world/district_life.gd")
var city_life: DistrictLife = DistrictLifeScript.bootstrap(self)
# Once the playable character has been created:
city_life.setup(player)
```

`bootstrap(parent)` adds a single `DistrictLife` child and builds it. Calling it again returns the same instance. `setup(player)` can safely rebind the player's `attacked` signal without duplicating scenery. If no player exists yet, `setup()` is valid.

`get_districts()` returns independent dictionaries with `id`, `name`, `bounds`, `marker`, `color`, `subtitle`, and `walk_loop`. Bounds are `[min_x, min_z, max_x, max_z]`; markers and waypoints are `[x, z]`. Both coordinates are metres. `get_counts()` reports instantiated art and actors. `get_status()` reports clock, fleeing people, stopped cars and signal phase.

`to_dict()` / `from_dict()` use only `{ "version": 1, "clock": seconds }`. Actors restart their deterministic routes after a scene rebuild. This state is optional; it contains no user or unrelated saved information. Invalid, negative and non-finite clocks are rejected.

| ID | Name | Bounds | Marker |
| --- | --- | --- | --- |
| old_street | 舊街車店 | `[-136, 12, -84, 66]` | `[-110, 39]` |
| commercial_core | 商辦核心 | `[82, -94, 134, -12]` | `[108, -64]` |
| park | 公園步道 | `[-136, 82, -84, 134]` | `[-112, 103]` |
| parking_plaza | 停車廣場 | `[82, 82, 134, 134]` | `[110, 113]` |
| station_forecourt | 前站廣場 | `[-72, -136, 72, -84]` | `[-44, -94]` |
| transit | 轉運街區 | `[82, 12, 134, 66]` | `[109, 34]` |

All six markers are outside the new solid obstacles and inside their districts. They may be used for optional activity locations. Scenery does not add collisions within the central `[-82, 82] × [-82, 82]` mission area.

## Scene contents and behaviour

Actual instantiated counts from the test:

- Six named areas, nine GLB building instances and 19 solid obstacle shapes, including ten park tree trunks.
- Eight civilians using the shipped `civilian.glb` Skeleton3D and its walk/run clips. They use collision layer 2 and mask 1, are absent from `damageable`, and have no damage handler. A nearby weapon swing makes them run away along the same clear route edge.
- Four moving cars on the four-point road loop at ±137 m and six parked cars in the parking plaza. Each moving car has a forward Area3D sensor and four real wheel mesh instances. The actual player or pedestrian ahead stops the car; clearing the sensor resumes movement. Moving cars have no solid body, so they cannot pin the player's car or bicycle.
- 112 imported road tiles, four road crossings, 28 streetlights, four traffic signals, 16 benches, 13 planters, ten trees, one decorative bicycle, one desk and one display.
- Shared PackedScene and model-bounds caches; no per-frame resource loading. Actor decisions and actual static-world clearance probes run at 5 Hz, with only movement and wheel updates on each physics frame. Geometry uses visibility ranges, and small background geometry does not cast shadows. No dynamic traffic lights were added.

The AI intentionally uses clear predetermined routes, waypoint reversal and bounded speed. It is ambient background movement, not a city traffic simulation. The ring connects to the existing southern/east-west streets; the existing central streets continue to provide the north/east/west connections. Level pavement rests on the existing terrain and introduces no raised collision lip.

## Executed validation

```powershell
& '<Godot 4.7.2 console executable>' --headless --path godot --editor --quit
& '<Godot 4.7.2 console executable>' --headless --path godot --script tests/district_life.gd
```

The test script instantiates the actual main scene, starts a new game, attaches or reuses the module and exercises the actual imported art and physics. Final result: **47 checks passed, zero failures; exit code 0**.

Evidence covers all six markers and stable IDs; real scene/asset counts; idempotent bootstrap; all imported assets present; eight main-route player-capsule obstruction queries; continuous capsule samples at intervals of at most 0.25 m along every citizen route against the actual integrated main scene's static physics, including optional activity objects; bounded traffic routes; actual citizen movement; actual GLB wheel rotation; frozen clock and actor positions while paused; a real player weapon swing and civilian survival; actual fleeing motion; actual Area3D braking and resume; bounded supported actor terrain; scene-clock roundtrip and malformed clock rejection.

The fleeing test measured citizen-to-player distance increasing from approximately **3.10 m to 4.55–4.59 m over one second** across the executed runs, while the citizen remained on its clear route. The motion test verifies position and wheel rotation changes rather than only checking implementation fields.

Headless validation does not establish browser frame rate, human art approval, or deployment. Those remain part of the supervisor's integrated browser/render checks. No Git push or deployment was performed by this worker.

## Integrated route repair

The independent integrated runner found that optional-content objects had been added on two park waypoints. Dense physics diagnostics also found a narrow breakfast sign on the old-street route that the original fixed 20-sample segments could skip. The actual blocking objects were `SIDE_012_breakfast_sign` at `[-106, 30]`, `SIDE_004_letter_3` at `[-112, 91]`, and `SIDE_011_neighbor_2` at `[-121, 115]`.

The old-street route now takes a short four-corner detour around the sign; the park route stays 1–1.5 m inside the original paths, with a level connecting pavement strip. District bounds, markers and other workers' optional-content points remain unchanged. Tests now sample by physical distance at intervals of at most 0.25 m, retain real collider diagnostics on failure and include every static collision in the integrated main scene. The runtime also checks a reused citizen capsule against actual static physics at 5 Hz before choosing avoidance, so later-added objects cannot be treated as clear merely because they were absent during scenery construction.

After this repair, the integrated scene again passed all **47 checks, zero failures, exit code 0**. The vehicle-exit investigation is owned by the supervisor; this worker added no solid scenery or citizens near the central car-shop vehicle spawn.

## Taiwan copy review

The `speak-human-tw` skill was applied under the core rules' standing mode 2 authorization. These are new fictional place names and concise wayfinding labels; no existing prose was changed. Review found zero phrases requiring replacement, so there are no original/reason/replacement edit entries. Names and signs use Traditional Chinese and Taiwan terms such as 車行、候車處、停車場 and 入口.
