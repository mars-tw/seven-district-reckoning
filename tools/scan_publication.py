"""Scan prospective tracked files without printing secret values."""
import json
import re
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
patterns = [
    ("private_absolute_path", re.compile(r"[A-Za-z]:[/\\\\]Users[/\\\\][^/\\\\\s\"']+[/\\\\]", re.I)),
    ("private_key", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
    ("api_token", re.compile(r"(?:sk-(?:proj-|sp-|ws-)?[A-Za-z0-9_.-]{28,}|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})")),
    ("oauth_token", re.compile(r"(?:1//[A-Za-z0-9_-]{35,}|AQX[A-Za-z0-9_-]{100,})")),
]
proc = subprocess.run(["git", "ls-files", "-z"], cwd=root, capture_output=True, check=True)
files = [root / x for x in proc.stdout.decode("utf-8").split("\0") if x]
findings = []
for path in files:
    if path.suffix.lower() in {".blend", ".glb", ".png", ".otf", ".wav", ".zip"}:
        continue
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeError:
        continue
    for label, pattern in patterns:
        for match in pattern.finditer(text):
            findings.append({"file": path.relative_to(root).as_posix(), "line": text.count("\n", 0, match.start()) + 1, "type": label})
result = {"status": "PASS" if not findings else "FAIL", "tracked_files": len(files), "findings": findings}
print(json.dumps(result, ensure_ascii=False, indent=2))
if findings:
    raise SystemExit(1)
