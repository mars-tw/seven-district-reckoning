"""Validate exported files, animation contracts and measured character renders."""
import json,struct,hashlib,colorsys
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'godot/assets/models';QA=ROOT/'qa/art'
expected={'idle','walk','run','attack','hit','pedal','drive','knockdown'}
checks=[]
for p in sorted(OUT.glob('*.glb')):
 b=p.read_bytes();magic,version,size=struct.unpack_from('<III',b);ln,kind=struct.unpack_from('<II',b,12);doc=json.loads(b[20:20+ln]);clips={a.get('name'):a for a in doc.get('animations',[])}
 def values(index):
  acc=doc['accessors'][index];view=doc['bufferViews'][acc['bufferView']];components={'SCALAR':1,'VEC3':3,'VEC4':4}[acc['type']]
  start=28+ln+view.get('byteOffset',0)+acc.get('byteOffset',0);stride=view.get('byteStride',components*4)
  return [struct.unpack_from('<'+'f'*components,b,start+i*stride) for i in range(acc['count'])]
 record={'asset':p.stem,'valid_glb':magic==0x46546c67 and version==2 and size==len(b),'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest(),'mesh_count':len(doc.get('meshes',[])),'material_count':len(doc.get('materials',[])),'clips':list(clips),'nodes':[n.get('name') for n in doc.get('nodes',[])],'private_extra_paths':[]}
 for n in doc.get('nodes',[]):
  for k,v in n.get('extras',{}).items():
   if isinstance(v,str) and ('C:/Users/' in v or 'C:\\Users\\' in v):record['private_extra_paths'].append(k)
 if p.stem in ('hero','guard','civilian'):
  joints=set(doc.get('skins',[{}])[0].get('joints',[]));record['joint_count']=len(joints);record['clips_complete']=expected<=set(clips)
  record['clips_target_skeleton']=all(any(c['target']['node'] in joints for c in a['channels']) for a in clips.values())
  record['clip_durations_seconds']={name:max(doc['accessors'][s['input']].get('max',[0])[0] for s in a['samplers']) for name,a in clips.items()}
  record['rotation_value_ranges']={}
  for name,a in clips.items():
   ranges=[]
   for ch in a['channels']:
    if ch['target']['path']!='rotation' or ch['target']['node'] not in joints:continue
    sampler=a['samplers'][ch['sampler']];vs=values(sampler['output'])
    if sampler.get('interpolation')=='CUBICSPLINE':vs=vs[1::3]
    ranges.append(max(max(row[i] for row in vs)-min(row[i] for row in vs) for i in range(4)))
   record['rotation_value_ranges'][name]=max(ranges,default=0)
  record['dynamic_clips_move_bones']=all(record['rotation_value_ranges'].get(name,0)>.001 for name in ['idle','walk','run','attack','hit','pedal','knockdown'])
 checks.append(record)
gates=[]
for name in ('hero','guard','civilian'):
 p=QA/(name+'_front.png');im=Image.open(p).convert('RGBA');pixels=[tuple(v/255 for v in px[:3]) for px in im.getdata() if px[3]>220]
 lum=sum(.2126*r+.7152*g+.0722*b for r,g,b in pixels)/len(pixels)
 sats=[colorsys.rgb_to_hsv(*px)[1] for px in pixels];vs=[max(px) for px in pixels]
 gate={'character':name,'mean_luminance':lum,'mean_saturation':sum(sats)/len(sats),'near_black_fraction':sum(v<.15 for v in vs)/len(vs),'low_saturation_fraction':sum(s<.32 for s in sats)/len(sats)}
 gate['numeric_gate_pass']=.30<=lum<=.75 and gate['near_black_fraction']<.35 and gate['mean_saturation']>=.32 and gate['low_saturation_fraction']<.20
 gates.append(gate)
 im.thumbnail((64,64),Image.Resampling.LANCZOS);im.save(QA/(name+'_64.png'))
result={'status':'VERIFIED' if all(c['valid_glb'] and not c['private_extra_paths'] for c in checks) else 'FAILED','assets':checks,'character_gates':gates,'note':'Numerical file/clip evidence. Visual likeness, animation feel and gameplay performance require actual scene checks.'}
(QA/'asset-validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'status':result['status'],'asset_count':len(checks),'characters':[c for c in checks if c['asset'] in ('hero','guard','civilian')],'character_gates':gates},ensure_ascii=False,indent=2))
