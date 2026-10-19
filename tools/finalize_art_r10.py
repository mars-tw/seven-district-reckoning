"""Copy only hash-verified original Web frames to store evidence; derive separate QA."""
import hashlib,json,shutil
from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'docs/art/compare/r10-after';STORE=ROOT/'docs/store/screenshots';OUT=ROOT/'docs/evidence/r10-art'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    m=json.loads((SOURCE/'manifest.json').read_text(encoding='utf8'))
    budget=json.loads((OUT/'export-budget.json').read_text(encoding='utf8'))
    assert m['status']=='VERIFIED' and len(m['views'])==10 and not m['failures']
    assert m['pck_sha256']==budget['pck_sha256']==sha(ROOT/'deliverables/web/game.pck')
    m['base_commit']=json.loads((OUT/'baseline.json').read_text(encoding='utf8'))['commit']
    m['source_fingerprint']=budget['source_fingerprint']
    images=[];actions=[];subject={}
    for view in m['views']:
        size=(view['pixels']['width'],view['pixels']['height'])
        if size[0] in [1290,2064]:
            for row in view['shots']+view['inspections']:
                p=SOURCE/row['file'];assert Image.open(p).size==size and sha(p)==row['sha256']
                shutil.copy2(p,STORE/p.name);images.append(p.name)
            frames=view['clock_seal'];assert len(frames)==3 and len({x['sha256'] for x in frames})==3
            action=frames[0];name=f'{size[0]}x{size[1]}-seal-action.png'
            shutil.copy2(SOURCE/action['file'],STORE/name);images.append(name)
            actions.append(dict(file=name,source='docs/art/compare/r10-after/'+action['file'],elapsed_ms=action['elapsed_ms'],sha256=action['sha256'],method=action['method']))
        if size==(390,844):
            row=next(x for x in view['shots'] if x['file'].endswith('-street.png'))
            im=Image.open(SOURCE/row['file']);art=row['state']['art']
            subject={k:art[k] for k in ['hero_height_px','mei_height_px']};assert min(subject.values())>=40
            for key in ['hero','mei']:
                head,feet=art[key+'_head'],art[key+'_feet'];height=abs(feet[1]-head[1]);cx=(head[0]+feet[0])/2
                bounds=(max(0,int(cx-height*.34)),max(0,int(head[1]-height*.15-5)),min(im.width,int(cx+height*.34)),min(im.height,int(feet[1]+5)))
                crop=im.crop(bounds);crop.thumbnail((64,64),Image.Resampling.LANCZOS)
                tile=Image.new('RGB',(64,64),'#16181d');tile.paste(crop,((64-crop.width)//2,(64-crop.height)//2));tile.save(OUT/(key+'-64px.png'))
            im.resize((195,422),Image.Resampling.LANCZOS).save(OUT/'street-list-thumbnail.png')
            # Explicitly marked QA mask, never a store screenshot or generated scene.
            masked=im.copy();ImageDraw.Draw(masked).rectangle((131,240,303,326),fill='#16181d');masked.save(OUT/'street-without-sign-QA.png')
    gates={}
    for name in ['ayuan-waist','meiqing-waist']:
        a=np.asarray(Image.open(ROOT/f'godot/assets/art/r9/{name}.png').convert('RGBA'));rgb=a[:,:,:3][a[:,:,3]>128]/255
        v=rgb.max(1);s=(v-rgb.min(1))/np.maximum(v,1e-6)
        g=dict(value_mean=float(v.mean()),near_black=float((v<.15).mean()),saturation_mean=float(s.mean()),low_saturation=float((s<.15).mean()))
        g['pass']=.30<=g['value_mean']<=.75 and g['near_black']<.35 and g['saturation_mean']>=.32 and g['low_saturation']<.20
        assert g['pass'];gates[name]=g
    (OUT/'retained-portrait-gates.json').write_text(json.dumps(dict(status='VERIFIED',scope='Actual retained 2D portrait alpha; not a 3D runtime object mask',characters=gates),indent=2)+'\n')
    m['subject_height_css_px']=subject
    text=json.dumps(m,ensure_ascii=False,indent=2)+'\n'
    (SOURCE/'manifest.json').write_text(text,encoding='utf8');(STORE/'manifest.json').write_text(text,encoding='utf8')
    status=dict(status='VERIFIED',release_status='BLOCKED',version='0.14.0',round=7,repo_round=10,generated_masters=1,runtime_images=1,new_glb=3,tool='image_gen.imagegen',model_slug=None,model_note='Actual model slug not exposed by tool',store_screenshots=images,action_captures=actions,pck_sha256=m['pck_sha256'],comparison_manifest='docs/art/compare/r10-after/manifest.json',report='docs/CODEX_RESPONSE_R10_ART.md',scope='Actual original-size Godot Web frames, no native iOS or independent score claim',release_blockers=['Independent 8/10 rescore outstanding','Clean-machine p95 and native hardware validation outstanding','Runtime 3D per-object colour masks outstanding'])
    (STORE/'R10_STATUS.json').write_text(json.dumps(status,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps(dict(status='VERIFIED',store_screenshots=len(images),subject=subject)))
if __name__=='__main__':main()
