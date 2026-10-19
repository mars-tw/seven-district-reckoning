"""Promote only hash-matched, original-size screenshots from a frozen Web export."""
import hashlib,json,shutil
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'docs/art/compare/r7-after'
STORE=ROOT/'docs/store/screenshots'
OUT=ROOT/'docs/evidence/r7-art'
def read(p):return json.loads(p.read_text(encoding='utf8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    m=read(SOURCE/'manifest.json');budget=read(OUT/'export-budget.json');base=read(OUT/'baseline.json')
    assert m['status']=='VERIFIED' and len(m['views'])==10 and not m['failures']
    assert m['pck_sha256']==budget['pck_sha256']==sha(ROOT/'deliverables/web/game.pck')
    m['base_commit']=base['commit']
    m['source_fingerprint']=budget['source_fingerprint']
    (SOURCE/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    images=[];actions=[];pacing=[]
    for view in m['views']:
        size=(view['pixels']['width'],view['pixels']['height'])
        if 'frame_pacing' in view:pacing.append(dict(pixels=list(size),**view['frame_pacing']))
        if size[0] in [1290,2064]:
            for row in view['shots']+view['inspections']:
                p=SOURCE/row['file'];assert sha(p)==row['sha256'] and Image.open(p).size==size
                shutil.copy2(p,STORE/p.name);images.append(p.name)
            motion_dir=OUT/('clock-phone' if size[0]==1290 else 'clock-tablet')
            motion=read(motion_dir/'manifest.json')
            assert motion['status']=='VERIFIED' and motion['pck_sha256']==m['pck_sha256']
            action=motion['views'][0]['clock_seal'][2]
            name=f'{size[0]}x{size[1]}-seal-action.png'
            shutil.copy2(motion_dir/action['file'],STORE/name)
            images.append(name);actions.append(dict(file=name,source=(motion_dir/action['file']).relative_to(ROOT).as_posix(),sha256=action['sha256'],elapsed_ms=action['elapsed_ms'],method=action['method']))
        if size==(390,844):
            row=next(x for x in view['shots'] if x['file'].endswith('-street.png'))
            art=row['state']['art'];im=Image.open(SOURCE/row['file'])
            for key in ['hero','mei']:
                head,feet=art[key+'_head'],art[key+'_feet'];height=abs(feet[1]-head[1]);cx=(head[0]+feet[0])/2
                bounds=(max(0,int(cx-height*.34)),max(0,int(head[1]-5)),min(im.width,int(cx+height*.34)),min(im.height,int(feet[1]+5)))
                crop=im.crop(bounds);crop.thumbnail((64,64),Image.Resampling.LANCZOS)
                tile=Image.new('RGB',(64,64),'#16181d');tile.paste(crop,((64-crop.width)//2,(64-crop.height)//2));tile.save(OUT/(key+'-64px.png'))
    icon=Image.open(ROOT/'godot/assets/art/r7/app-icon.webp');icon.resize((64,64),Image.Resampling.LANCZOS).save(OUT/'app-icon-64px.png')
    STORE.joinpath('manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    status=dict(status='VERIFIED',version='0.11.0',generated_masters=8,runtime_images=11,new_glb=2,tool='image_gen.imagegen',model_slug=None,model_note='Actual tool does not expose model slug.',store_screenshots=images,action_captures=actions,comparison_manifest='docs/art/compare/r7-after/manifest.json',before='docs/art/compare/r7-before/',report='docs/CODEX_RESPONSE_R7_ART.md',remaining='docs/art/R7_MISSING_3D.md',pck_sha256=m['pck_sha256'],scope='Actual Godot Web export; native hardware and independent 8/10 score remain unverified.')
    status['release_status']='BLOCKED'
    status['release_blockers']=['Desktop concurrent-load RAF p95 33.4 ms exceeds 18 ms','Early seal frames still show short-lived layout noise','Independent 8/10 rescore and native hardware validation outstanding']
    STORE.joinpath('R7_STATUS.json').write_text(json.dumps(status,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    OUT.joinpath('performance.json').write_text(json.dumps(dict(status='BLOCKED' if any(p['p95_median']>18 for p in pacing) else 'EXECUTED',threshold_ms=18,environment='並發載量測，僅供參考',method='Browser RAF presentation intervals; not native GPU timing',runs=pacing),ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    active=['godot/project.godot','web/shell.html','README.md','godot/assets/art/r7/manifest.json']
    old=[p for p in active if '0.10.0' in ROOT.joinpath(p).read_text(encoding='utf8')]
    assert not old
    OUT.joinpath('version-audit.json').write_text(json.dumps(dict(status='VERIFIED',version='0.11.0',active_files=active,old_version_hits=old,exclusions='Historical R4/R5/R6 reports and art manifests retained; owner native export presets unchanged.'),indent=2)+'\n')
    print(json.dumps(dict(status='VERIFIED',store_screenshots=len(images),actions=actions,pacing=[{'pixels':p['pixels'],'p95_median':p['p95_median']} for p in pacing])))
if __name__=='__main__':main()
