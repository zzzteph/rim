// RIM multiplayer server: GET /healthz (or /health) and, at /ws, the WebSocket protocol of PROTOCOL.md (logic in lobby.js).
// `node index.js` listens on $PORT (default 8787); the tests import startServer().
import { realpathSync } from 'node:fs';
import { createServer } from 'node:http';
import { pathToFileURL } from 'node:url';
import { WebSocket, WebSocketServer } from 'ws';
import { Hub } from './lobby.js';

const MAX_MESSAGE = 8 * 1024; // bytes; a bigger message closes the socket (close code 1009)
const MAX_BACKLOG = 1 << 20; // bytes queued for a client that stopped reading: it is cut off

const envInt = (name, fallback) => {
  const v = Number.parseInt(process.env[name] ?? '', 10);
  return Number.isInteger(v) && v >= 0 ? v : fallback;
};
const stamp = (line) => console.log(`${new Date().toISOString()} ${line}`);

export async function startServer({
  port = envInt('PORT', 8787),
  host, // default: every interface
  countdownMs = envInt('COUNTDOWN_MS', 5000), // ready countdown (shortened by the tests)
  pingMs = 20_000, // keepalive: ping every client this often, close those that missed the previous pong
  log = stamp,
} = {}) {
  const hub = new Hub({ countdownMs, log });
  const wss = new WebSocketServer({ noServer: true, maxPayload: MAX_MESSAGE });
  const server = createServer((req, res) => {
    const health = (req.method === 'GET' || req.method === 'HEAD') && ['/healthz', '/health'].includes(req.url.split('?')[0]);
    res.writeHead(health ? 200 : 404, { 'content-type': 'text/plain' }).end(health ? 'ok' : 'not found');
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
    }, ip);
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
  stamp(`RIM lobby server listening on :${port} (WebSocket at /ws, health at /healthz)`);
  const stop = () => close().then(() => process.exit(0));
  process.once('SIGTERM', stop);
  process.once('SIGINT', stop);
}
