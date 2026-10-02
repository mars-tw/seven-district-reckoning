"""Package the already-exported Windows binary with required license notices."""
import hashlib
import json
import shutil
import struct
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
directory = root / "deliverables/windows"
executable = directory / "SevenDistrict.exe"
assert executable.exists() and executable.stat().st_size > 20_000_000
image = root / "docs/evidence/alpha-packaged-windows.png"
assert image.exists() and image.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n", "Packaged executable must produce a real screenshot first"
for name in ["LICENSE", "LICENSE-ASSETS.md", "CREDITS.md"]:
    shutil.copy2(root / name, directory / name)
licenses = directory / "licenses"
licenses.mkdir(exist_ok=True)
for path in (root / "assets/provenance").glob("*.txt"):
    shutil.copy2(path, licenses / path.name)
shutil.copy2(root / "godot/assets/fonts/OFL.txt", licenses / "NotoSansTC-OFL.txt")
(directory / "PLAY.txt").write_text(
    "Seven District: Break the Chain - Alpha 0.1.0\n"
    "Run SevenDistrict.exe. Godot and Blender are not needed to play.\n"
    "WASD move; Shift sprint; mouse look; left-click attack; E interact; F mount/dismount;\n"
    "Q switch tool; Space jump/brake; R recover vehicle; Tab missions; Esc pause; F5/F9 save/load.\n"
    "This is a first-chapter alpha, not the complete six-zone MVP.\n"
    "Source: https://github.com/mars-tw/seven-district-reckoning\n", encoding="utf-8")
archive = root / "deliverables/SevenDistrict-v0.1.0-Windows-x86_64.zip"
files = [p for p in directory.rglob("*") if p.is_file()]
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
    for path in files:
        z.write(path, (Path("SevenDistrict-Alpha-0.1.0") / path.relative_to(directory)).as_posix())
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
result = {"scope": "windows-alpha-package", "status": "VERIFIED",
          "exe_bytes": executable.stat().st_size, "exe_sha256": hashlib.sha256(executable.read_bytes()).hexdigest(),
          "archive": archive.relative_to(root).as_posix(), "archive_bytes": archive.stat().st_size,
          "archive_sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
          "packaged_screenshot_dimensions": list(struct.unpack(">II", image.read_bytes()[16:24])),
          "model_exports": len(list((root / "godot/assets/models").glob("*.glb"))), "version": "0.1.0"}
(root / "qa/windows-package.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
(root / "deliverables/SHA256SUMS.txt").write_text(result["archive_sha256"] + "  " + archive.name + "\n", encoding="utf-8")
print(json.dumps(result, indent=2))
