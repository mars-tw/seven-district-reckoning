"""Promote hash-matched original-size captures; keep derived QA separate."""
import hashlib,json,shutil
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'docs/art/compare/r9-after';STORE=ROOT/'docs/store/screenshots';OUT=ROOT/'docs/evidence/r9-art'
def read(p):return json.loads(p.read_text(encoding='utf8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    m=read(SOURCE/'manifest.json');budget=read(OUT/'export-budget.json');base=read(OUT/'baseline.json')
    assert m['status']=='VERIFIED' and len(m['views'])==10 and not m['failures']
    assert m['pck_sha256']==budget['pck_sha256']==sha(ROOT/'deliverables/web/game.pck')
    m['base_commit']=base['commit'];m['source_fingerprint']=budget['source_fingerprint']
    (SOURCE/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    images=[];actions=[];pacing=[]
    for view in m['views']:
        size=(view['pixels']['width'],view['pixels']['height'])
        if 'frame_pacing' in view:pacing.append(dict(pixels=list(size),**view['frame_pacing']))
        if size[0] in [1290,2064]:
            for row in view['shots']+view['inspections']:
                p=SOURCE/row['file'];assert sha(p)==row['sha256'] and Image.open(p).size==size
                shutil.copy2(p,STORE/p.name);images.append(p.name)
            frames=view['clock_seal'];assert len(frames)==3
            action=frames[2];name=f'{size[0]}x{size[1]}-seal-action.png'
            shutil.copy2(SOURCE/action['file'],STORE/name);images.append(name)
            actions.append(dict(file=name,source=(SOURCE/action['file']).relative_to(ROOT).as_posix(),sha256=action['sha256'],elapsed_ms=action['elapsed_ms'],method=action['method']))
        if size==(390,844):
            row=next(x for x in view['shots'] if x['file'].endswith('-street.png'));art=row['state']['art'];im=Image.open(SOURCE/row['file'])
            for key in ['hero','mei']:
                head,feet=art[key+'_head'],art[key+'_feet'];height=abs(feet[1]-head[1]);cx=(head[0]+feet[0])/2
                # The diagnostic head uses a conservative 1.70m reference; leave
                # room for Mei's 1.1 visual scale rather than cropping her crown.
                bounds=(max(0,int(cx-height*.34)),max(0,int(head[1]-height*.15-5)),min(im.width,int(cx+height*.34)),min(im.height,int(feet[1]+5)))
                crop=im.crop(bounds);crop.thumbnail((64,64),Image.Resampling.LANCZOS);tile=Image.new('RGB',(64,64),'#16181d');tile.paste(crop,((64-crop.width)//2,(64-crop.height)//2));tile.save(OUT/(key+'-64px.png'))
            im.resize((195,422),Image.Resampling.LANCZOS).save(OUT/'street-list-thumbnail.png')
    # Retained character art is remeasured from actual alpha, not copied claims.
    import numpy as np
    gates={}
    for name in ['ayuan-waist','meiqing-waist']:
        a=np.array(Image.open(ROOT/f'godot/assets/art/r9/{name}.png').convert('RGBA'));rgb=a[:,:,:3][a[:,:,3]>128]/255
        v=rgb.max(1);s=(v-rgb.min(1))/np.maximum(v,1e-6)
        g=dict(value_mean=float(v.mean()),near_black=float((v<.15).mean()),saturation_mean=float(s.mean()),low_saturation=float((s<.15).mean()))
        g['pass']=.30<=g['value_mean']<=.75 and g['near_black']<.35 and g['saturation_mean']>=.32 and g['low_saturation']<.20
        assert g['pass'];gates[name]=g
    (OUT/'retained-portrait-gates.json').write_text(json.dumps(dict(status='VERIFIED',scope='Actual R9 waist portrait alpha only; not a 3D per-object mask measurement',characters=gates),indent=2)+'\n')
    STORE.joinpath('manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    perf=dict(status='BLOCKED' if any(p['p95_median']>18 for p in pacing) else 'EXECUTED',threshold_ms=18,environment='並發載量測，僅供參考',method='Three browser RAF runs; not native GPU timing or clean machine measurements',runs=pacing)
    OUT.joinpath('performance.json').write_text(json.dumps(perf,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    blockers=['Independent 8/10 rescore and native hardware validation outstanding','3D per-object luminance and saturation mask validation outstanding']
    if perf['status']=='BLOCKED':blockers.append('Concurrent-load RAF p95 exceeds 18 ms')
    status=dict(status='VERIFIED',release_status='BLOCKED',release_blockers=blockers,version='0.13.0',generated_masters=1,runtime_images=2,new_glb=3,tool='image_gen.imagegen',model_slug=None,model_note='Actual model slug not exposed.',store_screenshots=images,action_captures=actions,comparison_manifest='docs/art/compare/r9-after/manifest.json',before='docs/art/compare/r9-before/',report='docs/CODEX_RESPONSE_R9_ART.md',remaining='docs/art/R9_MISSING_3D.md',pck_sha256=m['pck_sha256'],scope='Actual Godot Web captures; no native iOS device or independent score claim')
    STORE.joinpath('R9_STATUS.json').write_text(json.dumps(status,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    # These exact manifests are hashed by the final audit; preserve LF bytes in
    # Git as well as on Windows instead of relying on checkout conversion.
    for path in [SOURCE/'manifest.json',STORE/'manifest.json']:
        path.write_bytes(path.read_bytes().replace(b'\r\n',b'\n'))
    print(json.dumps(dict(status='VERIFIED',store_screenshots=len(images),pacing=[{'pixels':p['pixels'],'p95_median':p['p95_median']} for p in pacing])))
if __name__=='__main__':main()
