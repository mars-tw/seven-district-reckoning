"""Package the finished planning documents; exclude caches and draft helpers."""
import hashlib
import json
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
archive = root.parent / "seven-district-reckoning-planning-20261002.zip"
required = ["README.md", "index.html", "docs/planning-review.md",
            "planning/validation-result.json"]
for name in required:
    assert (root / name).is_file(), f"Required delivery file missing: {name}"
excluded_names = {"localize_draft.py", "refine_tickets.py", "delivery-result.json", "delivery-manifest.json"}
files = [p for p in root.rglob("*") if p.is_file()
         and "__pycache__" not in p.parts and p.suffix != ".pyc"
         and not any(part in {".git", ".godot", ".audit-tmp", "downloads", "deliverables", "local"} for part in p.relative_to(root).parts)
         and p.relative_to(root).parts[0] in {"docs", "plan", "planning", "spec", "README.md", "index.html"}
         and p.name not in excluded_names]
manifest = {"date": "2026-10-02", "scope": "planning-only", "files": []}
for p in sorted(files):
    raw = p.read_bytes()
    manifest["files"].append({"path": p.relative_to(root).as_posix(),
                              "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()})
mp = root / "planning/delivery-manifest.json"
mp.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
files.append(mp)
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
    for p in sorted(files):
        z.write(p, (Path(root.name) / p.relative_to(root)).as_posix())
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None, "Archive CRC failure"
    assert len(z.namelist()) == len(files)
    for row in manifest["files"]:
        raw = z.read(root.name + "/" + row["path"])
        assert hashlib.sha256(raw).hexdigest() == row["sha256"]
result = {"status": "VERIFIED", "scope": "planning-package-only",
          "archive": str(archive), "files": len(files), "bytes": archive.stat().st_size,
          "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
          "cache_and_draft_helpers_excluded": True, "game_build_included": False}
(root / "planning/delivery-result.json").write_text(
    json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(result, ensure_ascii=True, indent=2))
