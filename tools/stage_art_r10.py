"""Stage explicit seventh-round paths only, refusing every owner's initial draft."""
import json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    paths=set('''README.md CREDITS.md docs/OPTIM_PLAN_R10.md docs/CODEX_RESPONSE_R10_ART.md docs/art/ART_DIRECTION.md docs/art/ART_REVIEW_R10.md docs/art/R10_MISSING_3D.md docs/art/PROMPTS.json docs/art/character-sheets/R10_TAILORING.md godot/project.godot godot/assets/fonts/SevenDistrictSansTC-Regular.otf godot/scripts/main.gd godot/scripts/ui/art_theme.gd godot/scripts/ui/evidence_inspector.gd godot/scripts/ui/fraud_case_panel.gd godot/scripts/ui/game_hud.gd godot/scripts/ui/mobile_touch_controls.gd godot/scripts/world/contact_shadow.gd godot/scripts/world/objective_beacon.gd godot/scripts/world/street_art.gd web/shell.html tests/r10_art.gd tools/test_game.py tools/prepare_art_r10.py tools/prepare_r10_assets.py tools/benchmark_art_r10.py tools/build_art_r10.py tools/finalize_art_r10.py tools/verify_art_r10.py tools/stage_art_r10.py tools/r10_store_evidence.mjs tools/blender/build_art_r10.py tools/blender/verify_art_r10.py docs/store/screenshots/manifest.json docs/store/screenshots/R10_STATUS.json'''.split())
    for directory in ['assets/art/r10','assets/source/blender/r10','godot/assets/art/r10','godot/assets/models/r10','docs/art/character-sheets/r10','docs/art/compare/r10-before','docs/art/compare/r10-after','docs/evidence/r10-art/benchmarks']:
        paths.update(p.relative_to(ROOT).as_posix() for p in (ROOT/directory).rglob('*') if p.is_file() and p.suffix not in ['.blend1','.blend2','.pyc'])
    for name in ['baseline.json','native-baseline.json','r4-build.json','paired-performance.json','performance-investigation.json','idle-host-load.json','model-validation.json','export-budget.json','web-build.json','final-source-tests.json','final-performance.json','retained-portrait-gates.json','hero-64px.png','mei-64px.png','street-list-thumbnail.png','street-without-sign-QA.png','artifact-verification.json']:
        p=ROOT/'docs/evidence/r10-art'/name
        if name=='artifact-verification.json' and not p.exists():continue
        paths.add(p.relative_to(ROOT).as_posix())
    status=json.loads((ROOT/'docs/store/screenshots/R10_STATUS.json').read_text(encoding='utf8'))
    paths.update('docs/store/screenshots/'+name for name in status['store_screenshots'])
    protected=set(json.loads((ROOT/'docs/evidence/r10-art/baseline.json').read_text(encoding='utf8'))['protected'])-{'tools/prepare_art_r10.py','docs/OPTIM_PLAN_R10.md'}
    assert not paths&protected,sorted(paths&protected)
    assert all((ROOT/p).is_file() for p in paths),[p for p in paths if not (ROOT/p).is_file()]
    assert not any('.godot' in Path(p).parts or p.startswith(('native/','qa/','.github/')) for p in paths)
    ordered=sorted(paths)
    for start in range(0,len(ordered),45):subprocess.run(['git','add','--',*ordered[start:start+45]],cwd=ROOT,check=True)
    (ROOT/'.audit-tmp/r10-staged-paths.json').write_text(json.dumps(ordered,indent=2)+'\n')
    print(json.dumps(dict(status='EXECUTED',explicit_paths=len(paths),owner_overlap=[])))
if __name__=='__main__':main()
