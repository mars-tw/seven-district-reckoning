"""Original metric urban kit. Run with Blender 5.2 --background --python this_file.

All geometry and deterministic PBR pixels are authored here (CC0-1.0).
No reference photographs, map imagery, or third-party model downloads are used.
"""
import bpy
import numpy as np
import math, json, hashlib, argparse, sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'godot/assets/models'
TEX = ROOT / 'godot/assets/textures/urban'
SOURCE = ROOT / 'assets/source/blender/urban'
QA = ROOT / 'qa/art/urban'
for p in (OUT, TEX, SOURCE, QA): p.mkdir(parents=True, exist_ok=True)
MANIFEST = []

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1.0

def image(name, pixels):
    height, width = pixels.shape[:2]
    im = bpy.data.images.get(name) or bpy.data.images.new(name, width, height, alpha=True)
    im.pixels.foreach_set(np.ascontiguousarray(pixels, dtype=np.float32).ravel())
    im.filepath_raw = str(TEX / (name + '.png'))
    im.file_format = 'PNG'; im.save()
    return im

def textures():
    """Shared 256 px albedo, tangent normal, packed ORM. Metric patterns repeat."""
    rng = np.random.default_rng(7303)
    size = 256; y, x = np.mgrid[0:size, 0:size]
    for kind, rgb, rough in [('granite',(.48,.47,.44),.87), ('asphalt',(.155,.17,.18),.96),
                              ('pavers',(.55,.54,.49),.90), ('glass',(.25,.37,.41),.28)]:
        noise = rng.normal(0,.02 if kind != 'asphalt' else .025,(size,size))
        ao = np.ones((size,size)); height = noise * .05
        if kind == 'pavers':
            joints = ((x % 128) < 3) | ((y % 64) < 3)
            ao[joints] = .70; noise[joints] -= .12; height[joints] -= .015
            noise += ((x//128+y//64)%3-.8)*.015
        elif kind == 'granite':
            noise += .02*np.sin(x*.13)*np.cos(y*.18)
        elif kind == 'glass':
            noise *= .13
            noise += (.045*np.cos(y/size*math.pi)+.018*np.sin(x/size*math.pi*3))
            # Very subtle blinds/reflection; opaque to avoid mobile transparency sorting.
            noise += .012*((y%13)<2)
            edge = np.minimum.reduce([x,y,size-1-x,size-1-y])
            ao = np.where(edge < 7,.60,1.0); noise -= (1-ao)*.10
        albedo = np.zeros((size,size,4)); albedo[:,:,:3] = np.clip(np.array(rgb)+noise[:,:,None],0,1)*ao[:,:,None]; albedo[:,:,3]=1
        normal = np.ones((size,size,4)); normal[:,:,0]=.5-np.gradient(height,axis=1)*2; normal[:,:,1]=.5-np.gradient(height,axis=0)*2; normal[:,:,2]=1; normal[:,:,3]=1
        orm = np.ones((size,size,4)); orm[:,:,0]=ao; orm[:,:,1]=np.clip(rough+noise*.8,.05,1); orm[:,:,2]=.32 if kind == 'glass' else 0
        image('urban_'+kind+'_albedo',albedo); image('urban_'+kind+'_normal',normal); image('urban_'+kind+'_orm',orm)

def material(name, rgb, rough=.7, metal=0, texture=None):
    m = bpy.data.materials.new(name); m.use_nodes=True; m.diffuse_color=(*rgb,1)
    nodes=m.node_tree.nodes; shader=nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=(*rgb,1); shader.inputs['Roughness'].default_value=rough; shader.inputs['Metallic'].default_value=metal
    if texture:
        al=nodes.new('ShaderNodeTexImage'); al.image=bpy.data.images.load(str(TEX/('urban_'+texture+'_albedo.png'))); m.node_tree.links.new(al.outputs['Color'],shader.inputs['Base Color'])
        nr=nodes.new('ShaderNodeTexImage'); nr.image=bpy.data.images.load(str(TEX/('urban_'+texture+'_normal.png'))); nr.image.colorspace_settings.name='Non-Color'
        nm=nodes.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value=.16
        m.node_tree.links.new(nr.outputs['Color'],nm.inputs['Color']); m.node_tree.links.new(nm.outputs['Normal'],shader.inputs['Normal'])
        mr=nodes.new('ShaderNodeTexImage'); mr.image=bpy.data.images.load(str(TEX/('urban_'+texture+'_orm.png'))); mr.image.colorspace_settings.name='Non-Color'
        sep=nodes.new('ShaderNodeSeparateColor'); m.node_tree.links.new(mr.outputs['Color'],sep.inputs['Color'])
        m.node_tree.links.new(sep.outputs['Green'],shader.inputs['Roughness']); m.node_tree.links.new(sep.outputs['Blue'],shader.inputs['Metallic'])
    return m

class Builder:
    def __init__(self): self.data={}
    def polygon(self, name, material, vertices, uv=None):
        d=self.data.setdefault(material.name,{'verts':[],'faces':[],'uv':[],'mat':material})
        start=len(d['verts']); d['verts'].extend(vertices); d['faces'].append(tuple(range(start,start+len(vertices))))
        d['uv'].append(uv or [(0,0),(1,0),(1,1),(0,1)][:len(vertices)])
    def box(self, name, p, dimensions, material):
        x,y,z=p; a,b,c=[v/2 for v in dimensions]
        v=[(x-a,y-b,z-c),(x+a,y-b,z-c),(x+a,y+b,z-c),(x-a,y+b,z-c),(x-a,y-b,z+c),(x+a,y-b,z+c),(x+a,y+b,z+c),(x-a,y+b,z+c)]
        for f in [(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]: self.polygon(name,material,[v[i] for i in f])
    def quad(self, name, p, width, height, material, side=0):
        x,y,z=p
        if side==0: v=[(x-width/2,y,z-height/2),(x+width/2,y,z-height/2),(x+width/2,y,z+height/2),(x-width/2,y,z+height/2)]
        elif side==1: v=[(x,y+width/2,z-height/2),(x,y-width/2,z-height/2),(x,y-width/2,z+height/2),(x,y+width/2,z+height/2)]
        elif side==2: v=[(x+width/2,y,z-height/2),(x-width/2,y,z-height/2),(x-width/2,y,z+height/2),(x+width/2,y,z+height/2)]
        else: v=[(x,y-width/2,z-height/2),(x,y+width/2,z-height/2),(x,y+width/2,z+height/2),(x,y-width/2,z+height/2)]
        self.polygon(name,material,v)
    def cylinder(self,name,p,radius,height,material,sides=12):
        for j in range(sides):
            a=j*math.tau/sides;b=(j+1)*math.tau/sides
            self.polygon(name,material,[(p[0]+radius*math.cos(a),p[1]+radius*math.sin(a),p[2]-height/2),(p[0]+radius*math.cos(b),p[1]+radius*math.sin(b),p[2]-height/2),(p[0]+radius*math.cos(b),p[1]+radius*math.sin(b),p[2]+height/2),(p[0]+radius*math.cos(a),p[1]+radius*math.sin(a),p[2]+height/2)])
    def finish(self):
        for key,d in self.data.items():
            mesh=bpy.data.meshes.new(key);mesh.from_pydata(d['verts'],[],d['faces']);mesh.update()
            uv=mesh.uv_layers.new(name='UVMap')
            for face,coords in zip(mesh.polygons,d['uv']):
                for li,value in zip(face.loop_indices,coords): uv.data[li].uv=value
            obj=bpy.data.objects.new(key,mesh);bpy.context.collection.objects.link(obj);mesh.materials.append(d['mat'])
            obj['authoring']='Original procedural urban kit';obj['license']='CC0-1.0'

def palette():
    return dict(stone=material('UrbanStone',(.5,.49,.46),texture='granite'), glass=material('UrbanGlazing',(.25,.37,.41),texture='glass'),
                glass2=material('UrbanGlazingWarm',(.32,.38,.37),.36,.24), trim=material('UrbanAnodizedMetal',(.32,.33,.31),.44,.72),
                dark=material('UrbanRecess',(.075,.085,.083),.94), pale=material('UrbanPaleConcrete',(.59,.60,.57),.84), green=material('UrbanPlanting',(.20,.28,.18),.94))

def tower(name,width,depth,floors,style):
    reset();m=palette();b=Builder();lobby=5.2;height=lobby+floors*3.6+.9
    # Grounded envelope, recesses and entry are all inside the original collision footprint.
    b.box('Podium',(0,0,2.5),(width,depth,5),m['stone'])
    bw=width-(2.0 if style=='a' else 1.0);bd=depth-1.2
    b.box('Core',(0,.3,(height+lobby)/2),(bw,bd,height-lobby),m['dark'])
    for k in range(floors):
        z=lobby+k*3.6
        # One structural spandrel and smaller glazing modules per real office floor.
        b.box('FloorSpandrel',(0,.3,z+.36),(bw+.16,bd+.16,.72),m['trim'] if style!='c' else m['stone'])
        for side, length, plane in [(0,bw,-bd/2+.3-.015),(2,bw,bd/2+.3+.015),(1,bd,bw/2+.015),(3,bd,-bw/2-.015)]:
            count=max(3,round(length/1.5));pitch=length/count
            for col in range(count):
                u=-length/2+pitch*(col+.5)
                p=(u,plane,z+1.97) if side in (0,2) else (plane,u+.3,z+1.97)
                use=m['glass2'] if (col+k*7)%13 in (0,1) else m['glass']
                b.quad('GlazingModule',p,pitch-.085,2.36,use,side)
                # Actual mullion depth reads without shadows; dark edges are baked in panel maps.
                if side in (0,2): b.box('Mullion',(u-pitch/2,plane,z+1.95),(.075,.10,2.56),m['trim'])
                else: b.box('Mullion',(plane,u-pitch/2+.3,z+1.95),(.10,.075,2.56),m['trim'])
        if style=='b':
            for x in [-bw/2+.3,bw/2-.3]: b.box('StoneFin',(x,-bd/2+.20,z+1.8),(.55,.48,3.6),m['stone'])
    b.box('RoofParapet',(0,.3,height-.35),(bw+.16,bd+.16,.7),m['pale'])
    b.box('RoofServiceScreen',(0,.5,height-.13),(bw*.56,bd*.60,.20),m['dark'])
    # Full-scale 3.1 m lobby doors, deep lintel, service grilles and enclosed columns.
    entry_y=-depth/2-.011
    b.quad('DoorRecess',(0,entry_y,1.80),5.8,3.6,m['dark'])
    for x in [-1.3,1.3]:
        b.quad('DoorGlass',(x,entry_y-.012,1.60),2.32,3.0,m['glass'])
        b.box('DoorStile',(x-1.20,entry_y-.028,1.60),(.075,.075,3.1),m['trim'])
        b.box('DoorHandle',(x+.65,entry_y-.07,1.20),(.035,.055,.62),m['pale'])
    b.box('DoorHead',(0,entry_y-.020,3.23),(5.65,.08,.12),m['trim'])
    b.box('Canopy',(0,-depth/2+.9,3.72),(8.0,1.8,.30),m['pale'])
    for x in [-3.7,3.7]: b.box('EntryColumn',(x,-depth/2+.3,1.85),(.30,.38,3.7),m['stone'])
    for side in [-1,1]:
        for i in range(8): b.box('ServiceGrille',(side*(width/2-.20),-depth/2-.012,.7+i*.18),(.27,.04,.045),m['dark'])
        b.quad('LobbySideGlazing',(side*(width/2-2),entry_y,2.08),2.40,2.78,m['glass'])
    b.finish();export(name,{'nominal_dimensions_m':[width,depth,height],'floor_height_m':3.6,'office_floors':floors,'door_height_m':3.1,'opaque_glazing':True})

def sidewalk():
    reset();m=palette();m['pavers']=material('UrbanPavers',(.55,.54,.49),texture='pavers');b=Builder()
    b.box('PavedSlab',(0,0,.015),(3.2,8,.03),m['pavers'])
    b.box('FlushKerb',(-1.5,0,.05),(.2,8,.1),m['stone'])
    # Drainage bars, tactile guidance and scored kerb joints at walking scale.
    for y in np.arange(-3.8,4,.5): b.box('KerbJoint',(-1.51,float(y),.104),(.19,.012,.003),m['dark'])
    for y in np.arange(-3.8,4,.12): b.box('TactileRib',(1.20,float(y),.042),(.34,.026,.010),m['pale'])
    for y in np.arange(-.5,.51,.07): b.box('DrainSlot',(-1.25,float(y),.033),(.19,.018,.004),m['dark'])
    b.finish();export('urban_sidewalk',{'nominal_dimensions_m':[3.2,8,.105],'collisions':False,'role':'flush visual pavement kit'})

def shopfront():
    reset();m=palette();b=Builder();w=16;d=14;h=8.0
    b.box('StoreCore',(0,0,h/2),(w,d,h),m['stone'])
    y=-d/2-.012
    for floor in range(2):
        z=2+floor*3.6
        for x in [-6,-3,0,3,6]:
            b.quad('StoreGlazing',(x,y,z),2.60,2.8,m['glass'])
            b.box('StoreMullion',(x-1.35,y-.02,z),(.10,.08,2.96),m['trim'])
    for x in [-5.0,5.0]:
        b.box('StoreCanopy',(x,-6.45,3.45),(5.3,1.1,.17),m['trim'])
        b.box('BlankStoreSign',(x,y-.04,3.93),(5.2,.08,.55),m['dark'])
        b.box('DoorHandle',(x+.55,y-.055,1.22),(.04,.065,.7),m['pale'])
    for x in [-7.6,7.6]: b.box('EdgePilaster',(x,-6.7,4),(.45,.60,8),m['pale'])
    b.box('RoofCoping',(0,0,7.92),(16,14,.16),m['pale']);b.finish()
    export('urban_shopfront',{'nominal_dimensions_m':[16,14,8],'floor_height_m':3.6,'door_height_m':3.1,'role':'low-rise mixed-use frontage, no brand'})

def bench():
    reset();m=palette();b=Builder()
    for y in [-.17,0,.17]: b.box('BenchSlat',(0,y,.46),(1.8,.14,.055),m['trim'])
    for z in [.72,.87]: b.box('BackrestSlat',(0,.26,z),(1.8,.045,.12),m['trim'])
    for x in [-.70,.70]:
        b.box('BenchSupport',(x,0,.22),(.08,.44,.44),m['dark'])
        b.box('BackSupport',(x,.25,.65),(.05,.07,.57),m['dark'])
    b.finish();export('urban_bench',{'nominal_dimensions_m':[1.8,.5,.93],'seat_height_m':.46,'collisions':False})

def export(name,metadata):
    bpy.context.view_layer.update();objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    # Keep editable construction meshes by material; no generated cache is a source.
    for o in objects: o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_extras=True,export_animations=False,export_cameras=False,export_lights=False)
    for im in bpy.data.images:
        if im.filepath: im.filepath=bpy.path.relpath(im.filepath,start=str(SOURCE))
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'.blend')))
    triangles=0;coords=[]
    for o in objects:
        o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles);coords.extend(o.matrix_world@v.co for v in o.data.vertices)
    lo=[min(v[i] for v in coords) for i in range(3)];hi=[max(v[i] for v in coords) for i in range(3)]
    p=OUT/(name+'.glb');entry={'name':name,'path':p.relative_to(ROOT).as_posix(),'source':(SOURCE/(name+'.blend')).relative_to(ROOT).as_posix(),'license':'CC0-1.0','triangles':triangles,'materials':len(objects),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bounds_blender_min':lo,'bounds_blender_max':hi,**metadata}
    assert triangles<20000 and len(objects)<=8
    MANIFEST.append(entry);print('URBAN_DONE',name,triangles,p.stat().st_size,flush=True)
    render(name,objects,lo,hi)

def render(name,objects,lo,hi):
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
    scene.render.resolution_x=960;scene.render.resolution_y=720;scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new('UrbanPreviewSky');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.62,.70,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.55
    bpy.ops.mesh.primitive_plane_add(size=500,location=(0,0,-.04));ground=bpy.context.object;ground.name='QA_ground';ground.data.materials.append(material('PreviewGround',(.45,.46,.43),.95))
    target=Vector(((lo[0]+hi[0])/2,(lo[1]+hi[1])/2,(hi[2]-lo[2])*.43));span=max(hi[i]-lo[i] for i in range(3))
    bpy.ops.object.camera_add(location=target+Vector((span*.86,-span*1.3,span*.38)));cam=bpy.context.object;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=span*1.6;scene.camera=cam
    bpy.ops.object.light_add(type='SUN',location=(0,0,100));sun=bpy.context.object;sun.rotation_euler=(math.radians(32),math.radians(-18),math.radians(-25));sun.data.energy=2.3
    scene.render.filepath=str(QA/(name+'_preview.png'));bpy.ops.render.render(write_still=True)

def main():
    reset();textures()
    tower('urban_tower_a',18,19,10,'a');tower('urban_tower_b',18,19,9,'b');tower('urban_tower_c',24,19,4,'c')
    sidewalk();shopfront();bench()
    total=sum(e['bytes'] for e in MANIFEST)+sum(p.stat().st_size for p in TEX.glob('*.png'))
    assert total<8*1024*1024,(total,'urban Web budget')
    (QA/'urban-manifest.json').write_text(json.dumps({'schema_version':1,'generator':'tools/blender/build_urban_assets.py','license':'CC0-1.0','assets':MANIFEST,'texture_max':256,'total_source_web_bytes':total,'note':'Nominal geometry is metric. Current Alpha building envelopes rescale templates; this is not a surveyed Taichung GIS map.'},indent=2),encoding='utf-8')
    render_street()
    print('URBAN_BUILD_PASS total_bytes='+str(total),flush=True)

def render_street():
    """Authored art review composition, explicitly not a game or GIS screenshot."""
    reset()
    def append(name,p=(0,0,0),yaw=0):
        path=SOURCE/(name+'.blend')
        with bpy.data.libraries.load(str(path),link=False) as (src,dst): dst.objects=[n for n in src.objects if not n.startswith('QA_')]
        for o in dst.objects:
            if o and o.type=='MESH':
                bpy.context.collection.objects.link(o)
                o.location=Vector(p);o.rotation_euler.z=yaw
    append('urban_tower_a',(-27,11,0));append('urban_tower_b',(0,17,0));append('urban_tower_c',(28,11,0))
    for x in range(-44,45,8): append('urban_sidewalk',(x,-8,.01),math.pi*.5)
    append('urban_bench',(-7,-8,.01));append('urban_bench',(7,-8,.01))
    m=palette();m['asphalt']=material('ReviewAsphalt',(.17,.18,.17),texture='asphalt');m['pavers']=material('ReviewPavers',(.55,.54,.49),texture='pavers')
    b=Builder();b.box('Road',(0,-16,-.04),(100,12,.08),m['asphalt']);b.box('Court',(0,10,-.04),(100,40,.08),m['pavers'])
    for x in [-50,50]: b.box('CentreLine',(x/2,-17,.007),(49,.08,.007),m['pale'])
    for x in range(-42,44,5): b.box('LaneMark',(x,-14,.007),(2.2,.06,.008),m['pale'])
    for y in np.arange(-21.5,-10.5,.7): b.box('Crosswalk',(-11,float(y),.009),(3.2,.38,.007),m['pale'])
    b.finish()
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
    scene.render.resolution_x=1280;scene.render.resolution_y=800;scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new('StreetPreviewSky');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.71,.76,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.75
    bpy.ops.object.camera_add(location=(-16,-35,1.75));cam=bpy.context.object;target=Vector((0,13,13));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=24;scene.camera=cam
    bpy.ops.object.light_add(type='SUN',location=(0,0,80));sun=bpy.context.object;sun.rotation_euler=(math.radians(33),math.radians(-16),math.radians(-30));sun.data.energy=2
    for im in bpy.data.images:
        if im.filepath: im.filepath=bpy.path.relpath(bpy.path.abspath(im.filepath),start=str(SOURCE))
    scene['review_only']='Original Blender street art composition, not an actual gameplay screenshot or measured Taichung location'
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'urban_street_review.blend'))
    scene.render.filepath=str(QA/'urban_street_review.png');bpy.ops.render.render(write_still=True)

if __name__=='__main__': main()
