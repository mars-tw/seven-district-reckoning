"""One headless browser/server at a time, with concurrent host-load evidence."""
import argparse
import json
from pathlib import Path
import subprocess
import threading
from benchmark_art_r10 import load_sample

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--playwright-module', required=True)
    parser.add_argument('--only')
    parser.add_argument('--chromium-executable', required=True)
    parser.add_argument('--output', default='docs/content/r12')
    args = parser.parse_args()
    out = ROOT / args.output
    out.mkdir(parents=True, exist_ok=True)
    samples = [load_sample()]
    stop = threading.Event()
    def monitor():
        while not stop.wait(3):
            samples.append(load_sample())
    thread = threading.Thread(target=monitor, daemon=True)
    thread.start()
    command = ['node', 'tools/content_r12_evidence.mjs', '--playwright-module', args.playwright_module, '--output', args.output, '--chromium-executable', args.chromium_executable]
    if args.only:
        command += ['--only', args.only]
    try:
        result = subprocess.run(command, cwd=ROOT, timeout=3600)
    finally:
        stop.set()
        thread.join()
        samples.append(load_sample())
        (out/'host-load.json').write_text(json.dumps({'status':'EXECUTED', 'method':'Concurrent owner workloads preserved; CPU, available memory and nvidia-smi sampled during Web capture. Reference only.', 'samples':samples},indent=2)+'\n',encoding='utf8')
    raise SystemExit(result.returncode)

if __name__ == '__main__':
    main()
