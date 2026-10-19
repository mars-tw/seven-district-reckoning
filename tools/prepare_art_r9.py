"""Preserve the round-six ownership boundary before producing any artifacts."""
import hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/evidence/r9-art'
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    paths=[x[3:] for x in subprocess.check_output(['git','status','--porcelain=v1','-z','--untracked-files=all'],cwd=ROOT).decode('utf8').split('\0') if x]
    protected={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths if (ROOT/p).is_file()}
    result=dict(status='PREPARED',round=6,repo_round=9,version='0.12.0',commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),protected=protected,pck_bytes=(ROOT/'deliverables/web/game.pck').stat().st_size)
    destination=OUT/'baseline.json'
    assert not destination.exists()
    destination.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps(dict(status='PREPARED',protected_files=len(protected))))
if __name__=='__main__':main()
