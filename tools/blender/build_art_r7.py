"""Authored bevelled workshop and courier tailoring; Blender background only."""
import bpy, bmesh, json, math, hashlib
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'godot/assets/models/r7'
SOURCE = ROOT/'assets/source/blender/r7'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
rows = []

def mat(name, color, metal=0, rough=.7):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
    return m

def finish(o,name,m):
    o.name=name; o.data.materials.append(m)
    return o

def box(name,p,d,m,bevel=.015):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p); o=bpy.context.object; o.dimensions=d
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('AuthoredRoundedEdges','BEVEL'); mod.width=bevel; mod.segments=3
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(o,name,m)

def tube(name,a,b,r,m):
    a,b=Vector(a),Vector(b); d=b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r,depth=d.length,location=(a+b)/2)
    o=bpy.context.object; o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    return finish(o,name,m)

def torus(name,p,major,minor,m,rotation=(math.pi/2,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=6,location=p,major_radius=major,minor_radius=minor,rotation=rotation)
    return finish(bpy.context.object,name,m)

def export(name, animated=False):
    # Material batches keep phone draw calls bounded; actual detail is retained.
    if not animated:
        meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
        bpy.ops.object.select_all(action='DESELECT')
        for o in meshes:o.select_set(True)
        bpy.context.view_layer.objects.active=meshes[0]
        bpy.ops.object.join()
        bpy.context.object.name='AuthoredWorkshop'
    bpy.ops.object.select_all(action='DESELECT')
    objects=[o for o in bpy.context.scene.objects if o.type in ('MESH','ARMATURE','EMPTY')]
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'.blend')))
    filename='hero_human' if name=='ayuan-tailored' else name
    bpy.ops.export_scene.gltf(filepath=str(OUT/(filename+'.glb')),export_format='GLB',use_selection=True,export_yup=True,
        export_animations=animated,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_frame_range=False,export_skins=True)
    triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects if o.type=='MESH')
    rows.append(dict(id=name,source=(SOURCE/(name+'.blend')).relative_to(ROOT).as_posix(),path=(OUT/(filename+'.glb')).relative_to(ROOT).as_posix(),triangles=triangles,objects=len(objects),bytes=(OUT/(filename+'.glb')).stat().st_size,sha256=hashlib.sha256((OUT/(filename+'.glb')).read_bytes()).hexdigest()))

bpy.ops.wm.read_factory_settings(use_empty=True)
steel=mat('Workshop_Gunmetal',(.12,.15,.16),.6,.52)
wood=mat('Workshop_WarmOak',(.40,.23,.105),0,.8)
ochre=mat('Workshop_Ochre',(.66,.38,.06),.2,.6)
metal=mat('Tool_BrushedSteel',(.56,.61,.62),.8,.38)
rubber=mat('Tool_Rubber',(.035,.04,.038),0,.88)
red=mat('Tool_Vermilion',(.60,.12,.055),0,.65)
# Bevelled open workbench with six independent drawers and curved handles.
box('WornOakTop',(0,0,1.03),(2.8,.9,.12),wood,.035)
for x in [-1.23,1.23]:
    for y in [-.31,.31]: tube('TubularLeg',(x,y,.08),(x,y,.99),.042,steel)
box('LowerShelf',(0,0,.20),(2.65,.75,.055),steel)
for side in [-1,1]:
    for row in range(3):
        x=side*.94; z=.38+row*.20
        box('DrawerBody',(x,-.03,z),(.68,.69,.18),steel,.012)
        box('DrawerOchreFace',(x,-.392,z),(.66,.035,.165),ochre,.009)
        tube('DrawerHandle',(x-.15,-.45,z),(x+.15,-.45,z),.018,metal)
        for dx in [-.15,.15]:tube('HandleBracket',(x+dx,-.40,z),(x+dx,-.45,z),.012,metal)
for x in [-1.32,1.32]: tube('PegboardStand',(x,.37,1.0),(x,.37,2.15),.026,steel)
box('ToolBackboard',(0,.39,1.72),(2.7,.07,.87),steel,.018)
for x in range(17):
    for z in range(4):
        # Recessed metal eyelets; authored geometry rather than painted tools.
        torus('PegHole',(-1.20+x*.15,.342,1.42+z*.19),.010,.003,metal)
for i in range(7):
    x=-1.06+i*.33; z=1.57+(i%2)*.15
    tube('HangingWrenchShaft',(x,.29,z-.13),(x,.29,z+.13),.017,metal)
    torus('WrenchRing',(x,.29,z-.14),.036,.012,metal)
    for sign in [-1,1]:tube('WrenchJaw',(x,.29,z+.10),(x+sign*.034,.29,z+.17),.015,metal)
    tube('ToolHook',(x,.34,z+.20),(x,.26,z+.20),.008,metal)
box('BenchViseBase',(.86,-.02,1.13),(.31,.30,.08),red)
for y in [-.10,.10]:box('ViseJaw',(.86,y,1.23),(.28,.06,.18),steel)
tube('ViseScrew',(.60,0,1.18),(1.15,0,1.18),.019,metal)
tube('ViseHandle',(1.15,0,1.06),(1.15,0,1.30),.012,metal)
for x in [-.25,.05]:
    tube('OilCan',(x,.18,1.10),(x,.18,1.32),.045,ochre)
    tube('OilSpout',(x,.18,1.32),(x+.10,.18,1.39),.008,metal)
export('mei-workbench')

# Original CC0 MakeHuman rig remains intact. Remove just the old bag island,
# then tailor substantial sewn bag geometry and bind every piece to pelvis.
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/source/blender/hero_human.blend'))
body=bpy.data.objects['TailoredHuman']; rig=bpy.data.objects['HumanSkeleton']
bm=bmesh.new();bm.from_mesh(body.data)
remaining=set(bm.verts);old=set()
while remaining:
    seed=remaining.pop();island={seed};pending=[seed]
    while pending:
        v=pending.pop()
        for edge in v.link_edges:
            other=edge.other_vert(v)
            if other in remaining:remaining.remove(other);island.add(other);pending.append(other)
    center=sum((v.co for v in island),Vector())/len(island)
    if len(island)==96 and (center-Vector((.24,.10,.979))).length<.001:old=island
assert len(old)==96, 'Only the measured disconnected original bag may be removed'
bmesh.ops.delete(bm,geom=list(old),context='VERTS');bm.to_mesh(body.data);bm.free()
canvas=mat('Courier_OrangeCanvas',(.91,.255,.035),0,.9)
leather=mat('Courier_Straps',(.11,.075,.045),0,.8)
seam=mat('Courier_Stitch',(.95,.65,.23),0,.8)
buckle=mat('Courier_Brass',(.46,.29,.09),.65,.4)
parts=[]
parts.append(box('SewnBagGusset',(.27,.13,.98),(.34,.19,.34),canvas,.035))
parts.append(box('SewnFoldedFlap',(.27,.241,1.071),(.355,.035,.16),canvas,.022))
parts.append(box('BagLowerPocket',(.27,.241,.92),(.27,.035,.13),canvas,.012))
for x in [.17,.37]:
    parts.append(box('BagBuckleStrap',(x,.264,.99),(.026,.016,.19),leather,.003))
    parts.append(box('BagBuckle',(x,.276,1.006),(.044,.014,.035),buckle,.004))
for z in [.832,1.146]:parts.append(tube('BagStitchLine',(.125,.232,z),(.415,.232,z),.0028,seam))
for x in [.125,.415]:parts.append(tube('BagSideSeam',(x,.232,.84),(x,.232,1.14),.0028,seam))
for o in parts:
    # Apply translation so vertex positions and armature coordinates agree.
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    g=o.vertex_groups.new(name='pelvis');g.add(range(len(o.data.vertices)),1,'REPLACE')
    mod=o.modifiers.new('OriginalPelvisSkin','ARMATURE');mod.object=rig;o.parent=rig
# Existing material shader only adds sleeve marks; the new bag has real depth.
export('ayuan-tailored',True)
(ROOT/'assets/art/r7/models.json').write_text(json.dumps(dict(status='EXECUTED',blender=bpy.app.version_string,license='CC0-1.0; original workshop geometry and CC0 MakeHuman courier derivative',outputs=rows),indent=2)+'\n')
print('R7_MODELS '+json.dumps(rows))
