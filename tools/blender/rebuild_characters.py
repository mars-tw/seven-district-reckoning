import importlib.util,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('alpha',ROOT/'tools/blender/build_alpha_assets.py');a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
a.REPORT[:]=json.loads((ROOT/'qa/art/asset-manifest.json').read_text(encoding='utf-8'))
a.character('hero','character-male-a',a.PAL)
p=a.PAL.copy();p[0]=(.055,.48,.35,1);p[2]=(.93,.62,.08,1);p[3]=(.68,.37,.20,1);p[4]=(.14,.030,.008,1);a.character('guard','character-male-e',p)
p=a.PAL.copy();p[0]=(.69,.075,.25,1);p[1]=(.10,.25,.46,1);p[2]=(.15,.65,.49,1);p[3]=(.80,.49,.29,1);p[4]=(.31,.12,.045,1);a.character('civilian','character-female-b',p)
