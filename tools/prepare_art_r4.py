"""Rebuild R4 runtime art from retained lossless generated masters.

Initial import: --sources-json <local JSON of id/path records>.
Subsequent builds need no credentials or generation services.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / 'assets/art/r4'
RUNTIME = ROOT / 'godot/assets/art/r4'
EVIDENCE = ROOT / 'docs/evidence/r4-art'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def metrics(image):
    im = image.convert('RGBA')
    pixels = np.asarray(im)
    visible = pixels[:, :, 3] > 127
    hsv = np.asarray(im.convert('RGB').convert('HSV')) / 255.0
    s, v = hsv[:, :, 1][visible], hsv[:, :, 2][visible]
    result = dict(value_mean=float(v.mean()), near_black_fraction=float((v < .15).mean()),
                  saturation_mean=float(s.mean()), low_saturation_fraction=float((s < .15).mean()))
    result['pass'] = (.30 <= result['value_mean'] <= .75 and result['near_black_fraction'] < .35
                      and result['saturation_mean'] >= .32 and result['low_saturation_fraction'] < .20)
    return result


def clean_alpha(im):
    a = np.array(im.convert('RGBA'))
    a[a[:, :, 3] == 0, :3] = 0
    return Image.fromarray(a)


def tile_edges(im):
    # Blend matching edge pairs, preserving the generated interior.
    a = np.array(im.convert('RGB')).astype(float)
    span = 20
    for i in range(span):
        weight = (1 - i / span) * .5
        left, right = a[:, i].copy(), a[:, -1-i].copy()
        a[:, i] = left * (1-weight) + right * weight
        a[:, -1-i] = right * (1-weight) + left * weight
    for i in range(span):
        weight = (1 - i / span) * .5
        top, bottom = a[i].copy(), a[-1-i].copy()
        a[i] = top * (1-weight) + bottom * weight
        a[-1-i] = bottom * (1-weight) + top * weight
    return Image.fromarray(np.uint8(np.clip(a, 0, 255)))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--sources-json', type=Path)
    args = parser.parse_args()
    for p in (MASTER, RUNTIME, EVIDENCE): p.mkdir(parents=True, exist_ok=True)
    prompts = json.loads((ROOT/'docs/art/PROMPTS.json').read_text(encoding='utf8'))
    imported = {x['id']: Path(x['path']) for x in json.loads(args.sources_json.read_text(encoding='utf8'))} if args.sources_json else {}
    old = json.loads((MASTER/'manifest.json').read_text(encoding='utf8')) if (MASTER/'manifest.json').exists() else {}
    assets, outputs = [], []
    def save(im, name, source_id, png=False):
        p = RUNTIME / (name + ('.png' if png else '.webp'))
        im.save(p, optimize=True) if png else im.save(p, quality=83, method=6)
        record = {'id': name, 'source_id': source_id, 'path': p.relative_to(ROOT).as_posix(),
                  'sha256': sha(p), 'bytes': p.stat().st_size, 'size': list(im.size), 'mode': im.mode}
        if im.mode == 'RGBA':
            a = np.asarray(im)[:, :, 3]
            record['alpha'] = {'corner_max': int(max(a[0,0],a[0,-1],a[-1,0],a[-1,-1])),
                               'occupancy': float((a > 127).mean()), 'has_partial': bool(((a > 0)&(a < 255)).any()),
                               'clear_rgb_zero': bool((np.asarray(im)[:,:,:3][a == 0] == 0).all())}
        if 'portrait' in name: record['character_gate'] = metrics(im)
        outputs.append(record)
        return im
    for job in prompts['assets']:
        name = job['id']; master = MASTER/(name+'.webp')
        if name in imported:
            Image.open(imported[name]).save(master, lossless=True, method=6, exact=True)
            original_hash = sha(imported[name])
        else:
            original_hash = next(x['generated_png_sha256'] for x in old['assets'] if x['id'] == name)
        im = Image.open(master)
        assets.append({'id':name,'master':master.relative_to(ROOT).as_posix(),'sha256':sha(master),
                       'generated_png_sha256':original_hash,'size':list(im.size),'bytes':master.stat().st_size,
                       'prompt_version':'r4.1','tool':'image_gen.imagegen','model_slug':None,
                       'license':'CC-BY-4.0','source_type':'AI-generated original, no reference images supplied'})
        if name.endswith('portrait'):
            im = ImageEnhance.Color(im).enhance(1.12)
            im = ImageEnhance.Brightness(im).enhance(1.10)
            im.thumbnail((640,640),Image.Resampling.LANCZOS)
            save(clean_alpha(im),name,name,True)
            mask=im.getchannel('A'); mask.save(MASTER/(name+'-mask.png'),optimize=True)
        elif name == 'evidence-icons':
            for i, icon in enumerate(['chain','phone','receipt','folder']):
                w,h=im.size; x,y=i%2,i//2
                crop=im.crop((x*w//2,y*h//2,(x+1)*w//2,(y+1)*h//2))
                crop=crop.crop(crop.getbbox()); crop.thumbnail((112,112),Image.Resampling.LANCZOS)
                cell=Image.new('RGBA',(128,128)); cell.alpha_composite(crop,((128-crop.width)//2,(128-crop.height)//2))
                save(clean_alpha(cell),'icon-'+icon,name,True)
        elif name == 'title-logo':
            im.thumbnail((768,512),Image.Resampling.LANCZOS)
            save(clean_alpha(im),name,name,True)
        elif name == 'app-icon':
            im=im.resize((512,512),Image.Resampling.LANCZOS); save(im,name,name,True)
        else:
            im.thumbnail((1024,1536) if name=='title-street' else (960,640) if name=='evidence-still' else (512,512),Image.Resampling.LANCZOS)
            if name in ['street-asphalt','arcade-tile']: im=tile_edges(im)
            save(im.convert('RGB'),name,name)
    manifest={'status':'EXECUTED','version':'0.8.0','generated_master_count':len(assets),'runtime_image_count':len(outputs),
              'tool':'image_gen.imagegen','model_slug':None,'model_note':prompts['model_note'],
              'license':'CC-BY-4.0','prompts':'docs/art/PROMPTS.json','assets':assets,'outputs':outputs,
              'postprocess':'lossless WebP source preservation; LANCZOS resize; portraits saturation x1.12 and brightness x1.10; true alpha preserved, zero-alpha RGB cleared; icon atlas split; material edge-pair blend 20px; RGB WebP q83',
              'master_bytes':sum(x['bytes'] for x in assets),'runtime_bytes':sum(x['bytes'] for x in outputs),
              'estimated_runtime_rgba_bytes':sum(x['size'][0]*x['size'][1]*4 for x in outputs)}
    manifest['alpha_masks'] = [{'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size}
                               for p in sorted(MASTER.glob('*-mask.png'))]
    (MASTER/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    (RUNTIME/'manifest.json').write_text(json.dumps({k:v for k,v in manifest.items() if k!='assets'},ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    sheet=Image.new('RGB',(640,360),'#F1E8D5'); draw=ImageDraw.Draw(sheet)
    for i,name in enumerate(['ayuan-portrait','meiqing-portrait']):
        im=Image.open(RUNTIME/(name+'.png'))
        # A face crop and an honest full-bust thumbnail, both exactly 64 pixels.
        face=im.crop((int(im.width*.34),0,int(im.width*.78),int(im.height*.44))).resize((64,64),Image.Resampling.LANCZOS)
        bust=im.resize((64,64),Image.Resampling.LANCZOS)
        sheet.paste(face,(40+i*300,64),face); sheet.paste(bust,(140+i*300,64),bust)
        draw.text((40+i*300,145),name,fill='#16181D')
        big=im.resize((160,160),Image.Resampling.LANCZOS); sheet.paste(big,(60+i*300,185),big)
    sheet.save(EVIDENCE/'portrait-64px.png')
    print(json.dumps({'generated':len(assets),'runtime':len(outputs),'runtime_bytes':manifest['runtime_bytes'],
                      'master_bytes':manifest['master_bytes'],'character_gates':{x['id']:x['character_gate'] for x in outputs if 'character_gate' in x}},indent=2))


if __name__ == '__main__': main()
