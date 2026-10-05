"""Local preview with the same Brotli headers as the static production host."""
import argparse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, default=8766)
parser.add_argument('--directory', type=Path, default=root / 'deliverables/web')
args = parser.parse_args()
directory = args.directory.resolve()
aliases = {'/index.html': '/', '/game.html': '/'}
for profile in ('phone', 'tablet', 'desktop'):
    aliases['/' + profile] = '/' + profile + '/'
    aliases['/' + profile + '/index.html'] = '/' + profile + '/'
class Handler(SimpleHTTPRequestHandler):
    def __init__(self,*a,**kw): super().__init__(*a,directory=str(directory),**kw)
    def canonical_redirect(self):
        url = urlsplit(self.path)
        if url.path not in aliases: return False
        self.send_response(301)
        self.send_header('Location', urlunsplit(('', '', aliases[url.path], url.query, '')))
        self.send_header('Content-Length', '0')
        self.end_headers()
        return True
    def do_GET(self):
        if not self.canonical_redirect(): super().do_GET()
    def do_HEAD(self):
        if not self.canonical_redirect(): super().do_HEAD()
    def send_response(self, code, message=None):
        self.response_code = code
        super().send_response(code, message)
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
        if urlsplit(path).path == '/game.wasm':
            return translated + '.br'
        return translated
    def end_headers(self):
        if urlsplit(self.path).path == '/game.wasm' and getattr(self, 'response_code', 0) in (200, 304):
            self.send_header('Content-Encoding','br')
        self.send_header('X-Content-Type-Options','nosniff')
        self.send_header('Cache-Control','public, max-age=0, must-revalidate')
        super().end_headers()
    def guess_type(self,path):
        if path.endswith(('.wasm', '.wasm.br')): return 'application/wasm'
        if path.endswith('.pck'): return 'application/octet-stream'
        if path.endswith('.js'): return 'application/javascript'
        return super().guess_type(path)
print(f'Static web preview on http://127.0.0.1:{args.port}', flush=True)
ThreadingHTTPServer(('127.0.0.1',args.port),Handler).serve_forever()
