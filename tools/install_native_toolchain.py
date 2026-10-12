"""Install an isolated official Godot/native inspection toolchain; no account setup."""
import argparse
import hashlib
import json
import os
import pathlib
import platform
import stat
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

TAG = "4.7.2-stable"
BUNDLETOOL_SHA = "a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29"


def fetch(url, path, digest, size=None, algorithm="sha256"):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_file() and (size is None or path.stat().st_size == size):
        if hashlib.new(algorithm, path.read_bytes()).hexdigest() == digest:
            return
    temporary = path.with_suffix(path.suffix + ".download")
    with urllib.request.urlopen(url, timeout=180) as source, temporary.open("wb") as out:
        while chunk := source.read(1024 * 1024):
            out.write(chunk)
    if (size is not None and temporary.stat().st_size != size) or hashlib.new(algorithm, temporary.read_bytes()).hexdigest() != digest:
        raise ValueError("Official download size/digest mismatch")
    temporary.replace(path)


def extract(archive_path, target):
    with zipfile.ZipFile(archive_path) as archive:
        for entry in archive.infolist():
            relative = pathlib.PurePosixPath(entry.filename)
            if relative.is_absolute() or ".." in relative.parts or "\\" in entry.filename:
                raise ValueError("Unsafe tool archive path")
            if stat.S_ISLNK(entry.external_attr >> 16):
                raise ValueError("Unexpected linked tool archive")
            path = target / entry.filename
            if entry.is_dir():
                path.mkdir(parents=True, exist_ok=True)
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(archive.read(entry))
                if os.name != "nt":
                    mode = entry.external_attr >> 16
                    if mode:
                        path.chmod(mode & 0o777)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--android-sdk", type=pathlib.Path)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    suffix = {"Windows": "win64.exe.zip", "Linux": "linux.x86_64.zip", "Darwin": "macos.universal.zip"}.get(platform.system())
    if not suffix:
        raise ValueError("Unsupported official Editor host")
    with urllib.request.urlopen("https://api.github.com/repos/godotengine/godot/releases/tags/" + TAG, timeout=60) as response:
        release = json.load(response)
    names = ["Godot_v" + TAG + "_" + suffix, "Godot_v" + TAG + "_export_templates.tpz"]
    for name in names:
        matches = [a for a in release["assets"] if a["name"] == name]
        if len(matches) != 1 or not str(matches[0].get("digest", "")).startswith("sha256:"):
            raise ValueError("Official release asset/checksum is missing")
        asset = matches[0]
        fetch(asset["browser_download_url"], output / name, asset["digest"].split(":")[1], asset["size"])
    editor = output / "editor"
    extract(output / names[0], editor)
    if platform.system() == "Darwin":
        godot = editor / "Godot.app/Contents/MacOS/Godot"
    else:
        files = [p for p in editor.iterdir() if p.is_file() and "console" not in p.name]
        if len(files) != 1:
            raise ValueError("Expected one official Editor executable")
        godot = files[0]
    if not godot.is_file():
        raise ValueError("Official Editor executable missing")
    if os.name != "nt":
        godot.chmod(0o755)
    (godot.parent / "_sc_").write_text("")
    templates = godot.parent / "editor_data/export_templates/4.7.2.stable"
    templates.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output / names[1]) as archive:
        for name in archive.namelist():
            leaf = pathlib.PurePosixPath(name).name
            if leaf in {"android_debug.apk", "android_release.apk", "android_source.zip", "ios.zip", "version.txt"}:
                (templates / leaf).write_bytes(archive.read(name))
    bundletool = output / "bundletool-1.18.3.jar"
    fetch("https://github.com/google/bundletool/releases/download/1.18.3/bundletool-all-1.18.3.jar", bundletool, BUNDLETOOL_SHA)
    if args.android_sdk:
        host = {"Windows": "windows", "Linux": "linux", "Darwin": "macosx"}[platform.system()]
        with urllib.request.urlopen("https://dl.google.com/android/repository/repository2-3.xml", timeout=60) as response:
            xml = ET.fromstring(response.read())
        package = next(p for p in xml.iter("remotePackage") if p.get("path") == "build-tools;36.1.0")
        item = next(a for a in package.findall("./archives/archive") if a.findtext("host-os") == host).find("complete")
        filename = item.findtext("url")
        archive_path = output / filename
        fetch("https://dl.google.com/android/repository/" + filename, archive_path, item.findtext("checksum"), int(item.findtext("size")), "sha1")
        unpacked = output / "build-tools"
        extract(archive_path, unpacked)
        folders = [p for p in unpacked.iterdir() if p.is_dir()]
        if len(folders) != 1:
            raise ValueError("Expected one official Build Tools directory")
        import shutil
        shutil.copytree(folders[0], args.android_sdk / "build-tools/36.1.0", dirs_exist_ok=True)
    report = {"godot": str(godot), "godotVersion": "4.7.2", "bundletool": str(bundletool), "publisherDigestsVerified": True}
    (output / "toolchain.json").write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
