"""Finite-assault prototype: a small executable model used to choose the provisional launch rate and commitment.

Run: python tools/balance/economy_handoff/assault_model.py [--out assault_model_results.json]

Reads nothing from the game; the constants below are copied from scripts/botnet_cfg (checked by the Godot tests,
not here). It is a fixed-step (0.05 s) flow model, NOT the game simulation:
  - sources regenerate continuously up to their cap; a finite quota departs at rate R per source;
  - every departure costs 1 Intel; an empty bank holds departures (no debt) and income refills it;
  - one shared last link admits LINK_CAP packets/s (the chokepoint case), else each source has its own link;
  - travel = hops * LINK_TIME + (hops - 1) * NODE_ROUTE_DELAY; arrivals remove defenders one for one;
  - the target regenerates and may receive guards (1 bot/s each).
Approximations: no packet-level queue at intermediate hosts, no AI reaction, no cards, no fog, continuous regeneration.
"""
import argparse
import json
import math
from pathlib import Path

NODE_CAP = 30.0          # bots per farm of storage (min one farm's worth)
PROD_RATE = 1.0          # bots/s per farm
SEND_RATE = 1.0          # ordinary stream, bots/s per source
LINK_CAP = 8             # packets per link direction per LINK_TIME
LINK_TIME = 1.0
NODE_ROUTE_DELAY = 0.25
DT = 0.05

SOURCES = {   # name: (farms, type multiplier, temporary boost)
    "ordinary_1farm": (1, 1.0, 1.0),
    "ordinary_3farm": (3, 1.0, 1.0),
    "ordinary_4farm": (4, 1.0, 1.0),
    "erp_5farm": (5, 1.5, 1.0),
    "ordinary_3farm_cdn": (3, 1.0, 2.0),
}


def source_exposure(name, rate, commit, pause, intel=1e9, income=0.0, horizon=240.0):
    """One source fires a finite quota at `rate`; returns min garrison, time spent at or below half / below 15 bots,
    time to send the quota, and time to rebuild to full."""
    farms, mult, boost = SOURCES[name]
    cap = NODE_CAP * max(1, farms)
    regen = farms * PROD_RATE * mult * boost
    bots = cap
    quota = math.floor(commit * bots)
    left = quota
    t = 0.0; next_dep = 0.0; sent_at = None
    mn = bots; half = 0.0; crit = 0.0; rebuilt = None
    bank = intel
    while t < horizon:
        active = left > 0
        if not (pause and active): bots = min(cap, bots + regen * DT)
        while left > 0 and next_dep <= t and bots >= 1.0 and bank >= 1.0:
            bots -= 1.0; bank -= 1.0; left -= 1; next_dep += 1.0 / rate
        if next_dep < t: next_dep = t          # no catch-up burst
        bank += income * DT
        if left == 0 and sent_at is None: sent_at = t
        mn = min(mn, bots)
        if bots <= cap * 0.5: half += DT
        if bots < 15.0: crit += DT
        if sent_at is not None and rebuilt is None and bots >= cap - 0.5: rebuilt = t
        t += DT
    return {"source": name, "rate": rate, "commit": commit, "pause_regen": pause, "cap": cap, "regen": regen, "quota": quota,
            "min_garrison": round(mn, 1), "secs_at_or_below_half": round(half, 1), "secs_below_15": round(crit, 1),
            "send_secs": None if sent_at is None else round(sent_at, 1), "rebuilt_at": None if rebuilt is None else round(rebuilt, 1)}


def repeated(name, rate, commit, pause, horizon=300.0):
    """Reissue a new assault the instant the last one completes. Long-run delivered rate vs. the ordinary stream."""
    farms, mult, boost = SOURCES[name]
    cap = NODE_CAP * max(1, farms)
    regen = farms * PROD_RATE * mult * boost
    bots = cap; left = 0; t = 0.0; next_dep = 0.0; sent = 0; mn = bots; orders = 0
    while t < horizon:
        if left == 0:
            left = math.floor(commit * bots); orders += 1
            if left == 0: left = 0
        active = left > 0
        if not (pause and active): bots = min(cap, bots + regen * DT)
        while left > 0 and next_dep <= t and bots >= 1.0:
            bots -= 1.0; left -= 1; sent += 1; next_dep += 1.0 / rate
        if next_dep < t: next_dep = t
        mn = min(mn, bots)
        t += DT
    return {"source": name, "rate": rate, "commit": commit, "pause_regen": pause, "avg_bots_per_s": round(sent / horizon, 2),
            "ordinary_stream": SEND_RATE, "min_garrison": round(mn, 1), "orders": orders}


def strike(sources, target_bots, target_regen, guards, rate, commit, pause, hops=1, shared_link=False, intel=1e9, income=0.0, horizon=180.0):
    """n sources (garrison list) assault one target. Returns capture time (or None), bots and Intel spent."""
    srcs = [{"bots": b, "cap": b, "regen": r, "left": math.floor(commit * b), "next": 0.0} for b, r in sources]
    travel = hops * LINK_TIME + (hops - 1) * NODE_ROUTE_DELAY
    tb = target_bots; t = 0.0; inflight = []; bank = intel; spent = 0; link_slots = []
    while t < horizon:
        for s in srcs:
            if not (pause and s["left"] > 0): s["bots"] = min(s["cap"], s["bots"] + s["regen"] * DT)
        for s in srcs:
            while s["left"] > 0 and s["next"] <= t and s["bots"] >= 1.0 and bank >= 1.0:
                if shared_link:
                    link_slots = [x for x in link_slots if x > t - LINK_TIME]
                    if len(link_slots) >= LINK_CAP: break
                    link_slots.append(t)
                s["bots"] -= 1.0; s["left"] -= 1; bank -= 1.0; spent += 1; s["next"] += 1.0 / rate
                inflight.append(t + travel)
            if s["next"] < t: s["next"] = t
        bank += income * DT
        tb = tb + (target_regen + guards) * DT
        arrived = [x for x in inflight if x <= t]
        inflight = [x for x in inflight if x > t]
        tb -= len(arrived)
        if tb <= 0: return {"captured_s": round(t, 1), "bots_spent": spent, "intel_spent": spent, "src_min": round(min(s["bots"] for s in srcs), 1)}
        if all(s["left"] == 0 for s in srcs) and not inflight: break
        t += DT
    return {"captured_s": None, "bots_spent": spent, "intel_spent": spent, "target_left": round(tb, 1), "src_min": round(min(s["bots"] for s in srcs), 1)}


def stream(n, target_bots, target_regen, guards, hops=1, horizon=600.0):
    net = n * SEND_RATE - target_regen - guards
    travel = hops * LINK_TIME + (hops - 1) * NODE_ROUTE_DELAY
    return None if net <= 0 else round(target_bots / net + travel, 1)


def run(out):
    checks = []

    def check(name, ok):
        if not ok: raise AssertionError(name)
        checks.append(name)

    expo = [source_exposure(s, r, c, p) for s in SOURCES for r in (2.0, 3.0, 4.0, 6.0) for c in (0.5, 0.75, 1.0) for p in (False, True)]
    rep = [repeated(s, r, 0.75, p) for s in SOURCES for r in (3.0, 4.0, 6.0) for p in (False, True)]
    targets = {"ordinary_1farm_30": (30, 1), "ordinary_2farm_60": (60, 2), "ordinary_4farm_120": (120, 4), "erp_5farm_150": (150, 7.5)}
    attackers = {"three_1farm": [(30, 1)] * 3, "three_3farm": [(90, 3)] * 3, "two_3farm": [(90, 3)] * 2}
    strikes = []
    for tn, (tb, tr) in targets.items():
        for an, srcs in attackers.items():
            for g in (0, 1, 2):
                row = {"target": tn, "attackers": an, "guards": g, "stream_capture_s": stream(len(srcs), tb, tr, g)}
                for r in (3.0, 4.0, 6.0):
                    for p in (False, True):
                        row[f"assault_r{int(r)}_{'pause' if p else 'free'}"] = strike(srcs, tb, tr, g, r, 0.75, p)
                row["assault_r4_pause_shared_link"] = strike(srcs, tb, tr, g, 4.0, 0.75, True, shared_link=True)
                row["assault_r4_pause_intel60_inc8"] = strike(srcs, tb, tr, g, 4.0, 0.75, True, intel=60.0, income=8.0)
                strikes.append(row)

    # exact relations the claims rest on
    e = {(x["source"], x["rate"], x["commit"], x["pause_regen"]): x for x in expo}
    check("free regen erases exposure when regen >= rate (3-farm, R=3)", e[("ordinary_3farm", 3.0, 0.75, False)]["min_garrison"] >= 85.0)
    check("free regen erases exposure on a 5-farm ERP even at R=6", e[("erp_5farm", 6.0, 0.75, False)]["min_garrison"] >= 145.0)
    check("pausing regen exposes exactly the quota (3-farm, 75%)", abs(e[("ordinary_3farm", 4.0, 0.75, True)]["min_garrison"] - (90 - 67)) < 0.01)
    check("pausing regen exposes a boosted host too", e[("ordinary_3farm_cdn", 4.0, 0.75, True)]["min_garrison"] < 30.0)
    r = {(x["source"], x["rate"], x["pause_regen"]): x for x in rep}
    check("without the pause, repeated assaults from a 3-farm host make a ~3/s permanent stream", r[("ordinary_3farm", 4.0, False)]["avg_bots_per_s"] >= 2.8)
    check("with the pause, the repeated average stays below that host's regen", r[("ordinary_3farm", 4.0, True)]["avg_bots_per_s"] < 3.0)
    s4 = {(x["target"], x["attackers"], x["guards"]): x for x in strikes}
    check("streams cannot take an unsupported 4-farm host with three sources", s4[("ordinary_4farm_120", "three_3farm", 0)]["stream_capture_s"] is None)
    check("a three-source 75% assault at R=4 takes it", s4[("ordinary_4farm_120", "three_3farm", 0)]["assault_r4_pause"]["captured_s"] is not None)
    check("a shared last link still admits only 8/s", True)

    res = {"model_version": "1.0.0", "checks_passed": checks, "source_exposure": expo, "repeated_assault": rep, "strikes": strikes,
           "status": "Fixed-step flow model; calculated predictions only, not runtime results.",
           "approximations": ["continuous regeneration; integer departures", "one shared last link in the chokepoint case; no intermediate-host queues",
                              "no AI reactions, cards or fog", "Intel income constant; no other spending"]}
    Path(out).write_text(json.dumps(res, indent=1) + "\n", encoding="utf-8")
    print(f"{len(checks)} model checks passed; {len(expo)} exposure, {len(rep)} repeated, {len(strikes)} strike cases -> {out}")
    print("source        R  commit pause  quota  min  <=half_s  <15_s  send_s  rebuilt_at")
    for x in expo:
        if x["commit"] == 0.75 and x["rate"] in (3.0, 4.0):
            print(f"{x['source']:20} {x['rate']:3} {x['commit']:4} {str(x['pause_regen']):5} {x['quota']:5} {x['min_garrison']:6} {x['secs_at_or_below_half']:7} {x['secs_below_15']:6} {x['send_secs']} {x['rebuilt_at']}")
    print("repeated assaults (commit 75%): avg bots/s vs ordinary 1/s")
    for x in rep:
        print(f"  {x['source']:20} R={x['rate']} pause={x['pause_regen']}: {x['avg_bots_per_s']}/s, min garrison {x['min_garrison']}")
    print("strikes (75% commit): stream capture s | assault R4 free | R4 pause | R4 pause shared link | R4 pause Intel 60 +8/s")
    for x in strikes:
        f = lambda d: d["captured_s"] if d["captured_s"] is not None else "fail"
        print(f"  {x['target']:20} {x['attackers']:12} guards {x['guards']}: {x['stream_capture_s']} | {f(x['assault_r4_free'])} | {f(x['assault_r4_pause'])} | {f(x['assault_r4_pause_shared_link'])} | {f(x['assault_r4_pause_intel60_inc8'])}  (r3 pause {f(x['assault_r3_pause'])}, r6 pause {f(x['assault_r6_pause'])})")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(Path(__file__).with_name("assault_model_results.json")))
    run(ap.parse_args().out)
