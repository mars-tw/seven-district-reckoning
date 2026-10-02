"""Keep only source meshes actually used by this alpha. Downloads remain ignored."""
import json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'assets/source/kenney'
used={'mini-characters':['character-male-a','character-male-e','character-female-b'],'city-kit-commercial':['building-skyscraper-a','building-skyscraper-b','building-skyscraper-c','detail-overhang-wide'],'car-kit':['sedan'],'city-kit-roads':['bridge-pillar','construction-barrier','road-sign-empty','light-curved','traffic-light','road-straight','road-crossing'],'furniture-kit':['floorFull','desk','computerScreen','chairDesk','pottedPlant','loungeSofa','wallWindow','bench','bookcaseClosed'],'nature-kit':['tree_oak']}
records=json.loads((ROOT/'assets/provenance/sources.json').read_text(encoding='utf-8-sig'))
for pack,names in used.items():
 directory=(SRC/pack).resolve();assert directory.is_relative_to(SRC.resolve())
 keep={next(directory.rglob(name+'.glb')).resolve() for name in names}
 keep.add((directory/'License.txt').resolve())
 # Preserve source texture files and the directly inspected original preview.
 for p in directory.rglob('*.png'):
  if p.parent.name=='Textures' or (p.stem in names and p.parent.name=='Previews'):keep.add(p.resolve())
 before=list(directory.rglob('*'));removed=0
 for p in before:
  if p.is_file() and p.resolve() not in keep:p.unlink();removed+=1
 for p in sorted((p for p in directory.rglob('*') if p.is_dir()),key=lambda p:len(p.parts),reverse=True):
  if not any(p.iterdir()):p.rmdir()
 record=next(r for r in records if r['name']==pack)
 record['used_source_files']=[{'path':p.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in sorted(keep)]
 record['unneeded_extracted_files_removed']=removed
(ROOT/'assets/provenance/sources.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
for p in (ROOT/'assets/source/blender').glob('*.blend1'):p.unlink()
for p in (ROOT/'assets/provenance').glob('*source-page.html'):p.unlink()
for p in (ROOT/'qa/art').glob('*.log'):
 text=p.read_text(encoding='utf-8',errors='replace').replace(str(ROOT),'[workspace]').replace(ROOT.as_posix(),'[workspace]')
 p.write_text(text,encoding='utf-8')
print('Preserved source files:',sum(len(r.get('used_source_files',[])) for r in records))
