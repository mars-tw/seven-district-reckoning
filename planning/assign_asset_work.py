"""Assign every planned asset to exactly one art ticket and include its paths."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
tp = root / "planning/tickets.json"
ap = root / "docs/asset-register.json"
tdata = json.loads(tp.read_text(encoding="utf-8-sig"))
assets = json.loads(ap.read_text(encoding="utf-8-sig"))["assets"]
index = {t["id"]: t for t in tdata["tickets"]}
assigned = {}
for a in assets:
    if a["phase"] == "Slice":
        if a["category"] in {"characters", "animations"} or a["id"] == "ASSET-062":
            owner = "TASK-024"
        elif a["category"] == "vehicles":
            owner = "TASK-026"
        elif a["category"] in {"weapons", "props", "destructibles", "vfx"}:
            owner = "TASK-027"
        else:
            owner = "TASK-025"
    elif a["category"] in {"vehicles", "weapons", "animations"}:
        owner = "TASK-040"
    elif a["category"] in {"buildings", "interiors"}:
        owner = "TASK-043"
    elif a["category"] == "characters":
        owner = "TASK-035"
    else:
        owner = "TASK-041"
    assigned.setdefault(owner, []).append(a["id"])
    t = index[owner]
    for p in [a["source_path"], a["export_path"]]:
        directory = str(Path(p).parent).replace("\\", "/") + "/"
        if directory not in t["output_paths"]:
            t["output_paths"].append(directory)
for t in tdata["tickets"]:
    t["asset_ids"] = assigned.get(t["id"], [])
tp.write_text(json.dumps(tdata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("Assigned", sum(map(len, assigned.values())), "assets to", len(assigned), "art tickets.")
