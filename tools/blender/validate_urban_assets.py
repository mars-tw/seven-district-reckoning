"""Validate original urban GLBs, textures, portable sources and source Web budget."""
import json, struct, hashlib
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
MODEL=ROOT/'godot/assets/models'
TEXTURE=ROOT/'godot/assets/textures/urban'
QA=ROOT/'qa/art/urban'
manifest=json.loads((QA/'urban-manifest.json').read_text(encoding='utf-8'))
checks=[]
def check(ok,label): checks.append({'pass':bool(ok),'label':label})

for asset in manifest['assets']:
    p=ROOT/asset['path'];blob=p.read_bytes()
    magic,version,length=struct.unpack_from('<III',blob)
    json_length,json_kind=struct.unpack_from('<II',blob,12)
    document=json.loads(blob[20:20+json_length])
    check(magic==0x46546C67 and version==2 and length==len(blob),asset['name']+': real GLB envelope')
    check(hashlib.sha256(blob).hexdigest()==asset['sha256'],asset['name']+': recorded hash')
    check(len(document.get('materials',[]))<=8,asset['name']+': <=8 materials')
    triangles=0
    for mesh in document.get('meshes',[]):
        for primitive in mesh['primitives']:
            check(primitive.get('mode',4)==4,asset['name']+': triangles')
            accessor=document['accessors'][primitive['indices']]
            triangles+=accessor['count']//3
    check(0<triangles<20000,asset['name']+': <20000 triangles')
    check(triangles==asset['triangles'],asset['name']+': measured triangle manifest')
    check((ROOT/asset['source']).is_file(),asset['name']+': Blender source exists')
    check(not any('C:/Users/' in str(v) or 'C:\\Users\\' in str(v) for node in document.get('nodes',[]) for v in node.get('extras',{}).values()),asset['name']+': no private paths in GLB extras')
    check(all('uri' not in image or not Path(image['uri']).is_absolute() for image in document.get('images',[])),asset['name']+': portable images')

all_png=list(TEXTURE.glob('*.png'))+list(MODEL.glob('urban*_*.png'))
for p in all_png:
    with Image.open(p) as im: check(max(im.size)<=256,p.name+': <=256 px')
runtime_files=list(MODEL.glob('urban*.glb'))+all_png
total=sum(p.stat().st_size for p in runtime_files)
check(total<8*1024*1024,'complete urban runtime source including extracted images <8 MiB')
check(len(manifest['assets'])==6,'six original kit assets')
report={'status':'VERIFIED' if all(c['pass'] for c in checks) else 'FAILED','passed':sum(c['pass'] for c in checks),'failed':sum(not c['pass'] for c in checks),'runtime_source_bytes':total,'runtime_file_count':len(runtime_files),'checks':checks,'limitations':'Source Web file budget is measured before Godot PCK compression and GPU upload. This does not measure actual browser frame rate.'}
(QA/'urban-validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='checks'},indent=2))
raise SystemExit(0 if report['status']=='VERIFIED' else 1)
