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
def scan_text(path, text):
    findings = []
    for label, pattern in patterns:
        for match in pattern.finditer(text):
            # A generated Godot import reference contains a filename and MD5,
            # not an API value. In dusk-sky, the substring sk-sky triggered the
            # broad token detector. Require the exact source filename, field,
            # cache directory, hash length and whole line before classifying it.
            line = text[text.rfind("\n", 0, match.start()) + 1:text.find("\n", match.end()) if "\n" in text[match.end():] else len(text)]
            if label == "api_token" and path.suffix == ".import":
                source_name = re.escape(path.name.removesuffix(".import"))
                reference = r'"res://\.godot/imported/' + source_name + r'-[a-f0-9]{32}\.ctex"'
                if re.fullmatch(r'(?:path=' + reference + r'|dest_files=\[' + reference + r'\])', line):
                    continue
            findings.append({"file": path.relative_to(root).as_posix(), "line": text.count("\n", 0, match.start()) + 1, "type": label})
    return findings

def main():
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
        findings.extend(scan_text(path, text))
    result = {"status": "PASS" if not findings else "FAIL", "tracked_files": len(files), "findings": findings}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if findings else 0

if __name__ == "__main__":
    raise SystemExit(main())
