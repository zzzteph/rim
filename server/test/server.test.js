// End-to-end tests of the lobby server over real WebSockets, against PROTOCOL.md. Run with `npm test`.
import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { setTimeout as sleep } from 'node:timers/promises';
import WebSocket from 'ws';
import { startServer } from '../index.js';
import { CODE_CHARS, Hub } from '../lobby.js';

process.env.COUNTDOWN_MS = '300'; // read by startServer(): a short ready countdown for the tests
const COUNTDOWN_SECS = 1; // what the server announces for 300 ms (5 with the default 5000 ms)

let srv;
let url;
let versions = 0;
const freshVersion = () => `test-${++versions}`; // every test plays its own game version: its own lobby list

before(async () => {
  srv = await startServer({ port: 0, host: '127.0.0.1', log: () => {} });
  url = `ws://127.0.0.1:${srv.port}/ws`;
});
after(() => srv.close());

// A test player. Every message is queued; next(t) takes the first queued one of type t (the others stay queued).
class Client {
  static async open(name, version, { url: at = url, ...options } = {}) {
    const c = new Client(new WebSocket(at, options));
    await new Promise((resolve, reject) => {
      c.ws.once('open', resolve);
      c.ws.once('error', reject);
    });
    if (name !== undefined) {
      c.send({ t: 'hello', name, version });
      const welcome = await c.next('welcome');
      c.id = welcome.id;
      c.name = welcome.name;
    }
    return c;
  }

  constructor(ws) {
    this.ws = ws;
    this.inbox = []; // not taken yet
    this.seen = []; // everything, in arrival order
    this.waiting = [];
    this.closed = new Promise((resolve) => ws.once('close', (code) => resolve(code)));
    ws.on('message', (data) => {
      const msg = JSON.parse(data.toString());
      this.inbox.push(msg);
      this.seen.push(msg);
      this.deliver();
    });
    ws.on('error', () => {});
  }

  send(msg) {
    this.ws.send(typeof msg === 'string' ? msg : JSON.stringify(msg));
  }

  deliver() {
    this.waiting = this.waiting.filter((w) => {
      const i = this.inbox.findIndex(w.match);
      if (i < 0) return true;
      clearTimeout(w.timer);
      w.resolve(this.inbox.splice(i, 1)[0]);
      return false;
    });
  }

  next(t, where = () => true, ms = 2000) {
    return new Promise((resolve, reject) => {
      const w = { match: (m) => m.t === t && where(m), resolve };
      w.timer = setTimeout(() => {
        this.waiting = this.waiting.filter((x) => x !== w);
        reject(new Error(`${this.name ?? 'client'}: no "${t}" within ${ms} ms; queued: ${JSON.stringify(this.inbox)}`));
      }, ms);
      this.waiting.push(w);
      this.deliver();
    });
  }

  // Asserts that no message of type t (matching `where`) arrives within `ms`.
  async none(t, where = () => true, ms = 150) {
    await sleep(ms);
    assert.deepEqual(this.inbox.filter((m) => m.t === t && where(m)), [], `${this.name}: unexpected "${t}"`);
  }

  clear() {
    this.inbox.length = 0;
  }

  drop() {
    this.ws.terminate(); // a disconnect without "leave"
  }
}

async function until(check, ms = 2000) {
  for (const end = Date.now() + ms; !check(); await sleep(10)) {
    if (Date.now() > end) throw new Error('condition not reached in time');
  }
}

// Players P1 (the host) … Pn in a fresh lobby, with everything they received so far cleared.
async function lobbyOf(n, create = {}) {
  const version = freshVersion();
  const players = [await Client.open('P1', version)];
  players[0].send({ t: 'create', public: true, max: 3, size: 'medium', ...create });
  const { lobby } = await players[0].next('lobby');
  for (let i = 2; i <= n; i++) {
    const p = await Client.open(`P${i}`, version);
    p.send({ t: 'join', code: lobby.code });
    players.push(p);
    for (const q of players) await q.next('chat', (m) => m.text === `P${i} joined`); // a join's last message
  }
  for (const p of players) p.clear();
  return { players, lobby, version };
}

// A running match of n players (factions 1 … n), with everything before it cleared.
async function matchOf(n) {
  const { players, lobby, version } = await lobbyOf(n);
  for (const p of players) p.send({ t: 'ready', ready: true });
  const starts = await Promise.all(players.map((p) => p.next('start')));
  for (const p of players) p.clear();
  return { players, starts, lobby, version };
}

const readyAll = async (players) => {
  for (const p of players) p.send({ t: 'ready', ready: true });
  for (const p of players) await p.next('countdown', (m) => m.secs > 0);
  for (const p of players) p.clear();
};

// ---- HTTP ----
test('GET /health answers 200 ok, other paths 404, and WebSockets upgrade only at /ws', async () => {
  const base = `http://127.0.0.1:${srv.port}`;
  const health = await fetch(`${base}/health`);
  assert.equal(health.status, 200);
  assert.equal(await health.text(), 'ok');
  const healthz = await fetch(`${base}/healthz`);   // the path the VPS check and the Docker HEALTHCHECK use
  assert.equal(healthz.status, 200);
  assert.equal(await healthz.text(), 'ok');
  const other = await fetch(`${base}/index.html`);
  assert.equal(other.status, 404);
  await other.text();
  await assert.rejects(Client.open(undefined, undefined, { url: `ws://127.0.0.1:${srv.port}/elsewhere` }), /404/);
});

// ---- connection ----
test('hello → welcome with a new id and the cleaned name; nothing else before hello', async () => {
  const anon = await Client.open();
  anon.send({ t: 'list' });
  assert.match((await anon.next('error')).msg, /hello/i);
  anon.send({ t: 'hello', name: '  Steph  ', version: '0.1.5' });
  const welcome = await anon.next('welcome');
  assert.deepEqual(welcome, { t: 'welcome', id: welcome.id, name: 'Steph' });
  assert.ok(Number.isInteger(welcome.id) && welcome.id > 0);
  anon.send('this is not JSON');
  assert.deepEqual(await anon.next('error'), { t: 'error', msg: 'Bad message' });

  const neo = await Client.open('Neo', '0.1.5');
  assert.notEqual(neo.id, welcome.id);
  assert.equal((await Client.open('A very long name indeed', '0.1.5')).name, 'A very long name'); // cut to 16
  assert.equal((await Client.open('   ', '0.1.5')).name, 'Player');
});

test('name → welcome again; in a lobby also a lobby update and a system chat line', async () => {
  const solo = await Client.open('Solo', freshVersion());
  solo.send({ t: 'name', name: ' Trinity ' });
  assert.deepEqual(await solo.next('welcome'), { t: 'welcome', id: solo.id, name: 'Trinity' });
  await solo.none('lobby');

  const { players: [a, b] } = await lobbyOf(2);
  b.send({ t: 'name', name: 'Neo' });
  assert.equal((await b.next('welcome')).name, 'Neo');
  for (const p of [a, b]) {
    assert.deepEqual((await p.next('lobby')).lobby.players.map((x) => x.name), ['P1', 'Neo']);
    assert.deepEqual(await p.next('chat'), { t: 'chat', system: true, text: 'P2 is now Neo' });
  }
  a.send({ t: 'name', name: 'Morpheus' }); // the host: the lobby carries their name
  assert.equal((await b.next('lobby')).lobby.name, "Morpheus's lobby");
});

// ---- lobbies ----
test('create answers with the lobby; list shows public open lobbies of the same version only', async () => {
  const version = freshVersion();
  const steph = await Client.open('Steph', version);
  steph.send({ t: 'create', public: true, max: 3, size: 'medium' });
  const { lobby } = await steph.next('lobby');
  assert.match(lobby.code, new RegExp(`^[${CODE_CHARS}]{5}$`));
  assert.deepEqual(lobby, {
    id: lobby.id, code: lobby.code, name: "Steph's lobby", public: true, host: steph.id, max: 3, size: 'medium',
    state: 'open', players: [{ id: steph.id, name: 'Steph', ready: false }],
  });

  const hidden = await Client.open('Hidden', version);
  hidden.send({ t: 'create', public: false, max: 2, size: 'small' });
  const secret = (await hidden.next('lobby')).lobby;
  assert.equal(secret.public, false);
  assert.notEqual(secret.code, lobby.code);

  const oldVersion = freshVersion();
  const old = await Client.open('Old', oldVersion);
  old.send({ t: 'create', public: true, max: 2, size: 'big' });
  const oldLobby = (await old.next('lobby')).lobby;

  const viewer = await Client.open('Viewer', version);
  viewer.send({ t: 'list' });
  assert.deepEqual(await viewer.next('lobbies'), {
    t: 'lobbies', lobbies: [{ id: lobby.id, name: "Steph's lobby", players: 1, max: 3, size: 'medium' }],
  });
  const oldViewer = await Client.open('Viewer', oldVersion);
  oldViewer.send({ t: 'list' });
  assert.deepEqual((await oldViewer.next('lobbies')).lobbies, [
    { id: oldLobby.id, name: "Old's lobby", players: 1, max: 2, size: 'big' },
  ]);

  viewer.send({ t: 'create', max: 4 });
  assert.match((await viewer.next('error')).msg, /2 or 3/);
  viewer.send({ t: 'create', size: 'huge' });
  assert.match((await viewer.next('error')).msg, /small, medium or big/);
  steph.send({ t: 'create', public: true, max: 3, size: 'medium' });
  assert.match((await steph.next('error')).msg, /already in a lobby/);
});

test('join by id (public lobbies) and by code (any lobby); the lobby goes to every member', async () => {
  const version = freshVersion();
  const host = await Client.open('Steph', version);
  host.send({ t: 'create', public: true, max: 3, size: 'medium' });
  const { lobby } = await host.next('lobby');
  const neo = await Client.open('Neo', version);
  neo.send({ t: 'join', id: lobby.id });
  for (const p of [host, neo]) {
    const now = (await p.next('lobby')).lobby;
    assert.equal(now.id, lobby.id);
    assert.equal(now.host, host.id);
    assert.deepEqual(now.players, [{ id: host.id, name: 'Steph', ready: false }, { id: neo.id, name: 'Neo', ready: false }]);
    assert.deepEqual(await p.next('chat'), { t: 'chat', system: true, text: 'Neo joined' });
  }

  const owner = await Client.open('Owner', version);
  owner.send({ t: 'create', public: false, max: 2, size: 'small' });
  const secret = (await owner.next('lobby')).lobby;
  const guest = await Client.open('Guest', version);
  guest.send({ t: 'join', id: secret.id }); // private: not by id
  assert.ok((await guest.next('error')).msg);
  guest.send({ t: 'join', code: 'ZZZZZ' });
  assert.match((await guest.next('error')).msg, /code/);
  guest.send({ t: 'join', code: ` ${secret.code.toLowerCase()} ` });
  assert.equal((await guest.next('lobby')).lobby.id, secret.id);
  assert.deepEqual((await owner.next('lobby')).lobby.players.map((p) => p.name), ['Owner', 'Guest']);
});

test('joining a full lobby, a lobby of another version or a running match is refused', async () => {
  const { lobby: full, version } = await lobbyOf(2, { max: 2 });
  const late = await Client.open('Late', version);
  late.send({ t: 'join', id: full.id });
  assert.deepEqual(await late.next('error'), { t: 'error', msg: 'Lobby is full' });
  late.send({ t: 'join', code: full.code });
  assert.deepEqual(await late.next('error'), { t: 'error', msg: 'Lobby is full' });

  const { lobby: open } = await lobbyOf(1);
  const stranger = await Client.open('Stranger', 'another-version');
  stranger.send({ t: 'join', id: open.id });
  assert.match((await stranger.next('error')).msg, /version/);
  stranger.send({ t: 'join', code: open.code });
  assert.match((await stranger.next('error')).msg, /version/);

  const { lobby: running, version: v2 } = await matchOf(2); // 2 of 3 seats taken
  const spectator = await Client.open('Spectator', v2);
  spectator.send({ t: 'join', code: running.code });
  assert.match((await spectator.next('error')).msg, /started/);
});

test('settings: host only, max never below the player count, every ready flag cleared', async () => {
  const { players: [host, b, c], version } = await lobbyOf(3);
  b.send({ t: 'settings', size: 'big' });
  assert.match((await b.next('error')).msg, /host/);
  host.send({ t: 'settings', max: 2 });
  assert.match((await host.next('error')).msg, /already 3 players/);
  host.send({ t: 'settings', size: 'tiny' });
  assert.match((await host.next('error')).msg, /small, medium or big/);

  b.send({ t: 'ready', ready: true });
  c.send({ t: 'ready', ready: true });
  await host.next('lobby', (m) => m.lobby.players.filter((p) => p.ready).length === 2);
  host.send({ t: 'settings', size: 'big', public: false });
  for (const p of [host, b, c]) {
    const { lobby } = await p.next('lobby', (m) => m.lobby.size === 'big');
    assert.equal(lobby.public, false);
    assert.equal(lobby.max, 3);
    assert.deepEqual(lobby.players.map((x) => x.ready), [false, false, false]);
  }
  const viewer = await Client.open('Viewer', version);
  viewer.send({ t: 'list' });
  assert.deepEqual((await viewer.next('lobbies')).lobbies, []); // private now

  c.send({ t: 'leave' });
  await c.next('left');
  host.send({ t: 'settings', max: 2 });
  assert.deepEqual((await b.next('lobby', (m) => m.lobby.max === 2)).lobby.players.length, 2);
});

test('chat: to every member with name and id, system lines, 1–200 characters, at most 5 per 5 s', async () => {
  const { players: [a, b] } = await lobbyOf(2);
  a.send({ t: 'chat', text: '  gl hf ' });
  for (const p of [a, b]) assert.deepEqual(await p.next('chat'), { t: 'chat', name: 'P1', from: a.id, text: 'gl hf' });
  a.send({ t: 'chat', text: 'x'.repeat(201) });
  assert.match((await a.next('error')).msg, /1 to 200/);
  a.send({ t: 'chat', text: '   ' });
  assert.match((await a.next('error')).msg, /1 to 200/);
  b.send({ t: 'chat', text: 'y'.repeat(200) });
  assert.equal((await a.next('chat', (m) => m.from === b.id)).text.length, 200);

  for (let i = 2; i <= 6; i++) a.send({ t: 'chat', text: `message ${i}` }); // the 6th within 5 s is refused
  for (let i = 2; i <= 5; i++) assert.equal((await b.next('chat', (m) => m.from === a.id)).text, `message ${i}`);
  assert.match((await a.next('error')).msg, /Slow down/);
  await b.none('chat', (m) => m.text === 'message 6');

  b.send({ t: 'leave' });
  assert.deepEqual(await a.next('chat', (m) => m.system), { t: 'chat', system: true, text: 'P2 left' });
  const lone = await Client.open('Lone', freshVersion());
  lone.send({ t: 'chat', text: 'anyone?' });
  assert.match((await lone.next('error')).msg, /not in a lobby/);
});

// ---- ready → countdown → start ----
test('everyone ready → countdown → start: factions in player order, your faction, seed in 1…900000', async () => {
  assert.equal(new Hub().countdownSecs, 5); // what production announces (COUNTDOWN_MS unset)
  const { players: [a, b], version } = await lobbyOf(2, { size: 'big' });
  a.send({ t: 'ready', ready: true });
  for (const p of [a, b]) {
    const { lobby } = await p.next('lobby');
    assert.deepEqual(lobby.players.map((x) => x.ready), [true, false]);
    assert.equal(lobby.state, 'open');
  }
  await a.none('countdown', undefined, 50); // one ready player of two: no countdown

  b.send({ t: 'ready', ready: true });
  for (const p of [a, b]) {
    assert.equal((await p.next('lobby')).lobby.state, 'countdown');
    assert.deepEqual(await p.next('countdown'), { t: 'countdown', secs: COUNTDOWN_SECS });
  }
  const [sa, sb] = await Promise.all([a.next('start'), b.next('start')]);
  const players = [{ id: a.id, name: 'P1', faction: 1 }, { id: b.id, name: 'P2', faction: 2 }];
  assert.deepEqual(sa, { t: 'start', seed: sa.seed, size: 'big', turn_steps: 3, delay: 2, you: 1, players });
  assert.deepEqual(sb, { ...sa, you: 2 });
  assert.ok(Number.isInteger(sa.seed) && sa.seed >= 1 && sa.seed <= 900000);

  const viewer = await Client.open('Viewer', version);
  viewer.send({ t: 'list' });
  assert.deepEqual((await viewer.next('lobbies')).lobbies, []); // playing: not listed
  a.send({ t: 'ready', ready: false });
  assert.match((await a.next('error')).msg, /started/);

  const { starts } = await matchOf(3);
  assert.deepEqual(starts.map((s) => s.you), [1, 2, 3]);
  assert.deepEqual(starts[0].players.map((p) => [p.name, p.faction]), [['P1', 1], ['P2', 2], ['P3', 3]]);
  assert.equal(new Set(starts.map((s) => s.seed)).size, 1); // one seed for everybody
});

test('the countdown stops (secs 0) when someone un-readies', async () => {
  const { players: [a, b] } = await lobbyOf(2);
  await readyAll([a, b]);
  a.send({ t: 'ready', ready: false });
  for (const p of [a, b]) {
    const { lobby } = await p.next('lobby');
    assert.equal(lobby.state, 'open');
    assert.deepEqual(lobby.players.map((x) => x.ready), [false, true]);
    assert.deepEqual(await p.next('countdown'), { t: 'countdown', secs: 0 });
  }
  await a.none('start', undefined, 450); // longer than the countdown
});

test('the countdown stops (secs 0) when someone joins', async () => {
  const { players: [a, b], lobby, version } = await lobbyOf(2); // max 3
  await readyAll([a, b]);
  const c = await Client.open('P3', version);
  c.send({ t: 'join', code: lobby.code });
  for (const p of [a, b, c]) {
    const now = (await p.next('lobby')).lobby;
    assert.equal(now.state, 'open');
    assert.equal(now.players.length, 3);
    assert.deepEqual(await p.next('countdown'), { t: 'countdown', secs: 0 });
  }
  await a.none('start', undefined, 450);
});

test('a rename or a leave stops the countdown too; it starts over while everyone left is ready', async () => {
  const { players: [a, b, c] } = await lobbyOf(3);
  await readyAll([a, b, c]);
  c.send({ t: 'name', name: 'Neo' });
  for (const p of [a, b, c]) {
    assert.equal((await p.next('lobby')).lobby.state, 'countdown');
    assert.deepEqual(await p.next('countdown'), { t: 'countdown', secs: 0 });
    assert.deepEqual(await p.next('countdown'), { t: 'countdown', secs: COUNTDOWN_SECS });
    p.clear();
  }
  c.send({ t: 'leave' }); // two ready players remain
  for (const p of [a, b]) {
    const { lobby } = await p.next('lobby');
    assert.deepEqual([lobby.state, lobby.players.length], ['countdown', 2]);
    assert.deepEqual(await p.next('countdown'), { t: 'countdown', secs: 0 });
    assert.deepEqual(await p.next('countdown'), { t: 'countdown', secs: COUNTDOWN_SECS });
    p.clear();
  }
  b.send({ t: 'leave' }); // alone: no countdown
  assert.equal((await a.next('lobby')).lobby.state, 'open');
  assert.deepEqual(await a.next('countdown'), { t: 'countdown', secs: 0 });
  await a.none('start', undefined, 450);
});

// ---- match ----
test('turns go to every member, sender included, with its faction; stale turns and >64 commands are dropped', async () => {
  const { players: [a, b] } = await matchOf(2);
  const cmds = [['wire', [12, 13], 40], ['launch', 40, 'attack']];
  a.send({ t: 'turn', turn: 2, cmds });
  for (const p of [a, b]) assert.deepEqual(await p.next('turn'), { t: 'turn', turn: 2, from: 1, cmds });
  b.send({ t: 'turn', turn: 2, cmds: [] });
  for (const p of [a, b]) assert.deepEqual(await p.next('turn'), { t: 'turn', turn: 2, from: 2, cmds: [] });

  a.send({ t: 'turn', turn: 2, cmds: [['halt', 1]] }); // the same turn again
  a.send({ t: 'turn', turn: 1, cmds: [] }); // older; and turns below delay are never sent
  a.send({ t: 'turn', turn: 3, cmds: Array.from({ length: 65 }, () => ['halt', 40]) });
  assert.match((await a.next('error')).msg, /64/);
  a.send({ t: 'turn', turn: 3, cmds: Array.from({ length: 64 }, () => ['halt', 40]) });
  const third = await b.next('turn');
  assert.deepEqual([third.turn, third.from, third.cmds.length], [3, 1, 64]);
  a.send({ t: 'turn', turn: 5, cmds: [] }); // increasing is enough
  assert.equal((await b.next('turn')).turn, 5);
  await b.none('turn'); // nothing else was relayed

  const outsider = await Client.open('Outsider', freshVersion());
  outsider.send({ t: 'turn', turn: 2, cmds: [] });
  await outsider.none('turn'); // not in a match: dropped
});

test('a disconnect in a match → drop with from_turn = last relayed turn + 1, after all its turns', async () => {
  const { players: [a, b] } = await matchOf(2);
  for (const turn of [2, 3, 4]) a.send({ t: 'turn', turn, cmds: [] });
  await a.next('turn', (m) => m.turn === 4); // the server has relayed all three
  a.drop();
  assert.deepEqual(await b.next('drop'), { t: 'drop', faction: 1, from_turn: 5 });
  assert.deepEqual(b.seen.filter((m) => m.t === 'turn' || m.t === 'drop').map((m) => m.turn ?? m.t), [2, 3, 4, 'drop']);
  assert.deepEqual(await b.next('chat'), { t: 'chat', system: true, text: 'P1 left' });
});

test('a faction that never sent a turn drops from turn delay; leave drops too; the match goes with its last member', async () => {
  const { players: [a, b, c], lobby } = await matchOf(3);
  c.drop(); // never sent a turn
  for (const p of [a, b]) assert.deepEqual(await p.next('drop'), { t: 'drop', faction: 3, from_turn: 2 });
  b.send({ t: 'turn', turn: 2, cmds: [] });
  await a.next('turn');
  b.send({ t: 'leave' });
  assert.deepEqual(await b.next('left'), { t: 'left' });
  assert.deepEqual(await a.next('drop'), { t: 'drop', faction: 2, from_turn: 3 });
  a.send({ t: 'turn', turn: 2, cmds: [] }); // the match goes on for whoever is left
  assert.deepEqual(await a.next('turn'), { t: 'turn', turn: 2, from: 1, cmds: [] });
  assert.ok(srv.hub.lobbies.has(lobby.id));
  a.send({ t: 'leave' });
  await a.next('left');
  assert.ok(!srv.hub.lobbies.has(lobby.id));
});

test('hashes: equal → nothing; different → desync to every member', async () => {
  const { players: [a, b] } = await matchOf(2);
  a.send({ t: 'hash', turn: 30, h: '9e107d9d372bb6826bd81d3542a419d6' });
  b.send({ t: 'hash', turn: 30, h: '9e107d9d372bb6826bd81d3542a419d6' });
  a.send({ t: 'hash', turn: 60, h: 'aaaa' });
  await a.none('desync'); // b has not reported 60 yet
  b.send({ t: 'hash', turn: 60, h: 'bbbb' });
  for (const p of [a, b]) assert.deepEqual(await p.next('desync'), { t: 'desync', turn: 60 }); // not 30
  await a.none('desync');
});

test('a drop completes a hash turn: the factions still in the match are compared', async () => {
  const { players: [a, b, c] } = await matchOf(3);
  a.send({ t: 'hash', turn: 30, h: 'aaaa' });
  b.send({ t: 'hash', turn: 30, h: 'bbbb' });
  await a.none('desync'); // c has not reported
  c.drop();
  for (const p of [a, b]) {
    assert.equal((await p.next('drop')).faction, 3);
    assert.deepEqual(await p.next('desync'), { t: 'desync', turn: 30 });
  }

  const { players: [x, y, z] } = await matchOf(3);
  x.send({ t: 'hash', turn: 30, h: 'same' });
  y.send({ t: 'hash', turn: 30, h: 'same' });
  z.send({ t: 'leave' });
  await x.next('drop');
  await x.none('desync');
});

// ---- host transfer, deletion, limits ----
test('when the host leaves, the next player becomes host (listed first, lobby renamed)', async () => {
  const { players: [a, b, c] } = await lobbyOf(3);
  a.send({ t: 'leave' });
  assert.deepEqual(await a.next('left'), { t: 'left' });
  for (const p of [b, c]) {
    const { lobby } = await p.next('lobby');
    assert.equal(lobby.host, b.id);
    assert.equal(lobby.name, "P2's lobby");
    assert.deepEqual(lobby.players.map((x) => x.id), [b.id, c.id]);
    assert.deepEqual(await p.next('chat'), { t: 'chat', system: true, text: 'P1 left' });
  }
  c.send({ t: 'settings', size: 'small' });
  assert.match((await c.next('error')).msg, /host/);
  b.send({ t: 'settings', size: 'small' });
  assert.equal((await c.next('lobby')).lobby.size, 'small');
});

test('an empty lobby is deleted (leave or disconnect)', async () => {
  const { players: [a], lobby, version } = await lobbyOf(1);
  const viewer = await Client.open('Viewer', version);
  viewer.send({ t: 'list' });
  assert.equal((await viewer.next('lobbies')).lobbies.length, 1);
  a.send({ t: 'leave' });
  await a.next('left');
  viewer.send({ t: 'list' });
  assert.deepEqual((await viewer.next('lobbies')).lobbies, []);
  viewer.send({ t: 'join', code: lobby.code });
  assert.match((await viewer.next('error')).msg, /code/);
  assert.ok(!srv.hub.lobbies.has(lobby.id));

  const { players: [d], lobby: other } = await lobbyOf(1);
  d.drop();
  await until(() => !srv.hub.lobbies.has(other.id));
});

test('a message over 8 KB closes the socket; exactly 8 KB is fine', async () => {
  const c = await Client.open('Big', freshVersion());
  const padded = (bytes) => {
    const bare = JSON.stringify({ t: 'list', pad: '' }).length;
    return JSON.stringify({ t: 'list', pad: 'x'.repeat(bytes - bare) });
  };
  assert.equal(Buffer.byteLength(padded(8192)), 8192);
  c.send(padded(8192));
  await c.next('lobbies');
  c.send(padded(8193));
  assert.equal(await c.closed, 1009); // "message too big"
});

test('keepalive: a client that stops answering pings is closed', async () => {
  const quick = await startServer({ port: 0, host: '127.0.0.1', pingMs: 50, log: () => {} });
  try {
    const at = `ws://127.0.0.1:${quick.port}/ws`;
    const dead = await Client.open('Dead', 'v', { url: at, autoPong: false });
    const alive = await Client.open('Alive', 'v', { url: at });
    const code = await Promise.race([dead.closed, sleep(2000).then(() => 'still open')]);
    assert.equal(code, 1006); // cut off without a close handshake
    assert.equal(alive.ws.readyState, WebSocket.OPEN);
  } finally {
    await quick.close();
  }
});
