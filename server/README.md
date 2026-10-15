# RIM server: the web game + the lobby server

One container serves everything at `https://network.thenakedcat.games`:

- `/` — the web game (the Godot Web export, built into the image by the workflow): open the address and play,
  single player or online.
- `/ws` — the multiplayer back end: lobbies, lobby/match chat, the ready countdown and the deterministic-lockstep
  turn relay, over one WebSocket per player. It never simulates the game. [PROTOCOL.md](PROTOCOL.md) is the
  contract with the game client. The web game served here connects back to this same server.
- `/api/lobbies` — the lobby list as JSON, for anyone (a browser, `curl`, a status page): every public lobby and
  match with its state (`open`, `countdown`, `playing`), players, size and game version, how many players are online,
  and how many private lobbies there are (only counted: their names and codes are never shown).
- `/healthz` → `ok`

Because the game and its server ship in the same image, they always have the same version (lobbies only match
players of the same version). Desktop builds and the GitHub Pages copy connect to `wss://network.thenakedcat.games/ws`.
- Everything lives in memory: restarting the container disconnects every player (lobbies and running matches are lost).

| file | what |
|---|---|
| `index.js` | the web game from `public/` (gzip twins, revalidated on every load), `/healthz` (also `/health`), WebSocket upgrade at `/ws`, 8 KB message limit, 20 s ping keepalive, logging |
| `lobby.js` | the protocol: lobbies, chat, countdown, turn relay, drops, desync check |
| `test/server.test.js` | end-to-end tests over real sockets (`node:test`) |
| `public/` | the Web export of the game (filled by the workflow; empty in git) |
| `Dockerfile` | the image: Node 22 Alpine, runs as user `node`, port 8787, health check on `/healthz` |
| `../.github/workflows/server.yml` | on every push to `main`: test, export the web game into `public/`, build and push the image to GHCR |

## Run and test locally

Node 20 or newer:

```sh
cd server
npm install
npm test        # end-to-end tests
npm start       # ws://localhost:8787/ws, http://localhost:8787/api/lobbies and /healthz
```

Environment: `PORT` (default 8787), `COUNTDOWN_MS` (the ready countdown, default 5000). Players always connect to
the official server; for development a build can be pointed at a local one with the launch argument
`-- --server=ws://localhost:8787/ws`.

With Docker: `docker build -t rim-lobby . && docker run --rm -p 127.0.0.1:8787:8787 rim-lobby` (without the game: `/` shows
a placeholder). To try the web game locally, export it first: from the repo root
`godot --headless --path . --export-release "Web" server/public/index.html`, then `npm start` and open
http://localhost:8787/ — the page connects to that local server.

## The image

Every push to `main` (or a manual run: Actions → "Lobby server image" → Run workflow) runs the tests, exports the web
game into `public/` (gzipped twins next to the big files), then builds the image for `linux/amd64` and `linux/arm64`
and pushes it to the GitHub Container Registry:

- `ghcr.io/zzzteph/rim-lobby:latest` — the newest build of `main`
- `ghcr.io/zzzteph/rim-lobby:sha-<commit>` — every build, to pin or roll back

The workflow logs in with its own `GITHUB_TOKEN`; no secrets to set up. The first push creates the package as
**private**: make it public once so the VPS can pull without logging in (GitHub → your profile → Packages →
`rim-lobby` → Package settings → Change visibility → Public), or log the VPS in with
`docker login ghcr.io -u zzzteph` and a personal access token that has `read:packages`.

## Deploy (on the VPS)

```sh
docker pull ghcr.io/zzzteph/rim-lobby:latest
docker rm -f rim-lobby 2>/dev/null || true
docker run -d --name rim-lobby --restart unless-stopped \
  -p 127.0.0.1:8787:8787 \
  --log-opt max-size=10m --log-opt max-file=3 \
  ghcr.io/zzzteph/rim-lobby:latest
curl -fsS http://127.0.0.1:8787/healthz      # "ok"
curl -fsS http://127.0.0.1:8787/api/lobbies  # who is online, the public lobbies and matches
docker logs -f rim-lobby                     # one line per connect / disconnect / lobby created / match start
```

The port is published on `127.0.0.1` only; your reverse proxy terminates TLS for `network.thenakedcat.games` and
forwards to it. It must pass WebSocket upgrades (the game connects to `/ws`). No volume: nothing is stored.
To pin a version or roll back, use a `sha-…` tag instead of `latest` in the `pull` and `run` lines.

Reverse proxy, one of:

```caddyfile
# Caddy (gets the certificate by itself; WebSockets pass through)
network.thenakedcat.games {
	reverse_proxy 127.0.0.1:8787
}
```

```nginx
# nginx (certificate e.g. from certbot)
server {
    listen 443 ssl;
    server_name network.thenakedcat.games;
    # ssl_certificate / ssl_certificate_key ...
    location / {
        proxy_pass http://127.0.0.1:8787;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;   # the server logs the real client address
        proxy_read_timeout 1h;   # a match can be quiet for a while; the server also pings every 20 s
    }
}
```

DNS: an `A` record `network` → the VPS's IPv4 (and `AAAA` → its IPv6, if any). From anywhere:
`curl https://network.thenakedcat.games/healthz` → `ok`, and https://network.thenakedcat.games/api/lobbies lists the
lobbies.

## Where PROTOCOL.md leaves room, the server does this

- A join, leave, rename or settings change stops a running countdown (`secs: 0`). If every remaining player is
  still ready (2 or more), a fresh countdown starts right away.
- `create` or `join` while already in a lobby is an error (send `leave` first); `leave` outside a lobby still
  answers `left`.
- Chat text is trimmed; empty or longer than 200 characters is an error (not cut). Control characters in names and
  chat become spaces.
- Turns below `delay`, repeated or older turns, and turns or hashes from outside a match are dropped silently; a
  turn with more than 64 commands gets an error and is not relayed.
- Desync check: only the factions still in the match count, so a drop can complete a pending check.
- A lobby is always called "<current host>'s lobby", so the name follows renames and host changes.
- The countdown's `secs` is `COUNTDOWN_MS` rounded up to whole seconds: 5 in production.
