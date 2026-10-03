# Changelog

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
