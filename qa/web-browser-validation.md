# Alpha 0.2 browser acceptance

Verified on 2026-10-03 against the published [online game](https://seven-district-reckoning.digimkt.workers.dev/), using Chrome with WebGL 2 and the actual Godot 4.7.2 single-threaded WASM runtime.

## Executed checks

- The public page displays the loading state, finishes engine startup, and accepts the real second-click start action. The genuine 3D scene, hero, buildings, vehicles and HUD appear.
- The touch toggle reveals actual in-game controls. A GUI tap moves the player's Z coordinate from 52.000 to 51.609, confirmed through the page's read-only canvas attributes.
- The optional-content menu opens through the website button. Clicking “招牌不會自己倒” starts the quest, displays the 0/3 target text and changes minimap guidance.
- Pause/resume and save commands work through the website UI. After saving, reloading the whole public page, restarting the runtime and choosing load, the position returns to (-56.000, 51.609), the selected side quest remains active, and “已讀取存檔” appears.
- The public-origin console reports no errors during the above actions. Local pointer-lock errors from an earlier build were resolved by visible web mouse input and right-button orbit support.
- The final shell's expanded-play fallback was exercised on localhost at 844 × 390: the whole play area, movement controls and quest button work. Chrome's native fullscreen request was rejected in automation, so native fullscreen success is not claimed. The fallback fills the browser viewport and the return button exits it.
- The public page was resized to 390 × 844; its game canvas measures 357 × 426 CSS pixels and displays the controls. Landscape expanded play remains the recommended touch layout. The temporary viewport override was reset afterward.
- All 29 HTTP/package checks pass, including WASM decoding back to the official 39,514,754-byte engine with its recorded SHA-256, all uploaded notices and a genuine 404 response. See [deployment integrity](web-deployment.json) and [build manifest](web-build.json).

## Deployment

- Worker: `seven-district-reckoning`.
- Accepted version: `76f47958-62bb-4205-826f-59e2fd90564f`.
- Engine transfer: 8,041,529-byte Brotli asset. One small handler serves only `/game.wasm` with manual response encoding; other resources use static delivery. This avoids the double compression observed on the first deployment. The approach follows [Cloudflare's response encoding contract](https://developers.cloudflare.com/workers/runtime-apis/response/#the-encodebody-option).
- Gameplay, quests and saves run locally in the browser. There is no multiplayer service, account or cloud-save database.

## Evidence and limits

![Public build after page reload and successful save load](../docs/evidence/web-public-alpha-0.2.jpg)

The image was captured from the live public site. Tests did not call hidden gameplay state setters, teleport APIs or mission-completion commands from the browser. Headless tests use explicit fixtures and are reported separately in [engine checks](engine-checks.json): 775 reported checks, zero failures.

This is not a complete human playthrough or a phone-hardware performance test. Native fullscreen, real multitouch, long sessions and the full 800 × 800 m MVP remain outside this acceptance. The game remains a stylized single-player Alpha within the existing 300 × 300 m map.
