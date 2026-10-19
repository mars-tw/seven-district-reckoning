"""Background Blender: an authored corrugated canopy and garage life assembly."""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'godot/assets/models/r8';OUT.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/'assets/source/blender/r8';SOURCE.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(name,color,metal=0,rough=.7):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    return m
steel=mat('R8_AgedGalvanized',(.34,.30,.23),.55,.56)
dark=mat('R8_RubberAndCable',(.043,.037,.031),0,.91)
clay=mat('R8_Terracotta',(.42,.13,.058),0,.83)
leaf=mat('R8_OliveLeaves',(.19,.24,.075),0,.72)
light=mat('R8_WarmLamp',(.95,.60,.21),.12,.38)
def finish(o,name,m):o.name=name;o.data.materials.append(m);return o
def mesh(name,verts,faces,m):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o);return finish(o,name,m)
def tube(name,a,b,r,m):
    a,b=Vector(a),Vector(b);d=b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=10,radius=r,depth=d.length,location=(a+b)/2)
    o=bpy.context.object;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return finish(o,name,m)
def torus(name,p,major,minor,m):
    bpy.ops.mesh.primitive_torus_add(major_segments=28,minor_segments=8,major_radius=major,minor_radius=minor,location=p)
    return finish(bpy.context.object,name,m)
def lathe(name,p,profile,m):
    n=24;verts=[(p[0]+r*math.cos(i*math.tau/n),p[1]+r*math.sin(i*math.tau/n),p[2]+z) for r,z in profile for i in range(n)]
    faces=[(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(len(profile)-1) for i in range(n)]
    return mesh(name,verts,faces,m)
# Corrugation is actual curved sheet geometry with projecting gutter and braces.
n=160;verts=[]
for y in [0,1.7]:
    for i in range(n+1):
        x=-5.6+i*11.2/n;verts.append((x,y,4.8-y*.14+math.sin(i*math.pi/2)*.035))
mesh('CorrugatedGarageAwning',verts,[(i,i+1,n+i+2,n+i+1) for i in range(n)],steel)
tube('RoundedRainGutter',(-5.6,1.7,4.55),(5.6,1.7,4.55),.075,steel)
for x in [-5.4,0,5.4]:
    tube('CanopyDiagonalBrace',(x,0,4.2),(x,1.6,4.55),.035,steel)
tube('DrainDownpipe',(5.4,1.7,.2),(5.4,1.7,4.55),.055,steel)
# Two long sagging cables on the roof edge, not painted into a backdrop.
for offset in [0,.20]:
    prev=None
    for i in range(25):
        t=i/24;p=(-6+t*12,.2+offset,5.35-.65*math.sin(t*math.pi))
        if prev:tube('SaggingUtilityCable',prev,p,.018,dark)
        prev=p
for x in [-3.9,3.8]:
    tube('LampGooseneck',(x,0,3.45),(x,.55,3.65),.025,steel)
    lathe('SpunMetalShade',(x,.55,3.46),[(.21,0),(.20,.035),(.07,.16),(.03,.18)],steel)
    lathe('WarmLampLens',(x,.55,3.45),[(.15,0),(.15,.025)],light)
# Worn motorcycle tires and rims, with visible tread geometry.
for row in range(3):
    torus('StackedMotorcycleTire',(3.8,1.2,.18+row*.24),.31,.11,dark)
    for i in range(12):
        a=i*math.tau/12;tube('TreadSegment',(3.8+.40*math.cos(a),1.2+.40*math.sin(a),.13+row*.24),(3.8+.40*math.cos(a+.035),1.2+.40*math.sin(a+.035),.23+row*.24),.015,steel)
# A shaped terracotta planter and curved leaves to break hard shop edges.
lathe('GlazedPlanter',(-4.1,1.4,0),[(.18,0),(.20,.05),(.29,.48),(.32,.49),(.32,.55),(.28,.55)],clay)
for i in range(9):
    a=i*math.tau/9;x,y=-4.1,1.4;length=.45+(i%3)*.12
    stem=Vector((x,y,.52));tip=Vector((x+math.cos(a)*length,y+math.sin(a)*length,.95+(i%2)*.2));middle=(stem+tip)*.5+Vector((0,0,.20));side=Vector((-math.sin(a),math.cos(a),0))*.085
    mesh('CurvedPlantLeaf',[stem,middle-side,tip,middle+side],[(0,1,2),(0,2,3)],leaf)
for x in [2.5,2.8]:
    lathe('GarageOilBottle',(x,.4,.03),[(.10,0),(.10,.29),(.065,.34),(.035,.35),(.035,.43)],clay)
    tube('OilBottleCap',(x,.4,.43),(x,.4,.47),.042,dark)
# One object per material to keep draw calls bounded.
for material in [steel,dark,clay,leaf,light]:
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.materials[0]==material]
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:o.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join();bpy.context.object.name=material.name
blend=SOURCE/'garage-life.blend';glb=OUT/'garage-life.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',export_animations=False)
triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')
report=dict(status='EXECUTED',blender=bpy.app.version_string,license='CC0-1.0; original project-authored garage geometry',source=blend.relative_to(ROOT).as_posix(),path=glb.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(glb.read_bytes()).hexdigest(),bytes=glb.stat().st_size,triangles=triangles,material_batches=5,features=['corrugated canopy','rounded rain gutter and drain','sagging utility cables','gooseneck lamps','treaded tire stack','curved planter and leaves','oil bottles'])
(ROOT/'assets/art/r8/models.json').write_text(json.dumps(report,indent=2)+'\n');print('R8_MODEL '+json.dumps(report))
