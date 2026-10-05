# Alpha 0.4 Windows x64 export and package

Status: VERIFIED for the bounded native export/redistribution lane. No release upload, Git push or deployment was performed here. This is a headless startup and package-integrity check, not a rendered Windows playthrough.

## Frozen source and exporter

The production freeze signal was received before the final import/export. Source includes the latest eight Taiwan character meshes after their apron/thigh adjustment, the culture activities and short-screen UI integration; their art/gameplay checks remain owned by their respective lanes.

- Official exporter: Godot `4.7.2.stable.official.ed1daf0bf`.
- Export preset: `Windows Desktop`, x86_64, embedded PCK, no code signing.
- File and product PE versions: **0.4.0.0**.
- The exported executable itself returns runtime version **4.7.2.stable.official.ed1daf0bf**.
- `tools/test_game.py::source_fingerprint` on the frozen source: **63 files**, SHA-256 `29c6c8c86b9c5a5950aac72dead196725defe8d35ccd18dd73892c27c5ef22d8`.
- That fingerprint covers Godot source/config, GDScript/JS fixtures, web shell and its imported build helpers. It explicitly excludes binary art and importer caches; it is not claimed as a Blender-art hash.

Final commands, run with the exporter executable on PATH as `godot`:

```powershell
# In godot/:
godot --headless --quiet --language en --path . --editor --import --quit
godot --headless --quiet --language en --path . --export-release "Windows Desktop" ../deliverables/windows/SevenDistrict.exe
# In repository root:
python tools/package_release.py --version 0.4.0
```

Both final import/export commands exited 0 without output.

## Executable and embedded resources

| Item | Verified value |
| --- | --- |
| EXE | `deliverables/windows/SevenDistrict.exe` |
| EXE size | 120,091,464 bytes |
| EXE SHA-256 | `e89be884b7e5c2cc6eb15566b288bd16b633c467711f91425ed4f01a88a4d814` |
| PE | x86_64 / PE32+ |
| Embedded PCK | Format 4, Godot 4.7.2; 10,935,100 bytes; 722 resources |
| External PCK | None; the executable already contains the one game payload. |
| Extra runtime DLL files | None in this export. The PE import table names Windows system/API-set libraries; actual native process startup succeeds with this standalone EXE. |

The pack reader follows the [official Godot 4.7.2 reader](https://github.com/godotengine/godot/blob/4.7.2-stable/core/io/file_access_pack.cpp). Every indexed resource passed its stored checksum, path uniqueness and byte bounds. `_checks/` fixtures and the full source `NotoSansTC-Regular` font are absent. The renamed font subset remains available to the game.

The embedded project configuration retains `res://scenes/main.tscn` and version 0.4.0. Six directly packaged JSON files exactly match the frozen source bytes: Taiwan life, expansion, device profiles, culture activities, street assets and people manifests. The seventh required resource is the derived project binary, whose version/main-scene configuration was checked separately. All eight named Taiwan character resources occur in the pack. No second standalone `.pck` was included in the ZIP.

## Quiet original-title startup

The verified exported EXE, with its directory as cwd, was started with:

```text
SevenDistrict.exe --headless --quiet --language en --quit-after 5
```

It exited **0 after the requested 5 frames**, with **0 bytes stdout/stderr**. There was no `--scene`, `--script`, custom fixture, gameplay command, input injection or save operation. The original project/title startup path was used; the process was hidden and headless. This does not prove GPU rendering, keyboard/mouse play, loading a player's save or completing the campaign.

## Redistribution archive

| Item | Verified value |
| --- | --- |
| Archive | `deliverables/SevenDistrict-0.4.0-Windows-x64.zip` |
| Archive size | **48,590,332 bytes** |
| Archive SHA-256 | **`a1d0110f0a277bc880395764b25eba1f75c78a7abcd9dc9609104401f3397c78`** |
| Checksum sidecar | `deliverables/SevenDistrict-0.4.0-Windows-x64.zip.sha256` |
| Entries | 20 files under `SevenDistrict-0.4.0-Windows-x64/` |

The archive passed ZIP CRC validation; its EXE bytes exactly equal the startup-verified binary. Repackaging with the source-fingerprint/runtime-version report produced the same archive hash. Entries come from the verified runtime and an explicit notice set, rather than archiving an arbitrary source or delivery directory.

Included notices: `LICENSE` (MIT), `CREDITS.md`, `LICENSE-ASSETS.md`, `runtime-notices.txt`, Godot MIT/copyright/third-party notices, Kenney license copies, bicycle CC BY 3.0, font OFL, MakeHuman source asset rights/notice, and original urban/Taiwan CC0 declarations. Original synthesized audio attribution and CC BY 4.0 license URL are retained. Packaged Markdown attribution links resolve to included notices or the source repository; original source documents are untouched.

No credentials, local reports, Blender/source archives, raw cache folders, test fixtures or full source font are copied into the binary archive. The new packager reads only the project version, exported EXE and known public notice sources; it never reads the credential store. It refuses malformed/mismatched versions, unsupported/encrypted packs, duplicate payloads, stale data, startup errors and potential secret-bearing notices.

Ignored local detail: `qa/local/v04-windows-package.json` and `qa/local/v04-windows-startup.log`. Public source changes owned by this lane are only `tools/package_release.py` and this report; web/README changes were frozen in the earlier lane and not touched during native packaging.

The binary remains unsigned Alpha software. Root owns final rendered/native review as needed and the release upload; this report supplies a ready local artifact and checksum, without claiming public publication.
