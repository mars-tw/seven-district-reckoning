"""Audit exact screenshots, protected files, art provenance and staged secrets."""
import hashlib,json,re,subprocess
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/evidence/r7-art'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads((ROOT/p).read_text(encoding='utf8'))

def main():
    art=read('godot/assets/art/r7/manifest.json')
    assert art['generated_master_count']==8 and art['runtime_image_count']==11
    for row in art['masters']:
        assert sha(ROOT/row['path'])==row['sha256']
    for row in art['outputs']:
        p=ROOT/row['path'];im=Image.open(p)
        assert sha(p)==row['sha256'] and list(im.size)==row['size']
        assert Path(str(p)+'.import').exists()
        if 'alpha' in row:
            assert row['alpha']['corners']==[0]*4 and row['alpha']['transparent_rgb_zero']
            if 'portrait' in row['id']:assert row['character_gate']['pass']
    models=read('assets/art/r7/models.json')
    model_qa=read('docs/evidence/r7-art/model-validation.json')
    assert model_qa['status']=='VERIFIED' and all(x['pass_result'] for x in model_qa['checks'])
    for row in models['outputs']:assert sha(ROOT/row['path'])==row['sha256']
    capture=read('docs/art/compare/r7-after/manifest.json')
    budget=read('docs/evidence/r7-art/export-budget.json')
    assert capture['status']=='VERIFIED' and not capture['failures'] and len(capture['views'])==10
    assert capture['pck_sha256']==budget['pck_sha256']==sha(ROOT/'deliverables/web/game.pck')
    stores=[];pacing=[];subject={}
    for view in capture['views']:
        assert 'NVIDIA' in view['game_renderer'] and len(view['shots'])==7 and len(view['inspections'])==2
        assert not view['logs'] and not view['blocked_remote_origins'] and len(view['reopen_checks'])==3
        assert view['last_layout']['peak_sorts_per_frame']<=32
        size=(view['pixels']['width'],view['pixels']['height'])
        records=view['shots']+view['inspections']+view.get('street_angles',[])+view.get('seal_screencast',[])+view.get('seal_animation',[])
        for row in records:
            p=ROOT/'docs/art/compare/r7-after'/row['file']
            assert sha(p)==row['sha256'] and Image.open(p).size==size
        if size[0] in [1290,2064]:
            for row in view['shots']+view['inspections']:
                p=ROOT/'docs/store/screenshots'/row['file']
                assert sha(p)==row['sha256'];stores.append(row['file'])
            motion_dir=OUT/('clock-phone' if size[0]==1290 else 'clock-tablet')
            motion=json.loads((motion_dir/'manifest.json').read_text(encoding='utf8'))
            assert motion['status']=='VERIFIED' and motion['pck_sha256']==capture['pck_sha256']
            frames=motion['views'][0]['clock_seal']
            assert len(frames)==3 and len({r['sha256'] for r in frames})==3
            for row in frames:
                p=motion_dir/row['file']
                assert Image.open(p).size==size and sha(p)==row['sha256']
            action=frames[2]
            p=ROOT/'docs/store/screenshots'/f'{size[0]}x{size[1]}-seal-action.png'
            assert p.exists() and sha(p)==action['sha256'];stores.append(p.name)
        if size==(390,844):
            street=next(x['state'] for x in view['shots'] if x['file'].endswith('-street.png'))
            subject={k:street['art'][k] for k in ['hero_height_px','mei_height_px']}
            assert min(subject.values())>=40 and len(view['street_angles'])==3
        if 'frame_pacing' in view:pacing.append(dict(pixels=list(size),**view['frame_pacing']))
    protected=read('docs/evidence/r7-art/protected-before.json')
    changed=[p for p,h in protected.items() if not (ROOT/p).is_file() or sha(ROOT/p)!=h]
    assert not changed,changed
    initial=read('docs/evidence/r7-art/initial-untracked.json')
    assert all((ROOT/p).exists() for p in initial)
    tests=read('docs/evidence/r7-art/final-source-tests.json')
    assert len(tests)==28 and all(t['status']=='PASS' and t['reported_failures']==0 for t in tests)
    assert all(t['source_fingerprint']['digest']==budget['source_fingerprint']['digest'] for t in tests)
    patterns=[re.compile(r'(?:sk-(?:proj-|sp-|ws-)?[A-Za-z0-9_.-]{28,}|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})'),re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),re.compile(r'[A-Za-z]:[/\\]Users[/\\][^/\\\s"\x27]+[/\\]',re.I)]
    scanned=0;findings=[]
    for entry in subprocess.check_output(['git','ls-files','--stage','-z'],cwd=ROOT).decode().split('\0'):
        if not entry:continue
        _,oid,rest=entry.split(' ',2);_,name=rest.split('\t',1)
        if Path(name).suffix.lower() not in ['.gd','.gdshader','.py','.mjs','.js','.json','.md','.html','.cfg','.yml','.txt','.godot','.import','.uid','.css']:continue
        content=subprocess.check_output(['git','cat-file','blob',oid],cwd=ROOT).decode('utf8',errors='replace');scanned+=1
        if any(p.search(content) for p in patterns):findings.append(name)
    assert not findings,findings
    base=read('docs/evidence/r7-art/baseline.json')
    report=dict(status='VERIFIED',version='0.11.0',generated_masters=8,runtime_images=11,new_glb=2,store_screenshots=stores,viewports=10,subject_pixels=subject,tests=len(tests)-1,reported_checks=sum(t['reported_checks'] for t in tests),protected_mismatches=changed,initial_untracked_preserved=len(initial),staged_text_scanned=scanned,secret_findings=findings,pacing=pacing,pck_bytes=budget['pck_bytes'],pck_delta_bytes=budget['pck_bytes']-base['pck_bytes'],source_fingerprint=budget['source_fingerprint'],pck_sha256=budget['pck_sha256'],capture_manifest_sha256=sha(ROOT/'docs/art/compare/r7-after/manifest.json'))
    report['release_status']='BLOCKED'
    report['release_blockers']=read('docs/store/screenshots/R7_STATUS.json')['release_blockers']
    (OUT/'artifact-verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ['status','tests','reported_checks','viewports','pck_delta_bytes','secret_findings']}))

if __name__=='__main__':main()
