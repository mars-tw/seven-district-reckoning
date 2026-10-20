"""Fast isolated import/suite loop; final certification uses test_game.py."""
import argparse,subprocess,os
from content_r13_prepare import base,ROOT
p=argparse.ArgumentParser();p.add_argument('--godot',default=os.environ.get('GODOT_BIN','godot'));p.add_argument('--suite',default='content_r13');a=p.parse_args()
source=base.snapshot();env=os.environ.copy()
for key in ['APPDATA','LOCALAPPDATA','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']:
 d=base.AUDIT/key.lower();d.mkdir(exist_ok=True);env[key]=str(d)
godot=a.godot
from test_game import disable_parallel_import
settings=source/'godot/project.godot';settings.write_text(disable_parallel_import(settings.read_text(encoding='utf8')),encoding='utf8')
commands=[['--editor','--import','--quit'],['--script',str(source/'tests'/f'{a.suite}.gd')]]
for args in commands:
 r=subprocess.run([godot,'--headless','--language','en','--path',str(source/'godot'),*args],env=env,capture_output=True,text=True,encoding='utf8',errors='replace',timeout=180)
 text=r.stdout+r.stderr;(base.AUDIT/(a.suite+('-import' if '--editor' in args else '')+'.log')).write_text(text,encoding='utf8')
 print('\n'.join(l for l in text.splitlines() if any(x in l for x in ['ERROR','FAIL','CHECKS=',' at:'])))
 if r.returncode or any(x in text for x in ['ERROR:','SCRIPT ERROR:','Parse Error:']):raise SystemExit(1)
