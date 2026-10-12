"""Export unsigned native projects and verify real artifacts; no store operations."""
import argparse
import hashlib
import json
import os
import pathlib
import platform
import plistlib
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]


def run(arguments, log=None, timeout=900, env=None):
    result = subprocess.run([str(a) for a in arguments], capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=timeout, env=env, cwd=ROOT)
    output = result.stdout + result.stderr
    if log:
        log.write_text(output, encoding="utf-8")
    if result.returncode or re.search(r"SCRIPT ERROR:|Parse Error:|Project export.*failed", output):
        raise RuntimeError("Native command failed; inspect the local build log")
    return output


def verify_android(apk, aab, config, sdk, jdk, bundletool):
    tools = sdk / "build-tools" / "36.1.0"
    binary = tools / ("aapt.exe" if os.name == "nt" else "aapt")
    # Windows aapt's legacy argument parser cannot read a Unicode absolute
    # project path. The same file is readable relative to our fixed repo cwd.
    apk_argument = apk.relative_to(ROOT) if apk.is_relative_to(ROOT) else apk
    aab_argument = aab.relative_to(ROOT) if aab.is_relative_to(ROOT) else aab
    badging = run([binary, "dump", "badging", apk_argument])
    identity = "package: name='%s' versionCode='%s' versionName='%s'" % (
        config["appId"], config["nativeBuild"], config["nativeVersion"])
    if identity not in badging or "targetSdkVersion:'36'" not in badging or "application-debuggable" in badging:
        raise ValueError("APK identity/version/target/release mismatch")
    if "uses-permission: name='android.permission.INTERNET'" in badging:
        raise ValueError("Offline game unexpectedly requests INTERNET")
    java = jdk / "bin" / ("java.exe" if os.name == "nt" else "java")
    xml = ET.fromstring(run([java, "-jar", bundletool, "dump", "manifest", "--bundle=" + str(aab_argument), "--module=base"]))
    ns = "{http://schemas.android.com/apk/res/android}"
    if xml.get("package") != config["appId"] or xml.get(ns + "versionCode") != str(config["nativeBuild"]) or xml.get(ns + "versionName") != config["nativeVersion"]:
        raise ValueError("AAB identity/version mismatch")
    uses = xml.find("uses-sdk")
    if uses is None or uses.get(ns + "targetSdkVersion") != "36":
        raise ValueError("AAB target API mismatch")
    if xml.find("application").get(ns + "debuggable", "false") != "false":
        raise ValueError("AAB is a debug build")
    packages = []
    for path in (apk, aab):
        with zipfile.ZipFile(path) as archive:
            names = archive.namelist()
            if any(re.search(r"META-INF/[^/]+\.(RSA|DSA|EC|SF)$", n, re.I) for n in names):
                raise ValueError("Expected an unsigned package")
            # Godot AABs put the game in an install-time asset pack, not base.
            assets = [n for n in names if re.search(r"(?:^|/)assets/", n) and not n.endswith("/")]
            if not assets:
                raise ValueError("Native game assets are missing")
            if not any(n.endswith("lib/arm64-v8a/libgodot_android.so") for n in names):
                raise ValueError("ARM64 Godot engine is missing")
        packages.append({"file": path.name, "bytes": path.stat().st_size,
                         "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "nativeAssets": len(assets)})
    return packages


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", choices=["android", "ios"], required=True)
    parser.add_argument("--godot", type=pathlib.Path, required=True)
    parser.add_argument("--jdk", type=pathlib.Path)
    parser.add_argument("--android-sdk", type=pathlib.Path)
    parser.add_argument("--bundletool", type=pathlib.Path)
    parser.add_argument("--doctor", action="store_true")
    parser.add_argument("--source-only", action="store_true", help="Export Xcode project without compiling an archive")
    args = parser.parse_args()
    config = json.loads((ROOT / "native/build-config.json").read_text(encoding="utf-8"))
    project = (ROOT / config["projectPath"]).resolve()
    output = (ROOT / config["outputPath"]).resolve()
    if not project.is_relative_to(ROOT) or not output.is_relative_to(ROOT):
        raise ValueError("Native paths must remain in this repository")
    output.mkdir(parents=True, exist_ok=True)
    report = {"appId": config["appId"], "nativeVersion": config["nativeVersion"],
              "nativeBuild": config["nativeBuild"] if args.target == "android" else 1,
              "engineVersion": "4.7.2", "sourceVersion": config["sourceVersion"], "target": args.target,
              "signed": False, "uploaded": False, "physicalDeviceTested": False,
              "sourceSha": run(["git", "rev-parse", "HEAD"]).strip(),
              "sourceWorkingTreeDirty": bool(run(["git", "status", "--porcelain"]).strip()), "status": "pending"}
    try:
        godot = args.godot.resolve()
        # The Windows console wrapper may retain handles inherited by Gradle.
        # Invoke the same official engine directly in headless mode instead.
        if godot.name.endswith("_console.exe"):
            direct = godot.with_name(godot.name.replace("_console.exe", ".exe"))
            if direct.is_file():
                godot = direct
        if not godot.is_file() or not run([godot, "--version"], timeout=60).startswith("4.7.2.stable.official."):
            raise ValueError("Official Godot 4.7.2 stable is required")
        if args.target == "ios":
            if not args.source_only:
                if platform.system() != "Darwin":
                    raise ValueError("iOS archive requires macOS + Xcode; use --source-only for the verified Godot 4.7.2 project export")
                run(["xcodebuild", "-version"], timeout=60)
        else:
            if not all(p and p.is_dir() for p in (args.jdk, args.android_sdk)) or not args.bundletool or not args.bundletool.is_file():
                raise ValueError("Provide JDK, Android SDK and the verified bundletool JAR")
            settings = godot.parent / "editor_data/editor_settings-4.7.tres"
            if not (godot.parent / "_sc_").exists():
                raise ValueError("Use the isolated portable Godot toolchain, not the user's global Editor settings")
            settings.parent.mkdir(parents=True, exist_ok=True)
            settings.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' +
                'export/android/java_sdk_path = ' + json.dumps(str(args.jdk.resolve()).replace("\\", "/")) + '\n' +
                'export/android/android_sdk_path = ' + json.dumps(str(args.android_sdk.resolve()).replace("\\", "/")) + '\n', encoding="utf-8")
        if args.doctor:
            report["status"] = "toolchain-present-not-exported"
        else:
            run([godot, "--headless", "--path", project, "--import"], output / "import.log")
            if args.target == "android":
                apk, aab = output / "native-unsigned.apk", output / "native-unsigned.aab"
                run([godot, "--headless", "--path", project, "--export-release", "Android APK unsigned", apk], output / "android-apk.log")
                run([godot, "--headless", "--path", project, "--install-android-build-template", "--export-release", "Android AAB unsigned", aab], output / "android-aab.log", timeout=1800)
                report["packages"] = verify_android(apk, aab, config, args.android_sdk, args.jdk, args.bundletool)
                report["status"] = "unsigned-android-verified"
            else:
                target = output / "ios"
                if target.exists() and any(target.iterdir()):
                    raise ValueError("iOS export needs a fresh directory; existing files will not be erased")
                target.mkdir(exist_ok=True)
                name = config["xcodeProjectName"]
                run([godot, "--headless", "--path", project, "--export-release", "iOS Xcode unsigned", target / (name + ".ipa")], output / "ios-export.log")
                xcode = target / (name + ".xcodeproj")
                if not xcode.is_dir() or not (target / (name + ".pck")).is_file():
                    raise ValueError("Xcode project or packed Godot game is missing")
                if args.source_only:
                    report["status"] = "ios-xcode-source-created-not-compiled"
                    (output / "ios-verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
                    print(json.dumps(report, ensure_ascii=False, indent=2))
                    return 0
                run(["xcodebuild", "-project", xcode, "-scheme", name, "-configuration", "Release", "-destination", "generic/platform=iOS",
                     "-archivePath", target / (name + ".xcarchive"), "CODE_SIGNING_ALLOWED=NO", "archive"], output / "ios-archive.log", timeout=1800)
                apps = list((target / (name + ".xcarchive/Products/Applications")).glob("*.app"))
                if len(apps) != 1:
                    raise ValueError("Expected one unsigned iOS device application")
                info = plistlib.loads((apps[0] / "Info.plist").read_bytes())
                if (info.get("CFBundleIdentifier") != config["appId"] or info.get("CFBundleShortVersionString") != config["nativeVersion"]
                        or str(info.get("CFBundleVersion")) != "1" or info.get("CFBundleSupportedPlatforms") != ["iPhoneOS"]):
                    raise ValueError("Archived iOS identity/version/platform mismatch")
                report["status"] = "unsigned-ios-archive-created"
    except (ValueError, RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        report.update(status="needs-tools-or-validation", error=str(error))
    (output / (args.target + "-verification.json")).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["status"] in ("toolchain-present-not-exported", "unsigned-android-verified", "unsigned-ios-archive-created") else 2


if __name__ == "__main__":
    raise SystemExit(main())
