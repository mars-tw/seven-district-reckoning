"""Original metric Taiwan neighbourhood kit (CC0-1.0), Blender 5.2.

The buildings and furniture are original authored geometry. References inform
public-space traits; photographs, map tiles, brand logos and source meshes are
not copied. Blender -Y is the facade; GLTF export makes Godot +Z the facade.
"""
import bpy
import numpy as np
import math, json, hashlib, sys, argparse
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot/assets/models"
TEX = ROOT / "godot/assets/textures/taiwan"
SOURCE = ROOT / "assets/source/blender/taiwan"
QA = ROOT / "qa/art/taiwan"
for p in (OUT, TEX, SOURCE, QA): p.mkdir(parents=True, exist_ok=True)
MANIFEST = []

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = 'METRIC'

def textures():
    rng = np.random.default_rng(404)
    n=128; y,x=np.mgrid[:n,:n]
    for kind,rgb in [('tile',(.69,.65,.55)),('metal',(.37,.40,.40)),('canvas',(.77,.46,.23)),('asphalt',(.16,.18,.18)),('pavers',(.58,.55,.49))]:
        noise=rng.normal(0,.018,(n,n))
        if kind in ('tile','pavers'):
            noise[(x%32<2)|(y%32<2)]-=.16
            noise+=((x//32+y//32)%3-1)*.035
        elif kind=='metal': noise+=np.sin(y*.7)*.012
        else: noise+=((x%2)+(y%2)-1)*.017
        pixels=np.ones((n,n,4),np.float32); pixels[:,:,:3]=np.clip(np.array(rgb)+noise[:,:,None],0,1)
        im=bpy.data.images.new('tw_'+kind+'_albedo',n,n,alpha=True)
        im.pixels.foreach_set(pixels.ravel()); im.filepath_raw=str(TEX/(im.name+'.png'));im.file_format='PNG';im.save()
        # Code-loaded floor textures need an explicit 3D mipmap import hint.
        hint=TEX/(im.name+'.png.import')
        if not hint.exists():hint.write_text('[params]\nmipmaps/generate=true\n',encoding='utf-8')

def mat(name,rgb,rough=.8,metal=0,texture=None,emission=0):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*rgb,1)
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*rgb,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    if texture:
        node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=bpy.data.images.load(str(TEX/('tw_'+texture+'_albedo.png')))
        m.node_tree.links.new(node.outputs['Color'],p.inputs['Base Color'])
    if emission:
        p.inputs['Emission Color'].default_value=(*rgb,1);p.inputs['Emission Strength'].default_value=emission
    return m

def palette(style='warm'):
    return {'tile':mat('TiledMasonry',(.69,.65,.55),texture='tile'),
            'metal':mat('GalvanizedMetal',(.37,.40,.40),.42,.66,texture='metal'),
            'glass':mat('OpaqueStoreGlazing',(.23,.38,.40),.27,.25),
            'dark':mat('CharcoalRecess',(.075,.095,.10),.94),
            'cream':mat('PaintedCream',(.88,.84,.70),.81),
            'accent':mat('FictionalShopAccent',(.08,.40,.41) if style=='cool' else (.80,.33,.11),.78),
            'canvas':mat('WovenAwning',(.77,.46,.23),texture='canvas'),
            'green':mat('LeafAndProduce',(.26,.45,.20),.91)}

class MeshBuilder:
    """Construction faces are merged by material before export (<=8 draws)."""
    def __init__(self): self.data={}
    def face(self,material,vertices,uv=None):
        d=self.data.setdefault(material.name,{'v':[],'f':[],'uv':[],'m':material});s=len(d['v']);d['v'].extend(vertices);d['f'].append(tuple(range(s,s+len(vertices))))
        # One texture repeat represents one metre: four tiled divisions in
        # the 128 px pattern therefore read as 25 cm facade tiles, not 2 m.
        if uv is None:
            normal=(Vector(vertices[1])-Vector(vertices[0])).cross(Vector(vertices[2])-Vector(vertices[0]))
            axis=max(range(3),key=lambda i:abs(normal[i]));axes=[i for i in range(3) if i!=axis]
            uv=[(float(v[axes[0]]),float(v[axes[1]])) for v in vertices]
        d['uv'].append(uv)
    def box(self,p,dim,m):
        x,y,z=p;a,b,c=[v*.5 for v in dim]
        v=[(x-a,y-b,z-c),(x+a,y-b,z-c),(x+a,y+b,z-c),(x-a,y+b,z-c),(x-a,y-b,z+c),(x+a,y-b,z+c),(x+a,y+b,z+c),(x-a,y+b,z+c)]
        for f in [(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]:self.face(m,[v[i] for i in f])
    def cylinder(self,p,r,h,m,sides=12,axis='z'):
        def pt(angle,level):
            return (p[0]+level,p[1]+r*math.cos(angle),p[2]+r*math.sin(angle)) if axis=='x' else (p[0]+r*math.cos(angle),p[1]+r*math.sin(angle),p[2]+level)
        for i in range(sides):
            a=i*math.tau/sides;c=(i+1)*math.tau/sides
            self.face(m,[pt(a,-h/2),pt(c,-h/2),pt(c,h/2),pt(a,h/2)])
            self.face(m,[pt(a,h/2),pt(c,h/2),(p[0]+h/2,p[1],p[2]) if axis=='x' else (p[0],p[1],p[2]+h/2)])
            self.face(m,[pt(c,-h/2),pt(a,-h/2),(p[0]-h/2,p[1],p[2]) if axis=='x' else (p[0],p[1],p[2]-h/2)])
    def ellipsoid(self,p,radii,m,sides=12,rings=6):
        for j in range(rings):
            a=-math.pi/2+j*math.pi/rings;b=-math.pi/2+(j+1)*math.pi/rings
            for i in range(sides):
                c=i*math.tau/sides;d=(i+1)*math.tau/sides
                def pt(t,u):return (p[0]+radii[0]*math.cos(t)*math.cos(u),p[1]+radii[1]*math.cos(t)*math.sin(u),p[2]+radii[2]*math.sin(t))
                self.face(m,[pt(a,c),pt(a,d),pt(b,d),pt(b,c)])
    def beam(self,a,b,width,m):
        va,vb=Vector(a),Vector(b);direction=(vb-va).normalized();other=direction.cross(Vector((0,0,1)))
        if other.length<.1:other=Vector((1,0,0))
        other.normalize();up=direction.cross(other).normalized();c=[other*width*.5+up*width*.5,-other*width*.5+up*width*.5,-other*width*.5-up*width*.5,other*width*.5-up*width*.5]
        for i in range(4):self.face(m,[va+c[i],va+c[(i+1)%4],vb+c[(i+1)%4],vb+c[i]])
    def finish(self):
        for name,d in self.data.items():
            mesh=bpy.data.meshes.new(name);mesh.from_pydata(d['v'],[],d['f']);mesh.update();uv=mesh.uv_layers.new(name='UVMap')
            for polygon,coords in zip(mesh.polygons,d['uv']):
                for li,value in zip(polygon.loop_indices,coords):uv.data[li].uv=value
            obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);mesh.materials.append(d['m']);obj['license']='CC0-1.0';obj['authored_by']='Seven District original Taiwan kit'

def shutter(b,m,x,y,z,width,height):
    b.box((x,y,z),(width,.12,height),m['metal'])
    for dz in np.arange(-height*.5+.06,height*.5,.14):b.box((x,y-.077,z+float(dz)),(width,.033,.035),m['dark'])
    for dx in [-width*.5,width*.5]:b.box((x+dx,y-.085,z),(.075,.075,height),m['cream'])
    b.box((x,y-.1,z-height*.5+.15),(.35,.07,.065),m['dark'])

def awning(b,m,p,width,depth,color=None):
    x,y,z=p;mm=color or m['canvas']
    b.face(mm,[(x-width/2,y,z+.22),(x+width/2,y,z+.22),(x+width/2,y-depth,z),(x-width/2,y-depth,z)])
    b.box((x,y-depth,z-.14),(width,.06,.28),mm)
    for dx in [-width*.5,width*.5]:b.beam((x+dx,y,z+.17),(x+dx,y-depth,z-.07),.075,m['metal'])

def exterior(b,m,width,depth,floors,arcade=False):
    height=3.6*floors;rear=1.2;front=-depth/2+2.4 if arcade else -depth/2
    core_depth=depth-2.4 if arcade else depth
    b.box((0,rear if arcade else 0,height/2),(width,core_depth,height),m['tile'])
    for floor in range(1,floors):
        z=3.6*floor+1.6
        for x in [-width*.30,0,width*.30]:
            b.box((x,front-.08,z),(width*.23,.08,1.70),m['dark']);b.box((x,front-.16,z),(width*.21,.055,1.52),m['glass'])
            b.box((x,front-.2,z),(.055,.06,1.6),m['metal']);b.box((x,front-.2,z-.50),(width*.23,.08,.055),m['metal'])
        b.box((width*.34,front-.39,z-1.0),(1.0,.60,.50),m['cream'])
        for i in range(6):b.box((width*.34-.36+i*.15,front-.71,z-1.0),(.045,.015,.32),m['metal'])
    b.box((0,0,height+.14),(width+.15,depth+.15,.28),m['cream'])
    b.cylinder((width*.26,depth*.18,height+.85),.73,1.42,m['metal'],16)
    b.cylinder((width*.26,depth*.18,height+1.58),.77,.12,m['metal'],16)
    for z in [height+.35,height+1.2]:b.cylinder((width*.26,depth*.18,z),.77,.06,m['cream'],16)
    return front,height

def arcade():
    reset();m=palette();b=MeshBuilder();front,h=exterior(b,m,10,10,2,True)
    for x in [-2.5,2.5]:shutter(b,m,x,front-.05,1.4,4.2,2.8)
    b.box((0,-4,3.23),(10.2,3.1,.35),m['cream'])
    for x in [-4.6,4.6]:b.box((x,-4.62,1.5),(.42,.42,3.0),m['tile'])
    b.box((0,-5.60,3.45),(9.6,.15,.72),m['accent'])
    awning(b,m,(0,-4.0,2.9),8.4,1.50)
    b.finish();export('tw_arcade_shop',{'traits':['covered_arcade','roller_shutter','tiled_facade','external_AC','roof_water_tank'],'collision_boxes':[[[0,3.6,-1.2],[10,7.2,7.6]],[[-4.6,1.5,4.62],[.42,3,.42]],[[4.6,1.5,4.62],[.42,3,.42]]],'role':'Original low-rise covered arcade; front walkway stays open'})

def convenience():
    reset();m=palette('cool');b=MeshBuilder();b.box((0,0,1.8),(12,8,3.6),m['tile']);y=-4.06
    for x in [-4.4,-2.2,0,2.2,4.4]:
        b.box((x,y,1.48),(2.04,.07,2.65),m['glass']);b.box((x-1.05,y-.06,1.5),(.08,.10,2.85),m['metal'])
    b.box((0,y-.08,2.94),(11.7,.12,.16),m['cream'])
    for z,mm,height in [(3.24,m['cream'],.58),(3.48,m['accent'],.10),(3.0,m['canvas'],.08)]:b.box((0,-4.1,z),(12.0,.2,height),mm)
    b.box((0,-5.20,2.88),(12.8,2.25,.20),m['cream'])
    b.box((0,y-.19,3.24),(4.6,.12,.38),m['accent'])
    for x in [-.62,.62]:b.box((x,y-.13,1.35),(.08,.08,2.55),m['cream']);b.box((x-.1,y-.18,1.12),(.035,.055,.45),m['metal'])
    for x in [-5.6,5.6]:b.cylinder((x,-5.75,.43),.11,.86,m['accent'],10)
    b.box((4.6,-4.32,.6),(.85,.38,1.2),m['cream']);b.box((4.6,-4.55,.8),(.66,.04,.52),m['dark'])
    b.box((0,0,3.75),(12.15,8.15,.30),m['metal']);b.finish()
    export('tw_convenience',{'traits':['sliding_glass_doors','ATM_recess','weather_canopy','original_cyan_ochre_fascia'],'collision_boxes':[[[0,1.9,0],[12,3.8,8]]],'role':'Fictional 日常便利; no real retailer logo or trade dress'})

def parcel():
    reset();m=palette();b=MeshBuilder();b.box((0,.7,2),(10,6.6,4),m['tile']);y=-2.65
    # Deliberately separate lockers, working counter and signage, not a renamed convenience shop.
    b.box((2.15,y-.08,1.28),(4.4,.8,2.56),m['dark'])
    for row in range(4):
        for col in range(5):
            x=.36+col*.89;z=.35+row*.6;b.box((x,y-.56,z),(.83,.08,.53),m['accent']);b.box((x+.30,y-.61,z),(.035,.035,.15),m['metal'])
    b.box((-2.6,y-.30,.50),(3.6,.8,1.0),m['cream']);b.box((-2.6,y-.30,1.03),(3.8,1.0,.11),m['metal'])
    for p in [(-3.65,y-.3,1.27),(-2.7,y-.15,1.24),(-3.2,y+.1,1.44)]:
        b.box(p,(.55,.40,.4),m['canvas']);b.box((p[0],p[1]-.205,p[2]),(.08,.02,.40),m['cream'])
    b.box((-1.4,y-.26,1.40),(.45,.10,.42),m['dark']);b.box((-1.4,y-.32,1.4),(.36,.03,.29),m['glass'])
    b.box((0,-2.7,3.28),(9.8,.12,.9),m['accent']);awning(b,m,(0,-2.6,2.9),10,2.3)
    b.box((0,.7,4.12),(10.2,6.8,.24),m['metal']);b.finish()
    export('tw_parcel_station',{'traits':['parcel_lockers','parcel_counter','labelled_cardboard_parcels','rain_awning'],'collision_boxes':[[[0,2,-.7],[10,4,6.6]]],'role':'Original 橘盒取貨站; fictional parcel service'})

def stall(name,kind):
    reset();m=palette('cool' if kind=='market' else 'warm');b=MeshBuilder()
    width=3.8 if kind=='market' else 3.2
    for x in [-width*.46,width*.46]:
        for y in [-1.2,1.2]:b.box((x,y,1.35),(.065,.065,2.7),m['metal'])
    awning(b,m,(0,1.45,2.75),width+.35,3.05,m['canvas'] if kind!='market' else m['accent'])
    b.box((0,-.2,.57),(width,1.8,1.14),m['accent']);b.box((0,-.2,1.18),(width+.12,1.96,.12),m['metal'])
    b.box((0,-1.13,.57),(width-.25,.06,.58),m['cream'])
    for x in [-width*.40,width*.40]:
        b.cylinder((x,.25,.16),.16,.1,m['dark'],12,'x')
    if kind=='market':
        for col in range(4):
            x=-1.42+col*.94
            b.box((x,-.38,1.34),(.78,.88,.22),m['cream'])
            for i in range(3):
                for j in range(3):b.ellipsoid((x-.25+i*.25,-.62+j*.24,1.53),(.13,.12,.11),m['green'] if col%2 else m['accent'],8,4)
    else:
        for x in [-1.1,.4]:b.cylinder((x,-.35,1.23),.40,.085,m['dark'],18)
        if kind=='breakfast':
            for x in [-1.22,-.86]:b.ellipsoid((x,-.40,1.31),(.20,.15,.035),m['cream'],12,3)
            b.box((.3,.4,1.48),(.65,.5,.55),m['cream']);b.box((.3,.13,1.47),(.48,.02,.24),m['glass'])
        else:
            b.cylinder((.4,-.35,1.45),.32,.42,m['metal'],16);b.cylinder((.4,-.35,1.69),.32,.06,m['cream'],16)
            for x in [-1.16,-.75]:b.cylinder((x,-.4,1.45),.095,.30,m['cream'],12)
    b.box((0,-1.35,2.28),(width-.3,.08,.5),m['cream'])
    b.finish();export(name,{'traits':['portable_food_cart','woven_rain_canopy','working_counter',kind+'_props'],'collision_boxes':[[[0,.65,.2],[width,1.3,1.8]]],'role':kind+' stall at life-size 1.18 m working surface'})

def scooter():
    reset();m=palette('cool');b=MeshBuilder()
    for y in [-.64,.68]:
        b.cylinder((0,y,.25),.25,.15,m['dark'],20,'x');b.cylinder((.082,y,.25),.15,.012,m['metal'],14,'x');b.cylinder((-.082,y,.25),.15,.012,m['metal'],14,'x')
    # Curved under-seat body and open step-through space distinguish scooter geometry.
    b.ellipsoid((0,.42,.53),(.25,.48,.30),m['accent'],16,8)
    b.box((0,-.16,.28),(.39,.72,.09),m['metal'])
    b.beam((0,-.65,.3),(0,-.53,1.00),.10,m['metal'])
    b.ellipsoid((0,-.50,.77),(.29,.17,.33),m['accent'],16,8)
    b.ellipsoid((0,.33,.88),(.25,.47,.09),m['dark'],16,6)
    b.box((0,.82,.68),(.44,.07,.20),m['cream'])
    b.beam((-.30,-.52,1.01),(.30,-.52,1.01),.09,m['metal'])
    for side in [-1,1]:
        b.beam((side*.24,-.52,1.02),(side*.32,-.52,1.22),.025,m['metal']);b.ellipsoid((side*.34,-.52,1.24),(.085,.038,.048),m['glass'],10,4)
    b.ellipsoid((0,-.69,.83),(.17,.024,.08),m['cream'],14,4)
    b.beam((.14,.40,.32),(.21,.68,.34),.10,m['metal']);b.box((0,.87,.54),(.20,.018,.12),m['cream']);b.finish()
    export('tw_scooter',{'traits':['two_wheels','step_through_frame','handlebars_and_mirrors','blank_licence_plate'],'collision_boxes':[[[0,.65,0],[.65,1.3,1.9]]],'role':'Original parked scooter; decorative, not a drivable vehicle claim'})

def lantern_gate():
    reset();m=palette();b=MeshBuilder()
    for x in [-4,4]:b.box((x,0,2.1),(.15,.15,4.2),m['metal'])
    b.beam((-4,0,4.2),(4,0,4.2),.09,m['metal'])
    for x in [-3,-1.5,0,1.5,3]:
        b.beam((x,0,4.2),(x,0,3.8),.028,m['dark']);b.ellipsoid((x,0,3.48),(.29,.29,.39),m['accent'],16,8)
        for z in [3.12,3.84]:b.cylinder((x,0,z),.17,.055,m['cream'],12)
        for i in range(3):b.beam((x+(i-1)*.04,0,3.10),(x+(i-1)*.035,0,2.94),.02,m['canvas'])
    b.box((0,.04,4.03),(2.7,.10,.56),m['cream']);b.finish()
    export('tw_lantern_gate',{'traits':['hanging_paper_lanterns','night_market_string','unbranded_signboard'],'collision_boxes':[[[-4,2.1,0],[.15,4.2,.15]],[[4,2.1,0],[.15,4.2,.15]]],'role':'Original evening market entrance; upper decoration leaves passage open'})

def shelter():
    reset();m=palette('cool');b=MeshBuilder()
    for x in [-2.4,2.4]:
        for y in [-.7,.7]:b.box((x,y,1.37),(.085,.085,2.74),m['metal'])
    b.box((0,.78,1.48),(4.75,.07,2.50),m['glass']);b.box((0,0,2.80),(5.4,2.10,.16),m['cream']);b.box((0,-.95,2.67),(5.25,.15,.38),m['accent'])
    for x in [-1.4,-.2,1.0]:
        b.box((x,.42,.47),(1.05,.46,.06),m['cream']);b.box((x,.68,.80),(1.05,.06,.35),m['cream']);b.box((x,.42,.23),(.075,.37,.46),m['metal'])
    b.box((2.0,.71,1.5),(.55,.07,1.08),m['cream'])
    for z in [1.25,1.45,1.65,1.85]:b.box((2.0,.665,z),(.36,.018,.034),m['accent'])
    b.finish();export('tw_bus_shelter',{'traits':['covered_bus_stop','timetable_board','public_bench'],'collision_boxes':[[[0,1.4,-.78],[5,2.8,.1]]],'role':'Original public waiting shelter; front opening clear'})

def pavilion():
    reset();m=palette('cool');b=MeshBuilder()
    for x in [-2.5,2.5]:
        for y in [-2.5,2.5]:b.box((x,y,1.45),(.20,.20,2.90),m['metal'])
    v=[(-3,-3,2.96),(3,-3,2.96),(3,3,2.96),(-3,3,2.96)];top=(0,0,4.1)
    for i in range(4):b.face(m['accent'],[v[i],v[(i+1)%4],top])
    for x in [-2.1,2.1]:b.box((x,0,.47),(.5,4,.09),m['cream']);b.box((x,0,.24),(.10,3.7,.46),m['metal'])
    b.finish();export('tw_river_pavilion',{'traits':['shaded_river_rest','open_pavilion','public_seating'],'collision_boxes':[],'role':'Open shaded rest pavilion; collision supplied only by supports at integration'})

def recycling():
    reset();m=palette('cool');b=MeshBuilder()
    for i in range(3):
        x=-1.3+i*1.3;b.box((x,0,.67),(1.1,.9,1.34),m['accent'] if i%2 else m['cream']);b.box((x,0,1.38),(1.2,1.0,.10),m['metal']);b.box((x,-.51,1.18),(.70,.04,.2),m['dark'])
        b.box((x,-.475,.8),(.55,.02,.27),m['cream']);b.cylinder((x,-.51,.78),.06,.012,m['green'],8)
    for x in [-2.05,2.05]:b.box((x,.75,1.25),(.075,.075,2.5),m['metal'])
    awning(b,m,(0,.85,2.6),4.35,2.4);b.finish()
    export('tw_recycling_station',{'traits':['covered_recycling_bins','sorted_material_slots','local_collection_point'],'collision_boxes':[[[0,.7,0],[4.0,1.4,1.0]]],'role':'Village recycling collection point; no copied municipal marks'})

def parcel_shelf():
    reset();m=palette();b=MeshBuilder()
    for x in [-.8,.8]:
        for y in [-.28,.28]:b.box((x,y,1.0),(.045,.045,2),m['metal'])
    for z in [.15,.70,1.25,1.80]:
        b.box((0,0,z),(1.7,.67,.035),m['metal'])
        for i in range(3):
            x=-.54+i*.54;b.box((x,0,z+.20),(.46,.47,.37),m['canvas']);b.box((x,-.24,z+.21),(.22,.015,.10),m['cream']);b.box((x,0,z+.40),(.055,.47,.015),m['cream'])
    b.finish();export('tw_parcel_shelf',{'traits':['sorted_cardboard_boxes','metal_rack','paper_labels'],'collision_boxes':[[[0,1,0],[1.7,2,.7]]],'role':'Working pickup counter accessory'})

def rowhouse():
    reset();m=palette('cool');b=MeshBuilder();front,h=exterior(b,m,10,10,3)
    shutter(b,m,-2.5,front-.03,1.38,4.25,2.75);b.box((2.5,front-.05,1.40),(4.2,.11,2.8),m['glass'])
    b.box((2.5,front-.15,1.35),(.07,.08,2.7),m['metal']);awning(b,m,(0,front+.08,3.1),10,1.35)
    # Balcony guard rails and old tile relief are genuine depth, legible in side view.
    for floor in [1,2]:
        z=floor*3.6+.60;b.box((0,front-.62,z-.5),(9.0,1.1,.17),m['cream'])
        for x in np.arange(-4.2,4.3,.52):b.box((float(x),front-1.14,z),(.055,.055,.88),m['metal'])
        b.box((0,front-1.14,z+.45),(8.6,.075,.065),m['metal'])
    b.finish();export('tw_rowhouse',{'traits':['mixed_use_low_rise','balcony_guardrails','corrugated_shutter','roof_water_tank','external_AC'],'collision_boxes':[[[0,h/2,0],[10,h,10]]],'role':'Original older Taiwanese mixed-use building'})

def export(name,metadata):
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH'];bpy.context.view_layer.update()
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_extras=True,export_animations=False,export_cameras=False,export_lights=False)
    for im in bpy.data.images:
        if im.filepath:im.filepath=bpy.path.relpath(im.filepath,start=str(SOURCE))
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'.blend')))
    coords=[];triangles=0
    for o in objects:o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles);coords.extend(o.matrix_world@v.co for v in o.data.vertices)
    lo=[min(v[i] for v in coords) for i in range(3)];hi=[max(v[i] for v in coords) for i in range(3)]
    p=OUT/(name+'.glb');entry={'name':name,'path':p.relative_to(ROOT).as_posix(),'source':(SOURCE/(name+'.blend')).relative_to(ROOT).as_posix(),'license':'CC0-1.0','triangles':triangles,'materials':len(objects),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bounds_blender_min':lo,'bounds_blender_max':hi,**metadata}
    assert triangles<12000 and len(objects)<=8,(name,triangles,len(objects));MANIFEST.append(entry)
    print('TAIWAN_ASSET_DONE',name,triangles,p.stat().st_size,flush=True)
    render(name,lo,hi)

def render(name,lo,hi):
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True
    scene.render.resolution_x=800;scene.render.resolution_y=600;scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new('TaiwanReviewSky');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.71,.75,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
    bpy.ops.mesh.primitive_plane_add(size=100,location=(0,0,-.03));ground=bpy.context.object;ground.name='QA_Ground';ground.data.materials.append(mat('QAGround',(.46,.49,.44)))
    target=Vector(((lo[0]+hi[0])/2,(lo[1]+hi[1])/2,(hi[2]-lo[2])*.42));span=max(hi[i]-lo[i] for i in range(3))
    bpy.ops.object.camera_add(location=target+Vector((span*.73,-span*1.1,span*.56)));camera=bpy.context.object;camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=span*1.45;scene.camera=camera
    bpy.ops.object.light_add(type='SUN');sun=bpy.context.object;sun.rotation_euler=(.55,-.31,-.45);sun.data.energy=2.2
    scene.render.filepath=str(QA/(name+'_preview.png'));bpy.ops.render.render(write_still=True)

def main():
    reset();textures();arcade();convenience();parcel();stall('tw_breakfast_stall','breakfast');stall('tw_food_stall','hot_food');stall('tw_market_stall','market');scooter();lantern_gate();shelter();pavilion();recycling();parcel_shelf();rowhouse()
    total=sum(a['bytes'] for a in MANIFEST)+sum(p.stat().st_size for p in TEX.glob('*.png'))
    assert total<10*1024*1024,(total,'Taiwan Web source budget')
    document={'schema_version':1,'generator':'tools/blender/build_taiwan_assets.py','license':'CC0-1.0','texture_max':128,'runtime_source_bytes':total,'assets':MANIFEST,'authorship':'Original procedural authored geometry and deterministic PBR textures; no map imagery or brand marks copied','limitations':'Culture-inspired fictional compressed neighbourhood; not a surveyed replica of Taichung'}
    (QA/'taiwan-manifest.json').write_text(json.dumps(document,ensure_ascii=False,indent=2),encoding='utf-8')
    (ROOT/'godot/data/taiwan_asset_manifest.json').write_text(json.dumps(document,ensure_ascii=False,indent=2),encoding='utf-8')
    print('TAIWAN_BUILD_PASS bytes='+str(total),flush=True)

if __name__=='__main__':main()
