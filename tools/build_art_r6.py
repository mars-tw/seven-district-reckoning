"""Headless-only export; reports remain outside unrelated qa/*.json."""
import argparse
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--godot', required=True)
args = parser.parse_args()
(ROOT / 'deliverables/web').mkdir(parents=True, exist_ok=True)
for options in [['--editor', '--import', '--quit'],
                ['--export-release', 'Web', '../deliverables/web/game.html']]:
    cmd = [args.godot, '--headless', '--quiet', '--language', 'en', '--path', 'godot', *options]
    p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=180)
    output = p.stdout + p.stderr
    print(output[-4000:])
    if p.returncode or re.search(r'ERROR:|Parse Error:|SCRIPT ERROR:', output):
        raise SystemExit(p.returncode or 1)
subprocess.run(['node', '--input-type=module', '-e',
                "import {prepareWebAssets} from './tools/prepare_web_assets.mjs'; prepareWebAssets(undefined,{manifestPath:'docs/evidence/r6-art/web-build.json'});"],
               cwd=ROOT, check=True)
