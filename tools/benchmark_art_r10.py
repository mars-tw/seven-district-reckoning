"""Build the named historical revision and record paired Web RAF runs with host load."""
import argparse, datetime, hashlib, io, json, re, subprocess, threading, time, zipfile
from pathlib import Path
import ctypes
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/evidence/r10-art'
def load_sample():
    def ticks():
        values=[ctypes.c_ulonglong() for _ in range(3)]
        ctypes.windll.kernel32.GetSystemTimes(*(ctypes.byref(x) for x in values))
        return [x.value for x in values]
    a=ticks();time.sleep(.1);b=ticks();total=(b[1]-a[1])+(b[2]-a[2])
    class Memory(ctypes.Structure):
        _fields_=[('length',ctypes.c_ulong),('load',ctypes.c_ulong)]+[(name,ctypes.c_ulonglong) for name in ['total','available','page','available_page','virtual','available_virtual','extended']]
    memory=Memory();memory.length=ctypes.sizeof(memory);ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(memory))
    sample=dict(utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),cpu_percent=round(100*(1-(b[0]-a[0])/max(1,total)),1),memory_available_mib=round(memory.available/1048576))
    r=subprocess.run(['nvidia-smi','--query-gpu=utilization.gpu,utilization.memory,memory.used,memory.total','--format=csv,noheader,nounits'],capture_output=True,text=True)
    sample['gpu_raw']=r.stdout.strip()
    if r.returncode==0:
        values=[int(x.strip()) for x in r.stdout.strip().split(',')]
        sample.update(zip(['gpu_percent','gpu_memory_percent','gpu_used_mib','gpu_total_mib'],values))
    return sample
def run(cmd,cwd=ROOT):
    p=subprocess.run(cmd,cwd=cwd,capture_output=True,text=True,encoding='utf8',errors='replace',timeout=360)
    if p.returncode: raise RuntimeError(p.stdout[-2500:]+p.stderr[-2500:])
    return p.stdout+p.stderr
def build_r4(godot):
    target=ROOT/'.audit-tmp/r10-dc73132'; target.mkdir(parents=True,exist_ok=True)
    data=subprocess.check_output(['git','archive','--format=zip','dc73132'],cwd=ROOT)
    with zipfile.ZipFile(io.BytesIO(data)) as archive: archive.extractall(target)
    # Match the revision's documented R7 packaging exclusions, leaving source unchanged.
    excluded=['assets/art/r4/'+x for x in ['app-icon.png','ayuan-portrait.png','meiqing-portrait.png','title-logo.png','title-street.webp']]
    excluded+=['assets/art/r5/title-street.webp']+['assets/art/r6/'+x for x in ['ayuan-portrait.png','meiqing-portrait.png','title-street.webp']]
    excluded+=['assets/models/r7/ayuan-tailored.glb','assets/art/r7/case-panel.webp']
    preset=target/'godot/export_presets.cfg'
    preset.write_text(re.sub(r'(?m)^exclude_filter="([^"]*)"$',lambda m:'exclude_filter="'+m[1]+','+','.join(excluded)+'"',preset.read_text(encoding='utf8')),encoding='utf8')
    dest=target/'deliverables/web';dest.mkdir(parents=True,exist_ok=True)
    log=''
    for options in [['--editor','--import','--quit'],['--export-release','Web',str(dest/'game.html')]]:
        log+=run([godot,'--headless','--quiet','--language','en','--path',str(target/'godot'),*options])
    (OUT/'r4-export.log').write_text(log,encoding='utf8')
    run(['node','tools/prepare_web_assets.mjs'],cwd=target)
    (OUT/'r4-build.json').write_text(json.dumps(dict(status='VERIFIED',commit=run(['git','rev-parse','dc73132']).strip(),version='0.11.0',pck_sha256=hashlib.sha256((dest/'game.pck').read_bytes()).hexdigest(),pck_bytes=(dest/'game.pck').stat().st_size),indent=2)+'\n')
def main():
    p=argparse.ArgumentParser();p.add_argument('--godot');p.add_argument('--playwright-module');p.add_argument('--build-r4',action='store_true');p.add_argument('--final',action='store_true');args=p.parse_args()
    OUT.mkdir(parents=True,exist_ok=True)
    if args.build_r4: build_r4(args.godot);return
    assert args.playwright_module
    # A/B then B/A counters order drift while only one browser/server runs.
    rows=[]
    sources=[('r4',ROOT/'.audit-tmp/r10-dc73132/deliverables/web','0.11.0'),('r9',ROOT/'.audit-tmp/r10-r9-web','0.13.0')]
    if args.final: sources=[('r10',ROOT/'deliverables/web','0.14.0')]
    for tag in ['390x844','1366x768']:
        for index,(label,web,version) in enumerate(sources if args.final else sources+list(reversed(sources))):
            folder=OUT/'benchmarks'/f'{tag}-{index}-{label}'
            samples=[load_sample()]; stop=threading.Event()
            def monitor():
                while not stop.wait(1): samples.append(load_sample())
            thread=threading.Thread(target=monitor,daemon=True);thread.start()
            try:
                output=run(['node','tools/r9_store_evidence.mjs','--web-dir',str(web),'--playwright-module',args.playwright_module,'--output',str(folder),'--version',version,'--only',tag,'--perf-only'])
            finally:
                stop.set();thread.join();samples.append(load_sample())
                folder.mkdir(parents=True,exist_ok=True)
                (folder/'host-load.json').write_text(json.dumps(dict(status='EXECUTED',samples=samples),indent=2)+'\n')
            m=json.loads((folder/'manifest.json').read_text(encoding='utf8'))
            v=m['views'][0]
            row=dict(revision=label,pixels=tag,order=index,pck_sha256=m['pck_sha256'],renderer=v['game_renderer'],pacing=v['frame_pacing'],host_load_path=(folder/'host-load.json').relative_to(ROOT).as_posix(),before=samples[0],after=samples[-1])
            rows.append(row);print(json.dumps({k:row[k] for k in ['revision','pixels','order','before','after']}|{'p95_median':row['pacing']['p95_median']}),flush=True)
            (OUT/('final-performance.json' if args.final else 'paired-performance.json')).write_text(json.dumps(dict(status='EXECUTED',method='Same R9 capture harness, hardware ANGLE D3D11, same viewport/DPR/profile, actual cold-open, 3 x 180 RAF intervals per build; ABBA order for each viewport',environment='Concurrent host load; no other owner workloads stopped',rows=rows),indent=2)+'\n')
if __name__=='__main__':main()
