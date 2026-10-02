"""Build the offline planning overview using only the standard library."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
data = {}
for key, name in {"tickets": "planning/tickets.json",
                  "missions": "docs/missions.json",
                  "assets": "docs/asset-register.json",
                  "scope": "planning/project-scope.json"}.items():
    data[key] = json.loads((root / name).read_text(encoding="utf-8-sig"))
payload = json.dumps(data, ensure_ascii=False).replace("<", "\\u003c")
template = (root / "planning/overview.template.html").read_text(encoding="utf-8")
assert template.count("__PLAN_DATA__") == 1
(root / "index.html").write_text(template.replace("__PLAN_DATA__", payload), encoding="utf-8")
print("Built offline planning overview.")
