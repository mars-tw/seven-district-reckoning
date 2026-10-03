"""CC0 MakeHuman data -> clothed, compact Blender/Godot characters.

Run: blender --background --python tools/blender/build_human_characters.py
Only asset data from MPFB is used. No MPFB/MakeHuman program code is embedded.
Original tailoring, texture painting and animation code is MIT; art is CC0.
"""
import bpy, math, json, gzip, hashlib, struct, sys
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'assets/source/makehuman'
OUT = ROOT / 'godot/assets/models'
BLEND = ROOT / 'assets/source/blender'
QA = ROOT / 'qa/art/v03-human'
TEX = ROOT / 'godot/assets/textures/v03-human'
CLIPS = ['idle', 'walk', 'run', 'attack', 'hit', 'drive', 'pedal', 'knockdown']
VARIANTS = {
 'hero_human': {'height': 1.78, 'gender': 'male', 'top': (.085,.18,.25), 'bottom': (.065,.095,.13), 'accent': (.90,.38,.13), 'skin': (.56,.34,.22), 'style': 'delivery', 'label': '阿遠｜工作夾克、斜背郵差包'},
 'guard_human': {'height': 1.80, 'gender': 'male', 'top': (.105,.145,.19), 'bottom': (.045,.06,.08), 'accent': (.72,.65,.38), 'skin': (.48,.29,.20), 'style': 'security', 'label': '園區保全｜深色制服、保全帽、識別章'},
 'civilian_human': {'height': 1.68, 'gender': 'female', 'top': (.52,.25,.20), 'bottom': (.095,.16,.23), 'accent': (.85,.73,.53), 'skin': (.62,.40,.29), 'style': 'casual', 'label': '市民｜陶紅襯衫、深藍長褲、及肩髮'},
 'mei_human': {'height': 1.69, 'gender': 'female', 'top': (.14,.29,.27), 'bottom': (.10,.105,.13), 'accent': (.92,.88,.73), 'skin': (.60,.38,.27), 'style': 'workshop', 'label': '美晴｜墨綠工作外套、工作證、短髮'},
 'yuan_human': {'height': 1.75, 'gender': 'male', 'top': (.46,.34,.19), 'bottom': (.115,.14,.18), 'accent': (.89,.82,.65), 'skin': (.58,.36,.25), 'style': 'hoodie', 'label': '予安｜沙色連帽外套、白球鞋'},
 'zhou_human': {'height': 1.77, 'gender': 'male', 'top': (.16,.18,.22), 'bottom': (.08,.085,.11), 'accent': (.38,.10,.09), 'skin': (.55,.34,.24), 'style': 'suit', 'label': '周成｜炭灰西裝、暗紅領帶、梳整短髮'},
}

def source_mesh():
 verts=[]; uv=[]; faces=[]; groups={}; current=''
 for line in (SOURCE/'base.obj').read_text().splitlines():
  p=line.split()
  if not p: continue
  if p[0]=='v': verts.append(Vector(tuple(float(v) for v in p[1:4])))
  elif p[0]=='vt': uv.append(tuple(float(v) for v in p[1:3]))
  elif p[0]=='g': current=p[1]; groups.setdefault(current,set())
  elif p[0]=='f':
   ff=[tuple(int(v)-1 for v in token.split('/')[:2]) for token in p[1:]]
   groups.setdefault(current,set()).update(v[0] for v in ff)
   if current=='body': faces.append(ff)
 return verts,uv,faces,groups

BASE, UV, FACES, GROUPS = source_mesh()
RIG_DATA = json.loads((SOURCE/'rig.game_engine.json').read_text())
WEIGHTS = json.loads((SOURCE/'weights.game_engine.json').read_text())['weights']
RENAME = {'hand_r':'hand.r','hand_l':'hand.l'}

def morph_vertices(cfg):
 verts=[v.copy() for v in BASE]
 targets=[(f"asian-{cfg['gender']}-young.target.gz",.55 if cfg['style']=='suit' else 1),
   (f"{cfg['gender']}-young-averagemuscle-averageweight-idealproportions.target.gz",.30)]
 if cfg['style']=='suit':targets.append(('asian-male-old.target.gz',.45))
 for file, amount in targets:
  for line in gzip.decompress((SOURCE/file).read_bytes()).decode().splitlines():
   p=line.split()
   if len(p)==4: verts[int(p[0])] += Vector(tuple(float(x) for x in p[1:]))*amount
 # MakeHuman decimetres, Y up / +Z face -> Blender metres Z up / -Y face.
 raw=[Vector((v.x,-v.z,v.y))*.1 for v in verts]
 body_ids=GROUPS['body']; bottom=min(raw[i].z for i in body_ids); top=max(raw[i].z for i in body_ids)
 scale=cfg['height']/(top-bottom)
 result=[Vector((v.x*scale,v.y*scale,(v.z-bottom)*scale)) for v in raw]
 # 7.4-head adult proportion, applied equally to face and anatomical helpers.
 neck=cfg['height']*.825
 for v in result:
  blend=max(0,min(1,(v.z-neck)/(.055*cfg['height'])))
  if blend:v.x*=1+.065*blend;v.y*=1+.04*blend;v.z=neck+(v.z-neck)*(1+.06*blend)
 highest=max(result[i].z for i in body_ids);ratio=cfg['height']/highest
 return [v*ratio for v in result],scale*ratio

def node_material(name,color,kind='cloth'):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1)
 bsdf=m.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=.82 if kind=='cloth' else .53
 bsdf.inputs['Metallic'].default_value=.0
 image=bpy.data.images.new(name+'_albedo',width=128,height=128,alpha=True)
 pixels=[]
 for y in range(128):
  for x in range(128):
   woven=(.96 if (x+y)%3==0 else 1.0)+.018*math.sin(x*.83)*math.sin(y*.79)
   shade=1.0+.025*math.sin(y*.11)+.016*math.sin(x*.17)
   if kind=='skin': shade=1+.055*math.cos((y-64)/80)+.012*math.sin(x*.23)
   if kind=='shoe': woven=.88 if y%23<2 else 1
   pixel_color=(.90,.91,.87) if name.endswith('_Details') and x>105 else color
   pixels.extend([min(1,max(0,c*woven*shade)) for c in pixel_color]+[1])
 image.pixels=pixels;image.filepath_raw=str(TEX/(name+'.png'));image.file_format='PNG';image.save();image.pack()
 tx=m.node_tree.nodes.new('ShaderNodeTexImage');tx.image=image
 m.node_tree.links.new(tx.outputs['Color'],bsdf.inputs['Base Color'])
 return m

def mesh_object(name,verts,faces,uvs=None):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj)
 if uvs:
  layer=mesh.uv_layers.new(name='UVMap')
  for p in mesh.polygons:
   for li,coord in zip(p.loop_indices,uvs[p.index]): layer.data[li].uv=coord
 for p in mesh.polygons:p.use_smooth=True
 return obj

def material_all(obj,mat):
 obj.data.materials.append(mat)
 if not obj.data.uv_layers:
  uv=obj.data.uv_layers.new(name='UVMap')
  for p in obj.data.polygons:
   for li in p.loop_indices:
    v=obj.data.vertices[obj.data.loops[li].vertex_index].co;uv.data[li].uv=(v.x*2+.5,v.z*.75)
 if mat.name.endswith('_Details'):
  for loop in obj.data.uv_layers.active.data:loop.uv=(.35,.5)

def bind_rigid(obj,rig,bone):
 vg=obj.vertex_groups.new(name=bone);vg.add(list(range(len(obj.data.vertices))),1,'REPLACE')
 mod=obj.modifiers.new('HumanSkin','ARMATURE');mod.object=rig;obj.parent=rig

def sphere(name,center,scale,mat,rig=None,bone='head',segments=16,rings=8):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=center)
 o=bpy.context.object;o.name=name;o.scale=scale;bpy.ops.object.transform_apply(location=True,rotation=False,scale=True)
 material_all(o,mat)
 for p in o.data.polygons:p.use_smooth=True
 if rig:bind_rigid(o,rig,bone)
 return o

def ribbon(name,points,width,mat,rig,bone='spine_03'):
 vv=[]
 for p in points: vv.extend([tuple(Vector(p)+Vector((-width/2,0,0))),tuple(Vector(p)+Vector((width/2,0,0)))])
 ff=[(i*2,i*2+1,i*2+3,i*2+2) for i in range(len(points)-1)]
 o=mesh_object(name,vv,ff);material_all(o,mat)
 solid=o.modifiers.new('StitchedThickness','SOLIDIFY');solid.thickness=.003
 bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=solid.name);bind_rigid(o,rig,bone)
 return o

def joint_position(spec,verts):
 ids=spec.get('vertex_indices',list(GROUPS.get(spec.get('cube_name',''),[])))
 if ids:return sum((verts[i] for i in ids),Vector())/len(ids)
 # Fallback for a legal rig's optional helper; Root gets a useful vertical bone.
 return Vector((0,0,.03))

def create_rig(verts):
 data=bpy.data.armatures.new('HumanSkeleton');rig=bpy.data.objects.new('HumanSkeleton',data);bpy.context.scene.collection.objects.link(rig)
 bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
 for name,row in RIG_DATA.items():
  b=data.edit_bones.new(RENAME.get(name,name));b.head=joint_position(row['head'],verts);b.tail=joint_position(row['tail'],verts)
  if name=='Root':b.head=(0,0,0);b.tail=(0,0,.15)
  if (b.head-b.tail).length<.0001:b.tail=b.head+Vector((0,0,.01))
  b.roll=row.get('roll',0)
 for name,row in RIG_DATA.items():
  if row['parent']: data.edit_bones[RENAME.get(name,name)].parent=data.edit_bones[RENAME.get(row['parent'],row['parent'])]
 bpy.ops.object.mode_set(mode='OBJECT');rig.select_set(False)
 rig['source_license']='CC0-1.0';rig['source_mesh']='MakeHuman hm08';rig['forward']='Blender -Y / Godot +Z'
 return rig

def clothed_body(verts,cfg,rig,mats):
 ids=sorted(GROUPS['body']);mapping={src:i for i,src in enumerate(ids)}
 vv=[verts[i].copy() for i in ids];height=cfg['height'];arms=set();hands=set();head=set()
 for bn in ['hand_r','hand_l','lowerarm_r','lowerarm_l','upperarm_r','upperarm_l']:
  arms.update(i for i,w in WEIGHTS[bn] if w>.35)
 for bn,rows in WEIGHTS.items():
  if any(bn.startswith(prefix) for prefix in ['hand_','thumb_','index_','middle_','ring_','pinky_']):hands.update(i for i,w in rows if w>.03)
  if bn in ['head','neck_01']:head.update(i for i,w in rows if w>.38)
 classifications=[]
 for src,v in zip(ids,vv):
  z=v.z/height
  arm=src in arms
  if z<.075:category=3
  elif src in hands or (src in head and z>.819 and abs(v.x)<.105):category=0
  elif z<.56 and not arm:category=2
  elif z<.844:category=1
  else:category=0
  classifications.append(category)
  # Garment volume is fitted to the anatomical mesh, not painted naked skin.
  if category==1:
   centre=Vector((0,.007,v.z));rad=v-centre;rad.z=0
   if arm:
    # Sleeves puff out relative to the closest upper-arm segment.
    side='l' if v.x>0 else 'r';b=rig.data.bones['upperarm_'+side]
    t=max(0,min(1,(v-b.head_local).dot(b.tail_local-b.head_local)/(b.tail_local-b.head_local).length_squared))
    centre=b.head_local.lerp(b.tail_local,t);rad=v-centre
   if rad.length:v+=rad.normalized()*.018
   if not arm:
    # Squared shirt hem and relaxed chest, avoiding breast/body outlines.
    if v.y>.05:v.y=max(v.y,.075)
    elif v.y<-.045:v.y=min(v.y,-.100)
  elif category==2:
   sx=1 if v.x>0 else -1;centre=Vector((sx*.105,0,v.z));rad=v-centre;rad.z=0
   if rad.length:v+=rad.normalized()*.027
   if z>.45:v.y*=1.10
  elif category==3:
   v.y*=1.06;v.x*=1.025
  # Small identity variations in face width, preserving facial topology.
  if z>.84 and cfg['style']=='suit':v.x*=.96;v.y*=1.05
  if z>.84 and cfg['style']=='hoodie':v.x*=1.035
 kept=[]
 for face in FACES:
  c=sum((vv[mapping[q[0]]] for q in face),Vector())/len(face)
  # Body under the sewn jacket is hidden, as real clothing exporters do.
  # Removing those surfaces also prevents breast anatomy poking through cloth.
  arm_fraction=sum(q[0] in arms for q in face)/len(face)
  categories=[classifications[mapping[q[0]]] for q in face]
  material=max(set(categories),key=categories.count)
  if height*.565<c.z<height*.841 and abs(c.x)<.24 and arm_fraction<.75:continue
  kept.append(face)
 ff=[[mapping[q[0]] for q in f] for f in kept];uvs=[[UV[q[1]] for q in f] for f in kept]
 obj=mesh_object('TailoredHuman',vv,ff,uvs)
 for mat in mats:obj.data.materials.append(mat)
 for p in obj.data.polygons:
  cats=[classifications[i] for i in p.vertices];p.material_index=max(set(cats),key=cats.count)
 # Straighten actual garment border loops before retopology. This prevents
 # anatomical quad rows from becoming torn-looking shirt hems and cuffs.
 adj={}
 for p in obj.data.polygons:
  for vid in p.vertices:adj.setdefault(vid,set()).add(p.material_index)
 for vid,cats in adj.items():
  if len(cats)<2:continue
  v=obj.data.vertices[vid].co
  if 1 in cats and 2 in cats and abs(v.x)<.30:v.z=height*.565
  if 1 in cats and 0 in cats and v.z>height*.78 and abs(v.x)<.14:v.z=height*.821
  if 2 in cats and 3 in cats:v.z=height*.070
 # Official anatomically authored skinning, retaining full finger weights.
 for old,rows in WEIGHTS.items():
  vg=obj.vertex_groups.new(name=RENAME.get(old,old))
  for index,weight in rows:
   if index in mapping and weight>.0001:vg.add([mapping[index]],weight,'REPLACE')
 bpy.context.view_layer.objects.active=obj;obj.select_set(True)
 dec=obj.modifiers.new('GameRetopologyBudget','DECIMATE');dec.ratio=.245;dec.use_collapse_triangulate=True
 bpy.ops.object.modifier_apply(modifier=dec.name);obj.select_set(False)
 mod=obj.modifiers.new('HumanSkin','ARMATURE');mod.object=rig;obj.parent=rig
 # Pattern uses object-space projection to ensure metre-scale woven cloth.
 for p in obj.data.polygons:
  if p.material_index in (1,2,3):
   for li in p.loop_indices:
    v=obj.data.vertices[obj.data.loops[li].vertex_index].co;obj.data.uv_layers.active.data[li].uv=(v.x*4+.5,v.z*3)
 return obj

def accessories(cfg,verts,rig,mats):
 skin,top,pants,shoes,hair,detail=mats;height=cfg['height']
 # Sewn torso panels keep jackets from clinging to body anatomy. The panels
 # are rings of garment cross-sections with blended pelvis/spine skinning.
 panels=[(.560,.176,.143,.112),(.625,.175,.150,.118),(.705,.192,.187,.123),(.775,.216,.171,.116),(.802,.212,.107,.096),(.845,.072,.110,.080)]
 jv=[];jf=[];steps=24
 for z,rx,front,back in panels:
  for i in range(steps):
   a=i*math.tau/steps;depth=back if math.sin(a)>0 else front;jv.append((rx*math.cos(a),depth*math.sin(a),z*height))
 for j in range(len(panels)-1):
  for i in range(steps):jf.append((j*steps+i,j*steps+(i+1)%steps,(j+1)*steps+(i+1)%steps,(j+1)*steps+i))
 jacket=mesh_object('SewnJacketPanels',jv,jf);material_all(jacket,top)
 low=jacket.vertex_groups.new(name='pelvis');high=jacket.vertex_groups.new(name='spine_03')
 for v in jacket.data.vertices:
  w=max(0,min(1,(v.co.z/height-.565)/.16));low.add([v.index],1-w,'REPLACE');high.add([v.index],w,'REPLACE')
 jm=jacket.modifiers.new('HumanSkin','ARMATURE');jm.object=rig;jacket.parent=rig
 # A fitted sneaker/boot last covers separate toes with a real closed sole.
 for side,sign in [('l',1),('r',-1)]:
  foot=rig.data.bones['foot_'+side];cx=foot.head_local.x
  profile=[(.075,.045,.082),(.038,.058,.109),(-.015,.062,.113),(-.100,.064,.105),(-.185,.063,.076),(-.257,.048,.046),(-.270,.008,.024)]
  sv=[];sf=[];n=12
  for y,width,topz in profile:
   for i in range(n):
    angle=i*math.tau/n;z=.008+(topz-.008)*(math.sin(angle)+1)/2
    sv.append((cx+width*math.cos(angle),y,z))
  for j in range(len(profile)-1):
   for i in range(n):sf.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
  sf.extend([tuple(reversed(range(n))),tuple((len(profile)-1)*n+i for i in range(n))])
  shoe=mesh_object('FittedShoe_'+side,sv,sf);material_all(shoe,shoes);bind_rigid(shoe,rig,'foot_'+side)
  for yy,zz in [(-.025,.116),(-.060,.115),(-.095,.108)]:
   lace=ribbon('ShoeLace_'+side,[(cx-.032,yy,zz),(cx+.032,yy,zz)],.006,detail,rig,'foot_'+side)
   for loop in lace.data.uv_layers.active.data:loop.uv=(.95,.5)
 for side,sign in [('l',1),('r',-1)]:
  e=joint_position({'cube_name':'joint-'+side+'-eye'},verts)
  rim=[v for i,v in enumerate(verts) if i in GROUPS['body'] and abs(v.x-e.x)<.011 and abs(v.z-e.z)<.014 and v.y<0]
  if rim:e.y=min(v.y for v in rim)-.002
  # Correctly sized eyeball (24mm diameter), small dark iris, dark brow.
  eye=sphere('Eye_'+side,e,(.011,.0025,.0045),detail,rig)
  for loop in eye.data.uv_layers.active.data:loop.uv=(.95,.5)
  sphere('Iris_'+side,e+Vector((0,-.0023,0)),(.0045,.001,.0045),hair,rig,segments=16,rings=8)
  ribbon('UpperEyelid_'+side,[e+Vector((-.010,-.001,.002)),e+Vector((0,-.003,.004)),e+Vector((.010,-.001,.002))],.0018,hair,rig,'head')
  brow=e+Vector((0,-.005,.023))
  ribbon('Eyebrow_'+side,[brow+Vector((-.024,.001,0)),brow+Vector((0,-.004,.003)),brow+Vector((.024,.001,-.001))],.006,hair,rig,'head')
 # Hair follows actual skull topology rather than a cartoon hemisphere.
 headfaces=[];headuv=[];hair_ids=set()
 for ff in FACES:
  c=sum((verts[q[0]] for q in ff),Vector())/len(ff)
  cutoff=.956 if c.y<-.025 else (.875 if cfg['gender']=='female' else .919)
  if c.z/height>cutoff:headfaces.append(ff);hair_ids.update(q[0] for q in ff)
 hi=sorted(hair_ids);mp={i:j for j,i in enumerate(hi)};hv=[]
 for i in hi:
  v=verts[i].copy();v.x*=1.055;v.y*=1.06;v.z+=.006
  if cfg['gender']=='female' and v.y>-.01 and v.z/height<.92:v.z-=.025 if cfg['style']=='workshop' else .090
  hv.append(v)
 o=mesh_object('FittedHair',hv,[[mp[q[0]] for q in ff] for ff in headfaces],[[UV[q[1]] for q in ff] for ff in headfaces]);material_all(o,hair)
 bpy.context.view_layer.objects.active=o;d=o.modifiers.new('HairBudget','DECIMATE');d.ratio=.5;bpy.ops.object.modifier_apply(modifier=d.name);bind_rigid(o,rig,'head')
 if cfg['gender']=='female':
  # Open-front bob/shoulder hairstyle, fitted around the temples and nape.
  hv=[];hf=[];steps=20;length=.895 if cfg['style']=='workshop' else .855
  for z,rx,ry in [(.984,.056,.060),(.957,.095,.094),(.923,.102,.086),(length,.096,.066)]:
   for i in range(steps):
    a=-.13*math.pi+i/(steps-1)*1.26*math.pi;hv.append((rx*math.cos(a),.025+ry*math.sin(a),z*height))
  for j in range(3):
   for i in range(steps-1):hf.append((j*steps+i,j*steps+i+1,(j+1)*steps+i+1,(j+1)*steps+i))
  bob=mesh_object('ShortBob' if cfg['style']=='workshop' else 'ShoulderLengthHair',hv,hf);material_all(bob,hair);bind_rigid(bob,rig,'head')
 # Collar uses a stitched contour shaped around a human neck.
 for sign in [-1,1]:
  collar=mesh_object('JacketCollar',[(sign*.034,-.114,height*.843),(sign*.082,-.120,height*.829),(sign*.151,-.152,height*.788),(sign*.086,-.155,height*.807)],[(0,1,2,3)])
  material_all(collar,top);bind_rigid(collar,rig,'spine_03')
 # A visible central fastening makes garment construction readable at game scale.
 ribbon('FrontFastening',[(0,-.150,height*.58),(0,-.201,height*.70),(0,-.153,height*.79)],.009,detail,rig)
 if cfg['style']=='delivery':
  ribbon('CrossbodyBagStrap',[(-.18,-.10,height*.81),(-.08,-.190,height*.75),(.035,-.201,height*.68),(.16,-.170,height*.62),(.23,-.13,height*.59)],.036,detail,rig)
  bpy.ops.mesh.primitive_cube_add(size=1,location=(.24,.10,height*.55));bag=bpy.context.object;bag.name='TailoredMessengerBag';bag.dimensions=(.24,.09,.26)
  bpy.ops.object.transform_apply(location=True,rotation=False,scale=True);bev=bag.modifiers.new('SewnRoundedCorners','BEVEL');bev.width=.023;bev.segments=3;bpy.context.view_layer.objects.active=bag;bpy.ops.object.modifier_apply(modifier=bev.name);material_all(bag,top);bind_rigid(bag,rig,'pelvis')
  ribbon('BagFlapStitch',[(.08,.177,height*.60),(.21,.19,height*.61),(.34,.173,height*.60)],.012,detail,rig,'pelvis')
 elif cfg['style']=='security':
  sphere('SecurityCap',(0,-.005,height-.020),(.102,.116,.035),top,rig,'head')
  sphere('CapPeak',(0,-.095,height-.030),(.093,.081,.012),pants,rig,'head')
  ribbon('SecurityBadge',[(-.10,-.144,height*.738),(-.10,-.146,height*.705)],.035,detail,rig)
 elif cfg['style']=='workshop':
  ribbon('StaffLanyard',[(-.07,-.145,height*.80),(0,-.207,height*.705),(.07,-.145,height*.80)],.012,detail,rig)
  ribbon('WorkCard',[(0,-.209,height*.707),(0,-.209,height*.666)],.044,detail,rig)
 elif cfg['style']=='hoodie':
  sphere('FoldedHood',(0,.073,height*.80),(.13,.055,.07),top,rig)
  for sign in [-1,1]:ribbon('HoodDrawstring',[(sign*.055,-.143,height*.79),(sign*.038,-.149,height*.717)],.004,detail,rig)
 elif cfg['style']=='suit':
  ribbon('SuitTie',[(0,-.152,height*.805),(.006,-.193,height*.74),(0,-.204,height*.682)],.023,detail,rig)
  for sign in [-1,1]:ribbon('SuitLapel',[(sign*.066,-.110,height*.825),(sign*.125,-.174,height*.775),(sign*.059,-.199,height*.705)],.044,top,rig)

def marker(name,rig,bone,pos):
 o=bpy.data.objects.new(name,None);bpy.context.scene.collection.objects.link(o)
 o.location=pos;bpy.context.view_layer.update();world=o.matrix_world.copy();o.parent=rig;o.parent_type='BONE';o.parent_bone=bone;o.matrix_world=world
 o.empty_display_size=.025;return o

def aim(rig,bone,direction):
 pb=rig.pose.bones[bone];rest=rig.data.bones[bone].matrix_local
 q=(rest.to_3x3()@Vector((0,1,0))).rotation_difference(Vector(direction).normalized())@rest.to_quaternion()
 bpy.context.view_layer.update();pos=pb.head.copy();pb.matrix=Matrix.LocRotScale(pos,q,Vector((1,1,1)));bpy.context.view_layer.update()

def rotate_global(rig,bone,axis,angle):
 pb=rig.pose.bones[bone];bpy.context.view_layer.update();m=pb.matrix.copy();q=Quaternion(axis,angle)@m.to_quaternion();pb.matrix=Matrix.LocRotScale(m.translation,q,Vector((1,1,1)));bpy.context.view_layer.update()

def two_bone(rig,upper,lower,target,bend):
 bpy.context.view_layer.update();a=rig.pose.bones[upper].head.copy();l1=rig.data.bones[upper].length;l2=rig.data.bones[lower].length
 delta=Vector(target)-a;dist=max(.0001,min(delta.length,l1+l2-.001));forward=delta.normalized()
 mid=(l1*l1-l2*l2+dist*dist)/(2*dist);rise=math.sqrt(max(0,l1*l1-mid*mid))
 side=Vector(bend)-forward*Vector(bend).dot(forward)
 if side.length<.01:side=Vector((1,0,0)).cross(forward)
 knee=a+forward*mid+side.normalized()*rise
 aim(rig,upper,knee-a);aim(rig,lower,Vector(target)-knee)

def animation_pose(rig,clip,t,cfg):
 for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4);pb.rotation_mode='QUATERNION'
 bpy.context.view_layer.update();height=cfg['height'];phase=t*math.tau
 # Hips remain centred; animation is in place and the controller owns travel.
 if clip in ['walk','run']:
  amp=.40 if clip=='walk' else .70;stride=math.sin(phase)
  rig.pose.bones['pelvis'].location.y=.007*(1-math.cos(phase*2))
  rotate_global(rig,'spine_03',(1,0,0),.05 if clip=='walk' else .14)
  for side,sign in [('l',1),('r',-1)]:
   swing=amp*stride*sign;flex=.04+max(0,-stride*sign)*(.65 if clip=='walk' else 1.02)
   aim(rig,'thigh_'+side,(sign*.018,-math.sin(swing),-math.cos(swing)))
   aim(rig,'calf_'+side,(0,-math.sin(swing-flex),-math.cos(swing-flex)))
   aim(rig,'foot_'+side,(0,-1,-.18))
   aim(rig,'upperarm_'+side,(sign*.12,math.sin(swing)*.65,-1))
   aim(rig,'lowerarm_'+side,(sign*.06,-.14+math.sin(swing)*.40,-1))
 elif clip in ['drive','pedal']:
  rotate_global(rig,'spine_03',(1,0,0),.10 if clip=='drive' else .21)
  for side,sign in [('l',1),('r',-1)]:
   if clip=='pedal':
    a=phase+(0 if side=='r' else math.pi);target=Vector((sign*.14,-.13+.14*math.sin(a),height*.18+.14*math.cos(a)))
   else:target=Vector((sign*.15,-.39,height*.325))
   two_bone(rig,'thigh_'+side,'calf_'+side,target,(0,-1,0))
   aim(rig,'foot_'+side,(0,-1,-.12))
   target=Vector((sign*.20,-.37,height*.61))
   two_bone(rig,'upperarm_'+side,'lowerarm_'+side,target,(sign*.6,.3,-.6))
   aim(rig,'hand.'+side,(0,-1,-.15))
 else:
  rotate_global(rig,'spine_03',(1,0,0),.009*math.sin(phase))
  for side,sign in [('l',1),('r',-1)]:
   aim(rig,'upperarm_'+side,(sign*.16,.014*math.sin(phase),-1))
   aim(rig,'lowerarm_'+side,(sign*.08,-.12,-1))
   aim(rig,'hand.'+side,(sign*.04,-.14,-1))
   for finger in ['index','middle','ring','pinky']:
    for segment in ['01','02','03']:rotate_global(rig,f'{finger}_{segment}_{side}',(1,0,0),.22)
  if clip=='attack':
   weight=math.sin(min(1,t)*math.pi)
   rotate_global(rig,'spine_03',(0,0,1),-.30*weight)
   aim(rig,'upperarm_r',(-.20,-math.sin(t*math.pi)*.9,-.4+1.15*math.sin(t*math.pi)))
   aim(rig,'lowerarm_r',(-.1,-.85,.15+math.cos(t*math.pi)*.55))
   for side in ['l','r']:
    for finger in ['index','middle','ring','pinky']:
     for segment in ['01','02','03']:rotate_global(rig,f'{finger}_{segment}_{side}',(1,0,0),.50)
  elif clip=='hit':
   w=math.sin(t*math.pi);rotate_global(rig,'spine_03',(1,0,0),-.30*w);rotate_global(rig,'head',(1,0,0),-.14*w)
  elif clip=='knockdown':
   amount=(t*t*(3-2*t));rotate_global(rig,'pelvis',(1,0,0),-1.48*amount)
   # Rotated body settles on the street; pelvis translation is actual bone motion.
   rig.pose.bones['Root'].location.y=-height*.48*amount
   for side in ['l','r']:rotate_global(rig,'calf_'+side,(1,0,0),-.32*amount)
 bpy.context.view_layer.update()

def create_animations(rig,cfg):
 rig.animation_data_create();actions={};durations={'idle':60,'walk':30,'run':22,'attack':24,'hit':18,'drive':40,'pedal':30,'knockdown':40}
 for clip in CLIPS:
  a=bpy.data.actions.new(clip);rig.animation_data.action=a;actions[clip]=a
  frames=sorted(set(list(range(0,durations[clip]+1,3))+[durations[clip]]))
  for f in frames:
   bpy.context.scene.frame_set(f);animation_pose(rig,clip,f/durations[clip],cfg)
   for pb in rig.pose.bones:
    pb.keyframe_insert(data_path='rotation_quaternion',frame=f);pb.keyframe_insert(data_path='location',frame=f)
  if clip=='knockdown':a['one_shot']=True
 rig.animation_data.action=None
 for name,a in actions.items():
  tr=rig.animation_data.nla_tracks.new();tr.name=name;strip=tr.strips.new(name,0,a);strip.name=name
 return actions

def glb_info(path):
 b=path.read_bytes();size=struct.unpack_from('<I',b,12)[0];d=json.loads(b[20:20+size]);tri=0
 for mesh in d.get('meshes',[]):
  for p in mesh['primitives']:tri+=d['accessors'][p['indices']]['count']//3
 return {'bytes':len(b),'triangles':tri,'materials':len(d.get('materials',[])),'animation_names':[a['name'] for a in d.get('animations',[])],'bones':len(d['skins'][0]['joints']),'sha256':hashlib.sha256(b).hexdigest()}

def render_views(name,rig,actions,cfg):
 scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=512;scene.render.resolution_y=640;scene.render.resolution_percentage=100
 scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG'
 scene.world=bpy.data.worlds.new('NeutralStudio');scene.world.use_nodes=True;scene.world.node_tree.nodes.get('Background').inputs[0].default_value=(.32,.36,.42,1);scene.world.node_tree.nodes.get('Background').inputs[1].default_value=.55
 scene.view_settings.view_transform='AgX'
 for n,loc,energy,color in [('Key',(3,-4,5),500,(1,.87,.74)),('Fill',(-3,-2,3),420,(.73,.84,1)),('Rim',(2,3,4),700,(.9,.96,1))]:
  bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=n;o['qa_only']=True;o.data.energy=energy;o.data.color=color;o.data.size=4;o.rotation_euler=(Vector((0,0,.9))-o.location).to_track_quat('-Z','Y').to_euler()
 bpy.ops.object.camera_add(location=(0,-5,.95));cam=bpy.context.object;cam.name='QA_Camera';cam['qa_only']=True;cam.data.type='ORTHO';cam.data.ortho_scale=2.12;scene.camera=cam
 for tr in rig.animation_data.nla_tracks:tr.mute=True
 rig.animation_data.action=actions['idle'];scene.frame_set(0)
 for suffix,loc in [('front',(0,-5,.93)),('side',(5,0,.93)),('back',(0,5,.93))]:
  cam.location=loc;cam.rotation_euler=(Vector((0,0,.92))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(QA/(name+'_'+suffix+'.png'));bpy.ops.render.render(write_still=True)
 cam.data.ortho_scale=.48;face_target=Vector((0,-.02,cfg['height']*.91));cam.location=face_target+Vector((0,-3,0));cam.rotation_euler=(face_target-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(QA/(name+'_face.png'));bpy.ops.render.render(write_still=True);cam.data.ortho_scale=2.12
 if name=='hero_human':
  for clip,f in [('walk',7),('run',7),('attack',12),('hit',9),('drive',0),('pedal',7),('knockdown',40)]:
   rig.animation_data.action=actions[clip];scene.frame_set(f);cam.location=(3,-5,2);cam.rotation_euler=(Vector((0,0,.85))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(QA/(name+'_'+clip+'.png'));bpy.ops.render.render(write_still=True)
 rig.animation_data.action=actions['idle'];scene.frame_set(0)
 scene.render.filepath='//../../../qa/art/v03-human/'+name+'_front.png'

def build_character(name,cfg,render=True):
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.render.fps=30
 verts,scale=morph_vertices(cfg);rig=create_rig(verts)
 mats=[node_material(name+'_Skin',cfg['skin'],'skin'),node_material(name+'_Fabric',cfg['top']),node_material(name+'_Trousers',cfg['bottom']),node_material(name+'_Shoes',(.10,.11,.12) if cfg['style']!='hoodie' else (.61,.60,.54),'shoe'),node_material(name+'_Hair',(.018,.014,.011),'hair'),node_material(name+'_Details',cfg['accent'])]
 body=clothed_body(verts,cfg,rig,mats);accessories(cfg,verts,rig,mats)
 # One skinned mesh / six material primitives per actor, rather than a draw
 # call for every eye, seam or shoe. Shared groups retain the real rig.
 bpy.ops.object.select_all(action='DESELECT')
 for obj in list(bpy.context.scene.objects):
  if obj.type=='MESH':obj.select_set(True)
 bpy.context.view_layer.objects.active=body;bpy.ops.object.join();body.name='TailoredHuman'
 handpos=rig.data.bones['hand.r'].head_local.lerp(rig.data.bones['hand.r'].tail_local,.65)
 marker('HandToolSocket',rig,'hand.r',handpos);marker('SeatHipSocket',rig,'pelvis',rig.data.bones['pelvis'].head_local)
 actions=create_animations(rig,cfg)
 rig['height_m']=cfg['height'];rig['clips']=','.join(CLIPS);rig['design']=cfg['label']
 bpy.ops.object.select_all(action='DESELECT')
 for o in bpy.context.scene.objects:o.select_set(True)
 bpy.context.view_layer.objects.active=rig
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_extras=True,export_yup=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_frame_range=False,export_skins=True,export_influence_nb=4,export_materials='EXPORT')
 row=glb_info(OUT/(name+'.glb'));row.update({'name':name,'path':'godot/assets/models/'+name+'.glb','blend':'assets/source/blender/'+name+'.blend','height_m':cfg['height'],'head_body_ratio':cfg['height']/(max(verts[i].z for i in GROUPS['body'])-joint_position({'cube_name':'joint-jaw'},verts).z),'label':cfg['label'],'license':'CC0-1.0'})
 assert row['triangles']<=18000,row;assert row['materials']<=6,row;assert row['bytes']<3*1024*1024,row;assert sorted(row['animation_names'])==sorted(CLIPS),row
 if render:render_views(name,rig,actions,cfg)
 else:
  for tr in rig.animation_data.nla_tracks:tr.mute=True
  rig.animation_data.action=actions['idle'];bpy.context.scene.frame_set(0)
 for image in bpy.data.images:
  if image.filepath:image.filepath=bpy.path.relpath(str(Path(bpy.path.abspath(image.filepath))),start=str(BLEND))
 bpy.ops.wm.save_as_mainfile(filepath=str(BLEND/(name+'.blend')))
 print('HUMAN_DONE',name,json.dumps(row,ensure_ascii=False),flush=True)
 return row

def main():
 for p in [OUT,BLEND,QA,TEX]:p.mkdir(parents=True,exist_ok=True)
 names=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(VARIANTS)
 rows=[]
 for name in names:rows.append(build_character(name,VARIANTS[name],render=True))
 prior=[];manifest=QA/'manifest.json'
 if manifest.exists():prior=json.loads(manifest.read_text(encoding='utf-8'))['characters']
 rows=[r for r in prior if r['name'] not in names]+rows
 manifest.write_text(json.dumps({'blender_version':bpy.app.version_string,'source':'MakeHuman Community MPFB CC0 hm08/Asian targets/game_engine rig and weights','method':'Original tailored derivative with authored eight skeletal clips, no Mixamo source or code','characters':rows},ensure_ascii=False,indent=2),encoding='utf-8')

if __name__=='__main__':main()
