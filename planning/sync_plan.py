"""Regenerate implementation table rows from tickets.json; preserve prose."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
tickets = json.loads((root / "planning/tickets.json").read_text(encoding="utf-8-sig"))["tickets"]
plan_path = root / "plan/design-game-production-1.md"
plan = plan_path.read_text(encoding="utf-8")
for t in tickets:
    deps = "、".join(t["depends_on"]) if t["depends_on"] else "無"
    paths = "、".join("`" + p + "`" for p in t["output_paths"])
    days = t["estimate_person_days"]
    assets = "資產：" + "、".join(t.get("asset_ids", [])) + "。" if t.get("asset_ids") else ""
    text = (f"| {t['id']} | **{t['title']}**。角色：{t['owner_role']}；{t['priority']}；"
            f"{days['min']}～{days['max']}人日。依賴：{deps}。輸出：{paths}。"
            f"{assets}執行：{t['description']}驗收：{t['acceptance']} | 未開始 | 尚未執行 |")
    pattern = rf"^\| {re.escape(t['id'])} \|.*$"
    plan, count = re.subn(pattern, lambda _: text, plan, flags=re.MULTILINE)
    assert count == 1, f"Expected one declaration: {t['id']}"
plan_path.write_text(plan, encoding="utf-8")
print(f"Synced {len(tickets)} ticket rows.")
