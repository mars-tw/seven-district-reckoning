import bpy,json,collections
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[2]
out={}
for name,f in [('hero',root/'assets/source/kenney/mini-characters/Models/GLB format/character-male-a.glb'),('car',root/'assets/source/kenney/car-kit/Models/GLB format/sedan.glb'),('bicycle',root/'assets/source/poly-pizza/bicycle-google.glb'),('tower',root/'assets/source/kenney/city-kit-commercial/Models/GLB format/building-skyscraper-a.glb')]:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(f))
 rig=next((o for o in bpy.data.objects if o.type=='ARMATURE'),None)
 if rig:
  rig.animation_data.action=bpy.data.actions.get('static')
  bpy.context.scene.frame_set(0)
 ds=bpy.context.evaluated_depsgraph_get()
 objs=[]
 for o in bpy.data.objects:
  d={'name':o.name,'type':o.type,'hide_render':o.hide_render,'parent':o.parent.name if o.parent else None,'dimensions':list(o.dimensions),'matrix':[list(x) for x in o.matrix_world]}
  if o.type=='MESH':
   ev=o.evaluated_get(ds);me=ev.to_mesh();vs=[ev.matrix_world@v.co for v in me.vertices]
   d.update({'vertices':len(vs),'bounds':[[min(v[i] for v in vs),max(v[i] for v in vs)] for i in range(3)],'uv':[(a.name) for a in o.data.uv_layers]})
   if name=='hero' and o.data.uv_layers:
    d['uv_regions']=dict(collections.Counter(tuple(round(v,3) for v in u.uv) for u in o.data.uv_layers[0].data))
    d['uv_regions']=[(str(k),v) for k,v in d['uv_regions'].items()]
   ev.to_mesh_clear()
  objs.append(d)
 out[name]=objs
(root/'qa/art/geometry-inspection.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(out,ensure_ascii=False))

