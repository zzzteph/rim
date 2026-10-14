# RIM multiplayer protocol (v1)

One WebSocket per player, JSON text frames, every message an object with a type field `t`.

- Production: `wss://network.thenakedcat.games/ws` (the game is served over https, so it must be wss).
- Local development: `ws://localhost:8787/ws`. The server listens on `$PORT` (default 8787) at path `/ws`;
  `GET /health` answers `200 ok`.

The server never simulates the game. Every client runs the same deterministic simulation (fixed 1/30 s steps)
and only player **commands** travel, grouped into **turns** (deterministic lockstep). The server keeps lobbies,
relays chat, runs the ready countdown and relays turns.

## Connection

| client → server | server → client |
|---|---|
| `{"t":"hello","name":"Steph","version":"0.1.5"}` (first message) | `{"t":"welcome","id":17,"name":"Steph"}` |
| `{"t":"name","name":"Neo"}` | `{"t":"welcome",…}` again, and a `lobby` update if in a lobby |

- `name`: trimmed, 1–16 characters (longer is cut; empty becomes `Player`). Names may repeat.
- `version`: the game version. Players can only meet in a lobby of the **same** version (the simulation must be
  identical); the lobby list only shows lobbies of the asking client's version.
- Errors for any request: `{"t":"error","msg":"Lobby is full"}` (human-readable, shown as is).

## Lobbies

| client → server | effect |
|---|---|
| `{"t":"list"}` | `{"t":"lobbies","lobbies":[{"id":3,"name":"Steph's lobby","players":1,"max":3,"size":"medium"}]}` — public, open (not playing) lobbies of the client's version |
| `{"t":"create","public":true,"max":3,"size":"medium"}` | creates a lobby, the creator is host; answers with `lobby` |
| `{"t":"join","id":3}` or `{"t":"join","code":"K7QPX"}` | joins (public by id, any lobby by code); `lobby` goes to every member |
| `{"t":"leave"}` | leaves the lobby or match; the leaver gets `{"t":"left"}`, the others a `lobby` update (or `drop` in a match) |
| `{"t":"settings","max":2,"size":"big","public":false}` | host only; any subset of the fields; every ready flag is cleared |
| `{"t":"ready","ready":true}` | sets your ready flag |
| `{"t":"chat","text":"gl hf"}` | `{"t":"chat","name":"Steph","from":17,"text":"gl hf"}` to every member (lobby and match) |

- `max`: 2 or 3 (and never below the current number of players). `size`: `small` (6×4), `medium` (8×6),
  `big` (10×8). Every lobby has a 5-character `code` (letters/digits without look-alikes); a private lobby is
  not listed and can only be joined by code.
- The lobby object sent to members:
  `{"t":"lobby","lobby":{"id":3,"code":"K7QPX","name":"Steph's lobby","public":true,"host":17,"max":3,
  "size":"medium","state":"open","players":[{"id":17,"name":"Steph","ready":true},{"id":21,"name":"Neo","ready":false}]}}`
  `state` is `open`, `countdown` or `playing`. Player order = join order; the host is always listed first.
- When the host leaves, the next player becomes host. An empty lobby is deleted.
- Join / leave / name changes are also announced as system chat: `{"t":"chat","system":true,"text":"Neo joined"}`.
- Limits: chat 1–200 characters, at most 5 chat messages per 5 s per player; any message over 8 KB closes the socket.

## Ready → countdown → start

- The countdown runs exactly while: state is not `playing`, there are at least 2 players, and every player is
  ready. When that becomes true the server sends `{"t":"countdown","secs":5}` to every member (state
  `countdown`); when it stops being true before the end (someone un-readies, joins, leaves, renames, or the host
  changes a setting) it sends `{"t":"countdown","secs":0}` (state back to `open`).
- After 5 s the match starts: state `playing`, and each member receives its own
  `{"t":"start","seed":482113,"size":"medium","turn_steps":3,"delay":2,"you":2,
   "players":[{"id":17,"name":"Steph","faction":1},{"id":21,"name":"Neo","faction":2}]}`
  Factions are 1, 2, 3 in player order. `seed` is a random integer in 1…900000.

## Match (lockstep)

- A turn is `turn_steps` simulation steps (3 × 1/30 s = 100 ms). Turns are numbered from 0.
- Turns `0 … delay-1` are empty for everybody and are never sent.
- When a client begins simulating turn `T`, it sends its commands for turn `T + delay`:
  `{"t":"turn","turn":5,"cmds":[["wire",[12,13],40],["launch",40,"attack"]]}` (an empty list when idle; at most 64
  commands). The server relays it to **every** match member, the sender included, adding the sender's faction:
  `{"t":"turn","turn":5,"from":2,"cmds":[…]}`. Turns from one client must arrive in increasing order; the server
  drops anything else.
- A client may simulate turn `T` only when it holds turn `T` from every faction that has not dropped. Commands
  of a turn are applied at its first step, faction by faction (ascending), each list in order.
- When a member disconnects or sends `leave` during a match, the others receive
  `{"t":"drop","faction":2,"from_turn":N}` where `N` = the last turn relayed from that faction + 1 (or `delay`
  if it never sent one). Every turn of that faction below `N` has already been relayed before the `drop`
  (same socket order), and from `N` on nobody waits for it: its botnet stays in the match, idle.
- Desync check: every 30 turns each client sends `{"t":"hash","turn":T,"h":"<hex>"}` for the state after turn
  `T`. When all non-dropped factions reported turn `T` and the hashes differ, every member receives
  `{"t":"desync","turn":T}`.
- The match ends inside the simulation (identical on every client); clients then `leave`. The server deletes a
  match when its last member has left. Chat keeps working during a match.

## Commands (inside `cmds`)

Arrays whose first element names the action; numbers arrive as JSON numbers (clients cast to int).

| command | meaning |
|---|---|
| `["wire", [sources…], target]` | connect your buildings `sources` to `target` |
| `["launch", target, "attack"\|"scan"]` | start every dormant connection of yours into `target` |
| `["halt", target]` | stop every live flow of yours into `target` (wires kept) |
| `["unwire", source]` | remove `source`'s connection |
| `["build", host, slot, kind]` | build (or replace) in a slot |
| `["job", host, slot]` / `["cancel", host, slot]` | pause/resume / cancel a construction |
| `["demolish", host, slot]` | clear a slot |
| `["produce", host, slot]` | pause/resume a producer |
| `["research", card_key]` / `["unresearch", card_key]` | queue-or-pause / cancel a card's research |
| `["card", card_key, target]` | play a held card on `target` |

The server does not interpret commands; clients validate them inside the simulation (a command touching a
building its sender does not own does nothing, identically on every client).
