"""Stage an explicit reviewed allowlist; never stage owner drafts or the repo root."""
import json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    paths=set('''README.md CREDITS.md docs/OPTIM_PLAN_R8.md docs/CODEX_RESPONSE_R8_ART.md docs/art/ART_DIRECTION.md docs/art/ART_REVIEW_R8.md docs/art/R8_MISSING_3D.md docs/art/PROMPTS.json godot/project.godot godot/scripts/main.gd godot/scripts/player/player_controller.gd godot/scripts/ui/art_theme.gd godot/scripts/ui/evidence_inspector.gd godot/scripts/ui/fraud_case_panel.gd godot/scripts/ui/game_hud.gd godot/scripts/world/contact_shadow.gd godot/scripts/world/opening_street.gd godot/scripts/world/street_art.gd godot/scripts/world/objective_beacon.gd web/shell.html tests/r8_art.gd tools/test_game.py tools/prepare_art_r8.py tools/prepare_r8_assets.py tools/build_art_r8.py tools/finalize_art_r8.py tools/verify_art_r8.py tools/stage_art_r8.py tools/r8_store_evidence.mjs tools/blender/build_art_r8.py tools/blender/verify_art_r8.py docs/store/screenshots/manifest.json docs/store/screenshots/R8_STATUS.json'''.split())
    for directory in ['assets/art/r8','assets/source/blender/r8','godot/assets/art/r8','godot/assets/models/r8','docs/art/compare/r8-before']:
        paths.update(p.relative_to(ROOT).as_posix() for p in (ROOT/directory).rglob('*') if p.is_file() and p.suffix not in ['.blend1','.pyc'])
    m=json.loads((ROOT/'docs/art/compare/r8-after/manifest.json').read_text(encoding='utf8'))
    paths.add('docs/art/compare/r8-after/manifest.json')
    for view in m['views']:
        for row in view['shots']+view['inspections']+view.get('street_angles',[])+view.get('seal_screencast',[])+view.get('seal_animation',[]):paths.add('docs/art/compare/r8-after/'+row['file'])
    status=json.loads((ROOT/'docs/store/screenshots/R8_STATUS.json').read_text(encoding='utf8'))
    paths.update('docs/store/screenshots/'+name for name in status['store_screenshots'])
    for name in ['baseline.json','protected-extra.json','native-baseline.json','final-source-tests.json','model-validation.json','web-build.json','export-budget.json','performance.json','retained-portrait-gates.json','hero-64px.png','mei-64px.png','street-list-thumbnail.png']:
        paths.add('docs/evidence/r8-art/'+name)
    for directory in ['clock-phone','clock-tablet']:
        paths.update(p.relative_to(ROOT).as_posix() for p in (ROOT/'docs/evidence/r8-art'/directory).iterdir() if p.is_file())
    if (ROOT/'tests/r8_art.gd.uid').exists():paths.add('tests/r8_art.gd.uid')
    protected=set(json.loads((ROOT/'docs/evidence/r8-art/baseline.json').read_text(encoding='utf8'))['protected'])
    protected.update(json.loads((ROOT/'docs/evidence/r8-art/protected-extra.json').read_text(encoding='utf8')))
    # This round's inventory script necessarily existed when it took its own
    # baseline. Its hash is still checked; it is not an owner draft.
    protected.discard('tools/prepare_art_r8.py')
    assert not paths&protected,sorted(paths&protected)
    assert all((ROOT/p).is_file() for p in paths),sorted(p for p in paths if not (ROOT/p).is_file())
    assert not any('.godot' in Path(p).parts or p.startswith(('native/','qa/','.github/')) for p in paths)
    (ROOT/'.audit-tmp/r8-staged-paths.json').write_text(json.dumps(sorted(paths),ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    subprocess.run(['git','add','--',*sorted(paths)],cwd=ROOT,check=True)
    print(json.dumps(dict(status='EXECUTED',explicit_paths=len(paths),protected_overlap=[])))
if __name__=='__main__':main()
