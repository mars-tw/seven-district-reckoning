"""Read-only Blender source and GLB checks; no visible window or renderer."""
import bpy,json,struct,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
models=json.loads((ROOT/'assets/art/r7/models.json').read_text())
checks=[];rows=[]
def check(label,condition):
    checks.append(dict(check=label,pass_result=bool(condition)))
    if not condition:raise AssertionError(label)
for row in models['outputs']:
    source=ROOT/row['source'];p=ROOT/row['path'];b=p.read_bytes()
    data=json.loads(b[20:20+struct.unpack_from('<I',b,12)[0]])
    check(row['id']+'/sha256',hashlib.sha256(b).hexdigest()==row['sha256'])
    check(row['id']+'/GLB2',b[:4]==b'glTF' and struct.unpack_from('<I',b,4)[0]==2)
    bpy.ops.wm.open_mainfile(filepath=str(source))
    check(row['id']+'/source_mesh',any(o.type=='MESH' for o in bpy.context.scene.objects))
    check(row['id']+'/relative_images',all(not im.filepath or im.filepath.startswith('//') for im in bpy.data.images))
    if row['id']=='ayuan-tailored':
        rig=bpy.data.objects['HumanSkeleton']
        check('courier/53_anatomical_bones',len(rig.data.bones)==53)
        names=[a['name'].rsplit('/',1)[-1] for a in data.get('animations',[])]
        check('courier/eight_real_clips',all(n in names for n in ['idle','walk','run','attack','hit','drive','pedal','knockdown']))
        check('courier/sewn_bag_geometry',all(any(n in o.name for o in bpy.data.objects) for n in ['SewnBagGusset','SewnFoldedFlap','BagBuckle']))
        check('courier/bag_bound_to_pelvis',all('pelvis' in o.vertex_groups for o in bpy.data.objects if o.name.startswith('Sewn')))
    else:
        check('workbench/batched',len(data['meshes'])==1 and len(data['meshes'][0]['primitives'])<=8)
    rows.append(dict(id=row['id'],source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),meshes=len(data['meshes']),primitives=sum(len(m['primitives']) for m in data['meshes']),clips=[a.get('name') for a in data.get('animations',[])],triangles=row['triangles']))
report=dict(status='VERIFIED',checks=checks,models=rows,blender=bpy.app.version_string)
(ROOT/'docs/evidence/r7-art/model-validation.json').write_text(json.dumps(report,indent=2)+'\n')
print('R7_MODEL_VALIDATION '+json.dumps(report))
