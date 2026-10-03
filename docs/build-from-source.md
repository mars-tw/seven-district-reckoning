# Build and run

## Requirements

- Godot **4.7.2 stable** standard build. Use the official release and verify the SHA-512 sums.
- Python 3.12+ for optional validation and sound generation.
- Blender **5.2.0 LTS** to modify/re-export the source art. Blender is not required to run the game because GLB exports are included.
- Windows x86_64 is the validated release target. Linux headless CI configuration is provided as .github/validate.workflow.example.yml. GitHub Actions is not enabled for this release; a native Linux playable binary is not yet validated.

## Run the source project

Open `godot/project.godot` in Godot, allow the first asset import, and press F6/F5 to run the main scene. From a terminal:

```text
godot --path godot --editor --import --quit
godot --path godot
```

If Godot is not on PATH, replace `godot` with the path to your installed executable. Do not edit repository scripts to hardcode a private machine path.

## Test

```text
python tools/test_game.py --godot godot
```

The script imports a clean temporary source snapshot, isolates engine user data, checks importer/parser errors and requires each suite's explicit final summary. It runs the original gameplay, mission, controls, guard and release checks, plus optional content, district life and Alpha 0.2 integration checks. Tests exercise the real scene and physics as well as deterministic mission events. They do not substitute for a human playthrough. Test slots 94–98 are reserved for fixtures; player saves use slot 1.

## Web export and preview

Install the official Godot 4.7.2 export templates and Node.js 24+. The single-threaded Web preset uses the custom shell in `web/` and desktop/mobile texture imports. Parallel importing is disabled after a Windows headless font-reimport crash.

```text
python tools/build_web.py --godot godot
python tools/serve_web.py --port 8766
```

Open `http://127.0.0.1:8766` in a WebGL 2 browser. The resulting static package is in `deliverables/web/`. `prepare_web_assets.mjs` Brotli-compresses the official WASM, adds matching `Content-Encoding: br` headers, versions CSS/JS by content hash, and includes attribution and runtime license files. Re-export before invoking that preparation script again; it deliberately refuses to compress an already-compressed WASM.

Serve the compressed `game.wasm.br` at `/game.wasm` with `Content-Type: application/wasm` and `Content-Encoding: br`. Double-clicking HTML or serving the compressed WASM without its Brotli header will fail. The production Cloudflare configuration is `wrangler.jsonc`; `web/worker.mjs` serves this one engine route with manual encoding to prevent double compression. Other files use normal static asset delivery. Forks must use their own account and deployment credentials in environment variables. Credentials are never part of this repository.

```text
npx wrangler@4.147.0 deploy
```

The site runs entirely on the client. It has no login, multiplayer server, database or cloud save. Browser saves belong to that browser and origin; use the game's save/load menu.

## Windows export

Install the official Godot 4.7.2 export templates in the Godot editor. Then:

```text
godot --headless --path godot --export-release "Windows Desktop" ../deliverables/windows/SevenDistrict.exe
```

The export embeds its PCK. Include CREDITS.md, LICENSE, LICENSE-ASSETS.md, the source asset license copies, Godot notices, and font OFL with binary redistribution. The initial alpha executable is unsigned.

## Art sources

`assets/source/blender/` contains the 25 current `.blend` authoring files; `godot/assets/models/` contains their GLB exports. Small used source meshes and original license copies are included. Original downloaded ZIP archives remain local and can be fetched again using the exact URL and SHA in `assets/provenance/sources.json`.

The Blender tools resolve the repository root from their own location. To rebuild the full alpha set after restoring the listed source files:

```text
blender --background --python tools/blender/build_alpha_assets.py
```

Individual repair/export tools and roundtrip validation are in tools/blender/. Re-exported GLB must be reimported by Godot before checking animation, wheel meshes, or bounds. See docs/asset-build-report.md for the alpha's art limitations.
