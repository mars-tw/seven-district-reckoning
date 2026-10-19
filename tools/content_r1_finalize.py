"""Verify and stage only the explicit content-round paths, retaining owner files."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import re
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/content/r1'
def read(p): return json.loads((ROOT/p).read_text(encoding='utf8'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def prepare():
    # Import metadata belongs only to the two new scripts and one new texture.
    for relative in ['scripts/content/content_investigations.gd.uid','scripts/ui/investigation_panel.gd.uid']:
        source=ROOT/'.audit-tmp/content-r1/source/godot'/relative
        if source.exists(): (ROOT/'godot'/relative).write_bytes(source.read_bytes())
    prompt=(ROOT/'assets/art/content-r1/PROMPT.md').read_text(encoding='utf8').split('\n\n實際工具：')[0].strip()
    prompts=read('docs/art/PROMPTS.json')
    prompts['content_round_1']={'date':'2026-10-18','tool':'image_gen.imagegen','model_slug':None,'assets':[{'id':'investigation-desk','prompt':prompt,'manifest':'assets/art/content-r1/manifest.json'}]}
    (ROOT/'docs/art/PROMPTS.json').write_text(json.dumps(prompts,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    manifest=read('assets/art/content-r1/manifest.json')
    manifest['godot_texture_import']={'mode':'lossy','quality':0.7,'mipmaps':False,'note':'Only the new UI illustration uses this import recipe; master remains lossless.'}
    (ROOT/'assets/art/content-r1/manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')

def verify(stage=False):
    owner=read('.audit-tmp/content-r1/ownership.json')['protected']
    assert all((ROOT/p).is_file() and sha(ROOT/p)==h for p,h in owner.items()),'Owner files changed'
    tests=read('docs/content/r1/final-tests.json')
    assert len(tests)==32 and all(r['status']=='PASS' for r in tests),[(r['check'],r['status']) for r in tests]
    export=read('docs/content/r1/export.json')
    assert all(r['source_fingerprint']['digest']==export['source_fingerprint']['digest'] for r in tests),'Test/build source mismatch'
    capture=read('docs/content/r1/screenshots/manifest.json')
    assert capture['status']=='VERIFIED' and len(capture['views'])==9 and not capture['failures']
    assert capture['pck_sha256']==export['pck_sha256']
    count=0
    for view in capture['views']:
        assert view['status']=='VERIFIED' and not view['errors']
        for shot in view['shots']:
            p=OUT/'screenshots'/shot['file']
            assert sha(p)==shot['sha256'] and Image.open(p).size==(view['viewport']['width']*view['dpr'],view['viewport']['height']*view['dpr'])
            count+=1
    for row in read('assets/art/content-r1/manifest.json')['files']:
        assert sha(ROOT/row['path'])==row['sha256'] and list(Image.open(ROOT/row['path']).size)==row['size']
    store=ROOT/'docs/store/screenshots'
    store.mkdir(exist_ok=True)
    new=[]
    for tag in ['1290x2796','2064x2752']:
        for suffix in ['timeline-arranged','testimony-crosscheck','second_help-sealed']:
            name=tag+'-content-r1-'+suffix+'.png'
            source=OUT/'screenshots'/(tag+'-'+suffix+'.png')
            target=store/name
            assert not target.exists() or sha(target)==sha(source),'Existing store file differs'
            target.write_bytes(source.read_bytes())
            new.append({'path':'docs/store/screenshots/'+name,'sha256':sha(target),'pixels':list(Image.open(target).size)})
    (store/'CONTENT_R1_STATUS.json').write_text(json.dumps({'status':'VERIFIED','version':'0.15.0','method':capture['method'],'new_screenshots':new,'existing_screenshots_deleted':False},ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    paths=set('''README.md CREDITS.md docs/OPTIM_PLAN_CONTENT_R1.md docs/CODEX_RESPONSE_CONTENT_R1.md docs/art/PROMPTS.json godot/project.godot godot/assets/fonts/SevenDistrictSansTC-Regular.otf godot/scripts/main.gd godot/scripts/ui/game_hud.gd godot/scripts/content/content_investigations.gd godot/scripts/content/content_investigations.gd.uid godot/scripts/ui/investigation_panel.gd godot/scripts/ui/investigation_panel.gd.uid godot/data/fraud_cases.json web/shell.html tests/content_r1.gd tools/test_game.py tools/content_r1_prepare.py tools/content_r1_evidence.mjs tools/content_r1_finalize.py docs/store/screenshots/CONTENT_R1_STATUS.json'''.split())
    for directory in ['assets/art/content-r1','godot/assets/art/content-r1','docs/content/r1/screenshots']:
        paths.update(p.relative_to(ROOT).as_posix() for p in (ROOT/directory).rglob('*') if p.is_file())
    paths.update(row['path'] for row in new)
    paths.update('docs/content/r1/'+n for n in ['export.json','web-build.json','final-tests.json','host-after-capture.json','verification.json'])
    assert not paths.intersection(owner),'Staging owner paths'
    verification=dict(status='VERIFIED',version='0.15.0',protected_files_unchanged=len(owner),test_suites=len(tests)-1,test_checks=sum(t['reported_checks'] for t in tests),test_failures=0,browser_views=len(capture['views']),captured_screenshots=count,new_store_screenshots=len(new),source_digest=export['source_fingerprint']['digest'],pck_sha256=export['pck_sha256'],pck_bytes=export['pck_bytes'],art_generated_masters=1,art_runtime_images=1,explicit_paths=len(paths))
    verification['performance_reference']=[{'viewport':v['tag'],'p95_median_ms':v['frame_pacing']['p95_median_ms'],'threshold_ms':18,'status':v['frame_pacing']['status']} for v in capture['views'] if 'frame_pacing' in v]
    verification['performance_environment']='並發載量測，僅供參考; not a clean-host or native-device proof'
    verification['shipping_gate']='BLOCKED'
    (OUT/'verification.json').write_text(json.dumps(verification,indent=2)+'\n',encoding='utf8')
    if stage:
        assert all((ROOT/p).is_file() for p in paths),[p for p in paths if not (ROOT/p).is_file()]
        ordered=sorted(paths)
        for start in range(0,len(ordered),35): subprocess.run(['git','add','--',*ordered[start:start+35]],cwd=ROOT,check=True)
        indexed=set(subprocess.check_output(['git','diff','--cached','--name-only','-z'],cwd=ROOT).decode('utf8').split('\0'))-{''}
        assert indexed==paths,(indexed-paths,paths-indexed)
        scan=subprocess.run(['python','tools/scan_publication.py'],cwd=ROOT,capture_output=True,text=True,encoding='utf8')
        raw_scan=json.loads(scan.stdout)
        # Keep the original scanner unchanged. Its broad sk-* regex matches
        # the suffix of the pre-existing word 'dusk-sky' in Godot MD5 paths.
        # Only two exact, unchanged HEAD cache-reference lines are non-secrets.
        classified=[]
        for finding in raw_scan['findings']:
            relative=finding['file']
            assert relative=='godot/assets/art/r8/dusk-sky.webp.import' and finding['type']=='api_token',finding
            file=ROOT/relative
            assert file.read_bytes()==subprocess.check_output(['git','show','HEAD:'+relative],cwd=ROOT)
            line=file.read_text(encoding='utf8').splitlines()[finding['line']-1]
            assert re.fullmatch(r'(?:path=|dest_files=\[)"res://\.godot/imported/dusk-sky\.webp-[a-f0-9]{32}\.ctex"\]?',line),finding
            classified.append(finding)
        verification['secret_scan']={'status':'VERIFIED','actual_secret_findings':[], 'actual_secret_count':0,'raw_scanner_status':raw_scan['status'],'unchanged_head_godot_cache_false_positives':classified,'tracked_files':raw_scan['tracked_files']}
        required_hits=[]
        required_pattern=re.compile(r'sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}')
        for relative in subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode('utf8').split('\0'):
            if not relative: continue
            try: content=(ROOT/relative).read_text(encoding='utf8')
            except UnicodeError: continue
            if required_pattern.search(content): required_hits.append(relative)
        assert not required_hits,required_hits
        verification['secret_scan']['required_pattern_hits']=0
        verification['secret_scan']['scope']='Prospective tracked text (git ls-files); no credential directories read'
        (OUT/'verification.json').write_text(json.dumps(verification,indent=2)+'\n',encoding='utf8')
        subprocess.run(['git','add','--','docs/content/r1/verification.json'],cwd=ROOT,check=True)
    print(json.dumps(verification))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare-metadata',action='store_true')
    parser.add_argument('--stage',action='store_true')
    args=parser.parse_args()
    if args.prepare_metadata: prepare()
    else: verify(args.stage)
