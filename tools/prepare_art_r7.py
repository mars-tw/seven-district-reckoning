"""Retain generated masters, segment cutouts on CPU and audit derivatives."""
import argparse, hashlib, json
from pathlib import Path
import numpy as np
from PIL import Image, ImageEnhance
from rembg import remove, new_session

ROOT=Path(__file__).resolve().parents[1]
MASTER=ROOT/'assets/art/r7'
RUNTIME=ROOT/'godot/assets/art/r7'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--sources-json',type=Path,required=True);args=parser.parse_args()
    inputs=json.loads(args.sources_json.read_text(encoding='utf8'))
    MASTER.mkdir(parents=True,exist_ok=True);RUNTIME.mkdir(parents=True,exist_ok=True)
    session=new_session('isnet-general-use',providers=['CPUExecutionProvider'])
    masters=[];outputs=[]
    def save(im,name,source,size,alpha=False):
        im=im.resize(size,Image.Resampling.LANCZOS)
        p=RUNTIME/(name+('.png' if alpha else '.webp'))
        if alpha:
            a=np.array(im.convert('RGBA')).copy();a[a[:,:,3]<4,3]=0;a[a[:,:,3]==0,:3]=0;im=Image.fromarray(a)
            im.save(p,optimize=True)
        else:im.convert('RGB').save(p,quality=84,method=6)
        record=dict(id=name,source_id=source,path=p.relative_to(ROOT).as_posix(),size=list(im.size),sha256=sha(p),bytes=p.stat().st_size,decoded_rgba_bytes=im.width*im.height*4)
        if alpha:
            a=np.array(im);rgb=a[:,:,:3][a[:,:,3]>128]/255;v=rgb.max(1);s=(v-rgb.min(1))/np.maximum(v,1e-6)
            record['alpha']=dict(corners=[int(a[y,x,3]) for x,y in [(0,0),(-1,0),(0,-1),(-1,-1)]],occupancy=float((a[:,:,3]>128).mean()),transparent_rgb_zero=bool((a[:,:,:3][a[:,:,3]==0]==0).all()))
            if 'portrait' in name:
                record['character_gate']=dict(value_mean=float(v.mean()),near_black=float((v<.15).mean()),saturation_mean=float(s.mean()),low_saturation=float((s<.15).mean()))
                g=record['character_gate'];g['pass']=.30<=g['value_mean']<=.75 and g['near_black']<.35 and g['saturation_mean']>=.32 and g['low_saturation']<.20
                assert g['pass'],(name,g)
            assert record['alpha']['corners']==[0]*4
        outputs.append(record)
    for name,source in inputs.items():
        source=Path(source);im=Image.open(source)
        retained=MASTER/(name+'.webp');im.save(retained,lossless=True,method=6,exact=True)
        masters.append(dict(id=name,path=retained.relative_to(ROOT).as_posix(),sha256=sha(retained),generated_png_sha256=sha(source),size=list(im.size)))
        if 'portrait' in name:
            # Remove residual glow, retain actual opaque subject and decontaminate RGB.
            clean=remove(im.convert('RGB'),session=session,alpha_matting=True,alpha_matting_foreground_threshold=235,alpha_matting_background_threshold=15,alpha_matting_erode_size=8)
            clean=ImageEnhance.Color(clean).enhance(1.10)
            clean.getchannel('A').save(MASTER/(name+'-mask.png'))
            clean.save(MASTER/(name+'-cutout.png'),optimize=True)
            bbox=clean.getchannel('A').point(lambda x:255 if x>30 else 0).getbbox();clean=clean.crop(bbox)
            # True above-knee composition. No lower legs exist in this image.
            canvas=Image.new('RGBA',(clean.width+40,clean.height+20));canvas.alpha_composite(clean,(20,0))
            save(canvas,name,name,(512,768),True)
        elif name=='cast-turnaround':
            im.save(ROOT/'docs/art/character-sheets/r7-cast-turnaround.png')
        elif name=='street-material-atlas':
            w,h=im.size
            for i,key in enumerate(['street-asphalt','warm-plaster']):
                cell=im.crop((i*w//2,0,(i+1)*w//2,h))
                save(cell,key,name,(768,768))
        elif name=='case-atlas':
            w,h=im.size
            for i,key in enumerate(['icon-chain','icon-phone','icon-receipt','case-panel']):
                cell=im.crop((i%2*w//2,i//2*h//2,(i%2+1)*w//2,(i//2+1)*h//2)).convert('RGB')
                if i==3:
                    cell=remove(cell,session=session)
                    bbox=cell.getchannel('A').point(lambda x:255 if x>32 else 0).getbbox()
                    cell=cell.crop(bbox)
                    canvas=Image.new('RGBA',(cell.width+8,cell.height+8));canvas.alpha_composite(cell,(4,4))
                    save(canvas,key,name,(640,320),True)
                else:
                    cell=remove(cell,session=session)
                    save(cell,key,name,(128,128),True)
        elif name=='app-icon':save(im,name,name,(512,512))
        elif name=='title-logo':save(im,name,name,(1024,342))
        else:save(im,name,name,(1536,864))
    report=dict(status='VERIFIED',version='0.11.0',tool='image_gen.imagegen',model_slug=None,model_note='Actual model slug not exposed; not inferred.',generated_master_count=len(masters),runtime_image_count=len(outputs),masters=masters,outputs=outputs,license='CC BY 4.0 to the extent applicable; project original generated art',postprocess='CPU isnet-general-use rembg alpha matting; transparent RGB zero; retained mask and cutout; LANCZOS; WebP Q84 for opaque artwork. No invented normal or ORM maps.',runtime_bytes=sum(r['bytes'] for r in outputs),decoded_rgba_bytes=sum(r['decoded_rgba_bytes'] for r in outputs))
    for folder in [MASTER,RUNTIME]:(folder/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    prompts=json.loads((ROOT/'docs/art/PROMPTS.json').read_text(encoding='utf8'));prompts['round7']=json.loads((MASTER/'generation-prompts.json').read_text(encoding='utf8'))
    (ROOT/'docs/art/PROMPTS.json').write_text(json.dumps(prompts,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps({k:report[k] for k in ['status','generated_master_count','runtime_image_count','runtime_bytes']}))

if __name__=='__main__':main()
