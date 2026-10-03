"""Local preview with the same Brotli headers as the static production host."""
import argparse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, default=8766)
args = parser.parse_args()
directory = root / 'deliverables/web'
class Handler(SimpleHTTPRequestHandler):
    def __init__(self,*a,**kw): super().__init__(*a,directory=str(directory),**kw)
    def send_error(self,code,message=None,explain=None):
        if code != 404: return super().send_error(code,message,explain)
        data = (directory/'404.html').read_bytes()
        self.send_response(404)
        self.send_header('Content-Type','text/html; charset=utf-8')
        self.send_header('Content-Length',str(len(data)))
        self.end_headers()
        if self.command != 'HEAD': self.wfile.write(data)
    def translate_path(self,path):
        translated = super().translate_path(path)
        if path.split('?')[0].endswith('/game.wasm'):
            return translated + '.br'
        return translated
    def end_headers(self):
        if self.path.split('?')[0].endswith('/game.wasm'):
            self.send_header('Content-Encoding','br')
        self.send_header('X-Content-Type-Options','nosniff')
        super().end_headers()
    def guess_type(self,path):
        if path.endswith('.wasm'): return 'application/wasm'
        return super().guess_type(path)
print(f'Static web preview on http://127.0.0.1:{args.port}', flush=True)
ThreadingHTTPServer(('127.0.0.1',args.port),Handler).serve_forever()
