"""Compile a fictional replacement packet, capture it, then prove source restoration."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
from fontTools.ttLib import TTFont
from test_game import source_fingerprint

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT/'.audit-tmp/content-r2'
SOURCE = AUDIT/'source'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def main(godot, playwright):
    original = SOURCE/'godot/data/fraud_cases.json'
    raw = original.read_bytes()
    expected = json.loads((ROOT/'docs/content/r2/export.json').read_text())['source_fingerprint']['digest']
    fingerprint = lambda: source_fingerprint(SOURCE/'godot',SOURCE/'tests',SOURCE/'web',SOURCE/'tools')['digest']
    assert fingerprint() == expected
    variant = raw.decode('utf8').replace('澄岸協助所','晴橋協助所').replace('岸七','橋七')
    assert variant != raw.decode('utf8')
    font_file = ROOT/'godot/assets/fonts/SevenDistrictSansTC-Regular.otf'
    font = TTFont(font_file)
    assert all(ord(c) in font.getBestCmap() for c in '晴橋協助所橋七'), 'Replacement glyph absent from shipping font'
    font.close()
    out = AUDIT/'data-swap-web'; out.mkdir(exist_ok=True)
    env = os.environ.copy()
    for key in ['APPDATA','LOCALAPPDATA','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']:
        directory = AUDIT/('swap-'+key.lower());directory.mkdir(exist_ok=True);env[key] = str(directory)
    try:
        original.write_bytes(variant.encode('utf8'))
        result = subprocess.run([godot,'--headless','--language','en','--path',str(SOURCE/'godot'),'--export-release','Web',str(out/'game.html')],env=env,capture_output=True,text=True,encoding='utf8',errors='replace',timeout=180)
        assert result.returncode == 0 and 'ERROR:' not in result.stdout+result.stderr, (result.stdout+result.stderr)[-2000:]
    finally:
        original.write_bytes(raw)
    assert fingerprint() == expected and original.read_bytes() == raw
    adapter = "import {prepareWebAssets} from './tools/prepare_web_assets.mjs';prepareWebAssets(process.argv[1],{manifestPath:process.argv[2]});"
    subprocess.run(['node','--input-type=module','-e',adapter,str(out),str(AUDIT/'data-swap-build.json')],cwd=SOURCE,check=True)
    pictures = AUDIT/'data-swap-capture'
    subprocess.run(['node','tools/content_r2_evidence.mjs','--playwright-module',playwright,'--web-dir',str(out),'--data-swap','--only','390x844','--output',str(pictures)],cwd=ROOT,check=True)
    capture = json.loads((pictures/'manifest.json').read_text(encoding='utf8'))
    assert capture['status'] == 'VERIFIED' and len(capture['views']) == 1 and not capture['failures']
    shots = [s for s in capture['views'][0]['shots'] if 'data-swap' in s['file']]
    assert len(shots) == 2
    for shot in shots:
        assert sha(pictures/shot['file']) == shot['sha256']
        shutil.copy2(pictures/shot['file'],ROOT/'docs/content/r2'/shot['file'])
    report = {'status':'VERIFIED','version':'0.16.0','scope':'Isolated compiled-data replacement proof only; not a fourth shipping case or a store screenshot. No UI strings or answers are injected by the browser.',
        'changed_literals':{'澄岸協助所':'晴橋協助所','岸七':'橋七'},'original_json_sha256':hashlib.sha256(raw).hexdigest(),'variant_json_sha256':hashlib.sha256(variant.encode('utf8')).hexdigest(),
        'variant_pck_sha256':sha(out/'game.pck'),'font_subset_sha256':sha(font_file),'replacement_glyphs_verified':True,'original_export_source_restored':fingerprint() == expected,'source_digest':expected,'renderer':capture['views'][0]['renderer'],'shots':shots}
    (ROOT/'docs/content/r2/data-swap.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print('VERIFIED compiled data replacement; original source restored; 2 native-size screenshots')

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__);p.add_argument('--godot',required=True);p.add_argument('--playwright-module',required=True);a=p.parse_args();main(a.godot,a.playwright_module)
