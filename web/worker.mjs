// Pass the precompressed engine through once. Gameplay runs entirely in the browser.
// https://developers.cloudflare.com/workers/runtime-apis/response/#the-encodebody-option
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname !== '/game.wasm') return env.ASSETS.fetch(request);
    url.pathname = '/game.wasm.br';
    const assetHeaders = new Headers(request.headers);
    assetHeaders.set('Accept-Encoding', 'identity');
    assetHeaders.delete('Range');
    const asset = await env.ASSETS.fetch(new Request(url, {method:request.method,headers:assetHeaders}));
    if (!asset.ok) return asset;
    const headers = new Headers(asset.headers);
    headers.set('Content-Type', 'application/wasm');
    headers.set('Content-Encoding', 'br');
    headers.set('Cache-Control', 'public, max-age=0, must-revalidate');
    headers.set('X-Content-Type-Options', 'nosniff');
    headers.delete('Content-Length');
    const body = request.method === 'HEAD' ? null : await asset.arrayBuffer();
    return new Response(body, {status:asset.status,headers,encodeBody:'manual'});
  }
};
