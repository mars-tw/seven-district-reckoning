"""Check the actual Taiwan kit GLBs, Blender sources, PBR images and budget."""
import json, struct, hashlib
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
QA=ROOT/'qa/art/taiwan'
document=json.loads((QA/'taiwan-manifest.json').read_text(encoding='utf-8'))
checks=[]
def check(ok,label):checks.append({'pass':bool(ok),'label':label})

check(document==json.loads((ROOT/'godot/data/taiwan_asset_manifest.json').read_text(encoding='utf-8')),'source and runtime metadata match')
check(len(document['assets'])==13,'13 original authored asset families')
for asset in document['assets']:
    path=ROOT/asset['path'];blob=path.read_bytes();magic,version,length=struct.unpack_from('<III',blob)
    json_length,json_kind=struct.unpack_from('<II',blob,12);gltf=json.loads(blob[20:20+json_length]);name=asset['name']
    check(magic==0x46546c67 and version==2 and length==len(blob),name+': binary GLTF envelope')
    check(hashlib.sha256(blob).hexdigest()==asset['sha256'],name+': independently measured SHA256')
    triangles=0;uvs=True;pbr=True
    for mesh in gltf.get('meshes',[]):
        for primitive in mesh['primitives']:
            triangles+=gltf['accessors'][primitive['indices']]['count']//3
            uvs=uvs and 'TEXCOORD_0' in primitive['attributes'] and 'NORMAL' in primitive['attributes']
    for material in gltf.get('materials',[]):
        pbr=pbr and 'pbrMetallicRoughness' in material
    check(triangles==asset['triangles'] and 0<triangles<12000,name+': real index triangle budget')
    check(uvs and pbr,name+': UV normals and PBR data present')
    check(len(gltf.get('materials',[]))==asset['materials'] and asset['materials']<=8,name+': <=8 authored material surfaces')
    check((ROOT/asset['source']).is_file(),name+': editable Blender source present')
    check(asset['license']=='CC0-1.0' and all(node.get('extras',{}).get('license','CC0-1.0')=='CC0-1.0' for node in gltf.get('nodes',[])),name+': original asset dedication retained')
    check(not any(s in json.dumps(gltf) for s in ['C:/Users/','C:\\\\Users\\\\']),name+': no private machine paths in GLTF')
    check(all('uri' not in im for im in gltf.get('images',[])),name+': self-contained embedded PBR image buffers')
    preview=QA/(name+'_preview.png')
    with Image.open(preview) as im:check(im.width==800 and im.height==600,name+': actual Blender Cycles preview file')
    for center,size in asset['collision_boxes']:check(len(center)==3 and len(size)==3 and min(size)>0,name+': metric authored collision envelope')

runtime_images=list((ROOT/'godot/assets/textures/taiwan').glob('*.png'))+list((ROOT/'godot/assets/models').glob('tw*_*.png'))
for path in runtime_images:
    with Image.open(path) as im:check(max(im.size)<=128,path.name+': <=128px runtime PBR texture')
total=sum((ROOT/a['path']).stat().st_size for a in document['assets'])+sum(p.stat().st_size for p in runtime_images)
check(total<10*1024*1024,'all GLBs and Godot extracted/source texture copies stay below 10 MiB')

# Contact sheet is explicitly labelled as asset art review, not gameplay.
sheet=Image.new('RGB',(1200,1030),(33,42,43));draw=ImageDraw.Draw(sheet)
for i,asset in enumerate(document['assets']):
    x=(i%4)*300;y=(i//4)*250
    with Image.open(QA/(asset['name']+'_preview.png')) as im:sheet.paste(im.resize((300,225)),(x,y+22))
    draw.text((x+10,y+4),asset['name'],fill=(232,223,199))
draw.text((16,1010),'Original Blender asset reviews. Not gameplay or surveyed Taichung imagery.',fill=(235,227,206))
sheet.save(QA/'taiwan-kit-contact.jpg',quality=88)
report={'status':'VERIFIED' if all(c['pass'] for c in checks) else 'FAILED','passed':sum(c['pass'] for c in checks),'failed':sum(not c['pass'] for c in checks),'runtime_source_bytes_including_Godot_extracted_images':total,'asset_count':13,'texture_max_px':128,'checks':checks,'limitations':'Validation measures asset files and topology, not browser frame rate or complete delivery/character game systems.'}
(QA/'taiwan-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='checks'},ensure_ascii=False,indent=2))
raise SystemExit(0 if report['status']=='VERIFIED' else 1)
