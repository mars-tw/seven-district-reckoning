"""Round six: fitted cloth, bob silhouette and readable solid garage tools."""
import bpy,bmesh,math,json,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'godot/assets/models/r9';SOURCE=ROOT/'assets/source/blender/r9'
OUT.mkdir(parents=True,exist_ok=True);SOURCE.mkdir(parents=True,exist_ok=True)
(ROOT/'assets/art/r9').mkdir(parents=True,exist_ok=True)
rows=[]
def material(name,color,metal=0,rough=.85):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 return m
def skin_mesh(name,vertices,faces,mat,rig,bone='pelvis'):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
 obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);mesh.materials.append(mat)
 for p in mesh.polygons:p.use_smooth=True
 group=obj.vertex_groups.new(name=bone);group.add(list(range(len(vertices))),1,'REPLACE')
 obj.parent=rig;mod=obj.modifiers.new('PreservedCharacterSkin','ARMATURE');mod.object=rig
 return obj
def export(name):
 for image in bpy.data.images:
  if image.type=='IMAGE' and image.packed_file:image.filepath='//'+image.name+'.png'
 bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'.blend')))
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_frame_range=False,export_skins=True)
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];p=OUT/(name+'.glb')
 rows.append(dict(id=name,source=(SOURCE/(name+'.blend')).relative_to(ROOT).as_posix(),path=p.relative_to(ROOT).as_posix(),triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest(),source_sha256=hashlib.sha256((SOURCE/(name+'.blend')).read_bytes()).hexdigest()))

# Retain the licensed real anatomical mesh and every original animation.
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/source/blender/mei_human.blend'))
body=bpy.data.objects['TailoredHuman'];rig=bpy.data.objects['HumanSkeleton']
bm=bmesh.new();bm.from_mesh(body.data)
hair=[f for f in bm.faces if body.data.materials[f.material_index].name.endswith('_Hair')]
hair += [f for f in bm.faces if body.data.materials[f.material_index].name.endswith('_Details') and 1.10 < f.calc_center_median().z < 1.40 and abs(f.calc_center_median().x) < .11]
bmesh.ops.delete(bm,geom=hair,context='FACES');bm.to_mesh(body.data);bm.free()
hair_mat=material('Mei_ChinLengthBob',(.035,.027,.022),0,.46)
verts=[];faces=[];n=32;rings=12
for j in range(rings):
 t=j/(rings-1)
 for i in range(n):
  a=i*math.tau/n
  # Face opens toward -Y. The asymmetrical left lock reaches the jaw.
  front=math.sin(a)<-.25
  bottom=1.63 if front else 1.48
  if front and math.cos(a)<-.30:bottom=1.51
  z=1.735+(bottom-1.735)*t
  radius=(math.sqrt(max(.001,1-((z-1.62)/.13)**2)) if z>1.62 else 1.0)*(.99+.018*math.cos(a*7))
  verts.append((.143*math.cos(a)*radius,-.028+.135*math.sin(a)*radius,z))
for j in range(rings-1):
 for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
faces.append(tuple(reversed(range(n))))
skin_mesh('MeiAsymmetricBob',verts,faces,hair_mat,rig,'head')
canvas=material('Mei_VermilionCanvas',(.43,.09,.038),0,.94)
verts=[];faces=[];n=12
for j,(z,width,y) in enumerate([(1.37,.135,-.145),(1.19,.17,-.158),(1.03,.18,-.153),(.83,.205,-.13),(.64,.23,-.125)]):
 for i in range(n+1):
  s=i/n*2-1;x=s*width
  surface=[v.co.y for v in body.data.vertices if abs(v.co.x-x)<.045 and abs(v.co.z-z)<.045]
  front=min(surface) if surface else y
  verts.append((x,front-.018-.010*math.cos(s*math.pi*3)*(j/4),z+.008*math.sin(s*4)))
for j in range(4):
 for i in range(n):faces.append((j*(n+1)+i,j*(n+1)+i+1,(j+1)*(n+1)+i+1,(j+1)*(n+1)+i))
apron=skin_mesh('MeiFittedApron',verts,faces,canvas,rig)
group=apron.vertex_groups.new(name='spine_03')
for i,v in enumerate(verts):
 w=max(0,min(1,(v[2]-1.02)/.25))
 apron.vertex_groups['pelvis'].add([i],1-w,'REPLACE');group.add([i],w,'REPLACE')
solid=apron.modifiers.new('CanvasHemThickness','SOLIDIFY');solid.thickness=.008
for side in [-1,1]:
 skin_mesh('MeiApronShoulderStrap',[(side*.105-.015,-.18,1.36),(side*.105+.015,-.18,1.36),(side*.105+.015,-.10,1.48),(side*.105-.015,-.10,1.48)],[(0,1,2,3)],canvas,rig,'spine_03')
rag_mat=material('Mei_YellowRag',(.63,.37,.045))
verts=[(.15+i*.023,-.17-.013*math.sin(i*math.pi*.6),1.02-j*.095+.010*math.cos(i*1.5)) for j in range(4) for i in range(5)]
faces=[(j*5+i,j*5+i+1,(j+1)*5+i+1,(j+1)*5+i) for j in range(3) for i in range(4)]
skin_mesh('MeiFoldedYellowRag',verts,faces,rag_mat,rig)
for p in body.data.polygons:p.use_smooth=True
# Re-key only Mei's idle forearm: a real bent-elbow wrench-holding pose,
# with breathing retained from the original clip. Other seven clips survive.
idle=next(t.strips[0].action for t in rig.animation_data.nla_tracks if t.name=='idle')
for track in rig.animation_data.nla_tracks:track.mute=True
rig.animation_data.action=idle
def aim(bone,direction):
 pb=rig.pose.bones[bone];rest=rig.data.bones[bone].matrix_local
 q=(rest.to_3x3()@Vector((0,1,0))).rotation_difference(Vector(direction).normalized())@rest.to_quaternion()
 bpy.context.view_layer.update();pb.matrix=Matrix.LocRotScale(pb.head.copy(),q,Vector((1,1,1)));bpy.context.view_layer.update()
for frame in range(0,61,3):
 bpy.context.scene.frame_set(frame)
 aim('upperarm_r',(-.25,-.12,-1));aim('lowerarm_r',(.12,-.72,.72));aim('hand.r',(0,-.3,.95))
 for name in ['upperarm_r','lowerarm_r','hand.r']:
  rig.pose.bones[name].keyframe_insert(data_path='rotation_quaternion',frame=frame)
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks:track.mute=False
export('mei_human')

bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/source/blender/r7/ayuan-tailored.blend'))
rig=bpy.data.objects['HumanSkeleton']
for m in bpy.data.materials:
 if m.name=='Courier_OrangeCanvas':
  m.diffuse_color=(.43,.205,.075,1);m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=m.diffuse_color
for o in list(bpy.context.scene.objects):
 if o.type=='MESH' and o.name.startswith(('SewnBag','SewnFolded','BagLower')):
  # Sculpt the existing skinned bag into flexible canvas instead of an orange box.
  for v in o.data.vertices:
   p=v.co;p.y+=.011*math.sin((p.x-.1)*24)*math.sin((p.z-.82)*math.pi/.34);p.z+=.009*math.sin(p.x*17)
  sub=o.modifiers.new('SoftCanvasSubdivision','SUBSURF');sub.levels=1;sub.render_levels=1
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_move_up(modifier=sub.name)
  for p in o.data.polygons:p.use_smooth=True
strap=material('Courier_ContinuousSling',(.095,.065,.035))
for back in [False,True]:
 verts=[];faces=[]
 for j in range(15):
  t=j/14;x=-.16+.42*t;z=1.53-.53*t;y=(.10 if back else -.17)+(.07 if back else -.015)*math.sin(t*math.pi)
  for dx in [-.025,.025]:verts.append((x+dx,y,z))
 for j in range(14):faces.append((j*2,j*2+1,j*2+3,j*2+2))
 obj=skin_mesh('ContinuousBackSling' if back else 'ContinuousChestSling',verts,faces,strap,rig)
 g=obj.vertex_groups.new(name='spine_03')
 for i,v in enumerate(verts):
  w=max(0,min(1,(v[2]-1.02)/.3));obj.vertex_groups['pelvis'].add([i],1-w,'REPLACE');g.add([i],w,'REPLACE')
 solid=obj.modifiers.new('StrapThickness','SOLIDIFY');solid.thickness=.009
export('hero_human')

# Re-author the existing editable tool assembly at readable physical thickness.
code=(ROOT/'tools/blender/build_art_r7.py').read_text(encoding='utf8').split('# Original CC0 MakeHuman')[0]
code=code.replace("ROOT/'godot/assets/models/r7'","ROOT/'godot/assets/models/r9'").replace("ROOT/'assets/source/blender/r7'","ROOT/'assets/source/blender/r9'")
code=code.replace('rows = []','rows = workshop_rows')
code=code.replace(".017,metal)",".029,metal)").replace(".036,.012,metal)",".052,.022,metal)").replace(".015,metal)",".027,metal)")
code=code.replace("range(17)","range(9)").replace('x*.15','x*.30')
code=code.replace("(.56,.61,.62)","(.68,.65,.56)")
code=code.replace("box('ToolBackboard',(0,.39,1.72),(2.7,.07,.87)","box('ToolBackboard',(0,.41,1.72),(2.7,.10,.87)")
workshop_rows=[];scope={'__file__':__file__,'workshop_rows':workshop_rows};exec(compile(code,__file__,'exec'),scope)
rows.extend(workshop_rows)
for row in rows:
 row['source_sha256']=hashlib.sha256((ROOT/row['source']).read_bytes()).hexdigest()
report=dict(status='EXECUTED',blender=bpy.app.version_string,license='CC0-1.0; original project tailoring and workshop; anatomical rig derived from retained licensed MakeHuman source',outputs=rows)
(ROOT/'assets/art/r9/models.json').write_text(json.dumps(report,indent=2)+'\n')
print('R9_MODELS '+json.dumps(report))
