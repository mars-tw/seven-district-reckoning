"""Original CC0 metric cargo; run with Blender --background --python this file."""
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location("taiwan_kit", Path(__file__).with_name("build_taiwan_assets.py"))
kit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kit)


def cargo(name, kind):
    kit.reset()
    m = {
        "paper": kit.mat("CorrugatedKraft", (.48, .31, .15), .95),
        "tape": kit.mat("PackingTape", (.77, .64, .39), .42),
        "label": kit.mat("BlankShippingLabel", (.93, .91, .82), .88),
        "fabric": kit.mat("InsulatedFabric", (.06, .32, .30), .92),
        "strap": kit.mat("WovenBlackStrap", (.035, .045, .045), .98),
        "seam": kit.mat("ReflectivePiping", (.66, .71, .60), .50),
    }
    b = kit.MeshBuilder()
    if kind == "parcel":
        b.box((0, 0, .17), (.42, .30, .34), m["paper"])
        b.box((0, 0, .341), (.065, .302, .004), m["tape"])
        b.box((0, -.151, .17), (.065, .004, .34), m["tape"])
        b.box((.115, -.154, .21), (.13, .004, .085), m["label"])
        for x in [-.015, 0, .015]:
            b.box((x+.115, -.157, .21), (.004, .002, .047), m["strap"])
    elif kind == "food":
        b.box((0, 0, .23), (.44, .32, .46), m["fabric"])
        b.box((0, 0, .475), (.46, .34, .035), m["fabric"])
        b.box((0, -.164, .34), (.31, .012, .11), m["seam"])
        for x in [-.2, .2]:
            b.beam((x, -.166, .025), (x, -.166, .448), .009, m["seam"])
        for x in [-.15, .15]:
            b.beam((x, .17, .41), (x, .24, .32), .038, m["strap"])
            b.beam((x, .24, .32), (x, .24, .10), .038, m["strap"])
            b.beam((x, .24, .10), (x, .17, .07), .038, m["strap"])
        b.beam((-.09, 0, .495), (-.09, 0, .55), .025, m["strap"])
        b.beam((-.09, 0, .55), (.09, 0, .55), .025, m["strap"])
        b.beam((.09, 0, .55), (.09, 0, .495), .025, m["strap"])
    else:
        b.box((0, 0, .21), (.32, .19, .42), m["paper"])
        # An open mouth and two independent loop handles distinguish a bag.
        b.box((0, 0, .423), (.29, .16, .006), m["strap"])
        for y in [-.08, .08]:
            b.beam((-.08, y, .425), (-.08, y, .53), .012, m["tape"])
            b.beam((-.08, y, .53), (.08, y, .53), .012, m["tape"])
            b.beam((.08, y, .53), (.08, y, .425), .012, m["tape"])
        b.box((0, -.098, .24), (.16, .004, .10), m["label"])
    b.finish()
    kit.export(name, {"traits": ["metric_carry_prop", kind, "original_unbranded"], "collision_boxes": [], "role": "Player carried " + kind})


for asset, kind in [("tw_carry_parcel", "parcel"), ("tw_carry_food", "food"), ("tw_carry_shop", "convenience")]:
    cargo(asset, kind)
document = {"schema_version": 1, "generator": "tools/blender/build_carry_assets.py", "license": "CC0-1.0", "assets": kit.MANIFEST}
(kit.ROOT / "godot/data/carry_asset_manifest.json").write_text(json.dumps(document, indent=2), encoding="utf-8")
print("CARRY_BUILD_PASS", len(kit.MANIFEST), flush=True)
