"""Remove host-specific source/render paths from the delivered Blender files."""
import bpy,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BLEND=ROOT/'assets/source/blender';out=[]
for p in sorted(BLEND.glob('alpha_*.blend')):
 bpy.ops.wm.open_mainfile(filepath=str(p));changes=0
 for im in bpy.data.images:
  if not im.filepath:continue
  q=Path(bpy.path.abspath(im.filepath))
  if q.is_relative_to(ROOT):
   im.filepath=bpy.path.relpath(str(q),start=str(BLEND));changes+=1
 for o in bpy.data.objects:
  for key in list(o.keys()):
   v=o[key]
   if isinstance(v,str):
    if key=='source_mesh':o[key]=v.replace('\\','/')
    elif str(ROOT).lower() in v.lower() or ROOT.as_posix().lower() in v.lower():o[key]=v.replace(str(ROOT),'[workspace]').replace(ROOT.as_posix(),'[workspace]');changes+=1
 bpy.context.scene.render.filepath=bpy.path.relpath(str(ROOT/'qa/art'/(p.stem.replace('alpha_','')+'_preview.png')),start=str(BLEND))
 bpy.ops.wm.save_as_mainfile(filepath=str(p));out.append({'file':p.relative_to(ROOT).as_posix(),'path_changes':changes})
(ROOT/'qa/art/portable-blend-check.json').write_text(json.dumps(out,indent=2),encoding='utf-8')
