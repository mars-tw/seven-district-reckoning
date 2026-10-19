"""Build a tracked-source snapshot without borrowing or changing owner drafts."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / '.audit-tmp/content-r2'
SOURCE = AUDIT / 'source'
EXTRA = ['tests/content_r2.gd', 'tools/content_r2_prepare.py', 'godot/scripts/content/investigation_field.gd', 'godot/scripts/content/investigation_field.gd.uid'] + [p.relative_to(ROOT).as_posix() for p in (ROOT/'godot/assets/art/content-r2').glob('*')]

def snapshot():
    protected = json.loads((AUDIT/'ownership.json').read_text(encoding='utf8'))['protected']
    for name, expected in protected.items():
        assert (ROOT/name).is_file() and hashlib.sha256((ROOT/name).read_bytes()).hexdigest() == expected, name
    tracked = subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode('utf8').split('\0')
    for name in sorted(set(tracked + EXTRA)):
        if not name or not (name.startswith(('godot/','tests/','web/','tools/','assets/provenance/')) or name in ['LICENSE','CREDITS.md','LICENSE-ASSETS.md','README.md','assets/source/makehuman/LICENSE.ASSETS.md']): continue
        if not (ROOT/name).is_file(): continue
        target = SOURCE/name
        target.parent.mkdir(parents=True,exist_ok=True)
        if name in protected:
            target.write_bytes(subprocess.check_output(['git','show','HEAD:'+name],cwd=ROOT))
        else: shutil.copy2(ROOT/name,target)
    return SOURCE

def build(godot):
    source = snapshot()
    out = AUDIT/'web'
    out.mkdir(exist_ok=True)
    # Exclude superseded assets in this isolated Web preset only.
    preset = source/'godot/export_presets.cfg'
    text = preset.read_text(encoding='utf8')
    exclusions=json.loads((ROOT/'docs/evidence/r10-art/export-budget.json').read_text(encoding='utf8'))['historical_images_excluded']
    text=re.sub(r'(?m)^exclude_filter="([^"]*)"$',lambda m:'exclude_filter="'+m[1]+','+','.join(exclusions)+'"',text)
    templates=Path(os.environ['APPDATA'])/'Godot/export_templates/4.7.stable'
    for kind in ['debug','release']:
        template=templates/('web_nothreads_'+kind+'.zip')
        assert template.is_file(), 'Missing installed Web template: '+template.name
        text=text.replace('custom_template/'+kind+'=""','custom_template/'+kind+'="'+template.as_posix()+'"')
    preset.write_text(text,encoding='utf8')
    env=os.environ.copy()
    for key in ['APPDATA','LOCALAPPDATA','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']:
        directory=AUDIT/key.lower();directory.mkdir(exist_ok=True);env[key]=str(directory)
    settings=source/'godot/project.godot'
    import sys
    sys.path.insert(0,str(ROOT/'tools'))
    from test_game import disable_parallel_import,source_fingerprint
    settings.write_text(disable_parallel_import(settings.read_text(encoding='utf8')),encoding='utf8')
    for flags in [['--editor','--import','--quit'],['--export-release','Web',str(out/'game.html')]]:
        proc=subprocess.run([godot,'--headless','--language','en','--path',str(source/'godot'),*flags],cwd=source,env=env,capture_output=True,text=True,encoding='utf8',errors='replace',timeout=300)
        print(proc.stdout[-1400:]+proc.stderr[-1400:],flush=True)
        assert proc.returncode==0 and not re.search(r'ERROR:|SCRIPT ERROR:|Parse Error:',proc.stdout+proc.stderr)
    # Run the normal web adapter from the same isolated source.
    script="import {prepareWebAssets} from './tools/prepare_web_assets.mjs'; prepareWebAssets(process.argv[1],{manifestPath:process.argv[2]});"
    subprocess.run(['node','--input-type=module','-e',script,str(out),str(ROOT/'docs/content/r2/web-build.json')],cwd=source,check=True)
    pck=out/'game.pck'
    report=dict(status='VERIFIED',pck_bytes=pck.stat().st_size,pck_sha256=hashlib.sha256(pck.read_bytes()).hexdigest(),owner_drafts_included=False,source_fingerprint=source_fingerprint(source/'godot',source/'tests',source/'web',source/'tools'))
    (ROOT/'docs/content/r2/export.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--snapshot',action='store_true')
    parser.add_argument('--build',action='store_true')
    parser.add_argument('--godot')
    args=parser.parse_args()
    (ROOT/'docs/content/r2').mkdir(parents=True,exist_ok=True)
    if args.snapshot: print(snapshot().relative_to(ROOT))
    if args.build: build(args.godot)
