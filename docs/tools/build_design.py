"""Builds the RIM design reference from the game's own config, so every number in it is the game's.

    godot --headless --path . --script res://docs/tools/dump_constants.gd   # refresh docs/rim_constants.json
    python3 docs/tools/build_design.py                                     # write docs/design.html and docs/DESIGN.md

Prices, card numbers and constants come from scripts/botnet_cfg/*.gd and docs/rim_constants.json; the prose that
describes behaviour lives in docs/tools/design.body.html and the D/WHY tables below, and must be kept true to
scripts/botnet_proto.gd by hand. DESIGN.md is converted from the HTML with pandoc (skipped if pandoc is missing).
"""
import html
import os
import re
import shutil
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DOCS = os.path.join(ROOT, "docs")
OUT = os.path.join(DOCS, "design.html")
try:
    COMMIT = subprocess.run(["git", "-C", ROOT, "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip() or "?"
except OSError:
    COMMIT = "?"
cards_src = open(f"{ROOT}/scripts/botnet_cfg/cards.gd").read()
build_src = open(f"{ROOT}/scripts/botnet_cfg/buildings.gd").read()

RES = ["intel", "cash", "creds", "research"]
RES_NAME = {"intel": "Intel", "cash": "Crypto", "creds": "Credentials", "research": "Research"}
RES_SHORT = {"intel": "Intel", "cash": "Crypto", "creds": "Creds", "research": "Research"}

cards = {}
for m in re.finditer(r'\n\t"(\w+)":\s+\{"name": "([^"]+)", "short": "([^"]+)".*?"bank": "(\w+)".*?"known": (true|false)(.*?)"make": \{"intel": (\d+), "cash": (\d+), "creds": (\d+), "research": (\d+)\}, "make_time": ([0-9.]+),\s+"lead": "([^"]+)"', cards_src, re.S):
    extra = m.group(6)
    num = lambda k: (re.search(r'"%s": ([0-9.]+)' % k, m.group(0)) or [None, None])[1]
    cards[m.group(1)] = {"name": m.group(2), "short": m.group(3), "bank": m.group(4), "known": m.group(5) == "true",
                         "make": dict(zip(RES, [int(m.group(i)) for i in range(7, 11)])), "time": float(m.group(11)), "lead": m.group(12),
                         "dur": num("dur"), "exec": num("exec"), "exec_rig": num("exec_rig"), "sec_max": num("sec_max"), "reach": num("reach"),
                         "cargo": num("cargo"), "chance": num("chance")}
research = {}
for m in re.finditer(r'\n\t"(\w+)":\s+\{"prereq": "(\w+)",\s+"intel": (\d+), "cash": (\d+), "research": (\d+), "time": ([0-9.]+)', cards_src):
    research[m.group(1)] = {"prereq": m.group(2), "cost": {"intel": int(m.group(3)), "cash": int(m.group(4)), "research": int(m.group(5))}, "time": float(m.group(6))}
assert len(cards) == 15, len(cards)
builds = {}
for m in re.finditer(r'\n\t"(\w+)":\s+\{"name": "([^"]+)".*?"out": "(\w*)", "rate": ([0-9.]+), "use": \{([^}]*)\}, "cost": \{([^}]*)\}, "cap": ([0-9.]+)', build_src, re.S):
    use = {k: float(v) for k, v in re.findall(r'"(\w+)": ([0-9.]+)', m.group(5))}
    cost = {k: float(v) for k, v in re.findall(r'"(\w+)": ([0-9.]+)', m.group(6))}
    builds[m.group(1)] = {"name": m.group(2), "out": m.group(3), "rate": float(m.group(4)), "use": use, "cost": cost, "cap": float(m.group(7))}
assert len(builds) == 6, builds.keys()

C = cards
def n(x):
    x = float(x)
    return str(int(x)) if x == int(x) else str(x)
def chips(cost, secs=None):
    out = []
    for r in RES:
        v = cost.get(r, 0)
        if v:
            out.append(f'<span class="chip r-{r}"><b>{n(v)}</b> {RES_SHORT[r]}</span>')
    if secs is not None:
        out.append(f'<span class="chip time"><b>{n(secs)}</b> s</span>')
    return "".join(out)

# reference income (units per minute) for the "price in seconds of income" column
EARLY = {"intel": 36, "cash": 30, "creds": 10, "research": 10}    # 1 unit per producer per 6-s cycle (0.6.18: the flow doubled), the trickle 10/min
MID = {"intel": 76, "cash": 40, "creds": 30, "research": 20}
def wait(cost, inc):
    best, who = 0.0, ""
    for r in RES:
        v = cost.get(r, 0)
        if v and v / inc[r] * 60 > best:
            best, who = v / inc[r] * 60, RES_NAME[r]
    return best, who

_TUNING = open(f"{ROOT}/scripts/botnet_cfg/tuning.gd").read()
RECON_P, SCOUTED_P, UNSCOUTED_P = (float(re.search(rf"{k} := ([0-9.]+)", _TUNING).group(1)) for k in ("RECON_CHANCE", "SCOUTED_CHANCE", "UNSCOUTED_CHANCE"))
pc = lambda p: f"{p * 100:g}%"
# ---- what every card does, exactly (checked against scripts/botnet_proto.gd) ----
D = {}
D["recon"] = [
    ("Target", "Any foreign host your operations can reach."),
    ("Timing", "Travels, then takes effect on arrival. No execution."),
    ("Effect", f"Takes a snapshot of the host: what is in each slot, how full its storage is, and which cards wait in its Firewall. You see the snapshot, not later changes, for {n(C['recon']['dur'])} s; then the slots go back to “?”."),
    ("Quiet", "The target gets no red frame and no pulse. It is the only attack card that does not show."),
    ("Its own odds", f"A Recon gets through {pc(RECON_P)} of the time (RECON_CHANCE), whatever the host. A miss shows nothing, and only you hear of it."),
    ("Odds", f"While the snapshot is fresh ({n(C['recon']['dur'])} s, and only for the faction that made it), your other attack cards on that host succeed {pc(SCOUTED_P)} of the time (SCOUTED_CHANCE); without it, {pc(UNSCOUTED_P)} (UNSCOUTED_CHANCE). Freshness is judged when the operation resolves. A change of owner voids it. Defence cards on your own hosts always work."),
]
D["breach"] = [
    ("Target", "Any foreign host your operations can reach, neutral or a rival’s. There are no security levels."),
    ("Timing", f"Travels, then executes for {n(C['breach']['exec'])} s on the host ({n(C['breach']['exec_rig'])} s on a held main node). The owner sees “Breach executing” and has that long to react."),
    ("Outcome", "When its execution ends: first a Patch (<b>countered</b>), losing your path to it (<b>route failed</b>) or another owner taking it first (<b>owner changed</b>) stop it; then one draw (<b>missed</b> on a fail): " + pc(SCOUTED_P) + " with fresh Recon of the host, " + pc(UNSCOUTED_P) + " without."),
    ("Effect", "On success the host becomes yours. All of its buildings, storage, Firewall cards and running effects are wiped: you start with empty slots."),
    ("Stopped by", "A Patch (by hand during execution, armed in advance, or loaded in a Firewall: then it never starts), losing your path to a neighbour of the host, or the host changing owner meanwhile."),
    ("Limit", "One capture or raid per attacker per host at a time."),
]
D["exploit"] = [
    ("Target", "Any foreign host your operations can reach."),
    ("Timing", f"Travels, then executes for {n(C['exploit']['exec'])} s ({n(C['exploit']['exec_rig'])} s on a held main node): less time for a defender's Patch to travel there."),
    ("Outcome", "As Credential breach: countered, route-failed, owner-changed, missed (the draw failed) or captured."),
    ("Effect", "As Credential breach: the host becomes yours, wiped."),
    ("Stopped by", "As Credential breach."),
]
D["zeroday"] = [
    ("Target", "Any foreign host your operations can reach."),
    ("Timing", f"Travels, then executes for {n(C['zeroday']['exec'])} s; {n(C['zeroday']['exec_rig'])} s on an active rival main node, with a countdown the owner sees. Usually only a Patch already armed or loaded in a Firewall is in time."),
    ("Outcome", "As Credential breach: countered, route-failed, owner-changed, missed (the draw failed) or captured."),
    ("Effect", "The host becomes yours, wiped. On a rival main node the rival is eliminated: their banks and cards are cleared, their flights and workers vanish, and every other host they held becomes <b>yours with its finished buildings</b> (storage, sockets, projects and effects cleared; its Bot stations staff themselves for you at once). You keep the old main node as an ordinary host."),
    ("Stopped by", "As Credential breach."),
]
D["worm"] = [
    ("Target", "Any foreign host your operations can reach."),
    ("What it is", f"A capture on up to {n(C['worm']['reach'])} linked hosts, one after the other."),
    ("Timing", f"Travels; each stage executes for {n(C['worm']['exec'])} s ({n(C['worm']['exec_rig'])} s on a main node), and each can be stopped on its own."),
    ("Chain", "Once the first host is captured, the second stage starts on the nearest (by map distance, then host number) visible host linked to it that belongs to the <b>same owner</b> as the first target. It never jumps to another owner. Each stage is its own operation with its own draw (" + pc(SCOUTED_P) + " scouted, " + pc(UNSCOUTED_P) + " not); if the first host had fresh Recon, the second counts as scouted too. Both stages land " + pc(SCOUTED_P * SCOUTED_P) + " of the time with the first host scouted, " + pc(UNSCOUTED_P * UNSCOUTED_P) + " without."),
    ("Stops when", "A stage is countered by a Patch, its route is lost, its host changes owner, or no such neighbour exists. A stopped stage ends the chain; a stage already captured stays captured."),
]
D["phish"] = [
    ("Target", "A foreign host (a rival’s; a neutral host makes nothing)."),
    ("Timing", f"Takes effect on arrival, for {n(C['phish']['dur'])} s."),
    ("Effect", "What the host makes is kept there for you: your workers collect it and carry it to <b>your</b> main node. The host and its workers stay the owner's."),
    ("Victim", "Keeps the host but gets nothing from it. Its main-node trickle (if you phish a main node) still goes to them."),
    ("Ends", "After its time, or when Incident response clears it. Your unsent stolen units on the host then go back to the owner."),
]
D["siphon"] = [
    ("In one line", "A tap on one of their hosts: for a while, their deliveries that go through it come to you instead."),
    ("Target", "A rival host their deliveries leave from or pass through (a junction is best). You pick the resource (Intel, Crypto, Credentials or Research) in the host’s Launch panel; a card dragged onto the map takes Crypto."),
    ("Timing", f"Takes effect on arrival, for {n(C['siphon']['dur'])} s."),
    ("Effect", f"Every unit of that resource carried by their workers leaving or passing the host after the siphon lands is dropped there for your workers to collect, up to {n(C['siphon']['cargo'])} units. Their workers are not consumed."),
    ("Not affected", "Covered cargo (Cargo cover), empty workers, your own cargo."),
    ("Ends", "After its time, after its last unit, or when Incident response clears it."),
]
D["vault"] = [
    ("Target", "Any rival host."),
    ("Timing", f"Travels, then executes for {n(C['vault']['exec'])} s."),
    ("Effect", f"Takes what is stored on the target and on its {int(n(C['vault']['reach'])) - 1} nearest linked hosts of the same owner, up to {n(C['vault']['cargo'])} units, all resources, unconsumed construction materials included (the project's shortage reopens). The loot waits there; your main node's workers collect it, one unit a leg."),
    ("Best on", "Hosts whose output piles up: no Bot station, busy workers, or no route home."),
    ("Stopped by", "A Patch on the target, or your operation having no way home."),
]
D["ddos"] = [
    ("Target", "Any foreign host."),
    ("Timing", f"Takes effect on arrival, for {n(C['ddos']['dur'])} s."),
    ("Reach", f"The target and its owner’s {int(n(C['ddos']['reach'])) - 1} hosts nearest to it on the map, all at once."),
    ("Effect", "Each one makes nothing, sends nothing and forwards nothing. New routes go round them. Workers whose route runs through one wait there until it is up. Cargo addressed to them still arrives."),
    ("On a main node", "Its one-of-each trickle and its producers stop, and its owner can play no card at all until it ends — no attack, and no defence card on any host, the main node included. Only cards already armed or loaded in a Firewall still act, so a DDoS on a main node opens a window for a capture."),
    ("Blocked by", "Traffic filter, host by host: a host under Filter ignores it; a Filter loaded in its Firewall fires and the DDoS never lands there."),
]
D["sabotage"] = [
    ("Target", "A rival host."),
    ("Timing", f"Takes effect on arrival, for {n(C['sabotage']['dur'])} s."),
    ("Effect", f"Switches off every producer on the target and on up to {int(n(C['sabotage']['reach'])) - 1} more hosts of the same owner, each the nearest neighbour of the last, and keeps the workers of their Bot stations from setting out (a leg already under way finishes). Routing and Firewalls keep working; a main node keeps its trickle."),
    ("Cleared by", "Incident response, host by host (a Response loaded in a hit host’s Firewall clears that host at once)."),
]
D["patch"] = [
    ("Target", "One of your hosts."),
    ("By hand", "Cancels the capture, Worm stage or Vault raid running there that ends first. With nothing running, it arms the host for 30 s: the next one that would finish there in that time is blocked instead."),
    ("Loaded", "In a free Firewall socket it waits with no time limit and stops the next capture, Worm stage or Vault raid the moment it starts executing there."),
    ("Recovery", f"Once a Patch stops something, the host recovers for {n(C['patch']['dur'])} s: no other Patch can be played there, one on its way goes back to your hand, and the window is shown to everyone who sees the host. A Patch already loaded in its Firewall still fires, and restarts the window."),
]
D["response"] = [
    ("Target", "One of your hosts."),
    ("By hand", "Ends Phishing, Packet siphon and sabotage on that host at once. Stolen units not yet sent come back to you. It does not clear DDoS, and with nothing to clear it does nothing."),
    ("Loaded", "Fires the moment Phishing, a siphon or sabotage lands on that host, so nothing is stolen or switched off."),
]
D["filter"] = [
    ("Target", "One of your hosts."),
    ("By hand", f"Clears a DDoS there and makes the host ignore DDoS for {n(C['filter']['dur'])} s — unless your main node is under DDoS: then no card can be played at all."),
    ("Loaded", "Fires when a DDoS lands: the DDoS never takes effect and the host is immune for the same 30 s."),
]
D["cover"] = [
    ("Target", "One of your hosts."),
    ("By hand", f"For {n(C['cover']['dur'])} s the cargo of every worker that host sends (and those already on the road from it) cannot be siphoned anywhere on its way."),
    ("Loaded", "Fires when a siphon grabs this host’s cargo: that cargo is saved, and cover starts for 30 s."),
]
D["express"] = [
    ("Target", "One of your hosts."),
    ("Effect", f"For {n(C['express']['dur'])} s, workers leaving that host cross each link in half the time (0.5 s instead of 1 s, forwarding 0.125 s instead of 0.25 s)."),
    ("Not loadable", "It cannot go in a Firewall socket."),
]

WHY = {
    "recon": ("Tells you whether an expensive card will pay off: what a host holds, how full its storage is, and whether a Patch waits in its Firewall.", "Before an 0day, Vault raid, Worm or Sabotage, or to find a rival's richest host."),
    "breach": ("The way to grow: every host adds slots, and holding 51% of all hosts wins.", "On neutral hosts first, as nobody defends them; scouted, for " + pc(SCOUTED_P) + " instead of " + pc(UNSCOUTED_P) + "."),
    "exploit": ("A faster capture: 9 s leaves a defender little time to get a Patch there.", "Against a rival's hosts, where a Patch might be sent."),
    "zeroday": ("The fastest capture: 5 s (12 s on a main node) leaves only an armed or loaded Patch in time: the card for a defended host or a rival main node.", "After a Recon shows no Patch waiting, or after a cheaper card has used it up."),
    "worm": ("Two captures in one launch, reaching a host behind a rival's front line.", "When a rival holds a chain of linked hosts; scout both."),
    "phish": ("Hurts a rival without taking ground: you gain exactly what they lose.", "On their best-producing host."),
    "siphon": ("Takes a whole supply line, not one host's output.", "On a host their deliveries cross, set to the resource they need most."),
    "vault": ("Punishes a network whose output piles up in storage.", "On hosts with no Bot station, busy workers or no route home."),
    "ddos": ("The only card that hits logistics: it strands supply lines and, on a main node, stops their attacks.", "Right before your own big attack, or on the hosts their supply lines share."),
    "sabotage": ("Shuts a district's production for a minute without touching its logistics.", "On their production cluster before a long fight."),
    "patch": ("Every capture has a countdown; Patch is the answer to it.", "On a host under intrusion, or loaded at your main node."),
    "response": ("Theft and sabotage last a minute; this ends them.", "On a host being phished, siphoned or sabotaged, or loaded where theft is likely."),
    "filter": ("DDoS is the strongest disruption and needs its own answer.", "Loaded on a junction or on your main node."),
    "cover": ("Protects a supply line from the sending side.", "On hosts whose workers cross a siphoned host."),
    "express": ("A shorter road: deliveries arrive sooner and spend less time in reach of siphons and cuts.", "On far producers, or while a siphon threatens your lines."),
}


def card_sheet(key):
    c = C[key]
    bank = {"attack": "ATTACK", "defense": "DEFENCE"}[c["bank"]]
    origin = "Known from the start" if key not in research else f"Research after {C[research[key]['prereq']]['name']}"
    e, ew = wait(c["make"], EARLY); m, mw = wait(c["make"], MID)
    rows = "".join(f"<dt>{html.escape(a)}</dt><dd>{b}</dd>" for a, b in [("Why it exists", html.escape(WHY[key][0])), ("Play it when", html.escape(WHY[key][1]))] + D[key])
    sock = ' <span class="tag sock">Firewall socket</span>' if key in ("patch", "response", "filter", "cover") else ""
    return f'''<article class="sheet {c['bank']}" id="card-{key}">
  <header><h3>{html.escape(c['name'])}</h3><span class="tag {c['bank']}">{bank}</span><span class="tag">{origin}</span>{sock}</header>
  <p class="lead">{html.escape(c['lead'])}</p>
  <div class="price"><span class="label">Make</span>{chips(c['make'], c['time'])}<span class="wait">≈ {e:.0f} s early · {m:.0f} s mid of {ew if e >= m else mw} income</span></div>
  <dl>{rows}</dl>
</article>'''

# ---- buildings table ----
B_NOTE = {
    "intel": "No input. Its Intel is stored on the host until workers take it home (a Firewall there eats 1 a cycle).",
    "bot": "Provides 2 reusable workers that join the one pool working from the main node. Each carries 1 unit per leg: building materials and a Firewall's upkeep out, output back. A worker lost on the road is replaced after 5 s; capture of its host destroys them, wherever they are.",
    "cash": "No input (since 0.6.12): it makes Crypto on its own, like a harvester.",
    "cred": "No input (since 0.6.12): it makes Credentials on its own.",
    "lab": "No input (since 0.6.12): it makes Research on its own.",
    "wall": "Not a producer. 3 sockets for defence cards per Firewall. Eats 1 Intel from its own host each cycle (workers bring it when none is made there); without it the Firewall is off and its cards wait. It does not make the host harder to capture.",
}
def brow(k):
    b = builds[k]
    if k == "wall":
        cyc = '<span class="chip r-intel"><b>−1</b> Intel</span> upkeep'
    elif k == "bot":
        cyc = "2 reusable workers"
    else:
        ins = "".join(f'<span class="chip r-{r}"><b>−{n(v)}</b> {RES_SHORT[r]}</span>' for r, v in b["use"].items())
        out = f'<span class="chip r-{b["out"]}"><b>+{n(b["rate"])}</b> {RES_SHORT[b["out"]]}</span>'
        cyc = (ins + " → " if ins else "") + out
    cap = f"+{n(b['cap'])} {RES_SHORT[b['out']]} cap" if b["cap"] else "—"
    return f"<tr><th>{html.escape(b['name'])}</th><td class='nowrap'>{cyc}</td><td class='nowrap'>{chips(b['cost'])}</td><td>{cap}</td><td>{B_NOTE[k]}</td></tr>"

def rrow(k):
    r = research[k]
    e, _ = wait(r["cost"], EARLY); m, _ = wait(r["cost"], MID)
    return f"<tr><th>{html.escape(C[k]['name'])}</th><td>{html.escape(C[r['prereq']]['name'])}</td><td class='nowrap'>{chips(r['cost'], r['time'])}</td><td class='num'>{e:.0f} s · {m:.0f} s</td></tr>"

attack = ["recon", "breach", "exploit", "zeroday", "worm", "phish", "siphon", "vault", "ddos", "sabotage"]
defence = ["patch", "response", "filter", "cover", "express"]
research_order = ["exploit", "zeroday", "worm", "ddos", "sabotage", "siphon", "vault", "filter", "cover", "express"]

def price_row(k):
    c = C[k]
    e, ew = wait(c["make"], EARLY); m, mw = wait(c["make"], MID)
    total = sum(c["make"].values())
    return f"<tr><th>{html.escape(c['name'])}</th>" + "".join(f"<td class='num'>{c['make'][r] or '·'}</td>" for r in RES[1:]) + f"<td class='num'>{n(c['time'])} s</td><td class='num'>{e:.0f} s <small>{ew}</small></td><td class='num'>{m:.0f} s <small>{mw}</small></td></tr>"

import json, os
DATA = json.load(open(f"{ROOT}/docs/rim_constants.json"))
def find_unused():   # constants in the config files that the game's scripts never read
    proto = open(f"{ROOT}/scripts/botnet_proto.gd").read()
    others = open(f"{ROOT}/scripts/botnet_help.gd").read()
    aliases = re.findall(r"^const (\w+) := (Cfg\w+)\.(\w+).*$", proto, re.M)
    body = re.sub(r"^const \w+ := Cfg\w+\.\w+.*$", "", proto, flags=re.M) + others
    cfg_all = "".join(open(f"{ROOT}/scripts/botnet_cfg/{g}.gd").read() for g in DATA if g != "engine")
    out = {}
    for f, consts in DATA.items():
        if f == "engine": continue
        for k in consts:
            names = [a for a, _, b in aliases if b == k] + [k]
            used = any(re.search(r"\b%s\b" % nm, body) for nm in names) or re.search(r"Cfg\w+\.%s\b" % k, body)
            inner = len(re.findall(r"^[^#\n]*\b%s\b" % k, cfg_all, re.M)) > 1   # read by another constant
            if not used and not inner: out.setdefault(f, []).append(k)
    return out
UNUSED = find_unused()
T = DATA["tuning"]; TY = DATA["types"]
def per_min(cost_cycle):   # units per production cycle -> per minute
    return cost_cycle * 60.0 / float(T["PROD_CYCLE"])

def start_chips():
    return chips({r: int(T["START"][r]) for r in RES})
def basecap():
    return ", ".join(f"{RES_NAME[r]} {int(T['BASE_CAP'][r])}" for r in RES)
SIZE_NAMES = ["Small", "Medium", "Big"]
def sizes():
    out = []
    for nm, (c, r) in zip(SIZE_NAMES, DATA["engine"]["SIZE_PRESETS"]):
        out.append(f"{nm} {int(c)}×{int(r)} (≈{max(12, round(c * r * 0.85))} hosts)")
    return ", ".join(out)
TYPE_ORDER = ["iot", "pc", "server", "web", "file", "db", "erp"]
def weight_head():
    return "".join(f"<th>{html.escape(TY['NODE_TYPES'][t]['name'])}</th>" for t in TYPE_ORDER)
def weights():
    rows = []
    for v in ["1", "2", "3"]:
        w = TY["TYPE_WEIGHTS"][v]
        rows.append(f"<tr><th>{v} {'(near starts)' if v == '1' else '(far from every start)' if v == '3' else ''}</th>" + "".join(f"<td class='num'>{int(round(float(w.get(t, 0)) * 100))}%</td>" if w.get(t) else "<td class='num'>·</td>" for t in TYPE_ORDER) + "</tr>")
    rows.append("<tr><th>hub</th>" + "".join("<td class='num'>always</td>" if t == "erp" else "<td class='num'>·</td>" for t in TYPE_ORDER) + "</tr>")
    return "".join(rows)
MULT_NAME = {"intel": "Intel", "cash": "Crypto", "cred": "Credentials", "research": "Research"}
def hosttypes():
    rows = []
    for t in TYPE_ORDER:
        nt = TY["NODE_TYPES"][t]
        mults = [f"{MULT_NAME[k]} ×{n(nt[k])}" for k in ["intel", "cash", "cred", "research"] if float(nt[k]) != 1.0]
        rows.append(f"<tr><th>{html.escape(nt['name'])}</th><td class='num'>{int(nt['slots'])}</td><td>{', '.join(mults) or 'none'}</td></tr>")
    return "".join(rows)
def ch(d):
    return chips({k: v for k, v in d.items() if v})
LAYOUTS = [
    # (what one cycle makes; the table shows it a minute, per_min, and the main node adds its trickle)
    ("Bot station + Intel harvester + Miner", "1 Intel + 1 Crypto; 2 workers for the pool", "2 units by your workers", {"intel": 1, "cash": 1}),
    ("Bot station + Intel harvester + Cred. harvester", "1 Intel + 1 Credential; 2 workers", "2 units by your workers", {"intel": 1, "creds": 1}),
    ("Intel harvester + Miner + Lab", "1 Intel + 1 Crypto + 1 Research", "3 units by your workers", {"intel": 1, "cash": 1, "research": 1}),
    ("2 Intel harvesters + Miner", "2 Intel + 1 Crypto", "3 units by your workers", {"intel": 2, "cash": 1}),
    ("Bot station alone (IoT device)", "2 workers for the pool", "nothing to carry", {}),
    ("Miner alone", "1 Crypto, no input", "1 unit by your workers", {"cash": 1}),
    ("Database: harvester + 2 Cred. harvesters", "2 Intel + 3 Credentials (Database: Intel x2, Credentials x1.5)", "5 units by your workers", {"intel": 2, "creds": 3}),
    ("Main node (Server): Intel harvester + Bot station + Miner", "1.5 Intel + 1 Crypto; 2 workers", "straight into the bank, plus the trickle", {"intel": 1.5, "cash": 1, "trickle": True}),
]
def layouts():
    out = []
    for nm, made, deliv, cyc in LAYOUTS:
        net = {r: round(per_min(float(cyc.get(r, 0))) + (float(T["MAIN_INCOME"]) * 60.0 if cyc.get("trickle") else 0.0), 2) for r in RES}
        net_txt = "".join(f'<span class="chip r-{r}"><b>{"+" if v > 0 else "−"}{n(abs(v))}</b> {RES_SHORT[r]}</span>' for r, v in ((r, net.get(r, 0)) for r in RES) if v)
        out.append(f"<tr><th>{html.escape(nm)}</th><td>{html.escape(made)}</td><td>{html.escape(deliv)}</td><td class='nowrap'>{net_txt or '0'}</td></tr>")
    out.append(f"<tr><th>+ a Firewall on the host</th><td>uses 1 Intel</td><td>—</td><td class='nowrap'><span class='chip r-intel'><b>−{n(round(per_min(1), 2))}</b> Intel</span></td></tr>")
    return "".join(out)
def inc_row(inc):
    return "".join(f"<td class='num'>{inc[r]}</td>" for r in RES)
def capture_ev():   # what a capture costs: a vector, its times and the reaction window it gives (no unit sums)
    rows = []
    for k in ["breach", "exploit", "zeroday", "worm"]:
        c = C[k]
        e, ew = wait(c["make"], EARLY); m, mw = wait(c["make"], MID)
        ex = f"{n(c['exec'])} s" + (f" ({n(c['exec_rig'])} s on a main node)" if c.get("exec_rig") else "") + (f" per stage, {n(c['reach'])} stages" if k == "worm" else "")
        rows.append(f"<tr><th>{html.escape(c['name'])}</th><td class='nowrap'>{chips(c['make'])}</td><td class='num'>{n(c['time'])} s</td><td class='num'>{ex}</td><td class='num'>{e:.0f} s ({ew}) · {m:.0f} s ({mw})</td></tr>")
    return "".join(rows)
BC = DATA["buildings"]["BUILD_COSTS"]
PAYBACK = [   # what each building adds and uses; no single "payback" number: the resources are not interchangeable
    ("Intel harvester", BC["intel"], "+1 Intel a cycle (+1.5 on a Server, +2 on a database or file server)", "Pays for most cards, the harvesters and the Firewalls' upkeep."),
    ("Bot station", BC["bot"], "2 reusable workers for the one pool at the main node", "More round trips for every host: building materials first, then output home."),
    ("Crypto miner", BC["cash"], "+1 Crypto a cycle, no input", "Buildings and blueprints are paid mostly in Crypto."),
    ("Credential harvester", BC["cred"], "+1 Credential a cycle, no input", "The capture and theft budget: a Breach is mostly Credentials."),
    ("Research lab", BC["lab"], "+1 Research a cycle, no input", "Blueprints and the Known exploit, Worm and 0day cards."),
    ("Firewall", BC["wall"], "3 sockets; uses 1 Intel on its host", "Returns nothing directly: its value is what its loaded cards stop."),
]
def payback():
    return "".join(f"<tr><th>{html.escape(nm)}</th><td class='nowrap'>{chips(c)}</td><td>{html.escape(a)}</td><td>{html.escape(b)}</td></tr>" for nm, c, a, b in PAYBACK)
def unused():
    return "".join(f"<tr><th>{f}.gd</th><td><code>{'</code>, <code>'.join(v)}</code></td></tr>" for f, v in UNUSED.items())
COMMANDS = "build (order a project: free until its materials arrive), demolish, cancel (a project; its delivered materials stay as salvage), research, cancel_research, card (play a card on a host, with a resource for a siphon), queue (add a copy to the four-place queue, with a command id), unqueue (remove one), queue_pause"
json_txt = json.dumps(DATA, indent=1, ensure_ascii=False)

page = open(os.path.join(HERE, "design.head.html")).read() + open(os.path.join(HERE, "design.body.html")).read()
for key, val in {"VERSION": str(DATA["engine"]["GAME_VERSION"]), "SIZES": sizes(), "START": start_chips(), "BASECAP": basecap(),
                 "WEIGHT_HEAD": weight_head(), "WEIGHTS": weights(), "HOSTTYPES": hosttypes(), "LAYOUTS": layouts(),
                 "COMMANDS": html.escape(COMMANDS), "CAP_PER_PRODUCER": n(T["CAP_PER_PRODUCER"]), "EARLY": inc_row(EARLY), "MID": inc_row(MID), "CAPTURE_EV": capture_ev(),
                 "PAYBACK": payback(), "UNUSED": unused(), "JSON": html.escape(json_txt), "JSON_KB": str(round(len(json_txt) / 1024))}.items():
    page = page.replace("{{%s}}" % key, val)
page = page.replace("{{COMMIT}}", COMMIT)
page = page.replace("{{BUILDINGS}}", "".join(brow(k) for k in ["intel", "bot", "cash", "cred", "lab", "wall"]))
page = page.replace("{{ATTACK}}", "".join(card_sheet(k) for k in attack))
page = page.replace("{{DEFENCE}}", "".join(card_sheet(k) for k in defence))
page = page.replace("{{RESEARCH}}", "".join(rrow(k) for k in research_order))
page = page.replace("{{PRICES}}", "".join(price_row(k) for k in attack + defence))
open(OUT, "w").write(page)
print("wrote", os.path.relpath(OUT, ROOT), len(page))


# ---- DESIGN.md: the same document as GitHub-flavoured Markdown ----
def to_markdown(doc: str) -> str:
    body = doc[doc.index('<div class="wrap">'):]
    body = re.sub(r"<script>.*?</script>", "", body, flags=re.S)
    body = re.sub(r'<nav class="toc".*?</nav>', "", body, flags=re.S)
    body = re.sub(r'<div><button class="copy".*?</details>', '<p>The data: <a href="rim_constants.json">rim_constants.json</a>.</p>', body, flags=re.S)
    body = body.replace("class='chip ", 'class="chip ').replace("r-intel'>", 'r-intel">')
    body = re.sub(r'<h2>(.*?)\s*<small>.*?</small></h2>', r"<h2>\1</h2>", body, flags=re.S)
    body = re.sub(r"<small>([^<]*)</small>", r"(\1)", body)
    body = re.sub(r'<span class="label">([^<]*)</span>', r"<b>\1:</b> ", body)
    body = re.sub(r"<figcaption>(.*?)</figcaption>", r"<p><em>\1</em></p>", body, flags=re.S)
    body = body.replace("</span><span class=\"chip", "</span>, <span class=\"chip")
    body = re.sub(r'<span class="chip time"><b>([^<]*)</b> s</span>', r"\1 s", body)
    body = re.sub(r'<span class="chip[^"]*"><b>([^<]*)</b>([^<]*)</span>', r"\1\2", body)
    body = re.sub(r'<span class="chip[^"]*">([^<]*)</span>', r"\1", body)
    body = re.sub(r'<span class="label">([^<]*)</span>', r"<b>\1:</b> ", body)
    body = re.sub(r'<span class="wait">([^<]*)</span>', r" (\1)", body)
    body = re.sub(r'<span class="tag[^"]*">([^<]*)</span>', r"<code>\1</code> ", body)
    body = re.sub(r"<dt>(.*?)</dt><dd>(.*?)</dd>", r"<li><b>\1:</b> \2</li>", body, flags=re.S)
    body = body.replace("<dl>", "<ul>").replace("</dl>", "</ul>")
    body = re.sub(r'<pre class="mermaid">(.*?)</pre>', lambda m: '<pre><code class="language-mermaid">' + m.group(1) + "</code></pre>", body, flags=re.S)
    body = re.sub(r'<h2>(.*?)\s*<small>.*?</small></h2>', r"<h2>\1</h2>", body, flags=re.S)
    if not shutil.which("pandoc"): return ""
    md = subprocess.run(["pandoc", "-f", "html", "-t", "gfm", "--wrap=none"], input=body, capture_output=True, text=True).stdout
    md = re.sub(r"</?div[^>]*>\n?", "", md)
    md = re.sub(r"</?(article|header|section|figure|figcaption)[^>]*>\n?", "", md)
    md = re.sub(r'<pre class="mermaid"><code>(.*?)</code></pre>', lambda m: "```mermaid\n" + html.unescape(m.group(1)).strip() + "\n```\n", md, flags=re.S)
    md = re.sub(r"<p><em>(.*?)</em></p>", r"*\1*", md, flags=re.S)
    md = re.sub(r"\n{3,}", "\n\n", md)
    toc = "\n".join("- [%s](#%s)" % (t, re.sub(r"[^a-z0-9 -]", "", t.lower()).replace(" ", "-")) for t in re.findall(r"^## (.+)$", md, re.M))
    head = ("<!-- Generated by docs/tools/build_design.py from the game's config. Edit the tools, not this file. -->\n\n"
            "# RIM design reference\n\nThe whole design of RIM as the game runs it: flow, map, economy, logistics, every card, defence, "
            "winning, the AI, multiplayer and the interface, with derived numbers for analysis. Same content as "
            "[design.html](design.html); every constant is in [rim_constants.json](rim_constants.json).\n\n"
            f"RIM {DATA['engine']['GAME_VERSION']} · commit {COMMIT}\n\n## Contents\n\n{toc}\n\n")
    md = re.sub(r"^# RIM rules reference\n+.*?(?=^## )", "", md, flags=re.M | re.S)
    return head + md


md = to_markdown(page)
if md:
    open(os.path.join(DOCS, "DESIGN.md"), "w").write(md)
    print("wrote docs/DESIGN.md", len(md))
else:
    print("pandoc not found: docs/DESIGN.md not rebuilt")
