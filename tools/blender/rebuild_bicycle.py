import importlib.util,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('alpha',ROOT/'tools/blender/build_alpha_assets.py');a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
a.REPORT[:]=json.loads((ROOT/'qa/art/asset-manifest.json').read_text(encoding='utf-8'));a.bicycle()
