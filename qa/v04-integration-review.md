# Alpha 0.4 RootScene integration review

The independent review ran the real shipping `scenes/main.tscn`, its actual
physics space, production managers, original mission objects, Taiwan expansion,
HUD and device controller. The final frozen-source run passed **17 suites with
8,561 assertions, zero failures**, including **2,698 RootScene integration checks**,
245 culture-activity module checks and 99 web-shell contract checks.
`qa/engine-checks.json` records the commands, actual output and common 63-file
source fingerprint:

`29c6c8c86b9c5a5950aac72dead196725defe8d35ccd18dd73892c27c5ef22d8`

An independent recomputation confirmed that the current shipping source matches
every final report entry. The fingerprint covers Godot source/config, fixtures,
web shell and imported web build/verification helpers; binary art/import caches
and ignored duplicate `_checks` capture scripts are excluded. Art/rendered
inspection is separate evidence. Later shipping-source edits invalidate this
frozen-source acceptance until their effects are verified.

Reproduce this bounded suite with:

```powershell
python tools/test_game.py --godot $env:GODOT_BIN --suite v04_integration
```

## Actual world and workflows

The test builds a capsule navigation graph connected to the old player start.
Each traversed edge is sampled every metre against the actual combined static
collision world and must also have actual floor collision. It found **9,307
connected points**. All **32 stations** have a connected approach within the
player's interaction range and an unobstructed ray to the real interactable.
This includes the original office/building collisions as well as new structures.
It establishes deterministic physical connectivity; fixture placement does not
claim a person manually walked these routes.

The final fixture completes **all 41 distinct shipping routes** through
production task-menu buttons, the player's real interaction signal and actual
station-menu buttons: all 16 character chapters, all 18 delivery orders and all
seven additional branch choices. Each independent case resets life state through
the production API, then completes any necessary earlier chapter through the
same real Root UI to earn its unlock. No records, wallet, trust, progress index
or cargo are filled to bypass prerequisites. Each branch's actual HUD button
sets the specified route; completion must increment the correct route record
exactly once, award its authored cash/trust, report the correct outcome and leave
no cargo or origin entries. The engine summary records the complete 41-key route
list and proves it contains 41 distinct keys.

The earlier negative and recovery scenarios remain: parcel pickup rejects an
incorrect four-digit code before verification, pickup, sorting drop-off, sorting
pickup and final hand-off; two shops' canceled cargo returns one origin while
retaining the other; timed bicycle food fails with its food retained and returns
through the actual station UI. After the full matrix, the fixture earns LIN's
two chapters again through the UI so save/retry must preserve genuinely nonzero
cash, trust and records together with active cargo. These scenarios execute
**321 successful station actions**, including prerequisites and recovery probes.
Menu signals are native logical UI fixtures; they are not hosted-browser clicks
or complete human walks across all 41 routes. The isolated manager's separate
41-route tests are additional coverage, not a substitute for this Root matrix.

All eight story actors use eight distinct authored GLB files, contain a real
skinned mesh and at least 53 bones/eight animation clips, and play idle animation.
Their visible name/role labels and actual home-station dialogue match their
individual identity. This does not establish photographic likeness or artistic
quality; rendered art inspection is separate evidence.

The cargo review inspects actual attached, visible mesh geometry, its source path
and current cargo metadata. Food uses `tw_carry_food.glb` with a local AABB of
0.46 × 0.5625 × 0.4295 m; convenience shopping uses `tw_carry_shop.glb`,
0.32 × 0.536 × 0.195 m; parcels use `tw_carry_parcel.glb`,
0.42 × 0.343 × 0.309 m. Empty cargo removes the visible carrying object. None is a
scaled multi-level sorting shelf.

The actual large map uses a radius of 400 m, therefore an **800 × 800 m** span,
contains all station markers and expansion roads, and round-trips every station
coordinate inside its drawing area. A new-world position more than 300 m from the
origin survives a root process update and real reserved-slot save/load.

## Device, save and pause integration

Phone, tablet and desktop selections actually change the viewport's 3D scaling
and LOD threshold, camera far distance, audio voice budget and touch input mode.
The root contains 24 ambient citizens and eight traffic actors. Applied global
budgets cap active actors at the profile's 6/2, 12/4 or 24/8 limits; distance also
limits which actors should be active. All 162 small expansion draw groups retain
the sector-corner allowance rather than receiving conflicting generic culling.

Measured native container rectangles fit these viewports:

| Profile | Viewport | Modal position | Modal size |
| --- | --- | --- | --- |
| Phone | 480 × 844 | 8, 172 | 464 × 500 |
| Phone | 360 × 800 | 8, 150 | 344 × 500 |
| Phone | 844 × 390 | 97, 55 | 650 × 280 |
| Tablet | 1024 × 768 | 38, 126 | 948 × 516 |
| Tablet | 768 × 1024 | 38, 254 | 692 × 516 |
| Desktop | 1366 × 768 | 126, 126 | 1114 × 516 |

The phone task menu uses one column. The tablet and wide desktop menus have two
actual laid-out columns with non-overlapping positive rectangles. Headless layout
rectangles are not pixel-rendered screenshots or physical-device measurements.

Reserved slots 91 and 92 round-trip a valid expanded-world snapshot. Representative
legacy schema-1 payloads with the 0.1/0.2/0.3 field sets restore at a playable old
spawn without replacing current phone render/input preferences. These payloads
are rebuilt compatibility fixtures, not a claim that human saves were inspected.
Main-mission retry retains life cash, trust, records and active cargo. Pausing the
real HUD freezes the work clock and both the old/new ambient actors. The runner
isolates every user-data/preference path and never reads or writes player slot 1.

## Findings repaired by the implementation owner

- Replaced the shrinking station shelf used as cargo with three actual carrying
  props, then verified their attached geometry through the runtime.
- Made root device selection apply the requested input mode; selecting phone or
  tablet had previously left touch controls disabled on a desktop.
- Reduced phone modal margins and allowed long button text to wrap; the old
  480 × 844 menu extended to x=490 outside the 480 px viewport.
- Removed generic device culling from sector-managed geometry. All 162 small
  draw groups had previously lost the expansion module's corner margin.

The review fixture also corrected its own `camera`/`_camera` field mismatch and an
invalid 0.5 sensitivity used in a purported 0.3 save. Neither fixture mistake was
reported as a production failure.

The complete regression run additionally exposed the expansion's two-argument
attack callback connected to the player's actual one-argument signal. The owner
repaired the signature; the final fixture begins a real player weapon swing and
checks the expanded civilian's flee clock and horizontal movement speed. Traffic
checks both apply the actual budget to fixture placement and let a normal budget
tick wake a distant actor before checking its physical sensor braking. Returning
to a position outside a tablet's visibility budget is not treated as a moving
car. Existing physics stopping/resuming checks retain their original speed
requirements.

The owner also repaired the activity host's `on_foot`/`foot` token mismatch and
reordered short-screen gameplay so the gauge and action remain visible together.
The final phone-landscape 844 × 390 clip is `(121,75;602,240)`; its gauge is
`(121,120;444,72)` and action is `(577,120;138,70)`, both fully inside the clip.
Actual station dialogue now follows the completed character chapters; the LIN
two-chapter run verifies the final remembered dialogue at the real home station.

The old 0.3 fixture was adapted to the new explicit requirements without dropping
coverage: it preserves every original district and every original building
collision in the full 14-district/all-collision map, invokes actual settings
callbacks, and proves that older campaign settings cannot overwrite the current
device's camera/audio preferences or hardware profile. Imported web build/helper
modules are copied into the isolated runner and included in its fingerprint.

## Remaining scope

The accepted real root culture flows complete eight scored top/clogs beats, three craft
recipes with one deliberate error, and four physically reachable walking stamps.
They earn all four badges without changing delivery cash or character trust.
Remote starts/stamps do not advance, the ordinary pause menu freezes the clock,
and actual save/retry retains earned results. Phone portrait and landscape,
tablet and desktop controls pass their simultaneous gauge/action clipping checks.

This suite does not certify Android/iOS/tablet FPS, heat, audio output, memory,
multitouch hardware or browser startup. Those require actual rendered and
device/browser evidence. It does not certify a subsequently changed source tree,
online deployment or publication. The full user goal remains active until the
remaining browser/public-build requirements are verified against the shipping
state. Headless native checks must never be presented as physical-device
performance certification.
