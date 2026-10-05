# Changelog

## 0.4.0 — Taiwan life expansion and independent device profiles

Published: https://seven-district-reckoning.digimkt.workers.dev. Dedicated browser entries are `/phone/`, `/tablet/` and `/desktop/`; Windows x64 download is in the [0.4.0 release](https://github.com/mars-tw/seven-district-reckoning/releases/tag/v0.4.0).

- Expanded fictional 800 × 800 m map retaining the original core and adding eight Taiwan-inspired areas: morning market, night market, convenience street, parcel hub, community greenway, riverside, arcade heritage street and creative lane. Thirty-two stations support actual world interaction.
- Research ledger with 52 opened primary sources across 31 major themes and 98 detailed tags. Original adaptation covers street life, local food, markets, community events, recycling, creative activities and store-to-store parcel flows; third-party street photographs are not redistributed.
- Eight additional named fictional characters, two story episodes each, relationship trust, prerequisite unlocks and seven two-route choices. Eight dedicated Blender/GLB variants use licensed MakeHuman base topology, individualized proportions, clothing and original working accessories, retaining the 53-bone rigs and eight action clips.
- Eighteen repeatable food, convenience-store and parcel jobs with cargo, pickup, simulated code checking, recipient handover, return handling and rewards. The fictional orange parcel station is inspired by researched Shopee-style services; no real account, order, payment or personal-data integration is present.
- Thirteen original Taiwan street asset kits plus three food/store/parcel cargo models, with editable Blender sources, exported GLB/PBR materials and CC0 notices, including arcade shops, food stalls, convenience/parcel buildings, shelters, lanterns, recycling and riverside props. A life album records discovered stations and culture notes.
- Four directly playable culture activities: spinning-top rhythm, alternating clog steps, craft color recipes and a four-station walking/bicycle stamp route. Results, badges and best scores persist without changing delivery cash or character trust.
- Actual phone/tablet/desktop input, HUD, resolution, view-distance, LOD, audio and ambient-actor budgets. Indexed floating touch controls support independent movement, camera and brake fingers, with releases on cancellation, focus/orientation/profile changes and pause. Device preferences remain outside campaign saves.
- Four generated launch documents at `/`, `/phone/`, `/tablet/` and `/desktop/`, each with distinct defaults and instructions while sharing one root engine/PCK/WASM. Fixed profile commands and a jobs menu replace arbitrary browser actions; canvas backing ratios cap at 1.50/1.75/2.00 while respecting the actual device ratio and safe margins.
- Corrected root asset URLs, content-hash cache busting, canonical entry redirects, compressed WASM MIME and unencoded 404 responses. Build/deployment verification rejects stale files, wrong configuration and HTML fallback returned as game resources.
- Final frozen-source evidence: 17 suites / 8,561 checks pass, including 2,698 actual Root scene/UI checks, 245 culture checks and 99 web-shell contracts. The Root matrix completes all 41 shipping story/order/branch routes through 321 real station actions; all 32 stations have connected physical approaches. Public package/entry integrity passes 96 checks. All three modes boot and apply their actual budgets in hosted desktop Chromium/IAB; canvas life-menu interaction and desktop-save continuation through phone/tablet modes retain both position and device profile. This viewport/profile evidence does not certify physical phone/tablet FPS, heat or long sessions.
- An unsigned Windows x64 package embeds its one PCK, retains required runtime/asset notices and passes native PE/version, pack integrity, archive CRC and quiet five-frame original-title headless startup. This package check is distinct from rendered gameplay verification.
- The renamed OFL game font grows to 266,184 bytes (about 260 KiB) for the new text. Alpha 0.3's historical subset was about 191 KiB.

## 0.3.0 — Character, street and gameplay systems update

Published: https://seven-district-reckoning.digimkt.workers.dev.

- Six new human-proportioned characters for the hero, guard, pedestrian, Mei, Yu-an and Zhou. MakeHuman CC0 base meshes, 53-bone rigs and eight movement/action clips are included with editable Blender sources; facial performance and close-up realism remain future work.
- Six new urban assets: three office towers, a shopfront, sidewalk and bench. Floor modules, entrance details, original PBR street materials, crossings, markings and drainage detail improve the existing fictional 300 × 300 m district. This is not a GIS reconstruction of Taichung.
- Sprint stamina and four shop offers: healing, a stamina-cap upgrade, tool-damage improvement and bicycle acceleration tuning. Purchases require proximity to the bike shop and use a separate district-credit ledger.
- Three grant-once district challenges track actual walking distance, distinct side-quest completions and distinct legal tool targets. Vehicle travel, respawn jumps, repeated rewards, civilians and evidence do not count toward the corresponding challenges.
- A destination map, navigation marker, day/night cycle, quality/difficulty presets, camera sensitivity and sound settings. Map clicks set guidance without teleporting. Settings and district progression are saved, with Alpha 0.1/0.2 save compatibility retained.
- Website controls for the map, supplies/challenges and settings, plus a read-only resource summary. Browsers without native fullscreen can expand the game within the page; native rejection and synchronous API errors use the same fallback.
- 1,381 reported engine/gameplay/GUI checks pass, with the complete run and later UI increments documented separately. Character source/GLB validation passes 192 checks, urban assets 121 checks, and public HTTP/package integrity 32 checks. Actual Chrome startup, legacy-save loading, map navigation, night setting, supplies and landscape controls are verified. Real phone hardware and a full human campaign playthrough remain outside this evidence.

## 0.2.0 — Browser play and district expansion

Published: https://seven-district-reckoning.digimkt.workers.dev.

- Single-player Web export using Godot 4.7.2's single-thread template, with a custom game-first shell, genuine loading progress, retry, fullscreen and fixed game UI commands. The existing Windows 0.1.0 download remains available.
- Web camera control uses right-button drag; the native desktop camera retains mouse capture. In-game touch controls include movement, combat, interaction, mount/dismount, jump/brake, tool change, vehicle recovery, camera steps, assignments and pause.
- Six playable side quests and four repeatable activities, with saved completion, separate parts vouchers, street-view collection and personal best times. First-completion and unique photo rewards cannot be collected twice.
- Six surrounding districts inside the existing 300 × 300 m alpha map, eight ambient pedestrians, four moving cars and six parked cars using the shipped art. Ambient actors follow bounded routes and freeze while the game is paused.
- Optional world targets integrated with actual interactions, bicycle/car requirements, timed checkpoints and fully contained, aligned, stationary parking checks. Checkpoint retries and save/load preserve optional outcomes.
- Browser saves remain in IndexedDB for the same browser and site origin. Clearing site data removes them; browser and Windows saves are separate.
- The OFL font is subset and renamed to Seven District Sans TC (about 171 KiB); the original Noto Sans TC source stays in the repository and is excluded from Web export.
- 47 district scene/physics checks, 175 optional-manager/save checks and 214 actual-root integration checks; all 775 reported checks pass including the original baseline suites. Headless/fixture checks do not establish mobile-device performance or a complete human playthrough.

## 0.1.0 — First public alpha

- Godot 4.7.2 project with a third-person controller, camera collision, tool combat, guards, and destructible objects.
- Five first-chapter missions with smash, evidence, and rescue options.
- Driveable car and bicycle with animated wheels, braking, safe dismount, and recovery.
- Traditional Chinese HUD, mission phone, title/pause/chapter screens, minimap, and bundled OFL font.
- Atomic save/backup, inventory/energy/vehicle/guard restoration, and replayable world checkpoints.
- Twenty-five actual Blender/GLB exports with source meshes, license copies, attribution, rig clips, and reproducible tools.
- Engine, contract, control, and independent regression evidence. This alpha is not the full six-zone MVP or completion of all 50 planned tickets.
