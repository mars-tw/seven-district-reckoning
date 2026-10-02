import bpy,json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
out={'blender_version':bpy.app.version_string,'initial_scene':[(o.name,o.type) for o in bpy.data.objects]}
for pack in ['mini-characters','car-kit','city-kit-commercial']:
    files=list((root/'assets/source/kenney'/pack).rglob('*.glb'))
    out[pack]=[str(f.relative_to(root)) for f in files]
f=next((root/'assets/source/kenney/mini-characters').rglob('character-male-a.glb'))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(f))
out['character_detail']={'objects':[(o.name,o.type,list(o.dimensions),list(o.location)) for o in bpy.data.objects], 'bones':[(b.name,list(b.head_local),list(b.tail_local)) for o in bpy.data.objects if o.type=='ARMATURE' for b in o.data.bones],'actions':[(a.name,list(a.frame_range)) for a in bpy.data.actions], 'materials':[m.name for m in bpy.data.materials]}
(root/'qa/art/source-inspection.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(out['character_detail'],ensure_ascii=False))

