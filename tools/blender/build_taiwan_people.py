"""Eight CC0 MakeHuman derivatives with original clothes, proportions and rig clips."""
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location("human_base", Path(__file__).with_name("build_human_characters.py"))
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
base.BLEND = base.ROOT / "assets/source/blender/taiwan/people"
base.QA = base.ROOT / "qa/art/taiwan/people"
base.BLEND.mkdir(parents=True, exist_ok=True)
base.QA.mkdir(parents=True, exist_ok=True)

variants = {
    "LIN": ("civilian_human", 1.61, (.44,.22,.14), (.73,.64,.48), 1.04, True),
    "YA": ("mei_human", 1.66, (.14,.25,.31), (.70,.54,.30), .97, True),
    "TING": ("hero_human", 1.81, (.08,.30,.28), (.78,.70,.54), 1.02, False),
    "AN": ("yuan_human", 1.73, (.36,.40,.45), (.78,.80,.67), .98, False),
    "JUAN": ("civilian_human", 1.64, (.23,.33,.19), (.60,.55,.33), 1.02, True),
    "WEI": ("zhou_human", 1.70, (.23,.28,.30), (.45,.31,.22), 1.05, False),
    "CHUN": ("yuan_human", 1.76, (.36,.28,.20), (.83,.74,.47), 1.03, True),
    "YUN": ("mei_human", 1.68, (.33,.21,.32), (.67,.62,.55), 1.01, True),
}
original_morph = base.morph_vertices
original_accessories = base.accessories


def morph(cfg):
    verts, scale = original_morph(cfg)
    h = cfg["height"]
    for v in verts:
        amount = max(0, min(1, (v.z/h-.865)/.07))
        v.x *= 1 + (cfg["head_width"]-1)*amount
    return verts, scale


def accessories(cfg, verts, rig, mats):
    original_accessories(cfg, verts, rig, mats)
    if not cfg["apron"]:
        return
    h = cfg["height"]
    apron = base.mesh_object("SewnWorkApron", [
        (-.10,-.181,h*.80),(.10,-.181,h*.80),
        (-.185,-.237,h*.67),(.185,-.237,h*.67),
        (-.19,-.225,h*.43),(.19,-.225,h*.43),
    ], [(0,1,3,2),(2,3,5,4)])
    base.material_all(apron, mats[5])
    low = apron.vertex_groups.new(name="pelvis")
    high = apron.vertex_groups.new(name="spine_03")
    for v in apron.data.vertices:
        w = max(0,min(1,(v.co.z/h-.56)/.18))
        low.add([v.index],1-w,"REPLACE")
        high.add([v.index],w,"REPLACE")
    modifier = apron.modifiers.new("HumanSkin","ARMATURE")
    modifier.object = rig
    apron.parent = rig
    for side in [-1,1]:
        base.ribbon("ApronNeckStrap",[(side*.09,-.183,h*.79),(side*.055,-.12,h*.85),(side*.06,.07,h*.835)],.02,mats[5],rig,"spine_03")
    base.ribbon("ApronPocketSeam",[(-.08,-.244,h*.65),(-.08,-.241,h*.60),(.08,-.241,h*.60),(.08,-.244,h*.65)],.004,mats[1],rig,"pelvis")


base.morph_vertices = morph
base.accessories = accessories
rows = []
life_path = base.ROOT / "godot/data/taiwan_life.json"
life = json.loads(life_path.read_text(encoding="utf-8"))
for npc in life["characters"]:
    template,height,top,accent,width,apron = variants[npc["id"]]
    config = {**base.VARIANTS[template], "height":height, "top":top, "accent":accent, "head_width":width, "apron":apron, "label":npc["name"]+"｜"+npc["role"]+"｜原創工作服"}
    name = "tw_person_"+npc["id"].lower()
    row = base.build_character(name,config,render=False)
    row["blend"] = "assets/source/blender/taiwan/people/"+name+".blend"
    row["npc_id"] = npc["id"]
    row["apron"] = apron
    row["head_width"] = width
    rows.append(row)
    npc["appearance_key"] = name
    # Material colours are authored per role; avoid retinting every fabric surface.
    npc["appearance_variant"] = ""
manifest = {"schema_version":1,"generator":"tools/blender/build_taiwan_people.py","license":"CC0-1.0","source":"MakeHuman Community MPFB CC0 hm08; upstream attribution retained in assets/source/makehuman","characters":rows}
(base.ROOT / "godot/data/taiwan_people_manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
life_path.write_text(json.dumps(life,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("TAIWAN_PEOPLE_BUILD_PASS",len(rows),flush=True)
