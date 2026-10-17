import json, os, sys, statistics as st
D = sys.argv[1]
def load(n):
    p = os.path.join(D, n)
    return json.load(open(p)) if os.path.exists(p) else None
seeds = [7, 19, 43]
rows = []
print("## Matches (policy faction = NYX vs 2 Normal AIs, Small 6x4, 900 s cap)")
hdr = "rules  policy    seed | end    winner pol_won | caps lost | 1st cap 1st miner 1st newfarm | farms@120/300/600/end hosts@120/300/600/end | Intel ovf attack build | C prod deliv build pausedMiner_s | stall_C_s | captures:first-farm median / all-farm median"
print(hdr)
for rs in ["base", "cand", "c20"]:
    for pol in ["original", "adapted", "adapted_late"]:
        for s in seeds:
            d = load(f"match_{rs}_{pol}_s{s}.json")
            if d is None: continue
            a = d["accounting"]; e = d["events"]; stg = d["stages"]
            def sv(k, f): return stg.get(k, {}).get(f, "-")
            ff = [c["first_farm_after_s"] for c in d["captures"] if c["first_farm_after_s"] is not None]
            af = [c["all_farms_after_s"] for c in d["captures"] if c["all_farms_after_s"] is not None]
            nofarm = sum(1 for c in d["captures"] if c["first_farm_after_s"] is None)
            rows.append({"rs": rs, "pol": pol, "seed": s, "d": d})
            print(f"{rs:5} {pol:9} {s:4} | {d['end_t']:6} {d['winner']:>3} {str(d['policy_won']):5} | {d['captures_total']:4} {d['hosts_lost']:4} | {e.get('first_capture','-'):>6} {e.get('first_miner_order','-'):>6} {e.get('first_new_farm','-'):>6} | "
                  f"{sv('early','farms')}/{sv('mid','farms')}/{sv('late','farms')}/{d['final']['farms']} {sv('early','hosts')}/{sv('mid','hosts')}/{sv('late','hosts')}/{d['final']['hosts']} | "
                  f"{a['overflow_intel']:7} {a['attack_intel']:6} {a['build_intel']:6} | {a.get('crypto_produced',0):6} {a.get('crypto_delivered',0):6} {a['build_cash']:6} {a.get('miner_paused_s',0):7} | {a['stall_cash_s']:6} | "
                  f"{(st.median(ff) if ff else '-')} / {(st.median(af) if af else '-')} (caps never farmed {nofarm})")
print()
print("## Bank trajectory (policy faction): Intel / cap / Crypto at 60,120,180,300,450,600,900 s")
for r in rows:
    smp = r["d"]["samples"]
    pts = []
    for t in [60, 120, 180, 300, 450, 600, 900]:
        best = None
        for x in smp:
            if x["t"] <= t + 0.01: best = x
        if best is not None and best["t"] >= t - 5.1: pts.append(f"{int(best['intel'])}/{int(best['intel_cap'])}/{int(best['cash'])}")
        else: pts.append("-")
    print(f"{r['rs']:5} {r['pol']:9} {r['seed']:3}: " + "  ".join(pts))
print()
print("## Fixtures")
for s in seeds:
    for rs in ["base", "cand", "c20"]:
        f = load(f"fixtures_{rs}_s{s}.json")
        if f is None: print(rs, s, "MISSING"); continue
        print(f"-- {rs} seed {s}")
        print("  opening direct:", f["bootstrap_direct"]["first_additional_farm_s"], f["bootstrap_direct"]["orders"])
        print("  opening harvester-first:", f["bootstrap_harvester_first"]["first_additional_farm_s"], f["bootstrap_harvester_first"]["orders"])
        print("  recovery direct:", f["recovery_direct"]["first_farm_s"], f["recovery_direct"]["orders"])
        print("  recovery optimized:", f["recovery_optimized"]["first_farm_s"], f["recovery_optimized"]["orders"])
        for k in ["prepared_equal_bank", "prepared_full_cap"]:
            p = f[k]
            print(f"  {k}:", p.get("skipped") or ("start Intel", p["intel_start"], "farms standing", p["farms_standing_after_s"], "cash end", p["cash_end"]))
        for it in f["interruption"]:
            print("  outage bank", it.get("crypto_bank"), ":", it.get("skipped") or ("miners", it["miners_paused"], "farms in outage", it["farms_done_in_outage"], "by 120 s", it["farms_done_by_120s"], "stalled job-s", it["stalled_job_seconds"], "cash end", it["cash_end"]))
        for path, c in f["card_alternative"].items():
            print(f"  card alt [{path}]:", c.get("skipped") or ("captured after", c["captured_after_s"], "target", c["target_type"], "orders", c["orders"][:6]))
        print("  midgame:", f["prepared_equal_bank"].get("midgame"))

print()
print("## Paired summary per seed (policy faction)")
def get(rs,pol,s):
    return load(f"match_{rs}_{pol}_s{s}.json")
for s in seeds:
    b = get("base","original",s)
    for rs in ["cand","c20"]:
        for pol in ["original","adapted","adapted_late"]:
            d = get(rs,pol,s)
            if d is None or b is None: continue
            print(f"seed {s} {rs:4} {pol:12}: end {d['end_t']:6} (base {b['end_t']:6}, x{d['end_t']/b['end_t']:.2f})  won {d['policy_won']!s:5} (base {b['policy_won']!s:5})  caps {d['captures_total']:3} (base {b['captures_total']:3})  farms@300 {d['stages'].get('mid',{}).get('farms','-')} (base {b['stages'].get('mid',{}).get('farms','-')})  1st farm {d['events'].get('first_new_farm','-')} (base {b['events'].get('first_new_farm','-')})")
