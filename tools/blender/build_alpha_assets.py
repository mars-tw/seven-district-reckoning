"""Rework downloaded licensed meshes in Blender. Run with Blender 5.2 --background.

No generated humanoid/city block bodies. Sources are retained with provenance.
Only small bespoke accessories (face, backpack, badge, tools) use authored geometry.
"""
import bpy, math, json, struct, hashlib, colorsys, io_scene_gltf2, bmesh
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'godot/assets/models'; SRC=ROOT/'assets/source/kenney'
BLEND=ROOT/'assets/source/blender'; QA=ROOT/'qa/art'
REPORT=[]
PAL=[(.035,.30,.70,1),(.085,.20,.36,1),(.98,.34,.045,1),(.72,.40,.24,1),(.14,.023,.008,1),(.85,.92,1,1),(.025,.055,.09,1),(.48,.13,.11,1)]

def reset():
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.context.scene.unit_settings.system='METRIC'
 bpy.context.scene.unit_settings.scale_length=1
 bpy.context.scene.render.fps=30

def mat(name,color,metal=0,rough=.55):
 m=bpy.data.materials.new(name);m.use_nodes=True
 n=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 n.inputs['Base Color'].default_value=color
 n.inputs['Roughness'].default_value=rough;n.inputs['Metallic'].default_value=metal
 m.diffuse_color=color
 return m

def meshes(): return [o for o in bpy.context.scene.objects if o.type=='MESH' and not o.get('qa_only')]
def bounds(objects=None):
 objects=objects or meshes();ds=bpy.context.evaluated_depsgraph_get();vv=[]
 for o in objects:
  if o.type!='MESH':continue
  ev=o.evaluated_get(ds);me=ev.to_mesh();vv.extend(ev.matrix_world@v.co for v in me.vertices);ev.to_mesh_clear()
 return Vector(tuple(min(v[i] for v in vv) for i in range(3))),Vector(tuple(max(v[i] for v in vv) for i in range(3)))

def import_src(pack,file):
 p=next((SRC/pack).rglob(file+'.glb'))
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(p))
 objs=list(set(bpy.data.objects)-before)
 # glTF importer creates custom bone display helper; it is not a source render mesh.
 for o in objs[:]:
  if o.name.startswith('Icosphere') and o.parent is None:
   bpy.data.objects.remove(o,do_unlink=True);objs.remove(o)
 for o in objs:o['source_mesh']=p.relative_to(ROOT).as_posix();o['source_license']='CC0-1.0'
 return objs

def transform_objects(objs,matrix):
 for o in objs:
  if o.parent not in objs:o.matrix_world=matrix@o.matrix_world
 bpy.context.view_layer.update()

def normalize(objs,target,axis=2,rotation=0):
 if rotation:transform_objects(objs,Matrix.Rotation(rotation,4,'Z'))
 lo,hi=bounds(objs);sc=target/(hi-lo)[axis]
 offset=Vector((-(lo.x+hi.x)/2,-(lo.y+hi.y)/2,-lo.z))
 transform_objects(objs,Matrix.Scale(sc,4)@Matrix.Translation(offset))
 return sc

def marker(name,loc):
 o=bpy.data.objects.new(name,None);bpy.context.scene.collection.objects.link(o);o.location=loc;o.empty_display_size=.1
 return o

def export(name,source,clips=None,notes=''):
 bpy.context.view_layer.update()
 objs=[o for o in bpy.context.scene.objects if o.name in bpy.context.view_layer.objects and not o.name.startswith('tmpParent') and not o.get('qa_only') and o.type not in ('CAMERA','LIGHT')]
 bpy.ops.object.select_all(action='DESELECT')
 for o in objs:o.select_set(True)
 if objs:bpy.context.view_layer.objects.active=objs[0]
 props=bpy.ops.export_scene.gltf.get_rna_type().properties
 kw={'filepath':str(OUT/(name+'.glb')),'use_selection':True,'export_extras':True,'export_yup':True,'export_cameras':False,'export_lights':False}
 if 'export_format' in props:
  opts=[i.identifier for i in props['export_format'].enum_items]
  if not opts:
   opts=[i[0] for i in io_scene_gltf2.get_format_items(None,bpy.context)]
  kw['export_format']=next(i for i in opts if i=='GLB')
 if 'export_animation_mode' in props and clips:
  opts=[i.identifier for i in props['export_animation_mode'].enum_items]
  kw['export_animation_mode']=next(i for i in opts if i=='NLA_TRACKS')
 if 'export_force_sampling' in props:kw['export_force_sampling']=True
 if 'export_frame_range' in props:kw['export_frame_range']=False
 if 'export_animations' in props:kw['export_animations']=bool(clips)
 bpy.ops.export_scene.gltf(**kw)
 for im in bpy.data.images:
  if not im.filepath:continue
  p=Path(bpy.path.abspath(im.filepath))
  if p.is_file() and p.is_relative_to(ROOT):im.filepath=bpy.path.relpath(str(p),start=str(BLEND))
 bpy.ops.wm.save_as_mainfile(filepath=str(BLEND/('alpha_'+name+'.blend')))
 rigs=[o for o in objs if o.type=='ARMATURE'];old_positions=[o.data.pose_position for o in rigs]
 for o in rigs:
  valid=[i.identifier for i in o.data.bl_rna.properties['pose_position'].enum_items];o.data.pose_position=next(i for i in valid if i=='REST')
 bpy.context.view_layer.update()
 lo,hi=bounds()
 ds=bpy.context.evaluated_depsgraph_get();tri=0
 for o in meshes():
  ev=o.evaluated_get(ds);me=ev.to_mesh();me.calc_loop_triangles();tri+=len(me.loop_triangles);ev.to_mesh_clear()
 for o,old in zip(rigs,old_positions):o.data.pose_position=old
 report={'name':name,'path':(OUT/(name+'.glb')).relative_to(ROOT).as_posix(),'source':source,'bounds_min':list(lo),'bounds_max':list(hi),'dimensions':list(hi-lo),'triangles':tri,'materials':len({m.name for o in meshes() for m in o.data.materials if m}),'clips':clips or [],'notes':notes,'sha256':hashlib.sha256((OUT/(name+'.glb')).read_bytes()).hexdigest()}
 REPORT[:]=[r for r in REPORT if r['name']!=name];REPORT.append(report)
 (QA/'asset-manifest.json').write_text(json.dumps(REPORT,ensure_ascii=False,indent=2),encoding='utf-8')
 print('ASSET_DONE '+name,flush=True)

def uv_palette(name,palette):
 im=bpy.data.images.new(name+'_palette',width=128,height=8,alpha=True)
 im.pixels=[min(1,v*1.30) if c<3 else v for y in range(8) for x in range(128) for c,v in enumerate(palette[min(7,x//16)])]
 im.filepath_raw=str(ROOT/'godot/assets/textures'/(name+'_palette.png'))
 opts=[i.identifier for i in im.bl_rna.properties['file_format'].enum_items];im.file_format=next(i for i in opts if i=='PNG');im.save();im.pack()
 m=mat(name+'_palette_mapped',(1,1,1,1));n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=im;n.interpolation='Closest'
 m.node_tree.links.new(n.outputs['Color'],next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Base Color'])
 shader=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');shader.inputs['Roughness'].default_value=.90
 specular=shader.inputs.get('Specular IOR Level')
 if specular:specular.default_value=.06
 return m

def palette_mesh(o,m,index):
 o.data.materials.clear();o.data.materials.append(m)
 uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
 for p in o.data.polygons:
  p.material_index=0
  ix=index(p) if callable(index) else index
  for li in p.loop_indices:uv.data[li].uv=((ix+.5)/8,.5)

def sphere(name,loc,scale,material,sub=2):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,location=loc)
 o=bpy.context.object;o.name=name;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.data.materials.append(material)
 for p in o.data.polygons:p.use_smooth=True
 return o

def curve(name,points,radius,material):
 data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D';data.bevel_depth=radius;data.bevel_resolution=2
 s=data.splines.new('POLY');s.points.add(len(points)-1)
 for p,v in zip(s.points,points):p.co=(*v,1)
 o=bpy.data.objects.new(name,data);bpy.context.scene.collection.objects.link(o);o.data.materials.append(material)
 bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o.select_set(False)
 return o

def rounded_box(name,loc,dims,material,bevel=.04):
 # Accessory tailoring only, never a replacement body or city silhouette.
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=dims
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 mod=o.modifiers.new('TailoredRoundedEdges','BEVEL');mod.width=bevel;mod.segments=3
 bpy.ops.object.modifier_apply(modifier=mod.name);o.data.materials.append(material)
 return o

def bind(o,rig,bone):
 world=o.matrix_world.copy();o.parent=rig;o.matrix_world=world
 # Rigid weights remain attached to true skeleton throughout imported clips.
 vg=o.vertex_groups.new(name=bone);vg.add([v.index for v in o.data.vertices],1,'REPLACE')
 a=o.modifiers.new('HumanSkeleton','ARMATURE');a.object=rig

def setup_render(name,views=False):
 sc=bpy.context.scene
 try:sc.render.engine='BLENDER_EEVEE'
 except TypeError: pass
 sc.render.resolution_x=512;sc.render.resolution_y=512;sc.render.resolution_percentage=100;sc.render.film_transparent=True
 opts=[i.identifier for i in sc.render.image_settings.bl_rna.properties['file_format'].enum_items];sc.render.image_settings.file_format=next(i for i in opts if i=='PNG')
 sc.world=bpy.data.worlds.new('CoolSky');sc.world.use_nodes=True
 bg=next(n for n in sc.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs[0].default_value=(.18,.25,.36,1);bg.inputs[1].default_value=.75
 lo,hi=bounds();target=(lo+hi)/2;size=max(hi-lo)*1.4
 lights=[]
 for lname,loc,energy,col in [('WarmKey',(4,-5,7),1400,(1,.86,.70)),('CoolFill',(-4,-1,5),1100,(.70,.83,1)),('Rim',(1,5,7),1700,(.90,.96,1))]:
  bpy.ops.object.light_add(type='AREA',location=target+Vector(loc)*(size/2));l=bpy.context.object;l.name=lname;l.data.energy=energy*size*size/6;l.data.color=col;l.data.shape='DISK';l.data.size=size*2;l.rotation_euler=(target-l.location).to_track_quat('-Z','Y').to_euler();l['qa_only']=True;lights.append(l)
 bpy.ops.object.camera_add();cam=bpy.context.object;cam.name='QA_Camera';cam['qa_only']=True;cam.data.type='ORTHO';cam.data.ortho_scale=size;sc.camera=cam
 dirs=[('preview',Vector((3,-5,2.3)))]
 if views:dirs=[('front',Vector((0,-6,.15))),('side',Vector((6,0,.15))),('back',Vector((0,6,.15))),('preview',Vector((3,-5,2.3)))]
 for suffix,d in dirs:
  cam.location=target+d.normalized()*size*3;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();sc.render.filepath=str(QA/(name+'_'+suffix+'.png'));bpy.ops.render.render(write_still=True)
 # Saved artist files retain their QA camera, light and version evidence.
 sc.render.filepath=bpy.path.relpath(str(QA/(name+'_preview.png')),start=str(BLEND))
 bpy.ops.wm.save_as_mainfile(filepath=str(BLEND/('alpha_'+name+'.blend')))

def character(name,file,palette):
 reset();objs=import_src('mini-characters',file);rig=next(o for o in objs if o.type=='ARMATURE');rig.name='HumanSkeleton'
 rig.animation_data.action=bpy.data.actions.get('static');bpy.context.scene.frame_set(0)
 # Add actual knee joints to the CC0 rigid-thigh source, repartitioning lower-leg weights.
 body=next(o for o in objs if o.type=='MESH' and 'body' in o.name)
 bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
 for side in ['left','right']:
  leg=rig.data.edit_bones['leg-'+side];shin=rig.data.edit_bones.new('shin-'+side)
  shin.head=(leg.head.x,leg.head.y,.088);shin.tail=(leg.head.x,leg.head.y,.018);shin.parent=leg
 bpy.ops.object.mode_set(mode='OBJECT');rig.select_set(False)
 for side in ['left','right']:
  leg=body.vertex_groups.get('leg-'+side);shin=body.vertex_groups.new(name='shin-'+side)
  for v in body.data.vertices:
   weight=next((g.weight for g in v.groups if g.group==leg.index),0)
   blend=max(0,min(1,(.105-v.co.z)/.065))
   if weight and blend:shin.add([v.index],weight*blend,'REPLACE');leg.add([v.index],weight*(1-blend),'REPLACE')
 # Original source mesh is resized as a single character, retaining its rig and weights.
 normalize(objs,1.75);m=uv_palette(name,palette);sc=1.75/.671325
 body=next(o for o in objs if o.type=='MESH' and 'body' in o.name);head=next(o for o in objs if o.type=='MESH' and 'head' in o.name)
 def body_pal(p):
  vs=[body.data.vertices[i].co for i in p.vertices];c=sum(vs,Vector())/len(vs)
  if c.z<.075:return 2 if name=='hero' else 1
  if c.z<.175:return 1
  if abs(c.x)>.265:return 3
  return 0
 def head_pal(p):
  vs=[head.data.vertices[i].co for i in p.vertices];c=sum(vs,Vector())/len(vs)
  return 4 if c.z>.57 or c.y>.065 else 3
 palette_mesh(body,m,body_pal);palette_mesh(head,m,head_pal)
 # Model face is forward Blender -Y, becoming Godot +Z on GLB export.
 z=1.365 if name!='civilian' else 1.23;y=-.423 if name!='civilian' else -.62
 features=[]
 for x in [-.155,.155]:
  features.append(sphere('EyeWhite', (x,y,z),(.086,.028,.063),m));palette_mesh(features[-1],m,5)
  features.append(sphere('Pupil',(x,y-.022,z),(.037,.013,.042),m));palette_mesh(features[-1],m,6)
  features.append(curve('ExpressiveEyebrow',[(x-.073,y-.005,z+.085),(x,y-.025,z+.108),(x+.073,y-.005,z+.083)],.018,m));palette_mesh(features[-1],m,4)
 features.append(sphere('Nose',(0,y+.008,z-.12),(.068,.045,.047),m));palette_mesh(features[-1],m,3)
 features.append(curve('Mouth',[(-.08,y+.022,z-.215),(0,y-.014,z-.23),(.08,y+.022,z-.215)],.012,m));palette_mesh(features[-1],m,7)
 for o in features:bind(o,rig,'head')
 if name=='hero':
  b=rounded_box('OrangeDeliveryBackpack',(0,.42,.77),(.55,.30,.58),m,.09);palette_mesh(b,m,2);bind(b,rig,'torso')
  pocket=rounded_box('BackpackPocket',(0,.60,.76),(.40,.06,.25),m,.04);palette_mesh(pocket,m,0);bind(pocket,rig,'torso')
  for x in [-.19,.19]:
   o=curve('ShoulderStrap',[(x,.42,1.04),(x,-.15,1.03),(x,-.21,.73),(x,.42,.54)],.035,m);palette_mesh(o,m,2);bind(o,rig,'torso')
  o=curve('JacketZip',[(0,-.205,.55),(0,-.24,.91)],.012,m);palette_mesh(o,m,5);bind(o,rig,'torso')
 elif name=='guard':
  cap=sphere('UniformCap',(0,.01,1.64),(.43,.38,.15),m);palette_mesh(cap,m,0);bind(cap,rig,'head')
  visor=rounded_box('CapVisor',(0,-.33,1.60),(.55,.30,.04),m,.028);palette_mesh(visor,m,1);bind(visor,rig,'head')
  badge=sphere('SecurityBadge',(-.13,-.21,.91),(.045,.016,.068),m);palette_mesh(badge,m,2);bind(badge,rig,'torso')
 else:
  for x in [-.18,.18]:
   o=sphere('HairSideLock',(x,.035,1.21),(.12,.23,.24),m);palette_mesh(o,m,4);bind(o,rig,'head')
 # Keep only named clips and make their NLA identity canonical.
 mapping={'idle':'idle','walk':'walk','sprint':'run','attack-melee-right':'attack','drive':'drive','die':'knockdown'}
 ad=rig.animation_data
 for tr in list(ad.nla_tracks):ad.nla_tracks.remove(tr)
 actions={}
 for old,new in mapping.items():
  a=bpy.data.actions.get(old);a.name=new;actions[new]=a
 # Relaxed idle: CC0 source's arms-out idle is replaced by authored arm-bone motion.
 actions['idle'].name='_source_idle';idle=bpy.data.actions.new('idle');ad.action=idle
 for f in [0,10,20,30,40]:
  bpy.context.scene.frame_set(f)
  for pb in rig.pose.bones:pb.matrix_basis.identity();pb.rotation_mode='QUATERNION'
  phase=f*math.tau/40
  rig.pose.bones['torso'].rotation_quaternion=Quaternion((1,0,0),.018*math.sin(phase))
  rig.pose.bones['head'].rotation_quaternion=Quaternion((0,1,0),.022*math.sin(phase))
  rig.pose.bones['arm-left'].rotation_quaternion=Quaternion((0,0,1),-1.10+.012*math.sin(phase))
  rig.pose.bones['arm-right'].rotation_quaternion=Quaternion((0,0,1),1.10-.012*math.sin(phase))
  for pb in rig.pose.bones:pb.keyframe_insert(data_path='rotation_quaternion',frame=f)
 actions['idle']=idle
 # Preserve original alternating gait, lowering only the arms before adding their swing.
 for clip in ['walk','run']:
  ad.action=actions[clip];samples=[];end=round(actions[clip].frame_range[1])
  for f in range(end+1):
   bpy.context.scene.frame_set(f);samples.append((f,{bn:rig.pose.bones[bn].rotation_quaternion.copy() for bn in ['arm-left','arm-right']}))
  for f,qs in samples:
   for bn,offset in [('arm-left',-1.0),('arm-right',1.0)]:
    pb=rig.pose.bones[bn];pb.rotation_mode='QUATERNION';pb.rotation_quaternion=Quaternion((0,0,1),offset)@qs[bn];pb.keyframe_insert(data_path='rotation_quaternion',frame=f)
 # Authored reaction and pedal cycles use skeleton channels, no object wobble.
 for new in ['hit','pedal']:
  a=bpy.data.actions.new(new);ad.action=a
  for f in ([0,5,11,18] if new=='hit' else list(range(0,31,3))):
   bpy.context.scene.frame_set(f)
   for pb in rig.pose.bones:pb.matrix_basis.identity();pb.rotation_mode='XYZ'
   if new=='hit':
    weight={0:0,5:1,11:.4,18:0}[f]
    rig.pose.bones['torso'].rotation_euler.x=-.38*weight
    rig.pose.bones['head'].rotation_euler.x=-.24*weight
    rig.pose.bones['arm-left'].rotation_euler.y=.40*weight;rig.pose.bones['arm-right'].rotation_euler.y=-.40*weight
   else:
    phase=f*math.tau/30
    rig.pose.bones['torso'].rotation_euler.x=.16
    rig.pose.bones['arm-left'].rotation_euler.x=.42;rig.pose.bones['arm-right'].rotation_euler.x=.42
    for bn,sign in [('leg-left',1),('leg-right',-1)]:rig.pose.bones[bn].rotation_euler.x=.72+sign*.38*math.sin(phase)
    for bn,sign in [('shin-left',1),('shin-right',-1)]:rig.pose.bones[bn].rotation_euler.x=-.85+sign*.40*math.sin(phase)
   for pb in rig.pose.bones:
    authored=pb.rotation_euler.to_quaternion();pb.rotation_mode='QUATERNION';pb.rotation_quaternion=authored;pb.keyframe_insert(data_path='rotation_quaternion',frame=f)
  actions[new]=a
 ad.action=None
 for name_a,a in actions.items():
  tr=ad.nla_tracks.new();tr.name=name_a;strip=tr.strips.new(name_a,int(a.frame_range[0]),a);strip.name=name_a
  tr.mute=False
  if name_a=='knockdown':strip.scale=2.5
 # NLA tracks evaluate together unless solo; render a clean idle rest frame.
 for tr in ad.nla_tracks:tr.mute=True
 ad.action=actions['idle'];bpy.context.scene.frame_set(0)
 rig['clips']=','.join(actions);rig['forward']='Godot +Z';rig['height_m']=1.75;rig['alpha_rig']='Kenney 7-bone source upgraded to 9-bone humanoid with weighted articulated knees'
 hand=marker('HandToolSocket',(.93,-.09,.72));hand_world=hand.matrix_world.copy();hand.parent=rig;hand.parent_type='BONE';hand.parent_bone='arm-left';hand.matrix_world=hand_world
 hand['socket_role']='tool grip follows animated arm-left';marker('SeatHipSocket',(0,0,.46))
 # Feet remain centered at source bone root; max silhouette includes cap/hair/accessories.
 rig.data.pose_position='REST';bpy.context.view_layer.update();lo,hi=bounds();factor=1.75/(hi.z-lo.z)
 transform_objects(list(bpy.context.scene.objects),Matrix.Scale(factor,4)@Matrix.Translation(Vector((0,0,-lo.z))))
 rig.data.pose_position='POSE'
 # Exporter exports muted NLA tracks only with mute=False; deselected action is cleared.
 ad.action=None
 for tr in ad.nla_tracks:tr.mute=False
 export(name,'Kenney Mini Characters CC0; original face/accessory/UV/animations/weighted knees',list(actions),'Shared 9-bone stylized rig; pedal articulated at hip/knee; precise hand/foot IK remains follow-up.')
 for tr in ad.nla_tracks:tr.mute=True
 ad.action=actions['idle'];bpy.context.scene.frame_set(0)
 setup_render(name,True)

def static_source(name,pack,file,target,axis=2,rotate=0,render=True):
 reset();objs=import_src(pack,file);normalize(objs,target,axis,rotate)
 for o in meshes():
  o.name=name+'_'+o.name
  # Apply matrices to static mesh while leaving meaningful wheel pivots intact.
  bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.transform_apply(location=False,rotation=True,scale=True);o.select_set(False)
 if name.startswith('office_tower'):
  lo,hi=bounds();depth=(hi-lo).y
  aw=import_src('city-kit-commercial','detail-overhang-wide');normalize(aw,6,0);transform_objects(aw,Matrix.Translation(Vector((0,-depth/2-.4,3.4))))
  for x in [-2.7,2.7]:
   col=import_src('city-kit-roads','bridge-pillar');normalize(col,3.3);transform_objects(col,Matrix.Translation(Vector((x,-depth/2-.45,0))))
 if name=='server':
  steel=mat('ServerRackSteel',(.055,.12,.18,1),.65,.38);plate=mat('ServerUnitPlate',(.11,.24,.31,1),.55,.44);led=mat('ServerStatusMint',(.12,.95,.56,1),.15,.25)
  lo,hi=bounds();w=(hi-lo).x;d=(hi-lo).y
  for o in meshes():o.data.materials.clear();o.data.materials.append(steel)
  for z in [.48,.99,1.51]:
   rounded_box('RackMountedServer',(0,-d/2+.16,z),(w*.86,.29,.29),plate,.022)
   for ix in range(7):
    curve('VentSlot',[(w*(ix/16-.20),-d/2-.001,z-.10),(w*(ix/16-.20),-d/2-.001,z+.10)],.01,steel)
   for ix in range(2):sphere('StatusLED',(w*.31,-d/2-.015,z-.05+ix*.09),(.018,.012,.018),led)
 if name=='glass':
  steel=mat('PartitionFrame',(.20,.40,.51,1),.65,.34);glass=mat('OpaqueGameGlass',(.10,.48,.61,1),.18,.20)
  for o in meshes():
   o.data.materials.clear();o.data.materials.append(steel);o.data.materials.append(glass)
   for p in o.data.polygons:
    c=o.matrix_world@(sum((o.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices))
    p.material_index=1 if abs(c.x)<.39 and .45<c.z<2.24 else 0
 export(name,'Kenney '+pack+' CC0; scaled/pivot rework')
 if render:setup_render(name)

def lobby():
 reset();floor=import_src('furniture-kit','floorFull');normalize(floor,2,0)
 for ix in range(6):
  for iy in range(5):
   for orig in floor:
    if orig.type!='MESH':continue
    o=orig.copy();o.data=orig.data.copy();bpy.context.scene.collection.objects.link(o);o.location=orig.location+Vector((ix*2-5,iy*2-4,0))
 for o in floor:bpy.data.objects.remove(o,do_unlink=True)
 def place(file,size,loc,rot=0,axis=2):
  ob=import_src('furniture-kit',file);normalize(ob,size,axis,rot);transform_objects(ob,Matrix.Translation(Vector(loc)));return ob
 # Real kit geometry; center circulation remains open.
 place('desk',.90,(0,2.7,0));place('computerScreen',.45,(-.35,2.7,.85));place('chairDesk',1.1,(0,3.7,0),math.pi)
 for x in [-4.4,4.4]:
  place('pottedPlant',1.5,(x,3.8,0));place('pottedPlant',1.5,(x,-3.8,0));place('loungeSofa',1.0,(x,0,0),math.pi/2 if x<0 else -math.pi/2)
 for x in [-5.5,5.5]:
  for y in [-3,0,3]:place('wallWindow',2.8,(x,y,0),math.pi/2,2)
 marker('EntranceSocket',(0,-5,.12));marker('ExitSocket',(0,4.7,.12))
 export('office_lobby','Kenney Furniture Kit CC0; hand arranged open lobby','', '12 x 10 m open floor; walkable center; outer side windows. Floor top height depends source tile, inspect bounds.')
 setup_render('office_lobby')

def car():
 reset();objs=import_src('car-kit','sedan');normalize(objs,4.2,1)
 for o in meshes():
  if 'wheel' in o.name:
   lo,hi=bounds([o]);center=(lo+hi)/2;bpy.context.scene.cursor.location=center;bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');o.select_set(False)
  bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.transform_apply(location=False,rotation=True,scale=True);o.select_set(False)
 marker('DriverSeat',(-.45,.12,.73));marker('PassengerSeat',(.45,.12,.73));marker('ExitLeft',(-1.65,.15,0));marker('ExitRight',(1.65,.15,0))
 export('car','Kenney Car Kit sedan CC0; 4.2m scale/wheel pivots/seat markers')
 setup_render('car')

def bicycle():
 reset();p=ROOT/'assets/source/poly-pizza/bicycle-google.glb';bpy.ops.import_scene.gltf(filepath=str(p));objs=list(bpy.context.scene.objects)
 normalize(objs,1.8,1,-math.pi/2)
 o=next(o for o in objs if o.type=='MESH');bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);bm.to_mesh(o.data);bm.free();o.data.update()
 me=o.data;parent=list(range(len(me.vertices)))
 def find(x):
  while parent[x]!=x:parent[x]=parent[parent[x]];x=parent[x]
  return x
 for e in me.edges:parent[find(e.vertices[0])]=find(e.vertices[1])
 groups={}
 for v in me.vertices:groups.setdefault(find(v.index),[]).append(v.index)
 part_ids={'WheelFront':set(),'WheelRear':set(),'Crank':set()}
 pivots={'WheelFront':Vector((0,-.537,.357)),'WheelRear':Vector((0,.537,.357)),'Crank':Vector((0,.091,.303))}
 for ids in groups.values():
  vv=[me.vertices[i].co for i in ids]
  for pn,pivot in pivots.items():
   radius=.37 if pn.startswith('Wheel') else .175
   if all(abs(v.x)<.105 and math.hypot(v.y-pivot.y,v.z-pivot.z)<=radius for v in vv):part_ids[pn].update(ids);break
 def kept_mesh(source,ids):
  target=source.copy();bb=bmesh.new();bb.from_mesh(target);bb.verts.ensure_lookup_table();bmesh.ops.delete(bb,geom=[v for v in bb.verts if v.index not in ids],context='VERTS');bb.to_mesh(target);bb.free();target.update();return target
 all_ids=set(range(len(me.vertices)));used=set()
 for pn,ids in part_ids.items():
  if not ids:continue
  part=kept_mesh(me,ids);part.transform(Matrix.Translation(-pivots[pn]));new=bpy.data.objects.new(pn,part);bpy.context.scene.collection.objects.link(new);new.location=pivots[pn];used.update(ids)
 o.data=kept_mesh(me,all_ids-used);o.name='BicycleFrame'
 marker('RiderSeat',(0,.295,1.049));marker('HandlebarGripLeft',(-.29,-.44,.943));marker('HandlebarGripRight',(.29,-.44,.943));marker('CrankPivot',(0,.091,.303));marker('WheelFrontAxis',(0,-.537,.357));marker('WheelRearAxis',(0,.537,.357));marker('ExitLeft',(-.8,0,0))
 for o in meshes():o['source_license']='CC-BY-3.0';o['source_author']='Poly by Google';o['source_url']='https://poly.pizza/m/19VoUuA2pcN'
 export('bicycle','Bicycle by Poly by Google CC-BY-3.0; source https://poly.pizza/m/19VoUuA2pcN; scaled, reoriented, sockets, UV-preserving wheel/crank separation','', 'WheelFront, WheelRear and Crank are meshes with real axle pivots; wheel radius .357m.')
 setup_render('bicycle')

def lathe(name,profile,material,segments=20):
 verts=[(r*math.cos(i*math.tau/segments),r*math.sin(i*math.tau/segments),z) for z,r in profile for i in range(segments)]
 faces=[]
 for j in range(len(profile)-1):
  for i in range(segments):faces.append((j*segments+i,j*segments+(i+1)%segments,(j+1)*segments+(i+1)%segments,(j+1)*segments+i))
 faces.extend([tuple(reversed(range(segments))),tuple((len(profile)-1)*segments+i for i in range(segments))])
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.scene.collection.objects.link(o);me.materials.append(material)
 bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project();bpy.ops.object.mode_set(mode='OBJECT');o.select_set(False)
 return o

def tools():
 reset();wood=mat('WarmAshWood',(.45,.20,.065,1));grip=mat('BlueGrip',(.045,.25,.55,1));metal=mat('BrushedSteel',(.45,.62,.72,1),.7,.32)
 lathe('TurnedBat',[(0,.028),(.025,.048),(.04,.031),(.32,.030),(.47,.065),(.78,.082),(.86,.06),(.88,.012)],wood)
 lathe('BatGrip',[(.05,.032),(.31,.032)],grip);marker('GripSocket',(0,0,.15));export('bat','Original accessory mesh, CC0-1.0');setup_render('bat')
 reset();metal=mat('ForgedSteel',(.48,.64,.72,1),.7,.32);grip=mat('ToolGrip',(.045,.30,.60,1));lathe('WrenchHandle',[(0,.028),(.06,.04),(.4,.032),(.48,.055)],metal)
 # Open jaws are a purpose drawn profile, extruded into a machined tool.
 outline=[(-.05,.41),(-.13,.47),(-.14,.57),(-.08,.64),(-.055,.63),(-.065,.53),(.065,.53),(.055,.63),(.08,.64),(.14,.57),(.13,.47),(.05,.41)]
 vv=[(x,y,z) for y in [-.028,.028] for x,z in outline];n=len(outline);ff=[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 me=bpy.data.meshes.new('OpenJawTopology');me.from_pydata(vv,[],ff);me.materials.append(metal);o=bpy.data.objects.new('WrenchOpenJaw',me);bpy.context.scene.collection.objects.link(o)
 marker('GripSocket',(0,0,.15));export('wrench','Original accessory mesh, CC0-1.0');setup_render('wrench')
 reset();blue=mat('PulseBlue',(.025,.28,.68,1),.1);orange=mat('PulseSafetyOrange',(.98,.33,.045,1));sphere('PulseHousing',(0,0,.34),(.11,.07,.27),blue);lathe('PulseGrip',[(0,.034),(.22,.034)],blue);lathe('PulseEmitter',[(.54,.082),(.61,.074),(.65,.04)],orange);marker('GripSocket',(0,0,.12));export('pulse','Original fictional non-lethal tool accessory mesh, CC0-1.0');setup_render('pulse')

def main():
 # Release static city kit first for concurrent Godot integration.
 for name,file,height in [('office_tower_a','building-skyscraper-a',38),('office_tower_b','building-skyscraper-b',46),('office_tower_c','building-skyscraper-c',33)]:static_source(name,'city-kit-commercial',file,height)
 for name,pack,file,target,axis in [('streetlight','city-kit-roads','light-curved',5.2,2),('traffic_light','city-kit-roads','traffic-light',3.8,2),('barrier','city-kit-roads','construction-barrier',1.0,2),('sign','city-kit-roads','road-sign-empty',2.2,2),('bench','furniture-kit','bench',1.75,0),('planter','furniture-kit','pottedPlant',1.2,2),('tree','nature-kit','tree_oak',5.0,2),('desk','furniture-kit','desk',.85,2),('display','furniture-kit','computerScreen',.8,2),('server','furniture-kit','bookcaseClosed',2,2),('glass','furniture-kit','wallWindow',2.6,2),('road_straight','city-kit-roads','road-straight',12,0),('road_crossing','city-kit-roads','road-crossing',12,0)]:static_source(name,pack,file,target,axis)
 lobby();car();bicycle();tools()
 character('hero','character-male-a',PAL)
 guardpal=PAL.copy();guardpal[0]=(.055,.48,.35,1);guardpal[2]=(.93,.62,.08,1);guardpal[3]=(.68,.37,.20,1);guardpal[4]=(.14,.030,.008,1)
 character('guard','character-male-e',guardpal)
 civpal=PAL.copy();civpal[0]=(.69,.075,.25,1);civpal[1]=(.10,.25,.46,1);civpal[2]=(.15,.65,.49,1);civpal[3]=(.80,.49,.29,1);civpal[4]=(.31,.12,.045,1)
 character('civilian','character-female-b',civpal)
 (QA/'blender-run.json').write_text(json.dumps({'blender_version':bpy.app.version_string,'method':'Blender CLI background; MCP unavailable','assets':len(REPORT),'user_prompt':'開始製作 並推上開源'},ensure_ascii=False,indent=2),encoding='utf-8')
if __name__=='__main__':main()

