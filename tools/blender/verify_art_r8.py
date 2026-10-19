"""Read back both editable Blender source and exported GLB, no renderer window."""
import bpy,json,hashlib,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
row=json.loads((ROOT/'assets/art/r8/models.json').read_text())
source=ROOT/row['source'];p=ROOT/row['path'];blob=p.read_bytes()
data=json.loads(blob[20:20+struct.unpack_from('<I',blob,12)[0]])
bpy.ops.wm.open_mainfile(filepath=str(source))
checks={
    'export_hash_matches':hashlib.sha256(blob).hexdigest()==row['sha256'],
    'glb2':blob[:4]==b'glTF' and struct.unpack_from('<I',blob,4)[0]==2,
    'five_material_batches':len(data['materials'])==5 and sum(len(m['primitives']) for m in data['meshes'])==5,
    'no_external_texture_dependencies':all('uri' not in x or not x['uri'].startswith(('C:', 'file:')) for x in data.get('images',[])),
    'source_geometry_present':len([o for o in bpy.context.scene.objects if o.type=='MESH'])==5,
    'source_has_curved_surfaces':any(len(o.data.polygons)>500 for o in bpy.context.scene.objects if o.type=='MESH'),
    'source_under_10000_triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')==row['triangles']<10000,
    'relative_image_paths':all(not im.filepath or im.filepath.startswith('//') for im in bpy.data.images),
}
report=dict(status='VERIFIED' if all(checks.values()) else 'BLOCKED',checks=checks,blender=bpy.app.version_string,source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),glb_sha256=hashlib.sha256(blob).hexdigest(),triangles=row['triangles'])
(ROOT/'docs/evidence/r8-art/model-validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report));assert all(checks.values())
