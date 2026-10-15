// RIM lobbies, ready countdown and lockstep turn relay: everything in PROTOCOL.md except the transport, which
// index.js wires to WebSockets. A client is the object Hub.connect() returns; its `send` takes one JSON text.
import { randomInt } from 'node:crypto';

export const CODE_CHARS = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // lobby codes: no look-alikes (0/O, 1/I/L)
export const SIZES = ['small', 'medium', 'big'];
export const TURN_STEPS = 3; // simulation steps per turn (3 × 1/30 s)
export const DELAY = 2; // commands sent while simulating turn T are for turn T + DELAY
export const MAX_CMDS = 64; // commands per turn
const NAME_MAX = 16;
const CHAT_MAX = 200;
const CHAT_BURST = 5; // chat messages per player ...
const CHAT_WINDOW_MS = 5000; // ... within this window
const HASH_MAX = 128; // longest state hash accepted
const HASH_PENDING = 128; // hash turns a match remembers while waiting for every faction's report
const LOOKAHEAD = DELAY + 2; // a turn may lead the slowest other member's last turn by this much (lockstep allows DELAY)
const MSG_BURST = 40; // messages (turns aside) per connection ...
const MSG_WINDOW_MS = 10_000; // ... within this window; more closes the connection
const JOIN_FAILS = 10; // failed joins (wrong code, gone lobby) per connection ...
const JOIN_WINDOW_MS = 60_000; // ... within this window; then even a right code waits (no guessing private codes)

// Trimmed text with control characters (newlines, tabs, …) turned into spaces; '' for anything but a string.
const clean = (raw) => (typeof raw === 'string' ? raw.replace(/\p{Cc}+/gu, ' ').trim() : '');
const chars = (s) => [...s]; // characters (code points), not UTF-16 units

export const cleanName = (raw) => chars(clean(raw)).slice(0, NAME_MAX).join('').trim() || 'Player';

const lobbyName = (l) => `${l.players[0].name}'s lobby`; // the host is always players[0]

// The lobby settings in `msg` (any subset of public/max/size) applied over `base`; a string is an error message.
function readSettings(msg, base, players) {
  const s = { public: base.public, max: base.max, size: base.size };
  if (msg.public != null) {
    if (typeof msg.public !== 'boolean') return 'public must be true or false';
    s.public = msg.public;
  }
  if (msg.max != null) {
    if (msg.max !== 2 && msg.max !== 3) return 'A lobby holds 2 or 3 players';
    s.max = msg.max;
  }
  if (msg.size != null) {
    if (!SIZES.includes(msg.size)) return 'The map size is small, medium or big';
    s.size = msg.size;
  }
  if (s.max < players) return `There are already ${players} players in the lobby`;
  return s;
}

export class Hub {
  constructor({ countdownMs = 5000, stallMs = 30_000, log = () => {} } = {}) {
    this.countdownMs = countdownMs;
    this.countdownSecs = Math.max(1, Math.ceil(countdownMs / 1000)); // 5 with the default 5000 ms
    this.stallMs = stallMs; // a member others wait for that sends no turn this long is removed (see checkStalls)
    this.log = log;
    this.lobbies = new Map(); // id -> lobby (open, countdown or playing)
    this.codes = new Map(); // code -> lobby
    this.nextPlayer = 1;
    this.nextLobby = 1;
    this.sweep = setInterval(() => this.checkStalls(), Math.max(50, Math.min(2000, stallMs / 4)));
    this.sweep.unref?.();
  }

  // `send` takes one JSON text; `close(code, reason)` ends the connection (a misbehaving client is cut off).
  connect(send, ip = '?', close = () => {}) {
    return { id: 0, name: '', version: '', ip, send, close, lobby: null, ready: false, faction: 0, lastTurn: 0, lastTurnAt: 0, chats: [], msgs: [], joinFails: [] };
  }

  disconnect(c) {
    if (!c.id) return; // never said hello
    if (c.lobby) this.remove(c);
    this.log(`disconnect #${c.id} "${c.name}"`);
  }

  close() {
    clearInterval(this.sweep);
    for (const l of this.lobbies.values()) clearTimeout(l.timer);
  }

  handle(c, msg) {
    if (msg?.t !== 'turn') { // turns are bounded by the lockstep itself (see turn); everything else by rate
      const now = Date.now();
      c.msgs = c.msgs.filter((t) => now - t < MSG_WINDOW_MS);
      if (c.msgs.length >= MSG_BURST) return this.kick(c, 'Too many messages');
      c.msgs.push(now);
    }
    if (msg === null || typeof msg !== 'object' || Array.isArray(msg) || typeof msg.t !== 'string') {
      return this.error(c, 'Bad message');
    }
    if (!c.id) return msg.t === 'hello' ? this.hello(c, msg) : this.error(c, 'Say hello first');
    switch (msg.t) {
      case 'hello': return this.error(c, 'Already said hello');
      case 'name': return this.rename(c, msg);
      case 'list': return this.list(c);
      case 'create': return this.create(c, msg);
      case 'join': return this.join(c, msg);
      case 'leave':
        if (c.lobby) this.remove(c);
        return this.send(c, { t: 'left' });
      case 'settings': return this.settings(c, msg);
      case 'ready': return this.ready(c, msg);
      case 'chat': return this.chat(c, msg);
      case 'turn': return this.turn(c, msg);
      case 'hash': return this.hash(c, msg);
      default: return this.error(c, 'Unknown message');
    }
  }

  // ---- connection ----
  hello(c, msg) {
    c.id = this.nextPlayer++;
    c.name = cleanName(msg.name);
    c.version = clean(String(msg.version ?? '')).slice(0, 32);
    this.send(c, { t: 'welcome', id: c.id, name: c.name });
    this.log(`connect #${c.id} "${c.name}" v${c.version} from ${c.ip}`);
  }

  rename(c, msg) {
    const old = c.name;
    c.name = cleanName(msg.name);
    this.send(c, { t: 'welcome', id: c.id, name: c.name });
    if (!c.lobby) return;
    const changed = c.name !== old;
    this.sync(c.lobby, changed); // a rename stops a running countdown
    if (changed) this.system(c.lobby, `${old} is now ${c.name}`);
  }

  // ---- lobbies ----
  list(c) {
    const lobbies = [];
    for (const l of this.lobbies.values()) {
      if (l.public && l.state !== 'playing' && l.version === c.version) {
        lobbies.push({ id: l.id, name: lobbyName(l), players: l.players.length, max: l.max, size: l.size });
      }
    }
    this.send(c, { t: 'lobbies', lobbies });
  }

  create(c, msg) {
    if (c.lobby) return this.error(c, 'You are already in a lobby');
    const s = readSettings(msg, { public: true, max: 3, size: 'medium' }, 1);
    if (typeof s === 'string') return this.error(c, s);
    let code;
    do code = Array.from({ length: 5 }, () => CODE_CHARS[randomInt(CODE_CHARS.length)]).join('');
    while (this.codes.has(code));
    const l = { id: this.nextLobby++, code, version: c.version, ...s, state: 'open', players: [], timer: null, hashes: new Map() };
    this.lobbies.set(l.id, l);
    this.codes.set(code, l);
    this.enter(c, l);
    this.log(`lobby #${l.id} ${code} created by #${c.id} "${c.name}" (${l.public ? 'public' : 'private'}, max ${l.max}, ${l.size}, v${l.version})`);
    this.sync(l);
  }

  join(c, msg) {
    if (c.lobby) return this.error(c, 'You are already in a lobby');
    const now = Date.now();
    c.joinFails = c.joinFails.filter((t) => now - t < JOIN_WINDOW_MS);
    if (c.joinFails.length >= JOIN_FAILS) return this.error(c, 'Too many tries: wait a minute');
    const code = typeof msg.code === 'string' ? msg.code.trim().toUpperCase() : '';
    let l = code ? this.codes.get(code) : this.lobbies.get(msg.id);
    if (l && !code && !l.public) l = undefined; // a private lobby is joined by code only
    if (!l) {
      c.joinFails.push(now);
      return this.error(c, code ? 'No lobby has that code' : 'That lobby is gone');
    }
    if (l.version !== c.version) return this.error(c, `That lobby runs game version ${l.version || '?'} (you have ${c.version || '?'})`);
    if (l.state === 'playing') return this.error(c, 'That match has already started');
    if (l.players.length >= l.max) return this.error(c, 'Lobby is full');
    this.enter(c, l);
    this.sync(l, true);
    this.system(l, `${c.name} joined`);
  }

  settings(c, msg) {
    const l = c.lobby;
    if (!l) return this.error(c, 'You are not in a lobby');
    if (l.players[0] !== c) return this.error(c, 'Only the host can change the settings');
    if (l.state === 'playing') return this.error(c, 'The match has already started');
    const s = readSettings(msg, l, l.players.length);
    if (typeof s === 'string') return this.error(c, s);
    Object.assign(l, s);
    for (const p of l.players) p.ready = false;
    this.sync(l, true);
  }

  ready(c, msg) {
    const l = c.lobby;
    if (!l) return this.error(c, 'You are not in a lobby');
    if (l.state === 'playing') return this.error(c, 'The match has already started');
    if (typeof msg.ready !== 'boolean') return this.error(c, 'ready must be true or false');
    c.ready = msg.ready;
    this.sync(l);
  }

  chat(c, msg) {
    const l = c.lobby;
    if (!l) return this.error(c, 'You are not in a lobby');
    const text = clean(msg.text);
    if (!text || chars(text).length > CHAT_MAX) return this.error(c, `Chat messages are 1 to ${CHAT_MAX} characters`);
    const now = Date.now();
    c.chats = c.chats.filter((t) => now - t < CHAT_WINDOW_MS);
    if (c.chats.length >= CHAT_BURST) return this.error(c, `Slow down: at most ${CHAT_BURST} chat messages per ${CHAT_WINDOW_MS / 1000} s`);
    c.chats.push(now);
    this.broadcast(l, { t: 'chat', name: c.name, from: c.id, text });
  }

  enter(c, l) {
    Object.assign(c, { lobby: l, ready: false, faction: 0, lastTurn: 0 });
    l.players.push(c);
  }

  // `c` leaves its lobby or match (a leave message or a disconnect).
  remove(c) {
    const l = c.lobby;
    l.players.splice(l.players.indexOf(c), 1);
    c.lobby = null;
    c.ready = false;
    if (!l.players.length) { // the last one out: the lobby or match is gone
      clearTimeout(l.timer);
      this.lobbies.delete(l.id);
      this.codes.delete(l.code);
      return;
    }
    if (l.state === 'playing') {
      // Every turn of this faction below from_turn went out before this message; from then on nobody waits for it.
      this.broadcast(l, { t: 'drop', faction: c.faction, from_turn: c.lastTurn + 1 });
      for (const turn of [...l.hashes.keys()]) this.checkHash(l, turn); // fewer factions left to report
    } else {
      this.sync(l, true); // the next player is the host now if the host left
    }
    this.system(l, `${c.name} left`);
  }

  // ---- ready → countdown → start ----
  // Applies the countdown rule (it runs exactly while the lobby is not playing, has 2+ players and all are ready),
  // then sends the lobby to every member. `restart`: this change (join, leave, rename, settings) stops a running
  // countdown even if the rule still holds afterwards, in which case a fresh countdown starts at once.
  sync(l, restart = false) {
    const news = [];
    if (l.state !== 'playing') {
      const go = l.players.length >= 2 && l.players.every((p) => p.ready);
      if (l.state === 'countdown' && (restart || !go)) {
        clearTimeout(l.timer);
        l.timer = null;
        l.state = 'open';
        news.push({ t: 'countdown', secs: 0 });
      }
      if (l.state === 'open' && go) {
        l.state = 'countdown';
        l.timer = setTimeout(() => this.start(l), this.countdownMs);
        news.push({ t: 'countdown', secs: this.countdownSecs });
      }
    }
    this.broadcast(l, { t: 'lobby', lobby: this.view(l) });
    for (const m of news) this.broadcast(l, m);
  }

  start(l) {
    l.timer = null;
    if (l.state !== 'countdown' || this.lobbies.get(l.id) !== l) return;
    l.state = 'playing';
    const seed = randomInt(1, 900001);
    const now = Date.now();
    const players = l.players.map((p, i) => {
      p.faction = i + 1;
      p.lastTurn = DELAY - 1; // turns 0 … DELAY-1 are empty for everybody and never sent
      p.lastTurnAt = now;
      return { id: p.id, name: p.name, faction: p.faction };
    });
    for (const p of l.players) {
      this.send(p, { t: 'start', seed, size: l.size, turn_steps: TURN_STEPS, delay: DELAY, you: p.faction, players });
    }
    this.log(`match start lobby #${l.id} ${l.code} seed ${seed} ${l.size}: ${players.map((p) => `#${p.id} "${p.name}"`).join(', ')}`);
  }

  // ---- match (lockstep) ----
  turn(c, msg) {
    const l = c.lobby;
    // Dropped: not in a match, or not after this player's previous turn (which starts at DELAY - 1).
    if (!l || l.state !== 'playing' || !Number.isSafeInteger(msg.turn) || msg.turn <= c.lastTurn) return;
    // A gap would make from_turn a lie: the others would wait for the missing turns forever.
    if (msg.turn !== c.lastTurn + 1) return this.kick(c, 'Turns must come one after another');
    if (!Array.isArray(msg.cmds)) return this.error(c, 'A turn needs a cmds list');
    if (msg.cmds.length > MAX_CMDS) return this.error(c, `At most ${MAX_CMDS} commands per turn`);
    // A client simulates turn T only with everyone's turn T, then sends T + DELAY: it never leads the slowest
    // member by more than DELAY. Anything further ahead is a flood, not a player.
    let slowest = Infinity;
    for (const p of l.players) if (p !== c) slowest = Math.min(slowest, p.lastTurn);
    if (msg.turn > slowest + LOOKAHEAD) return this.kick(c, 'Too far ahead of the other players');
    c.lastTurn = msg.turn;
    c.lastTurnAt = Date.now();
    this.broadcast(l, { t: 'turn', turn: msg.turn, from: c.faction, cmds: msg.cmds });
  }

  // A member the others are waiting for (one of them is already DELAY turns past it) that has sent no turn for
  // stallMs (a hidden browser tab, a frozen machine) leaves the match like a disconnect: its botnet stays, idle,
  // and the others play on. When everyone stops together (the match is over) nobody is waiting.
  checkStalls(now = Date.now()) {
    for (const l of this.lobbies.values()) {
      if (l.state !== 'playing' || l.players.length < 2) continue;
      for (const c of [...l.players]) {
        const waited = l.players.some((p) => p !== c && p.lastTurn >= c.lastTurn + DELAY);
        if (!waited || now - c.lastTurnAt <= this.stallMs) continue;
        this.log(`stall #${c.id} "${c.name}" left lobby #${l.id} at turn ${c.lastTurn}`);
        this.remove(c);
        this.error(c, `You left the match: no response for ${Math.round(this.stallMs / 1000)} s`);
        this.send(c, { t: 'left' });
      }
    }
  }

  hash(c, msg) {
    const l = c.lobby;
    const h = typeof msg.h === 'number' ? String(msg.h) : msg.h;
    if (!l || l.state !== 'playing' || !Number.isSafeInteger(msg.turn) || msg.turn < 0) return;
    if (typeof h !== 'string' || !h || h.length > HASH_MAX) return;
    let got = l.hashes.get(msg.turn);
    if (!got) {
      if (l.hashes.size >= HASH_PENDING) l.hashes.delete(Math.min(...l.hashes.keys()));
      l.hashes.set(msg.turn, (got = new Map()));
    }
    if (!got.has(c.faction)) got.set(c.faction, h);
    this.checkHash(l, msg.turn);
  }

  // Once every faction still in the match reported `turn`, compare its hashes (then forget them).
  checkHash(l, turn) {
    const got = l.hashes.get(turn);
    if (!got || !l.players.every((p) => got.has(p.faction))) return;
    l.hashes.delete(turn);
    if (new Set(l.players.map((p) => got.get(p.faction))).size > 1) this.broadcast(l, { t: 'desync', turn });
  }

  // ---- output ----
  view(l) {
    return {
      id: l.id, code: l.code, name: lobbyName(l), public: l.public, host: l.players[0].id,
      max: l.max, size: l.size, state: l.state,
      players: l.players.map((p) => ({ id: p.id, name: p.name, ready: p.ready })),
    };
  }

  send(c, msg) { c.send(JSON.stringify(msg)); }
  broadcast(l, msg) {
    const text = JSON.stringify(msg);
    for (const p of l.players) p.send(text);
  }
  error(c, msg) { this.send(c, { t: 'error', msg }); }
  kick(c, msg) { // tell why, then close: the disconnect handling (drop, host transfer, …) follows from the close
    this.error(c, msg);
    this.log(`kick #${c.id} "${c.name}": ${msg}`);
    c.close(1008, msg);
  }
  system(l, text) { this.broadcast(l, { t: 'chat', system: true, text }); }
}
