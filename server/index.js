// RIM multiplayer server: the web game itself (the Godot Web export in public/), GET /healthz (or /health), GET
// /api/lobbies (the public lobbies and matches as JSON) and, at /ws, the WebSocket protocol of PROTOCOL.md (logic in
// lobby.js). `node index.js` listens on $PORT (default 8787);
// the tests import startServer().
import { createReadStream, realpathSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { dirname, extname, resolve, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { WebSocket, WebSocketServer } from 'ws';
import { Hub } from './lobby.js';

const MAX_MESSAGE = 8 * 1024; // bytes; a bigger message closes the socket (close code 1009)
const MAX_BACKLOG = 1 << 20; // bytes queued for a client that stopped reading: it is cut off

const PUBLIC = resolve(dirname(fileURLToPath(import.meta.url)), 'public'); // the Web export (filled by the image build)
const TYPES = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream', '.png': 'image/png', '.svg': 'image/svg+xml', '.ico': 'image/x-icon',
  '.json': 'application/json', '.webmanifest': 'application/manifest+json', '.txt': 'text/plain; charset=utf-8',
};
const NO_GAME = '<!doctype html><meta charset="utf-8"><title>RIM</title><p>The game files are not in this server image.</p>';

// A file of the web game, or false when there is none (the caller answers 404). Every file is revalidated on each
// load (a deploy replaces them under the same names); a .gz twin made at build time is sent to browsers that take gzip.
function serveFile(root, req, res) {
  let path;
  try { path = decodeURIComponent(req.url.split('?')[0]); } catch { return false; }
  if (path.endsWith('/')) path += 'index.html';
  const file = resolve(root, '.' + path);
  if (!file.startsWith(root + sep)) return false; // never outside the game's folder
  let st;
  try { st = statSync(file); } catch { return path === '/index.html' && res.writeHead(200, { 'content-type': TYPES['.html'] }).end(NO_GAME); }
  if (!st.isFile()) return false;
  let body = file;
  const headers = { 'content-type': TYPES[extname(file)] ?? 'application/octet-stream', 'cache-control': 'no-cache', vary: 'accept-encoding' };
  if (/\bgzip\b/.test(req.headers['accept-encoding'] ?? '')) {
    try {
      const gz = statSync(file + '.gz');
      if (gz.isFile()) { body = file + '.gz'; st = gz; headers['content-encoding'] = 'gzip'; }
    } catch { /* no compressed twin */ }
  }
  headers.etag = `W/"${st.size.toString(36)}-${Math.floor(st.mtimeMs).toString(36)}${headers['content-encoding'] ? '-gz' : ''}"`;
  if (req.headers['if-none-match'] === headers.etag) return res.writeHead(304, headers).end();
  headers['content-length'] = st.size;
  res.writeHead(200, headers);
  if (req.method === 'HEAD') return res.end();
  createReadStream(body).on('error', () => res.destroy()).pipe(res);
  return true;
}

const envInt = (name, fallback) => {
  const v = Number.parseInt(process.env[name] ?? '', 10);
  return Number.isInteger(v) && v >= 0 ? v : fallback;
};
const stamp = (line) => console.log(`${new Date().toISOString()} ${line}`);

export async function startServer({
  port = envInt('PORT', 8787),
  host, // default: every interface
  countdownMs = envInt('COUNTDOWN_MS', 5000), // ready countdown (shortened by the tests)
  stallMs = envInt('STALL_MS', 30_000), // a match member the others wait for, silent this long, leaves the match
  pingMs = 20_000, // keepalive: ping every client this often, close those that missed the previous pong
  publicDir = PUBLIC, // the web game's files
  log = stamp,
} = {}) {
  const root = resolve(publicDir);
  const hub = new Hub({ countdownMs, stallMs, log });
  const wss = new WebSocketServer({ noServer: true, maxPayload: MAX_MESSAGE });
  const server = createServer((req, res) => {
    const read = req.method === 'GET' || req.method === 'HEAD';
    const path = req.url.split('?')[0];
    if (read && ['/healthz', '/health'].includes(path)) return res.writeHead(200, { 'content-type': 'text/plain' }).end('ok');
    if (read && path === '/api/lobbies') {
      return res.writeHead(200, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', 'access-control-allow-origin': '*' })
        .end(JSON.stringify(hub.overview(), null, 2) + '\n');
    }
    if (read && serveFile(root, req, res)) return;
    res.writeHead(404, { 'content-type': 'text/plain' }).end('not found');
  });

  server.on('upgrade', (req, socket, head) => {
    if (req.url.split('?')[0] !== '/ws') {
      socket.on('error', () => {});
      socket.once('finish', () => socket.destroy());
      socket.end('HTTP/1.1 404 Not Found\r\nConnection: close\r\nContent-Length: 0\r\n\r\n');
      return;
    }
    wss.handleUpgrade(req, socket, head, (ws) => wss.emit('connection', ws, req));
  });

  wss.on('connection', (ws, req) => {
    const forwarded = String(req.headers['x-forwarded-for'] ?? '').split(',')[0].trim(); // set by Caddy
    const ip = (forwarded || req.socket.remoteAddress || '?').replace(/^::ffff:/, '');
    const client = hub.connect((text) => {
      if (ws.readyState !== WebSocket.OPEN) return;
      if (ws.bufferedAmount > MAX_BACKLOG) return ws.terminate();
      ws.send(text);
    }, ip, (code, reason) => { // close politely, but never wait the 30 s close handshake for a misbehaving client
      ws.close(code, reason);
      setTimeout(() => ws.terminate(), 1000).unref();
    });
    ws.isAlive = true;
    ws.on('pong', () => { ws.isAlive = true; });
    ws.on('message', (data) => {
      ws.isAlive = true;
      let msg;
      try { msg = JSON.parse(data.toString()); } catch { /* not JSON: answered as a bad message */ }
      try {
        hub.handle(client, msg);
      } catch (err) {
        log(`error: a message from #${client.id} failed: ${err?.stack ?? err}`);
      }
    });
    ws.on('close', () => hub.disconnect(client));
    ws.on('error', () => {}); // e.g. an oversize message: ws closes the socket itself
  });

  const keepalive = setInterval(() => {
    for (const ws of wss.clients) {
      if (!ws.isAlive) ws.terminate();
      else {
        ws.isAlive = false;
        ws.ping();
      }
    }
  }, pingMs);

  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen({ port, host }, () => {
      server.off('error', reject);
      resolve();
    });
  });

  return {
    port: server.address().port,
    hub,
    async close() {
      clearInterval(keepalive);
      hub.close();
      for (const ws of wss.clients) ws.terminate();
      wss.close();
      await new Promise((resolve) => {
        server.close(() => resolve());
        server.closeAllConnections();
      });
    },
  };
}

const isMain = (() => {
  try {
    return pathToFileURL(realpathSync(process.argv[1])).href === import.meta.url;
  } catch {
    return false;
  }
})();

if (isMain) {
  const { port, close } = await startServer();
  stamp(`RIM server listening on :${port} (game at /, WebSocket at /ws, lobbies at /api/lobbies, health at /healthz)`);
  const stop = () => close().then(() => process.exit(0));
  process.once('SIGTERM', stop);
  process.once('SIGINT', stop);
}
