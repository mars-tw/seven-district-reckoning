"""Record ownership and preserve the exact pre-round build without touching drafts."""
import hashlib, json, shutil, subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/r10-art'
def main():
    OUT.mkdir(parents=True, exist_ok=True)
    entries = subprocess.check_output(['git','status','--porcelain=v1','-z','--untracked-files=all'], cwd=ROOT).decode('utf8').split('\0')
    protected = {e[3:]: hashlib.sha256((ROOT/e[3:]).read_bytes()).hexdigest() for e in entries if e and (ROOT/e[3:]).is_file()}
    result = dict(status='PREPARED', round=7, repo_round=10, version='0.13.0', commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(), protected=protected)
    target=OUT/'baseline.json'
    assert not target.exists()
    target.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    before=ROOT/'docs/art/compare/r10-before'; before.mkdir(parents=True,exist_ok=True)
    for p in (ROOT/'docs/store/screenshots').glob('*'):
        if p.is_file(): shutil.copy2(p,before/p.name)
    shutil.copytree(ROOT/'deliverables/web',ROOT/'.audit-tmp/r10-r9-web',dirs_exist_ok=True)
    print(json.dumps(dict(status='PREPARED',protected_files=len(protected))))
if __name__=='__main__': main()
