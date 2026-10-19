"""Retain generated masters and verify the actual alpha; no painted substitutions."""
import hashlib, json
from pathlib import Path
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'godot/assets/art/r8'
MASTER=ROOT/'assets/art/r8'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    rows=[]
    for record in json.loads((ROOT/'.audit-tmp/r8-image-sources.json').read_text(encoding='utf8')):
        p=Path(record['source']);im=Image.open(p)
        retained=MASTER/(record['id']+'-master.webp');im.save(retained,lossless=True,exact=True)
        size={'paper':(768,1152),'sky':(2048,1024),'stamp':(256,256)}[record['id']]
        if record['id']=='stamp':
            im=im.convert('RGBA');assert im.getextrema()[3][0]==0, 'Generated transparent alpha required'
            bbox=im.getchannel('A').point(lambda x:255 if x>8 else 0).getbbox();im=im.crop(bbox)
            im.thumbnail((236,236),Image.Resampling.LANCZOS)
            canvas=Image.new('RGBA',size);canvas.alpha_composite(im,((256-im.width)//2,(256-im.height)//2));im=canvas
            a=np.array(im);a[a[:,:,3]==0,:3]=0;im=Image.fromarray(a)
            out=OUT/'stamp-applicator.png';im.save(out,optimize=True)
        else:
            im=im.convert('RGB').resize(size,Image.Resampling.LANCZOS)
            out=OUT/('clean-paper.webp' if record['id']=='paper' else 'dusk-sky.webp');im.save(out,quality=86,method=6)
        rows.append(dict(id=record['id'],master=retained.relative_to(ROOT).as_posix(),master_sha256=sha(retained),generated_png_sha256=sha(p),path=out.relative_to(ROOT).as_posix(),sha256=sha(out),size=list(im.size),bytes=out.stat().st_size,decoded_rgba_bytes=im.width*im.height*4,alpha_corners=[im.getpixel((x,y))[3] for x,y in [(0,0),(-1,0),(0,-1),(-1,-1)]] if im.mode=='RGBA' else None))
    report=dict(status='VERIFIED',version='0.12.0',tool='image_gen.imagegen',model_slug=None,model_note='Actual model slug not exposed.',generated_masters=len(rows),runtime_images=len(rows),outputs=rows,runtime_bytes=sum(x['bytes'] for x in rows),license='CC BY 4.0 to the extent applicable; original generated project artwork',postprocess='Retain lossless masters; WebP Q86; transparent object preserves native generated alpha, alpha-zero RGB cleared, cropped and padded; no invented normal/ORM.')
    for path in [MASTER/'manifest.json',OUT/'manifest.json']:path.write_text(json.dumps(report,indent=2)+'\n')
    prompts=ROOT/'docs/art/PROMPTS.json';data=json.loads(prompts.read_text(encoding='utf8'));data['round8']=json.loads((MASTER/'generation-prompts.json').read_text(encoding='utf8'));prompts.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps(dict(status='VERIFIED',runtime_images=len(rows),runtime_bytes=report['runtime_bytes'])))
if __name__=='__main__':main()
