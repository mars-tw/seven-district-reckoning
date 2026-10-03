# Alpha 0.3 independent integration review

Date: 2026-10-03. Runtime: Godot 4.7.2 stable, native headless renderer.

**VERIFIED: the baseline suites and the final targeted Alpha 0.3 run cover 1,381 reported checks with zero failures.** The last complete 11-suite run passed 1,379 checks. After the final supply-feedback and touch-sprint layout changes, only clean import/parse and the affected Alpha 0.3 suite were rerun, passing all 255 checks. The consolidated results retain each record's source fingerprint and validation scope; they do not certify a later deployment or every mobile device.

| Suite | Reported checks | Result |
| --- | ---: | --- |
| Gameplay integration | 9 | PASS |
| Mission contract | 234 | PASS |
| Controls | 44 | PASS |
| Guard persistence | 16 | PASS |
| Release regressions | 37 | PASS |
| Optional content | 175 | PASS |
| District life | 47 | PASS |
| Alpha 0.2 integration | 214 | PASS |
| District systems | 304 | PASS |
| Alpha 0.3 integration | 255 | PASS |
| Urban detail | 46 | PASS |

The existing Alpha 0.2 suites remain in the runner. Their current aggregate is 776 checks, including one additional mission-contract check; the previous release reported 775. The runner requires each suite's actual summary, rejects engine errors even when a script exits with zero, and parses UrbanDetail's integer `passed`/`failed` fields explicitly.

The final 35-file source/config/fixture fingerprint is `6e940f0476c0d3277d7207e8b8938907c3d782009ad5cb157001743c4714b509`. It matches the frozen working source after the final targeted test run. Baseline suite records retain the earlier fingerprint `c2947272ca86d37722e3ac6a150bbf7e47fcaa0507044b44c0bc98288ecbb506`. These fingerprints exclude binary artwork and generated caches; the art manifests retain their separate asset hashes.

## What was exercised

- Six real imported human GLBs load as `PackedScene` resources. Each has articulated skin geometry, textured materials, and eight nonempty animation clips: idle, walk, run, attack, hit, drive, pedal, and knockdown. The actual production player, guards, four rescue people, eight ambient citizens, and three story characters use the appropriate new human models. A held tool attaches to the real hand bone.
- A real mouse event delivered through the root viewport clicks the actual HUD map and reaches the root waypoint state. The player remains in place. The map receives six district regions and the real building obstacle bounds, including the new 16 × 8 metre Mei shop; its marker updates immediately. Alpha 0.2's full physics navigation test still verifies that all 44 optional targets can be approached.
- Map readiness preserves a caller's 350 pixel minimum. The production desktop plot is at least 300 × 300 pixels with the region-label font loaded. At 844 × 390, the entire 164 × 164 pixel plot lies within the visible scroll clip, so its corners remain available for input. At 390 × 219, the map modal stays within the viewport; this tiny size is not claimed to display the entire plot simultaneously.
- Urban visual bounds remain inside the existing 300 × 300 metre map. The actual CPU-authored matrices submitted to the renderer preserve the 294 metre central roads, their 15 metre width, and their intended axes.
- The actual root rejects remote supply purchases, purchases beyond the six metre shop radius, and spending on healing at full health. Nearby first aid applies the exact health and credit changes. One-time upgrades change the player's stamina limit, delivered tool damage, and the bicycle's real acceleration step; the car's acceleration and original mission reward ledgers remain independent.
- A real GUI click on first aid while health is full emits exactly one purchase request, leaves 120 credits and full health intact, and presents one rejection label above the first offer and inside the visible scroll clip.
- The real player's physics moves on the existing streets, spends stamina when sprinting, and supplies valid walking samples to the growth manager. Exhaustion reduces movement to walking; walking recovers stamina. A paused menu freezes player motion, stamina, walking rewards, and the day/night clock. A respawn-sized position jump earns no walking credit.
- Actual training-object damage callbacks complete the tools challenge once. A real three-object SIDE-007 interaction sequence preserves its original 140 voucher reward and records commission completion in the separate growth ledger. Repeated object and completion callbacks cannot duplicate growth rewards.
- Actual HUD time buttons update the street hour and the world's sun energy. Difficulty changes received damage; performance quality disables material normal/AO layers and sun shadows. Camera sensitivity and master-bus mute are reapplied from saved settings. Map, growth, and settings modals fit the tested 844 × 390 native viewport geometry.
- At 844 × 390, the sprint button's rectangle `(10, 170, 54, 50)` does not overlap the visible prompt rectangle `(38, 316, 768, 18)`. A real GUI click on the retained forward arrow still activates movement. A real GUI hold on the touch sprint button presses the input action; after the menu has processed its next frame, that held action is released. Settings opened from the title return to the title without resuming an unstarted game.
- Slot 93 exercises JSON save/load for growth, purchases, stamina, time, preferences, the waypoint, and a nondefault camera yaw. Malformed new dictionaries, invalid stamina, and a NaN camera yaw are rejected before changing the current player or progress. Alpha 0.1 and 0.2 saves migrate; retry retains growth and settings; a new game clears challenges and upgrade effects.
- The initial camera and character face Mei's shop. A legacy save placing the player at `(-54, 0.1, 65)` inside the new shop is relocated to a position with a genuinely clear physics capsule, preserving inventory, mission state, and growth. The small contact shadows share a 32 pixel texture, add no solid or damageable nodes, and disappear for a mounted player.

## Findings resolved during review

1. `StreetState.from_dict` originally compared a string version with an integer and raised a script error. Its first stricter fix rejected JSON's numeric `1.0`. The final finite-number version check rejects invalid input and accepts the genuine JSON roundtrip. Both cases remain covered.
2. The map initially extended perimeter roads to ±145 metres. Its central and perimeter endpoints now match the authored geometry at ±147 and ±137 metres.
3. The existing DistrictLife assertion counted only the old tower-C alias. It now retains the road threshold and requires at least nine imported building instances across the three tower variants and the new shopfront kit.
4. The initial review fixture wrongly required every rescue character to share the civilian model. It now verifies the intended civilian, Zhou, and Yuan variants individually. The requirement for real new human assets was retained.
5. Godot's dummy renderer returns identity matrices when reading back MultiMesh transforms. Road checks now inspect the same CPU-authored matrices passed to the renderer, retaining the dimensions and axis assertions. Touch pause checks wait across the next complete process boundary, retaining the held-action release assertion.
6. Review of the legacy shop relocation path identified a risk of selecting the phone's collision volume. The final root checks candidate positions against real collision shapes. The new fixture restores the inside-shop position to `(-54, 0.1, 71)` with no capsule blockers and requires preservation of inventory and progress.
7. Root's actual browser validation found that `DistrictMap._ready` overwrote the caller's larger minimum with 180 pixels. The original headless checks verified input and outer modal bounds but missed the undersized desktop plot. The fixed component preserves the caller's minimum; additional checks now cover desktop plot dimensions, the region-label size condition, a fully visible landscape-phone plot, and the tiny modal boundary. Headless geometry checks still do not replace browser screenshots or physical-device testing.
8. Root's browser validation found that purchase rejection feedback appeared below the long growth menu. The final HUD inserts that feedback before the offers and avoids repeating it at the footer. The final targeted run verifies the actual purchase GUI callback, credit preservation, label order, single occurrence, and visible label bounds.
9. Root's browser validation at a phone viewport found that the sprint button's third directional-pad row obscured the prompt. Moving sprint to the first row retains a two-row pad. The final targeted fixture checks nonoverlapping button/prompt rectangles and an actual forward-button input callback, while retaining the existing sprint hold/release checks.

## Evidence and limits

- [Consolidated engine results and validation scopes](engine-checks.json)
- [Final targeted UI run](engine-checks-incremental.json)
- [Executable review fixture](../tests/v03_integration.gd)
- [Blender character lineup](art/v03-human/character-lineup.png)
- [Blender urban kit preview](art/urban/urban_street_review.png)

The reviewer inspected the two Blender previews. Human proportions, faces, clothing, glass, stone, footways, and crossings are more specific than the earlier block-style art, but the models remain lightweight and stylized. Blender previews are not browser gameplay screenshots. Headless topology, animation-track, UI-geometry, physics, and state checks do not prove motion quality, photorealism, mobile frame rates, or touch behavior on physical hardware.

The map is an original compact fictional district inspired by Taichung's Seventh Redevelopment Zone. It is not a surveyed GIS reconstruction of Taichung. Navigation lines do not perform automatic pathfinding. The game remains a single-player Alpha.

The runner imports a clean temporary project, redirects user-data locations into that temporary directory, and audits only reserved test slots 93–98. It does not inspect or modify the player's real slot 1. Public logs replace local machine paths with `<repository-root>`, `<isolated-run>`, and `<godot>`. Each suite record includes a source fingerprint for the Godot scripts, scenes, JSON/config files, and GDScript fixtures; binary art and generated import caches are excluded from that fingerprint.

Reproduce from the repository root with:

```powershell
python tools/test_game.py --godot $env:GODOT_BIN
```

Set `GODOT_BIN` to a local Godot 4.7.2 stable executable before running the command.

The final UI increments were validated with:

```powershell
python tools/test_game.py --godot $env:GODOT_BIN --suite v03_integration
```
