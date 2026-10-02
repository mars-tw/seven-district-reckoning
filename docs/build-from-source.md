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

The script checks importer/parser errors and requires explicit integration success. Tests exercise the real scene and physics as well as deterministic mission events. They do not substitute for a human playthrough. Test slots 95–98 are reserved for fixtures; player saves use slot 1. Contract tests refuse to overwrite a pre-existing unrelated fixture.

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
