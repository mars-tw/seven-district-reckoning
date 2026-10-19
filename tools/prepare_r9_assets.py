"""Audit the actual generated cutout and retained derivative, without inferring a model."""
import hashlib,json,struct
from pathlib import Path
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 outputs=[]
 for name,source in [('meiqing-waist','assets/art/r9/meiqing-waist.webp'),('ayuan-waist','godot/assets/art/r7/ayuan-portrait.png')]:
  p=ROOT/f'godot/assets/art/r9/{name}.png';im=Image.open(p).convert('RGBA');a=np.array(im)
  rgb=a[:,:,:3][a[:,:,3]>128]/255;v=rgb.max(1);s=(v-rgb.min(1))/np.maximum(v,1e-6)
  gate=dict(value_mean=float(v.mean()),near_black=float((v<.15).mean()),saturation_mean=float(s.mean()),low_saturation=float((s<.15).mean()))
  gate['pass']=.3<=gate['value_mean']<=.75 and gate['near_black']<.35 and gate['saturation_mean']>=.32 and gate['low_saturation']<.20
  assert gate['pass'],gate
  outputs.append(dict(id=name,path=p.relative_to(ROOT).as_posix(),sha256=sha(p),size=list(im.size),bytes=p.stat().st_size,source=source,source_sha256=sha(ROOT/source),character_gate=gate,alpha_corners=[int(a[y,x,3]) for x,y in [(0,0),(-1,0),(0,-1),(-1,-1)]],alpha_occupancy=float((a[:,:,3]>128).mean()),transparent_rgb_zero=bool((a[:,:,:3][a[:,:,3]==0]==0).all()),decoded_rgba_bytes=im.width*im.height*4))
 report=dict(status='VERIFIED',version='0.13.0',tool='image_gen.imagegen',model_slug=None,model_note='Actual model slug not exposed.',generated_masters=1,runtime_images=2,outputs=outputs,postprocess='Actual tool alpha retained; near-zero alpha and transparent RGB cleaned; crop to visible waist with side margin; LANCZOS to maximum 768 px; optimized PNG. Ayuan is a declared crop of the retained R7 portrait, not a new generation.',runtime_bytes=sum(x['bytes'] for x in outputs),decoded_rgba_bytes=sum(x['decoded_rgba_bytes'] for x in outputs),license='CC BY 4.0 to the extent applicable; retained project-generated art policy')
 for folder in ['assets/art/r9','godot/assets/art/r9']:(ROOT/folder/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
 prompts=ROOT/'docs/art/PROMPTS.json';data=json.loads(prompts.read_text(encoding='utf8'));data['round9']=json.loads((ROOT/'assets/art/r9/generation-prompts.json').read_text(encoding='utf8'));prompts.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
 models=json.loads((ROOT/'assets/art/r9/models.json').read_text())
 for row in models['outputs']:
  blob=(ROOT/row['path']).read_bytes();d=json.loads(blob[20:20+struct.unpack_from('<I',blob,12)[0]])
  row['exported_triangles']=sum(d['accessors'][p['indices']]['count']//3 for m in d['meshes'] for p in m['primitives'])
  row['animation_names']=[x['name'] for x in d.get('animations',[])]
  row['material_batches']=sum(len(m['primitives']) for m in d['meshes'])
  assert not d.get('buffers',[{}])[0].get('uri')
  if row['id']!='mei-workbench':assert sorted(row['animation_names'])==sorted(['idle','walk','run','attack','hit','drive','pedal','knockdown'])
 (ROOT/'assets/art/r9/models.json').write_text(json.dumps(models,indent=2)+'\n')
 print(json.dumps(dict(status='VERIFIED',runtime_images=2,runtime_bytes=report['runtime_bytes'],model_triangles=[(x['id'],x['exported_triangles']) for x in models['outputs']])))
if __name__=='__main__':main()
