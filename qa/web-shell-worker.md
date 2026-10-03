# Web shell worker handoff

Status: EXECUTED. Static syntax and 52 isolated DOM/Engine/bridge-contract checks are VERIFIED. Actual exported WebAssembly, hosted gameplay, touchscreen input, browser audio and visual acceptance remain for the supervisor's real-browser run.

## Delivered scope

- `web/shell.html`: Godot custom export shell; `canvas` is the actual game canvas and `start-button` starts the official engine. It includes a compact playable-first page, street dispatch-slip launch screen, controls, background, source/credits links and an explicitly labeled Windows Alpha 0.1.0 alternative.
- `web/play-site.css`: forest/deep office blue, warm orange and glass-office geometry. The canvas remains the main surface. Responsive layout, visible focus, landscape play area and reduced-motion handling are included.
- `web/play-site.js`: user-initiated `Engine.startGame()`, genuine `onProgress`, failures, whole-page retry, exit handling, fullscreen and canvas focus. The canvas uses `canvasResizePolicy: 0` with a 1366:768 aspect and backing scale capped at 2. Resize/fullscreen/orientation/visualViewport/ResizeObserver updates keep dimensions above zero.
- `web/404.html`: root-hosted 404 entry with a return-to-game and download link.

Only these four files and this report were written by this worker. No presets, Godot scripts, deployment code, publishing, package installation or credentials were changed.

## Export integration contract

Export the game to the site's root under the `game` prefix, and copy `play-site.css`, `play-site.js` and `404.html` alongside the generated HTML and engine files. Set `web/shell.html` as the preset's custom shell. The shell intentionally retains `$GODOT_PROJECT_NAME`, `$GODOT_HEAD_INCLUDE`, `$GODOT_THREADS_ENABLED`, `$GODOT_CONFIG` and `$GODOT_URL` for the exporter. Configuration is JSON in a non-executable script node, so there is no inline bootstrap script.

DOM hooks: `start-button`, `canvas`, `game-frame`, `fullscreen-button`, `load-progress` and `status-message`. `window.sevenDistrictStatus` is a read-only, frozen snapshot getter exposing only `phase`, `loaded`, `total` and `message`; it cannot issue game actions. Phases are `ready`, `loading`, `running`, `failed` and `exited`. `running` means the engine startup promise resolved; it does not prove a mission was completed or a gameplay check passed.

The page accepts the supervisor's `seven-district-state` event for plain-text mission/objective and side/activity completion display. Coordinates are limited to numeric canvas data attributes for UI validation. The game's `window.sevenDistrictCommand` exposes a fixed UI whitelist; page buttons call only `new_game`, `pause`, `phone`, `resume`, `save`, `load` and `touch_toggle`. No event/mission ID, position, arbitrary code or host API can be injected through the page controls.

After engine startup, a second real “進入街區” click calls `new_game` if the game bridge is available. Otherwise the actual Godot menu remains usable. Mouse capture and audio begin through that player gesture or Godot's own menu click. Fullscreen is requested immediately in its click gesture. No fake game, synthetic input, public engine instance or arbitrary GDScript action bridge is provided.

The single-thread feature check uses the substituted `$GODOT_THREADS_ENABLED` rather than assuming isolation headers. File URLs are not a supported launch path. The page does not alter the engine's asset URLs or perform compression. Host encoding and `.wasm`/`.pck` transport are the supervisor's responsibility.

## API evidence

The same-version local export template (`godot.html`) and engine bundle (`godot.js`) were inspected. Their public startup, progress, configuration and exit contracts match the implementation. Primary-source references are the [Godot 4.7.2 HTML template](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/misc/dist/html/full-size.html), [Engine API](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/platform/web/js/engine/engine.js), [configuration](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/platform/web/js/engine/config.js), [feature checks](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/platform/web/js/engine/features.js) and [canvas resizing](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/platform/web/js/libs/library_godot_display.js).

## Executed verification

- `node --check web/play-site.js`: PASS.
- An ephemeral Node VM harness with mock DOM/Engine/game bridge: PASS, 52 assertions. It covered the genuine callback contract, single-thread feature flag, duplicate-start suppression, known and indeterminate download progress, percentage clamp, manual aspect/DPR sizing, zero-size protection, startup success/rejection, fullscreen/unsupported fullscreen, normal exit, missing engine/config/features, reload retry, lost WebGL context, touch notice, the read-only diagnostic surface, the second-click start gesture, bridge fallback, fixed command calls, plain-text event display, state-specific controls and numeric-only coordinate attributes.
- HTML inspection: PASS. Exactly one canvas, unique DOM IDs, five official placeholder types, self-hosted executable resources and non-executable JSON configuration.
- Placeholder/API inspection against the same-version local template: PASS.

Mock Engine checks validate page behavior only. They are not actual engine startup, game input, screenshot, WebAssembly, mobile or hosting validation. The supervisor must perform those checks against an exported build.

## Real-browser acceptance still required

This worker report records the initial isolated shell contract tests. The supervisor later changed responsive sizing, added the fullscreen fallback, and completed real exported/public browser validation in [web-browser-validation.md](web-browser-validation.md). That final report supersedes the pending items below for the checks it actually executed.

1. Export and open over localhost/HTTPS. Check no `$GODOT_*` remains in generated HTML and the root's engine asset URLs all return the correct content and encoding.
2. Click `start-button`, observe genuine progress, then observe the actual Godot title/menu and start a new game. Validate keyboard, mouse/audio, pause/resume, save/load and mission progress through the game UI.
3. Enter/exit fullscreen and resize repeatedly at 1366×768 and a high-DPR viewport. Verify canvas stays visible, correctly proportioned and at most twice its CSS dimensions.
4. Test missing/blocked engine assets, unsupported features and context loss. The retry must reload the page and the download alternative remain available.
5. Disable JavaScript to inspect the explicit WebGL 2/JavaScript notice. Check keyboard focus, reduced motion, 390px portrait and phone landscape layout.
6. Verify actual phone controls and performance on a device before describing mobile play as validated. The current copy explicitly says mobile input/performance remain in testing.

## Copy review (mode 2)

This is new interface copy, so no existing sentences were replaced. The protected game name, public repository URLs and Windows Alpha 0.1.0 label were preserved. Wording uses concrete actions (“開始線上遊玩”, “重新載入遊戲”, “回到遊戲”) and explains real browser constraints without promotional claims. The page's Alpha 0.2 label identifies the new online build; the existing download is separately labeled 0.1.0.

## Material integration consideration

The shell CSP allows same-origin scripts and WebAssembly compilation, plus same-origin/blob workers. It excludes `unsafe-eval`. The supervisor confirmed that the game state/command integration uses `JavaScriptBridge.get_interface` / `create_object` / `dispatchEvent`, which does not require that permission. No analytics, third-party font request or external executable resource is used.
