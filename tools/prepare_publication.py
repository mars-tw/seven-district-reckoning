"""Normalize published documentation paths and register the current alpha state."""
import hashlib
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
prefixes = {str(root), root.as_posix(), json.dumps(str(root), ensure_ascii=False)[1:-1]}
skip_parts = {".git", ".godot", "__pycache__", "downloads", "local", "deliverables"}
extensions = {".md", ".json", ".html", ".py", ".gd", ".tscn", ".godot", ".yml", ".txt", ".cfg"}
count = 0
for path in root.rglob("*"):
    if not path.is_file() or path.suffix not in extensions or any(p in skip_parts for p in path.relative_to(root).parts):
        continue
    if path.name in {"prepare_publication.py", "delivery-result.json", "delivery-manifest.json", "localize_draft.py", "refine_tickets.py"}:
        continue
    try:
        old = path.read_text(encoding="utf-8-sig")
    except UnicodeError:
        continue
    new = old
    for prefix in sorted(prefixes, key=len, reverse=True):
        new = new.replace(prefix, ".")
    # Cache locations in review prose are local evidence locations, not build dependencies.
    new = re.sub(r"[A-Za-z]:[/\\]Users[/\\][^/\\\s]+[/\\]\.cache[/\\]seven-district-tools[/\\][^\s`\"<>]+", "<local-tool-cache>", new)
    if path.suffix == ".md":
        new = new.replace("C:/Program Files/Blender Foundation/Blender 5.2/blender.exe", "BLENDER_BIN")
    if new != old:
        path.write_text(new, encoding="utf-8")
        count += 1
scope_path = root / "planning/project-scope.json"
scope = json.loads(scope_path.read_text(encoding="utf-8"))
scope.update({"document_status": "HistoricalPlanningBaseline", "game_status": "PlayableAlpha0.1.0",
              "engine": "Godot 4.7.2 stable", "asset_tool": "Blender 5.2.0 LTS", "production_started": True})
scope_path.write_text(json.dumps(scope, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
font = root / "godot/assets/fonts/NotoSansTC-Regular.otf"
ledger = {"name": "Noto Sans TC Regular", "author": "Adobe / Noto contributors", "copyright": "Copyright 2014-2021 Adobe",
    "license": "OFL-1.1", "license_file": "godot/assets/fonts/OFL.txt",
    "source_url": "https://github.com/notofonts/noto-cjk", "source_commit": "f8d157532fbfaeda587e826d4cd5b21a49186f7c",
    "download_url": "https://raw.githubusercontent.com/notofonts/noto-cjk/f8d157532fbfaeda587e826d4cd5b21a49186f7c/Sans/SubsetOTF/TC/NotoSansTC-Regular.otf",
    "sha256": hashlib.sha256(font.read_bytes()).hexdigest()}
(root / "assets/provenance/font-source.json").write_text(json.dumps(ledger, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("Normalized", count, "public text files; font source registered.")
