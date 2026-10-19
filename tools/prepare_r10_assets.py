"""Compress the actual generated diffuse master and record exact provenance."""
import argparse,hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    p=argparse.ArgumentParser();p.add_argument('--source',required=True);args=p.parse_args()
    source=Path(args.source);master=ROOT/'assets/art/r10';runtime=ROOT/'godot/assets/art/r10'
    master.mkdir(parents=True,exist_ok=True);runtime.mkdir(parents=True,exist_ok=True)
    im=Image.open(source).convert('RGB');im.save(master/'forecourt-asphalt-master.webp',lossless=True,method=6)
    native=im.resize((768,768),Image.Resampling.LANCZOS);native.save(runtime/'forecourt-asphalt.webp',quality=86,method=6)
    rows=[]
    for f in [master/'forecourt-asphalt-master.webp',runtime/'forecourt-asphalt.webp']:
        rows.append(dict(path=f.relative_to(ROOT).as_posix(),sha256=sha(f),bytes=f.stat().st_size,pixels=list(Image.open(f).size),mode=Image.open(f).mode))
    report=dict(status='VERIFIED',tool='image_gen.imagegen',model_slug=None,model_note='Actual tool did not expose model slug; do not infer a specific gpt-image model.',original_tool_sha256=sha(source),license='AI-generated original project artwork; retained third-party licenses unchanged',postprocess='Preserve opaque RGB master as lossless WebP; runtime LANCZOS resize 768 square, WebP quality86; diffuse only, no invented normal/ORM. No cutout required.',outputs=rows)
    (master/'manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    (runtime/'manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps(report))
if __name__=='__main__':main()
