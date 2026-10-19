"""Preserve original generated art and make reproducible R5 runtime derivatives."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / 'assets/art/r5'
RUNTIME = ROOT / 'godot/assets/art/r5'
SIZES = {'ceramic-tile': (768, 768), 'rolling-shutter': (768, 768),
         'workshop-window': (768, 1152), 'shop-sign': (1536, 512),
         'title-street': (1536, 1024), 'archive-seal': (512, 512)}


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sources-json', type=Path)
    args = parser.parse_args()
    for p in (MASTER, RUNTIME):
        p.mkdir(parents=True, exist_ok=True)
    inputs = json.loads(args.sources_json.read_text()) if args.sources_json else {}
    previous = json.loads((MASTER / 'manifest.json').read_text()) if (MASTER / 'manifest.json').exists() else {}
    records = []
    for name, size in SIZES.items():
        master = MASTER / (name + '.webp')
        if name in inputs:
            source = Path(inputs[name])
            im = Image.open(source).convert('RGBA' if name == 'archive-seal' else 'RGB')
            im.save(master, lossless=True, method=6)
            source_hash = sha(source)
        else:
            source_hash = next(r['generated_png_sha256'] for r in previous['outputs'] if r['id'] == name)
        im = Image.open(master)
        out = RUNTIME / (name + ('.png' if name == 'archive-seal' else '.webp'))
        im = im.resize(size, Image.Resampling.LANCZOS)
        if name == 'archive-seal':
            a = np.asarray(im.convert('RGBA')).copy()
            a[a[:, :, 3] == 0, :3] = 0
            im = Image.fromarray(a)
            im.save(out, optimize=True)
        else:
            im.save(out, quality=84, method=6)
        record = dict(id=name, master=master.relative_to(ROOT).as_posix(), master_sha256=sha(master),
                      generated_png_sha256=source_hash, path=out.relative_to(ROOT).as_posix(),
                      sha256=sha(out), size=list(size), bytes=out.stat().st_size,
                      decoded_rgba_bytes=size[0]*size[1]*4)
        if name == 'archive-seal':
            a = np.asarray(im)
            record['alpha'] = dict(corners=[int(a[y, x, 3]) for x, y in [(0, 0), (-1, 0), (0, -1), (-1, -1)]],
                                   occupancy=float((a[:, :, 3] > 0).mean()),
                                   transparent_rgb_zero=bool((a[a[:, :, 3] == 0, :3] == 0).all()))
            assert record['alpha']['corners'] == [0, 0, 0, 0] and record['alpha']['transparent_rgb_zero']
            Image.fromarray(a[:, :, 3]).save(MASTER / 'archive-seal-mask.png')
        records.append(record)
    atlas_master = MASTER / 'toolbar-atlas.webp'
    if 'toolbar-original' in inputs:
        Image.open(inputs['toolbar-original']).save(MASTER / 'toolbar-original.webp', lossless=True, method=6)
    if 'toolbar-atlas' in inputs:
        Image.open(inputs['toolbar-atlas']).convert('RGBA').save(atlas_master, lossless=True, method=6)
        atlas_hash = sha(Path(inputs['toolbar-atlas']))
    elif atlas_master.exists():
        atlas_hash = next(r['generated_png_sha256'] for r in previous['outputs'] if r['id'] == 'toolbar-0')
    if atlas_master.exists():
        atlas = Image.open(atlas_master).convert('RGBA')
        atlas.getchannel('A').save(MASTER / 'toolbar-atlas-mask.png')
        cw, ch = atlas.width // 3, atlas.height // 2
        for i in range(6):
            cell = atlas.crop((i % 3*cw, i//3*ch, (i % 3+1)*cw, (i//3+1)*ch))
            bbox = cell.getchannel('A').point(lambda x: 255 if x > 20 else 0).getbbox()
            assert bbox, 'Missing toolbar icon'
            cell = cell.crop(bbox)
            side = max(cell.size)+20
            padded = Image.new('RGBA', (side, side))
            padded.paste(cell, ((side-cell.width)//2, (side-cell.height)//2))
            im = padded.resize((96, 96), Image.Resampling.LANCZOS)
            a = np.asarray(im).copy()
            a[a[:, :, 3] == 0, :3] = 0
            im = Image.fromarray(a)
            name = f'toolbar-{i}'
            out = RUNTIME / (name+'.png')
            im.save(out, optimize=True)
            corners = [int(a[y, x, 3]) for x, y in [(0, 0), (-1, 0), (0, -1), (-1, -1)]]
            assert corners == [0, 0, 0, 0], 'Toolbar matte is opaque'
            records.append(dict(id=name, master=atlas_master.relative_to(ROOT).as_posix(), master_sha256=sha(atlas_master),
                                generated_png_sha256=atlas_hash, source_cell=i, path=out.relative_to(ROOT).as_posix(),
                                sha256=sha(out), size=[96, 96], bytes=out.stat().st_size, decoded_rgba_bytes=96*96*4,
                                alpha=dict(corners=corners,occupancy=float((a[:, :, 3] > 0).mean()),transparent_rgb_zero=True)))
    report = dict(status='VERIFIED', version='0.9.0', date='2026-10-16', tool='image_gen.imagegen', model_slug=None,
                  model_note='Actual model slug is not exposed by the built-in tool; no gpt-image model inferred.',
                  generated_master_count=7 if atlas_master.exists() else 6, runtime_image_count=len(records),
                  license='CC BY 4.0 to the extent applicable; AI-assisted original project art, no third-party inputs.',
                  postprocess='Pillow LANCZOS resize and WebP Q84. Original alpha preserved; zero RGB under transparent pixels. No painted substitute, no invented PBR maps.',
                  outputs=records, runtime_bytes=sum(r['bytes'] for r in records),
                  decoded_rgba_bytes=sum(r['decoded_rgba_bytes'] for r in records))
    for p in (MASTER / 'manifest.json', RUNTIME / 'manifest.json'):
        p.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    masks = [{'path': p.relative_to(ROOT).as_posix(), 'sha256': sha(p), 'size': list(Image.open(p).size)}
             for p in sorted(MASTER.glob('*-mask.png'))]
    (MASTER / 'alpha-masks.json').write_text(json.dumps({'status': 'VERIFIED', 'masks': masks}, indent=2) + '\n')
    print(json.dumps({k: report[k] for k in ['status', 'generated_master_count', 'runtime_bytes', 'decoded_rgba_bytes']}))


if __name__ == '__main__':
    main()
