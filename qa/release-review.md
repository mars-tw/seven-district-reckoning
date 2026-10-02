# Alpha release review

Review date: 2026-10-03. Independent context review of the first-chapter alpha. This reviewer did not modify runtime source, publish the repository, use credentials, or perform a human playthrough.

Result: **PASS for the reviewed gameplay blockers after repairs**. A final official-Godot run passed 37 targeted checks with zero failures and process exit 0. Final publication-set scanning and Blender cleanup remain the supervisor's release checks.

## Evidence reviewed

- Read `AGENTS.md`, the eight runtime modules, `godot/data/alpha_missions.json`, `godot/project.godot`, `tools/test_game.py`, and the mission/control worker reports.
- Inspected the existing `qa/engine-checks.json`: official Godot 4.7.2 import/parse and nine integration checks report PASS. The movement checks exercise actual player, bicycle, and car physics. Most mission progression in that test is supplied through direct events; this does not demonstrate human navigation, melee timing, or a full human playthrough.
- Inspected `assets/provenance/sources.json`, `assets/provenance/CREDITS.md`, the Kenney license copy, the bicycle CC BY 3.0 copy, and the font OFL file. All seven source entries have an existing license file and existing local source/archive. Counted 25 `.blend` sources and 25 runtime `.glb` files. This is a file/traceability check, not independent confirmation of every mesh or animation.
- Reviewed publication ignore rules and prospective text files. Initial repository index was empty; a scan using `git ls-files` before staging would cover zero files.

## Findings sent to the supervisor

### Resolved P1: interaction bypassed real hits and destruction

In the reviewed revision, `DistrictObject.interact()` emits `used` for any uncollected object. `main.gd::_use_object()` then forwards its configured event without checking damage or destruction. During the active practice objective, E on `practice_1` and `practice_2` counts as hitting both. During the smash branch, E on each intact `equipment_*` counts as destroying three machines while their world health remains 35 and `broken` remains false.

Fix must distinguish damage-only events from ordinary interaction. Simply removing E progression requires handling early destruction as described below.

Repair verified: E no longer sends practice/destruction events. Actual player attacks advance practice, and actual object damage advances the smash objective.

### Resolved P1: fresh load of MAIN-001 followed by Retry stranded the wrench objective

On a fresh title scene, `mission_state` is 0 and `checkpoint_state` is empty. Loading a legitimate MAIN-001 save after borrowing the wrench does not change the mission index, so `_on_mission_updated()` does not capture a checkpoint. Retry resets mission objectives but has no world rollback. The wrench remains collected/hidden. After talking and reading the phone again, the borrow-wrench objective cannot be completed. New Game is the remaining escape.

A retry checkpoint must restore a replayable world state for the restarted objectives. Merely capturing the loaded mid-mission snapshot would retain the same collected wrench.

Repair verified: new saves include a nonrecursive world checkpoint. The final driver saved MAIN-001 after borrowing the wrench, loaded slot 95 through the product `_load(95)` in a fresh scene, retried, and successfully borrowed the restored wrench again.

### Resolved: early destruction must remain consistent with later objectives

`equipment_*` destroyed before MAIN-005 emits a currently invalid mission event, yet persists as broken. The subsequent mission checkpoint can contain those broken objects. Removing the E workaround alone can strand the smash route. Either protect future mission objects from premature destruction or reconcile their persistent world state when the objective starts.

`record_1`/`record_2` destruction before MAIN-005 is not tracked by `_handle_lost_record()`, which only recognizes branch records at mission index 4. The reviewed E path can later collect an already broken record. Persist destruction independently of the active mission or prevent premature damage.

Repair verified: all eight relevant future targets retained health 35 and remained unbroken after early damage attempts. Target-specific damage gates allow practice/equipment/sign damage only during valid objectives and record damage during MAIN-005.

### Resolved P2: guard state was not part of the saved world

The reviewed snapshot contains objects, rescues, and vehicle positions, but no guard health/state/position. Loading a pre-fight save in the same process leaves guards defeated; loading the same save in a fresh process gives live guards. Retry also retains guard defeat. The alternative entrance route remains available, so this is inconsistent rollback rather than a demonstrated total mainline lock.

Repair verified: after both guards were defeated, restoring a pre-fight world snapshot restored health 75 and damageable-group membership. Separate guard contract evidence remains in the control worker report.

### Resolved in source P2: screenshot success ignored image-write failure

`_capture()` ignores the return value of `image.save_png(path)` and always prints `CAPTURE_SAVED` before exiting. A missing destination directory or failed write can therefore report false success. Screenshot evidence should verify the saved PNG exists, has nonzero size, and opens correctly; source should propagate the write result.

Final source checks the returned error and exits 1 on failure. This reviewer did not rerun the failing-output-path capture scenario.

## Checks without a blocking finding

- Mounted saves record the selected vehicle; restore force-releases both vehicles before restoring the selected occupancy. Force-release also clears stale speed/driver state. Save restoration does not persist vehicle rotation, which limits exact positional continuity.
- Duplicate pulse pickup calls equip an existing weapon and does not replenish `pulse_energy`. Retry restores checkpoint inventory/energy as part of a failed attempt. No separate repeat-pickup energy farm was found in source.
- An early captive arrival rejected by the mission manager is reset to following/not-arrived so the safe-point event can retry after the second release. The follower still uses direct steering rather than full pathfinding; difficult-route navigation remains unverified.
- Normal repeated New Game reloads the scene and restarts through engine metadata, resetting guard/NPC instances. The final driver exercised normal reload/autostart and the separate test-mode reset. It invoked the callback rather than clicking the native UI button.

## Publication and claim limits

- The supervisor was notified of private absolute paths found in planning/docs/index and the worker report. A path-detection string in `tools/blender/validate_assets.py` is a scanner rule, not a private source path. Final candidate-file scanning must occur after staging and inspect the actual publication set.
- `.gitignore` excludes runtime caches, downloaded ZIP archives, `.audit-tmp`, local reports, generated deliveries, environment files, and key/credential filenames. No claim is made that filename exclusions alone prove the publication set contains no secrets.
- Binary Blender/GLB files require their separate source-path cleaning/validation evidence because the text publication scanner skips them.
- Independently decoded the JSON chunk of all 25 runtime GLBs and recursively inspected strings for private drive paths (`Users`, `AI`, `Program Files`); found zero fields. This does not scan compressed Blender contents or texture pixels.
- Font OFL is present; Noto Sans TC attribution/source should also be included in the final credits. Kenney material remains CC0 and the Poly by Google bicycle remains CC BY 3.0 with title, author, source URL, license URL, and modifications documented.
- Alpha evidence does not establish all 50 planned tickets or 70 planned assets as complete. README/planning claims were being updated by the supervisor and were not the final publication revision during this review.
- No measured playtime, extended performance run, minimum-hardware FPS, Linux export, packaged executable, or full human completion of all three routes was independently verified by this reviewer. A successful screenshot does not supply performance evidence.
- Opened `docs/evidence/alpha-gameplay-1366.png`: 1366×768 image displays the street scene, hero, map, mission text, and readable Traditional Chinese HUD. The initial image's fixed control hint incorrectly listed E for boarding and 1–3 for weapon switching. Final HUD source now uses F and Q; refreshed screenshot verification remains with the supervisor.

## Current review status

The supervisor implemented initial repairs. This reviewer then ran a one-time driver in official Godot 4.7.2 headless mode, outside the repository. The driver used save slot 95 and disconnected automatic save callbacks; it did not read or write the human slot 1 and did not run an editor import.

The first engine run verified premature-damage protection for eight mission objects, rejected E-only practice/smash completion, completed practice through the actual player attack and physics code, counted two NPC arrivals after the first arrived early, rejected duplicate pulse-energy refills, and exercised both repeated test-mode resets and normal scene reload/autostart.

The run exited 1 because `_valid_world_save()` assigned a ternary untyped `Array` to `Array[String]` for allowed inventory weapons. Godot raised `Trying to assign an array of type "Array" to a variable of type "Array[String]"` and legal restore attempts failed. This new P1 was sent immediately. Further source inspection also found legitimate broken-object health could be negative while validation required 0–35, which would reject saves after real destruction; this related P1 was sent for repair.

The supervisor repaired the ternary array assignment, clamped object damage health to zero, and exposed `_load(slot: int = 1)` so slot 95 could exercise the real load/checkpoint path without accessing slot 1. A second targeted engine run passed **37/37 checks**, emitted `RELEASE_REVIEW_RESULT` with `failures: []`, and exited 0 without a script error. Real broken-object state remained health zero, was accepted by world validation, and survived a slot-95 JSON roundtrip and `_restore()`.

The original gameplay blockers are resolved in the verified revision. No remaining P0/P1 was found within this bounded review. This result is appropriate for a clearly labeled first-chapter alpha; it does not establish a human playthrough, measured performance, all planned assets/tickets, or final publication sanitation.
