"""Run meaningful engine checks and require an explicit integration PASS marker."""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
parser.add_argument("--import-only", action="store_true")
args = parser.parse_args()
commands = [[args.godot, "--headless", "--language", "en", "--path", str(root / "godot"), "--editor", "--import", "--quit"]]
if not args.import_only:
    commands.append([args.godot, "--headless", "--language", "en", "--path", str(root / "godot"), "--quit-after", "900", "--", "--self-test"])
    for name in ["mission_contract.gd", "controls.gd", "guard_persistence.gd", "release_regressions.gd"]:
        commands.append([args.godot, "--headless", "--language", "en", "--path", str(root / "godot"), "--script", str(root / "tests" / name)])
results = []
for i, cmd in enumerate(commands):
    proc = subprocess.run(cmd, cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180)
    output = proc.stdout + proc.stderr
    cleaned = output.replace(str(root), "<repository-root>").replace(str(root).replace("\\", "/"), "<repository-root>")
    failed = proc.returncode != 0 or "SCRIPT ERROR:" in output or "Parse Error:" in output or "INTEGRATION_FAIL" in output
    if i == 1 and "INTEGRATION_PASS" not in output:
        failed = True
    if i > 1 and ("FAILURES=0" not in output and '"failures":[]' not in output and '"failures": []' not in output):
        failed = True
    label = "godot_import_parse" if i == 0 else ("gameplay_integration" if i == 1 else Path(cmd[-1]).stem)
    entry = {"check": label,
             "status": "FAIL" if failed else "PASS", "returncode": proc.returncode,
             "output": cleaned[-16000:]}
    results.append(entry)
    print(cleaned[-16000:])
    if failed:
        break
(root / "qa").mkdir(exist_ok=True)
(root / "qa/engine-checks.json").write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
if len(results) != len(commands) or any(x["status"] != "PASS" for x in results):
    sys.exit(1)
print("ENGINE_CHECKS_PASS")
