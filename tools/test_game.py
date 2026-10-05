"""Import a clean isolated project and validate baseline plus Taiwan/device suites."""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SUITES = [
    ("mission_contract.gd", "ALPHA_CONTRACT_CHECKS="),
    ("controls.gd", "CONTROL_CHECKS="),
    ("guard_persistence.gd", "GUARD_SAVE_CHECKS="),
    ("release_regressions.gd", "RELEASE_REVIEW_RESULT "),
    ("optional_content.gd", "Optional content: "),
    ("district_life.gd", "CITY_LIFE_RESULT "),
    ("v02_integration.gd", "V02_INTEGRATION_RESULT "),
    ("district_systems.gd", "DISTRICT_SYSTEMS_RESULT "),
    ("v03_integration.gd", "V03_INTEGRATION_RESULT "),
    ("urban_detail.gd", "URBAN_SUMMARY "),
    ("taiwan_life.gd", "TAIWAN_LIFE_RESULT "),
    ("taiwan_expansion.gd", "TAIWAN_MAP_RESULT "),
    ("device_profiles.gd", "DEVICE_PROFILE_CHECKS="),
    ("v04_integration.gd", "V04_INTEGRATION_RESULT "),
    ("taiwan_activities.gd", "TAIWAN_ACTIVITY_CHECKS="),
]
JS_SUITES = [("device_web.mjs", "DEVICE_WEB_CHECKS=")]
JS_SUPPORT = ["prepare_web_assets.mjs", "verify_web.mjs"]


def summary(output, marker):
    """Require the suite's real final record; never infer PASS from quiet output."""
    records = [line[len(marker):] for line in output.splitlines() if line.startswith(marker)]
    if len(records) != 1:
        raise ValueError(f"Expected exactly one {marker.strip()} summary, received {len(records)}")
    record = records[0]
    if marker.endswith("CHECKS="):
        match = re.fullmatch(r"(\d+) FAILURES=(\d+)", record)
        if not match:
            raise ValueError("Malformed numbered suite summary")
        return int(match[1]), int(match[2])
    if marker == "Optional content: ":
        match = re.fullmatch(r"(\d+) checks, (\d+) failures", record)
        if not match:
            raise ValueError("Malformed optional-content summary")
        return int(match[1]), int(match[2])
    data = json.loads(record)
    if marker == "INTEGRATION_PASS ":
        if not isinstance(data, list) or not data:
            raise ValueError("Missing gameplay integration groups")
        return len(data), 0
    if marker == "URBAN_SUMMARY ":
        if not isinstance(data, dict):
            raise ValueError("Malformed urban-detail summary")
        passed, failed = data.get("passed"), data.get("failed")
        if any(not isinstance(value, int) or isinstance(value, bool) or value < 0 for value in (passed, failed)):
            raise ValueError("Invalid urban-detail check counts")
        return passed + failed, failed
    if not isinstance(data, dict) or not isinstance(data.get("failures"), list):
        raise ValueError("Malformed structured suite summary")
    passed = data.get("passed_count", data.get("passed", []))
    if isinstance(passed, list):
        passed = len(passed)
    if not isinstance(passed, int) or isinstance(passed, bool) or passed < 0:
        raise ValueError("Invalid suite check count")
    return passed + len(data["failures"]), len(data["failures"])


def save_slots(sandbox):
    """Audit only the isolated run. Never inspect the player's real save directory."""
    paths = list(sandbox.rglob("save*.json*"))
    slots = []
    for path in paths:
        match = re.fullmatch(r"save(\d+)\.json(?:\.bak|\.tmp)?", path.name)
        if not match or not 91 <= int(match[1]) <= 98:
            raise ValueError(f"Unexpected save outside test slots 91-98: {path.name}")
        slots.append(path.name)
    return sorted(set(slots))


def disable_parallel_import(text):
    section = re.search(r"(?ms)^\[editor\]\r?\n(?P<body>.*?)(?=^\[|\Z)", text)
    setting = "import/use_multiple_threads=false"
    if section:
        body, found = re.subn(r"(?m)^import/use_multiple_threads\s*=.*$", setting, section["body"])
        if not found:
            body = body.rstrip("\r\n") + "\n" + setting + "\n"
        return text[:section.start("body")] + body + text[section.end("body"):]
    return text.rstrip("\r\n") + "\n\n[editor]\n" + setting + "\n"


def source_fingerprint(project, fixtures=None, web=None, support=None):
    """Identify the tested source/config and fixtures, excluding generated import caches."""
    files = [("godot/" + path.relative_to(project).as_posix(), path)
             for path in project.rglob("*")
             if path.is_file() and not any(part in {".godot", "_checks"} for part in path.relative_to(project).parts)
             and (path.suffix in {".gd", ".gdshader", ".gdshaderinc", ".json", ".tscn", ".cfg"}
                  or path.name == "project.godot")]
    fixtures = fixtures or ROOT / "tests"
    web = web or ROOT / "web"
    files.extend(("tests/" + path.relative_to(fixtures).as_posix(), path)
                 for path in fixtures.rglob("*") if path.is_file() and path.suffix in {".gd", ".mjs"})
    files.extend(("web/" + path.relative_to(web).as_posix(), path)
                 for path in web.rglob("*") if path.is_file() and path.suffix in {".html", ".css", ".js"})
    support = support or ROOT / "tools"
    files.extend(("tools/" + name, support / name) for name in JS_SUPPORT)
    digest = hashlib.sha256()
    for label, path in sorted(files):
        digest.update(label.encode("utf-8") + b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return {"algorithm": "sha256", "scope": "Godot source/config, GDScript/JS fixtures, web shell and imported web build/verification helpers; excludes binary art/import caches",
            "file_count": len(files), "digest": digest.hexdigest()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--import-only", action="store_true")
    parser.add_argument("--node", default=os.environ.get("NODE_BIN", "node"))
    parser.add_argument("--suite", action="append", choices=["gameplay_integration"] + [Path(name).stem for name, _ in SUITES + JS_SUITES],
                        help="Run selected suites after a clean import; repeat to select more than one")
    args = parser.parse_args()
    if sys.platform != "win32" and not sys.platform.startswith("linux"):
        parser.error("Isolated test user-data is supported on Windows and Linux")
    results = []
    with tempfile.TemporaryDirectory(prefix="seven-district-tests-") as directory:
        sandbox = Path(directory)
        project = sandbox / "godot"
        # A clean source snapshot avoids racing the working project's editor/export cache.
        shutil.copytree(ROOT / "godot", project, ignore=shutil.ignore_patterns(".godot", "_checks"))
        fixtures, web = sandbox / "tests", sandbox / "web"
        shutil.copytree(ROOT / "tests", fixtures)
        shutil.copytree(ROOT / "web", web)
        support = sandbox / "tools"
        support.mkdir()
        for name in JS_SUPPORT:
            shutil.copy2(ROOT / "tools" / name, support / name)
        # World fixtures may write scoped reports beside res://. Keep these
        # disposable reports inside the run rather than the checked-out project.
        (sandbox / "qa").mkdir()
        fingerprint = source_fingerprint(project, fixtures, web, support)
        project_settings = project / "project.godot"
        project_settings.write_text(disable_parallel_import(project_settings.read_text(encoding="utf-8")), encoding="utf-8")
        child_env = os.environ.copy()
        for name in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
            path = sandbox / name.lower()
            path.mkdir()
            child_env[name] = str(path)
        base = [args.godot, "--headless", "--language", "en", "--path", str(project)]
        commands = [("godot_import_parse", base + ["--editor", "--import", "--quit"], None)]
        if not args.import_only:
            selected = set(args.suite) if args.suite else None
            if selected is None or "gameplay_integration" in selected:
                commands.append(("gameplay_integration", base + ["--quit-after", "900", "--", "--self-test"], "INTEGRATION_PASS "))
            commands.extend((Path(name).stem, base + ["--script", str(fixtures / name)], marker)
                            for name, marker in SUITES if selected is None or Path(name).stem in selected)
            commands.extend((Path(name).stem, [args.node, str(fixtures / name)], marker)
                            for name, marker in JS_SUITES if selected is None or Path(name).stem in selected)
        for label, cmd, marker in commands:
            errors = []
            check_count = 0
            failure_count = 0
            returncode = None
            try:
                proc = subprocess.run(cmd, cwd=sandbox, env=child_env, capture_output=True, text=True,
                                      encoding="utf-8", errors="replace", timeout=180)
                output = proc.stdout + proc.stderr
                returncode = proc.returncode
                if returncode != 0:
                    errors.append(f"Godot exited with {returncode}")
                if re.search(r"SCRIPT ERROR:|Parse Error:|ERROR:|INTEGRATION_FAIL|^FAIL:", output, re.MULTILINE):
                    errors.append("Engine or test error was reported")
                if marker:
                    try:
                        check_count, failure_count = summary(output, marker)
                        if failure_count:
                            errors.append(f"Suite reported {failure_count} failures")
                    except (ValueError, TypeError) as exc:
                        errors.append(str(exc))
            except subprocess.TimeoutExpired as exc:
                # Preserve the engine evidence preceding a stalled fixture. The
                # command is already recorded structurally below; repr(cmd) would
                # obscure path sanitization by doubling Windows backslashes.
                partials = [exc.stdout or "", exc.stderr or ""]
                output = "".join(value.decode("utf-8", errors="replace") if isinstance(value, bytes) else value
                                 for value in partials)
                output += f"\nTimeoutExpired: command did not finish within {exc.timeout} seconds"
                errors.append("Godot could not complete this command")
            except OSError as exc:
                output = f"{type(exc).__name__}: {exc}"
                errors.append("Godot could not complete this command")
            try:
                slots = save_slots(sandbox)
            except ValueError as exc:
                slots = []
                errors.append(str(exc))
            cleaned = output
            for path, replacement in ((ROOT, "<repository-root>"), (sandbox, "<isolated-run>")):
                cleaned = cleaned.replace(str(path), replacement).replace(path.as_posix(), replacement)
            if Path(args.godot).is_absolute():
                cleaned = cleaned.replace(args.godot, "<godot>").replace(Path(args.godot).as_posix(), "<godot>")
            executable = "<node>" if label in {Path(name).stem for name, _ in JS_SUITES} else "<godot>"
            command = [executable] + [arg.replace(str(ROOT), "<repository-root>").replace(str(sandbox), "<isolated-run>") for arg in cmd[1:]]
            entry = {"check": label, "status": "FAIL" if errors else "PASS", "returncode": returncode,
                     "source_fingerprint": fingerprint,
                     "reported_checks": check_count, "reported_failures": failure_count,
                     "command": command, "test_slot_files": slots, "errors": errors, "output": cleaned[-16000:]}
            results.append(entry)
            print(f"{label}: {entry['status']} ({check_count} reported checks, {failure_count} reported failures)", flush=True)
            if errors:
                print(cleaned[-16000:], flush=True)
                print("; ".join(errors), flush=True)
            if label == "godot_import_parse" and errors:
                break
    (ROOT / "qa").mkdir(exist_ok=True)
    report_path = ROOT / ("qa/engine-checks-incremental.json" if args.suite else "qa/engine-checks.json")
    report_path.write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if len(results) != len(commands) or any(item["status"] != "PASS" for item in results):
        return 1
    total = sum(item["reported_checks"] for item in results)
    print(f"ENGINE_CHECKS_PASS suites={len(results) - 1} reported_checks={total} failures=0", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
