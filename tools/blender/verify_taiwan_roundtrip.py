"""Reopen every editable source and independently import its GLB in Blender."""
import bpy, json, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
QA=ROOT/'qa/art/taiwan'
manifest=json.loads((QA/'taiwan-manifest.json').read_text(encoding='utf-8'))
checks=[]
def check(ok,label):checks.append({'pass':bool(ok),'label':label})
def measure():
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH'];coords=[];triangles=0
    bpy.context.view_layer.update()
    for o in objects:
        o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles);coords.extend(o.matrix_world@v.co for v in o.data.vertices)
    return triangles,[min(v[i] for v in coords) for i in range(3)],[max(v[i] for v in coords) for i in range(3)],objects
for asset in manifest['assets']:
    name=asset['name'];bpy.ops.wm.open_mainfile(filepath=str(ROOT/asset['source']))
    triangles,lo,hi,objects=measure()
    check(triangles==asset['triangles'],name+': editable source triangle count')
    check(all(abs(lo[i]-asset['bounds_blender_min'][i])<.0001 and abs(hi[i]-asset['bounds_blender_max'][i])<.0001 for i in range(3)),name+': editable source metric envelope')
    check(all(im.filepath.startswith('//') and Path(bpy.path.abspath(im.filepath)).is_file() for im in bpy.data.images if im.filepath),name+': portable source texture paths resolve')
    check(all(len(o.data.uv_layers)>0 for o in objects),name+': source UV editing retained')
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(ROOT/asset['path']))
    triangles,lo,hi,objects=measure()
    check(triangles==asset['triangles'],name+': independent GLB reimport triangle count')
    check(all(abs(lo[i]-asset['bounds_blender_min'][i])<.001 and abs(hi[i]-asset['bounds_blender_max'][i])<.001 for i in range(3)),name+': GLB reimport metric envelope matches source')
    check(all(len(o.data.uv_layers)>0 for o in objects),name+': reimported UVs retained')
    print('TAIWAN_ROUNDTRIP',name,'PASS' if all(c['pass'] for c in checks) else 'FAIL',flush=True)
report={'status':'VERIFIED' if all(c['pass'] for c in checks) else 'FAILED','passed':sum(c['pass'] for c in checks),'failed':sum(not c['pass'] for c in checks),'checks':checks}
(QA/'taiwan-roundtrip.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('TAIWAN_ROUNDTRIP_RESULT',report['status'],report['passed'],report['failed'],flush=True)
if report['failed']:raise SystemExit(1)
