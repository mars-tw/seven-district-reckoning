# Alpha 0.3 browser validation

Verified on 2026-10-03 using the actual single-threaded Godot 4.7.2 WASM runtime in Chrome. Production: [seven-district-reckoning](https://seven-district-reckoning.digimkt.workers.dev/). Accepted deployment version: `a98b8dd4-3e2c-4f91-964c-ec2030826c65`.

## Actual browser checks

- The local exported runtime starts and renders the new adult-proportioned hero, distinct contact characters, shopfront, towers and street surfaces. Production shows Alpha 0.3, starts the same real engine and renders the new model set.
- Production loads the pre-existing Alpha 0.2 browser save: position (-56.000, 51.609), the active side commission and original mission state remain; the new district ledger initializes with 120 credits. No production save was overwritten during this acceptance.
- On localhost, the map opens, displays the six districts and real building footprints, and a pointer click adds a destination. Position remains (-56.000, 52.000): this is guidance, not a teleport.
- The actual supply GUI is usable near the shop. Clicking first-aid at health 100 leaves credits at 120. A final usability fix moves rejection text above the offers; its visible placement and single instance were then verified in the native GUI increment.
- The settings UI selects night through an actual canvas click. The resource row reports 21:00 and the rendered sky and ambient colors change. Menus freeze the day/night clock.
- A local explicit save at 21:56 preserves the selected destination, 120 credits and player position after a full page reload, engine restart and load. The resource row confirms night and custom guidance restored.
- At 844 × 390, expanded play shows direction, combat, camera, map and sprint buttons. An actual direction tap changes position from (-56.000, 52.000) to (-55.617, 52.391); the in-game map button opens the full visible map. Sprint was moved into the first direction row after visual inspection found its former third row covered the prompt. The final layout is verified visually and with native GUI rectangles.
- Native fullscreen is rejected by the automation environment; the page-expanded fallback works. The no-native-API branch has isolated JS contract evidence, not an iPhone hardware test. Viewport override was reset.
- No console errors were observed during production startup and legacy-save loading. All [32 production package checks](web-deployment-v03.json) pass against the [build manifest](web-build.json), including decompressed WASM hash, PCK, executable scripts, styles, notices and genuine 404 behavior.

## Evidence and scope

![Actual public Alpha 0.3 after loading the previous save](../docs/evidence/web-public-alpha-0.3.jpg)

This is a real production screenshot, separate from the Blender authoring previews. Browser actions used visible UI and fixed page commands; no arbitrary gameplay setter, mission-completion API or teleport was called.

The [native report](v03-integration-review.md) records 1,381 checks across retained suites and explicit later GUI increments. It does not claim every suite was rerun after each small layout change. Six character assets passed 192 Blender/source/GLB checks and urban assets 121 checks; those are independent asset checks, not phone-performance measurements.

Limits: low-poly human proportions and simplified PBR, not photogrammetry; no facial animation or full riding IK; fictional 300 × 300 m Alpha, not a GIS map of Taichung; background traffic uses bounded routes; navigation is a direction line. Phone hardware, real multitouch, long sessions and complete human campaign playthrough are not established by these tests.
