# RIM economy — tuning guide

**Every number that drives the economy lives in `data/economy.json`.** Edit that file to balance the
game; you never need to touch code. `scripts/econ.gd` (the `Econ` autoload) loads the file once at
startup and applies it. A missing or broken file falls back to a tiny built-in set and logs
`Econ: could not load …` — if the game suddenly has only three programs, that's why.

This guide explains **what each group and field is, when it's read, and why it exists.** After editing,
validate the JSON (any validator) and run the checks (bottom of this file).

---

## The five resources (fixed in code, not the file)

| Resource | Symbol | Where it comes from | What it's for |
|---|---|---|---|
| **Intel** | ◈ | the passive +1/s baseline, scrapers/harvesters, the Darknet Market's input | the universal currency — pays for **every** scan, profile and capture, and feeds converters |
| **Cash** | ¥ | Crypto Mixer, Darknet Market | buying the pricier tools |
| **Credentials** | ⚿ | Keylogger, Credential Dumper | **burned** (1 each) to boost a capture of a node with a login |
| **Exploits** | ⚡ | Exploit Forge | **burned** (1 each) to boost a capture of a node running software |
| **Crypto** | ₿ | Cryptojacker, Mining Rig | nothing on its own — a Mixer turns it into Cash |

These keys (`intel/cash/creds/exploits/crypto`) are what you write inside `cost`, `out`, `in`, `store`
and `start`.

---

## Top-level groups in `economy.json`

### `start` — your opening stockpiles
`{"intel": 20, "cash": 0, …}` — the amount of each resource a **new game** begins with (used by
`Econ.reset()`, which the main menu calls on New Game). **Why:** sets how long you can act before you
must get a producer running. Raise `intel` to make the opening gentler.

### `cap_base` — the default ceiling on every resource
A single number (default **100**). Every stockpile holds this much before it stops filling. **When:**
checked every tick when production is clamped, and shown in the HUD as "Intel 57 / 100". **Why:** makes
storage programs matter and stops idle hoarding. Storage programs add on top of this (see below).

### `passive_intel` — Intel you always gather
A rate per second (default **1.0**), added to Intel every tick even with nothing installed. **Why:** you
can never be fully stuck with no way to earn. Set to 0 for a harsher game.

### `action_cost` — the Intel price of the three hacking actions
```
"action_cost": { "net_scan": 4, "profile": 3, "take": 8 }
```
- `net_scan` — Intel to **scan the network** from a controlled node (reveal its neighbours).
- `profile` — Intel to **scan an endpoint** (learn what a detected node is; unlocks capture).
- `take` — Intel to attempt **Take control** of a profiled node.

**When:** charged the moment you press the action, **even if the dice fail** (so scanning/attacking is a
real cost, not free retries). **Why:** Intel is the throttle on expansion. A burned node multiplies
these (see `heat.rehack_cost_per_alarm`).

### `capture_boost` — the bonus from burning a credential/exploit
A success-chance bonus (default **0.3** = +30 percentage points) added when you choose to burn one
Credential (login nodes) or one Exploit (software nodes) on a Take-control attempt. The item is spent
whether or not the attempt succeeds. **Why:** gives Credentials and Exploits a concrete use and a reason
to keep harvesting them.

### `heat` — the alarm system (per node)
```
"heat": {
  "max": 100,                      // a node's heat is 0..100
  "alarm_at": 100,                 // at this heat the node alarms immediately
  "warn_at": 50,                   // at/above this, it risks an alarm every minute
  "alarm_minute_chance": 0.05,     // that per-minute risk (0.05 = 5%)
  "rehack_cost_per_alarm": 0.10,   // each past alarm makes re-hacking cost +10% Intel
  "rehack_chance_per_alarm": 0.05, // …and −5% success chance
  "rehack_alarm_cap": 5            // but no more than 5 alarms' worth of penalty (so ≤ +50% cost, −25% chance)
}
```
**How heat works, second by second** (`Econ._heat_second`, stepped once per real second):
- Each **running tool** on a connected, controlled node emits `heat` points **with probability `noise`**
  (see per-program fields). A loud Mining Rig (`noise 0.85`) adds ~0.85/s on average; a quiet Data Vault
  (`noise 0.08`) is almost silent.
- Each **evade** tool subtracts its `evade` points per second, flat (no chance).
- Net heat is clamped to `0..max`.
- If a node hits `alarm_at` → **alarm now**. Once a minute, any node at/above `warn_at` rolls
  `alarm_minute_chance` → alarm.

**On alarm** (`Econ._alarm`): the node's tools are wiped, you lose control (it drops to "detected" and
must be re-hacked), its heat resets to 0, and its **burned** count goes up by one (capped at
`rehack_alarm_cap`). Because production only flows through connected nodes, losing a relay also stops
every node behind it until you reconnect. **Why this group exists:** it's the cost of greed — you can't
stuff a node with producers without cooling it, and a traced node sets you back.

### `programs` — the tool catalogue (the big one)
A map of `program_id → { fields }`. Order here is the order they appear in the deploy list. The id is
internal; `name` is what's shown. Below is every field and when it matters.

---

## Per-program fields

**Shared by all programs**

| Field | Meaning / when it's used |
|---|---|
| `name` | Display name in the list, slots and tooltips. |
| `cat` | **Slot category** — a node only accepts a program whose `cat` is in its accepts list. The categories are `intel`, `creds`, `crypto`, `ops` (converters) and `evade`. This is how "a Database takes intel/creds tools" is enforced. |
| `tier` | 1 = basic, 2 = upgraded. Cosmetic/ordering only today; use it to mark the "better but pricier" version. |
| `glyph` | Which icon to draw (`scraper/sniffer/vault/keylog/dumper/jacker/skimmer/cloak/forge/mixer/market`). Reuse an existing glyph or add a new case in `building.gd`'s `ProgramIcon.paint`. |
| `cost` | `{resource: amount, …}` paid once to **deploy** the program. Checked and charged when you click it in the list. |

**Producer programs** (make a resource each second)

| Field | Meaning |
|---|---|
| `out` | which resource it produces (`intel/creds/crypto`). |
| `rate` | how much per second, while the node is connected to the city. |
| `heat` | heat points it can emit per second (usually 1). |
| `noise` | the **chance (0..1)** it emits that heat each second — the tool's loudness. Higher = hotter = riskier. This is the main per-tool balance dial. |

Example: `"rig": {… "out":"crypto","rate":1.4,"heat":1.0,"noise":0.85 …}` — lots of Crypto, but very
loud, so it needs evade cover.

**Converter programs** (turn one resource into another)

| Field | Meaning |
|---|---|
| `in` | the input resource consumed. |
| `in_rate` | input consumed per second. The converter **scales down** if you don't have enough input, and never drives a stockpile negative. |
| `out`, `rate` | the output resource and how much per second (at full input). |
| `heat`, `noise` | same as producers. |

Example: `"mixer": {… "in":"crypto","in_rate":1.0,"out":"cash","rate":0.8 …}` — spends 1 Crypto/s to
make 0.8 Cash/s.

**Storage programs** (raise a cap)

| Field | Meaning |
|---|---|
| `store` | which resource's cap it raises. |
| `amount` | how much it adds to that resource's cap **while installed** (removed if you uninstall or lose the node). |
| `heat`, `noise` | usually tiny — storage is quiet. |

Example: `"vault_i": {… "store":"intel","amount":150 …}` → Intel cap becomes 100 + 150 = 250 while it's
installed.

**Evade programs** (cool heat)

| Field | Meaning |
|---|---|
| `evade` | heat points removed **per second, flat** (no chance). |

Example: `"cloak": {"cat":"evade","evade":2.0, …}` — cancels roughly two average producers, but costs a
slot.

---

## The rules a tool list can't show (fixed in code)

- **Only connected nodes produce.** A program earns only if its node has a path over controlled nodes
  back to the entry firewall (the city uplink). Lose a relay and everything behind it goes idle.
- **Heat/alarms only run on the city and building screens**, not in the menu, and are **paused during
  tests**.
- Node slot counts and which categories each node type accepts live in `scripts/building.gd` (`NODE`),
  not in this file — they're structure, not economy.

---

## Balancing recipes

- **Game too easy / resources pile up?** Lower `passive_intel`, lower producer `rate`s, or lower
  `cap_base` so you must invest in storage.
- **Expansion too cheap?** Raise `action_cost`.
- **Heat never bites?** Raise producer `noise`, lower `heat.warn_at`, or raise
  `heat.alarm_minute_chance`. **Too punishing?** Do the opposite, or make `cloak`'s `evade` larger.
- **Credentials/Exploits ignored?** Raise `capture_boost`, or make the tough nodes' base odds lower so
  the bonus matters more.

## Checking your edits

1. `data/economy.json` must be valid JSON (double quotes, commas, no trailing comma).
2. Run the suite:
   `Godot_v4.7.2-stable_win64_console.exe --headless --path . res://review/building_checks.tscn`
   It covers deploy cost, production, the converter scaling, the 100 cap, storage raising the cap,
   passive Intel, connected-only production, evade cooling, and the alarm-at-100 behaviour.
3. If the file won't load, the log shows `Econ: could not load res://data/economy.json …` and the game
   runs on the built-in fallback.

---

## `capture_scale_per_node` — captures get pricier as you grow

A fraction (default **0.5**). The Intel cost of **Take control** is multiplied by
`1 + capture_scale_per_node × (nodes you already control − 1)`. So your first capture is full price, and
with 5 nodes held a capture costs ×3, with 11 nodes ×6 (and around 25–30 nodes it approaches the 100-Intel cap, so you must deploy Data Vaults to expand further), and so on — like paying more alloys for each
new Stellaris base. **Why:** stops a single fully-owned building (and its Intel firehose) from letting
you trivially capture everything. Raise it to make expansion bite sooner; set 0 for flat cost. This
stacks on top of the per-node re-hack surcharge (`heat.rehack_cost_per_alarm`).

## `action_time` — nothing is instant

Hacking takes time; you watch a progress ring fill on the node and can Cancel.

| Field | Meaning / when it's used |
|---|---|
| `net_scan` | seconds a **network scan** takes before it resolves (then the success roll happens). |
| `profile` | seconds an **endpoint scan** takes. |
| `take` | seconds a **capture** attempt takes. |
| `install_per_hop` | a deployed tool is **delivered** from the city along your controlled route; this is the seconds per hop it travels. |
| `install_min` | the minimum delivery time, however short the route. |
| `install_finalise` | after delivery, the seconds to actually install (the quick part). |
| `install_fail_chance` | chance (0..1) the install fails at the end (the tool is lost, its cost already spent). |

**Why:** actions are commitments, not spam. Costs are charged up front when you start; the dice (and the
install-fail roll) are rolled when the timer completes. Total deploy time ≈
`max(install_min, hops × install_per_hop) + install_finalise`.
