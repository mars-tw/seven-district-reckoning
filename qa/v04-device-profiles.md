# Alpha 0.4 device profiles

This report covers the device lane. Hosted browser playback and real mobile hardware
performance require the final integration/export review; they are not asserted here.

## Implemented

| Setting | Phone | Tablet | Desktop |
| --- | --- | --- | --- |
| Input | Indexed floating joystick, tap actions, drag view | Larger joystick and spaced actions | Keyboard/mouse; optional legacy D-pad |
| 3D bilinear scale | 0.70 | 0.85 | 1.00 |
| Canvas pixel ratio cap | 1.50 | 1.75 | 2.00 |
| Small prop / building range | 70 / 190 m | 110 / 280 m | 180 / 440 m |
| Camera far | 240 m | 360 m | 560 m |
| Mesh LOD threshold | 4 | 2 | 1 |
| Ambient citizen / traffic limit | 6 / 2 | 12 / 4 | 24 / 8 |
| Ambient activation distance | 90 m | 140 m | 230 m |
| Audio voices / spatial range | 4 / 30 m | 8 / 55 m | 16 / 90 m |
| Requested HUD contract | Compact, one task column | Split task columns, larger map | Expanded, two task columns |

The manager applies real `Viewport`, `Camera3D`, `Light3D`, geometry range and audio
properties. Ambient nodes receive `device_budget_active` metadata and visibility;
the central city update loop must honor that flag to skip their CPU movement/thinking.
No collision bodies or mission actors are deleted. Player/guard/rescue groups and
`device_geometry_kind=character` are exempt from generic mesh culling. Large ground
footprints, `device_geometry_kind=terrain` and `device_keep_visible=true` remain
visible; this avoids a road/terrain group disappearing because its origin is distant.
Original shorter geometry ranges remain upper bounds. Only lights with an original
enabled shadow are restored for desktop; the root must create its sun with that
baseline if it previously forced Web low quality.

Phone/tablet actions use an owning finger index, not a simulated mouse. Movement,
camera drag and braking can occur with three distinct fingers. A joystick drag is
consumed even after it crosses the camera half. Canceled touches, focus loss, pause,
orientation changes, profile changes and disabling controls release owned actions.
A 140 ms action window makes a quick interaction tap observable by the physics loop.
Sprint supports both tap toggle and a held action via `sprint_toggle` preference.
Touch-to-mouse emulation is disabled during active touch gameplay and restored in
menus, preventing finger 0 from also triggering the desktop attack binding.

The shell adds a device selector plus `/phone`, `/tablet`, `/desktop` entry links.
These are separate launch configurations for the same exported engine and same
browser save, not three duplicated builds. The export integration must generate
the route index documents and keep engine resources rooted at `/game`. Device mode
changes actually change backing canvas allocation. Fullscreen CSS safe-area padding
is subtracted before allocation, so native Godot controls occupy the safe content
area. A touch-enabled laptop with a fine pointer stays desktop automatically.

## API contract for root integration

`DeviceProfiles.initialize(viewport, pointer_touch, device_hint, load_preferences)`
classifies native/mobile hardware and loads only its own device section.
`set_profile("auto"|"phone"|"tablet"|"desktop", persist)` selects a manual profile;
`profile_changed(settings)` exposes the full immutable-by-copy settings dictionary.
Use `get_profile()`, `get_requested_profile()`, `get_hardware_profile()` and
`get_settings()` for UI/status. `set_preference(key,value)` accepts only validated
resolution scale, muted, sensitivity and sprint toggle preferences. Device settings
live in `user://device-preferences-v1.cfg`, outside campaign/street snapshots.

Call `apply_scene(scene, player)` after geometry and ambient actors are created.
The attached manager updates nearest ambient budgets every 0.5 seconds;
`update_ambient(player)` may also be called after a world rebuild or teleport used
by test/save migration. Root applies sensitivity to its controller and uses the
HUD contract fields to build the actual compact/split/expanded layout.

`TouchControls.set_profile(settings_dictionary_or_name)` changes the actual control
layout; `set_safe_insets(Vector4(left,top,right,bottom))` accepts UI-coordinate native
safe margins. Existing `camera_step`, `phone_requested`, `map_requested`,
`pause_requested`, `set_enabled()` and `release_all()` remain available.
New `jobs_requested` is a fixed menu signal. Do not inject arbitrary task/position
events through the browser bridge.

`window.sevenDistrictDevice` is a read-only frozen snapshot with `profile`,
`requested_profile`, `device_hint`, `pointer_touch`, `pixel_ratio_cap` and the actual
`pixel_ratio`. Root uses actual pixel ratio for its UI scale. The shell sends only
`profile_auto`, `profile_phone`, `profile_tablet`, `profile_desktop`, and `jobs` in
addition to its existing command whitelist. Root status includes `device_profile`.

## Verification completed

- `tests/device_profiles.gd`: **86 checks, 0 failures** on real Godot 4.7.2 headless.
  Includes actual animated `SevenPlayer` movement from an indexed joystick; separate
  camera finger; third-finger brake; tap interaction once; sprint toggle and held
  mode; cancel/pause/orientation releases; real geometry, camera, shadow, audio and
  ambient node budgets; independent preference files and validation.
- Actual control rectangle/44 px minimum target checks at 360×800, 390×844,
  844×390, 768×1024, 1024×768, 1280×800, 1366×768 and 1920×1080. Safe insets were
  supplied as 12 px horizontally and 20 px vertically. Joystick/action grids do not
  overlap in these cases. These are viewport geometry checks, not hardware FPS claims.
- `node tests/device_web.mjs`: **54 checks, 0 failures**. Isolated DOM/engine mocks
  verify shell selectors, actual canvas dimension calculations, fixed bridge
  commands, route/manual/auto choices, fine-pointer laptop classification, local
  preference isolation, safe-padding subtraction and focus-loss pause. This does
  not prove WASM loading, WebGL rendering, CSS screenshots or touch hardware behavior.
- Existing isolated Godot regressions: `v02_integration.gd` **214 checks, 0 failures**;
  `v03_integration.gd` **255 checks, 0 failures**. Their source snapshot predates the
  final 0.4 main/HUD integration, which must receive its own final regression run.

Primary renderer evidence: Godot 4.7.2 GLES3 `RenderSceneBuffersGLES3::configure`
accepts distinct internal/target sizes, supports bilinear/nearest modes and allocates
the GL render textures with `internal_size`. Thus 3D scale support is not inferred
from old 4.2 forum posts or a no-op property assignment. It still needs final rendered
frame inspection and profiling for the shipped export.

- [Godot 4.7.2 GLES3 render buffers](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/gles3/storage/render_scene_buffers_gles3.cpp)
- [Viewport scaling API](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-property-scaling-3d-scale)
- [Indexed/canceled screen touches](https://docs.godotengine.org/en/stable/classes/class_inputeventscreentouch.html)

## Final integration gates still required

Root must wire the manager/HUD layout, central city budget flag, browser whitelist,
keyboard J shortcut and native sensitivity/preferences; generate separate entry
routes; then export and run real browser startup/control/save checks. Phone/tablet
task/map rendered layouts and Safari/Android hardware frame rate, heat, audio and
browser memory limits have not been certified by this bounded lane.
