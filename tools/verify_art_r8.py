"""Verify the exact export, evidence rectangles, ownership boundary and Git index."""
import hashlib,json,re,subprocess
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/evidence/r8-art'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(name):return json.loads((ROOT/name).read_text(encoding='utf8'))
def encloses(a,b):return b[0]>=a[0]-.5 and b[1]>=a[1]-.5 and b[0]+b[2]<=a[0]+a[2]+.5 and b[1]+b[3]<=a[1]+a[3]+.5
def main():
    art=read('assets/art/r8/manifest.json');assert art['generated_masters']==3 and art['runtime_images']==3
    for row in art['outputs']:
        p=ROOT/row['path'];assert sha(p)==row['sha256'] and list(Image.open(p).size)==row['size']
        assert Path(str(p)+'.import').exists() and sha(ROOT/row['master'])==row['master_sha256']
        if row['alpha_corners'] is not None:assert row['alpha_corners']==[0]*4
    model=read('assets/art/r8/models.json');assert sha(ROOT/model['path'])==model['sha256']
    assert all(read('docs/evidence/r8-art/model-validation.json')['checks'].values())
    m=read('docs/art/compare/r8-after/manifest.json');budget=read('docs/evidence/r8-art/export-budget.json')
    assert m['status']=='VERIFIED' and not m['failures'] and len(m['views'])==10
    assert m['pck_sha256']==budget['pck_sha256']==sha(ROOT/'deliverables/web/game.pck')
    stores=[];rectangle_checks=0;subject={}
    for view in m['views']:
        size=(view['pixels']['width'],view['pixels']['height'])
        assert 'NVIDIA' in view['game_renderer'] and not view['logs'] and not view['blocked_remote_origins']
        assert len(view['shots'])==7 and len(view['inspections'])==2 and len(view['reopen_checks'])==3
        assert view['last_layout']['peak_sorts_per_frame']<=32
        for row in view['shots']+view['inspections']+view.get('street_angles',[])+view.get('seal_screencast',[])+view.get('seal_animation',[]):
            p=ROOT/'docs/art/compare/r8-after'/row['file'];assert sha(p)==row['sha256'] and Image.open(p).size==size
        for row in view['inspections']:
            d=row['state']['art']['details']['inspection'];circled=[x for x in d['marks'] if x['circled']]
            assert len(circled)==(1 if d['receipt'] else 0)
            assert not circled or circled[0]['text']=='林○翔（個人）'
            for label in d['labels']:assert encloses(d['paper'],label['rect']),(row['file'],label);rectangle_checks+=1
        if size[0] in [1290,2064]:
            for row in view['shots']+view['inspections']:
                assert sha(ROOT/'docs/store/screenshots'/row['file'])==row['sha256'];stores.append(row['file'])
                if row['file'].endswith(('-evidence.png','-link.png','-sealed.png')):
                    paper=row['state']['layout']['panel']
                    for label in row['state']['art']['details']['case_labels']:
                        assert encloses(paper,label['rect']) and label['rect'][0]>=paper[0]+40,(row['file'],label)
                        rectangle_checks+=1
            motion_dir=OUT/('clock-phone' if size[0]==1290 else 'clock-tablet');motion=json.loads((motion_dir/'manifest.json').read_text(encoding='utf8'))
            assert motion['status']=='VERIFIED' and motion['pck_sha256']==m['pck_sha256']
            frames=motion['views'][0]['clock_seal'];assert len(frames)==3 and len({x['sha256'] for x in frames})==3
            for row in frames:
                assert sha(motion_dir/row['file'])==row['sha256'] and Image.open(motion_dir/row['file']).size==size
                for label in row['state']['art']['details']['case_labels']:
                    assert encloses(row['state']['layout']['panel'],label['rect']),(row['file'],label)
            action=ROOT/'docs/store/screenshots'/f'{size[0]}x{size[1]}-seal-action.png';assert sha(action)==frames[2]['sha256'];stores.append(action.name)
        if size==(390,844):
            street=next(x['state'] for x in view['shots'] if x['file'].endswith('-street.png'))
            subject={k:street['art'][k] for k in ['hero_height_px','mei_height_px']};assert min(subject.values())>=40 and len(view['street_angles'])==3
    base=read('docs/evidence/r8-art/baseline.json');protected=base['protected']|read('docs/evidence/r8-art/protected-extra.json')
    changed=[p for p,h in protected.items() if not (ROOT/p).is_file() or sha(ROOT/p)!=h];assert not changed,changed
    tests=read('docs/evidence/r8-art/final-source-tests.json')
    assert len(tests)==29 and all(t['status']=='PASS' and t['reported_failures']==0 for t in tests)
    assert all(t['source_fingerprint']['digest']==budget['source_fingerprint']['digest'] for t in tests)
    patterns=[re.compile(r'(?<![A-Za-z0-9_.-])(?:sk-(?:proj-|sp-|ws-)?[A-Za-z0-9_.-]{28,}|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})'),re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),re.compile(r'[A-Za-z]:[/\\]Users[/\\][^/\\\s"\x27]+[/\\]',re.I),re.compile(r'sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}')]
    # A real token must still be detected, including the owner's exact unbounded
    # expression. A dusk-sky texture plus an import hash is a filename, not a key.
    assert any(p.search('sk-'+'a'*40) for p in patterns)
    assert not any(p.search('dusk-sky.webp-'+'a'*32) for p in patterns)
    findings=[];scanned=0;staged=[]
    for entry in subprocess.check_output(['git','ls-files','--stage','-z'],cwd=ROOT).decode().split('\0'):
        if not entry:continue
        _,oid,rest=entry.split(' ',2);_,name=rest.split('\t',1)
        if Path(name).suffix.lower() not in ['.gd','.gdshader','.py','.mjs','.js','.json','.md','.html','.cfg','.yml','.txt','.godot','.import','.uid','.css']:continue
        content=subprocess.check_output(['git','cat-file','blob',oid],cwd=ROOT).decode('utf8',errors='replace');scanned+=1
        if any(p.search(content) for p in patterns):findings.append(name)
    staged=subprocess.check_output(['git','diff','--cached','--name-only','-z'],cwd=ROOT).decode().split('\0')
    assert not findings,findings
    assert not (set(staged)&(set(protected)-{'tools/prepare_art_r8.py'})),'Owner work entered the index'
    runtime_mismatches=[]
    for name in staged:
        if not name.startswith(('godot/','web/','tests/')):continue
        candidate=ROOT/'.audit-tmp/r8-export'/name
        expected=subprocess.check_output(['git','show',':'+name],cwd=ROOT)
        actual=candidate.read_bytes() if candidate.is_file() else b''
        if Path(name).suffix.lower() in ['.gd','.gdshader','.json','.html','.cfg','.godot','.import','.uid','.mjs','.css']:
            actual=actual.replace(b'\r\n',b'\n');expected=expected.replace(b'\r\n',b'\n')
        if actual!=expected:runtime_mismatches.append(name)
    assert not runtime_mismatches,runtime_mismatches
    active=['godot/project.godot','web/shell.html','README.md']
    assert all('0.11.0' not in (ROOT/p).read_text(encoding='utf8') and '0.12.0' in (ROOT/p).read_text(encoding='utf8') for p in active)
    status=read('docs/store/screenshots/R8_STATUS.json')
    report=dict(status='VERIFIED',release_status=status['release_status'],release_blockers=status['release_blockers'],version='0.12.0',generated_masters=3,runtime_images=3,new_glb=1,store_screenshots=stores,viewports=10,subject_pixels=subject,rectangle_checks=rectangle_checks,tests=len(tests)-1,reported_checks=sum(t['reported_checks'] for t in tests),protected_files=len(protected),protected_mismatches=changed,staged_runtime_mismatches=runtime_mismatches,staged_text_scanned=scanned,secret_findings=findings,pck_bytes=budget['pck_bytes'],pck_delta_bytes=budget['pck_bytes']-base['pck_bytes'],source_fingerprint=budget['source_fingerprint'],pck_sha256=budget['pck_sha256'],capture_manifest_sha256=sha(ROOT/'docs/art/compare/r8-after/manifest.json'),version_active_files=active)
    (OUT/'artifact-verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps({k:report[k] for k in ['status','tests','reported_checks','viewports','pck_delta_bytes','secret_findings']}))
if __name__=='__main__':main()
