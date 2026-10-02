import bpy,json,bmesh
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root/'godot/assets/models/bicycle.glb'))
o=next(o for o in bpy.data.objects if o.type=='MESH');me=o.data
bm=bmesh.new();bm.from_mesh(me);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);bm.to_mesh(me);bm.free();me.update()
parent=list(range(len(me.vertices)))
def find(x):
 while parent[x]!=x:parent[x]=parent[parent[x]];x=parent[x]
 return x
for e in me.edges:parent[find(e.vertices[0])]=find(e.vertices[1])
groups={}
for v in me.vertices:groups.setdefault(find(v.index),[]).append(o.matrix_world@v.co)
out=[]
for g in groups.values():
 lo=Vector(tuple(min(v[i] for v in g) for i in range(3)));hi=Vector(tuple(max(v[i] for v in g) for i in range(3)))
 out.append({'n':len(g),'center':list((lo+hi)/2),'dimensions':list(hi-lo),'bounds_min':list(lo),'bounds_max':list(hi)})
(root/'qa/art/bike-islands.json').write_text(json.dumps(sorted(out,key=lambda x:-x['n']),indent=2),encoding='utf-8')
print(json.dumps(sorted(out,key=lambda x:-x['n'])[:20],indent=2))

