"""Check the R4.1 actual screenshots and their layout/provenance records."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
NAMES = {"title", "dialogue", "dialogue-meiqing", "street", "evidence", "link", "sealed"}
SIZES = {(1290, 2796), (2064, 2752), (430, 932), (390, 844), (1376, 1032)}


def verify():
    issues, records, packages = [], [], set()
    for folder, expected in [("docs/store/screenshots", {(1290, 2796), (2064, 2752)}),
                             ("docs/art/compare/after", SIZES)]:
        directory = ROOT / folder
        manifest = json.loads((directory / "manifest.json").read_text(encoding="utf-8"))
        if manifest["status"] != "VERIFIED" or manifest["version"] != "0.8.1":
            issues.append(folder + ": status/version")
        packages.add(manifest["pck_sha256"])
        sizes = set()
        for view in manifest["views"]:
            size = (view["pixels"]["width"], view["pixels"]["height"])
            sizes.add(size)
            tag = f"{size[0]}x{size[1]}-"
            names = {shot["file"].removeprefix(tag).removesuffix(".png") for shot in view["shots"]}
            if names != NAMES:
                issues.append(tag + "missing/extra capture state")
            if view["logs"] or view["blocked_remote_origins"]:
                issues.append(tag + "browser errors/remote requests")
            if "NVIDIA" not in view["game_renderer"] or "SwiftShader" in view["game_renderer"]:
                issues.append(tag + "hardware renderer")
            if len(view["reopen_checks"]) != 3 or any(not row["stable"] or row["resize"] > 4 or row["sorts"] > 24 for row in view["reopen_checks"]):
                issues.append(tag + "repeated open convergence")
            for shot in view["shots"]:
                file = directory / shot["file"]
                digest = hashlib.sha256(file.read_bytes()).hexdigest()
                with Image.open(file) as image:
                    actual_size = image.size
                state = shot["state"]
                if actual_size != size or digest != shot["sha256"] or state["version"] != "0.8.1":
                    issues.append(shot["file"] + ": PNG size/hash/source")
                if state["layout"]["peak_sorts_per_frame"] > 32:
                    issues.append(shot["file"] + ": unbounded layout")
                name = shot["file"].removeprefix(tag).removesuffix(".png")
                if name in {"evidence", "link", "sealed"}:
                    if state["menu"] != "case" or not state["layout"]["case_gutter_reserved"]:
                        issues.append(shot["file"] + ": case state")
                    if state["case_stage"] != (4 if name == "sealed" else 2):
                        issues.append(shot["file"] + ": evidence progression")
                records.append({"path": file.relative_to(ROOT).as_posix(), "sha256": digest, "size": size})
            if folder.startswith("docs/store"):
                for shot in view["shots"]:
                    other = ROOT / "docs/art/compare/after" / shot["file"]
                    if other.read_bytes() != (directory / shot["file"]).read_bytes():
                        issues.append(shot["file"] + ": comparison/store mismatch")
        if sizes != expected:
            issues.append(folder + ": missing/extra viewport")
    if len(packages) != 1:
        issues.append("Screenshot packages differ")
    manifest = json.loads((ROOT / "godot/assets/art/r4/manifest.json").read_text(encoding="utf-8"))
    for record in manifest["outputs"]:
        if not (ROOT / (record["path"] + ".import")).is_file():
            issues.append(record["path"] + ": missing import")
    if not (ROOT / "godot/scripts/ui/art_theme.gd.uid").is_file():
        issues.append("art_theme UID missing")
    return {"status": "VERIFIED" if not issues else "BLOCKED", "issues": issues,
            "version": "0.8.1", "pck_sha256": sorted(packages), "checked_png_copies": len(records), "files": records}


if __name__ == "__main__":
    result = verify()
    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(0 if result["status"] == "VERIFIED" else 1)
