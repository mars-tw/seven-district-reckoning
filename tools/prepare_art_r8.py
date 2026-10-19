"""Record an immutable ownership baseline without touching pending owner work."""
import hashlib, json, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/r8-art'
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    OUT.mkdir(parents=True, exist_ok=True)
    status = subprocess.check_output(['git','status','--porcelain=v1','-z','--untracked-files=all'], cwd=ROOT).decode('utf8')
    paths = [x[3:] for x in status.split('\0') if x]
    protected = {p:sha(ROOT/p) for p in paths if (ROOT/p).is_file()}
    report = dict(status='PREPARED', branch=subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip(), commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(), protected=protected, pck_bytes=(ROOT/'deliverables/web/game.pck').stat().st_size)
    destination = OUT/'baseline.json'
    assert not destination.exists(), 'Do not replace the ownership baseline'
    destination.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps(dict(status='PREPARED', protected_files=len(protected), branch=report['branch'], commit=report['commit'])))
if __name__=='__main__':main()
