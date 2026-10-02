"""Normalize report labels without rerunning unchanged engine measurements."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
for number in range(1, 4):
    path = root / f"qa/profile-run-{number}.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    if "game_ram_bytes" in data:
        data["godot_static_memory_bytes"] = data.pop("game_ram_bytes")
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
for name in ["README.md", "docs/alpha-validation.md"]:
    path = root / name
    text = path.read_text(encoding="utf-8")
    for old, new in {"结局": "結局", "独立": "獨立", "70项": "70項", "後续": "後續", "L\u200b\u200bOD": "LOD"}.items():
        text = text.replace(old, new)
    path.write_text(text, encoding="utf-8")
print("Normalized publication report labels.")
