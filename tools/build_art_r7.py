"""Isolated headless export; preserve the owner's pending native-export files."""
import argparse,hashlib,json,re,shutil,subprocess
from test_game import source_fingerprint
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--godot',required=True);args=parser.parse_args()
candidate=ROOT/'.audit-tmp/r7-export/godot'
candidate.mkdir(parents=True,exist_ok=True)
shutil.copytree(ROOT/'godot',candidate,dirs_exist_ok=True,ignore=shutil.ignore_patterns('.godot','_checks'))
shutil.copytree(ROOT/'web',candidate.parent/'web',dirs_exist_ok=True)
for name in ['export_presets.cfg','scripts/ui/touch_controls.gd']:
    (candidate/name).write_bytes(subprocess.check_output(['git','show','HEAD:godot/'+name],cwd=ROOT))
excluded=['assets/art/r4/'+x for x in ['app-icon.png','ayuan-portrait.png','meiqing-portrait.png','title-logo.png','title-street.webp']]
excluded+=['assets/art/r5/title-street.webp']+['assets/art/r6/'+x for x in ['ayuan-portrait.png','meiqing-portrait.png','title-street.webp']]
excluded+=['assets/models/r7/ayuan-tailored.glb','assets/art/r7/case-panel.webp']
p=candidate/'export_presets.cfg';text=p.read_text(encoding='utf8')
text=re.sub(r'(?m)^exclude_filter="([^"]*)"$',lambda m:'exclude_filter="'+m[1]+','+','.join(excluded)+'"',text)
p.write_text(text,encoding='utf8')
out=ROOT/'deliverables/web';out.mkdir(parents=True,exist_ok=True)
for options in [['--editor','--import','--quit'],['--export-release','Web',str(out/'game.html')]]:
    cmd=[args.godot,'--headless','--quiet','--language','en','--path',str(candidate),*options]
    result=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,encoding='utf8',errors='replace',timeout=240)
    output=result.stdout+result.stderr
    print(output[-2000:])
    if result.returncode or re.search(r'ERROR:|Parse Error:|SCRIPT ERROR:',output):raise SystemExit(result.returncode or 1)
subprocess.run(['node','--input-type=module','-e',"import {prepareWebAssets} from './tools/prepare_web_assets.mjs'; prepareWebAssets(undefined,{manifestPath:'docs/evidence/r7-art/web-build.json'});"],cwd=ROOT,check=True)
report=dict(status='EXECUTED',version='0.11.0',source_fingerprint=source_fingerprint(candidate),pck_bytes=(out/'game.pck').stat().st_size,pck_sha256=hashlib.sha256((out/'game.pck').read_bytes()).hexdigest(),historical_images_excluded=excluded,protected_files_from='HEAD versions copied into isolated export only',working_protected_files_modified=False)
(ROOT/'docs/evidence/r7-art/export-budget.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
