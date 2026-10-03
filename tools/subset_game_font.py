"""Build an OFL font subset from actual game text, preserving attribution."""
from pathlib import Path
from fontTools import subset

root = Path(__file__).resolve().parents[1]
font_dir = root / "godot/assets/fonts"
source = font_dir / "NotoSansTC-Regular.otf"
output = font_dir / "SevenDistrictSansTC-Regular.otf"
text = "".join(chr(i) for i in range(32, 127)) + "←↑→↓⏸▶⛶✓／｜，。！？：；（）「」『』…％／★☆●○"
for pattern in ["*.gd", "*.json"]:
    for path in (root / "godot").rglob(pattern):
        text += path.read_text(encoding="utf-8")
options = subset.Options()
options.name_IDs = [0, 1, 2, 3, 4, 5, 6, 13, 14]
options.name_legacy = True
options.name_languages = [0x409]
font = subset.load_font(str(source), options)
processor = subset.Subsetter(options=options)
processor.populate(text=text)
processor.subset(font)
for record in font["name"].names:
    if record.nameID in {1, 3, 4, 6}:
        new_name = "SevenDistrictSansTC-Regular" if record.nameID == 6 else "Seven District Sans TC"
        record.string = new_name.encode(record.getEncoding(), errors="replace")
subset.save_font(font, str(output), options)
for path in (root / "godot/scripts").rglob("*.gd"):
    old = path.read_text(encoding="utf-8")
    new = old.replace("NotoSansTC-Regular.otf", "SevenDistrictSansTC-Regular.otf")
    if new != old:
        path.write_text(new, encoding="utf-8")
print("Game font subset bytes:", output.stat().st_size, "from", source.stat().st_size)
