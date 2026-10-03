"""Independent saved-source and GLB contract checks for v0.3 humans."""
import bpy, json, math, struct
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
QA=ROOT/'qa/art/v03-human'
manifest=json.loads((QA/'manifest.json').read_text(encoding='utf-8'))
checks=[];rows=[]

def check(name,passed,evidence):
 checks.append({'name':name,'passed':bool(passed),'evidence':evidence})
 if not passed:print('FAIL',name,evidence,flush=True)

def bounds():
 points=[];ds=bpy.context.evaluated_depsgraph_get()
 for obj in bpy.context.scene.objects:
  if obj.type!='MESH' or obj.get('qa_only') or obj.name.startswith('Icosphere'):continue
  ev=obj.evaluated_get(ds);mesh=ev.to_mesh();points.extend(ev.matrix_world@v.co for v in mesh.vertices);ev.to_mesh_clear()
 return [min(v[i] for v in points) for i in range(3)],[max(v[i] for v in points) for i in range(3)]

for row in manifest['characters']:
 name=row['name'];bpy.ops.wm.open_mainfile(filepath=str(ROOT/row['blend']))
 rig=bpy.data.objects['HumanSkeleton'];ad=rig.animation_data
 for tr in ad.nla_tracks:tr.mute=True
 check(name+'/anatomical_bones',len(rig.data.bones)==53,len(rig.data.bones))
 check(name+'/right_hand_contract','hand.r' in rig.data.bones,list(rig.data.bones.keys()))
 check(name+'/sockets',all(n in bpy.data.objects for n in ['HandToolSocket','SeatHipSocket']),True)
 check(name+'/no_absolute_images',all(not im.filepath or im.filepath.startswith('//') for im in bpy.data.images),[im.filepath for im in bpy.data.images])
 rig.data.pose_position='REST';bpy.context.view_layer.update();lo,hi=bounds()
 check(name+'/foot_floor',abs(lo[2])<.015,lo[2])
 check(name+'/metre_height',1.66<hi[2]<1.84,hi[2])
 rig.data.pose_position='POSE'
 actions={clip:bpy.data.actions.get(clip) for clip in ['idle','walk','run','attack','hit','drive','pedal','knockdown']}
 check(name+'/eight_source_actions',all(actions.values()),list(actions))
 positions={};knee=0
 for clip,a in actions.items():
  ad.action=a;samples=[]
  for f in [float(a.frame_range[0]),float(a.frame_range[1]/4),float(a.frame_range[1]/2),float(a.frame_range[1]*3/4),float(a.frame_range[1])]:
   bpy.context.scene.frame_set(int(f));bpy.context.view_layer.update()
   samples.append({bn:list(rig.pose.bones[bn].tail) for bn in ['hand.r','calf_r','head']})
   if clip=='drive':
    upper=(rig.pose.bones['thigh_r'].tail-rig.pose.bones['thigh_r'].head).normalized();lower=(rig.pose.bones['calf_r'].tail-rig.pose.bones['calf_r'].head).normalized()
    knee=math.degrees(upper.angle(lower))
  positions[clip]=samples
  bag=a.layers[0].strips[0].channelbags[0]
  curves=[fc.data_path for fc in bag.fcurves]
  check(name+'/'+clip+'/bone_channels',len(curves)>30 and all('pose.bones' in p for p in curves),len(curves))
  if clip not in ['drive','idle']:
   moved=max((Vector(s[bn])-Vector(samples[0][bn])).length for s in samples[1:] for bn in ['hand.r','calf_r','head'])
   check(name+'/'+clip+'/real_pose_change',moved>.025,moved)
 check(name+'/drive_knee_articulation',knee>45,knee)
 ad.action=actions['attack'];bpy.context.scene.frame_set(12);bpy.context.view_layer.update()
 distance=(bpy.data.objects['HandToolSocket'].matrix_world.translation-rig.pose.bones['hand.r'].head).length
 check(name+'/animated_tool_socket',distance<.12,distance)
 path=ROOT/row['path'];bb=path.read_bytes();n=struct.unpack_from('<I',bb,12)[0];glb=json.loads(bb[20:20+n]);names=[a['name'] for a in glb['animations']]
 check(name+'/glb_animation_names',set(names)==set(actions),names)
 check(name+'/glb_budget',row['triangles']<=18000 and row['bytes']<3*1024*1024 and row['materials']<=6,{k:row[k] for k in ['triangles','bytes','materials']})
 check(name+'/glb_all_texture_uv',all('TEXCOORD_0' in p['attributes'] for m in glb['meshes'] for p in m['primitives']),True)
 check(name+'/glb_embedded_textures',all('bufferView' in im and 'uri' not in im for im in glb['images']),len(glb['images']))
 check(name+'/draw_call_budget',sum(len(m['primitives']) for m in glb['meshes'])<=6,sum(len(m['primitives']) for m in glb['meshes']))
 bone_nodes=set(glb['skins'][0]['joints'])
 check(name+'/glb_skeletal_animation',all(any(ch['target']['node'] in bone_nodes for ch in a['channels']) for a in glb['animations']),True)
 rows.append({'name':name,'rest_bounds_min':lo,'rest_bounds_max':hi,'drive_knee_degrees':knee,'attack_socket_to_hand_m':distance,'sampled_pose_endpoints':positions})
 # Re-import the actual exported artifact. The source file alone cannot
 # prove that skinning, sockets and metre scale survived glTF serialization.
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(path))
 imported=[o for o in bpy.data.objects if o.type=='ARMATURE'];ir=imported[0];ir.data.pose_position='REST'
 if ir.animation_data:
  ir.animation_data.action=None
  for tr in ir.animation_data.nla_tracks:tr.mute=True
 bpy.context.view_layer.update();gl,gh=bounds()
 check(name+'/glb_roundtrip_skeleton',len(imported)==1 and len(ir.data.bones)==53,len(ir.data.bones))
 check(name+'/glb_roundtrip_scale',max(abs(gh[i]-hi[i]) for i in range(3))<.015,{'source':hi,'imported':gh})
 check(name+'/glb_roundtrip_sockets',all(n in bpy.data.objects for n in ['HandToolSocket','SeatHipSocket']),True)

report={'blender_version':bpy.app.version_string,'checks':len(checks),'passed':sum(c['passed'] for c in checks),'failed':sum(not c['passed'] for c in checks),'validation':checks,'characters':rows}
(QA/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('HUMAN_VALIDATION',report['passed'],'PASS',report['failed'],'FAIL',flush=True)
if report['failed']:raise RuntimeError('Human asset verification failed; inspect validation.json')
