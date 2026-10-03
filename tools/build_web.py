"""Reproduce the single-threaded web export and static hosting package."""
import argparse
import shutil
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--godot', default=shutil.which('godot') or 'godot')
parser.add_argument('--node', default=shutil.which('node') or 'node')
args = parser.parse_args()
(root / 'deliverables/web').mkdir(parents=True, exist_ok=True)
for command, directory in [
    ([args.godot, '--headless', '--quiet', '--language', 'en', '--path', '.', '--editor', '--import', '--quit'], root / 'godot'),
    ([args.godot, '--headless', '--quiet', '--language', 'en', '--path', '.', '--export-release', 'Web', '../deliverables/web/game.html'], root / 'godot'),
    ([args.node, 'tools/prepare_web_assets.mjs'], root),
]:
    subprocess.run(command, cwd=directory, check=True)
print('Web export ready: deliverables/web/index.html')
