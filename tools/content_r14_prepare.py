"""Isolate tracked game source, replacing owner drafts with their HEAD versions."""
import content_r12_prepare as base
from pathlib import Path
import argparse

ROOT=Path(__file__).resolve().parents[1]
base.AUDIT=ROOT/'.audit-tmp/content-r14'
base.SOURCE=base.AUDIT/'source'
base.EXTRA=['tests/content_r14.gd','tools/content_r14_prepare.py','tools/content_r14_evidence.mjs','godot/assets/art/content-r14/paper-seal.webp']

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--build',action='store_true');p.add_argument('--godot');a=p.parse_args()
 (ROOT/'docs/content/r14').mkdir(parents=True,exist_ok=True)
 base.snapshot()
 if a.build:
  # Godot's incremental exporter may skip an unchanged runtime; the web
  # adapter removes raw WASM after Brotli compression. Restore it first.
  runtime=base.AUDIT/'web/game.wasm'
  if not runtime.exists() and runtime.with_suffix('.wasm.br').exists():
   import subprocess
   subprocess.run(['node','-e',"const fs=require('fs'),z=require('zlib');fs.writeFileSync(process.argv[1],z.brotliDecompressSync(fs.readFileSync(process.argv[1]+'.br')))",str(runtime)],check=True)
  # Existing adapter only writes its own R12 output paths; redirect those two
  # reports locally without touching the retained R12 evidence.
  source=(ROOT/'tools/content_r12_prepare.py').read_text(encoding='utf8').replace("ROOT / '.audit-tmp/content-r12'","ROOT / '.audit-tmp/content-r14'").replace('docs/content/r12','docs/content/r14')
  scope={'__file__':str(ROOT/'tools/content_r14_prepare.py'),'__name__':'r14_adapter'}
  exec(compile(source,'r14_adapter','exec'),scope)
  scope['EXTRA']=base.EXTRA
  scope['build'](a.godot)
