"""Read back editable character sources and render identity sheets on CPU."""
import bpy,json,hashlib,struct,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/art/character-sheets/r10'
OUT.mkdir(parents=True,exist_ok=True)
data=json.loads((ROOT/'assets/art/r10/models.json').read_text());checks={};sheets=[]
for row in data['outputs']:
 p=ROOT/row['path'];blob=p.read_bytes();gltf=json.loads(blob[20:20+struct.unpack_from('<I',blob,12)[0]])
 checks[row['id']+'_hash']=hashlib.sha256(blob).hexdigest()==row['sha256']
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/row['source']))
 checks[row['id']+'_source_hash']=hashlib.sha256((ROOT/row['source']).read_bytes()).hexdigest()==row['source_sha256']
 checks[row['id']+'_relative_images']=all(not im.filepath or im.filepath.startswith('//') for im in bpy.data.images)
 checks[row['id']+'_embedded_glb']=all('uri' not in x for x in gltf.get('images',[]))
 if row['id']!='hero_human':continue
 checks[row['id']+'_eight_real_clips']=len(gltf['animations'])==8 and all(len(a['channels'])>10 for a in gltf['animations'])
 checks[row['id']+'_skin_present']=len(gltf['skins'][0]['joints'])>30
 rig=bpy.data.objects['HumanSkeleton'];idle=next(t.strips[0].action for t in rig.animation_data.nla_tracks if t.name=='idle')
 for track in rig.animation_data.nla_tracks:track.mute=True
 rig.animation_data.action=idle;bpy.context.scene.frame_set(0)
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=8
 scene.render.threads_mode='FIXED';scene.render.threads=2
 scene.render.resolution_x=320;scene.render.resolution_y=480;scene.render.resolution_percentage=100
 scene.render.film_transparent=False;scene.render.image_settings.file_format='PNG'
 scene.world=bpy.data.worlds.new('R10_QA_World');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.42,.37,.28,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
 for loc,energy in [((-3,-4,5),450),((3,2,4),260)]:
  bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=energy;o.data.size=4;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
 bpy.ops.object.camera_add();cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=2.05;scene.camera=cam
 for label,loc in [('front',(0,-5,.95)),('side',(5,0,.95)),('back',(0,5,.95))]:
  cam.location=loc;cam.rotation_euler=(Vector((0,0,.95))-cam.location).to_track_quat('-Z','Y').to_euler();file=OUT/f"{row['id']}-{label}.png";scene.render.filepath=str(file);bpy.ops.render.render(write_still=True);sheets.append(file.relative_to(ROOT).as_posix())
report=dict(status='VERIFIED' if all(checks.values()) else 'BLOCKED',checks=checks,sheets=sheets,method='Background Blender 5.2, CPU Cycles 8 samples, actual saved skinned sources with original idle clip. Studio QA only, never store screenshots.')
(ROOT/'docs/evidence/r10-art/model-validation.json').write_text(json.dumps(report,indent=2)+'\n');assert all(checks.values()),checks
print('R10_MODELS_VERIFIED '+json.dumps(checks))
