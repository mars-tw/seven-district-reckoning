"""Validate planning data only; does not assert any game has been implemented."""
from __future__ import annotations
import json
import math
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def read_json(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8-sig"))

def records(value, preferred):
    if isinstance(value, list):
        return value
    for key in preferred:
        if key in value and isinstance(value[key], list):
            return value[key]
    raise AssertionError(f"Missing record list: {preferred}")

def unique(items, label):
    ids = [row["id"] for row in items]
    assert len(ids) == len(set(ids)), f"Duplicate IDs: {label}"
    return {row["id"]: row for row in items}

def assert_dag(items, label):
    index = unique(items, label)
    visited, active = set(), set()
    def visit(key):
        assert key in index, f"Unknown dependency: {label} {key}"
        assert key not in active, f"Dependency cycle: {label} {key}"
        if key in visited:
            return
        active.add(key)
        for dep in index[key].get("depends_on", []):
            visit(dep)
        active.remove(key)
        visited.add(key)
    for key in index:
        visit(key)
    return index

def check_relative(path):
    p = Path(path)
    assert not p.is_absolute() and ".." not in p.parts, f"Unsafe planned path: {path}"
    assert not re.match(r"^[A-Za-z]:", path), f"Drive in planned relative path: {path}"

scope = read_json("planning/project-scope.json")
tickets = records(read_json("planning/tickets.json"), ["tickets"])
missions_data = read_json("docs/missions.json")
missions = records(missions_data, ["missions"])
assets_data = read_json("docs/asset-register.json")
assets = records(assets_data, ["assets"])
assert len(tickets) == 50
ticket_index = assert_dag(tickets, "tickets")
assert set(ticket_index) == {f"TASK-{i:03}" for i in range(1, 51)}
assert Counter(t["phase"] for t in tickets) == {"Slice": 33, "MVP": 14, "Future": 3}
rank = {"Slice": 0, "MVP": 1, "Future": 2}
for t in tickets:
    assert t["status"] == "Planned", f"False implementation status: {t['id']}"
    assert t["priority"] in {"P0", "P1", "P2", "P3"}
    assert t["estimate_person_days"]["min"] > 0
    assert t["estimate_person_days"]["max"] >= t["estimate_person_days"]["min"]
    for dep in t["depends_on"]:
        assert rank[ticket_index[dep]["phase"]] <= rank[t["phase"]]
    for p in t["output_paths"]:
        check_relative(p)

mission_index = assert_dag(missions, "missions")
expected = {f"MAIN-{i:03}" for i in range(1, 13)}
expected |= {f"SIDE-{i:03}" for i in range(1, 13)}
expected |= {f"ACT-{i:03}" for i in range(1, 9)}
assert set(mission_index) == expected
slice_ids = {m["id"] for m in missions if m["phase"] == "Slice"}
assert slice_ids == {f"MAIN-{i:03}" for i in range(1, 6)}
required_mission = {"id", "type", "title", "line_id", "phase", "location",
                    "depends_on", "objectives", "fail_conditions", "rewards"}
for m in missions:
    assert required_mission <= m.keys(), f"Mission fields missing: {m['id']}"
    assert m["phase"] in rank
    for dep in m["depends_on"]:
        assert rank[mission_index[dep]["phase"]] <= rank[m["phase"]]
    assert len(m["objectives"]) > 0
asset_index = unique(assets, "assets")
assert len(assets) == 70
assert Counter(a["phase"] for a in assets) == {"Slice": 55, "MVP": 15}
mapping = assets_data["character_asset_mapping"]
assert set(mapping) == {"CHAR-PLAYER", "CHAR-MEI", "CHAR-YU", "CHAR-CHENG", "CHAR-AUNT", "CHAR-LIAO", "CHAR-CAPTAIN"}
owned_assets = [aid for t in tickets for aid in t.get("asset_ids", [])]
assert len(owned_assets) == len(set(owned_assets)) == len(assets)
assert set(owned_assets) == set(asset_index), "Asset assignment incomplete"
for t in tickets:
    for aid in t.get("asset_ids", []):
        a = asset_index[aid]
        assert t["phase"] == a["phase"], f"Asset phase mismatch: {aid}"
        for key in ["source_path", "export_path"]:
            assert any(a[key].startswith(p) for p in t["output_paths"]), f"Asset output missing: {aid} {key}"
for a in assets:
    assert a["status"] == "Planned", f"False asset status: {a['id']}"
    assert a["phase"] in rank
    for p in [a["source_path"], a["export_path"]]:
        check_relative(p)
    assert a["source_path"].startswith("assets/source/blender/")
    assert a["export_path"].startswith(("godot/assets/models/", "godot/assets/textures/"))
    assert a.get("license"), f"License proposal missing: {a['id']}"
    for dep in a.get("dependencies", []):
        assert dep in asset_index, f"Asset dependency missing: {dep}"
assert_dag([dict(a, depends_on=a.get("dependencies", [])) for a in assets], "assets")
for a in assets:
    for dep in a.get("dependencies", []):
        assert rank[asset_index[dep]["phase"]] <= rank[a["phase"]]

plan = (ROOT / "plan/design-game-production-1.md").read_text(encoding="utf-8")
plan_sections = ["# Introduction", "## 1. Requirements & Constraints",
"## 2. Implementation Steps", "## 3. Alternatives", "## 4. Dependencies",
"## 5. Files", "## 6. Testing", "## 7. Risks & Assumptions",
"## 8. Related Specifications / Further Reading"]
for header in plan_sections:
    assert header in plan, f"Missing plan section: {header}"
decls = re.findall(r"^\| (TASK-\d+) \|", plan, re.M)
bullet_ids = re.findall(r"^- \*\*([A-Z]+-\d+)\*\*[：:]", plan, re.M)
assert len(decls) == 50 and len(set(decls)) == 50
assert len(bullet_ids) == len(set(bullet_ids)), "Duplicate bullet declarations"
spec = (ROOT / "spec/spec-design-game-systems.md").read_text(encoding="utf-8")
for number, name in enumerate(["Purpose & Scope", "Definitions",
"Requirements, Constraints & Guidelines", "Interfaces & Data Contracts",
"Acceptance Criteria", "Test Automation Strategy", "Rationale & Context",
"Dependencies & External Integrations", "Examples & Edge Cases",
"Validation Criteria", "Related Specifications / Further Reading"], 1):
    assert f"## {number}. {name}" in spec
summary = {"status": "VERIFIED", "verification_scope": "planning-static-only",
           "game_status": "NotStarted", "tickets": len(tickets),
           "missions": len(missions), "assets": len(assets), "character_mappings": len(mapping),
           "asset_phases": dict(Counter(a["phase"] for a in assets)), "effort_person_days": {}}
for phase in rank:
    selected = [t for t in tickets if t["phase"] == phase]
    lo = sum(t["estimate_person_days"]["min"] for t in selected)
    hi = sum(t["estimate_person_days"]["max"] for t in selected)
    summary["effort_person_days"][phase] = {
        "min": lo, "max": hi,
        "buffered_min": math.ceil(lo * 1.25), "buffered_max": math.ceil(hi * 1.25)}
assert scope["phases"]["MVP"]["counts_include_slice"] is True
assert len(missions_data["lines"]) == 5 and len(missions_data["zones"]) == 6
for key, value in scope["default_scores"].items():
    assert missions_data["state_contract"][key]["initial"] == value
rules = sorted(missions_data["ending_rules"], key=lambda x: x["priority"])
assert len(rules) == 3 and sum(bool(r.get("fallback")) for r in rules) == 1
assert rules[-1].get("fallback") is True
def resolve(evidence, trust, rescued):
    state = {"evidence_score": evidence, "community_trust": trust, "rescued_count": rescued}
    for rule in rules:
        if rule.get("fallback"):
            return rule["id"]
        matches = []
        for key, value in rule["all_of"].items():
            if key.endswith("_gte"):
                matches.append(state[key[:-4]] >= value)
            elif key.endswith("_lt"):
                matches.append(state[key[:-3]] < value)
            else:
                raise AssertionError(f"Unsupported ending operator: {key}")
        if all(matches):
            return rule["id"]
assert resolve(90, 69, 8) == "END-001"
assert resolve(22, 33, 8) == "END-003"
assert resolve(54, 69, 8) == "END-002"
for e in [0, 39, 40, 69, 70, 100]:
    for t in [0, 34, 35, 59, 60, 100]:
        for r in [0, 7, 8, 9, 10, 20]:
            assert resolve(e, t, r) in {"END-001", "END-002", "END-003"}
summary["ending_boundary_cases"] = 216
print(json.dumps(summary, ensure_ascii=False, indent=2))
(ROOT / "planning/validation-result.json").write_text(
    json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

