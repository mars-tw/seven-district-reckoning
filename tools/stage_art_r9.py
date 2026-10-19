"""Stage only the reviewed round-six deliverables; retain owner work verbatim."""
import json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
 paths=set('''README.md CREDITS.md docs/OPTIM_PLAN_R9.md docs/CODEX_RESPONSE_R9_ART.md docs/art/ART_DIRECTION.md docs/art/ART_REVIEW_R9.md docs/art/R9_MISSING_3D.md docs/art/PROMPTS.json godot/project.godot godot/scripts/main.gd godot/scripts/player/player_controller.gd godot/scripts/ui/art_theme.gd godot/scripts/ui/evidence_inspector.gd godot/scripts/ui/fraud_case_panel.gd godot/scripts/ui/story_intro.gd godot/scripts/world/opening_street.gd godot/scripts/world/street_art.gd godot/scripts/world/taiwan_expansion.gd web/shell.html tests/r9_art.gd tools/test_game.py tools/prepare_art_r9.py tools/prepare_r9_assets.py tools/build_art_r9.py tools/finalize_art_r9.py tools/verify_art_r9.py tools/stage_art_r9.py tools/r9_store_evidence.mjs tools/blender/build_art_r9.py tools/blender/verify_art_r9.py docs/store/screenshots/manifest.json docs/store/screenshots/R9_STATUS.json'''.split())
 paths.add('tools/write_art_report_r9.py')
 paths.add('docs/evidence/r9-art/recognition-crop.json')
 for directory in ['assets/art/r9','assets/source/blender/r9','godot/assets/art/r9','godot/assets/models/r9','docs/art/character-sheets/r9','docs/art/compare/r9-before']:
  paths.update(p.relative_to(ROOT).as_posix() for p in (ROOT/directory).rglob('*') if p.is_file() and p.suffix not in ['.blend1','.blend2','.pyc'])
 m=json.loads((ROOT/'docs/art/compare/r9-after/manifest.json').read_text(encoding='utf8'))
 paths.add('docs/art/compare/r9-after/manifest.json')
 for v in m['views']:
  for row in v['shots']+v['inspections']+v.get('clock_seal',[])+v.get('street_angles',[])+v.get('seal_screencast',[])+v.get('seal_animation',[]):paths.add('docs/art/compare/r9-after/'+row['file'])
 status=json.loads((ROOT/'docs/store/screenshots/R9_STATUS.json').read_text(encoding='utf8'))
 paths.update('docs/store/screenshots/'+name for name in status['store_screenshots'])
 for name in ['baseline.json','native-baseline.json','final-source-tests.json','model-validation.json','export-budget.json','web-build.json','performance.json','performance-investigation.json','retained-portrait-gates.json','hero-64px.png','mei-64px.png','mei-without-marker.png','street-list-thumbnail.png','artifact-verification.json']:
  if name=='artifact-verification.json' and not (ROOT/'docs/evidence/r9-art'/name).exists():continue
  paths.add('docs/evidence/r9-art/'+name)
 for name in ['tests/r9_art.gd.uid']:
  if (ROOT/name).exists():paths.add(name)
 # These two round-owned files were created immediately before the baseline;
 # their hashes remain checked, but they are authorized delivery files.
 protected=set(json.loads((ROOT/'docs/evidence/r9-art/baseline.json').read_text(encoding='utf8'))['protected'])-{'tools/prepare_art_r9.py','docs/OPTIM_PLAN_R9.md'}
 assert not paths&protected,sorted(paths&protected)
 assert all((ROOT/p).is_file() for p in paths),sorted(p for p in paths if not (ROOT/p).is_file())
 assert not any('.godot' in Path(p).parts or p.startswith(('native/','qa/','.github/')) for p in paths)
 (ROOT/'.audit-tmp/r9-staged-paths.json').write_text(json.dumps(sorted(paths),indent=2)+'\n')
 subprocess.run(['git','add','--',*sorted(paths)],cwd=ROOT,check=True)
 print(json.dumps(dict(status='EXECUTED',explicit_paths=len(paths),owner_overlap=[])))
if __name__=='__main__':main()
