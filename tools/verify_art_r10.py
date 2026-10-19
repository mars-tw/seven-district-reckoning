"""Audit ownership, native-size frames, clean-source checks and indexed secrets."""
import hashlib,json,re,struct,subprocess
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/evidence/r10-art'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads((ROOT/p).read_text(encoding='utf8'))
def encloses(a,b):return b[0]>=a[0]-.5 and b[1]>=a[1]-.5 and b[0]+b[2]<=a[0]+a[2]+.5 and b[1]+b[3]<=a[1]+a[3]+.5
def main():
    protected=read('docs/evidence/r10-art/baseline.json')['protected']
    changed=[p for p,h in protected.items() if not (ROOT/p).is_file() or sha(ROOT/p)!=h];assert not changed,changed
    art=read('assets/art/r10/manifest.json')
    for row in art['outputs']:
        assert sha(ROOT/row['path'])==row['sha256'] and list(Image.open(ROOT/row['path']).size)==row['pixels']
    models=read('assets/art/r10/models.json');validation=read('docs/evidence/r10-art/model-validation.json')
    assert validation['status']=='VERIFIED' and all(validation['checks'].values())
    model_details=[]
    for row in models['outputs']:
        assert sha(ROOT/row['path'])==row['sha256'] and sha(ROOT/row['source'])==row['source_sha256']
        data=(ROOT/row['path']).read_bytes();g=json.loads(data[20:20+struct.unpack_from('<I',data,12)[0]])
        if row['id']=='hero_human':assert len(g['animations'])==8 and len(g['skins'][0]['joints'])>30
        tris=sum(g['accessors'][p['indices']]['count']//3 for mesh in g['meshes'] for p in mesh['primitives'])
        model_details.append(dict(id=row['id'],triangles=tris,material_batches=sum(len(x['primitives']) for x in g['meshes']),animations=len(g.get('animations',[])),bytes=row['bytes']))
    m=read('docs/art/compare/r10-after/manifest.json');budget=read('docs/evidence/r10-art/export-budget.json')
    assert m['status']=='VERIFIED' and not m['failures'] and len(m['views'])==10
    assert m['pck_sha256']==budget['pck_sha256']==sha(ROOT/'deliverables/web/game.pck')
    geometric=0;stores=[]
    for view in m['views']:
        size=(view['pixels']['width'],view['pixels']['height']);screen=view['viewport']
        assert 'NVIDIA' in view['game_renderer'] and not view['logs'] and not view['blocked_remote_origins']
        assert len(view['shots'])==8 and len(view['inspections'])==2 and len(view['reopen_checks'])==3
        assert view['last_layout']['peak_sorts_per_frame']<=32
        for row in view['shots']+view['inspections']+view.get('street_angles',[])+view.get('clock_seal',[]):
            p=ROOT/'docs/art/compare/r10-after'/row['file'];assert sha(p)==row['sha256'] and Image.open(p).size==size
        for row in view['inspections']:
            d=row['state']['art']['details']['inspection'];circles=[x for x in d['marks'] if x['circled']]
            assert len(circles)==(1 if d['receipt'] else 0)
            assert not circles or circles[0]['text']=='林○翔（個人）'
            assert d['paper'][1]*2/screen['height']<=.10 and d['close'][1]>=d['paper'][1]+d['paper'][3]-.5
            for label in d['labels']:assert encloses(d['paper'],label['rect']),(row['file'],label);geometric+=1
        if size[0] in [1290,2064]:
            for row in view['shots']+view['inspections']:
                assert sha(ROOT/'docs/store/screenshots'/row['file'])==row['sha256'];stores.append(row['file'])
                if row['file'].endswith(('-evidence.png','-link.png','-linked.png','-sealed.png')):
                    paper=row['state']['layout']['panel']
                    for label in row['state']['art']['details']['case_labels']:
                        assert encloses(paper,label['rect']) and label['rect'][0]>=paper[0]+40,(row['file'],label);geometric+=1
            frames=view['clock_seal'];assert len(frames)==3 and len({x['sha256'] for x in frames})==3
            assert frames[2]['state']['art']['details']['seal']['applicator']
            assert frames[0]['state']['art']['details']['seal']['scale']>1.05,'Store action must visibly show the scaled pressing impression'
            action=f'{size[0]}x{size[1]}-seal-action.png';assert sha(ROOT/'docs/store/screenshots'/action)==frames[0]['sha256'];stores.append(action)
    tests=read('docs/evidence/r10-art/final-source-tests.json')
    assert len(tests)==31 and all(t['status']=='PASS' and t['reported_failures']==0 for t in tests)
    assert all(t['source_fingerprint']['digest']==budget['source_fingerprint']['digest'] for t in tests)
    staged=[p for p in subprocess.check_output(['git','diff','--cached','--name-only','-z'],cwd=ROOT).decode().split('\0') if p]
    assert not set(staged)&(set(protected)-{'tools/prepare_art_r10.py','docs/OPTIM_PLAN_R10.md'})
    patterns=[re.compile(r'sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}'),re.compile(r'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}'),re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----')]
    findings=[];scanned=0
    for item in subprocess.check_output(['git','ls-files','--stage','-z'],cwd=ROOT).decode().split('\0'):
        if not item:continue
        _,oid,tail=item.split(' ',2);_,name=tail.split('\t',1)
        if Path(name).suffix.lower() not in ['.gd','.gdshader','.gdshaderinc','.py','.mjs','.js','.json','.md','.html','.cfg','.yml','.yaml','.txt','.godot','.import','.uid','.css','.svg','.tscn','.tres','.toml','.ini','.ps1','.sh'] and Path(name).name not in ['LICENSE','.gitignore','.gitattributes']:continue
        content=subprocess.check_output(['git','cat-file','blob',oid],cwd=ROOT).decode('utf8',errors='replace');scanned+=1
        if any(p.search(content) for p in patterns):findings.append(name)
    assert not findings,findings
    broad=subprocess.run(['git','grep','--cached','-I','-l','-E','sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----'],cwd=ROOT,capture_output=True,text=True,encoding='utf8',errors='replace')
    assert broad.returncode==1 and not broad.stdout,'All-index text scan failed or found a possible credential; inspect paths without printing values'
    for name in staged:
        if not name.startswith(('godot/','web/','tests/')):continue
        p=ROOT/'.audit-tmp/r10-export'/name
        assert p.is_file(),name
        actual=p.read_bytes();expected=subprocess.check_output(['git','show',':'+name],cwd=ROOT)
        if Path(name).suffix.lower() in ['.gd','.gdshader','.json','.html','.cfg','.godot','.import','.uid','.mjs','.css']:
            actual=actual.replace(b'\r\n',b'\n');expected=expected.replace(b'\r\n',b'\n')
        assert actual==expected,name
    report=dict(status='VERIFIED',version='0.14.0',store_screenshots=len(stores),geometry_checks=geometric,tests={'suites':len(tests)-1,'checks':sum(t['reported_checks'] for t in tests),'failures':0},protected_files_unchanged=len(protected),secret_scan={'indexed_text_files':scanned,'findings':[]},models=model_details,runtime_index_matches_export=True,pck_sha256=m['pck_sha256'],release_status='BLOCKED',limitations=['Independent 8/10 rescore outstanding','Concurrent phone and desktop p95 above18ms; clean machine/native validation outstanding','3D runtime per-object masks outstanding'])
    (OUT/'artifact-verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8');print(json.dumps(report,ensure_ascii=False))
if __name__=='__main__':main()
