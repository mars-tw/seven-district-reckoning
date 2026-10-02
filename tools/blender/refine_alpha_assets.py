"""Rebuild the improved subset, leaving other imported alpha assets intact."""
import importlib.util,json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('alpha',root/'tools/blender/build_alpha_assets.py');a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
a.REPORT[:]=json.loads((root/'qa/art/asset-manifest.json').read_text(encoding='utf-8'))
for name,file,height in [('office_tower_a','building-skyscraper-a',38),('office_tower_b','building-skyscraper-b',46),('office_tower_c','building-skyscraper-c',33)]:a.static_source(name,'city-kit-commercial',file,height)
a.static_source('tree','nature-kit','tree_oak',5.0)
a.static_source('server','furniture-kit','bookcaseClosed',2.0)
a.static_source('glass','furniture-kit','wallWindow',2.6)
a.bicycle()
a.character('hero','character-male-a',a.PAL)
p=a.PAL.copy();p[0]=(.055,.48,.35,1);p[2]=(.93,.62,.08,1);p[3]=(.68,.37,.20,1);p[4]=(.14,.030,.008,1);a.character('guard','character-male-e',p)
p=a.PAL.copy();p[0]=(.69,.075,.25,1);p[1]=(.10,.25,.46,1);p[2]=(.15,.65,.49,1);p[3]=(.80,.49,.29,1);p[4]=(.31,.12,.045,1);a.character('civilian','character-female-b',p)
(root/'qa/art/blender-run.json').write_text(json.dumps({'blender_version':a.bpy.app.version_string,'method':'Blender CLI background; MCP unavailable','assets':len(a.REPORT),'user_prompt':'開始製作 並推上開源'},ensure_ascii=False,indent=2),encoding='utf-8')

