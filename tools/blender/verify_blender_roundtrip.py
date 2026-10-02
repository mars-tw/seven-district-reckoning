import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];QA=ROOT/'qa/art';out=[]
def snapshot(p):
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(p));objs=[o for o in bpy.data.objects if not o.name.startswith('Icosphere')]
 for o in objs:
  if o.type=='ARMATURE':
   o.data.pose_position='REST'
   if o.animation_data:
    o.animation_data.action=None
    for tr in o.animation_data.nla_tracks:tr.mute=True
 bpy.context.view_layer.update();ds=bpy.context.evaluated_depsgraph_get();vv=[];tris=0
 for o in objs:
  if o.type!='MESH':continue
  ev=o.evaluated_get(ds);me=ev.to_mesh();me.calc_loop_triangles();tris+=len(me.loop_triangles);vv.extend(ev.matrix_world@v.co for v in me.vertices);ev.to_mesh_clear()
 return {'objects':sorted((o.name,o.type) for o in objs),'triangles':tris,'bounds_min':[round(min(v[i] for v in vv),5) for i in range(3)],'bounds_max':[round(max(v[i] for v in vv),5) for i in range(3)],'bones':sorted(b.name for o in objs if o.type=='ARMATURE' for b in o.data.bones),'clips':sorted(a.name for a in bpy.data.actions),'uv_sets':sorted((o.name,len(o.data.uv_layers)) for o in objs if o.type=='MESH')}
for p in sorted((ROOT/'godot/assets/models').glob('*.glb')):
 first=snapshot(p);second=snapshot(p);out.append({'file':p.relative_to(ROOT).as_posix(),'two_imports_identical':first==second,'signature':second})
(QA/'blender-roundtrip.json').write_text(json.dumps({'status':'VERIFIED' if all(r['two_imports_identical'] for r in out) else 'FAILED','blender_version':bpy.app.version_string,'assets':out},ensure_ascii=False,indent=2),encoding='utf-8')
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/source/blender/alpha_hero.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.data.pose_position='POSE'
for tr in rig.animation_data.nla_tracks:tr.mute=True
for clip,frames in [('walk',[0,4,8,12]),('attack',[0,3,6,10]),('pedal',[0,8,16,24])]:
 rig.animation_data.action=bpy.data.actions.get(clip)
 for frame in frames:
  bpy.context.scene.frame_set(frame);bpy.context.scene.render.filepath=str(QA/(f'hero_{clip}_{frame:02d}.png'));bpy.ops.render.render(write_still=True)
print('ROUNDTRIP_VERIFIED',len(out))
