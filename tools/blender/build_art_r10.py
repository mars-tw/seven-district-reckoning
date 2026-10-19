"""Seventh art round: soft sewn courier bag and six solid garage tools."""
import bpy, json, math, hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'godot/assets/models/r10';SOURCE=ROOT/'assets/source/blender/r10'
OUT.mkdir(parents=True,exist_ok=True);SOURCE.mkdir(parents=True,exist_ok=True)
(ROOT/'assets/art/r10').mkdir(parents=True,exist_ok=True)
rows=[]
def material(name,color,metal=0,rough=.8):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=m.diffuse_color
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    return m
def mesh(name,verts,faces,mat,rig=None):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);data.materials.append(mat)
    for p in data.polygons:p.use_smooth=True
    if rig:
        group=obj.vertex_groups.new(name='pelvis');group.add(range(len(verts)),1,'REPLACE')
        mod=obj.modifiers.new('OriginalPelvisSkin','ARMATURE');mod.object=rig;obj.parent=rig
    return obj
def export(name):
    for im in bpy.data.images:
        if im.type=='IMAGE' and im.packed_file:im.filepath='//'+im.name+'.png'
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_frame_range=False,export_skins=True)
    p=OUT/(name+'.glb')
    rows.append(dict(id=name,path=p.relative_to(ROOT).as_posix(),source=(SOURCE/(name+'.blend')).relative_to(ROOT).as_posix(),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),source_sha256=hashlib.sha256((SOURCE/(name+'.blend')).read_bytes()).hexdigest(),bytes=p.stat().st_size,triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')))

bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/source/blender/r9/hero_human.blend'))
rig=bpy.data.objects['HumanSkeleton']
for obj in list(bpy.context.scene.objects):
    if obj.type=='MESH' and obj.name.startswith(('Sewn','Bag')):bpy.data.objects.remove(obj,do_unlink=True)
canvas=material('Courier_WashedCanvas',(.37,.24,.12),rough=.92)
edge=material('Courier_DarkSeams',(.12,.075,.04),rough=.95)
brass=material('Courier_OldBrass',(.32,.23,.12),metal=.65,rough=.58)
verts=[];faces=[]
for j in range(13):
    t=j/12
    p=(1-t)**2*Vector((.26,-.17,1.02))+2*(1-t)*t*Vector((.47,-.06,1.04))+t*t*Vector((.43,.13,1.12))
    for dz in [-.018,.018]:verts.append(tuple(p+Vector((0,0,dz))))
for j in range(12):faces.append((2*j,2*j+1,2*j+3,2*j+2))
anchor=mesh('LoadedHipSlingConnection',verts,faces,edge,rig)
anchor.modifiers.new('LoadedWebbingThickness','SOLIDIFY').thickness=.009
def pouch(name,center,half,mat):
    verts=[];faces=[];n=24;rings=13
    for j in range(rings):
        theta=math.pi*(.03+.94*j/(rings-1));profile=math.sin(theta)**.38
        for i in range(n):
            a=2*math.pi*i/n;c=math.cos(a);s=math.sin(a)
            x=math.copysign(abs(c)**.7,c)*half[0]*profile
            y=math.copysign(abs(s)**.65,s)*half[1]*profile
            z=math.cos(theta)*half[2]-.010*math.cos(a*2)*math.sin(theta)
            y+=.009*math.sin(a*5+theta*4)*math.sin(theta)
            verts.append((center[0]+x,center[1]+y,center[2]+z))
    for j in range(rings-1):
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    faces.extend([tuple(reversed(range(n))),tuple((rings-1)*n+i for i in range(n))])
    return mesh(name,verts,faces,mat,rig)
pouch('SoftSewnGusset',(.27,.13,.98),(.20,.105,.17),canvas)
pouch('GatheredSidePocket',(.443,.13,.955),(.064,.085,.11),canvas)
verts=[];faces=[]
for j in range(8):
    t=j/7
    for i in range(13):
        x=-.19+.38*i/12
        verts.append((.27+x,.19+.06*math.sin(t*math.pi*.75)+.008*math.cos(x*34),1.14-.19*t-.012*(1-(x/.19)**2)))
for j in range(7):
    for i in range(12):a=j*13+i;faces.append((a,a+1,a+14,a+13))
flap=mesh('SoftFoldOverFlap',verts,faces,canvas,rig);solid=flap.modifiers.new('FoldedClothThickness','SOLIDIFY');solid.thickness=.008
# Existing continuous sling remains skinned; these anchors visually carry its load.
for x in [.105,.435]:
    verts=[(x-.016,.248,1.10),(x+.016,.248,1.10),(x+.016,.251,.95),(x-.016,.251,.95)]
    obj=mesh('CanvasClosureTab',verts,[(0,1,2,3)],edge,rig);obj.modifiers.new('WebbingThickness','SOLIDIFY').thickness=.009
    bpy.ops.mesh.primitive_torus_add(major_segments=16,minor_segments=4,location=(x,.258,1.025),major_radius=.022,minor_radius=.004,rotation=(math.pi/2,0,0))
    obj=bpy.context.object;obj.name='DullBrassBuckle';obj.data.materials.append(brass)
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    group=obj.vertex_groups.new(name='pelvis');group.add(range(len(obj.data.vertices)),1,'REPLACE');obj.modifiers.new('OriginalPelvisSkin','ARMATURE').object=rig;obj.parent=rig
export('hero_human')

# Reuse the editable workshop's bevelled drawers/legs, replace every repeated tool.
code=(ROOT/'tools/blender/build_art_r7.py').read_text(encoding='utf8')
prefix=code.split('for x in range(17):')[0]
prefix=prefix.replace("ROOT/'godot/assets/models/r7'","ROOT/'godot/assets/models/r10'").replace("ROOT/'assets/source/blender/r7'","ROOT/'assets/source/blender/r10'")
scope={'__file__':__file__};exec(compile(prefix,__file__,'exec'),scope)
tube,torus,box=[scope[k] for k in ['tube','torus','box']]
metal,rubber,red,steel=[scope[k] for k in ['metal','rubber','red','steel']]
for i in range(6):
    x=-1.08+i*.43;z=1.70+(i%2)*.07;y=.235
    tube('SolidPegHook',(x,.35,z+.23),(x,.19,z+.23),.016,metal)
    if i in [0,1]:
        tube('ForgedWrenchStem',(x,y,z-.20),(x,y,z+.17),.026,metal)
        torus('BoxEnd',(x,y,z-.20),.060,.024,metal)
        for s in [-1,1]:tube('OpenJaw',(x+s*.025,y,z+.13),(x+s*.062,y,z+.23),.023,metal)
    elif i==2:
        for s in [-1,1]:
            tube('PliersGrip',(x+s*.075,y,z-.23),(x+s*.018,y,z-.02),.033,red)
            tube('PliersSteelJaw',(x+s*.018,y,z-.02),(x+s*.050,y,z+.14),.026,metal)
        torus('PliersPivot',(x,y,z-.02),.025,.014,metal)
    elif i==3:
        tube('DriverGrip',(x,y,z-.24),(x,y,z-.04),.050,rubber)
        tube('DriverShaft',(x,y,z-.02),(x,y,z+.25),.018,metal)
        box('DriverTip',(x,y,z+.25),(.05,.028,.06),metal,.006)
    elif i==4:
        tube('SocketHandle',(x-.10,y,z+.14),(x+.10,y,z+.14),.035,metal)
        tube('SocketStem',(x,y,z-.24),(x,y,z+.14),.022,metal)
        tube('DeepSocket',(x,y,z-.29),(x,y,z-.18),.050,metal)
    else:
        tube('RatchetGrip',(x,y,z-.25),(x,y,z-.04),.040,rubber)
        tube('RatchetStem',(x,y,z-.04),(x,y,z+.18),.026,metal)
        torus('RatchetHead',(x,y,z+.19),.055,.027,metal)
# Static near-surface occlusion silhouettes match real tool geometry and direction.
shadow=scope['mat']('ToolContactOcclusion',(.025,.022,.018),0,1)
for obj in list(bpy.context.scene.objects):
    if obj.type=='MESH' and obj.name.startswith(('Forged','BoxEnd','OpenJaw','Pliers','Driver','Socket','DeepSocket','Ratchet')):
        duplicate=obj.copy();duplicate.data=obj.data.copy();bpy.context.collection.objects.link(duplicate)
        duplicate.name='ToolContactShadow';duplicate.location+=Vector((.018,.10,-.018));duplicate.data.materials.clear();duplicate.data.materials.append(shadow)
suffix=code.split("box('BenchViseBase'",1)[1].split("export('mei-workbench')",1)[0]
exec(compile("box('BenchViseBase'"+suffix,__file__,'exec'),scope)
scope['export']('mei-workbench');rows.extend(scope['rows'])
bpy.ops.wm.read_factory_settings(use_empty=True)
concrete=material('Curb_WornConcrete',(.34,.31,.25),rough=.94)
iron=material('Drain_OxidisedIron',(.075,.065,.05),metal=.45,rough=.78)
for i in range(14):
    # Bevelled cut kerbstones, each with a shaped sloping top and recessed joint.
    x=-7+i;v=[(x,0,0),(x+.97,0,0),(x+.97,.32,0),(x,.32,0),(x,0,.06),(x+.97,0,.06),(x+.97,.32,.11),(x,.32,.11)]
    obj=mesh('SlopedKerbstone',v,[(0,3,2,1),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5),(4,5,6,7)],concrete)
    mod=obj.modifiers.new('WornStoneEdges','BEVEL');mod.width=.018;mod.segments=2
for i in range(26):
    x=.1+i*.15
    tube('DrainCrossBar',(x,3.2,.025),(x,3.6,.025),.018,iron)
for y in [3.18,3.62]:tube('DrainFrame',(0,y,.025),(4,y,.025),.025,iron)
# One static mesh with two material surfaces, rather than a draw per grate bar.
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
for obj in meshes:
    bpy.context.view_layer.objects.active=obj
    for mod in list(obj.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join();bpy.context.object.name='AuthoredKerbAndDrain'
export('forecourt-detail')
for row in rows:
    row['source_sha256']=hashlib.sha256((ROOT/row['source']).read_bytes()).hexdigest()
(ROOT/'assets/art/r10/models.json').write_text(json.dumps(dict(status='EXECUTED',blender=bpy.app.version_string,license='CC0-1.0, original project tailoring and workshop; retained MakeHuman CC0 rig attribution',outputs=rows),indent=2)+'\n')
print('R10_MODELS '+json.dumps(rows))
