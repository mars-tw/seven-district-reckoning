# Changelog

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
