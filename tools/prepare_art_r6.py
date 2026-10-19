"""Retain original generated sources and derive R6 game art with audited alpha."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SIZES = {'ayuan-portrait': (512, 768), 'meiqing-portrait': (512, 768),
         'title-street': (1536, 1024), 'receipt-paper': (512, 768)}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sources-json', type=Path, required=True)
    args = parser.parse_args()
    sources = json.loads(args.sources_json.read_text())
    master = ROOT / 'assets/art/r6'
    runtime = ROOT / 'godot/assets/art/r6'
    master.mkdir(parents=True, exist_ok=True)
    runtime.mkdir(parents=True, exist_ok=True)
    records = []
    for name, size in SIZES.items():
        source = Path(sources[name])
        cutout = 'portrait' in name
        original = Image.open(source).convert('RGBA' if cutout else 'RGB')
        retained = master / (name+'.webp')
        original.save(retained, lossless=True, method=6)
        # Keep the lossless whole source; crop only the runtime receipt's desk
        # surround so dark UI text is always over the actual light paper.
        visual = original.crop((100,150,900,1400)) if name == 'receipt-paper' else original
        im = visual.resize(size, Image.Resampling.LANCZOS)
        record = dict(id=name, generated_png_sha256=sha(source), master=retained.relative_to(ROOT).as_posix(),
                      master_sha256=sha(retained), size=list(size))
        reference = ROOT / ('godot/assets/art/r4/'+name+'.png' if cutout else 'godot/assets/art/r5/title-street.webp')
        if name != 'receipt-paper':
            record.update(reference=reference.relative_to(ROOT).as_posix(), reference_sha256=sha(reference))
        else:
            record['source_crop_pixels'] = [100,150,900,1400]
        out = runtime / (name+('.png' if cutout else '.webp'))
        if cutout:
            pixels = np.array(im)
            pixels[pixels[:, :, 3] == 0, :3] = 0
            im = Image.fromarray(pixels)
            im.save(out, optimize=True)
            mask = master / (name+'-mask.png')
            im.getchannel('A').save(mask)
            rgb = pixels[:, :, :3][pixels[:, :, 3] > 128]/255.0
            v = rgb.max(axis=1)
            sat = (v-rgb.min(axis=1))/np.maximum(v, 1e-5)
            record['character_gate'] = dict(value_mean=float(v.mean()), near_black=float((v < 0.15).mean()),
                                            saturation_mean=float(sat.mean()), low_saturation=float((sat < 0.15).mean()))
            g = record['character_gate']
            g['pass'] = .30 <= g['value_mean'] <= .75 and g['near_black'] < .35 and g['saturation_mean'] >= .32 and g['low_saturation'] < .20
            record['alpha'] = dict(corners=[int(pixels[y, x, 3]) for x,y in [(0,0),(-1,0),(0,-1),(-1,-1)]],
                                   occupancy=float((pixels[:, :, 3] > 0).mean()), mask=mask.relative_to(ROOT).as_posix(), mask_sha256=sha(mask), transparent_rgb_zero=True)
            assert record['alpha']['corners'] == [0]*4
            assert g['pass'], (name,g)
        else:
            im.save(out, quality=85, method=6)
        record.update(path=out.relative_to(ROOT).as_posix(), sha256=sha(out), bytes=out.stat().st_size,
                      decoded_rgba_bytes=size[0]*size[1]*4)
        records.append(record)
    report = dict(status='VERIFIED', version='0.10.0', tool='image_gen.imagegen', model_slug=None,
                  model_note='Actual model slug is not exposed. No model name inferred from planning files.',
                  generated_master_count=4, runtime_image_count=4, outputs=records,
                  license='CC BY 4.0 to the extent applicable; prior character and backdrop are original project AI art.',
                  postprocess='Original alpha retained, LANCZOS resize, transparent RGB zeroed. Runtime shader fades bottom 10 percent. WebP quality 85 for opaque art. No invented PBR maps.',
                  runtime_bytes=sum(r['bytes'] for r in records), decoded_rgba_bytes=sum(r['decoded_rgba_bytes'] for r in records))
    for folder in [master,runtime]:
        (folder/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ['status','runtime_image_count','runtime_bytes','decoded_rgba_bytes']}))

if __name__ == '__main__':
    main()
