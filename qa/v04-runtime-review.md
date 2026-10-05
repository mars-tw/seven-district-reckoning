# Alpha 0.4 runtime review

This is an independent context review of the actual shipping sources. It is not a
mobile hardware or hosted-browser performance certification. The world integration
and publication gates remain pending until the root scene is connected and tested.

## Verified manager and device/map modules

`tests/taiwan_life.gd` executes every one of the 34 shipping work orders through
`TaiwanLife.start_task`, real prerequisite completion, prefix conversations,
`choose_route`, and actual `handle_action` calls at the JSON station coordinates.
All 41 possible routes finish. No live manager record/index/cargo is patched to
complete a work order. Negative calls prove that wrong station, action, item,
pickup code, required vehicle, paused input and a position more than 4.5 m away do
not advance the work order. The test round-trips JSON after each actual action and
route choice, including the float representation produced by Godot JSON parsing.

Additional scenarios cover all 32 discoveries, character chapter/trust gates,
one-time story rewards, real repeatable cooldowns, pause/time-step validation,
multi-origin canceled cargo, partial returns, timeout cargo return and restarting.
Malformed-save probes are separate from honest route execution and require
atomic rejection of contradictory cash, trust, route, prerequisite, cargo source,
discovery and index state.

The first review exposed JSON float trust comparison failure after honest NPC
story completion. Root normalized saved whole-number trust/record values and
validated the trust dictionary key/value contract. This repaired all previously
failing story-save round-trips. Root also repaired wrong delivery item validation
and required-trust validation for active and completed stories; the review checks
exercise both gates.

Further probes exposed a completed route that contradicted its reward record,
route selection before the required prefix conversation, and cancellation state
that removed only one of several items sharing a pickup origin. Root repaired
those validators. The current real manager suite passes **3,884 assertions, zero
failures**, executing **470 actual actions** across the 41 routes and additional
prerequisite/return scenarios. Each numbered assertion is a state/action check;
this count does not mean 3,884 unrelated player journeys.

The current final combined totals and source fingerprint must come from a new
full run after Root integration. A previously passing isolated module snapshot
does not certify later source changes.

The refreshed isolated module run passed **4,175 assertions, zero failures**:
Taiwan life 3,884; expanded map 151; native device profiles 86; web device shell
54. `qa/engine-checks-incremental.json` records the common tested fingerprint and
the commands. Expanded-world ambient animation/movement/braking/pause scenarios
are included in the 151 map assertions. The runner now creates a disposable
`qa/` directory for the map fixture's report; without it, that fixture had raised
an error before its summary/quit and reached the runner's 180-second timeout.
That terminated run was a runner fixture-directory failure, not evidence that
the production map succeeded or failed.

## Runner isolation

`tools/test_game.py` snapshots the complete Godot source, GDScript/JavaScript
fixtures and web shell into one temporary directory. Each run imports from a
clean cache and places all engine user-data/config/cache paths in that directory.
Test slots 91–98 are audited; player slot 1 is never read or written. Device
preferences are also inside the sandbox. The fingerprint includes engine source,
JSON, scene/config files, fixtures and web source. Binary art and generated caches
are excluded, so art/rendered inspection is separate evidence.

## Required final integration evidence

- Actual root scene has the 800 m terrain, every station and eight interactive
  story actors, connected through real collision-free approaches from the old
  player start.
- Food, convenience, parcel sorting/verified pickup and return workflows complete
  through actual HUD/station interactions with cargo visuals and no toolbar task
  completion shortcut.
- Phone, tablet and desktop actually apply their distinct renderer, actor and
  input budgets and their intended task/map layouts at representative viewports.
- Pause freezes actual actors/traffic/work clocks; existing mission/optional
  reward ledgers remain independent; old saves retain a valid playable position;
  new expanded-world saves round-trip through reserved test slots.
- Final source snapshot passes all baseline and new suites. Browser startup,
  hosted assets and publication remain Root's responsibility. Android/iOS/tablet
  hardware FPS, heat, audio and memory behavior are not established by headless
  fixtures or isolated DOM mocks.
