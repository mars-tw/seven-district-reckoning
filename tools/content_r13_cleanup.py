"""Delete only tracked, unchanged superseded evidence listed by the R13 plan."""
import hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
AUDIT=ROOT/'.audit-tmp/content-r13'
plan=json.loads((AUDIT/'cleanup-plan.json').read_text(encoding='utf8'))
protected=json.loads((AUDIT/'ownership.json').read_text(encoding='utf8'))['protected']
tracked=set(subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode('utf8').split('\0'))
dirty=set(subprocess.check_output(['git','diff','--name-only','-z'],cwd=ROOT).decode('utf8').split('\0'))
assert ROOT.resolve()==Path.cwd().resolve(), 'Run from the named repository root'
receipts=[]
for entry in plan['delete']:
 name=entry['path'];p=(ROOT/name).resolve()
 assert p.is_relative_to(ROOT.resolve()) and name in tracked and name not in protected and name not in dirty
 assert name.startswith(('docs/content/r','docs/evidence/','docs/art/compare/')) and not name.startswith('docs/content/r13/')
 assert p.suffix.lower() in ['.png','.webp','.jpg','.jpeg','.mp4','.webm','.gif']
 assert p.is_file() and p.stat().st_size==entry['bytes']
 receipts.append({'path':name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
for entry in receipts:
 (ROOT/entry['path']).unlink()
assert all(not (ROOT/e['path']).exists() for e in receipts)
for name,digest in protected.items():
 assert (ROOT/name).is_file() and hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name
report={'status':'EXECUTED','deleted_files':len(receipts),'released_bytes':sum(e['bytes'] for e in receipts),'deleted':receipts,'retained_script_inputs':plan['retain'],'preserved':'All Markdown reviews/reports, store screenshots, all pre-existing untracked or modified files, and named script input files. No directory removal.','post_cleanup_tests':'PREPARED: must rerun test_game.py before final delivery'}
(ROOT/'docs/content/r13/cleanup.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps({k:report[k] for k in ['status','deleted_files','released_bytes']}))
